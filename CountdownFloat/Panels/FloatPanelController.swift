import AppKit
import Combine
import SwiftUI

/// A small SwiftUI shell that makes the user's scale an actual layout
/// dimension.  `scaleEffect` alone intentionally leaves an
/// `NSHostingView.fittingSize` unchanged, so the controller first measures
/// `baseSize` at the unscaled root and then gives the transformed root a frame
/// of `baseSize * scale`.  That keeps both the panel and its hit area in sync
/// with what is drawn.
private struct ScaledFloatRoot: View {
    let content: FloatView
    let scale: CGFloat
    let baseSize: CGSize?

    var body: some View {
        if let baseSize {
            content
                .scaleEffect(scale, anchor: .center)
                .frame(
                    width: max(1, baseSize.width * scale),
                    height: max(1, baseSize.height * scale),
                    alignment: .center
                )
        } else {
            content
                .scaleEffect(scale, anchor: .center)
        }
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
    private let hostingView: NSHostingView<ScaledFloatRoot>
    private var storeObservation: AnyCancellable?
    private var scaleObservation: AnyCancellable?
    private let onChange: () -> Void
    private let onHide: () -> Void
    private var hasRestoredPosition = false
    private var lastBaseContentSize: CGSize?
    private var pendingScaleAnchor: FloatScaleAnchor?
    private var isApplyingLayout = false
    private var isApplyingFrame = false

    private enum DefaultsKey {
        static let originX = "floatPanel.originX"
        static let originY = "floatPanel.originY"
    }

    init(
        store: CountdownStore,
        scaleSettings: FloatScaleSettings = FloatScaleSettings(),
        onChange: @escaping () -> Void = {},
        onHide: @escaping () -> Void = {}
    ) {
        self.store = store
        self.scaleSettings = scaleSettings
        self.onChange = onChange
        self.onHide = onHide

        let initialRect = NSRect(x: 0, y: 0, width: 116, height: 84)
        let panel = CountdownPanel(
            contentRect: initialRect,
            styleMask: [.borderless, .nonactivatingPanel],
            kind: .float
        )
        self.panel = panel

        let view = FloatView(
            store: store,
            onChange: { [weak panel] in
                // Keeping the closure in the view independent from the
                // controller avoids a retain cycle through NSHostingView.
                _ = panel
                onChange()
            },
            onHide: { [weak panel] in
                _ = panel
                onHide()
            }
        )
        self.rootContent = view
        self.hostingView = NSHostingView(
            rootView: ScaledFloatRoot(
                content: view,
                scale: scaleSettings.scale,
                baseSize: nil
            )
        )

        super.init()

        panel.delegate = self
        // The hosting bounds intentionally include transparent room for the
        // overhanging hover controls. Make that room genuinely transparent
        // instead of inheriting an AppKit backing color.
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView
        panel.isMovableByWindowBackground = true
        panel.acceptsMouseMovedEvents = true
        panel.setAccessibilityTitle("Countdown")

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
        clampToVisibleFrame()
        persistPosition()
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
        pendingScaleAnchor = anchor
        scaleSettings.setScale(value)
    }

    @discardableResult
    func increaseScale(anchor: FloatScaleAnchor = .center) -> CGFloat {
        pendingScaleAnchor = anchor
        return scaleSettings.increase()
    }

    @discardableResult
    func decreaseScale(anchor: FloatScaleAnchor = .center) -> CGFloat {
        pendingScaleAnchor = anchor
        return scaleSettings.decrease()
    }

    func resetScale(anchor: FloatScaleAnchor = .center) {
        pendingScaleAnchor = anchor
        scaleSettings.reset()
    }

    // MARK: - Layout

    private func scaleDidChange(_ scale: CGFloat) {
        let anchor = pendingScaleAnchor ?? .center
        pendingScaleAnchor = nil
        layoutContentSynchronously(anchor: anchor, clamp: hasRestoredPosition)
        if hasRestoredPosition {
            persistPosition()
        }
    }

    /// Measure the unscaled SwiftUI root, then update both the transformed
    /// root frame and the AppKit panel size. This is deliberately synchronous;
    /// the caller controls any optional follow-up pass.
    private func layoutContentSynchronously(
        anchor: FloatScaleAnchor? = nil,
        clamp: Bool
    ) {
        guard !isApplyingLayout else { return }
        isApplyingLayout = true
        defer { isApplyingLayout = false }

        let oldFrame = panel.frame

        // Remove the explicit frame while measuring so fittingSize represents
        // the actual content, not the previous scaled panel dimensions.
        hostingView.rootView = ScaledFloatRoot(
            content: rootContent,
            scale: scaleSettings.scale,
            baseSize: nil
        )
        hostingView.invalidateIntrinsicContentSize()
        hostingView.layoutSubtreeIfNeeded()

        let fitting = hostingView.fittingSize
        let measuredBase = validContentSize(fitting) ?? lastBaseContentSize
        guard let measuredBase,
              let scaledSize = FloatPanelGeometry.scaledSize(
                measuredBase,
                by: scaleSettings.scale
              ) else {
            return
        }
        lastBaseContentSize = measuredBase

        // Give the scaled root a real frame. Besides making the visual size
        // deterministic, this ensures transparent hit area and panel bounds
        // grow with the user's zoom instead of clipping at fittingSize.
        hostingView.rootView = ScaledFloatRoot(
            content: rootContent,
            scale: scaleSettings.scale,
            baseSize: measuredBase
        )
        hostingView.invalidateIntrinsicContentSize()
        hostingView.layoutSubtreeIfNeeded()

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
            applyFrame(frame)
        }
        clampToVisibleFrame()
    }

    private func persistedOrigin(in defaults: UserDefaults) -> NSPoint? {
        guard defaults.object(forKey: DefaultsKey.originX) != nil,
              defaults.object(forKey: DefaultsKey.originY) != nil else {
            return nil
        }
        let x = defaults.double(forKey: DefaultsKey.originX)
        let y = defaults.double(forKey: DefaultsKey.originY)
        guard x.isFinite, y.isFinite else { return nil }
        return NSPoint(x: x, y: y)
    }

    private func persistPosition() {
        let origin = panel.frame.origin
        guard origin.x.isFinite, origin.y.isFinite else { return }
        UserDefaults.standard.set(origin.x, forKey: DefaultsKey.originX)
        UserDefaults.standard.set(origin.y, forKey: DefaultsKey.originY)
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
