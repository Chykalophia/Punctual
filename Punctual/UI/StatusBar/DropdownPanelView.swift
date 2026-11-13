//
//  DropdownPanelView.swift
//  Punctual
//
//  The SwiftUI dropdown panel shown from the status item. Renders the modules
//  resolved by `DropdownCompositionPolicy` from a `StatusBarMenuState` snapshot;
//  every side effect goes out through the injected `DropdownPanelHandlers`.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import AppKit
import Defaults
import KeyboardShortcuts
import SwiftUI

/// Everything the panel can do, injected by `StatusBarItemController` so the view
/// has no side effects. `dismiss` is supplied by the window host
/// (`WindowCoordinator.openDropdownPanel`) and closes the panel.
struct DropdownPanelHandlers {
    var joinEvent: @MainActor (MBEvent) -> Void = { _ in }
    var openBookmark: @MainActor (Bookmark) -> Void = { _ in }
    /// Starts an online meeting on the configured service.
    var createMeeting: @MainActor () -> Void = {}
    /// Opens the in-app editor for a new calendar event.
    var newEvent: @MainActor () -> Void = {}
    /// Fetches events in `[from, to)` for the compact month grid's dots; the same
    /// closure as `CalendarWindowHandlers.fetchEvents`.
    var fetchEvents: @MainActor (_ from: Date, _ to: Date) async throws -> [MBEvent] = { _, _ in [] }
    var refresh: @MainActor () -> Void = {}
    var openPreferences: @MainActor () -> Void = {}
    var openCalendar: @MainActor () -> Void = {}
    var openCommandBar: @MainActor () -> Void = {}
    var openChangelog: @MainActor () -> Void = {}
    var quit: @MainActor () -> Void = {}
    var dismiss: @MainActor () -> Void = {}

    // MARK: - Utility actions

    /// Detects a meeting link on the pasteboard and opens it.
    var openLinkFromClipboard: @MainActor () -> Void = {}
    /// Flips `eventTitleFormat` between `.show` and `.generic`, hiding or revealing
    /// the meeting title in the menu bar (not in this panel).
    var toggleMeetingTitleVisibility: @MainActor () -> Void = {}
    /// Opens the camera/mic pre-call preview with no event attached.
    var openCameraPreview: @MainActor () -> Void = {}
    var openWorldClock: @MainActor () -> Void = {}
    /// Dismisses the current or next meeting.
    var dismissNextMeeting: @MainActor () -> Void = {}
    var undismissAllMeetings: @MainActor () -> Void = {}

    // MARK: - Per-event actions

    var editEvent: @MainActor (MBEvent) -> Void = { _ in }
    /// Deletes after a confirmation alert, which also offers the recurring scope.
    var deleteEvent: @MainActor (MBEvent) -> Void = { _ in }
    /// Copies a detail string (location, organizer, attendee, notes).
    var copyText: @MainActor (String) -> Void = { _ in }
    var copyMeetingLink: @MainActor (MBEvent) -> Void = { _ in }
    var copyMeetingIdentifier: @MainActor (MBEvent) -> Void = { _ in }
    /// `nil` returns the event to the global reminder setting.
    var setReminderOverride: @MainActor (MBEvent, StartReminderOverride?) -> Void = { _, _ in }
    /// Opens a meeting-prep or alternate meeting link in the default browser.
    var openURL: @MainActor (URL) -> Void = { _ in }
    var emailAttendees: @MainActor (MBEvent) -> Void = { _ in }
    var dismissEvent: @MainActor (MBEvent) -> Void = { _ in }
    var undismissEvent: @MainActor (MBEvent) -> Void = { _ in }

    // MARK: - Per-reminder actions

    var completeReminder: @MainActor (MBReminder) -> Void = { _ in }
    var snoozeReminder: @MainActor (MBReminder, ReminderSnoozeOption) -> Void = { _, _ in }
    var openReminderInApp: @MainActor (MBReminder) -> Void = { _ in }
}

struct DropdownPanelView: View {
    let state: StatusBarMenuState
    let handlers: DropdownPanelHandlers
    /// Seed for the panel's clock. Read `clock`, never this, for anything
    /// time-dependent: the clock advances while the panel is open and this does not.
    var now: Date = Date()
    /// When true, the panel grows to its full content height and disables its own
    /// scrolling, for the Display-tab preview's outer ScrollView.
    var isPreview: Bool = false

    @Default(.dropdownModuleOrder) private var dropdownModuleOrder

    @Environment(\.colorScheme) private var colorScheme
    @Default(.dropdownDensity) private var dropdownDensityRaw
    @Default(.timelineStyle) private var timelineStyleRaw
    @Default(.timelineAppearance) private var timelineAppearanceRaw
    @Default(.meetingCardShowsProgress) private var showsMeetingCardProgress
    @Default(.dropdownHidesEmptyDays) private var hidesEmptyAgendaDays
    @Default(.dateMarkers) private var storedDateMarkers
    @Default(.dropdownCalendarWeekFold) private var calendarWeekFold
    @Default(.panelAccent) private var panelAccentRaw
    @Default(.meetingCardShowsSectionLine) private var meetingCardShowsSectionLine
    @Default(.meetingCardShowsTimes) private var meetingCardShowsTimes
    @Default(.meetingCardShowsProvider) private var meetingCardShowsProvider
    @Default(.meetingCardShowsSource) private var meetingCardShowsSource
    @Default(.greetingShowsDate) private var greetingShowsDate

    private var dropdownDensity: DropdownDensity {
        DropdownDensity(rawValue: dropdownDensityRaw) ?? .standard
    }

    /// How close a meeting must be for its row action to look actionable.
    @Default(.eventActionHighlightMinutes) private var eventActionHighlightMinutes

    /// Rows one agenda section draws before the rest go behind "+N more".
    @Default(.dropdownMaxEventRows) private var dropdownMaxEventRows

    /// Months stepped away from today in the compact grid. Not persisted, so the
    /// panel always reopens on the current month.
    @State private var calendarMonthOffset = 0
    /// Dots for the visible month, filled by `loadMonthMarkers`.
    @State private var monthMarkers: [Date: [Color]] = [:]

    /// Agenda sections unfolded past the row cap while the panel is open. Not persisted.
    @State private var expandedAgendaDays: Set<AgendaDay> = []

    /// Index into `navigationRows` of the keyboard-selected row; `nil` until the
    /// user moves the selection.
    @State private var selectionIndex: Int?
    /// Event ids whose inline detail disclosure is expanded.
    @State private var expandedEventIDs: Set<String> = []
    /// Key focus, so Up/Down/Return reach `onMoveCommand` and `onKeyPress`.
    @FocusState private var isPanelFocused: Bool
    /// The advancing clock, published by `panelClock()`. `nil` until the first
    /// tick, so the first frame renders at `now`.
    @State private var tickedNow: Date?
    /// The AppKit view the More-actions flyout anchors to. `@State` so it survives
    /// the view being rebuilt on every clock tick.
    @State private var moreActionsAnchor = MenuAnchorBox()

    /// Pending hover spring-open of the More-actions flyout; cancelled if the
    /// pointer leaves first.
    @State private var moreActionsHoverTimer: DispatchWorkItem?

    /// Set when the flyout closes so a pointer still on the row cannot reopen it;
    /// cleared when the pointer leaves.
    @State private var moreActionsHoverDisarmed = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The layout grid for the current density, passed down through the environment.
    private var metrics: DropdownMetrics { dropdownDensity.metrics }

    /// Hover dwell before the More-actions flyout springs open, in seconds. Long
    /// enough that sweeping past the row toward the footer does not fire it.
    private static let moreActionsHoverDelay: TimeInterval = 0.25

    static var preferredWidth: CGFloat { MeetingSummaryView.preferredWidth }

