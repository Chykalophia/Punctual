//
//  StatusBarItemController.swift
//  MeetingBar
//
//  Created by Andrii Leitsius on 12.06.2020.
//  Copyright © 2020 Andrii Leitsius. All rights reserved.
//
//  Modified for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Cocoa
import Combine
import Defaults
import KeyboardShortcuts

enum MenuStyleConstants {
    static let defaultFontSize: CGFloat = 13
    static let runningIconName = "running_icon"
    static let appIconName = "menuBarGlyph"
    static let calendarCheckmarkIconName = "iconCalendarCheckmark"
    static let calendarIconName = "iconCalendar"
    static let iconSize: NSSize = .init(width: 16, height: 16)

    /// Loads a named asset, falling back to the app icon and then to a 1x1
    /// placeholder, so a missing asset never crashes the menu bar.
    static func iconNamed(_ name: String) -> NSImage {
        if let image = NSImage(named: name) {
            return image
        }
        if let appIcon = NSImage(named: NSImage.applicationIconName) {
            return appIcon
        }
        return NSImage(size: NSSize(width: 1, height: 1))
    }
}

struct StatusBarDependencies {
    var appState: @MainActor () -> AppState = { AppState() }
    var events: @MainActor () -> [MBEvent] = { [] }
    var send: @MainActor (AppAction) -> Void = { _ in }
    var openPreferences: @MainActor () -> Void = {}
    var openChangelog: @MainActor () -> Void = {}
    var openCommandBar: @MainActor () -> Void = {}
    /// Opens or toggles the dropdown panel below the status item, given a state
    /// snapshot, the panel's handlers and the status-item button's rect in screen coordinates.
    var openDropdownPanel: @MainActor (StatusBarMenuState, DropdownPanelHandlers, NSRect) -> Void =
        { _, _, _ in }
    var openCalendar: @MainActor () -> Void = {}
    var openWorldClock: @MainActor () -> Void = {}
    var openCameraPreview: @MainActor (MBEvent?) -> Void = { _ in }
    var newEvent: @MainActor () -> Void = {}
    /// Fetches events in `[from, to)`; the same closure the calendar window uses.
    var fetchEvents: @MainActor (_ from: Date, _ to: Date) async throws -> [MBEvent] =
        { _, _ in [] }
    var editEvent: @MainActor (MBEvent) -> Void = { _ in }
    var deleteEvent: @MainActor (MBEvent, EventEditSpan) -> Void = { _, _ in }
    var quit: @MainActor () -> Void = {}
    #if DEBUG
    /// Opens the development harness (DEBUG builds only).
    var openDebugHarness: @MainActor () -> Void = {}
    #endif
}

/// Owns the status item: renders its title, routes its clicks and shortcuts, and hosts the action handlers.
@MainActor
final class StatusBarItemController {
    var statusItem: NSStatusItem!

    /// The menu-bar progress indicator, added to the status-item button once and
    /// reused. Weak because the button owns it as a subview.
    private weak var meetingProgressOverlay: MeetingProgressOverlayView?

    /// The Join chip's capsule overlay; weak because the button owns it.
    private weak var actionChipOverlay: MenuBarActionChipOverlayView?

    /// Area of the status-item button, in its coordinates, where a left-click joins
    /// the next meeting instead of opening the panel. `nil` when no chip is drawn.
    private(set) var actionChipHitRect: CGRect?

    /// Current event list from the app model. A non-nil `_eventsOverride` takes
    /// precedence (used by tests and the debug harness).
    private var _eventsOverride: [MBEvent]?
    var events: [MBEvent] {
        get { _eventsOverride ?? dependencies.events() }
        set { _eventsOverride = newValue }
    }

    let installationDate = getInstallationDate()

    private var dependencies = StatusBarDependencies()

    private var cancellables = Set<AnyCancellable>()

    /// The menu-bar redraw timer: one-shot, re-armed on every `updateTitle()`.
    private var tickTimer: Timer?

    /// Removes the status item from the menu bar and stops the redraw timer.
    func removeFromStatusBar() {
        tickTimer?.invalidate()
        tickTimer = nil
        cancellables.removeAll()
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    init() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusMenuBarAction)
        // Both edges of both buttons: macOS 27 may deliver only one half of a click;
        // `StatusItemClickPolicy` acts on whichever arrives first and swallows its partner.
        statusItem.button?.sendAction(on: [
            NSEvent.EventTypeMask.rightMouseDown, NSEvent.EventTypeMask.rightMouseUp,
            NSEvent.EventTypeMask.leftMouseUp, NSEvent.EventTypeMask.leftMouseDown
        ])

        statusItem.button?.image = MenuStyleConstants.iconNamed(MenuStyleConstants.appIconName)
        statusItem.button?.image?.size = MenuStyleConstants.iconSize
        statusItem.button?.imagePosition = .imageLeft

