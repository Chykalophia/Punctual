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
//  The rule now: act on the FIRST half of a click that arrives, and swallow
//  the second half only when its partner was actually seen. A lone
//  mouse-up (no down delivered) therefore still opens the panel, and a click
//  with no mouse event at all is treated as a plain left click.
//
//  Pure so it is testable without a window server.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

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

    /// The button whose mouse-down this policy last acted on, so its mouse-up
    /// can be recognised as the second half of the same click.
    enum Button: Equatable, Sendable { case left, right }

    /// - Parameters:
    ///   - input: the event behind this action call.
    ///   - controlKeyHeld: whether ⌃ was held, which makes a left click a
    ///     secondary click, as it does everywhere else on the Mac.
    ///   - pendingDown: the button whose mouse-down was acted on and whose
    ///     mouse-up has not arrived yet, if any.
    ///
    /// Pairing is by order, not by time: a press held on the item for as long
    /// as you like is still one click. A down whose up never arrives can cost at
    /// most one later lone-up click, since consuming an up clears the pairing.
    static func outcome(
        for input: Input,
        controlKeyHeld: Bool,
        pendingDown: Button?
    ) -> Outcome {
        switch input {
        case .leftMouseDown:
            return controlKeyHeld ? .secondary : .primary
        case .rightMouseDown:
            return .secondary
        case .leftMouseUp:
            if pendingDown == .left { return .ignore }
            return controlKeyHeld ? .secondary : .primary
        case .rightMouseUp:
            // Up to macOS 26 the button delivered a right click on its up edge
            // only; whichever half arrives first opens the menu, once.
            if pendingDown == .right { return .ignore }
            return .secondary
        case .nonMouse:
            // No mouse event means no reliable modifier state to read, so this
            // is always the plain click.
            return .primary
        }
    }

    /// What to remember after `input`, whatever its outcome: a mouse-down is
    /// remembered so its mouse-up can be swallowed; anything else clears it,
    /// so a consumed or stale down can never swallow a later click.
    static func pendingDown(after input: Input) -> Button? {
        switch input {
        case .leftMouseDown: .left
        case .rightMouseDown: .right
        case .leftMouseUp, .rightMouseUp, .nonMouse: nil
        }
    }
}
