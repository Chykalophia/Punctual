//
//  AppDelegate.swift
//  MeetingBar
//
//  Created by Andrii Leitsius on 24.04.2020.
//  Copyright © 2020 Andrii Leitsius. All rights reserved.
//
//  Modified for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import AppKit
import Combine
import Defaults
import KeyboardShortcuts
import UserNotifications

@MainActor
@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: StatusBarItemController!
    var calendarSync: CalendarSync!
    /// Separate EventKit store, so Reminders permission is requested independently and only on opt-in.
    let remindersStore = RemindersStore.shared
    private var remindersSync: RemindersSync!
    let notificationScheduler = NotificationScheduler()
    let snoozeService = SnoozeService()
    private var notificationCenterDelegate: NotificationCenterDelegate?
    private var notificationActionHandler: NotificationActionHandler?
    private(set) var appModel: AppModel?
    private let lifecycleObserver = LifecycleObserver()
    private let urlHandler = URLHandler()
    private let windowCoordinator = WindowCoordinator()

    private var launchTask: Task<Void, Never>?
    private var notificationSetupTask: Task<Void, Never>?
    private var statusLoopTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_: Notification) {
        // Skip the launch flow when running as a test host.
        guard !AppMessageCenter.shouldSuppressSystemUI() else { return }

        MeetingOpenPreferencesMigration.migrateDefaultsIfNeeded()
        StatusBarTitleFormatMigration.migrateDefaultsIfNeeded()
        TimeFormatDefaultMigration.migrateDefaultsIfNeeded()
        ChangelogResetMigration.migrateDefaultsIfNeeded()
        MenuBarTimeFormatDefaultsMigration.migrateDefaultsIfNeeded()
        DropdownModuleMergeMigration.migrateDefaultsIfNeeded()

        SoftwareUpdater.shared.start()

        NotificationCenter.default.addObserver(
            self, selector: #selector(AppDelegate.windowClosed),
            name: NSWindow.willCloseNotification, object: nil
        )

        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            Defaults[.appVersion] = appVersion
        }

        statusBarItem = StatusBarItemController()
        // Highlight the status item while the panel is open; macOS 27 no longer does this
        // for an app that shows its own window.
        windowCoordinator.onDropdownPanelVisibilityChange = { [weak self] isOpen in
            self?.statusBarItem?.setStatusItemHighlighted(isOpen)
        }

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(AppDelegate.handleURLEvent(getURLEvent:replyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        launchTask = Task { [weak self] in
            guard let self else { return }
            let manager = await CalendarSync()
            guard !Task.isCancelled else {
                manager.stop()
                return
            }
            calendarSync = manager
            if Defaults[.onboardingCompleted] {
                setup()
            } else {
                setup(triggerInitialRefresh: false)
                presentOnboardingWindow()
            }
            launchTask = nil
        }
    }

    /// Opens the first-run setup window from the cold-launch path when setup is
    /// incomplete.
    func presentOnboardingWindow() {
        guard let appModel else { return }
        // Logged once per launch with setup unfinished, so relaunches mid-setup are visible.
        PunctualLogger.onboarding.info("Presenting setup (launch with setup unfinished)")
        windowCoordinator.openOnboardingWindow(
            appModel: appModel,
            onProviderSelected: { [weak appModel] provider in
                guard let appModel else {
                    return .failed("Application state is unavailable")
                }
                return await appModel.selectSoleProvider(provider)
            },
            onComplete: { [weak appModel] provider in
                guard let appModel else {
                    return .failed("Application state is unavailable")
                }
                let result = await appModel.completeOnboarding(with: provider)
                if result == .success {
                    appModel.handleLaunch()
                }
                return result
            }
        )
    }

    func setup(triggerInitialRefresh: Bool = true) {
        guard appModel == nil else { return }
        let sync = RemindersSync(store: remindersStore)
        remindersSync = sync
        let env = AppEnvironment.live(
            calendarSync: calendarSync,
            remindersSync: sync,
            remindersStore: remindersStore,
            notificationScheduler: notificationScheduler,
            snoozeService: snoozeService,
            openPreferences: { [weak self] in
                self?.openPreferencesWindow(nil)
            },
            openDropdown: { [weak self] in
                guard let self else { return }
                // Idempotent: `toggleDropdownPanel` would close an already-open panel.
                guard !self.windowCoordinator.isDropdownPanelOpen else { return }
                self.statusBarItem?.toggleDropdownPanel()
            },
            resumeOAuthFlow: { [weak self] url in
                guard let calendarSync = self?.calendarSync else { return }
                calendarSync.repository.resumeAuthorizationFlow(with: url)
            }
        )
        let model = AppModel(environment: env)
        appModel = model
        AppRuntimeBridge.shared.install(appModel: model)

        let actionHandler = NotificationActionHandler(
            isScreenLocked: { [weak model] in model?.state.screenIsLocked ?? false },
            send: { [weak model] action in model?.send(action) },
            showFullscreen: { [weak self] event in
                self?.windowCoordinator.openFullscreenNotificationWindow(event: event)
            },
            runEventStartScript: { event in
                runMeetingStartsScript(event: event, type: .meetingStart)
            }
        )
        notificationActionHandler = actionHandler
        notificationScheduler.setActionSink(actionHandler)

        var statusBarDependencies = StatusBarDependencies(
            appState: { [weak model] in model?.state ?? AppState() },
            events: { [weak model] in model?.state.events ?? [] },
            send: { [weak model] action in model?.send(action) },
            openPreferences: { [weak self] in self?.openPreferencesWindow(nil) },
            openChangelog: { [weak self] in self?.openChangelogWindow(nil) },
            openCommandBar: { [weak self] in self?.openCommandBarWindow() },
            openDropdownPanel: { [weak self] state, handlers, anchor in
                self?.windowCoordinator.openDropdownPanel(
                    state: state,
                    handlers: handlers,
                    relativeTo: anchor
                )
            },
            openCalendar: { [weak self] in self?.openCalendarWindow() },
            openWorldClock: { [weak self] in self?.openWorldClockWindow() },
            openCameraPreview: { [weak self] event in self?.openCameraPreviewWindow(event: event) },
            newEvent: { [weak self] in self?.openNewEventWindow() },
            fetchEvents: dateRangeEventFetch(),
            editEvent: { [weak self] event in self?.openEditEventWindow(event) },
            deleteEvent: { [weak self] event, span in self?.deleteEvent(event, span: span) },
            quit: { [weak self] in self?.quit(nil) }
        )
        #if DEBUG
        statusBarDependencies.openDebugHarness = { [weak self] in self?.toggleDebugHarnessWindow() }
        #endif
        statusBarItem.configure(dependencies: statusBarDependencies)

        model.$state
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.statusBarItem.updateTitle()
            }
            .store(in: &cancellables)

        let ncDelegate = NotificationCenterDelegate { [weak model] response in
            model?.send(.notificationResponse(response))
        }
        notificationCenterDelegate = ncDelegate
        UNUserNotificationCenter.current().delegate = ncDelegate
        notificationSetupTask = Task { @MainActor [weak self] in
            await ensureNotificationAuthorization()
            guard !Task.isCancelled else { return }
            registerNotificationCategories()
            self?.notificationSetupTask = nil
        }

        startAsyncLoops()
        if Defaults[.browsers].isEmpty {
            addInstalledBrowser()
        }

        lifecycleObserver.onScreenLocked = { [weak self] in
            self?.appModel?.handleScreenLock()
        }
        lifecycleObserver.onScreenUnlocked = { [weak self] in
            self?.appModel?.handleScreenUnlock()
        }
        lifecycleObserver.onDidWake = { [weak self] in
            self?.appModel?.handleWake()
        }
        lifecycleObserver.onSystemClockChanged = { [weak self] in
            self?.handleSystemClockChange()
        }
        lifecycleObserver.onTimezoneChanged = { [weak self] in
            self?.handleTimezoneChange()
        }
        lifecycleObserver.onDayChanged = { [weak self] in
            self?.appModel?.handleDayChange()
        }
        lifecycleObserver.start()

        if triggerInitialRefresh {
            model.handleLaunch()
            requestCalendarAccessIfNeeded(model: model)
            // Never prompts here: the Reminders permission prompt comes only from the Preferences toggle.
            if Defaults[.showRemindersInMenu], remindersStore.isAccessGranted {
                sync.refreshSubject.send()
            }
        }
    }

    /// Requests EventKit access on a normal launch when macOS Calendar is active and
    /// authorization is `.notDetermined`, so the app prompts and registers with TCC.
    /// Routed through `.changeProvider` so the resulting fetch and state wiring run.
    private func requestCalendarAccessIfNeeded(model: AppModel) {
        guard model.state.activeProvider == .macOSEventKit,
              PermissionReporter.calendarAuthorizationStatus() == .notDetermined else {
            return
        }
        PunctualLogger.calendar.info(
            "Requesting EventKit calendar access on launch (authorization not determined)"
        )
        model.send(.changeProvider(model.state.activeProvider, signOut: false))
    }

    /*
     * -----------------------
     * MARK: - Scheduled tasks
     * ------------------------
     */
    private func startAsyncLoops() {
        statusLoopTask?.cancel()

        // Redraw the status bar title at each minute boundary.
        statusLoopTask = Task(priority: .utility) { [weak self] in
            while let self, !Task.isCancelled {
                let now = Date()
                let calendar = Calendar.current
                let nextMinute = calendar.nextDate(
                    after: now,
                    matching: DateComponents(second: 0),
                    matchingPolicy: .nextTime
                )!

                let interval = nextMinute.timeIntervalSince(now)
                do {
                    try await Task.sleep(
                        nanoseconds: UInt64(max(interval, 0) * Double(NSEC_PER_SEC))
                    )
                } catch {
                    return
                }

                await MainActor.run {
                    self.statusBarItem.updateTitle()
                }
            }
        }
    }

    private func handleSystemClockChange() {
        appModel?.handleSystemClockChange()
        startAsyncLoops()
    }

    private func handleTimezoneChange() {
        appModel?.handleTimezoneChange()
        startAsyncLoops()
    }

    /*
     * -----------------------
     * MARK: - Windows
     * ------------------------
     */

    @objc
    func openChangelogWindow(_: NSStatusBarButton?) {
        windowCoordinator.openChangelogWindow()
    }

    @objc
    func openPreferencesWindow(_: NSStatusBarButton?) {
        windowCoordinator.openPreferencesWindow(
            appModel: appModel,
            calendarSync: calendarSync
        )
    }

    func openCommandBarWindow() {
        let model = appModel
        windowCoordinator.openCommandBarWindow(
            handlers: CommandBarHandlers(
                events: { [weak model] in model?.state.events ?? [] },
                send: { [weak model] action in model?.send(action) },
                openPreferences: { [weak self] in self?.openPreferencesWindow(nil) },
                createMeeting: { createMeeting() }
            )
        )
    }

    /// Fetches events in `[from, to)` across the selected calendars, independent of the
    /// main sync. Used by the calendar window and the dropdown month grid.
    private func dateRangeEventFetch() -> @MainActor (Date, Date) async throws -> [MBEvent] {
        let sync = calendarSync
        return { [weak sync] from, to in
            guard let repository = sync?.repository else { return [] }
            let allCalendars = try await repository.fetchAllCalendars()
            let selected = repository.selectedCalendars(from: allCalendars.elements)
            return try await repository.fetchEventsForDateRange(
                for: selected, from: from, to: to
            ).elements
        }
    }

    /// Opens the month calendar window. Joining forwards to the AppModel's join
    /// action.
    func openCalendarWindow() {
        let model = appModel
        windowCoordinator.openCalendarWindow(
            handlers: CalendarWindowHandlers(
                fetchEvents: dateRangeEventFetch(),
                join: { [weak model] eventID in
                    model?.send(.joinMeeting(eventID: eventID))
                }
            )
        )
    }

    /// Opens the world-clock panel window.
    func openWorldClockWindow() {
        windowCoordinator.openWorldClockWindow()
    }

    /// Opens the camera/mic preview. With an `event`, it shows a Join button that
    /// forwards to the model's join action.
    func openCameraPreviewWindow(event: MBEvent?) {
        let model = appModel
        windowCoordinator.openCameraPreviewWindow(
            handlers: CameraPreviewHandlers(
                joinEventID: event?.id,
                join: { [weak model] eventID in
                    model?.send(.joinMeeting(eventID: eventID))
                }
            )
        )
    }

    /// Opens the in-app event editor to create a new event (EventKit write path).
    func openNewEventWindow() {
        windowCoordinator.openEventEditorWindow(
            mode: .create,
            handlers: makeEventEditorHandlers()
        )
    }

    /// Opens the in-app event editor prefilled to edit `event`.
    func openEditEventWindow(_ event: MBEvent) {
        windowCoordinator.openEventEditorWindow(
            mode: .edit(event),
            handlers: makeEventEditorHandlers()
        )
    }

    /// Deletes `event` via the EventKit writer and refreshes the sync.
    /// - Parameter span: which occurrences of a recurring event to delete.
    func deleteEvent(_ event: MBEvent, span: EventEditSpan) {
        let sync = calendarSync
        Task {
            do {
                try await EventKitEventWriter.shared.delete(id: event.scriptIdentifier, span: span)
                sync?.refreshSubject.send()
            } catch {
                PunctualLogger.calendar.error(
                    "Event delete failed: \(String(describing: error), privacy: .private)"
                )
            }
        }
    }

    /// Builds the editor handlers; each write refreshes `CalendarSync` on success.
    /// `dismiss` is replaced by `WindowCoordinator`, which owns the window.
    private func makeEventEditorHandlers() -> EventEditorHandlers {
        let sync = calendarSync
        return EventEditorHandlers(
            create: { draft in
                _ = try await EventKitEventWriter.shared.create(draft: draft)
                sync?.refreshSubject.send()
            },
            update: { id, draft, span in
                try await EventKitEventWriter.shared.update(id: id, draft: draft, span: span)
                sync?.refreshSubject.send()
            },
            delete: { id, span in
                try await EventKitEventWriter.shared.delete(id: id, span: span)
                sync?.refreshSubject.send()
            },
            writableCalendars: { EventKitEventWriter.shared.writableCalendars() },
            dismiss: {}
        )
    }

    @objc
    func windowClosed(notification: NSNotification) {
        let window = notification.object as? NSWindow
        windowCoordinator.handleWindowClosed(
            window,
            onboardingCompleted: Defaults[.onboardingCompleted],
            onIncompleteOnboardingClosed: { [weak self] in
                guard let self else { return }
                NSApplication.shared.terminate(self)
            },
            onChangelogClosed: {
                AppSettings.acknowledgeCurrentChangelog()
            }
        )
    }

    /*
     * -----------------------
     * MARK: - Actions
     * ------------------------
     */

    @objc
    func handleURLEvent(
        getURLEvent event: NSAppleEventDescriptor, replyEvent _: NSAppleEventDescriptor
    ) {
        guard let string = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: string) else { return }

        #if DEBUG
        // DEBUG URLs are intercepted here so release builds carry no route for them.
        if DropdownInspectorWindow.matches(url) {
            toggleDropdownInspectorWindow()
            return
        }
        if DebugHarnessWindow.matches(url) {
            toggleDebugHarnessWindow()
            return
        }
        #endif

        appModel?.send(.openRoute(urlHandler.route(for: url)))
    }

    #if DEBUG
    /// Toggles the non-dismissing dropdown inspector (`punctual://dropdown-debug`).
    private func toggleDropdownInspectorWindow() {
        guard let snapshot = statusBarItem?.dropdownPanelSnapshotForInspector() else { return }
        windowCoordinator.toggleDropdownInspectorWindow(
            state: snapshot.state,
            handlers: snapshot.handlers,
            anchor: snapshot.anchor
        )
    }

    /// Opens the development harness. Reached from the status item's right-click
    /// menu, or via `punctual://debug-harness`.
    func toggleDebugHarnessWindow() {
        windowCoordinator.openDebugHarnessWindow(
            handlers: DebugHarnessHandlers(
                apply: { [weak self] scenario in
                    // `nil` restores the real calendar; an empty list is itself a scenario.
                    self?.statusBarItem?.debugOverrideEvents(scenario.build.map { $0(Date()) })
                },
                summary: { [weak self] in
                    self?.statusBarItem?.debugRenderSummary()
                        ?? DebugHarnessHandlers().summary()
                }
            )
        )
    }
    #endif

    @objc
    func quit(_: Any?) {
        statusLoopTask?.cancel()
        NSApplication.shared.terminate(self)
    }

    /// Opens Preferences on reopen (Finder, Dock, `open`), so the app is reachable even
    /// when its status item is hidden, e.g. behind the notch.
    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        // While onboarding is still open, leave that window in charge.
        guard Defaults[.onboardingCompleted] else { return true }
        openPreferencesWindow(nil)
        return true
    }

    func applicationWillTerminate(_: Notification) {
        launchTask?.cancel()
        launchTask = nil
        notificationSetupTask?.cancel()
        notificationSetupTask = nil
        statusLoopTask?.cancel()
        statusLoopTask = nil
        lifecycleObserver.stop()
        appModel?.handleWillTerminate()
        notificationScheduler.stop()
        calendarSync?.stop()
        remindersSync?.stop()
        cancellables.removeAll()
        statusBarItem?.removeFromStatusBar()
    }
}
