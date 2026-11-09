//
//  AlertsPresentation.swift
//  Punctual
//
//  Hostless mapping from notification permission state to what the Alerts pane
//  shows. The app maps `UNAuthorizationStatus` / `UNAlertStyle` onto these cases
//  in `UI/Views/Shared.swift`.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Foundation

/// Whether macOS has been asked, and what it said.
enum NotificationAuthorization: String, CaseIterable, Sendable {
    /// macOS has not been asked yet, so nothing is delivered.
    case notDetermined
    /// Switched off in System Settings.
    case denied
    /// Allowed to deliver.
    case allowed
}

/// How notifications actually reach the user.
enum NotificationDelivery: String, CaseIterable, Sendable {
    /// Nothing arrives.
    case blocked
    /// Banners: they arrive, then vanish on their own.
    case disappearing
    /// Alerts: they stay onscreen until dismissed.
    case persistent

    /// Localization key of the advisory line, or `nil` when delivery needs no comment.
    var messageKey: String? {
        switch self {
        case .blocked: "preferences_alerts_disabled_tip"
        case .disappearing: "preferences_alerts_banner_style_tip"
        case .persistent: nil
        }
    }

    /// Whether this is a failure (nothing arrives) rather than advice.
    var isProblem: Bool { self == .blocked }

    /// Whether to show the "Open notification settings" button; true whenever there is a message.
    var offersSettingsButton: Bool { messageKey != nil }

    /// Localization key of the "Open notification settings" button.
    static let settingsButtonKey = "preferences_alerts_open_notification_settings"
}

enum NotificationDeliveryPolicy {
    /// Resolves what the user actually receives.
    ///
    /// - Parameters:
    ///   - authorization: The notification authorization state.
    ///   - staysOnscreen: Whether the style is Alerts rather than Banners.
    /// - Returns: `.blocked` unless authorized; otherwise `.persistent` or `.disappearing`.
    static func resolve(
        authorization: NotificationAuthorization,
        staysOnscreen: Bool
    ) -> NotificationDelivery {
        switch authorization {
        // Not determined counts as blocked: nothing is delivered until the user is asked.
        case .notDetermined, .denied:
            .blocked
        case .allowed:
            staysOnscreen ? .persistent : .disappearing
        }
    }
}
