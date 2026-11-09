//
//  CalendarGridViewModel.swift
//  Punctual
//
//  View model for the calendar window: the visible month or week, its grid, and that range's
//  events bucketed by day, fetched through an injected closure independent of the main sync.
//

import Defaults
import Foundation

/// How the calendar window folds its grid: a full month or a single week.
/// Persisted as a raw string in `Defaults[.calendarGridMode]`.
enum CalendarGridMode: String, CaseIterable, Sendable {
    case month
    case week
}

/// App closures the calendar window needs, injected by AppDelegate.
struct CalendarWindowHandlers {
    /// Fetches events for `[from, to)` across the user's selected calendars.
    var fetchEvents: @MainActor (_ from: Date, _ to: Date) async throws -> [MBEvent]
    /// Joins the meeting for the given event id.
    var join: @MainActor (_ eventID: String) -> Void
}

@MainActor
final class CalendarGridViewModel: ObservableObject {
    @Published private(set) var mode: CalendarGridMode
    @Published private(set) var visibleMonth: Date
    /// First day of the visible week (week mode only), already on `firstWeekday`.
    @Published private(set) var visibleWeekStart: Date
    @Published private(set) var weeks: [[MonthGridDay]] = []
    @Published private(set) var eventsByDay: [Date: [MBEvent]] = [:]
    @Published var selectedDay: Date?
    @Published private(set) var isLoading = false

    let calendar: Calendar
    private let now: Date
    private let handlers: CalendarWindowHandlers
    private var loadTask: Task<Void, Never>?

    init(
        handlers: CalendarWindowHandlers,
        calendar: Calendar = CalendarGridViewModel.defaultCalendar(),
        now: Date = Date(),
        mode: CalendarGridMode = CalendarGridMode(rawValue: Defaults[.calendarGridMode]) ?? .month
    ) {
        self.handlers = handlers
        self.calendar = calendar
        self.now = now
        self.mode = mode
        self.visibleMonth = MonthGridLayout.startOfMonth(for: now, calendar: calendar)
        self.visibleWeekStart = MonthGridLayout.firstVisibleDayOfWeek(
            containing: now, calendar: calendar
        )
        self.selectedDay = calendar.startOfDay(for: now)
        reload()
    }

    /// The current calendar with the app's locale and the user's first-weekday override (0 follows the locale).
    static func defaultCalendar() -> Calendar {
        var calendar = Calendar.current
        calendar.locale = I18N.instance.locale
        let override = Defaults[.calendarFirstWeekday]
        if override > 0 {
            calendar.firstWeekday = override
        }
        return calendar
    }

    // MARK: - Mode

    /// Switches and persists the mode, anchoring the new range on the selected day.
    func setMode(_ newMode: CalendarGridMode) {
        guard newMode != mode else { return }
        mode = newMode
        Defaults[.calendarGridMode] = newMode.rawValue

        let anchor = selectedDay ?? now
        switch newMode {
        case .week:
            visibleWeekStart = MonthGridLayout.firstVisibleDayOfWeek(
                containing: anchor, calendar: calendar
            )
        case .month:
            visibleMonth = MonthGridLayout.startOfMonth(for: anchor, calendar: calendar)
        }
        reload()
    }

    // MARK: - Navigation

    /// Steps back one month in month mode, one week in week mode.
    func goToPrevious() {
        step(-1)
    }

    /// Steps forward one month in month mode, one week in week mode.
    func goToNext() {
        step(1)
    }

    private func step(_ direction: Int) {
        switch mode {
        case .month:
            guard let stepped = calendar.date(
                byAdding: .month, value: direction, to: visibleMonth
            ) else { return }
            visibleMonth = MonthGridLayout.startOfMonth(for: stepped, calendar: calendar)
        case .week:
            guard let stepped = calendar.date(
                byAdding: .day, value: direction * 7, to: visibleWeekStart
            ) else { return }
            visibleWeekStart = MonthGridLayout.firstVisibleDayOfWeek(
                containing: stepped, calendar: calendar
            )
        }
        reload()
    }

    func goToToday() {
        goTo(now)
    }

