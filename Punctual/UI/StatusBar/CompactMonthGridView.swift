//
//  CompactMonthGridView.swift
//  Punctual
//
//  A month (or single-week) grid sized for the dropdown panel. Shares
//  `MonthGridLayout` with the calendar window's `CalendarGridView`, not the view.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import SwiftUI

struct CompactMonthGridView: View {
    /// Month to render, any date within it.
    let month: Date
    let now: Date
    let calendar: Calendar
    /// Calendar colours of each day's events, keyed by start of day; drawn as dots.
    let markers: [Date: [Color]]
    /// User-marked days, shown by tinting the day number (not as a dot).
    var dateMarkers: [DateMarker] = []
    /// Whether the grid is folded to a single week; stepping then moves by week.
    var isWeekFold = false
    let onStep: (Int) -> Void
    let onSelect: (Date) -> Void
    /// Toggles the fold; `nil` hides the fold button.
    var onToggleFold: (() -> Void)?
    /// Returns the grid to the current period. Shown only when `isSteppedAway`.
    var onReturnToToday: (() -> Void)?
    /// Whether the grid shows a period other than the one containing `now`.
    var isSteppedAway = false

    @Environment(\.dropdownMetrics) private var metrics

    /// Maximum dots per day; extra events are not drawn.
    static let maxMarkers = 3

    var body: some View {
        VStack(spacing: 5) {
            header
            weekdayRow
            grid
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: metrics.rowFontSize, weight: .semibold))
            Spacer(minLength: 0)
            if isSteppedAway, let onReturnToToday {
                Text("dropdown_calendar_today".loco())
                    .font(.system(size: metrics.secondaryFontSize - 2, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                    .pointerStyle(.link)
                    .onTapGesture { onReturnToToday() }
                    .help("dropdown_calendar_today_help".loco())
            }
            if let onToggleFold {
                Image(systemName: isWeekFold
                    ? "rectangle.expand.vertical"
                    : "rectangle.compress.vertical")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 18)
                    .contentShape(Rectangle())
                    .pointerStyle(.link)
                    .onTapGesture { onToggleFold() }
                    .help(isWeekFold
                        ? "dropdown_calendar_show_month".loco()
                        : "dropdown_calendar_show_week".loco())
                    .accessibilityLabel(isWeekFold
                        ? "dropdown_calendar_show_month".loco()
                        : "dropdown_calendar_show_week".loco())
            }
            stepButton(symbol: "chevron.left", step: -1)
            stepButton(symbol: "chevron.right", step: 1)
        }
    }

    private func stepButton(symbol: String, step: Int) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 18)
            .contentShape(Rectangle())
            .pointerStyle(.link)
            .onTapGesture { onStep(step) }
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(size: metrics.secondaryFontSize - 3, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        VStack(spacing: 1) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(week, id: \.date) { day in
                        cell(day)
                    }
                }
            }
        }
    }

    private func cell(_ day: MonthGridDay) -> some View {
        let marked = DateMarkerPolicy.markers(on: day.date, from: dateMarkers, calendar: calendar)
        return CompactMonthDayCell(
            day: day,
            dots: markers[calendar.startOfDay(for: day.date)] ?? [],
            markerLabels: marked.map(\.label),
            calendar: calendar,
            metrics: metrics,
            onSelect: onSelect
        )
    }

    // MARK: - Derived

    private var weeks: [[MonthGridDay]] {
        MonthGridLayout.rows(anchoredOn: month, isWeekFold: isWeekFold, calendar: calendar, now: now)
    }

    /// Very short weekday symbols rotated to start at `calendar.firstWeekday`.
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        guard offset > 0, offset < symbols.count else { return symbols }
        return Array(symbols[offset...] + symbols[..<offset])
    }

    private var title: String {
        guard isWeekFold else { return monthTitle }
        // A folded week can straddle two months, so show its date range instead.
        let range = MonthGridLayout.visibleRange(
            anchoredOn: month, isWeekFold: true, calendar: calendar
        )
        let formatter = DateIntervalFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.dateTemplate = "MMMd"
        return formatter.string(from: range.start, to: range.end)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: month)
    }
}

/// One day in the grid, with its own hover state.
private struct CompactMonthDayCell: View {
    let day: MonthGridDay
    let dots: [Color]
    /// Labels of any user markers on this day.
    let markerLabels: [String]
    let calendar: Calendar
    let metrics: DropdownMetrics
    let onSelect: (Date) -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let maxMarkers = CompactMonthGridView.maxMarkers

    var body: some View {
        VStack(spacing: 1) {
            Text(dayNumber(day.date))
                .font(.system(
                    size: metrics.secondaryFontSize - 1,
                    // Weight as well as colour, for colour-vision deficiency and Increase Contrast.
                    weight: day.isToday ? .bold : (isMarked ? .semibold : .regular)
                ))
                .foregroundStyle(dayColor(day))
            // Always present, even when empty, so every cell has the same height.
            HStack(spacing: 2) {
                ForEach(Array(dots.prefix(Self.maxMarkers).enumerated()), id: \.offset) { _, colour in
                    Circle()
                        .fill(day.isToday ? Color.white.opacity(0.9) : colour)
                        .frame(width: 3, height: 3)
                }
            }
            .frame(height: 3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(fill)
        )
        .contentShape(Rectangle())
        .pointerStyle(.link)
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.10)) {
                isHovered = hovering
            }
        }
        .onTapGesture { onSelect(day.date) }
        .help(markerLabels.joined(separator: " · "))
        .accessibilityLabel(accessibilityLabel)
    }

    /// The day number followed by any marker labels.
    private var accessibilityLabel: String {
        let dayText = dayNumber(day.date)
        guard isMarked else { return dayText }
        return "\(dayText), \(markerLabels.joined(separator: ", "))"
    }

    private var fill: Color {
        if day.isToday {
            return isHovered ? Color.accentColor.opacity(0.85) : Color.accentColor
        }
        return isHovered ? Color.primary.opacity(0.12) : .clear
    }

    private var isMarked: Bool { !markerLabels.isEmpty }

    private func dayColor(_ day: MonthGridDay) -> Color {
        if day.isToday { return .white }
        guard day.isInMonth else { return .secondary.opacity(0.5) }
        return isMarked ? .accentColor : .primary
    }

    private func dayNumber(_ date: Date) -> String {
        String(calendar.component(.day, from: date))
    }
}
