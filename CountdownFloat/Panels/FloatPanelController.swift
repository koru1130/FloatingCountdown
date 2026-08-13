import AppKit
import Combine
import SwiftUI

/// Owns the always-on-top countdown float.  Hiding the panel only calls
/// `orderOut`; the store (and therefore its timer) is intentionally untouched.
@MainActor
final class FloatPanelController: NSObject, NSWindowDelegate {
    let store: CountdownStore
    let panel: CountdownPanel

    private let hostingView: NSHostingView<FloatView>
    private var storeObservation: AnyCancellable?
    private let onChange: () -> Void
    private let onHide: () -> Void
    private var hasRestoredPosition = false

    private enum DefaultsKey {
        static let originX = "floatPanel.originX"
        static let originY = "floatPanel.originY"
    }

    init(
        store: CountdownStore,
        onChange: @escaping () -> Void = {},
        onHide: @escaping () -> Void = {}
    ) {
        self.store = store
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
        self.hostingView = NSHostingView(rootView: view)

        super.init()

        panel.delegate = self
        // The hosting bounds intentionally include transparent room for the
        // overhanging hover controls.  Make that room genuinely transparent
        // instead of inheriting an AppKit backing color.
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView
        panel.isMovableByWindowBackground = true
        panel.acceptsMouseMovedEvents = true
        panel.setAccessibilityTitle("Countdown")

        // SwiftUI state changes can alter Bar/Ring intrinsic dimensions (and
        // urgent/completed overlays can change the requested size).  Refit on
        // every published update, without relying on a fixed frame.
        storeObservation = store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshLayout()
            }
    }

    deinit {
        storeObservation?.cancel()
    }

    func show() {
        refreshLayout()
        restoreOrPlace()
        panel.orderFrontRegardless()
    }

    func hide() {
        // Do not pause/cancel the store here.  The menu-bar status and
        // completion notification must continue while the float is hidden.
        persistPosition()
        panel.orderOut(nil)
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    /// Publicly callable by AppDelegate after a mode/state change.
    func refreshLayout() {
        // `NSHostingView` updates its intrinsic size during the next run-loop
        // turn.  Dispatching prevents us from measuring the previous root
        // view while handling an objectWillChange notification.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.hostingView.invalidateIntrinsicContentSize()
            self.panel.sizeToFitContent()
            self.clampToVisibleFrame()
        }
    }

    // MARK: - Position persistence

    private func restoreOrPlace() {
        guard !hasRestoredPosition else {
            clampToVisibleFrame()
            return
        }
        hasRestoredPosition = true

        let defaults = UserDefaults.standard
        if defaults.object(forKey: DefaultsKey.originX) != nil,
           defaults.object(forKey: DefaultsKey.originY) != nil {
            let point = NSPoint(
                x: defaults.double(forKey: DefaultsKey.originX),
                y: defaults.double(forKey: DefaultsKey.originY)
            )
            panel.setFrameOrigin(point)
        } else if let visibleFrame = targetVisibleFrame() {
            let frame = panel.frame
            let origin = NSPoint(
                x: visibleFrame.maxX - frame.width - 28,
                y: visibleFrame.maxY - frame.height - 28
            )
            panel.setFrameOrigin(origin)
        }
        clampToVisibleFrame()
    }

    private func persistPosition() {
        let origin = panel.frame.origin
        UserDefaults.standard.set(origin.x, forKey: DefaultsKey.originX)
        UserDefaults.standard.set(origin.y, forKey: DefaultsKey.originY)
    }

    private func targetVisibleFrame() -> NSRect? {
        // A persisted origin must win over the current pointer monitor.  In a
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

        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame
    }

    private func clampToVisibleFrame() {
        guard let visible = targetVisibleFrame() else { return }
        var frame = panel.frame
        let margin: CGFloat = 8
        let minX = visible.minX + margin
        let maxX = max(minX, visible.maxX - frame.width - margin)
        let minY = visible.minY + margin
        let maxY = max(minY, visible.maxY - frame.height - margin)
        frame.origin.x = min(max(frame.origin.x, minX), maxX)
        frame.origin.y = min(max(frame.origin.y, minY), maxY)
        if frame.origin != panel.frame.origin {
            panel.setFrameOrigin(frame.origin)
        }
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        persistPosition()
        clampToVisibleFrame()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }
}