    /// `nil` under Reduce Motion, so state changes apply instantly.
    private var revealAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.12)
    }

    /// Height cap before the panel scrolls. `DropdownPanelPlacement` trims this
    /// further on a short display.
    static let maximumHeight: CGFloat = 760

    /// Corner radius of the panel surface. Must equal the mask applied by
    /// `WindowStylePolicy.applyRoundedCorners`, or the corners clip or show a hairline.
    static var cornerRadius: CGFloat {
        if #available(macOS 26.0, *) { 20 } else { 16 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(visibleModules.enumerated()), id: \.element) { pair in
                            if separatorIndices.contains(pair.offset) { separator }
                            moduleBlock(pair.element)
                        }
                    }
                    .padding(.vertical, 6)
                    .frame(width: Self.preferredWidth, alignment: .leading)
                }
                .scrollDisabled(isPreview)
                .onChange(of: selectionIndex) { _, _ in
                    guard let selectedRow else { return }
                    withAnimation(revealAnimation) {
                        proxy.scrollTo(selectedRow, anchor: .center)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            // Hidden so an overflowing panel still reads as a menu.
            .scrollIndicators(.hidden)

            // Outside the scroll view so Preferences and Quit never scroll away.
            separator
            footerBlock
                .padding(.bottom, 6)
                .frame(width: Self.preferredWidth, alignment: .leading)
        }
        .frame(width: Self.preferredWidth)
        .frame(maxHeight: isPreview ? .infinity : Self.maximumHeight)
        .background(panelSurface)
        .overlay(panelEdge)
        .environment(\.dropdownMetrics, metrics)
        // Child views draw with `Color.accentColor`, so this one tint themes them all;
        // `nil` keeps the system accent.
        .tint(PanelThemePolicy.accent(fromRaw: panelAccentRaw).tint)
        // Up/Down walk the interactive rows and Return activates the selection.
        // Escape is handled by `DropdownPanelWindow`.
        .focusable()
        .focusEffectDisabled()
        .focused($isPanelFocused)
        .onAppear { isPanelFocused = true }
        .onMoveCommand { direction in
            switch direction {
            case .up: moveSelection(.up)
            case .down: moveSelection(.down)
            default: break
            }
        }
        .onKeyPress(.return) { activateSelection() ? .handled : .ignored }
        .task { await panelClock() }
    }

    // MARK: - The panel's clock

    /// Advances `tickedNow` while the panel is on screen, on the same
    /// `StatusBarTickPolicy` cadence as the menu bar. Runs in `.task`, so closing
    /// the panel cancels it.
    private func panelClock() async {
        // Keeps a panel seeded with a fixed date (previews, tests) advancing from
        // that date instead of jumping to today; about 0 in production.
        let seedOffset = now.timeIntervalSinceNow
        let transitions = tickTransitions

        while !Task.isCancelled {
            let current = clock
            let delay = StatusBarTickPolicy.delay(
                now: current,
                until: StatusBarTickPolicy.nextFireDate(now: current, transitions: transitions)
            )
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            withAnimation(revealAnimation) {
                tickedNow = Date().addingTimeInterval(seedOffset)
            }
        }
    }

    /// Start and end instants of every event the panel can draw: today, tomorrow,
    /// and the meeting card's event.
    private var tickTransitions: [Date] {
        let events = state.todayEvents + state.tomorrowEvents + [state.nextEvent].compactMap { $0 }
        return StatusBarTickPolicy.transitionDates(
            boundaries: events.map {
                StatusBarTickPolicy.EventBoundary(start: $0.startDate, end: $0.endDate)
            },
            hideFinishedAfter: state.menu.hideFinishedEventsInMenu
                ? EventListWindow.endedGracePeriod
                : nil
        )
    }

    /// The instant all time-dependent content is drawn against: `now` until the
    /// first tick, the live clock afterwards.
    private var clock: Date { tickedNow ?? now }

    // MARK: - Composition

    /// The enabled modules in user order, minus any with nothing to render.
    private var visibleModules: [DropdownModule] {
        DropdownCompositionPolicy.resolve(
            order: dropdownModuleOrder,
            enabled: DropdownCompositionPolicy.enabledRawValues(
                greeting: state.showGreetingHeader,
                // The timeline style picker doubles as its on/off; see `TimelineSpan`.
                timeline: timelineStyle.isVisible,
                meeting: state.menu.showMeetingControlInMenu,
                agenda: state.menu.showAgendaInMenu,
                join: state.menu.showJoinSectionInMenu,
                bookmarks: state.menu.showBookmarksInMenu,
                calendar: state.menu.showCalendarInMenu
            )
        )
        .filter(hasContent)
    }

    /// Whether a module has anything to render.
    private func hasContent(_ module: DropdownModule) -> Bool {
        switch module {
        case .greeting: state.shouldShowGreetingHeader
        case .timeline: state.shouldShowTimeline
        case .meeting: true
        case .agenda: state.hasSelectedCalendars
        case .join: true
        case .bookmarks: !state.meetings.bookmarks.isEmpty
        case .calendar: state.hasSelectedCalendars
        }
    }

    @ViewBuilder
    private func moduleBlock(_ module: DropdownModule) -> some View {
        switch module {
        case .greeting: greetingBlock
        case .timeline: timelineBlock
        case .meeting: meetingBlock
        case .agenda: agendaBlock
        case .join: joinBlock
        case .bookmarks: bookmarksBlock
        case .calendar: calendarBlock
        }
    }

    /// Indices of modules that get a divider above them; see `DropdownSeparatorPolicy`.
    private var separatorIndices: Set<Int> {
        DropdownSeparatorPolicy.separatorIndices(for: visibleModules)
    }

    /// A divider inset to the row grid rather than full-bleed.
    private var separator: some View {
        Divider()
            .padding(.horizontal, metrics.rowOuterPadding)
            .padding(.vertical, 5)
    }

    // MARK: - Keyboard navigation

    /// A hostless description of the rendered rows, from which
    /// `DropdownPanelNavigation` derives the keyboard order.
    private var navigationContent: DropdownPanelContent {
        // Capped lists, so arrow keys never land on a row hidden behind "+N more".
        let today = capped(todayRenderedEvents, day: .today)
        let tomorrow = capped(tomorrowRenderedEvents, day: .tomorrow)
        return DropdownPanelContent(
            modules: visibleModules,
            meetingEventID: state.nextEvent?.id,
            todayEventIDs: today.shown.map(\.id),
            reminderIDs: state.todayReminders.map(\.id),
            tomorrowEventIDs: tomorrow.shown.map(\.id),
            todayHasHiddenEvents: today.hidden > 0,
            tomorrowHasHiddenEvents: tomorrow.hidden > 0,
            joinNextEventID: joinSectionEvent?.id,
            bookmarkCount: state.meetings.bookmarks.count,
            showsWhatsNew: showsWhatsNew
        )
    }

    private var navigationRows: [DropdownPanelRow] {
        DropdownPanelNavigation.interactiveRows(for: navigationContent)
    }

    private var selectedRow: DropdownPanelRow? {
        guard let selectionIndex, navigationRows.indices.contains(selectionIndex) else {
            return nil
        }
        return navigationRows[selectionIndex]
    }

    private func moveSelection(_ direction: DropdownPanelMoveDirection) {
        selectionIndex = DropdownPanelNavigation.next(
            from: selectionIndex,
            direction: direction,
            count: navigationRows.count
        )
    }

    /// Runs the selected row's primary action. Returns `false` when nothing is
    /// selected, so the key press falls through to AppKit.
    private func activateSelection() -> Bool {
        guard let selectedRow else { return false }
        switch selectedRow {
        case .meetingSummary(let id), .event(let id):
            guard let event = event(withID: id) else { return false }
            primaryAction(for: event)
        case .emptyStateAction:
            emptyStateAction()
        case .showMoreEvents(let day):
            // The only row that keeps the panel open.
            expandAgendaDay(day)
        case .reminder(let id):
            guard let reminder = state.todayReminders.first(where: { $0.id == id }) else {
                return false
            }
            perform { handlers.completeReminder(reminder) }()
        case .joinNext(let id):
            guard let event = event(withID: id) else { return false }
            perform { handlers.joinEvent(event) }()
        case .createMeeting:
            perform(handlers.createMeeting)()
        case .bookmark(let index):
            guard state.meetings.bookmarks.indices.contains(index) else { return false }
            let bookmark = state.meetings.bookmarks[index]
            perform { handlers.openBookmark(bookmark) }()
        case .whatsNew:
            perform(handlers.openChangelog)()
        case .preferences:
            perform(handlers.openPreferences)()
        case .quit:
            perform(handlers.quit)()
        }
        return true
    }

    private func event(withID id: String) -> MBEvent? {
        if let next = state.nextEvent, next.id == id { return next }
        return (state.todayEvents + state.tomorrowEvents).first { $0.id == id }
    }

    private func isSelected(_ row: DropdownPanelRow) -> Bool {
        selectedRow == row
    }

    // MARK: - Greeting

    @ViewBuilder
    private var greetingBlock: some View {
        if let summary = state.daySummary {
            DaySummaryHeaderView(
                greeting: greetingLine(summary.timeOfDay),
                summary: daySummaryLine(summary),
                symbolName: greetingSymbolName(summary.timeOfDay),
                actions: headerActions
            )
        }
    }

    /// The header's trailing quick actions: new meeting, command bar, preferences.
    private var headerActions: [DaySummaryHeaderAction] {
        [
            DaySummaryHeaderAction(
                id: "create",
                symbol: "plus",
                help: "status_bar_section_join_create_meeting".loco(),
                run: perform(handlers.createMeeting)
            ),
            DaySummaryHeaderAction(
                id: "search",
                symbol: "magnifyingglass",
                help: "command_bar_open".loco(),
                run: dismissThen(handlers.openCommandBar)
            ),
            DaySummaryHeaderAction(
                id: "preferences",
                symbol: "gearshape",
                help: "status_bar_preferences".loco(),
                run: perform(handlers.openPreferences)
            )
        ]
    }

    private func greetingLine(_ timeOfDay: GreetingTimeOfDay) -> String {
        let name = state.greetingName
        let key: String
        switch timeOfDay {
        case .morning:
            key = name == nil ? "menu_greeting_morning" : "menu_greeting_morning_named"
        case .afternoon:
            key = name == nil ? "menu_greeting_afternoon" : "menu_greeting_afternoon_named"
        case .evening:
            key = name == nil ? "menu_greeting_evening" : "menu_greeting_evening_named"
        }
        return name.map { key.loco($0) } ?? key.loco()
    }

    private func greetingSymbolName(_ timeOfDay: GreetingTimeOfDay) -> String {
        switch timeOfDay {
        case .morning: "sunrise.fill"
        case .afternoon: "sun.max.fill"
        case .evening: "moon.stars.fill"
        }
    }

    private func daySummaryLine(_ summary: DaySummary) -> String {
        // The `_dated` keys omit "today", which the leading date makes redundant.
        let dated = greetingShowsDate
        let countText: String
        switch summary.eventCount {
        case 0:
            countText = (dated ? "menu_day_summary_no_events_dated" : "menu_day_summary_no_events")
                .loco()
        case 1:
            countText = (dated
                ? "menu_day_summary_event_count_one_dated"
                : "menu_day_summary_event_count_one").loco(summary.eventCount)
        default:
            countText = (dated
                ? "menu_day_summary_event_count_other_dated"
                : "menu_day_summary_event_count_other").loco(summary.eventCount)
        }
        let freeText = "menu_day_summary_focus_time".loco(formattedFreeTime(summary.freeMinutes))
        guard dated else { return "\(countText) · \(freeText)" }
        return "\(greetingDateText(clock)) · \(countText) · \(freeText)"
    }

    /// Weekday and day number ("Tue 28"), with no month so the summary line fits
    /// the header without truncating.
    private func greetingDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = I18N.instance.locale
        formatter.setLocalizedDateFormatFromTemplate("Ed")
        return formatter.string(from: date)
    }

    private func formattedFreeTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0, mins > 0 { return "\(hours)h \(mins)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(mins)m"
    }

    // MARK: - Timeline

    // MARK: - Up next

    /// The countdown bar and label under the meeting card.
    ///
    /// Drawn only inside `MeetingProgressPolicy`'s fill window, which ends at the
    /// `eventActionHighlightMinutes` threshold shared with the menu bar.
    @ViewBuilder
    private func meetingProgressBar(_ event: MBEvent) -> some View {
        if showsMeetingCardProgress,
           let progress = MeetingProgressPolicy.presentation(
               start: event.startDate,
               end: event.endDate,
               now: clock,
               leadMinutes: eventActionHighlightMinutes
           ) {
            VStack(alignment: .leading, spacing: 5) {
                upNextBar(progress)
                HStack(spacing: 6) {
                    Spacer(minLength: 0)
                    Text(upNextCountdown(event))
                        .font(.system(size: metrics.secondaryFontSize - 1))
                        .foregroundStyle(progress.phase == .upcoming ? .secondary : Color.accentColor)
                        .monospacedDigit()
                }
            }
            .padding(.top, 2)
        }
    }

    private func upNextBar(_ progress: MeetingProgressPresentation) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.10))
                Capsule()
                    .fill(
                        progress.phase == .upcoming
                            ? Color.accentColor.opacity(0.55)
                            : Color.accentColor
                    )
                    .frame(width: progress.fraction * proxy.size.width)
            }
        }
        .frame(height: 4)
    }

    private func upNextCountdown(_ event: MBEvent) -> String {
        if event.startDate <= clock {
            return "dropdown_panel_up_next_now".loco()
        }
        let minutes = Int((event.startDate.timeIntervalSince(clock) / 60).rounded())
        if minutes >= 60 {
            return "dropdown_panel_up_next_in_hm".loco(minutes / 60, minutes % 60)
        }
        return "dropdown_panel_up_next_in_m".loco(max(minutes, 0))
    }

    // MARK: - Calendar

    /// A compact month grid in a card.
    ///
    /// Uses `CompactMonthGridView` because the window's `CalendarGridView` has a
    /// 460pt minimum width; both share `MonthGridLayout`.
    private var calendarBlock: some View {
        PanelCard {
            CompactMonthGridView(
                month: visibleCalendarMonth,
                now: clock,
                calendar: panelCalendar,
                markers: calendarMarkers,
                dateMarkers: DateMarkerCodec.decodeAll(storedDateMarkers),
                isWeekFold: calendarWeekFold,
                onStep: { step in
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
                        calendarMonthOffset += step
                    }
                },
                onSelect: { _ in handlers.openCalendar() },
                onToggleFold: {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
                        calendarWeekFold.toggle()
                        // The offset's unit changes with the fold (months vs weeks), so reset it.
                        calendarMonthOffset = 0
                    }
                },
                onReturnToToday: {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
                        calendarMonthOffset = 0
                    }
                },
                isSteppedAway: calendarMonthOffset != 0
            )
            // Keyed on fold and offset so stepping cancels the in-flight load
            // instead of letting two loads land out of order.
            .task(id: "\(calendarWeekFold)-\(calendarMonthOffset)") { await loadMonthMarkers() }
        }
    }

    private var panelCalendar: Calendar {
        CalendarGridViewModel.defaultCalendar()
    }

    /// The date the grid is anchored on. Steps by weeks when folded, months
    /// otherwise; see `MonthGridLayout.anchor`.
    private var visibleCalendarMonth: Date {
        MonthGridLayout.anchor(
            from: clock,
            offset: calendarMonthOffset,
            isWeekFold: calendarWeekFold,
            calendar: panelCalendar
        )
    }

    /// Event dots for the visible month: the fetched `monthMarkers`, with today and
    /// tomorrow filled from the snapshot so they show before the fetch completes.
    private var calendarMarkers: [Date: [Color]] {
        var byDay = monthMarkers
        for event in visibleEvents(state.todayEvents) + visibleEvents(state.tomorrowEvents) {
            let day = panelCalendar.startOfDay(for: event.startDate)
            guard byDay[day] == nil else { continue }
            byDay[day] = [calendarColor(for: event)]
        }
        return byDay
    }

    /// Fetches the visible month's events into `monthMarkers`, one colour per event
    /// per day. A failed fetch leaves the previous dots in place.
    private func loadMonthMarkers() async {
        let calendar = panelCalendar
        guard let interval = calendar.dateInterval(of: .month, for: visibleCalendarMonth) else {
            return
        }
        // Pad a week either side to cover the neighbouring months' days in the grid.
        let from = calendar.date(byAdding: .day, value: -7, to: interval.start) ?? interval.start
        let to = calendar.date(byAdding: .day, value: 7, to: interval.end) ?? interval.end

        guard let events = try? await handlers.fetchEvents(from, to) else { return }
        guard !Task.isCancelled else { return }

        var byDay: [Date: [Color]] = [:]
        for event in events {
            let day = calendar.startOfDay(for: event.startDate)
            byDay[day, default: []].append(calendarColor(for: event))
        }
        monthMarkers = byDay
    }

    private func calendarColor(for event: MBEvent) -> Color {
        Color(nsColor: event.displayColor)
    }

    /// The stored timeline style; an unrecognised value falls back to `.relative`.
    private var timelineStyle: TimelineSpan {
        TimelineSpan(rawValue: timelineStyleRaw) ?? .relative
    }

    private var timelineAppearance: TimelineAppearance {
        TimelineAppearance(rawValue: timelineAppearanceRaw) ?? .track
    }

    private var timelineBlock: some View {
        let timeline = DayRelativeTimelineView(
            segments: timelineSegments,
            currentDate: clock,
            timeFormat: state.timeFormat,
            style: timelineStyle,
            appearance: timelineAppearance
        )
        return PanelCard {
            timeline
                .frame(
                    width: Self.preferredWidth
                        - 2 * (metrics.rowOuterPadding + metrics.cardHorizontalPadding),
                    height: timeline.preferredHeight
                )
        }
    }

    private var timelineSegments: [DaySegment] {
        let startOfDay = Calendar.current.startOfDay(for: clock)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? clock
        let highlightedEventID = state.nextEvent?.id
        return visibleEvents(state.todayEvents).map { event in
            DaySegment(
                id: event.id,
                start: max(event.startDate, startOfDay),
                end: min(event.endDate, endOfDay),
                color: Color(nsColor: event.displayColor),
                isHighlighted: event.id == highlightedEventID,
                title: event.title
            )
        }
    }

    // MARK: - Meeting control

    @ViewBuilder
    private var meetingBlock: some View {
        if let event = state.nextEvent {
            let presentation = meetingSummaryPresentation(for: event)
            PanelCard {
                VStack(alignment: .leading, spacing: 0) {
                    MeetingSummaryView(
                        presentation: presentation,
                        onJoin: event.meetingLink == nil
                            ? nil
                            : { handlers.joinEvent(event); handlers.dismiss() },
                        isActionImminent: isActionImminent(event),
                        horizontalPadding: metrics.cardHighlightOutset,
                        highlightCornerRadius: metrics.cardHighlightCornerRadius
                    )
                    // Pulls the padded summary back into the card's content box: the
                    // text stays aligned with the rows below while its hover highlight
                    // and hit area extend into the card padding.
                    .padding(.horizontal, -metrics.cardHighlightOutset)
                    meetingProgressBar(event)
                }
                .background(
                    PanelHighlight(
                        isSelected: isSelected(.meetingSummary(event.id)),
                        isHovered: false,
                        cornerRadius: metrics.cardHighlightCornerRadius
                    )
                    .padding(.horizontal, -metrics.cardHighlightOutset)
                )
            }
            .contextMenu { eventContextMenu(event) }
            .id(DropdownPanelRow.meetingSummary(event.id))
        } else {
            emptyStateBlock
        }
    }

    /// The meeting card's copy from `MeetingSummaryPresenter`, with the service
    /// icon removed when `showMeetingServiceIcon` is off.
    private func meetingSummaryPresentation(for event: MBEvent) -> MeetingSummaryPresentation {
        var presentation = MeetingSummaryPresenter.presentation(
            for: event,
            timeFormat: state.timeFormat,
            now: clock,
            fields: meetingCardFields
        )
        if !state.menu.showMeetingServiceIcon {
            presentation.meetingService = nil
        }
        return presentation
    }

    private var meetingCardFields: MeetingCardFields {
        MeetingCardFields(
            showsSectionLine: meetingCardShowsSectionLine,
            showsTimes: meetingCardShowsTimes,
            showsProvider: meetingCardShowsProvider,
            showsSource: meetingCardShowsSource
        )
    }

    /// Why there is no meeting to show, plus the action that can fix it: a
    /// Preferences visit for repairable reasons, otherwise a refresh.
    @ViewBuilder
    private var emptyStateBlock: some View {
        let reason = state.emptyStateReason ?? .noUpcomingMeetings
        VStack(alignment: .leading, spacing: 2) {
            Text(emptyStateTitle(reason))
                .font(.system(size: metrics.rowFontSize, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, metrics.sectionHeaderInset)
                .padding(.vertical, 4)
            actionRow(
                symbol: emptyStateSymbol(reason),
                title: emptyStateActionTitle(reason),
                row: .emptyStateAction,
                action: emptyStateAction
            )
        }
    }

    private func emptyStateAction() {
        let reason = state.emptyStateReason ?? .noUpcomingMeetings
        if emptyStateIsRepairable(reason) {
            perform(handlers.openPreferences)()
        } else {
            perform(handlers.refresh)()
        }
    }

    private func emptyStateTitle(_ reason: StatusBarEmptyStateReason) -> String {
        switch reason {
        case .authRequired: "status_bar_control_auth_required".loco()
        case .permissionRequired: "status_bar_control_permission_required".loco()
        case .noCalendarsAvailable: "status_bar_control_no_calendars_available".loco()
        case .noCalendarsSelected: "status_bar_control_no_calendars".loco()
        case .refreshFailed: "status_bar_control_refresh_failed".loco()
        case .noUpcomingMeetings: "status_bar_control_no_upcoming".loco()
        }
    }

    private func emptyStateActionTitle(_ reason: StatusBarEmptyStateReason) -> String {
        switch reason {
        case .authRequired, .permissionRequired: "status_bar_quick_action_preferences".loco()
        case .noCalendarsAvailable: "status_bar_control_open_calendar_preferences".loco()
        case .noCalendarsSelected: "status_bar_control_select_calendars".loco()
        case .refreshFailed, .noUpcomingMeetings: "status_bar_section_refresh_sources".loco()
        }
    }

    private func emptyStateSymbol(_ reason: StatusBarEmptyStateReason) -> String {
        emptyStateIsRepairable(reason) ? "gearshape" : "arrow.clockwise"
    }

    /// Reasons a Preferences visit can fix (connect / grant / select calendars);
    /// the rest are transient and offer a refresh instead.
    private func emptyStateIsRepairable(_ reason: StatusBarEmptyStateReason) -> Bool {
        switch reason {
        case .authRequired, .permissionRequired, .noCalendarsAvailable, .noCalendarsSelected: true
        case .refreshFailed, .noUpcomingMeetings: false
        }
    }

    // MARK: - Agenda

    private var showsTomorrowSection: Bool {
        // Counts drawn events, not raw ones. Summary mode draws no rows, so it
        // counts the visible list instead.
        let renderedCount = tomorrowDisplayMode == .today_n_tomorrow_summary
            ? visibleEvents(state.tomorrowEvents).count
            : tomorrowRenderedEvents.count
        return AgendaSectionVisibilityPolicy.showsSection(
            eventCount: renderedCount,
            isIncludedByPeriod: state.events.showEventsForPeriod.includesTomorrow,
            hidesEmptyDays: hidesEmptyAgendaDays,
            isAnchorDay: false
        )
    }

    private var tomorrowDisplayMode: ShowEventsForPeriod {
        state.events.showEventsForPeriod
    }

    /// Tomorrow's events as rendered before the row cap; read by both `agendaBlock`
    /// and `navigationContent`. Empty in summary mode.
    private var tomorrowRenderedEvents: [MBEvent] {
        DropdownEventVisibility.tomorrowRendered(
            state.tomorrowEvents,
            menu: state.menu,
            display: state.events,
            isDeclined: isDeclined,
            now: clock
        )
    }

    private var todayRenderedEvents: [MBEvent] {
        visibleEvents(state.todayEvents)
    }

    /// Splits a section's events into the ones it draws and the number it holds
    /// back. A section the user has expanded, or a cap of `0`, withholds nothing.
    private func capped(_ events: [MBEvent], day: AgendaDay) -> (shown: [MBEvent], hidden: Int) {
        let limit = dropdownMaxEventRows
        guard limit > 0, !expandedAgendaDays.contains(day), events.count > limit else {
            return (events, 0)
        }
        return (Array(events.prefix(limit)), events.count - limit)
    }

    private var agendaBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            dateSection(
                title: "status_bar_section_today".loco(),
                date: clock,
                events: todayRenderedEvents,
                day: .today
            )
            remindersRows
            if showsTomorrowSection {
                separator
                let tomorrowDate = Calendar.current.date(byAdding: .day, value: 1, to: clock) ?? clock
                switch tomorrowDisplayMode {
                case .today_n_tomorrow, .today_n_tomorrow_next:
                    dateSection(
                        title: "status_bar_section_tomorrow".loco(),
                        date: tomorrowDate,
                        events: tomorrowRenderedEvents,
                        day: .tomorrow
                    )
                case .today_n_tomorrow_summary:
                    tomorrowSummarySection(
                        date: tomorrowDate,
                        events: visibleEvents(state.tomorrowEvents)
                    )
                default:
                    EmptyView()
                }
            }
        }
    }

    @ViewBuilder
    private func tomorrowSummarySection(date: Date, events: [MBEvent]) -> some View {
        let title = "status_bar_section_tomorrow".loco()
        sectionHeader(title, date: date)
        Text(DropdownEventVisibility.tomorrowSummaryText(visibleTomorrowEvents: events))
            .font(.system(size: metrics.rowFontSize))
            .foregroundStyle(.secondary)
            .padding(.horizontal, metrics.sectionHeaderInset)
            .padding(.vertical, 4)
    }

    @ViewBuilder
    private func dateSection(
        title: String,
        date: Date,
        events: [MBEvent],
        day: AgendaDay
    ) -> some View {
        sectionHeader(title, date: date, showsCreateAction: showsAgendaCreateAction(day))
        if events.isEmpty {
            Text("status_bar_section_date_nothing".loco(title.lowercased()))
                .font(.system(size: metrics.rowFontSize))
                .foregroundStyle(.secondary)
                .padding(.horizontal, metrics.sectionHeaderInset)
                .padding(.vertical, 4)
        }
        let section = capped(events, day: day)
        ForEach(section.shown, id: \.id) { event in
            eventRow(event)
        }
        if section.hidden > 0 {
            showMoreRow(day: day, hidden: section.hidden)
        }
    }

    /// A row that reveals the events the cap withheld, in place. One-way: the
    /// panel reopens capped.
    private func showMoreRow(day: AgendaDay, hidden: Int) -> some View {
        actionRow(
            symbol: "chevron.down",
            title: hidden == 1
                ? "status_bar_section_show_more_events_one".loco(hidden)
                : "status_bar_section_show_more_events_other".loco(hidden),
            row: .showMoreEvents(day),
            action: { expandAgendaDay(day) }
        )
    }

    private func expandAgendaDay(_ day: AgendaDay) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
            _ = expandedAgendaDays.insert(day)
        }
    }

    // MARK: - Event row

    private func eventRow(_ event: MBEvent) -> some View {
        let row = DropdownPanelRow.event(event.id)
        return VStack(alignment: .leading, spacing: 0) {
            PanelRow(isSelected: isSelected(row), action: { primaryAction(for: event) }) { hovering in
                eventRowContent(event, isHovered: hovering)
            }
            if isExpanded(event) {
                eventDetails(event)
            }
        }
        .contextMenu { eventContextMenu(event) }
        .id(row)
    }

    private func eventRowContent(_ event: MBEvent, isHovered: Bool) -> some View {
        let layout = agendaRowLayout
        let appearance = rowAppearance(for: event)
        return HStack(spacing: metrics.columnSpacing) {
            if layout.timeColumnWidth > 0 {
                eventTimeColumn(event, width: layout.timeColumnWidth)
            }
            // `agendaRowLayout` never resolves to `.farLeft`, so only the in-row marker is drawn.
            if layout.resolvedPosition == .betweenTimeAndTitle,
                let markerFrame = layout.markerFrame {
                calendarMarker(
                    event,
                    marker: layout.marker,
                    frame: markerFrame,
                    isHollow: appearance.markerIsHollow
                )
            }
            if layout.serviceIconOrigin != nil {
                serviceIcon(event)
            }
            // The fade masks this full-width box, not the Text, so short titles
            // never reach the faded zone.
            HStack(spacing: 6) {
                // Without priority the Spacer takes about half the width and truncates the title.
                eventTitle(event, appearance: appearance)
                    .layoutPriority(1)
                if appearance.isRunning, appearance.showsActiveEmphasis {
                    runningBadge
                }
                Spacer(minLength: 0)
            }
            .mask(titleFadeMask)
            trailingAffordance(event, isHovered: isHovered)
            disclosureChevron(event, isHovered: isHovered)
        }
    }

    /// Fades the last 20pt of the title area where it meets the trailing controls.
    /// Truncation still applies underneath for very long titles.
    private var titleFadeMask: some View {
        HStack(spacing: 0) {
            Rectangle()
            LinearGradient(
                colors: [.black, .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 20)
        }
    }

    /// The row grid for the current preferences. `showEventCalendarColor` selects
    /// a dot or no marker; marker shape and position are not user-settable.
    private var agendaRowLayout: AgendaRowLayout {
        AgendaRowLayout.resolve(
            metrics: metrics,
            marker: state.menu.showEventCalendarColor ? .dot : .none,
            position: .betweenTimeAndTitle,
            timeColumn: agendaTimeColumn,
            showsServiceIcon: state.menu.showMeetingServiceIcon
        )
    }

    private var agendaTimeColumn: AgendaTimeColumn {
        state.statusBar.showEventEndTime ? .startAndEnd : .startOnly
    }

    /// Start time, with the end time stacked underneath when enabled; see
    /// `DropdownMetrics.timeColumnWidth(for:)`.
    private func eventTimeColumn(_ event: MBEvent, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(eventStartText(event))
            if let endText = eventEndText(event) {
                Text(endText)
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.system(size: metrics.secondaryFontSize).monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(width: width, alignment: .leading)
    }

    @ViewBuilder
    private func calendarMarker(
        _ event: MBEvent,
        marker: AgendaMarker,
        frame: AgendaRowLayout.MarkerFrame,
        isHollow: Bool
    ) -> some View {
        let color = Color(nsColor: event.displayColor)
        Group {
            switch marker {
            case .none:
                EmptyView()
            case .dot:
                if isHollow {
                    Circle().strokeBorder(color, lineWidth: 1.5)
                } else {
                    Circle().fill(color)
                }
            case .leftBorderBar:
                Capsule().fill(color)
            }
        }
        .frame(width: frame.width, height: frame.height)
    }

    /// The meeting service's logo in a fixed slot, left empty when the event has
    /// no link so titles stay aligned.
    private func serviceIcon(_ event: MBEvent) -> some View {
        Group {
            if let link = event.meetingLink {
                Image(nsImage: getIconForMeetingService(link.service))
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: metrics.serviceIconWidth, height: metrics.serviceIconWidth)
    }

    private func eventTitle(_ event: MBEvent, appearance: EventRowAppearance) -> some View {
        Text(eventTitleText(event))
            .font(.system(
                size: metrics.rowFontSize,
                weight: appearance.isRunning && appearance.showsActiveEmphasis
                    ? .semibold
                    : .regular
            ))
            .foregroundStyle(appearance.isDimmed ? Color.secondary : Color.primary)
            .strikethrough(appearance.isStruckThrough)
            .lineLimit(1)
    }

    /// The glyph shown after the title of a meeting in progress.
    private var runningBadge: some View {
        Image(nsImage: MenuStyleConstants.iconNamed(MenuStyleConstants.runningIconName))
            .resizable()
            .scaledToFit()
            .frame(width: 11, height: 11)
            .accessibilityLabel("status_bar_control_current_meeting".loco())
    }

    /// The row title, shortened via `StatusBarTitlePolicy.shortenTitle` when enabled
    /// and prefixed with the dismissed mark. Unshortened titles have no length cap;
    /// the fixed-width row truncates them visually.
    private func eventTitleText(_ event: MBEvent) -> String {
        let rawTitle: String? = event.title.isEmpty ? nil : event.title
        var title = state.menu.shortenEventTitle
            ? StatusBarTitlePolicy.shortenTitle(
                rawTitle,
                limit: state.menu.menuEventTitleLength,
                noTitle: "status_bar_no_title".loco()
            )
            : rawTitle ?? "status_bar_no_title".loco()
        if isDismissed(event) {
            title = "[\("status_bar_event_dismissed_mark".loco())] \(title)"
        }
        return title
    }

    // MARK: - Event row appearance

    /// How an agenda row is styled for its event's status and the appearance preferences.
    private struct EventRowAppearance {
        var isDimmed = false
        var isStruckThrough = false
        var isRunning = false
        /// False for declined and inactive personal events, which get no running
        /// badge or bold weight.
        var showsActiveEmphasis = true
        /// The `.show_underlined` style: SwiftUI cannot draw AppKit's dotted by-word
        /// underline, so the calendar marker is drawn hollow instead.
        var markerIsHollow = false
    }

    private func rowAppearance(for event: MBEvent) -> EventRowAppearance {
        var appearance = EventRowAppearance()
        appearance.isRunning = event.startDate <= clock && event.endDate > clock

        if isDeclined(event) {
            if state.events.declinedEventsAppearance == .show_inactive {
                appearance.isDimmed = true
            } else {
                appearance.isStruckThrough = true
            }
            appearance.showsActiveEmphasis = false
        }

        if !event.isAllDay,
            state.events.nonAllDayEvents == .show_inactive_without_meeting_link,
            event.meetingLink == nil {
            appearance.isDimmed = true
        }

        applyParticipationStyle(
            statusMatches: event.participationStatus == .pending,
            showInactive: state.events.showPendingEvents == .show_inactive,
            showUnderlined: state.events.showPendingEvents == .show_underlined,
            to: &appearance
        )
        applyParticipationStyle(
            statusMatches: event.participationStatus == .tentative,
            showInactive: state.events.showTentativeEvents == .show_inactive,
            showUnderlined: state.events.showTentativeEvents == .show_underlined,
            to: &appearance
        )

        if event.attendees.isEmpty, state.events.personalEventsAppearance == .show_inactive {
            appearance.isDimmed = true
            appearance.showsActiveEmphasis = false
        }

        if event.endDate < clock, state.events.pastEventsAppearance == .show_inactive {
            appearance.isDimmed = true
        }

        return appearance
    }

    private func applyParticipationStyle(
        statusMatches: Bool,
        showInactive: Bool,
        showUnderlined: Bool,
        to appearance: inout EventRowAppearance
    ) {
        guard statusMatches else { return }
        if showInactive {
            appearance.isDimmed = true
        } else if showUnderlined {
            appearance.markerIsHollow = true
        }
    }

    private func isDeclined(_ event: MBEvent) -> Bool {
        event.participationStatus == .declined || event.status == .canceled
    }

    /// A video glyph that swaps for a Join pill on hover or selection.
    @ViewBuilder
    private func trailingAffordance(_ event: MBEvent, isHovered: Bool) -> some View {
        if event.meetingLink != nil {
            let revealed = isHovered || isSelected(.event(event.id))
            let actionable = isActionImminent(event)
            Image(systemName: "video.fill")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .opacity(revealed ? 0 : 1)
                // Only the glyph takes layout; the wider pill is an overlay so the row never reflows.
                .frame(width: metrics.trailingGlyphWidth, alignment: .trailing)
                .overlay(alignment: .trailing) {
                    Text("notifications_meetingbar_join_event_action".loco())
                        .font(.system(size: 10, weight: actionable ? .semibold : .regular))
                        .foregroundStyle(
                            actionable ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary)
                        )
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .joinControlSurface(isActionImminent: actionable)
                        .fixedSize()
                        .opacity(revealed ? 1 : 0)
                        .contentShape(Capsule())
                        .onTapGesture(perform: perform { handlers.joinEvent(event) })
                        // Otherwise the invisible pill swallows clicks meant for the row.
                        .allowsHitTesting(revealed)
                }
                .animation(revealAnimation, value: revealed)
                .animation(revealAnimation, value: actionable)
        }
    }

    /// Whether the event's action is imminent per `EventActionProminence`,
    /// evaluated against the live clock.
    private func isActionImminent(_ event: MBEvent) -> Bool {
        EventActionProminence.isImminent(
            start: event.startDate,
            end: event.endDate,
            now: clock,
            leadMinutes: eventActionHighlightMinutes
        )
    }

    /// The inline-details chevron, visible on hover, selection or expansion.
    ///
    /// Deliberately ignores `showEventDetails`: expansion is on demand and costs
    /// nothing while collapsed.
    private func disclosureChevron(_ event: MBEvent, isHovered: Bool) -> some View {
        let expanded = isExpanded(event)
        let revealed = isHovered || isSelected(.event(event.id)) || expanded
        return Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(expanded ? 90 : 0))
            .opacity(revealed ? 1 : 0)
            .frame(width: 14, height: 14)
            .contentShape(Rectangle())
            .onTapGesture { toggleExpansion(event) }
            .help(expanded
                ? "dropdown_panel_hide_details".loco()
                : "dropdown_panel_show_details".loco())
            .animation(revealAnimation, value: revealed)
    }

    private func isExpanded(_ event: MBEvent) -> Bool {
        expandedEventIDs.contains(event.id)
    }

    private func toggleExpansion(_ event: MBEvent) {
        withAnimation(revealAnimation) {
            if expandedEventIDs.contains(event.id) {
                expandedEventIDs.remove(event.id)
            } else {
                expandedEventIDs.insert(event.id)
            }
        }
    }

    /// A row's primary action: join when there is a meeting link, otherwise open
    /// the inline details.
    private func primaryAction(for event: MBEvent) {
        if event.meetingLink != nil {
            perform { handlers.joinEvent(event) }()
        } else {
            toggleExpansion(event)
        }
    }

    // MARK: - Inline event details

    @ViewBuilder
    private func eventDetails(_ event: MBEvent) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            detailRow(symbol: "clock", text: timeRangeText(event))
            if let location = event.location, !location.isEmpty {
                detailRow(symbol: "mappin.and.ellipse", text: location)
            }
            if let organizer = event.organizer {
                detailRow(
                    symbol: "person.crop.circle",
                    text: "status_bar_submenu_organizer_title".loco(organizer.name),
                    copyValue: organizer.email ?? organizer.name
                )
            }
            attendeeDetails(event)
            notesDetail(event)
            prepLinkDetails(event)
        }
        .padding(.leading, metrics.detailIndent)
        .padding(.trailing, metrics.sectionHeaderInset)
        .padding(.bottom, 4)
    }

    /// Meeting-prep links in the inline details (also in the context menu).
    @ViewBuilder
    private func prepLinkDetails(_ event: MBEvent) -> some View {
        let links = prepLinks(for: event)
        if !links.isEmpty {
            detailLabel(sectionLabel("status_bar_submenu_prep_links_title"))
            ForEach(links, id: \.url) { link in
                if let url = URL(string: link.url) {
                    prepLinkRow(title: link.displayTitle, url: url)
                }
            }
        }
    }

    private func prepLinkRow(title: String, url: URL) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "link")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(width: 12)
            Text(title)
                .font(.system(size: metrics.rowFontSize - 1))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .pointerStyle(.link)
        .onTapGesture(perform: perform { handlers.openURL(url) })
        .help(url.absoluteString)
    }

    @ViewBuilder
    private func attendeeDetails(_ event: MBEvent) -> some View {
        if !event.attendees.isEmpty {
            let attendees = event.attendees.sorted { $0.status.rawValue < $1.status.rawValue }
            detailLabel("status_bar_submenu_attendees_title".loco(attendees.count))
            ForEach(attendees, id: \.self) { attendee in
                detailRow(
                    symbol: nil,
                    text: attendeeTitle(attendee),
                    copyValue: attendee.email ?? attendee.name
                )
            }
        }
    }

    private func attendeeTitle(_ attendee: MBEventAttendee) -> String {
        let name = attendee.isCurrentUser
            ? "status_bar_submenu_attendees_you".loco(attendee.name)
            : attendee.name
        switch attendee.status {
        case .tentative:
            return name + "status_bar_submenu_attendees_status_tentative".loco()
        case .pending:
            return name + "status_bar_submenu_attendees_status_unknown".loco()
        default:
            return name
        }
    }

    @ViewBuilder
    private func notesDetail(_ event: MBEvent) -> some View {
        if let rawNotes = event.notes {
            let notes = cleanUpNotes(rawNotes).trimmingCharacters(in: .whitespacesAndNewlines)
            if !notes.isEmpty {
                detailLabel(sectionLabel("status_bar_submenu_notes_title"))
                detailRow(symbol: nil, text: notes, lineLimit: 6)
            }
        }
    }

    private func detailLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: metrics.rowFontSize - 2, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 3)
    }

    /// One click-to-copy detail line. Copying leaves the panel open.
    private func detailRow(
        symbol: String?,
        text: String,
        copyValue: String? = nil,
        lineLimit: Int = 2
    ) -> some View {
        HStack(alignment: .top, spacing: 6) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(width: 12)
            }
            Text(text)
                .font(.system(size: metrics.rowFontSize - 1))
                .foregroundStyle(.secondary)
                .lineLimit(lineLimit)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture { handlers.copyText(copyValue ?? text) }
        .help("status_bar_submenu_click_to_copy".loco())
    }

    private func timeRangeText(_ event: MBEvent) -> String {
        guard !event.isAllDay else { return "status_bar_event_start_time_all_day".loco() }
        let minutes = String(Int(event.endDate.timeIntervalSince(event.startDate) / 60))
        return "status_bar_submenu_duration_all_day".loco(
            clockText(event.startDate),
            clockText(event.endDate),
            minutes
        )
    }

    /// Submenu of per-event reminder presets, including an explicit return to the
    /// global default.
    @ViewBuilder
    private func reminderMenu(_ event: MBEvent) -> some View {
        Menu("status_bar_submenu_remind_me".loco()) {
            Button("status_bar_submenu_remind_default".loco()) {
                perform { handlers.setReminderOverride(event, nil) }()
            }
            Button("status_bar_submenu_remind_never".loco()) {
                perform { handlers.setReminderOverride(event, .suppressed) }()
            }
            Divider()
            Button("status_bar_submenu_remind_at_start".loco()) {
                perform { handlers.setReminderOverride(event, .offset(0)) }()
            }
            ForEach([1, 5, 10, 15, 30, 60], id: \.self) { minutes in
                Button("status_bar_submenu_remind_minutes".loco(minutes)) {
                    perform {
                        handlers.setReminderOverride(event, .offset(TimeInterval(minutes * 60)))
                    }()
                }
            }
        }
    }

    // MARK: - Per-event context menu

    @ViewBuilder
    private func eventContextMenu(_ event: MBEvent) -> some View {
        if event.meetingLink != nil {
            Button("notifications_meetingbar_join_event_action".loco()) {
                perform { handlers.joinEvent(event) }()
            }
            Button("status_bar_submenu_copy_meeting_link".loco()) {
                perform { handlers.copyMeetingLink(event) }()
            }
            if let identifier = event.meetingIdentifier {
                Button(identifier.kind == .room
                    ? "status_bar_submenu_copy_meeting_room".loco()
                    : "status_bar_submenu_copy_meeting_id".loco()) {
                    perform { handlers.copyMeetingIdentifier(event) }()
                }
            }
        }
        alternateLinksMenu(event)
        prepLinksMenu(event)
        reminderMenu(event)
        Divider()
        Button("status_bar_submenu_email_attendees".loco()) {
            perform { handlers.emailAttendees(event) }()
        }
        if isDismissed(event) {
            Button("status_bar_submenu_undismiss_meeting".loco()) {
                perform { handlers.undismissEvent(event) }()
            }
        } else {
            Button("status_bar_submenu_dismiss_meeting".loco()) {
                perform { handlers.dismissEvent(event) }()
            }
        }
        // EventKit only: the event writer targets EKEventStore.
        if state.activeProvider == .macOSEventKit {
            Divider()
            Button("status_bar_submenu_edit_event".loco()) {
                dismissThen { handlers.editEvent(event) }()
            }
            Button("status_bar_submenu_delete_event".loco(), role: .destructive) {
                // Dismiss first, or the floating panel covers the confirmation alert.
                dismissThen { handlers.deleteEvent(event) }()
            }
        }
    }

    @ViewBuilder
    private func alternateLinksMenu(_ event: MBEvent) -> some View {
        if !event.alternateMeetingLinkCandidates.isEmpty {
            Menu("status_bar_join_with_other_link".loco()) {
                ForEach(event.alternateMeetingLinkCandidates, id: \.self) { candidate in
                    Button(alternateMeetingLinkTitle(candidate)) {
                        perform { handlers.openURL(candidate.url) }()
                    }
                }
            }
        }
    }

    private func alternateMeetingLinkTitle(_ candidate: MeetingLinkCandidate) -> String {
        let service = candidate.service?.localizedValue ?? "constants_meeting_service_other".loco()
        guard let host = candidate.url.host else { return service }
        return "\(service) - \(host)"
    }

    /// Submenu of meeting-prep links from the invite.
    @ViewBuilder
    private func prepLinksMenu(_ event: MBEvent) -> some View {
        let links = prepLinks(for: event)
        if !links.isEmpty {
            Menu(sectionLabel("status_bar_submenu_prep_links_title")) {
                ForEach(links, id: \.url) { link in
                    if let url = URL(string: link.url) {
                        Button(link.displayTitle) {
                            perform { handlers.openURL(url) }()
                        }
                    }
                }
            }
        }
    }

    /// Prep links extracted by `MeetingPrepLinks`; empty when `showMeetingPrepLinks` is off.
    private func prepLinks(for event: MBEvent) -> [PrepLink] {
        guard state.menu.showMeetingPrepLinks else { return [] }
        return MeetingPrepLinks.extract(
            notes: event.notes,
            location: event.location,
            excluding: [event.meetingLink?.url, event.url].compactMap { $0?.absoluteString }
        )
    }

    private func isDismissed(_ event: MBEvent) -> Bool {
        state.events.dismissedEvents.contains { $0.id == event.id }
    }

    // MARK: - Reminders

    /// Today's reminders. Clicking the row or its checkbox completes it; the context
    /// menu offers Complete, Snooze and Open in Reminders.
    @ViewBuilder
    private var remindersRows: some View {
        if !state.todayReminders.isEmpty {
            sectionHeader("status_bar_section_reminders".loco())
            ForEach(state.todayReminders, id: \.id) { reminder in
                reminderRow(reminder)
            }
        }
    }

    private func reminderRow(_ reminder: MBReminder) -> some View {
        let row = DropdownPanelRow.reminder(reminder.id)
        return PanelRow(
            isSelected: isSelected(row),
            action: perform { handlers.completeReminder(reminder) }
        ) { _ in
            HStack(spacing: metrics.columnSpacing) {
                Text(reminderTimeText(reminder))
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: metrics.timeColumnWidth, alignment: .leading)
                Image(systemName: reminder.isCompleted ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: perform { handlers.completeReminder(reminder) })
                    .help("status_bar_reminders_complete".loco())
                Text(reminder.title.isEmpty ? "status_bar_no_title".loco() : reminder.title)
                    .font(.system(size: metrics.rowFontSize))
                    .foregroundStyle(reminder.isOverdue ? Color.red : Color.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
        .contextMenu { reminderContextMenu(reminder) }
        .id(row)
    }

    @ViewBuilder
    private func reminderContextMenu(_ reminder: MBReminder) -> some View {
        Button("status_bar_reminders_complete".loco()) {
            perform { handlers.completeReminder(reminder) }()
        }
        Menu("status_bar_reminders_snooze".loco()) {
            ForEach(ReminderSnoozeOption.allCases, id: \.rawValue) { option in
                Button(reminderSnoozeOptionTitle(option)) {
                    perform { handlers.snoozeReminder(reminder, option) }()
                }
            }
        }
        Divider()
        Button("status_bar_reminders_open_in_reminders".loco()) {
            dismissThen { handlers.openReminderInApp(reminder) }()
        }
    }

    private func reminderSnoozeOptionTitle(_ option: ReminderSnoozeOption) -> String {
        switch option {
        case .laterToday: "status_bar_reminders_snooze_later_today".loco()
        case .thisEvening: "status_bar_reminders_snooze_this_evening".loco()
        case .tomorrow: "status_bar_reminders_snooze_tomorrow".loco()
        }
    }

    // MARK: - Join

    /// The event the join module's "Join …" row acts on, when it renders one.
    private var joinSectionEvent: MBEvent? {
        guard let nextEvent = state.nextEvent, nextEvent.meetingLink != nil else { return nil }
        return nextEvent
    }

    @ViewBuilder
    private var joinBlock: some View {
        if let nextEvent = joinSectionEvent {
            actionRow(
                symbol: "video.fill",
                title: nextEvent.startDate < clock
                    ? "status_bar_section_join_current_meeting".loco()
                    : "status_bar_section_join_next_meeting".loco(),
                row: .joinNext(nextEvent.id),
                action: { perform { handlers.joinEvent(nextEvent) }() }
            )
        }
        actionRow(
            symbol: "plus.circle",
            title: "status_bar_section_join_create_meeting".loco(),
            row: .createMeeting,
            action: perform(handlers.createMeeting)
        )
        moreActionsRow
    }

    // MARK: - More actions

    /// The "More actions" row, which flies out an `NSMenu` of utility actions on
    /// click or hover.
    ///
    /// A plain `PanelRow` rather than a SwiftUI `Menu`: `Menu`'s button container adds
    /// insets (not removable via `.menuStyle`/`.menuIndicator`) that break the row grid.
    /// Deliberately absent from `DropdownPanelNavigation`, so arrow keys only land on
    /// rows that Return completes.
    private var moreActionsRow: some View {
        PanelRow(action: { openMoreActionsMenu() }) { _ in
            actionRowContent(
                symbol: "ellipsis.circle",
                title: "dropdown_panel_more_actions".loco(),
                trailingSymbol: "chevron.right"
            )
        }
        .background(MenuAnchorView(box: moreActionsAnchor))
        .onHover { hovering in
            if hovering {
                scheduleMoreActionsMenu()
            } else {
                cancelMoreActionsHover()
            }
        }
    }

    /// Opens the flyout after `moreActionsHoverDelay`, like an AppKit submenu,
    /// unless hover is disarmed.
    @MainActor
    private func scheduleMoreActionsMenu() {
        guard !moreActionsHoverDisarmed else { return }
        moreActionsHoverTimer?.cancel()
        let work = DispatchWorkItem { openMoreActionsMenu() }
        moreActionsHoverTimer = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.moreActionsHoverDelay,
            execute: work
        )
    }

    /// Cancels a pending spring-open and re-arms hover for the next entry.
    @MainActor
    private func cancelMoreActionsHover() {
        moreActionsHoverTimer?.cancel()
        moreActionsHoverTimer = nil
        moreActionsHoverDisarmed = false
    }

    private var panelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
    }

    /// The panel's background. Clear in the real panel, which sits on
    /// `PanelBackdrop`'s `NSVisualEffectView`; a SwiftUI material in the Preferences
    /// preview, which has no backdrop.
    @ViewBuilder
    private var panelSurface: some View {
        if isPreview {
            panelShape.fill(.regularMaterial)
        } else {
            // Any fill here would cover the AppKit vibrancy beneath.
            Color.clear
        }
    }

    /// A hairline edge so the panel separates from a light desktop.
    private var panelEdge: some View {
        panelShape.strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
    }

    /// Shows the More-actions flyout beside the row, like a submenu. Blocks until
    /// the menu closes.
    @MainActor
    private func openMoreActionsMenu() {
        guard let anchor = moreActionsAnchor.view else { return }
        moreActionsHoverTimer?.cancel()
        moreActionsHoverTimer = nil
        // The anchor is flipped, so (width, 0) is its top-right corner.
        let menu = makeMoreActionsMenu()
        // Closes the flyout when the pointer returns to the panel.
        let watchdog = MenuExitWatchdog(menu: menu, anchor: anchor)
        watchdog.start()
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: anchor.bounds.width, y: 0),
            in: anchor
        )
        // `popUp` returns only after the menu closes, usually with the pointer still
        // on the row; disarm hover so the flyout does not reopen at once.
        watchdog.stop()
        moreActionsHoverDisarmed = true
    }

    /// Builds the More-actions flyout: dismiss actions, clipboard join, menu-bar
    /// title toggle, window openers and refresh.
    ///
    /// Internal rather than private so `MoreActionsMenuTests` can check the item sequence.
    @MainActor
    func makeMoreActionsMenu() -> NSMenu {
        let menu = NSMenu(title: "dropdown_panel_more_actions".loco())
        // Nothing in the responder chain validates these closure items, so AppKit
        // would grey them all out.
        menu.autoenablesItems = false

        if state.nextEvent != nil {
            menu.addItem(ClosureMenuItem(
                title: dismissNextMeetingTitle,
                handler: perform(handlers.dismissNextMeeting)
            ))
        }
        if !state.events.dismissedEvents.isEmpty {
            menu.addItem(ClosureMenuItem(
                title: "status_bar_menu_remove_all_dismissals".loco(),
                handler: perform(handlers.undismissAllMeetings)
            ))
        }
        if state.nextEvent != nil || !state.events.dismissedEvents.isEmpty {
            menu.addItem(.separator())
        }

        let clipboardItem = ClosureMenuItem(
            title: "status_bar_section_join_from_clipboard".loco(),
            handler: perform(handlers.openLinkFromClipboard)
        )
        // Display only: `StatusBarItemController` already registers the global shortcut.
        clipboardItem.setShortcut(for: .openClipboardShortcut)
        menu.addItem(clipboardItem)

        if let titleLabel = meetingTitleVisibilityTitle {
            let toggleItem = ClosureMenuItem(
                title: titleLabel,
                handler: perform(handlers.toggleMeetingTitleVisibility)
            )
            toggleItem.setShortcut(for: .toggleMeetingTitleVisibilityShortcut)
            menu.addItem(toggleItem)
        }
        menu.addItem(.separator())

        menu.addItem(ClosureMenuItem(
            title: "status_bar_quick_action_open_calendar".loco(),
            handler: dismissThen(handlers.openCalendar)
        ))
        menu.addItem(ClosureMenuItem(
            title: "status_bar_quick_action_camera_check".loco(),
            handler: dismissThen(handlers.openCameraPreview)
        ))
        menu.addItem(ClosureMenuItem(
            title: "status_bar_quick_action_world_clock".loco(),
            handler: dismissThen(handlers.openWorldClock)
        ))
        menu.addItem(.separator())

        menu.addItem(ClosureMenuItem(
            title: "status_bar_section_refresh_sources".loco(),
            handler: perform(handlers.refresh)
        ))
        return menu
    }

    /// The dismiss item's title, which says "current" once the meeting has started.
    private var dismissNextMeetingTitle: String {
        guard let start = state.nextEvent?.startDate, start < clock else {
            return "status_bar_menu_dismiss_next_meeting".loco()
        }
        return "status_bar_menu_dismiss_curent_meeting".loco()
    }

    /// The title-visibility toggle's label, or `nil` (no item) when the menu bar
    /// shows neither a real nor a generic title.
    private var meetingTitleVisibilityTitle: String? {
        switch state.statusBar.eventTitleFormat {
        case .show: "status_bar_hide_meeting_names".loco()
        case .generic: "status_bar_show_meeting_names".loco()
        case .dot, .none: nil
        }
    }

    // MARK: - Bookmarks

    private var bookmarksBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("status_bar_section_bookmarks_title".loco())
            ForEach(Array(state.meetings.bookmarks.enumerated()), id: \.element) { index, bookmark in
                actionRow(
                    symbol: "bookmark.fill",
                    title: bookmark.name,
                    row: .bookmark(index),
                    action: perform { handlers.openBookmark(bookmark) }
                )
            }
        }
    }

    // MARK: - Pinned footer

    /// Whether the running major version differs from the acknowledged one.
    private var showsWhatsNew: Bool {
        compareVersions(state.appMajorVersion, state.lastRevisedMajorVersion)
    }

    private var footerBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsWhatsNew {
                actionRow(
                    symbol: "sparkles",
                    title: "status_bar_whats_new".loco(),
                    row: .whatsNew,
                    action: perform(handlers.openChangelog)
                )
            }
            actionRow(
                symbol: "gearshape",
                title: "\("status_bar_preferences".loco())…",
                row: .preferences,
                action: perform(handlers.openPreferences)
            )
            actionRow(
                symbol: "power",
                title: "status_bar_quit".loco(),
                row: .quit,
                action: perform(handlers.quit)
            )
        }
    }

    // MARK: - Shared row chrome

    private func actionRow(
        symbol: String,
        title: String,
        row: DropdownPanelRow,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        PanelRow(isSelected: isSelected(row), action: action) { _ in
            actionRowContent(symbol: symbol, title: title)
        }
        .id(row)
    }

    /// Icon and title for an action row.
    /// - Parameter trailingSymbol: A submenu arrow for a row that opens a flyout.
    @ViewBuilder
    private func actionRowContent(
        symbol: String,
        title: String,
        trailingSymbol: String? = nil
    ) -> some View {
        HStack(spacing: metrics.columnSpacing) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .frame(width: metrics.actionSymbolWidth)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: metrics.rowFontSize))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let trailingSymbol {
                // `.primary` like AppKit's submenu arrow; a dimmed arrow reads as disabled.
                Image(systemName: trailingSymbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
    }

    /// A small uppercase section heading. The date is appended only when the
    /// greeting does not already show it.
    private func sectionHeader(
        _ title: String,
        date: Date? = nil,
        showsCreateAction: Bool = false
    ) -> some View {
        HStack(spacing: 6) {
            Text(sectionHeaderText(title, date: date))
                .font(.system(size: metrics.secondaryFontSize - 1, weight: .bold))
                .textCase(.uppercase)
                .kerning(0.75)
                // Not `.tertiary`: behind-window vibrancy follows the desktop, so a
                // pale wallpaper washes a tertiary label out.
                .foregroundStyle(.secondary)
            Spacer(minLength: 6)
            if showsCreateAction {
                sectionCreateButton
            }
        }
        .padding(.horizontal, metrics.sectionHeaderInset)
        .padding(.top, 6)
        .padding(.bottom, 3)
    }

    /// Whether a section heading shows the new-event chip: today only, and only
    /// for the EventKit provider, since in-app creation is EventKit-only.
    private func showsAgendaCreateAction(_ day: AgendaDay) -> Bool {
        day == .today && state.activeProvider == .macOSEventKit
    }

    /// The `+ ⌘N` chip beside today's heading; opens the new-event editor.
    private var sectionCreateButton: some View {
        HStack(spacing: 3) {
            Image(systemName: "plus")
                .font(.system(size: metrics.secondaryFontSize - 3, weight: .semibold))
            Text("dropdown_panel_new_event_shortcut".loco())
                .font(.system(size: metrics.secondaryFontSize - 2.5, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color.primary.opacity(0.12)))
        .overlay(Capsule().strokeBorder(PanelChrome.rim(colorScheme), lineWidth: 0.8))
        .contentShape(Capsule())
        .pointerStyle(.link)
        // `newEvent`, not `createMeeting`: the chip's ⌘N label is the event-editor shortcut.
        .onTapGesture(perform: perform(handlers.newEvent))
        .help("status_bar_quick_action_new_event".loco())
    }

    private func sectionHeaderText(_ title: String, date: Date?) -> String {
        guard let date, !greetingShowsDate else { return title }
        return "\(title) (\(sectionDateText(date)))"
    }

    /// Localizes `key` and strips trailing colons ("Prep links:" becomes "Prep links"),
    /// reusing a header string as a control label.
    private func sectionLabel(_ key: String) -> String {
        var title = key.loco()
        while title.hasSuffix(":") { title.removeLast() }
        return title
    }

    /// Wraps a handler so it runs and then closes the panel.
    private func perform(_ action: @escaping @MainActor () -> Void) -> @MainActor () -> Void {
        let dismiss = handlers.dismiss
        return {
            action()
            dismiss()
        }
    }

    /// Closes the panel, then runs the action. Use for anything that opens an alert
    /// or another window, which the floating panel would otherwise cover.
    private func dismissThen(_ action: @escaping @MainActor () -> Void) -> @MainActor () -> Void {
        let dismiss = handlers.dismiss
        return {
            dismiss()
            action()
        }
    }

    // MARK: - Formatting

    private func visibleEvents(_ events: [MBEvent]) -> [MBEvent] {
        DropdownEventVisibility.visible(
            events,
            menu: state.menu,
            display: state.events,
            isDeclined: isDeclined,
            now: clock
        )
    }

    private func eventStartText(_ event: MBEvent) -> String {
        event.isAllDay
            ? "status_bar_event_start_time_all_day".loco()
            : clockText(event.startDate)
    }

    /// `nil` unless `showEventEndTime` is on and the event has a real end time.
    private func eventEndText(_ event: MBEvent) -> String? {
        guard agendaTimeColumn == .startAndEnd, !event.isAllDay else { return nil }
        return clockText(event.endDate)
    }

    private func reminderTimeText(_ reminder: MBReminder) -> String {
        guard reminder.hasTime, let due = reminder.dueDate else { return "" }
        return clockText(due)
    }

    private func clockText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = I18N.instance.locale
        formatter.dateFormat = state.timeFormat == .am_pm ? "h:mm a" : "HH:mm"
        return formatter.string(from: date)
    }

    private func sectionDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = I18N.instance.locale
        formatter.dateFormat = "E, d MMM"
        return formatter.string(from: date)
    }
}

