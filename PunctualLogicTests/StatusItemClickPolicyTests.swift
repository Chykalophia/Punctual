//
//  StatusItemClickPolicyTests.swift
//  PunctualLogicTests
//
//  Pins how a status-item click is read, including the ways macOS 27 delivers
//  one: with no mouse event behind it, or as a lone mouse-up.
//

import XCTest

@testable import PunctualLogic

final class StatusItemClickPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func outcome(
        _ input: StatusItemClickPolicy.Input,
        control: Bool = false,
        lastDown: StatusItemClickPolicy.HandledDown? = nil,
        at time: Date? = nil
    ) -> StatusItemClickPolicy.Outcome {
        StatusItemClickPolicy.outcome(
            for: input,
            controlKeyHeld: control,
            lastDown: lastDown,
            now: time ?? now
        )
    }

    private func down(
        _ button: StatusItemClickPolicy.HandledDown.Button,
        secondsAgo: TimeInterval
    ) -> StatusItemClickPolicy.HandledDown {
        .init(button: button, at: now.addingTimeInterval(-secondsAgo))
    }

    // MARK: - Primary clicks

    func testLeftMouseDownOpensThePanel() {
        XCTAssertEqual(outcome(.leftMouseDown), .primary)
    }

    func testTheMouseUpOfAHandledClickIsIgnored() {
        XCTAssertEqual(outcome(.leftMouseUp, lastDown: down(.left, secondsAgo: 0.1)), .ignore)
    }

    /// macOS 27: the click arrives as a mouse-up only. Before, this did nothing.
    func testALoneMouseUpStillOpensThePanel() {
        XCTAssertEqual(outcome(.leftMouseUp), .primary)
    }

    func testAMouseUpLongAfterTheLastDownIsANewClick() {
        XCTAssertEqual(outcome(.leftMouseUp, lastDown: down(.left, secondsAgo: 5)), .primary)
    }

    /// macOS 27: the click arrives with no mouse event at all (also the path the
    /// keyboard shortcut takes). Before, any non-mouse event was dropped.
    func testAnEventlessClickOpensThePanel() {
        XCTAssertEqual(outcome(.nonMouse), .primary)
        XCTAssertEqual(outcome(.nonMouse, lastDown: down(.left, secondsAgo: 0.1)), .primary)
    }

    /// The reported macOS 27 bug: after the right-click menu was used once,
    /// left clicks stopped working. A right-click must never swallow the next
    /// left click.
    func testARightClickNeverSwallowsTheNextLeftClick() {
        XCTAssertEqual(outcome(.leftMouseUp, lastDown: down(.right, secondsAgo: 0.1)), .primary)
        XCTAssertEqual(outcome(.leftMouseDown, lastDown: down(.right, secondsAgo: 0.1)), .primary)
    }

    func testAClockThatRanBackwardsDoesNotSwallowAClick() {
        XCTAssertEqual(outcome(.leftMouseUp, lastDown: down(.left, secondsAgo: -10)), .primary)
    }

    // MARK: - Secondary clicks

    func testARightClickOpensTheMenuOnWhicheverHalfArrivesFirst() {
        XCTAssertEqual(outcome(.rightMouseDown), .secondary)
        XCTAssertEqual(outcome(.rightMouseUp), .secondary)
    }

    func testTheMouseUpOfAHandledRightClickIsIgnored() {
        XCTAssertEqual(outcome(.rightMouseUp, lastDown: down(.right, secondsAgo: 0.2)), .ignore)
    }

    func testAControlClickOpensTheMenu() {
        XCTAssertEqual(outcome(.leftMouseDown, control: true), .secondary)
        XCTAssertEqual(outcome(.leftMouseUp, control: true), .secondary)
        XCTAssertEqual(
            outcome(.leftMouseUp, control: true, lastDown: down(.left, secondsAgo: 0.1)),
            .ignore
        )
    }

    // MARK: - What gets remembered

    func testOnlyAMouseDownIsRemembered() {
        XCTAssertEqual(
            StatusItemClickPolicy.handledDown(after: .leftMouseDown, now: now),
            .init(button: .left, at: now)
        )
        XCTAssertEqual(
            StatusItemClickPolicy.handledDown(after: .rightMouseDown, now: now),
            .init(button: .right, at: now)
        )
        XCTAssertNil(StatusItemClickPolicy.handledDown(after: .leftMouseUp, now: now))
        XCTAssertNil(StatusItemClickPolicy.handledDown(after: .rightMouseUp, now: now))
        XCTAssertNil(StatusItemClickPolicy.handledDown(after: .nonMouse, now: now))
    }
}
