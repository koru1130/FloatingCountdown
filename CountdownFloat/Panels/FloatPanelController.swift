import AppKit
import Combine
import SwiftUI

/// A stable layout boundary between NSWindow and NSHostingView. Hosting views
/// can otherwise propagate a changed SwiftUI fitting size back to their window
/// and undo the frame explicitly calculated by FloatPanelController.
final class FloatPanelContentView: NSView {
    override var isOpaque: Bool { false }
}

/// Applies the user scale as a SwiftUI environment value so the timer surface
/// and its controls both grow through real layout rather than render transforms.
private struct ScaledFloatRoot: View {
    let content: FloatView
    let onChange: () -> Void
    let onHide: () -> Void
    let alwaysShowControls: Bool
    let scale: CGFloat

    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content
                .environment(\.floatLayoutScale, scale)

            if alwaysShowControls || isHovered {
                FloatControlsPill(
                    scale: scale,
                    onChange: onChange,
                    onHide: onHide
                )
                .zIndex(2)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

/// Owns the always-on-top countdown float. Hiding the panel only calls
/// `orderOut`; the store (and therefore its timer) is intentionally untouched.
@MainActor
final class FloatPanelController: NSObject, NSWindowDelegate {
    let store: CountdownStore
    let panel: CountdownPanel

    /// The presentation-only scale model.  Menu/SwiftUI integrations can read
    /// or write `scaleSettings.scale`; every accepted write is persisted and
    /// resizes this panel immediately.
    let scaleSettings: FloatScaleSettings

    private let rootContent: FloatView
    private let contentContainer: FloatPanelContentView
    private let hostingView: NSHostingView<ScaledFloatRoot>
    private let measurementHostingView: NSHostingView<FloatView>
    private let alwaysShowControls: Bool
    private var storeObservation: AnyCancellable?
    private var scaleObservation: AnyCancellable?
    private let onChange: () -> Void
    private let onHide: () -> Void
    private var hasRestoredPosition = false
    private var lastBaseContentSize: CGSize?
    private var pendingScaleAnchor: FloatScaleAnchor?
    private var scrollZoomAccumulator = FloatScrollZoomAccumulator()
    private var presentedScale: CGFloat
    private var isApplyingLayout = false
    private var isApplyingFrame = false
    private let positionKeyPrefix: String
    private let initialPlacementOffset: CGFloat

    private var originXKey: String { "\(positionKeyPrefix).originX" }
    private var originYKey: String { "\(positionKeyPrefix).originY" }

    init(
        store: CountdownStore,
        scaleSettings: FloatScaleSettings = FloatScaleSettings(),
        positionKeyPrefix: String = "floatPanel",
        initialPlacementOffset: CGFloat = 0,
        onChange: @escaping () -> Void = {},
        onHide: @escaping () -> Void = {},
        alwaysShowControls: Bool = false
    ) {
        self.store = store
        self.scaleSettings = scaleSettings
        self.onChange = onChange
        self.onHide = onHide
        self.positionKeyPrefix = positionKeyPrefix
        self.initialPlacementOffset = max(0, initialPlacementOffset)

        let initialRect = NSRect(x: 0, y: 0, width: 116, height: 84)
        let panel = CountdownPanel(
            contentRect: initialRect,
            styleMask: [.borderless, .nonactivatingPanel],
            kind: .float
        )
        self.panel = panel

        let view = FloatView(store: store, showsControls: false)
        self.rootContent = view
        self.contentContainer = FloatPanelContentView(frame: initialRect)
        self.alwaysShowControls = alwaysShowControls
        self.presentedScale = scaleSettings.scale
        self.hostingView = NSHostingView(
            rootView: ScaledFloatRoot(
                content: view,
                onChange: onChange,
                onHide: onHide,
                alwaysShowControls: alwaysShowControls,
                scale: scaleSettings.scale
            )
        )
        self.measurementHostingView = NSHostingView(
            rootView: FloatView(store: store, showsControls: false)
        )
        super.init()

        panel.delegate = self
        // The hosting bounds intentionally include transparent room for the
        // overhanging hover controls. Make that room genuinely transparent
        // instead of inheriting an AppKit backing color.
        contentContainer.wantsLayer = true
        contentContainer.layer?.backgroundColor = NSColor.clear.cgColor
        contentContainer.layer?.masksToBounds = true
        hostingView.frame = contentContainer.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.sizingOptions = []
        contentContainer.addSubview(hostingView)
        panel.contentView = contentContainer
        panel.isMovableByWindowBackground = true
        panel.acceptsMouseMovedEvents = true
        panel.setAccessibilityTitle("Countdown")
        panel.onScrollWheel = { [weak self] event in
            self?.handleScrollWheel(event)
        }

        // SwiftUI state changes can alter Bar/Ring intrinsic dimensions (and
        // urgent/completed overlays can change the requested size). Refit on
        // every published update, without relying on a fixed frame.
        storeObservation = store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshLayout()
            }

        // This subscription is intentionally separate from CountdownStore:
        // changing a presentation preference must never mutate countdown
        // timing state. The sink also covers direct SwiftUI bindings.
        scaleObservation = scaleSettings.$scale
            .receive(on: RunLoop.main)
            .sink { [weak self] scale in
                self?.scaleDidChange(scale)
            }
    }

    deinit {
        storeObservation?.cancel()
        scaleObservation?.cancel()
    }

    // MARK: - Lifecycle

    func show() {
        // Fit synchronously before calculating the first origin. This is the
        // critical ordering that prevents an async fitting pass from moving a
        // newly shown float away from the requested top-right inset.
        layoutContentSynchronously(clamp: false)
        restoreOrPlace()
        panel.orderFrontRegardless()
    }

    func hide() {
        // Do not pause/cancel the store here. The menu-bar status and
        // completion notification must continue while the float is hidden.
        // A newly-created, not-yet-started session has never been placed. Do
        // not let cancelling that editor overwrite a previously saved origin
        // with the panel's temporary construction frame.
        if hasRestoredPosition {
            clampToVisibleFrame()
            persistPosition()
        }
        panel.orderOut(nil)
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    /// Publicly callable by AppDelegate after a mode/state change.
    ///
    /// The first pass is synchronous so callers get an immediately useful
    /// panel size. While visible, a second pass is scheduled for the next
    /// run-loop turn because `objectWillChange` can arrive just before
    /// SwiftUI has committed the new store value. That pass retains the
    /// current origin and clamps it, so content changes never drift the float.
    func refreshLayout() {
        layoutContentSynchronously(clamp: hasRestoredPosition)

        guard panel.isVisible else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.layoutContentSynchronously(clamp: self.hasRestoredPosition)
        }
    }

    // MARK: - Scale API

    /// Set the user scale and choose which edge remains stable while the
    /// panel resizes. Direct writes to `scaleSettings.scale` use `.center`.
    func setScale(_ value: CGFloat, anchor: FloatScaleAnchor = .center) {
        applyScaleChange(anchor: anchor) {
            scaleSettings.setScale(value)
        }
    }

    @discardableResult
    func increaseScale(anchor: FloatScaleAnchor = .center) -> CGFloat {
        applyScaleChange(anchor: anchor) {
            scaleSettings.increase()
        }
    }

    @discardableResult
    func decreaseScale(anchor: FloatScaleAnchor = .center) -> CGFloat {
        applyScaleChange(anchor: anchor) {
            scaleSettings.decrease()
        }
    }

    func resetScale(anchor: FloatScaleAnchor = .center) {
        applyScaleChange(anchor: anchor) {
            scaleSettings.reset()
            return scaleSettings.scale
        }
    }

    @discardableResult
    private func applyScaleChange(
        anchor: FloatScaleAnchor,
        _ update: () -> CGFloat
    ) -> CGFloat {
        pendingScaleAnchor = anchor
        let acceptedScale = update()
        scaleDidChange(acceptedScale)
        return acceptedScale
    }

    private func handleScrollWheel(_ event: NSEvent) {
        // Inertial trackpad events can keep arriving after the pointer gesture
        // ends. Ignore that momentum so one deliberate swipe maps to one
        // bounded sequence of zoom steps.
        guard event.momentumPhase.isEmpty else {
            if event.momentumPhase.contains(.ended)
                || event.momentumPhase.contains(.cancelled) {
                scrollZoomAccumulator.reset()
            }
            return
        }

        if event.phase.contains(.began) {
            scrollZoomAccumulator.reset()
        }

        let steps = scrollZoomAccumulator.steps(
            for: event.scrollingDeltaY,
            hasPreciseDeltas: event.hasPreciseScrollingDeltas
        )
        if steps != 0 {
            applyScaleChange(anchor: .center) {
                scaleSettings.adjust(by: steps)
            }
        }

        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            scrollZoomAccumulator.reset()
        }
    }

