//
//  DayTimelineView.swift
//  MeetingBar
//
//  Created by Andrii Leitsius on 22.05.2025.
//  Copyright © 2025 Andrii Leitsius. All rights reserved.
//

import SwiftUI

struct DaySegment: Identifiable {
    let id: String
    let start: Date
    let end: Date
    let color: Color
    let isHighlighted: Bool
    let title: String?

    init(
        id: String = UUID().uuidString,
        start: Date,
        end: Date,
        color: Color,
        isHighlighted: Bool = false,
        title: String? = nil
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.color = color
        self.isHighlighted = isHighlighted
        self.title = title
    }
}

enum DayTimelineLayout {
    /// How many hours are visible to the left / right of “now”
    static let hoursBefore: TimeInterval = 3 * 3600   // 3 h
    static let hoursAfter: TimeInterval = 6 * 3600   // 6 h

    static let baseTrackHeight: CGFloat = 22
    static let segmentHeight: CGFloat = 10
    /// Thickness of the single rail used by the `bar` and `minimal` appearances.
    static let railHeight: CGFloat = 6
    static let rowSpacing: CGFloat = 4

    static var rowHeight: CGFloat { segmentHeight + rowSpacing }

    /// Estimated half width of the widest hour label at `.caption2`, by format.
    /// Deliberately over-estimates so labels thin out rather than collide.
    static func hourLabelHalfWidth(for format: TimeFormat) -> CGFloat {
        switch format {
        case .am_pm: 17    // "12 PM"
        case .military: 7  // "09"
        }
    }

    /// Minimum distance between two label centres before both are drawn: two half widths plus a gap.
    static func minimumLabelSpacing(for format: TimeFormat) -> CGFloat {
        hourLabelHalfWidth(for: format) * 2 + 6
    }
}

struct DayTimelineLayoutCalculator {
    // MARK: Cached range information
    let now: Date
    let visibleRange: ClosedRange<Date>
    private let totalSeconds: TimeInterval

    /// Creates a calculator for a range produced by `DayTimelineRange`.
    init(now: Date = Date(), range: ClosedRange<Date>) {
        self.now = now
        self.visibleRange = range
        self.totalSeconds = range.upperBound.timeIntervalSince(range.lowerBound)
    }

    init(now: Date = Date()) {
        self.now = now
        let lower = now.addingTimeInterval(-DayTimelineLayout.hoursBefore)
        let upper = now.addingTimeInterval( DayTimelineLayout.hoursAfter)
        self.visibleRange = lower...upper
        self.totalSeconds = upper.timeIntervalSince(lower)
    }

    // MARK: X-position helpers
    func xPosition(of date: Date, width: CGFloat) -> CGFloat {
        let clamped = min(max(date, visibleRange.lowerBound), visibleRange.upperBound)
        let seconds = clamped.timeIntervalSince(visibleRange.lowerBound)
        return width * CGFloat(seconds / totalSeconds)
    }

    // MARK: Hour ticks
    func hourTicks() -> [Date] {
        var out: [Date] = []
        var current = Calendar.current.nextDate(
            after: visibleRange.lowerBound.addingTimeInterval(-1),
            matching: DateComponents(minute: 0, second: 0),
            matchingPolicy: .strict
        )!
        while current <= visibleRange.upperBound {
            out.append(current)
            current = Calendar.current.date(byAdding: .hour, value: 1, to: current)!
        }
        return out
    }

    // MARK: Hour labels

    /// Clamps an hour label's centre x so the label stays inside the view.
    func clampedLabelX(_ x: CGFloat, width: CGFloat, halfWidth: CGFloat) -> CGFloat {
        guard width > halfWidth * 2 else { return width / 2 }
        return min(max(x, halfWidth), width - halfWidth)
    }

    /// Hour ticks that get a label at this width. Every tick keeps its grid line, but a
    /// label is dropped when it would overlap the last one kept, scanning from the left.
    func labelledTicks(width: CGFloat, timeFormat: TimeFormat) -> [Date] {
        let halfWidth = DayTimelineLayout.hourLabelHalfWidth(for: timeFormat)
        let minimumSpacing = DayTimelineLayout.minimumLabelSpacing(for: timeFormat)
        var kept: [Date] = []
        var lastX: CGFloat?

        for tick in hourTicks() {
            let x = clampedLabelX(
                xPosition(of: tick, width: width),
                width: width,
                halfWidth: halfWidth
            )
            if let lastX, x - lastX < minimumSpacing { continue }
            kept.append(tick)
            lastX = x
        }
        return kept
    }

