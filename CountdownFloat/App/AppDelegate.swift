import AppKit
import SwiftUI

/// AppKit coordinator for a menu-bar utility with any number of independent
/// countdowns. Every session owns its store and all three of its panels.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let collection = CountdownCollection()
    private let notificationManager = NotificationManager()
    private var sessions: [UUID: CountdownSession] = [:]
    private var nextSessionSlot = 0

    private var statusItem: NSStatusItem?
    private var statusTimer: Timer?
    private var statusPopover: NSPopover?
    private var statusPopoverHosting: NSViewController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        notificationManager.onAddFive = { [weak self] id in
            Task { @MainActor [weak self] in self?.addFive(to: id) }
        }
        notificationManager.onEnd = { [weak self] id in
            Task { @MainActor [weak self] in self?.sessions[id]?.store.cancel() }
        }
        notificationManager.requestAuthorization()

        configureStatusItem()
        startStatusRefreshTimer()
        updateStatusItem()

        DispatchQueue.main.async { [weak self] in
            self?.createNewCountdown()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusTimer?.invalidate()
        statusTimer = nil
        sessions.values.forEach { $0.store.stopTimer() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if collection.isEmpty {
            createNewCountdown()
        } else {
            collection.stores.forEach { store in
                guard let session = sessions[store.id] else { return }
                store.setFloatHidden(false)
                session.floatController.show()
            }
        }
        return true
    }

    // MARK: - Session lifecycle

    private func createNewCountdown() {
        closeStatusPopover()
        hideEditors()

        nextSessionSlot += 1
        let slot = nextSessionSlot
        let store = CountdownStore()
        let id = store.id
        let keyPrefix = slot == 1 ? "floatPanel" : "floatPanel.\(slot)"
        let scaleSettings = FloatScaleSettings(
            persistenceKey: "\(keyPrefix).scale"
        )

        let floatController = FloatPanelController(
            store: store,
            scaleSettings: scaleSettings,
            positionKeyPrefix: keyPrefix,
            initialPlacementOffset: CGFloat((slot - 1) % 8) * 24,
            onChange: { [weak self] in self?.showEditor(for: id) },
            onHide: { [weak self] in self?.hideFloat(for: id) }
        )
        let completionController = CompletionPanelController(
            store: store,
            onClose: { [weak self] in self?.sessions[id]?.completionController.hide() },
            onEnd: { [weak self] in self?.sessions[id]?.store.cancel() }
        )
        let editorController = SetupPanelController(
            store: store,
            onCancel: { [weak self] in self?.cancelEditor(for: id) },
            onStart: { [weak self] in self?.sessions[id]?.editorController.hide() }
        )
        let session = CountdownSession(
            store: store,
            floatController: floatController,
            completionController: completionController,
            editorController: editorController
        )
        sessions[id] = session

        store.onTransition = { [weak self] transition in
            self?.handle(transition: transition, for: id)
        }
        store.onCompletion = { [weak self] event in
            self?.notificationManager.postCompletion(for: event)
        }

        editorController.show(isEditing: false, beside: nil)
        updateStatusItem()
    }

    private func showEditor(for id: UUID) {
        closeStatusPopover()
        guard let session = sessions[id], collection.contains(id) else { return }
        hideEditors(except: id)

        session.store.setFloatHidden(false)
        session.floatController.show()
        session.editorController.show(
            isEditing: true,
            beside: session.floatController.panel
        )
        updateStatusItem()
    }

    private func cancelEditor(for id: UUID) {
        guard let session = sessions[id] else { return }
        session.editorController.hide()
        if !collection.contains(id) {
            removeSession(id)
        }
    }

    private func removeSession(_ id: UUID) {
        guard let session = sessions[id] else { return }
        session.editorController.hide()
        session.completionController.hide()
        session.floatController.hide()
        session.store.stopTimer()
        collection.remove(id)
        sessions.removeValue(forKey: id)
        updateStatusItem()
    }

    private func hideEditors(except id: UUID? = nil) {
        sessions.forEach { sessionID, session in
            if sessionID != id { session.editorController.hide() }
        }
    }

    private func handle(transition: CountdownTransition, for id: UUID) {
        guard let session = sessions[id] else { return }

        switch transition {
        case .started, .reset:
            collection.add(session.store)
            session.editorController.hide()
            session.completionController.hide()
            session.store.setFloatHidden(false)
            session.floatController.show()
        case .paused, .resumed:
            session.completionController.hide()
            session.floatController.refreshLayout()
        case .extended:
            session.completionController.hide()
            if !session.store.floatHidden { session.floatController.show() }
        case .completed:
            session.completionController.show()
            session.floatController.refreshLayout()
        case .stopped, .cancelled:
            removeSession(id)
        }
        updateStatusItem()
    }

    // MARK: - Menu-bar item

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
            Task { @MainActor [weak self] in self?.updateStatusItem() }
        }
        statusTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        if statusPopover?.isShown == true {
            closeStatusPopover()
        } else {
            showStatusPopover()
        }
    }

    private func showStatusPopover() {
        guard let button = statusItem?.button else { return }
        closeStatusPopover()

        let root = CountdownMenuView(
            collection: collection,
            onAdd: { [weak self] in self?.createNewCountdown() },
            onEdit: { [weak self] id in self?.showEditor(for: id) },
            onToggleVisibility: { [weak self] id in self?.toggleFloat(for: id) },
            onStop: { [weak self] id in self?.sessions[id]?.store.stop() },
            onDismiss: { [weak self] in self?.closeStatusPopover() },
            onQuit: { NSApp.terminate(nil) }
        )
        presentStatusPopover(root, width: 300, relativeTo: button)
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
        popover.contentSize = NSSize(
            width: width,
            height: max(1, hosting.view.fittingSize.height)
        )
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
        let representative = collection.stores.min { lhs, rhs in
            statusSortValue(lhs) < statusSortValue(rhs)
        }
        var value = representative?.displayText ?? "New"
        if collection.count > 1 { value += " +\(collection.count - 1)" }

        let dotAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12.5, weight: .medium),
            .foregroundColor: NSColor.systemPurple
        ]
        let digitAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ]
        let title = NSMutableAttributedString(string: "• ", attributes: dotAttributes)
        title.append(NSAttributedString(string: value, attributes: digitAttributes))
        button.attributedTitle = title
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.toolTip = collection.isEmpty
            ? "Countdown Float — create a countdown"
            : "Countdown Float — \(collection.count) active"
        button.target = self
        button.action = #selector(statusItemClicked(_:))
    }

    private func statusSortValue(_ store: CountdownStore) -> Int64 {
        if store.isCountUp { return Int64.max - 2 }
        switch store.status {
        case .running, .paused:
            return max(0, store.remainingMilliseconds)
        case .done:
            return Int64.max - 1
        case .idle:
            return Int64.max
        }
    }

    // MARK: - Per-session actions

    private func toggleFloat(for id: UUID) {
        guard let session = sessions[id] else { return }
        if session.floatController.panel.isVisible {
            hideFloat(for: id)
        } else {
            session.store.setFloatHidden(false)
            session.floatController.show()
        }
        updateStatusItem()
    }

    private func hideFloat(for id: UUID) {
        guard let session = sessions[id] else { return }
        session.store.setFloatHidden(true)
        session.editorController.hide()
        session.floatController.hide()
        updateStatusItem()
    }

    private func addFive(to id: UUID) {
        guard let session = sessions[id] else { return }
        session.store.addFiveMinutes()
        session.completionController.hide()
        if !session.store.floatHidden { session.floatController.show() }
        updateStatusItem()
    }
}

@MainActor
private final class CountdownSession {
    let store: CountdownStore
    let floatController: FloatPanelController
    let completionController: CompletionPanelController
    let editorController: SetupPanelController

    init(
        store: CountdownStore,
        floatController: FloatPanelController,
        completionController: CompletionPanelController,
        editorController: SetupPanelController
    ) {
        self.store = store
        self.floatController = floatController
        self.completionController = completionController
        self.editorController = editorController
    }
}
