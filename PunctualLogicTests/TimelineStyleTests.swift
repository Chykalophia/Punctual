//
//  TimelineStyleTests.swift
//  PunctualLogicTests
//

import XCTest
@testable import PunctualLogic

final class TimelineSpanTests: XCTestCase {
    /// 2026-07-28 16:00 local, so "the afternoon" means the same thing in every
    /// assertion below.
    private let now = Calendar.current.date(
        from: DateComponents(year: 2026, month: 7, day: 28, hour: 16)
    )!

    private func hours(_ range: ClosedRange<Date>) -> Double {
        range.upperBound.timeIntervalSince(range.lowerBound) / 3600
    }

    private func offset(_ hoursFromNow: Double) -> Date {
        now.addingTimeInterval(hoursFromNow * 3600)
    }

    // MARK: - Relative

    func testRelativeDoesNotOpenOnEmptyPast() {
        let range = DayTimelineRange.range(
            style: .relative,
            now: now,
            bounds: (first: offset(3.75), last: offset(4))
        )
        XCTAssertEqual(
            range.lowerBound,
            now.addingTimeInterval(-DayTimelineRange.minimumLookBehind),
            "with nothing behind us the bar shows the minimum context, not 3h of it"
        )
    }

    func testRelativeAlwaysKeepsSomePastOnScreen() {
        for startsIn in [0.25, 1.0, 3.75, 8.0] {
            let range = DayTimelineRange.range(
                style: .relative,
                now: now,
                bounds: (first: offset(startsIn), last: offset(startsIn + 0.5))
            )
            XCTAssertLessThanOrEqual(
                range.lowerBound,
                now.addingTimeInterval(-DayTimelineRange.minimumLookBehind),
                "starting in \(startsIn)h"
            )
        }
    }

    func testRelativeReachesBackForAMeetingAlreadyStarted() {
        let range = DayTimelineRange.range(
            style: .relative,
            now: now,
            bounds: (first: offset(-2), last: offset(1))
        )
        XCTAssertLessThanOrEqual(range.lowerBound, offset(-2))
    }

    func testRelativeAlwaysContainsNow() {
        let cases: [(first: Date, last: Date)?] = [
            nil,
            (first: offset(-8), last: offset(-6)),
            (first: offset(5), last: offset(9)),
            (first: offset(0.1), last: offset(0.2))
        ]
        for bounds in cases {
            let range = DayTimelineRange.range(style: .relative, now: now, bounds: bounds)
            XCTAssertTrue(range.contains(now), "\(String(describing: bounds))")
        }
    }

    func testRelativeKeepsAMinimumSpan() {
        let range = DayTimelineRange.range(
            style: .relative,
            now: now,
            bounds: (first: offset(0.25), last: offset(0.5))
        )
        XCTAssertGreaterThanOrEqual(
            hours(range),
            DayTimelineRange.minimumRelativeSpan / 3600
        )
    }

    func testRelativeNeverExceedsTheFixedWindow() {
        let range = DayTimelineRange.range(
            style: .relative,
            now: now,
            bounds: (first: offset(-12), last: offset(12))
        )
        let widest = (DayTimelineRange.relativeLookBehind
            + DayTimelineRange.relativeLookAhead) / 3600
        // Plus the half-hour of breathing room added at each end.
        XCTAssertLessThanOrEqual(hours(range), widest + 1)
    }

    func testRelativeWithNoEventsUsesTheFixedWindow() {
        let range = DayTimelineRange.range(style: .relative, now: now, bounds: nil)
        XCTAssertEqual(range.lowerBound, now.addingTimeInterval(-DayTimelineRange.relativeLookBehind))
        XCTAssertEqual(range.upperBound, now.addingTimeInterval(DayTimelineRange.relativeLookAhead))
    }

    // MARK: - Day

    func testDayCoversTheWorkingDay() {
        let range = DayTimelineRange.range(style: .day, now: now, bounds: nil)
        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.hour, from: range.lowerBound), DayTimelineRange.dayStartHour)
        XCTAssertEqual(calendar.component(.hour, from: range.upperBound), DayTimelineRange.dayEndHour)
    }

    func testDayWidensForEventsOutsideWorkingHours() {
        let early = DayTimelineRange.range(
            style: .day,
            now: now,
            bounds: (first: offset(-9.5), last: offset(1))
        )
        XCTAssertLessThanOrEqual(early.lowerBound, offset(-9.5))

        let late = DayTimelineRange.range(
            style: .day,
            now: now,
            bounds: (first: offset(-1), last: offset(6))
        )
        XCTAssertGreaterThanOrEqual(late.upperBound, offset(6))
    }

    func testDayAlwaysContainsNow() {
        // 02:00 — outside the working day entirely.
        let smallHours = Calendar.current.date(
            from: DateComponents(year: 2026, month: 7, day: 28, hour: 2)
        )!
        let range = DayTimelineRange.range(style: .day, now: smallHours, bounds: nil)
        XCTAssertTrue(range.contains(smallHours))
    }

    func testDayRangeDoesNotMoveAsTheAfternoonPasses() {
        let bounds = (first: offset(-2), last: offset(2))
        let atFour = DayTimelineRange.range(style: .day, now: now, bounds: bounds)
        let atFive = DayTimelineRange.range(style: .day, now: offset(1), bounds: bounds)
        XCTAssertEqual(atFour, atFive)
    }

    // MARK: - Style

    func testStyleRawValuesAreStableAcrossLaunches() {
        XCTAssertEqual(TimelineSpan.allCases.map(\.rawValue), ["off", "relative", "day"])
    }

    func testOnlyOffIsHidden() {
        for style in TimelineSpan.allCases {
            XCTAssertEqual(style.isVisible, style != .off, "\(style)")
        }
    }

    func testOffStillAnswersWithAUsableRange() {
        let range = DayTimelineRange.range(style: .off, now: now, bounds: nil)
        XCTAssertTrue(range.contains(now))
    }

    // MARK: - Migration off the retired toggles

    func testMigrationKeepsTheUpNextCardAsTheCountdownBar() {
        XCTAssertTrue(DropdownModuleMergePolicy.showsProgress(hadUpNextModule: true))
        XCTAssertFalse(DropdownModuleMergePolicy.showsProgress(hadUpNextModule: false))
    }

    func testMigrationTurnsAHiddenTimelineIntoTheOffStyle() {
        XCTAssertEqual(
            DropdownModuleMergePolicy.timelineStyle(wasVisible: false, stored: .day),
            .off
        )
        XCTAssertEqual(
            DropdownModuleMergePolicy.timelineStyle(wasVisible: true, stored: .day),
            .day,
            "a visible timeline keeps whatever style is stored"
        )
    }
}