// MARK: - Row

/// One panel row with hover and keyboard-selection highlights. Rows with an
/// action get a pointing-hand cursor; `content` receives the hover state.
private struct PanelRow<Content: View>: View {
    var isSelected = false
    let action: (@MainActor () -> Void)?
    @ViewBuilder let content: (Bool) -> Content

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(\.dropdownMetrics) private var metrics

    var body: some View {
        content(isHovered)
            .padding(.horizontal, metrics.rowInnerPadding)
            .padding(.vertical, metrics.rowVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                PanelHighlight(
                    isSelected: isSelected,
                    isHovered: isHovered && action != nil
                )
            )
            .padding(.horizontal, metrics.rowOuterPadding)
            .contentShape(Rectangle())
            // Not NSCursor.push/pop, which can strand the cursor if the panel closes mid-hover.
            .pointerStyle(action == nil ? nil : .link)
            .onHover { hovering in
                guard action != nil else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
                    isHovered = hovering
                }
            }
            .onTapGesture { action?() }
    }

}

/// The panel's hover and keyboard-selection surface: a neutral translucent fill
/// rather than an accent fill. Selection is brighter with an accent-tinted rim, so
/// it stays distinct from hover on another row.
private struct PanelHighlight: View {
    @Environment(\.colorScheme) private var colorScheme