        setupDefaultsObservers()
        setupKeyboardShortcuts()
    }

    private func setupDefaultsObservers() {
        Defaults.publisher(
            keys: .statusbarEventTitleLength, .eventTimeFormat,
            .eventTitleIconFormat, .showEventMaxTimeUntilEventThreshold,
            .showEventMaxTimeUntilEventEnabled, .showEventDetails,
            .menuBarHighlightImminentEvent, .eventActionHighlightMinutes,
            .shortenEventTitle, .menuEventTitleLength,
            .showEventEndTime, .showMeetingServiceIcon,
            .showEventCalendarColor, .showMeetingPrepLinks,
            .timeFormat, .bookmarks, .deduplicateEvents,
            .personalEventsAppereance, .pastEventsAppereance,
            .declinedEventsAppereance, .ongoingEventVisibility,
            .showTimelineInMenu, .hideFinishedEventsInMenu,
            .menuBarTokens, .menuBarCountdownStyle, .menuBarDateStyle,
            .menuBarProgressStyle, .menuBarWorldClockTimeZone, .menuBarWorldClockLabel,
            .menuBarTwoLineLayout,
            .menuBarShowJoinAction, .menuBarJoinActionLeadMinutes,
            .menuBarCountdownLeadMinutes,
            .showGreetingInMenu, .greetingName,
            .showRemindersInMenu, .remindersIncludeOverdue,
            .dropdownModuleOrder, .showMeetingControlInMenu,
            .showAgendaInMenu, .showJoinSectionInMenu, .showBookmarksInMenu,
            options: []
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.updateTitle()
        }
        .store(in: &cancellables)

        Defaults.publisher(.eventTitleFormat, options: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateTitle()
                self?.reconcileNotifications()
            }
            .store(in: &cancellables)

        Defaults.publisher(.preferredLanguage, options: [.initial])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                if I18N.instance.changeLanguage(to: change.newValue) {
                    self?.updateTitle()
                    self?.reconcileNotifications()
                }
            }
            .store(in: &cancellables)

        Defaults.publisher(
            keys: .joinEventNotification,
            .joinEventNotificationTime,
            .endOfEventNotification,
            .endOfEventNotificationTime,
            .fullscreenNotification,
            .fullscreenNotificationTime,
            .fullscreenNotificationsForEventsWithoutMeetingLink,
            .automaticEventJoin,
            .automaticEventJoinTime,
            .runEventStartScript,
            .eventStartScriptTime,
            .eventStartScriptLocation,
            .dismissedEvents,
            options: []
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.reconcileNotifications()
        }
        .store(in: &cancellables)
    }

    private func reconcileNotifications() {
        dependencies.send(.reconcileNotifications)
    }

    private func setupKeyboardShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .createMeetingShortcut, action: createMeeting)

        KeyboardShortcuts.onKeyUp(for: .joinEventShortcut) {
            Task { @MainActor in self.joinNextMeeting() }
        }

        KeyboardShortcuts.onKeyUp(for: .openMenuShortcut) {
            Task { @MainActor in self.toggleDropdownPanel() }
        }

        KeyboardShortcuts.onKeyUp(for: .openClipboardShortcut, action: openLinkFromClipboard)

        KeyboardShortcuts.onKeyUp(for: .toggleMeetingTitleVisibilityShortcut) {
            Task { @MainActor in self.dependencies.send(.toggleMeetingTitleVisibility) }
        }

        KeyboardShortcuts.onKeyUp(for: .commandBarShortcut) {
            Task { @MainActor in self.dependencies.openCommandBar() }
        }

        KeyboardShortcuts.onKeyUp(for: .calendarShortcut) {
            Task { @MainActor in self.dependencies.openCalendar() }
        }

        KeyboardShortcuts.onKeyUp(for: .worldClockShortcut) {
            Task { @MainActor in self.dependencies.openWorldClock() }
        }

        KeyboardShortcuts.onKeyUp(for: .cameraPreviewShortcut) {
            Task { @MainActor in self.dependencies.openCameraPreview(nil) }
        }

        KeyboardShortcuts.onKeyUp(for: .newEventShortcut) {
            Task { @MainActor in self.dependencies.newEvent() }
        }
    }

    @objc
    func statusMenuBarAction(sender _: NSStatusItem) {
        let event = NSApp.currentEvent
        let input = Self.clickInput(for: event)
        let outcome = StatusItemClickPolicy.outcome(
            for: input,
            controlKeyHeld: event?.modifierFlags.contains(.control) ?? false,
            pendingDown: pendingStatusItemDown
        )
        // Must run after acting on every outcome, so a consumed mouse-up clears the
        // pairing and cannot swallow the next click.
        defer { pendingStatusItemDown = StatusItemClickPolicy.pendingDown(after: input) }

        switch outcome {
        case .ignore:
            return
        case .secondary:
            showQuickActionsMenu()
        case .primary:
            // The Join chip is drawn into the title, not a separate control, so it is
            // hit-tested here. An event-less click (macOS 27) has no location and opens the panel.
            if let event, input != .nonMouse, isActionChipClick(event) {
                joinNextMeeting()
                return
            }
            toggleDropdownPanel()
        }
    }

    /// The button whose mouse-down `statusMenuBarAction` acted on and whose
    /// mouse-up is still pending. See `StatusItemClickPolicy`.
    private var pendingStatusItemDown: StatusItemClickPolicy.Button?

    /// Maps AppKit's current event to the policy's input. Anything other than a
    /// mouse button event, including no event at all (macOS 27), is `.nonMouse`.
    private static func clickInput(for event: NSEvent?) -> StatusItemClickPolicy.Input {
        switch event?.type {
        case .leftMouseDown: .leftMouseDown
        case .leftMouseUp: .leftMouseUp
        case .rightMouseDown: .rightMouseDown
        case .rightMouseUp: .rightMouseUp
        default: .nonMouse
        }
    }

    /// Draws the status item as selected or not, like an open menu's highlight.
    ///
    /// Deferred one run-loop turn, because the button's own click tracking would
    /// overwrite a state set during the click that opened or closed the panel.
    func setStatusItemHighlighted(_ highlighted: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.statusItem?.button?.highlight(highlighted)
        }
    }

    /// Whether `event` landed on the Join chip.
    private func isActionChipClick(_ event: NSEvent) -> Bool {
        guard let hitRect = actionChipHitRect,
              let button = statusItem?.button,
              button.window != nil
        else { return false }
        // Modified clicks always open the panel, never join.
        guard event.modifierFlags.isDisjoint(with: .deviceIndependentFlagsMask) else {
            return false
        }
        return hitRect.contains(button.convert(event.locationInWindow, from: nil))
    }

    /// Opens the dropdown panel with a fresh state snapshot, anchored to the
    /// status-item button, or closes it when already open.
    func toggleDropdownPanel() {
        nudgeCalendarForceSync()

        var appState = dependencies.appState()
        appState.events = events
        let menuState = StatusBarMenuState.make(from: appState)

        guard let statusItem, let button = statusItem.button, let window = button.window else {
            PunctualLogger.lifecycle.error(
                "SwiftUI dropdown panel: status-item button has no window; skipping"
            )
            return
        }
        let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        dependencies.openDropdownPanel(menuState, dropdownPanelHandlers(), anchor)
    }

    #if DEBUG
    /// Everything `toggleDropdownPanel` would hand the panel, for the DEBUG
    /// inspector window to host instead.
    ///
    /// `anchor` is `nil` when the status item has no window yet.
    func dropdownPanelSnapshotForInspector() -> DropdownInspectorSnapshot {
        nudgeCalendarForceSync()

        var appState = dependencies.appState()
        appState.events = events
        let menuState = StatusBarMenuState.make(from: appState)

        let anchor = statusItem?.button.flatMap { button in
            button.window.map { $0.convertToScreen(button.convert(button.bounds, to: nil)) }
        }
        return DropdownInspectorSnapshot(
            state: menuState,
            handlers: dropdownPanelHandlers(),
            anchor: anchor
        )
    }
    #endif

    /// The panel's side effects, routed through the same dependency closures and
    /// @objc handlers the quick-actions menu uses. `dismiss` is filled in by the host.
    private func dropdownPanelHandlers() -> DropdownPanelHandlers {
        DropdownPanelHandlers(
            joinEvent: { [weak self] event in
                self?.dependencies.send(.joinMeeting(eventID: event.id))
            },
            openBookmark: { bookmark in
                MeetingOpener.open(
                    meetingLink: MeetingLink(
                        service: MeetingServices(rawValue: bookmark.service),
                        url: bookmark.url
                    )
                )
            },
            createMeeting: { createMeeting() },
            newEvent: { [weak self] in self?.dependencies.newEvent() },
            fetchEvents: { [weak self] from, to in
                guard let self else { return [] }
                return try await self.dependencies.fetchEvents(from, to)
            },
            refresh: { [weak self] in self?.dependencies.send(.refreshCalendars) },
            openPreferences: { [weak self] in self?.dependencies.openPreferences() },
            openCalendar: { [weak self] in self?.dependencies.openCalendar() },
            openCommandBar: { [weak self] in self?.dependencies.openCommandBar() },
            openChangelog: { [weak self] in self?.dependencies.openChangelog() },
            quit: { [weak self] in self?.dependencies.quit() },
            openLinkFromClipboard: { [weak self] in self?.openLinkFromClipboardAction() },
            toggleMeetingTitleVisibility: { [weak self] in self?.toggleMeetingTitleVisibility() },
            openCameraPreview: { [weak self] in self?.openCameraPreviewAction() },
            openWorldClock: { [weak self] in self?.openWorldClockAction() },
            dismissNextMeeting: { [weak self] in self?.dismissNextMeetingAction() },
            undismissAllMeetings: { [weak self] in self?.undismissMeetingsActions() },
            editEvent: { [weak self] event in self?.editEvent(event) },
            deleteEvent: { [weak self] event in self?.confirmAndDeleteEvent(event) },
            copyText: { [weak self] value in self?.copyDetail(value) },
            copyMeetingLink: { [weak self] event in self?.copyMeetingLink(for: event) },
            copyMeetingIdentifier: { [weak self] event in self?.copyMeetingIdentifier(for: event) },
            setReminderOverride: { event, override in
                if let override {
                    EventReminderOverrideStore.set(override, for: event)
                } else {
                    EventReminderOverrideStore.clear(for: event)
                }
            },
            openURL: { [weak self] url in self?.openReferenceURL(url) },
            emailAttendees: { [weak self] event in self?.emailAttendees(for: event) },
            dismissEvent: { [weak self] event in self?.dismiss(event: event) },
            undismissEvent: { [weak self] event in self?.undismiss(event: event) },
            completeReminder: { [weak self] reminder in self?.completeReminder(reminder) },
            snoozeReminder: { [weak self] reminder, option in
                self?.snoozeReminder(reminder, option: option)
            },
            openReminderInApp: { [weak self] reminder in self?.openReminderInApp(reminder) }
        )
    }

    /// Asks `CalendarSync` to force an EventKit source refresh. Debounced there
    /// (~30s), so calling it on every open is safe.
    private func nudgeCalendarForceSync() {
        dependencies.send(.forceCalendarSync)
    }

    /// Pops up the right-click quick-actions menu at the status item.
    func showQuickActionsMenu() {
        nudgeCalendarForceSync()
        guard let statusItem else { return }
        var appState = dependencies.appState()
        appState.events = events
        let menuState = StatusBarMenuState.make(from: appState)
        let menu = QuickActionsMenu.build(target: self, state: menuState)
        #if DEBUG
        menu.addItem(.separator())
        let harness = NSMenuItem(
            title: "Debug harness…",
            action: #selector(openDebugHarnessAction),
            keyEquivalent: ""
        )
        harness.target = self
        menu.addItem(harness)
        #endif
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    /// Copies today's agenda to the pasteboard, in the same format as the Command
    /// Bar's "Copy agenda".
    @objc func copyTodayAgendaAction() {
        let now = Date()
        let calendar = Calendar.current
        let todays = events
            .filter { calendar.isDate($0.startDate, inSameDayAs: now) }
            .sorted { $0.startDate < $1.startDate }
        let entries = todays.map { event in
            CommandBarAgendaEntry(
                title: event.title,
                timeRange: event.isAllDay ? "" : agendaTimeRange(event),
                isAllDay: event.isAllDay
            )
        }
        let header = "command_bar_agenda_header".loco(agendaDateText(now, calendar: calendar))
        let text = CommandBarAgenda.text(
            for: entries,
            header: header,
            emptyPlaceholder: "command_bar_agenda_empty".loco()
        )
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func agendaTimeRange(_ event: MBEvent) -> String {
        "\(agendaClock(event.startDate)) – \(agendaClock(event.endDate))"
    }

    private func agendaClock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = I18N.instance.locale
        formatter.setLocalizedDateFormatFromTemplate(Defaults[.timeFormat] == .military ? "Hmm" : "hmma")
        return formatter.string(from: date)
    }

    private func agendaDateText(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = I18N.instance.locale
        formatter.setLocalizedDateFormatFromTemplate("EEEMMMd")
        return formatter.string(from: date)
    }

    func configure(dependencies: StatusBarDependencies) {
        self.dependencies = dependencies
    }

    func updateTitle() {
        let now = Date()
        let selectedEvent = events.nextEvent()
        let nextEvent = selectedEvent.map(StatusBarEventPresentationInput.init)
        scheduleNextTick(now: now, event: selectedEvent)

        let presentation: StatusBarPresentation
        if let composition = MenuBarComposition.currentIfEnabled {
            presentation = StatusBarPresenter.composedPresentation(
                nextEvent: nextEvent,
                composition: composition,
                settings: .current,
                now: now,
                calendar: statusBarCalendar()
            )
        } else {
            presentation = StatusBarPresenter.presentation(
                nextEvent: nextEvent,
                settings: .current,
                now: now,
                calendar: statusBarCalendar()
            )
        }

        if presentation.removeDeliveredNotifications, Defaults[.joinEventNotification] {
            removeDeliveredNotifications()
        }

        renderStatusBar(presentation)
    }

    // MARK: - The clock

    /// Arms a one-shot redraw for the next time-driven change: a meeting starting
    /// or ending, the ongoing grace period expiring, or the next minute.
    private func scheduleNextTick(now: Date, event: MBEvent?) {
        tickTimer?.invalidate()

        var transitions = StatusBarTickPolicy.transitionDates(
            eventStart: event?.startDate,
            eventEnd: event?.endDate,
            ongoingGracePeriod: Defaults[.ongoingEventVisibility].gracePeriod
        )
        if let start = event?.startDate {
            if let due = MenuBarJoinActionPolicy.appearanceDate(
                eventStart: start,
                settings: .current
            ) {
                transitions.append(due)
            }
            if let due = MenuBarCompositionPolicy.countdownAppearanceDate(
                eventStart: start,
                leadMinutes: Defaults[.menuBarCountdownLeadMinutes]
            ) {
                transitions.append(due)
            }
        }

        let fireDate = StatusBarTickPolicy.nextFireDate(
            now: now,
            transitions: transitions,
            calendar: statusBarCalendar()
        )

        let timer = Timer(
            timeInterval: StatusBarTickPolicy.delay(now: now, until: fireDate),
            repeats: false
        ) { [weak self] _ in
            DispatchQueue.main.async { self?.updateTitle() }
        }
        // .common keeps ticking while a menu is tracking or a window resizes.
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    func renderStatusBar(_ presentation: StatusBarPresentation) {
        guard let statusItem, let button = statusItem.button else { return }

        button.image = nil
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.toolTip = nil
        button.alignment = .center
        button.cell?.lineBreakMode = .byTruncatingTail

        switch presentation.icon {
        case .asset(let name):
            button.image = MenuStyleConstants.iconNamed(name)
            button.image?.size = MenuStyleConstants.iconSize
        case .meetingService(let service):
            button.image = getIconForMeetingService(service)
        case .none:
            break
        }
        if button.image?.name() == "no_online_session" {
            button.imagePosition = .noImage
        } else {
            button.imagePosition = presentation.iconPosition == .trailing ? .imageRight : .imageLeft
        }

        // `.none` layout means icon-only.
        if presentation.layout != .none {
            button.attributedTitle = StatusBarTitleRenderer.attributedTitle(for: presentation)
        }
        if let tooltip = presentation.tooltip {
            button.toolTip = tooltip
        }

        ensureStatusBarButtonIsVisible(button)
        renderMeetingProgress(on: button)
        // Must run last: the chip is measured against the final image and title,
        // and `renderMeetingProgress` may replace the image.
        renderActionChip(on: button, presentation: presentation)

        #if DEBUG
        lastRenderedPresentation = presentation
        #endif
    }

    #if DEBUG
    @objc
    func openDebugHarnessAction() {
        dependencies.openDebugHarness()
    }

    /// The last presentation drawn, for the debug harness's readout.
    private var lastRenderedPresentation: StatusBarPresentation?

    /// Replaces the event list with synthetic events, or restores the real
    /// calendar when passed `nil`, then redraws immediately.
    func debugOverrideEvents(_ events: [MBEvent]?) {
        _eventsOverride = events
        updateTitle()
    }

    /// What the menu bar is currently drawing, for the harness's readout.
    func debugRenderSummary() -> DebugRenderSummary {
        DebugRenderSummary(
            firstLine: lastRenderedPresentation?.title ?? "",
            secondLine: lastRenderedPresentation?.time ?? "",
            actionLabel: lastRenderedPresentation?.actionLabel ?? "",
            chipRect: actionChipHitRect,
            buttonWidth: statusItem?.button?.bounds.width ?? 0,
            eventCount: events.count,
            isOverridden: _eventsOverride != nil,
            hasSelectedCalendars: !CalendarSourceSelection.connectedSelectedCalendarIDs().isEmpty
        )
    }
    #endif

    // MARK: - Join chip (menu bar)

    /// Positions the Join chip's capsule and its click target, or clears both.
    ///
    /// The chip is the trailing run of the button's attributed title; the presenter
    /// guarantees the action label comes last (`composedLines`).
    private func renderActionChip(on button: NSStatusBarButton, presentation: StatusBarPresentation) {
        let label = presentation.actionLabel
        let title = button.attributedTitle
        let labelLength = label.utf16.count

        guard !label.isEmpty, title.length >= labelLength, labelLength > 0 else {
            clearActionChip()
            return
        }

        // Drop the chip rather than put a click target over the wrong glyphs.
        let range = NSRange(location: title.length - labelLength, length: labelLength)
        let trailing = title.attributedSubstring(from: range)
        guard trailing.string == label else {
            clearActionChip()
            return
        }

        let isStacked = presentation.layout == .stacked
        let lastLine = isStacked
            ? title.attributedSubstring(from: lastLineRange(of: title))
            : title
        let hasImage = button.imagePosition != .noImage && button.image != nil

        guard let chip = MenuBarActionChipGeometry.rect(
            MenuBarActionChipMetrics(
                buttonBounds: button.bounds,
                imageWidth: hasImage ? (button.image?.size.width ?? 0) : 0,
                imageIsTrailing: button.imagePosition == .imageRight,
                titleWidth: renderedWidth(of: title),
                lineWidth: renderedWidth(of: lastLine),
                labelWidth: renderedWidth(of: trailing),
                isStacked: isStacked
            )
        ) else {
            clearActionChip()
            return
        }

        let overlay = actionChipOverlay ?? {
            let view = MenuBarActionChipOverlayView()
            view.autoresizingMask = [.width, .height]
            button.addSubview(view)
            actionChipOverlay = view
            return view
        }()
        overlay.frame = button.bounds
        overlay.chipRect = chip

        actionChipHitRect = MenuBarActionChipGeometry.hitRect(chip: chip, buttonBounds: button.bounds)
    }

    private func clearActionChip() {
        actionChipOverlay?.chipRect = nil
        actionChipHitRect = nil
    }

    /// Width of the widest line. Uses `boundingRect` because `size()` measures a
    /// two-line string as one run.
    private func renderedWidth(of string: NSAttributedString) -> CGFloat {
        guard string.length > 0 else { return 0 }
        return ceil(
            string.boundingRect(
                with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            ).width
        )
    }

    /// The range of the text after the last newline: the stacked layout's detail
    /// line, which carries the chip.
    private func lastLineRange(of string: NSAttributedString) -> NSRange {
        let text = string.string as NSString
        let newline = text.rangeOfCharacter(from: .newlines, options: .backwards)
        guard newline.location != NSNotFound else {
            return NSRange(location: 0, length: string.length)
        }
        let start = newline.location + newline.length
        return NSRange(location: start, length: string.length - start)
    }

    // MARK: - Meeting progress (menu bar)

    /// Draws or clears the menu-bar progress indicator for the next meeting.
    ///
    /// Call after the icon and title are set: styles are sized from the button's
    /// final bounds and the ring wraps the current icon.
    private func renderMeetingProgress(on button: NSStatusBarButton) {
        let style = MeetingProgressStyle(rawValue: Defaults[.meetingProgressStyle]) ?? .none
        let progress = style.drawsSomething ? currentMeetingProgress() : nil

        guard let progress else {
            meetingProgressOverlay?.presentation = nil
            return
        }

        if style.occupiesImageSlot {
            // The bar replaces the icon rather than overlaying it.
            button.image = MeetingProgressRenderer.barImage(for: progress)
            button.imagePosition = .imageLeft
            meetingProgressOverlay?.presentation = nil
            return
        }

        // With no icon, an overlay ring would land on the title's first letter, so
        // the ring becomes the icon instead.
        if style == .ring, button.image == nil {
            button.image = MeetingProgressRenderer.ringImage(for: progress)
            button.imagePosition = .imageLeft
            meetingProgressOverlay?.presentation = nil
            return
        }

        let overlay = meetingProgressOverlay ?? {
            let view = MeetingProgressOverlayView()
            view.autoresizingMask = [.width, .height]
            button.addSubview(view)
            meetingProgressOverlay = view
            return view
        }()
        overlay.frame = button.bounds
        overlay.iconWidth = button.image?.size.width ?? 0
        overlay.style = style
        overlay.presentation = progress
    }

    /// The indicator's state for whichever meeting the menu bar is showing, or
    /// `nil` when there is nothing to draw.
    private func currentMeetingProgress() -> MeetingProgressPresentation? {
        guard let event = events.nextEvent() else { return nil }
        return MeetingProgressPolicy.presentation(
            start: event.startDate,
            end: event.endDate,
            now: Date(),
            leadMinutes: Defaults[.eventActionHighlightMinutes]
        )
    }

    private func ensureStatusBarButtonIsVisible(_ button: NSStatusBarButton) {
        guard button.image == nil,
              button.title.isEmpty,
              button.attributedTitle.string.isEmpty
        else { return }

        button.image = MenuStyleConstants.iconNamed(MenuStyleConstants.appIconName)
        button.image?.size = MenuStyleConstants.iconSize
        button.imagePosition = .imageLeft
    }

    /*
     * -----------------------
     * MARK: - Actions
     * ------------------------
     */

    @objc func createMeetingAction() {
        createMeeting()
    }

    @objc
    func joinNextMeeting() {
        if let nextEvent = events.nextEvent() {
            dependencies.send(.joinMeeting(eventID: nextEvent.id))
        } else {
            AppMessageCenter.shared.post(.nextMeetingMissing)
        }
    }

    @objc
    func joinEvent(sender: NSMenuItem) {
        guard let event = sender.representedObject as? MBEvent else {
            AppMessageCenter.shared.post(.nextMeetingMissing)
            return
        }
        dependencies.send(.joinMeeting(eventID: event.id))
    }

    @objc
    func dismissNextMeetingAction() {
        if let nextEvent = events.nextEvent() {
            dependencies.send(.dismissMeeting(eventID: nextEvent.id))
            AppMessageCenter.shared.post(.meetingDismissed(title: nextEvent.title))

            updateTitle()
            reconcileNotifications()
        }
    }

    @objc
    func undismissMeetingsActions() {
        dependencies.send(.clearDismissedMeetings)
        AppMessageCenter.shared.post(.allDismissalsRemoved)

        updateTitle()
        reconcileNotifications()
    }

    @objc
    func openLinkFromClipboardAction() {
        openLinkFromClipboard()
    }

    @objc
    func toggleMeetingTitleVisibility() {
        dependencies.send(.toggleMeetingTitleVisibility)
    }

    @objc
    func joinBookmark(sender: NSMenuItem) {
        if let bookmark: Bookmark = sender.representedObject as? Bookmark {
            MeetingOpener.open(
                meetingLink: MeetingLink(service: MeetingServices(rawValue: bookmark.service), url: bookmark.url))
        }
    }

    @objc
    func clickOnEvent(sender: NSMenuItem) {
        if let event: MBEvent = sender.representedObject as? MBEvent {
            dependencies.send(.joinMeeting(eventID: event.id))
        }
    }

    @objc
    func joinMeetingLinkCandidate(sender: NSMenuItem) {
        if let candidate = sender.representedObject as? MeetingLinkCandidate {
            MeetingOpener.open(
                meetingLink: MeetingLink(service: candidate.service, url: candidate.url))
        }
    }

    @objc
    func openEventInCalendar(sender: NSMenuItem) {
        // `representedObject` is the provider-specific calendar URL.
        if let url = sender.representedObject as? URL {
            url.openInDefaultBrowser()
        }
    }

    @objc
    func openPrepLink(sender: NSMenuItem) {
        if let url = sender.representedObject as? URL {
            openReferenceURL(url)
        }
    }

    /// Opens a reference URL (prep link, alternate meeting link) in the default browser.
    func openReferenceURL(_ url: URL) {
        url.openInDefaultBrowser()
    }

    // MARK: - Reminders

    @objc
    func toggleReminderComplete(sender: NSMenuItem) {
        guard let reminder = sender.representedObject as? MBReminder else { return }
        completeReminder(reminder)
    }

    func completeReminder(_ reminder: MBReminder) {
        dependencies.send(.completeReminder(id: reminder.id))
    }

    @objc
    func snoozeReminder(sender: NSMenuItem) {
        guard let command = sender.representedObject as? ReminderSnoozeCommand else { return }
        dependencies.send(.snoozeReminder(id: command.reminderID, option: command.option))
    }

    func snoozeReminder(_ reminder: MBReminder, option: ReminderSnoozeOption) {
        dependencies.send(.snoozeReminder(id: reminder.id, option: option))
    }

    @objc
    func openReminderInApp(sender: NSMenuItem) {
        guard let reminder = sender.representedObject as? MBReminder else { return }
        openReminderInApp(reminder)
    }

    func openReminderInApp(_ reminder: MBReminder) {
        if let deepLink = URL(string: "x-apple-reminderkit://REMCDReminder/\(reminder.id)") {
            NSWorkspace.shared.open(deepLink)
        } else if let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.reminders"
        ) {
            NSWorkspace.shared.open(appURL)
        }
    }

    @objc func handleManualRefresh() {
        dependencies.send(.refreshCalendars)
    }

    @objc func reconnectProviderAction() {
        dependencies.send(.changeProvider(stateProvider, signOut: true))
    }

    @objc func openCalendarPermissionsAction() {
        NSWorkspace.shared.open(Links.calendarPreferences)
    }

    @objc
    func dismissEvent(sender: NSMenuItem) {
        if let event: MBEvent = sender.representedObject as? MBEvent {
            dismiss(event: event)
        }
    }

    func dismiss(event: MBEvent) {
        dependencies.send(.dismissMeeting(eventID: event.id))

        updateTitle()
        reconcileNotifications()
    }

    @objc
    func undismissEvent(sender: NSMenuItem) {
        if let event: MBEvent = sender.representedObject as? MBEvent {
            undismiss(event: event)
        }
    }

    func undismiss(event: MBEvent) {
        dependencies.send(.undismissMeeting(eventID: event.id))

        updateTitle()
        reconcileNotifications()
    }

    /// Copies the menu item's `representedObject` string to the pasteboard.
    @objc
    func copyDetailAction(sender: NSMenuItem) {
        guard let value = sender.representedObject as? String else { return }
        copyDetail(value)
    }

    /// Copies a trimmed detail string to the pasteboard, ignoring blanks.
    func copyDetail(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(trimmed, forType: .string)
    }

    @objc
    func copyEventMeetingLink(sender: NSMenuItem) {
        if let event: MBEvent = sender.representedObject as? MBEvent {
            copyMeetingLink(for: event)
        }
    }

    func copyMeetingLink(for event: MBEvent) {
        if let meetingLink = event.meetingLink {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(meetingLink.url.absoluteString, forType: .string)
        } else {
            AppMessageCenter.shared.post(.meetingLinkMissing(title: event.title))
        }
    }

    /// Copies the meeting's id or room name rather than its URL.
    ///
    /// Without a `meetingIdentifier`, posts a message and leaves the pasteboard untouched.
    func copyMeetingIdentifier(for event: MBEvent) {
        guard let identifier = event.meetingIdentifier else {
            AppMessageCenter.shared.post(.meetingLinkMissing(title: event.title))
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(identifier.value, forType: .string)
    }

    @objc
    func emailAttendees(sender: NSMenuItem) {
        if let event: MBEvent = sender.representedObject as? MBEvent {
            emailAttendees(for: event)
        }
    }

    func emailAttendees(for event: MBEvent) {
        MeetingOpener.emailAttendees(for: event)
    }

    @objc
    func openEventInFantastical(sender: NSMenuItem) {
        if let event: MBEvent = sender.representedObject as? MBEvent {
            openInFantastical(startDate: event.startDate, title: event.title)
        }
    }

    @objc
    func openPreferencesAction() {
        dependencies.openPreferences()
    }

    @objc
    func checkForUpdatesAction() {
        SoftwareUpdater.shared.checkForUpdates()
    }

    @objc
    func openCalendarAction() {
        dependencies.openCalendar()
    }

    @objc
    func openWorldClockAction() {
        dependencies.openWorldClock()
    }

    /// Opens the camera/mic pre-call preview without an event, so it shows no Join button.
    @objc
    func openCameraPreviewAction() {
        dependencies.openCameraPreview(nil)
    }

    /// Opens the camera/mic preview for the menu item's event, with a Join button.
    @objc
    func previewCameraForEventAction(sender: NSMenuItem) {
        guard let event = sender.representedObject as? MBEvent else { return }
        dependencies.openCameraPreview(event)
    }

    // MARK: - Event editing

    @objc
    func newEventAction() {
        dependencies.newEvent()
    }

    @objc
    func editEventAction(sender: NSMenuItem) {
        guard let event = sender.representedObject as? MBEvent else { return }
        editEvent(event)
    }

    func editEvent(_ event: MBEvent) {
        dependencies.editEvent(event)
    }

    @objc
    func deleteEventAction(sender: NSMenuItem) {
        guard let event = sender.representedObject as? MBEvent else { return }
        confirmAndDeleteEvent(event)
    }

    /// Confirms with a modal alert, offering this-event or this-and-future for a
    /// recurring event, then deletes through the injected dependency.
    func confirmAndDeleteEvent(_ event: MBEvent) {
        let alert = NSAlert()
        alert.messageText = "event_editor_delete_confirm_title".loco()
        alert.informativeText = "event_editor_delete_confirm_message".loco(event.title)
        alert.alertStyle = .warning

        if event.recurrent {
            let thisButton = alert.addButton(withTitle: "event_editor_delete_this_event".loco())
            thisButton.hasDestructiveAction = true
            let futureButton = alert.addButton(withTitle: "event_editor_delete_this_and_future".loco())
            futureButton.hasDestructiveAction = true
            alert.addButton(withTitle: "event_editor_cancel".loco())

            switch alert.runModal() {
            case .alertFirstButtonReturn:
                dependencies.deleteEvent(event, .thisEvent)
            case .alertSecondButtonReturn:
                dependencies.deleteEvent(event, .thisAndFuture)
            default:
                return
            }
        } else {
            let deleteButton = alert.addButton(withTitle: "event_editor_delete".loco())
            deleteButton.hasDestructiveAction = true
            alert.addButton(withTitle: "event_editor_cancel".loco())

            guard alert.runModal() == .alertFirstButtonReturn else { return }
            dependencies.deleteEvent(event, .thisEvent)
        }
    }

    private var stateProvider: EventStoreProvider {
        dependencies.appState().activeProvider
    }

    @objc
    func openChangelogAction() {
        dependencies.openChangelog()
    }

    @objc
    func quitAction() {
        dependencies.quit()
    }
}

@MainActor
enum StatusBarTitleRenderer {
    static func attributedTitle(for presentation: StatusBarPresentation) -> NSAttributedString {
        switch presentation.layout {
        case .none:
            return NSAttributedString(string: "")
        case .inline(let showTime):
            var eventTitle = presentation.title
            if showTime {
                eventTitle += " " + presentation.time
            }
            return NSAttributedString(
                string: eventTitle,
                attributes: titleAttributes(
                    style: presentation.titleStyle,
                    font: titleFont(
                        ofSize: MenuStyleConstants.defaultFontSize,
                        emphasized: presentation.emphasizeTitle
                    )
                )
            )
        case .stacked:
            return stackedTitle(for: presentation)
        }
    }

    /// Emphasis uses weight, not colour, because the menu bar's background is
    /// unknown and the system owns its tinting.
    private static func titleFont(ofSize size: CGFloat, emphasized: Bool) -> NSFont {
        emphasized
            ? NSFont.systemFont(ofSize: size, weight: .bold)
            : NSFont.systemFont(ofSize: size)
    }

    private static func stackedTitle(for presentation: StatusBarPresentation) -> NSAttributedString {
        let title = NSMutableAttributedString(
            string: presentation.title,
            attributes: titleAttributes(
                style: presentation.titleStyle,
                font: titleFont(ofSize: 12, emphasized: presentation.emphasizeTitle),
                baselineOffset: -3
            )
        )
        title.append(
            NSAttributedString(
                string: "\n" + presentation.time,
                attributes: [
                    NSAttributedString.Key.font: NSFont.systemFont(ofSize: 9),
                    NSAttributedString.Key.foregroundColor: NSColor.lightGray
                ]
            ))

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 0.7
        paragraphStyle.alignment = .center
        title.addAttributes(
            [NSAttributedString.Key.paragraphStyle: paragraphStyle],
            range: NSRange(location: 0, length: title.length)
        )
        return title
    }

    private static func titleAttributes(
        style: StatusBarTitleStyle,
        font: NSFont,
        baselineOffset: CGFloat? = nil
    ) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font
        ]
        if let baselineOffset {
            attributes[.baselineOffset] = baselineOffset
        }
        switch style {
        case .normal:
            break
        case .inactive:
            attributes[.foregroundColor] = NSColor.disabledControlTextColor
        case .underlined:
            attributes[.underlineStyle] =
                NSUnderlineStyle.single.rawValue
                | NSUnderlineStyle.patternDot.rawValue
                | NSUnderlineStyle.byWord.rawValue
        }
        return attributes
    }
}

private func statusBarCalendar() -> Calendar {
    var calendar = Calendar.current
    calendar.locale = I18N.instance.locale
    return calendar
}

/// A reminder and snooze option carried in a menu item's `representedObject`
/// to `snoozeReminder(sender:)`.
struct ReminderSnoozeCommand {
    let reminderID: String
    let option: ReminderSnoozeOption
}
