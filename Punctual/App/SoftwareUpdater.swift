//
//  SoftwareUpdater.swift
//  Punctual
//
//  Sparkle-based update checking and installation. Feed, EdDSA key, signed-feed and
//  installer settings live in Info.plist; this class owns the updater's lifetime and
//  exposes what the UI needs.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import AppKit
import Combine
import Defaults
import Sparkle
import UserNotifications

/// Decides who shows a scheduled update: Sparkle's window or a notification.
enum UpdateReminderPolicy {
    /// Sparkle shows its window when Punctual is already in focus, or when notifications
    /// can't be shown; otherwise a notification announces the update.
    static func sparkleShowsScheduledUpdate(immediateFocus: Bool, notificationsAuthorized: Bool) -> Bool {
        immediateFocus || !notificationsAuthorized
    }
}

@MainActor
final class SoftwareUpdater: NSObject, ObservableObject {
    static let shared = SoftwareUpdater()

    /// Identifier of the "update available" notification, so a tap on it can
    /// be routed here rather than to the meeting-notification handlers.
    nonisolated static let updateNotificationIdentifier = "punctual.software-update-available"

    /// False while a check is already running, so "Check for Updates…" can be
    /// disabled instead of queueing a second one.
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var lastUpdateCheckDate: Date?
    @Published private(set) var automaticallyChecksForUpdates = false
    @Published private(set) var automaticallyDownloadsUpdates = false

    private var controller: SPUStandardUpdaterController?
    private var cancellables: Set<AnyCancellable> = []

    /// Whether alert notifications can be shown. Refreshed before each scheduled check
    /// and read synchronously by the Sparkle delegate.
    private var notificationsAuthorized = false

    private func refreshNotificationAuthorization() {
        Task { @MainActor in
            notificationsAuthorized = await Self.notificationsCanAlert()
        }
    }

    /// Returns only a Bool because `UNNotificationSettings` isn't `Sendable` in every SDK.
    nonisolated private static func notificationsCanAlert() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let allowed = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
        return allowed && settings.alertStyle != .none
    }

    /// Debug builds check for updates only with `PUNCTUAL_ENABLE_UPDATER=1`, so a
    /// development build is never replaced by the release.
    static var isEnabledInThisBuild: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["PUNCTUAL_ENABLE_UPDATER"] == "1"
        #else
        return true
        #endif
    }

    /// Starts the updater once per launch; never in a test host.
    func start() {
        guard controller == nil,
              Self.isEnabledInThisBuild,
              !AppMessageCenter.shouldSuppressSystemUI() else { return }
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: self
        )
        self.controller = controller
        refreshNotificationAuthorization()
        let updater = controller.updater
        bind(updater.publisher(for: \.canCheckForUpdates), to: \.canCheckForUpdates)
        bind(updater.publisher(for: \.automaticallyChecksForUpdates), to: \.automaticallyChecksForUpdates)
        bind(updater.publisher(for: \.automaticallyDownloadsUpdates), to: \.automaticallyDownloadsUpdates)
        updater.publisher(for: \.lastUpdateCheckDate)
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.lastUpdateCheckDate = $0 }
            .store(in: &cancellables)
    }

    private func bind(
        _ publisher: some Publisher<Bool, Never>,
        to keyPath: ReferenceWritableKeyPath<SoftwareUpdater, Bool>
    ) {
        publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?[keyPath: keyPath] = $0 }
            .store(in: &cancellables)
    }

    /// User-initiated check. Activates the accessory app first so Sparkle's window does
    /// not open behind other apps.
    func checkForUpdates() {
        guard let controller else { return }
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }

    func setAutomaticallyChecksForUpdates(_ value: Bool) {
        controller?.updater.automaticallyChecksForUpdates = value
    }

    func setAutomaticallyDownloadsUpdates(_ value: Bool) {
        controller?.updater.automaticallyDownloadsUpdates = value
    }

    /// Whether the updater is running at all (false in tests, in Debug builds
    /// that did not opt in, and before launch finishes).
    var isAvailable: Bool { controller != nil }

    /// Tap on the "update available" notification: bring the update forward.
    func handleUpdateNotificationTapped() {
        checkForUpdates()
    }

    private func postUpdateAvailableNotification(version: String) {
        let content = UNMutableNotificationContent()
        content.title = "software_update_available_title".loco()
        content.body = "software_update_available_body".loco(version)
        let request = UNNotificationRequest(
            identifier: Self.updateNotificationIdentifier,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                PunctualLogger.lifecycle.error(
                    "Update-available notification failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private func clearUpdateAvailableNotification() {
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [Self.updateNotificationIdentifier])
        center.removePendingNotificationRequests(withIdentifiers: [Self.updateNotificationIdentifier])
    }
}

extension SoftwareUpdater: SPUUpdaterDelegate {
    /// Replaces Sparkle's second-launch rule: asks whether to check automatically only
    /// once first-run setup is finished.
    nonisolated func updaterShouldPromptForPermissionToCheck(forUpdates _: SPUUpdater) -> Bool {
        MainActor.assumeIsolated { Defaults[.onboardingCompleted] }
    }

    /// Keep the notification-permission answer fresh for the next check.
    nonisolated func updater(_: SPUUpdater, willScheduleUpdateCheckAfterDelay _: TimeInterval) {
        MainActor.assumeIsolated { refreshNotificationAuthorization() }
    }
}

extension SoftwareUpdater: SPUStandardUserDriverDelegate {
    /// A scheduled check never pulls Punctual in front of a call or screen share.
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    /// See `UpdateReminderPolicy`.
    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(
        _: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        MainActor.assumeIsolated {
            UpdateReminderPolicy.sparkleShowsScheduledUpdate(
                immediateFocus: immediateFocus,
                notificationsAuthorized: notificationsAuthorized
            )
        }
    }

    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard !handleShowingUpdate, !state.userInitiated else { return }
        let version = update.displayVersionString
        MainActor.assumeIsolated {
            postUpdateAvailableNotification(version: version)
        }
    }

    /// The user has seen the update, so the reminder notification is removed.
    nonisolated func standardUserDriverDidReceiveUserAttention(forUpdate _: SUAppcastItem) {
        MainActor.assumeIsolated { clearUpdateAvailableNotification() }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        MainActor.assumeIsolated { clearUpdateAvailableNotification() }
    }
}