    var isSelected: Bool
    var isHovered: Bool
    var cornerRadius: CGFloat = 7

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(Color.primary.opacity(isSelected ? 0.14 : 0.09))
            .overlay(
                shape.strokeBorder(
                    isSelected
                        ? LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.75),
                                Color.accentColor.opacity(0.18)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        : PanelChrome.rim(colorScheme),
                    lineWidth: 0.8
                )
            )
            .opacity(isSelected || isHovered ? 1 : 0)
    }
}

// MARK: - Card container

/// A bounded surface for a self-contained widget (timeline, month grid, meeting
/// card). Lists stay flat.
///
/// A plain fill rather than `glassEffect`: stacked translucent layers add haze
/// and lose contrast.
private struct PanelCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    var title: String?
    @ViewBuilder let content: Content

    @Environment(\.dropdownMetrics) private var metrics

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                // Styled like `sectionHeader`.
                Text(title)
                    .font(.system(size: metrics.secondaryFontSize - 1, weight: .bold))
                    .textCase(.uppercase)
                    .kerning(0.65)
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding(.horizontal, metrics.cardHorizontalPadding)
        .padding(.vertical, metrics.cardVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardShape.fill(Color.primary.opacity(0.09)))
        // A rim that fades from top to bottom; the bottom stays above zero so the
        // lower edge remains visible.
        .overlay(
            cardShape.strokeBorder(PanelChrome.rim(colorScheme, top: 0.20, bottom: 0.08), lineWidth: 1)
        )
        .padding(.horizontal, metrics.rowOuterPadding)
        .padding(.vertical, metrics.cardSpacing)
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: metrics.cardCornerRadius, style: .continuous)
    }
}

