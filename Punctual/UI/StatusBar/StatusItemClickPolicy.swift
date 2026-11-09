//
//  StatusItemClickPolicy.swift
//  Punctual
//
//  Decides what a click on the status item means from the event behind the
//  button's action. On macOS 27 a click may arrive with no mouse event or only
//  its mouse-up, so the first half to arrive acts and its partner is swallowed.
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
        /// No current event, or not a mouse button event (macOS 27 action path).
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

    /// What a status-item action call should do.
    ///
    /// Downs and ups are paired by order, not time.
    ///
    /// - Parameters:
    ///   - input: The event behind this action call.
    ///   - controlKeyHeld: Whether Control was held, making a left click secondary.
    ///   - pendingDown: The button whose mouse-down was acted on and whose
    ///     mouse-up has not arrived yet, if any.
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
            if pendingDown == .right { return .ignore }
            return .secondary
        case .nonMouse:
            // No reliable modifier state without a mouse event.
            return .primary
        }
    }

    /// The pending mouse-down to remember after `input`: set by a down, cleared
    /// by anything else.
    static func pendingDown(after input: Input) -> Button? {
        switch input {
        case .leftMouseDown: .left
        case .rightMouseDown: .right
        case .leftMouseUp, .rightMouseUp, .nonMouse: nil
        }
    }
}