    // MARK: Row packing
    func rows(for segments: [DaySegment]) -> [[DaySegment]] {
        var rows: [[DaySegment]] = []
        for seg in segments where seg.end > visibleRange.lowerBound && seg.start < visibleRange.upperBound {
            if let idx = rows.firstIndex(where: { row in
                !row.contains(where: { $0.start < seg.end && $0.end > seg.start })
            }) {
                rows[idx].append(seg)
            } else {
                rows.append([seg])
            }
        }
        return rows
    }
}

struct DayRelativeTimelineView: View {
    let segments: [DaySegment]
    let currentDate: Date
    let timeFormat: TimeFormat
    let appearance: TimelineAppearance

    // Cached / pre-computed values
    private let layout: DayTimelineLayoutCalculator
    private let eventRows: [[DaySegment]]
    private let contentHeight: CGFloat

    /// Height the parent can rely on for sizing; depends on the appearance.
    var preferredHeight: CGFloat {
        switch appearance {
        case .track: contentHeight + 26
        case .bar: DayTimelineLayout.railHeight + 18
        case .minimal: DayTimelineLayout.railHeight + 4
        }
    }

    // MARK: Init
    init(
        segments: [DaySegment],
        currentDate: Date,
        timeFormat: TimeFormat,
        style: TimelineSpan = .relative,
        appearance: TimelineAppearance = .track
    ) {
        let bounds = segments.isEmpty
            ? nil
            : (
                first: segments.map(\.start).min() ?? currentDate,
                last: segments.map(\.end).max() ?? currentDate
            )
        let layout = DayTimelineLayoutCalculator(
            now: currentDate,
            range: DayTimelineRange.range(style: style, now: currentDate, bounds: bounds)
        )
        self.segments     = segments
        self.currentDate  = currentDate
        self.timeFormat   = timeFormat
        self.appearance   = appearance
        self.layout       = layout
        // Only `track` stacks overlapping meetings into extra rows.
        let rows = appearance.stacksOverlaps
            ? layout.rows(for: segments)
            : (segments.isEmpty ? [] : [segments])
        self.eventRows = rows
        self.contentHeight = appearance == .track
            ? DayTimelineLayout.baseTrackHeight
                + DayTimelineLayout.rowHeight * CGFloat(max(rows.count - 1, 0))
            : DayTimelineLayout.railHeight
    }

    /// Ticks that get a label at this width, in the view's current time format.
    private func labelledTicks(width: CGFloat) -> [Date] {
        layout.labelledTicks(width: width, timeFormat: timeFormat)
    }

