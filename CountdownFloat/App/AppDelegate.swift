import AppKit
import SwiftUI

/// AppKit coordinator for the menu-bar utility.
///
/// There is one store for the entire process.  The float, setup popover, toast,
/// status item and notification actions all call into that same instance, so
/// hiding a window never pauses or otherwise forks the countdown.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let store = CountdownStore()
    private let notificationManager = NotificationManager()

    private var floatController: FloatPanelController!
    private var completionController: CompletionPanelController!

    private var statusItem: NSStatusItem?
    private var statusTimer: Timer?
    private var statusPopover: NSPopover?
    private var statusPopoverHosting: NSViewController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        floatController = FloatPanelController(
            store: store,
            onChange: { [weak self] in self?.showSetup() },
            onHide: { [weak self] in self?.hideFloat() }
        )
        completionController = CompletionPanelController(
            store: store,
            onClose: { [weak self] in self?.completionController.hide() },
            onEnd: { [weak self] in self?.endFromCompletion() }
        )

        store.onTransition = { [weak self] transition in
            self?.handle(transition: transition)
        }
        store.onCompletion = { [weak self] event in
            self?.notificationManager.postCompletion(for: event)
        }

        notificationManager.onAddFive = { [weak self] in
            Task { @MainActor [weak self] in
                self?.addFiveFromCompletion()
            }
        }
        notificationManager.onEnd = { [weak self] in
            Task { @MainActor [weak self] in
                self?.endFromCompletion()
            }
        }
        notificationManager.requestAuthorization()

        configureStatusItem()
        startStatusRefreshTimer()
        updateStatusItem()

        // Wait one run-loop turn so the variable-width status item has its
        // final frame before the first popover anchors to it.
        DispatchQueue.main.async { [weak self] in
            self?.showSetup()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusTimer?.invalidate()
        statusTimer = nil
        store.stopTimer()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if store.hasCountdown {
            showFloat()
        } else {
            showSetup()
        }
        return true
    }

    // MARK: Status item

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            button.imagePosition = .imageLeading
            button.toolTip = "Countdown Float"
        }
    }

    private func startStatusRefreshTimer() {
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateStatusItem()
            }
        }
        statusTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        if statusPopover?.isShown == true {
            closeStatusPopover()
            return
        }
        if store.hasCountdown {
            showStatusPopover()
        } else {
            showSetup()
        }
    }

    private func showStatusPopover() {
        guard let button = statusItem?.button else { return }
        closeStatusPopover()

        let hidden = store.floatHidden || !(floatController?.panel.isVisible ?? false)
        let root = CountdownMenuView(
            store: store,
            isFloatHidden: hidden,
            onShowFloat: { [weak self] in
                self?.showFloat()
            },
            onHideFloat: { [weak self] in
                self?.hideFloat()
            },
            onChange: { [weak self] in
                self?.showSetup()
            },
            onReset: { [weak self] in
                self?.store.reset()
            },
            onDismiss: { [weak self] in
                self?.closeStatusPopover()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        presentStatusPopover(root, width: 232, relativeTo: button)
    }

    private func presentSetupPopover() {
        guard let button = statusItem?.button else { return }

        let root = SetupView(store: store)
        presentStatusPopover(root, width: 312, relativeTo: button)
    }

    private func presentStatusPopover<Content: View>(
        _ root: Content,
        width: CGFloat,
        relativeTo button: NSStatusBarButton
    ) {
        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = [.preferredContentSize]
        hosting.view.appearance = NSAppearance(named: .darkAqua)
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = hosting
        hosting.view.layoutSubtreeIfNeeded()
        let fittingHeight = max(1, hosting.view.fittingSize.height)
        popover.contentSize = NSSize(width: width, height: fittingHeight)
        statusPopoverHosting = hosting
        statusPopover = popover
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        button.highlight(true)
    }

    private func closeStatusPopover() {
        statusPopover?.performClose(nil)
        statusPopover = nil
        statusPopoverHosting = nil
        statusItem?.button?.highlight(false)
    }

    func popoverDidClose(_ notification: Notification) {
        guard let closedPopover = notification.object as? NSPopover,
              closedPopover === statusPopover else { return }
        statusPopover = nil
        statusPopoverHosting = nil
        statusItem?.button?.highlight(false)
    }

    private func updateStatusItem() {
        guard let item = statusItem, let button = item.button else { return }
        let value = store.hasCountdown ? store.displayText : "Set"
        // Menu bars may be light, dark, tinted or transparent depending on
        // wallpaper.  Use the system's adaptive label colour for the digits;
        // the previous fixed pale lavender disappeared on light menu bars.
        let dotColor = NSColor.systemPurple
        let digitColor = NSColor.labelColor
        let dotAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12.5, weight: .medium),
            .foregroundColor: dotColor
        ]
        let digitAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .regular),
            .foregroundColor: digitColor
        ]
        let attributedTitle = NSMutableAttributedString(string: "• ", attributes: dotAttributes)
        attributedTitle.append(NSAttributedString(string: value, attributes: digitAttributes))
        button.attributedTitle = attributedTitle
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.toolTip = store.hasCountdown
            ? "Countdown Float — \(store.displayText)"
            : "Countdown Float — Set a countdown"
        button.target = self
        button.action = #selector(statusItemClicked(_:))
    }

    // MARK: Panel coordination

    private func handle(transition: CountdownTransition) {
        switch transition {
        case .started:
            completionController.hide()
            showFloatAndHideSetup()
        case .paused, .resumed:
            completionController.hide()
            floatController.refreshLayout()
        case .extended:
            completionController.hide()
            if !store.floatHidden { showFloat() }
        case .completed:
            completionController.show()
            floatController.refreshLayout()
        case .stopped:
            completionController.hide()
            // Stopping from the countdown menu clears the model and hides the
            // float, but deliberately leaves the setup popover closed.  The
            // status item can still be clicked later to configure a new one.
            hideFloat()
        case .cancelled, .reset:
            completionController.hide()
            floatController.hide()
            store.setFloatHidden(false)
            showSetup()
        }
        updateStatusItem()
    }

    private func showSetup() {
        closeStatusPopover()
        completionController.hide()
        presentSetupPopover()
    }

    private func hideSetup() {
        closeStatusPopover()
    }

    private func showFloatAndHideSetup() {
        hideSetup()
        showFloat()
    }

    private func showFloat() {
        guard store.hasCountdown else {
            showSetup()
            return
        }
        store.setFloatHidden(false)
        floatController.show()
        updateStatusItem()
    }

    private func hideFloat() {
        store.setFloatHidden(true)
        floatController.hide()
        updateStatusItem()
    }

    private func addFiveFromCompletion() {
        store.addFiveMinutes()
        completionController.hide()
        if !store.floatHidden { showFloat() }
        updateStatusItem()
    }

    private func endFromCompletion() {
        store.cancel()
        completionController.hide()
        updateStatusItem()
    }
}
