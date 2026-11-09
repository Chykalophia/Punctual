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
    private func outcome(
        _ input: StatusItemClickPolicy.Input,
        control: Bool = false,
        pending: StatusItemClickPolicy.Button? = nil
    ) -> StatusItemClickPolicy.Outcome {
        StatusItemClickPolicy.outcome(for: input, controlKeyHeld: control, pendingDown: pending)
    }

    /// Runs a sequence of inputs through the policy the way the controller
    /// does, carrying the pending down from one call to the next.
    private func run(_ inputs: [StatusItemClickPolicy.Input]) -> [StatusItemClickPolicy.Outcome] {
        var pending: StatusItemClickPolicy.Button?
        return inputs.map { input in
            let result = outcome(input, pending: pending)
            pending = StatusItemClickPolicy.pendingDown(after: input)
            return result
        }
    }

    // MARK: - Primary clicks

    func testLeftMouseDownOpensThePanel() {
        XCTAssertEqual(outcome(.leftMouseDown), .primary)
    }

    /// Also covers a press held for any length of time: pairing is by order.
    func testTheMouseUpOfAHandledClickIsIgnored() {
        XCTAssertEqual(outcome(.leftMouseUp, pending: .left), .ignore)
    }

    /// macOS 27: the click arrives as a mouse-up only. Before, this did nothing.
    func testALoneMouseUpStillOpensThePanel() {
        XCTAssertEqual(outcome(.leftMouseUp), .primary)
    }

    /// macOS 27: the click arrives with no mouse event at all, or alongside a
    /// non-mouse event (also the path the keyboard shortcut takes). There is no
    /// modifier state worth trusting there, so ⌃ does not change it.
    func testAnEventlessClickOpensThePanel() {
        XCTAssertEqual(outcome(.nonMouse), .primary)
        XCTAssertEqual(outcome(.nonMouse, pending: .left), .primary)
        XCTAssertEqual(outcome(.nonMouse, control: true), .primary)
    }

    /// The reported macOS 27 bug: after the right-click menu was used once,
    /// left clicks stopped working. A right-click must never swallow the next
    /// left click.
    func testARightClickNeverSwallowsTheNextLeftClick() {
        XCTAssertEqual(outcome(.leftMouseUp, pending: .right), .primary)
        XCTAssertEqual(outcome(.leftMouseDown, pending: .right), .primary)
    }

    // MARK: - Sequences

    func testAFullClickActsOnce() {
        XCTAssertEqual(run([.leftMouseDown, .leftMouseUp]), [.primary, .ignore])
    }

    /// Consuming the up clears the pairing, so two up-only clicks in a row
    /// after a full click both register.
    func testAConsumedMouseUpDoesNotSwallowTheNextClick() {
        XCTAssertEqual(
            run([.leftMouseDown, .leftMouseUp, .leftMouseUp, .leftMouseUp]),
            [.primary, .ignore, .primary, .primary]
        )
    }

    func testTwoFullClicksToggleTwice() {
        XCTAssertEqual(
            run([.leftMouseDown, .leftMouseUp, .leftMouseDown, .leftMouseUp]),
            [.primary, .ignore, .primary, .ignore]
        )
    }

    /// The right-click menu is modal and can eat its own mouse-up, leaving the
    /// right down pending. The next left click must still land.
    func testALeftClickAfterARightClickWhoseUpWasEatenLands() {
        XCTAssertEqual(
            run([.rightMouseDown, .leftMouseDown, .leftMouseUp]),
            [.secondary, .primary, .ignore]
        )
    }

    // MARK: - Secondary clicks

    func testARightClickOpensTheMenuOnWhicheverHalfArrivesFirst() {
        XCTAssertEqual(outcome(.rightMouseDown), .secondary)
        XCTAssertEqual(outcome(.rightMouseUp), .secondary)
        XCTAssertEqual(run([.rightMouseDown, .rightMouseUp]), [.secondary, .ignore])
    }

    func testAControlClickOpensTheMenu() {
        XCTAssertEqual(outcome(.leftMouseDown, control: true), .secondary)
        XCTAssertEqual(outcome(.leftMouseUp, control: true), .secondary)
        XCTAssertEqual(outcome(.leftMouseUp, control: true, pending: .left), .ignore)
    }

    // MARK: - What gets remembered

    func testOnlyAMouseDownIsRemembered() {
        XCTAssertEqual(StatusItemClickPolicy.pendingDown(after: .leftMouseDown), .left)
        XCTAssertEqual(StatusItemClickPolicy.pendingDown(after: .rightMouseDown), .right)
        XCTAssertNil(StatusItemClickPolicy.pendingDown(after: .leftMouseUp))
        XCTAssertNil(StatusItemClickPolicy.pendingDown(after: .rightMouseUp))
        XCTAssertNil(StatusItemClickPolicy.pendingDown(after: .nonMouse))
    }
}