    // MARK: Body
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            if appearance == .track {
                trackBody(width: width)
            } else {
                railBody(width: width)
            }
        }
        // Padding stays outside the GeometryReader so the proxy measures the width the content draws into.
        .padding(.top, appearance == .track ? 10 : 0)
        .padding(.vertical, appearance == .track ? 8 : 2)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("timeline_accessibility_label".loco(segments.count))
    }

    /// One rail with the meetings inline, used by the `bar` and `minimal` appearances.
    @ViewBuilder
    private func railBody(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.14))
                    .frame(height: DayTimelineLayout.railHeight)

                ForEach(segments) { seg in
                    let startX = layout.xPosition(
                        of: max(seg.start, layout.visibleRange.lowerBound), width: width
                    )
                    let endX = layout.xPosition(
                        of: min(seg.end, layout.visibleRange.upperBound), width: width
                    )
                    Capsule()
                        .fill(seg.color.opacity(seg.isHighlighted ? 0.95 : 0.75))
                        .frame(
                            width: max(endX - startX, DayTimelineLayout.railHeight),
                            height: DayTimelineLayout.railHeight
                        )
                        .offset(x: startX)
                        .help(seg.title ?? "")
                }

                if layout.visibleRange.contains(currentDate) {
                    Capsule()
                        .fill(Color.primary)
                        .frame(width: 2, height: DayTimelineLayout.railHeight + 6)
                        .offset(x: layout.xPosition(of: currentDate, width: width) - 1)
                }
            }
            .frame(height: DayTimelineLayout.railHeight)

            if appearance.showsHourLabels {
                ZStack(alignment: .topLeading) {
                    ForEach(labelledTicks(width: width), id: \.self) { tick in
                        Text(hourFormatter.string(from: tick))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .fixedSize()
                            .position(
                                x: layout.clampedLabelX(
                                    layout.xPosition(of: tick, width: width),
                                    width: width,
                                    halfWidth: DayTimelineLayout.hourLabelHalfWidth(for: timeFormat)
                                ),
                                y: 5
                            )
                    }
                }
                .frame(height: 11)
            }
        }
    }

    private func trackBody(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {

                // Hour grid
                ForEach(layout.hourTicks(), id: \.self) { tick in
                    let x = layout.xPosition(of: tick, width: width)
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: contentHeight))
                    }
                    .stroke(Color.primary.opacity(0.25), lineWidth: 1)
                }

                // Hour labels: only non-colliding ticks, each clamped inside the view.
                ForEach(labelledTicks(width: width), id: \.self) { tick in
                    Text(hourFormatter.string(from: tick))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize()
                        .position(
                            x: layout.clampedLabelX(
                                layout.xPosition(of: tick, width: width),
                                width: width,
                                halfWidth: DayTimelineLayout.hourLabelHalfWidth(for: timeFormat)
                            ),
                            y: -8
                        )
                }

                // Event rows
                ForEach(eventRows.indices, id: \.self) { row in
                    ForEach(eventRows[row]) { seg in
                        let startX  = layout.xPosition(of: max(seg.start, layout.visibleRange.lowerBound), width: width)
                        let endX    = layout.xPosition(of: min(seg.end, layout.visibleRange.upperBound), width: width)
                        let widthPx = max(endX - startX, DayTimelineLayout.segmentHeight / 2)

                        // Fill opacity is high enough to stay visible over behind-window vibrancy on pale wallpapers.
                        Capsule()
                            .fill(seg.color.opacity(seg.isHighlighted ? 0.70 : 0.42))
                            .overlay(
                                Capsule().stroke(
                                    seg.color,
                                    lineWidth: seg.isHighlighted ? 2 : 1
                                )
                            )
                            .frame(width: widthPx, height: DayTimelineLayout.segmentHeight)
                            .offset(
                                x: startX,
                                y: (DayTimelineLayout.baseTrackHeight - DayTimelineLayout.segmentHeight) / 2 +
                                   CGFloat(row) * DayTimelineLayout.rowHeight
                            )
                            .help(seg.title ?? "")
                    }
                }

                // Current time indicator
                if layout.visibleRange.contains(currentDate) {
                    let x = layout.xPosition(of: currentDate, width: width)
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 2, height: contentHeight + 4)
                        .offset(x: x - 1, y: -2)
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                        .offset(x: x - 3, y: -5)
                }
        }
        .frame(height: contentHeight)
    }

    private var hourFormatter: DateFormatter {
        let format = DateFormatter()
        format.locale = I18N.instance.locale
        switch timeFormat {
        case .am_pm:    format.dateFormat = "h a"
        case .military: format.dateFormat = "HH"
        }
        return format
    }
}

// MARK: - Preview

#Preview {
    let cal = Calendar.current
    let now = Date()
    let sampleSegments = [
        DaySegment(
            start: cal.date(byAdding: .hour, value: -2, to: now)!,
            end: cal.date(byAdding: .hour, value: -1, to: now)!,
            color: .blue
        ),
        DaySegment(
            start: cal.date(byAdding: .minute, value: -90, to: now)!,
            end: cal.date(byAdding: .minute, value: -30, to: now)!,
            color: .blue
        ),
        DaySegment(
            start: cal.date(byAdding: .minute, value: -90, to: now)!,
            end: cal.date(byAdding: .minute, value: 30, to: now)!,
            color: .blue
        ),
        DaySegment(
            start: cal.date(byAdding: .minute, value: -30, to: now)!,
            end: cal.date(byAdding: .minute, value: 30, to: now)!,
            color: .blue
        ),
        DaySegment(
            start: cal.date(byAdding: .hour, value: 1, to: now)!,
            end: cal.date(byAdding: .hour, value: 2, to: now)!,
            color: .green
        ),
        DaySegment(
            start: cal.date(byAdding: .hour, value: 4, to: now)!,
            end: cal.date(byAdding: .hour, value: 5, to: now)!,
            color: .orange
        )
    ]

    DayRelativeTimelineView(
        segments: sampleSegments,
        currentDate: now,
        timeFormat: .military
    )
    .padding()
}