    // MARK: - Layout

    private func scaleDidChange(_ scale: CGFloat) {
        let anchor = pendingScaleAnchor ?? .center
        pendingScaleAnchor = nil
        layoutContentSynchronously(anchor: anchor, clamp: hasRestoredPosition)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.layoutContentSynchronously(
                anchor: anchor,
                clamp: self.hasRestoredPosition
            )
            if self.hasRestoredPosition {
                self.persistPosition()
            }
        }
    }

    /// Measure the actual scaled SwiftUI layout, then apply that exact size to
    /// the AppKit panel. This is deliberately synchronous; the caller controls
    /// any optional follow-up pass.
    private func layoutContentSynchronously(
        anchor: FloatScaleAnchor? = nil,
        clamp: Bool
    ) {
        guard !isApplyingLayout else { return }
        isApplyingLayout = true
        defer { isApplyingLayout = false }

        let oldFrame = panel.frame

        updateRootForScaleIfNeeded()
        hostingView.invalidateIntrinsicContentSize()
        hostingView.layoutSubtreeIfNeeded()

        measurementHostingView.invalidateIntrinsicContentSize()
        measurementHostingView.layoutSubtreeIfNeeded()
        let measuredBase = validContentSize(measurementHostingView.fittingSize)
            ?? lastBaseContentSize
        guard let measuredBase,
              let scaledSize = FloatPanelGeometry.scaledSize(
                measuredBase,
                by: scaleSettings.scale
              ) else { return }
        lastBaseContentSize = measuredBase

        var newFrame = oldFrame
        newFrame.size = scaledSize
        if let anchor {
            newFrame = FloatPanelGeometry.resized(oldFrame, to: scaledSize, anchor: anchor)
        }
        if clamp, let visible = targetVisibleFrame() {
            newFrame = FloatPanelGeometry.clamped(
                newFrame,
                to: visible,
                margin: FloatPanelGeometry.defaultMargin
            )
        }
        applyFrame(newFrame)

        // HostingView and its independent container use the final physical
        // size. Only the noninteractive timer surface is transformed; the
        // controls above are laid out directly at this scaled size.
        hostingView.frame = contentContainer.bounds
        hostingView.setBoundsSize(contentContainer.bounds.size)
        hostingView.needsLayout = true
        hostingView.layoutSubtreeIfNeeded()
    }

    private func updateRootForScaleIfNeeded() {
        let scale = scaleSettings.scale
        guard scale != presentedScale else { return }
        presentedScale = scale
        hostingView.rootView = ScaledFloatRoot(
            content: rootContent,
            onChange: onChange,
            onHide: onHide,
            alwaysShowControls: alwaysShowControls,
            scale: scale
        )
    }

    private func validContentSize(_ size: CGSize) -> CGSize? {
        guard size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else { return nil }
        return size
    }

    private func applyFrame(_ frame: NSRect) {
        guard frame.width.isFinite, frame.height.isFinite,
              frame.width > 0, frame.height > 0 else { return }
        guard frame != panel.frame else { return }

        isApplyingFrame = true
        panel.setFrame(frame, display: panel.isVisible)
        isApplyingFrame = false
    }

    // MARK: - Position persistence

    private func restoreOrPlace() {
        guard !hasRestoredPosition else {
            clampToVisibleFrame()
            return
        }
        hasRestoredPosition = true

        let defaults = UserDefaults.standard
        if let point = persistedOrigin(in: defaults) {
            // A saved origin wins over the current pointer monitor. The
            // subsequent clamp only intervenes when that origin is no longer
            // on a visible display.
            applyFrame(NSRect(origin: point, size: panel.frame.size))
        } else if let visibleFrame = currentVisibleFrame() {
            // Use the already-fitted size. AppKit Y grows upward, therefore
            // the top-right formula is maxY - height - margin.
            let frame = FloatPanelGeometry.topTrailingFrame(
                contentSize: panel.frame.size,
                in: visibleFrame,
                margin: FloatPanelGeometry.defaultMargin
            )
            var cascadedFrame = frame
            cascadedFrame.origin.x -= initialPlacementOffset
            cascadedFrame.origin.y -= initialPlacementOffset
            applyFrame(cascadedFrame)
        }
        clampToVisibleFrame()
    }

    private func persistedOrigin(in defaults: UserDefaults) -> NSPoint? {
        guard defaults.object(forKey: originXKey) != nil,
              defaults.object(forKey: originYKey) != nil else {
            return nil
        }
        let x = defaults.double(forKey: originXKey)
        let y = defaults.double(forKey: originYKey)
        guard x.isFinite, y.isFinite else { return nil }
        return NSPoint(x: x, y: y)
    }

    private func persistPosition() {
        let origin = panel.frame.origin
        guard origin.x.isFinite, origin.y.isFinite else { return }
        UserDefaults.standard.set(origin.x, forKey: originXKey)
        UserDefaults.standard.set(origin.y, forKey: originYKey)
    }

    private func targetVisibleFrame() -> NSRect? {
        // A persisted origin must win over the current pointer monitor. In a
        // multi-display setup the user can launch the app with the pointer on
        // display A while the saved float lives on display B; choosing the
        // pointer first would unexpectedly teleport the float on every launch.
        let panelFrame = panel.frame
        if let frameScreen = NSScreen.screens.first(where: {
            $0.frame.intersects(panelFrame)
        })?.visibleFrame {
            return frameScreen
        }

        if let panelScreen = panel.screen?.visibleFrame {
            return panelScreen
        }

        return currentVisibleFrame()
    }

    private func currentVisibleFrame() -> NSRect? {
        // The display containing the pointer is the best approximation of the
        // user's "current screen" when the utility is first shown. Main screen
        // and the first available display provide deterministic fallbacks for
        // launch/test contexts where no pointer screen is available.
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame
    }

    private func clampToVisibleFrame() {
        guard let visible = targetVisibleFrame() else { return }
        let clamped = FloatPanelGeometry.clamped(
            panel.frame,
            to: visible,
            margin: FloatPanelGeometry.defaultMargin
        )
        applyFrame(clamped)
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        guard !isApplyingFrame else { return }
        hasRestoredPosition = true
        clampToVisibleFrame()
        persistPosition()
    }

    func windowDidResize(_ notification: Notification) {
        guard !isApplyingFrame else { return }
        clampToVisibleFrame()
        persistPosition()
    }

    func windowDidChangeScreen(_ notification: Notification) {
        guard !isApplyingFrame else { return }
        clampToVisibleFrame()
        persistPosition()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }
}
