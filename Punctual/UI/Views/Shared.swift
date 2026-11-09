//
//  Shared.swift
//  MeetingBar
//
//  Created by Andrii Leitsius on 13.01.2021.
//  Copyright © 2021 Andrii Leitsius. All rights reserved.
//
//  Modified for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import AppKit
import Defaults
import Foundation
import LaunchAtLogin
import Observation
import SwiftUI
import UserNotifications

/// The macOS notification delivery setting, read asynchronously and cached; refreshed on
/// app activation rather than read synchronously during rendering.
@MainActor
@Observable
final class NotificationSettingsMonitor {
    static let shared = NotificationSettingsMonitor()

    /// The resolved delivery mode for the app's notifications.
    private(set) var delivery: NotificationDelivery = .persistent

    private init() {}

    func refresh() async {
        delivery = await Self.currentDelivery()
    }

    /// Reads the settings off the main actor and returns only the resolved value, because
    /// `UNNotificationSettings` is not `Sendable` in every SDK this builds with.
    nonisolated private static func currentDelivery() async -> NotificationDelivery {
        // https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/notificationsettings()
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return NotificationDeliveryPolicy.resolve(
            authorization: NotificationAuthorization(settings.authorizationStatus),
            staysOnscreen: settings.alertStyle == .alert
        )
    }
}

extension NotificationAuthorization {
    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        default:
            // .authorized, .provisional, .ephemeral — macOS will deliver.
            self = .allowed
        }
    }
}
