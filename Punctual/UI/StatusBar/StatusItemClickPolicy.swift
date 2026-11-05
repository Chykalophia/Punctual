//
//  StatusItemClickPolicy.swift
//  Punctual
//
//  Decides what a click on the status item means, from the event AppKit hands
//  the button's action (or the lack of one).
//
//  Why this exists: macOS 27 changed how a status-item click reaches the app.
//  A click can now arrive through the status item's own one-shot action path,
//  which calls the action with NO mouse event behind it (`NSApp.currentEvent`
//  is nil, or is whatever non-mouse event happened to be current), or with only
//  the mouse-up half of the click. The old handler acted on left-mouse-DOWN
//  only and dropped everything that was not a mouse event, so on macOS 27 a
//  click could do nothing at all — most visibly after the right-click menu had
//  been used once, which is the same failure other menu-bar apps reported.
//
//  The rule now: act on the FIRST half of a primary click that arrives, and
//  swallow the second half only when its partner was actually seen. A lone
//  mouse-up (no down delivered) therefore still opens the panel, and a click
//  with no mouse event at all is treated as a plain left click.
//
//  Pure so it is testable without a window server.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Foundation

enum StatusItemClickPolicy {
    /// The event AppKit reports as current when the status item's action fires,
    /// reduced to what matters here.
    enum Input: Equatable, Sendable {
        case leftMouseDown
        case leftMouseUp
        case rightMouseDown
        case rightMouseUp
        /// No current event, or one that is not a mouse button event at all.
        /// macOS 27's one-shot action path delivers clicks like this.
        case nonMouse
    }

    enum Outcome: Equatable, Sendable {
        /// A primary click: open or close the panel (or hit the Join chip).
        case primary
        /// A secondary click: show the quick-actions menu.
        case secondary
        /// The second half of a click whose first half was already acted on.
        case ignore
    }

    /// The mouse-down this policy last acted on, so its mouse-up can be
    /// recognised as the second half of the same click.
    struct HandledDown: Equatable, Sendable {
        enum Button: Equatable, Sendable { case left, right }
        var button: Button
        var at: Date
    }

    /// How long after a handled mouse-down its mouse-up is still treated as the
    /// same click. Generous: a press held on the item is still one click, and
    /// the cost of a too-long window is only that a SECOND deliberate click,
    /// arriving as a lone mouse-up within it, is ignored.
    static let clickPairingWindow: TimeInterval = 1.5

    /// - Parameters:
    ///   - input: the event behind this action call.
    ///   - controlKeyHeld: whether ⌃ was held, which makes a left click a
    ///     secondary click, as it does everywhere else on the Mac.
    ///   - lastDown: the mouse-down last acted on, if any.
    ///   - now: the current time.
    static func outcome(
        for input: Input,
        controlKeyHeld: Bool,
        lastDown: HandledDown?,
        now: Date
    ) -> Outcome {
        switch input {
        case .leftMouseDown:
            return controlKeyHeld ? .secondary : .primary
        case .rightMouseDown:
            return .secondary
        case .leftMouseUp:
            if pairs(.left, with: lastDown, now: now) { return .ignore }
            return controlKeyHeld ? .secondary : .primary
        case .rightMouseUp:
            // Up to macOS 26 the button delivered a right click on its up edge
            // only; whichever half arrives first opens the menu, once.
            if pairs(.right, with: lastDown, now: now) { return .ignore }
            return .secondary
        case .nonMouse:
            return .primary
        }
    }

    /// The value to remember after acting on `input` at `now`: a mouse-down is
    /// recorded so its mouse-up can be swallowed; anything else clears it, so a
    /// stale down can never swallow a later, unrelated click.
    static func handledDown(after input: Input, now: Date) -> HandledDown? {
        switch input {
        case .leftMouseDown: HandledDown(button: .left, at: now)
        case .rightMouseDown: HandledDown(button: .right, at: now)
        case .leftMouseUp, .rightMouseUp, .nonMouse: nil
        }
    }

    private static func pairs(
        _ button: HandledDown.Button,
        with lastDown: HandledDown?,
        now: Date
    ) -> Bool {
        guard let lastDown, lastDown.button == button else { return false }
        let elapsed = now.timeIntervalSince(lastDown.at)
        return elapsed >= 0 && elapsed < clickPairingWindow
    }
}
