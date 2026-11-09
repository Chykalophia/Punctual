//
//  DropdownInspectorWindow.swift
//  Punctual
//
//  DEBUG-only development aid: hosts the real dropdown panel in a window that
//  STAYS OPEN, so the panel can be screenshotted and inspected from another
//  process.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

#if DEBUG
import AppKit

/// A borderless copy of the dropdown panel that stays open when it loses focus, for
/// screenshots and inspection. Dismissed by Escape or by re-running the deep link.
final class DropdownInspectorWindow: NSWindow {
    /// Fires just before close so the coordinator can drop its reference.
    var onClose: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            close()
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_: Any?) {
        close()
    }

    // No `resignKey` override: losing focus must leave this window on screen.

    override func close() {
        let handler = onClose
        onClose = nil
        handler?()
        super.close()
    }

    /// Whether `url` is the inspector's deep link (`punctual://dropdown-debug`). Matched
    /// outside `URLHandler` so no DEBUG-only case reaches `AppRoute`.
    static func matches(_ url: URL) -> Bool {
        url.scheme == "punctual" && url.host == "dropdown-debug"
    }
}

/// Everything needed to host the real dropdown panel in the inspector window.
struct DropdownInspectorSnapshot {
    let state: StatusBarMenuState
    let handlers: DropdownPanelHandlers
    /// The live status-item rect when there is one, so the panel lands where a
    /// click would put it. `nil` falls back to a synthetic top-right anchor.
    let anchor: NSRect?
}

enum DropdownInspectorPresentationPolicy {
    /// Above ordinary windows, below a real `.popUpMenu`.
    static let level: NSWindow.Level = .floating

    /// Fallback anchor at the screen's top-right: a zero-size rect on the menu-bar line, so
    /// the shared placement math treats it like a status-item anchor.
    static func syntheticAnchor(in screenFrame: NSRect) -> NSRect {
        NSRect(x: screenFrame.maxX - 80, y: screenFrame.maxY, width: 0, height: 0)
    }
}
#endif
