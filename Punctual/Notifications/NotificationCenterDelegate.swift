//
//  NotificationCenterDelegate.swift
//  MeetingBar
//

import UserNotifications

/// Owns the `UNUserNotificationCenterDelegate` role and translates callbacks into app response actions.
@MainActor
final class NotificationCenterDelegate: NSObject, @preconcurrency UNUserNotificationCenterDelegate {
    private let actionHandler: (NotificationResponseAction) -> Void

    init(actionHandler: @escaping (NotificationResponseAction) -> Void) {
        self.actionHandler = actionHandler
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Shows notifications even when the app has focus.
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.list, .banner, .badge, .sound])
    }

    func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        // Sparkle "update available" reminder: not a meeting notification.
        if response.notification.request.identifier == SoftwareUpdater.updateNotificationIdentifier {
            SoftwareUpdater.shared.handleUpdateNotificationTapped()
            return
        }

        let content = response.notification.request.content
        guard let action = NotificationResponseAction(
            categoryIdentifier: content.categoryIdentifier,
            actionIdentifier: response.actionIdentifier,
            eventID: content.userInfo["eventID"] as? String,
            defaultActionIdentifier: UNNotificationDefaultActionIdentifier
        ) else {
            return
        }

        actionHandler(action)
    }
}
