//
//  StartReminderOverrideTests.swift
//  PunctualLogicTests
//
//  Tests for per-event start-reminder overrides against the global setting.
//

import XCTest

@testable import PunctualLogic

final class StartReminderOverrideTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func event(
        id: String = "event-1",
        startsInMinutes: Double = 60,
        override: StartReminderOverride? = nil,
        hasMeetingLink: Bool = true
    ) -> NotificationPlanningEvent {
        let start = now.addingTimeInterval(startsInMinutes * 60)
        return NotificationPlanningEvent(
            id: id,
            startDate: start,
            endDate: start.addingTimeInterval(1800),
            status: .active,
            participationStatus: .active,
            isAllDay: false,
            hasMeetingLink: hasMeetingLink,
            startReminderOverride: override
        )
    }

    private func settings(
        startEnabled: Bool = true,
        startOffset: TimeInterval = 300
    ) -> NotificationPlanningSettings {
        NotificationPlanningSettings(
            eventStart: .init(enabled: startEnabled, offset: startOffset),
            eventEnd: .disabled,
            fullscreen: .disabled,
            autoJoin: .disabled,
            scriptOnStart: .disabled,
            dismissedEventIDs: []
        )
    }

    private func startNotifications(
        _ event: NotificationPlanningEvent,
        _ settings: NotificationPlanningSettings
    ) -> [PlannedNotification] {
        NotificationPlanner.plan(events: [event], settings: settings, now: now)
            .filter { $0.kind == .eventStart }
    }

    // MARK: - No override: the global setting rules

    func testWithoutAnOverrideTheGlobalOffsetIsUsed() {
        let planned = startNotifications(event(), settings(startOffset: 300))
        XCTAssertEqual(planned.count, 1)
        XCTAssertEqual(
            planned.first?.fireDate,
            now.addingTimeInterval(60 * 60 - 300)
        )
    }

    func testWithoutAnOverrideAGlobalOffMeansNothing() {
        XCTAssertTrue(startNotifications(event(), settings(startEnabled: false)).isEmpty)
    }

    // MARK: - Custom offset

    func testAnOverrideReplacesTheGlobalOffset() {
        let planned = startNotifications(
            event(override: .offset(900)), settings(startOffset: 300)
        )
        XCTAssertEqual(planned.first?.fireDate, now.addingTimeInterval(60 * 60 - 900))
    }

    func testAnOverrideFiresEvenWhenTheGlobalReminderIsOff() {
        // An explicit per-event offset wins even with the global reminder off.
        let planned = startNotifications(
            event(override: .offset(600)), settings(startEnabled: false)
        )
        XCTAssertEqual(planned.count, 1)
        XCTAssertEqual(planned.first?.fireDate, now.addingTimeInterval(60 * 60 - 600))
    }

    func testAZeroOffsetMeansAtTheStart() {
        let planned = startNotifications(event(override: .offset(0)), settings())
        XCTAssertEqual(planned.first?.fireDate, now.addingTimeInterval(60 * 60))
    }

    // MARK: - Suppression

    func testSuppressedSilencesThisEventWhileTheGlobalIsOn() {
        XCTAssertTrue(startNotifications(event(override: .suppressed), settings()).isEmpty)
    }

    func testSuppressedIsDistinctFromInherit() {
        XCTAssertTrue(startNotifications(event(override: .suppressed), settings(startEnabled: true)).isEmpty)
        XCTAssertFalse(startNotifications(event(override: nil), settings(startEnabled: true)).isEmpty)
    }

    // MARK: - Scope

    func testAnOverrideDoesNotAffectOtherEvents() {
        let overridden = event(id: "a", override: .offset(900))
        let plain = event(id: "b")
        let planned = NotificationPlanner.plan(
            events: [overridden, plain], settings: settings(startOffset: 300), now: now
        ).filter { $0.kind == .eventStart }

        XCTAssertEqual(planned.count, 2)
        let byID = Dictionary(uniqueKeysWithValues: planned.map { ($0.eventID, $0.fireDate) })
        XCTAssertEqual(byID["a"], now.addingTimeInterval(60 * 60 - 900))
        XCTAssertEqual(byID["b"], now.addingTimeInterval(60 * 60 - 300))
    }

    func testTheOverrideDoesNotTouchTheEndReminder() {
        // Only the start reminder is per-event; the other notifications ignore the override.
        let settings = NotificationPlanningSettings(
            eventStart: .init(enabled: true, offset: 300),
            eventEnd: .init(enabled: true, offset: 0),
            fullscreen: .disabled,
            autoJoin: .disabled,
            scriptOnStart: .disabled,
            dismissedEventIDs: []
        )
        let planned = NotificationPlanner.plan(
            events: [event(override: .suppressed)], settings: settings, now: now
        )
        XCTAssertTrue(planned.contains { $0.kind == .eventEnd })
        XCTAssertFalse(planned.contains { $0.kind == .eventStart })
    }

    func testASuppressedEventStillObeysDismissal() {
        let planned = NotificationPlanner.plan(
            events: [event(id: "a", override: .offset(60))],
            settings: NotificationPlanningSettings(
                eventStart: .init(enabled: true, offset: 300),
                eventEnd: .disabled,
                fullscreen: .disabled,
                autoJoin: .disabled,
                scriptOnStart: .disabled,
                dismissedEventIDs: ["a"]
            ),
            now: now
        )
        XCTAssertTrue(planned.isEmpty, "a dismissed event is out regardless of its override")
    }

    // MARK: - Identity

    func testChangingTheOverrideChangesTheNotificationIdentity() {
        // The identity carries the offset, so a re-plan replaces the scheduled
        // notification instead of leaving the old time live alongside it.
        let first = startNotifications(event(override: .offset(300)), settings()).first
        let second = startNotifications(event(override: .offset(900)), settings()).first
        XCTAssertNotNil(first?.identity)
        XCTAssertNotEqual(first?.identity, second?.identity)
    }

    func testAPastFireDateIsNotPlanned() {
        // An override far enough back to have already passed must not schedule.
        let planned = startNotifications(
            event(startsInMinutes: 5, override: .offset(3600)), settings()
        )
        XCTAssertTrue(planned.isEmpty)
    }
}
