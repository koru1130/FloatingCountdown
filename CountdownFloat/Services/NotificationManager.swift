import Foundation
import UserNotifications

/// Owns the small amount of UserNotifications plumbing needed by the app.
///
/// Keeping this separate from ``AppDelegate`` makes the completion flow easy to
/// exercise without having to construct any of the AppKit panels.  Actions are
/// delivered back through closures; the delegate never reaches into the store
/// directly.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let categoryIdentifier = "COUNTDOWN_COMPLETION"
    static let addFiveActionIdentifier = "COUNTDOWN_ADD_FIVE"
    static let endActionIdentifier = "COUNTDOWN_END"

    private let center: UNUserNotificationCenter

    var onAddFive: ((UUID) -> Void)?
    var onEnd: ((UUID) -> Void)?

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        center.delegate = self
        registerActions()
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func postCompletion(for event: CountdownCompletionEvent) {
        let content = UNMutableNotificationContent()
        let trimmedLabel = event.label.trimmingCharacters(in: .whitespacesAndNewlines)
        content.title = "\(trimmedLabel.isEmpty ? "Countdown" : trimmedLabel) — time's up"
        content.body = "The float keeps counting up until you end or extend it."
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        content.threadIdentifier = event.countdownID.uuidString
        content.userInfo = ["countdownID": event.countdownID.uuidString]

        let request = UNNotificationRequest(
            identifier: event.id.uuidString,
            content: content,
            trigger: nil
        )
        center.add(request) { _ in }
    }

    func removePendingAndDeliveredNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Keep completion visible even when the float app is frontmost.
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let countdownID = (response.notification.request.content.userInfo["countdownID"] as? String)
            .flatMap(UUID.init(uuidString:))
        switch (response.actionIdentifier, countdownID) {
        case (Self.addFiveActionIdentifier, let id?):
            onAddFive?(id)
        case (Self.endActionIdentifier, let id?):
            onEnd?(id)
        default:
            break
        }
        completionHandler()
    }

    private func registerActions() {
        let addFive = UNNotificationAction(
            identifier: Self.addFiveActionIdentifier,
            title: "Add 5 min",
            options: []
        )
        let end = UNNotificationAction(
            identifier: Self.endActionIdentifier,
            title: "End",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [addFive, end],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }
}