// MARK: - Layout grid propagation

/// Carries the current density's layout grid down the panel. Nested views must
/// read this rather than a static `DropdownMetrics` so they follow the density setting.
private struct DropdownMetricsKey: EnvironmentKey {
    /// Used only outside the panel (e.g. `#Preview`); the panel always injects a value.
    static let defaultValue = DropdownMetrics.standard
}

extension EnvironmentValues {
    var dropdownMetrics: DropdownMetrics {
        get { self[DropdownMetricsKey.self] }
        set { self[DropdownMetricsKey.self] = newValue }
    }
}

// MARK: - AppKit menu plumbing

/// An `NSMenuItem` that runs a closure, so the More-actions flyout can use the
/// `DropdownPanelHandlers` closures directly.
private final class ClosureMenuItem: NSMenuItem {
    private let handler: @MainActor () -> Void

    init(title: String, handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        // `target` is weak, so self-targeting is not a retain cycle.
        target = self
        isEnabled = true
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("ClosureMenuItem is built in code, never from a nib")
    }

    @objc private func run() {
        // Deferred off AppKit's callback stack: handlers close the panel that owns the
        // menu's anchor view, a reentrancy that crashes (see `DropdownPanelWindow.resignKey()`).
        let handler = handler
        DispatchQueue.main.async { handler() }
    }
}

