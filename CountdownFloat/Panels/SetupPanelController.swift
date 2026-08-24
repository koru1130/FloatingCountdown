import AppKit
import Combine
import SwiftUI

/// Owns one countdown's editor and positions it beside that countdown's float.
/// A real key-capable panel is used instead of a menu-bar popover so text
/// fields remain editable and each timer can keep its own editor lifecycle.
@MainActor
final class SetupPanelController: NSObject, NSWindowDelegate {
    let store: CountdownStore
    let scaleSettings: FloatScaleSettings
    let panel: CountdownPanel

    private let hostingView: NSHostingView<SetupView>
    private let onCancel: () -> Void
    private let onStart: () -> Void
    private var closesOnFocusLoss = false
    private weak var anchorPanel: NSPanel?
    private var scaleObservation: AnyCancellable?

    init(
        store: CountdownStore,
        scaleSettings: FloatScaleSettings,
        onCancel: @escaping () -> Void,
        onStart: @escaping () -> Void
    ) {
        self.store = store
        self.scaleSettings = scaleSettings
        self.onCancel = onCancel
        self.onStart = onStart

        let root = SetupView(
            store: store,
            scaleSettings: scaleSettings,
            onCancel: onCancel,
            onStart: onStart
        )
        self.hostingView = NSHostingView(rootView: root)
        self.panel = CountdownPanel(
            contentRect: NSRect(x: 0, y: 0, width: 312, height: 440),
            styleMask: [.borderless],
            kind: .editor
        )
        super.init()

        panel.delegate = self
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.contentView = hostingView
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.setAccessibilityTitle("Countdown editor")

        scaleObservation = scaleSettings.$scale
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.panel.isVisible else { return }
                    self.place(beside: self.anchorPanel)
                }
            }
    }

    func show(isEditing: Bool, beside floatPanel: NSPanel?) {
        closesOnFocusLoss = isEditing
        anchorPanel = floatPanel
        hostingView.rootView = SetupView(
            store: store,
            scaleSettings: scaleSettings,
            isEditing: isEditing,
            onCancel: onCancel,
            onStart: onStart
        )
        hostingView.invalidateIntrinsicContentSize()
        hostingView.layoutSubtreeIfNeeded()
        panel.sizeToFitContent(minimumWidth: 312)
        place(beside: floatPanel)

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak panel] in
            panel?.makeKey()
        }
    }

    func hide() {
        closesOnFocusLoss = false
        anchorPanel = nil
        panel.orderOut(nil)
    }

    private func place(beside floatPanel: NSPanel?) {
        let gap: CGFloat = 12
        let pointer = NSEvent.mouseLocation
        let visible = floatPanel?.screen?.visibleFrame
            ?? NSScreen.screens.first(where: { $0.frame.contains(pointer) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame
        guard let visible else { return }

        var frame = panel.frame
        if let anchor = floatPanel, anchor.isVisible {
            let anchorFrame = anchor.frame
            let rightX = anchorFrame.maxX + gap
            frame.origin.x = rightX + frame.width <= visible.maxX
                ? rightX
                : anchorFrame.minX - frame.width - gap
            frame.origin.y = anchorFrame.maxY - frame.height
        } else {
            frame.origin.x = visible.maxX - frame.width - 16
            frame.origin.y = visible.maxY - frame.height - 16
        }

        frame.origin.x = min(max(frame.origin.x, visible.minX + 8), visible.maxX - frame.width - 8)
        frame.origin.y = min(max(frame.origin.y, visible.minY + 8), visible.maxY - frame.height - 8)
        panel.setFrame(frame, display: true)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        closesOnFocusLoss = false
        onCancel()
        return false
    }

    func windowDidResignKey(_ notification: Notification) {
        guard closesOnFocusLoss, panel.isVisible else { return }
        closesOnFocusLoss = false
        onCancel()
    }
}
