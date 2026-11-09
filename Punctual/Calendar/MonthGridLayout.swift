//
//  MonthGridLayout.swift
//  Punctual
//
//  Pure month and week grid geometry for the calendar window: seven-day weeks
//  starting on `Calendar.firstWeekday`, padded with adjacent-month days.
//

import Foundation

/// A single cell in the month grid.
///
/// `isInMonth` is `false` for the leading/trailing padding days that belong to
/// the previous or next month. `isToday` is set when the cell falls on the same
/// day as the `now` passed to `MonthGridLayout.weeks(...)`.
public struct MonthGridDay: Equatable, Sendable {
    public let date: Date
    public let isInMonth: Bool
    public let isToday: Bool

    public init(date: Date, isInMonth: Bool, isToday: Bool) {
        self.date = date
        self.isInMonth = isInMonth
        self.isToday = isToday
    }
}

public enum MonthGridLayout {
    /// The first moment of the month containing `date` (its day-1 midnight).
    public static func startOfMonth(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    /// The top-left cell of the month grid: the month's first day stepped back to `firstWeekday`.
    public static func firstVisibleDay(forMonthContaining date: Date, calendar: Calendar) -> Date {
        let monthStart = startOfMonth(for: date, calendar: calendar)
        let weekday = calendar.component(.weekday, from: monthStart)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -leading, to: monthStart) ?? monthStart
    }

    /// The bottom-right cell of the month grid (inclusive): the month's last day stepped forward to the week's end.
    public static func lastVisibleDay(forMonthContaining date: Date, calendar: Calendar) -> Date {
        let monthStart = startOfMonth(for: date, calendar: calendar)
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        let lastDay = calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? monthStart
        let weekday = calendar.component(.weekday, from: lastDay)
        let trailing = (calendar.firstWeekday + 6 - weekday + 7) % 7
        return calendar.date(byAdding: .day, value: trailing, to: lastDay) ?? lastDay
    }

    /// The first cell of a single-week grid: `date`'s day stepped back to `firstWeekday`.
    public static func firstVisibleDayOfWeek(containing date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -leading, to: day) ?? day
    }

    /// The last cell of a single-week grid (inclusive): six days after `firstVisibleDayOfWeek`.
    public static func lastVisibleDayOfWeek(containing date: Date, calendar: Calendar) -> Date {
        let first = firstVisibleDayOfWeek(containing: date, calendar: calendar)
        return calendar.date(byAdding: .day, value: 6, to: first) ?? first
    }

    /// The seven-day week containing `date`, starting on `firstWeekday`.
    ///
    /// `isInMonth` is relative to `date`'s own month; `isToday` matches the day of `now`.
    public static func week(containing date: Date, calendar: Calendar, now: Date) -> [MonthGridDay] {
        let monthComponents = calendar.dateComponents([.year, .month], from: date)
        let first = firstVisibleDayOfWeek(containing: date, calendar: calendar)
        return (0..<7).compactMap { offset in
            guard let dayDate = calendar.date(byAdding: .day, value: offset, to: first) else {
                return nil
            }
            let components = calendar.dateComponents([.year, .month], from: dayDate)
            return MonthGridDay(
                date: calendar.startOfDay(for: dayDate),
                isInMonth: components.year == monthComponents.year
                    && components.month == monthComponents.month,
                isToday: calendar.isDate(dayDate, inSameDayAs: now)
            )
        }
    }

    /// Whole weeks (each exactly seven days) covering the month of `date`.
    ///
    /// Leading/trailing padding days from the adjacent months are flagged
    /// `isInMonth == false`; the cell falling on `now` is flagged `isToday`.
    /// Returns 5 or 6 rows depending on how the month lands on the week grid.
    public static func weeks(
        forMonthContaining date: Date,
        calendar: Calendar,
        now: Date
    ) -> [[MonthGridDay]] {
        let monthComponents = calendar.dateComponents(
            [.year, .month], from: startOfMonth(for: date, calendar: calendar)
        )
        let first = firstVisibleDay(forMonthContaining: date, calendar: calendar)
        let last = lastVisibleDay(forMonthContaining: date, calendar: calendar)
        let totalDays = (calendar.dateComponents([.day], from: first, to: last).day ?? 0) + 1

        var weeks: [[MonthGridDay]] = []
        var week: [MonthGridDay] = []
        for offset in 0..<max(totalDays, 0) {
            guard let dayDate = calendar.date(byAdding: .day, value: offset, to: first) else { continue }
            let components = calendar.dateComponents([.year, .month], from: dayDate)
            let isInMonth = components.year == monthComponents.year
                && components.month == monthComponents.month
            week.append(
                MonthGridDay(
                    date: calendar.startOfDay(for: dayDate),
                    isInMonth: isInMonth,
                    isToday: calendar.isDate(dayDate, inSameDayAs: now)
                )
            )
            if week.count == 7 {
                weeks.append(week)
                week = []
            }
        }
        if !week.isEmpty {
            weeks.append(week)
        }
        return weeks
    }
}

// MARK: - Month / week fold

/// Month or single-week grids. The fold is a `Bool` on purpose; the window layer owns `CalendarGridMode`.
public extension MonthGridLayout {
    /// The date a grid is anchored on after `offset` steps of a week (folded) or a month.
    static func anchor(
        from now: Date,
        offset: Int,
        isWeekFold: Bool,
        calendar: Calendar
    ) -> Date {
        let component: Calendar.Component = isWeekFold ? .weekOfYear : .month
        return calendar.date(byAdding: component, value: offset, to: now) ?? now
    }

    /// The rows to draw for an anchor date: every week of its month, or just the
    /// one week containing it.
    static func rows(
        anchoredOn date: Date,
        isWeekFold: Bool,
        calendar: Calendar,
        now: Date
    ) -> [[MonthGridDay]] {
        guard isWeekFold else {
            return weeks(forMonthContaining: date, calendar: calendar, now: now)
        }
        return [week(containing: date, calendar: calendar, now: now)]
    }

    /// The first and last dates the grid covers, for its title.
    /// A week may straddle two months; a month returns its own first and last day.
    static func visibleRange(
        anchoredOn date: Date,
        isWeekFold: Bool,
        calendar: Calendar
    ) -> (start: Date, end: Date) {
        if isWeekFold {
            let start = firstVisibleDayOfWeek(containing: date, calendar: calendar)
            let end = lastVisibleDayOfWeek(containing: date, calendar: calendar)
            return (start, end)
        }
        let start = startOfMonth(for: date, calendar: calendar)
        let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? start
        return (start, end)
    }
}
