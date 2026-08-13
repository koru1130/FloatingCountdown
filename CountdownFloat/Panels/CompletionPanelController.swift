import AppKit
import Combine
import SwiftUI

/// Displays the non-activating completion toast at the upper-right of the
/// current visible screen.  The toast has no effect on countdown state when it
/// is ordered out; its actions are owned by `CompletionToastView`/the store.
@MainActor
final class CompletionPanelController: NSObject, NSWindowDelegate {
    let store: CountdownStore
    let panel: CountdownPanel

    private let hostingView: NSHostingView<CompletionToastView>
    private var storeObservation: AnyCancellable?
    private let onClose: () -> Void
    private let onEnd: () -> Void

    init(
        store: CountdownStore,
        onClose: @escaping () -> Void = {},
        onEnd: @escaping () -> Void = {}
    ) {
        self.store = store
        self.onClose = onClose
        self.onEnd = onEnd

        let panel = CountdownPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 144),
            styleMask: [.borderless, .nonactivatingPanel],
            kind: .completion
        )
        self.panel = panel

        let view = CompletionToastView(
            store: store,
            onClose: { [weak panel] in
                _ = panel
                onClose()
            },
            onEnd: { [weak panel] in
                _ = panel
                onEnd()
            }
        )
        self.hostingView = NSHostingView(rootView: view)

        super.init()

        panel.delegate = self
        // Keep NSVisualEffectView in the Claude Design's dark HUD treatment
        // regardless of the user's desktop/system appearance.
        panel.appearance = NSAppearance(named: .darkAqua)
        hostingView.appearance = NSAppearance(named: .darkAqua)
        panel.contentView = hostingView
        panel.isMovableByWindowBackground = false
        panel.setAccessibilityTitle("Countdown complete")

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
        fitContentAndPlace()
        panel.orderFrontRegardless()
        panel.invalidateShadow()

        // SwiftUI may publish the completed label after the transition that
        // opens this panel. Measure once more on the next run-loop turn so a
        // two-line title/body never retains the initial placeholder height.
        refreshLayout()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func refreshLayout() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.fitContentAndPlace()
        }
    }

    private func fitContentAndPlace() {
        hostingView.invalidateIntrinsicContentSize()
        panel.sizeToFitContent(minimumWidth: 300)
        placeTopRight()
        panel.invalidateShadow()
    }

    private func placeTopRight() {
        // A hidden toast should appear on the monitor where the user invoked
        // it, not on the stale screen remembered by NSPanel from a previous
        // presentation.  While visible, retain its current monitor.
        let visible = panel.isVisible
            ? (panel.screen?.visibleFrame ?? visibleFrameForPointerOrMain())
            : visibleFrameForPointerOrMain()
        guard let visible = visible ?? NSScreen.screens.first?.visibleFrame else { return }

        let margin: CGFloat = 16
        var frame = panel.frame
        frame.origin.x = visible.maxX - frame.width - margin
        frame.origin.y = visible.maxY - frame.height - margin
        panel.setFrame(frame, display: true)
    }

    private func visibleFrameForPointerOrMain() -> NSRect? {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(pointer) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        onClose()
        hide()
        return false
    }
}