/// Polls the pointer and closes an open `NSMenu` once it returns to the panel.
///
/// Needed because `NSMenu.popUp` runs modal tracking, so the panel gets no hover
/// events while the flyout is open. Uses the frontmost window under the pointer,
/// not a frame test, because AppKit may place the flyout over the panel itself.
@MainActor
private final class MenuExitWatchdog {
    private let menu: NSMenu
    private weak var anchor: NSView?
    private var timer: Timer?

    /// Polling interval, in seconds.
    private static let interval: TimeInterval = 0.05

    init(menu: NSMenu, anchor: NSView) {
        self.menu = menu
        self.anchor = anchor
    }

    func start() {
        let timer = Timer(timeInterval: Self.interval, repeats: true) { _ in
            MainActor.assumeIsolated { self.tick() }
        }
        // `.common` so it fires during the menu's event-tracking run loop mode.
        RunLoop.current.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let anchor, let panel = anchor.window else { return }
        let pointer = NSEvent.mouseLocation
        // Stay open while the pointer is on the row that owns the flyout.
        let rowOnScreen = panel.convertToScreen(anchor.convert(anchor.bounds, to: nil))
        guard !rowOnScreen.contains(pointer) else { return }
        // Close only when the panel itself is the frontmost window under the pointer.
        guard NSWindow.windowNumber(at: pointer, belowWindowWithWindowNumber: 0)
            == panel.windowNumber else { return }
        menu.cancelTracking()
    }
}

/// Holds the `NSView` that `MenuAnchorView` places in the More-actions row, for
/// `NSMenu.popUp(positioning:at:in:)` to anchor to.
private final class MenuAnchorBox {
    weak var view: NSView?
}

/// A non-interactive AppKit view behind a row, for a native menu to anchor to.
private struct MenuAnchorView: NSViewRepresentable {
    let box: MenuAnchorBox

    func makeNSView(context _: Context) -> NSView {
        let view = FlippedAnchor()
        box.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        // Re-point on every update so the box never holds a view from a torn-down hierarchy.
        box.view = nsView
    }

    /// Flipped, so y = 0 is the row's top edge.
    private final class FlippedAnchor: NSView {
        override var isFlipped: Bool { true }

        /// Never takes a click; the `PanelRow` in front owns the hit area.
        override func hitTest(_: NSPoint) -> NSView? { nil }
    }
}

#Preview {
    DropdownPanelView(state: StatusBarMenuState(), handlers: DropdownPanelHandlers())
}