    /// Jumps the grid to `date` and selects that day. Moves both the month and week anchors.
    func goTo(_ date: Date) {
        visibleMonth = MonthGridLayout.startOfMonth(for: date, calendar: calendar)
        visibleWeekStart = MonthGridLayout.firstVisibleDayOfWeek(
            containing: date, calendar: calendar
        )
        selectedDay = calendar.startOfDay(for: date)
        reload()
    }

    // MARK: - Selection

    func select(_ day: MonthGridDay) {
        selectedDay = calendar.startOfDay(for: day.date)
    }

    /// The first and last day currently drawn, padding cells included.
    var visibleRange: (start: Date, end: Date)? {
        guard let first = weeks.first?.first?.date,
              let last = weeks.last?.last?.date else { return nil }
        return (first, last)
    }

    /// Moves the keyboard selection, paging the grid when it walks off the edge.
    /// With nothing selected, starts from the visible range's anchor.
    func moveSelection(byDays days: Int) {
        guard let visibleRange else { return }
        let anchor = selectedDay ?? (mode == .month ? visibleMonth : visibleWeekStart)
        let result = CalendarGridNavigation.move(
            from: anchor,
            byDays: days,
            visibleRange: visibleRange,
            calendar: calendar
        )
        if result.requiresPaging {
            goTo(result.selectedDay)
        } else {
            selectedDay = result.selectedDay
        }
    }

    var selectedDayEvents: [MBEvent] {
        guard let selectedDay else { return [] }
        return eventsByDay[calendar.startOfDay(for: selectedDay)] ?? []
    }

    func events(on day: MonthGridDay) -> [MBEvent] {
        eventsByDay[calendar.startOfDay(for: day.date)] ?? []
    }

    // MARK: - Join

    func join(_ event: MBEvent) {
        guard event.meetingLink != nil else { return }
        handlers.join(event.id)
    }

    // MARK: - Loading

    /// Rebuilds the grid for the visible range and reloads its events.
    private func reload() {
        let first: Date
        let lastVisible: Date
        switch mode {
        case .month:
            weeks = MonthGridLayout.weeks(
                forMonthContaining: visibleMonth, calendar: calendar, now: now
            )
            first = MonthGridLayout.firstVisibleDay(
                forMonthContaining: visibleMonth, calendar: calendar
            )
            lastVisible = MonthGridLayout.lastVisibleDay(
                forMonthContaining: visibleMonth, calendar: calendar
            )
        case .week:
            weeks = [
                MonthGridLayout.week(containing: visibleWeekStart, calendar: calendar, now: now)
            ]
            first = MonthGridLayout.firstVisibleDayOfWeek(
                containing: visibleWeekStart, calendar: calendar
            )
            lastVisible = MonthGridLayout.lastVisibleDayOfWeek(
                containing: visibleWeekStart, calendar: calendar
            )
        }
        // The fetch range is half-open, so end at the start of the day after the last visible day.
        let upperBound = calendar.date(byAdding: .day, value: 1, to: lastVisible) ?? lastVisible

        loadTask?.cancel()
        isLoading = true
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let events = try await self.handlers.fetchEvents(first, upperBound)
                guard !Task.isCancelled else { return }
                self.eventsByDay = self.bucket(events)
            } catch {
                guard !Task.isCancelled else { return }
                PunctualLogger.calendar.error(
                    "Calendar window month fetch failed: \(String(describing: error), privacy: .private)"
                )
                self.eventsByDay = [:]
            }
            self.isLoading = false
        }
    }

    /// Buckets events by their start day (a multi-day event lands only on its first day),
    /// each bucket sorted all-day first, then by start time.
    private func bucket(_ events: [MBEvent]) -> [Date: [MBEvent]] {
        var result: [Date: [MBEvent]] = [:]
        for event in events {
            let day = calendar.startOfDay(for: event.startDate)
            result[day, default: []].append(event)
        }
        for key in result.keys {
            result[key]?.sort { lhs, rhs in
                if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                return lhs.startDate < rhs.startDate
            }
        }
        return result
    }
}
