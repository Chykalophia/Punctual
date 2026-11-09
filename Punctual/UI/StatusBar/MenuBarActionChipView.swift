//
//  MenuBarActionChipView.swift
//  Punctual
//
//  Draws the capsule around the menu bar's Join label at the rect from
//  `MenuBarActionChipGeometry`, as an overlay on AppKit's own title rendering.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import AppKit

enum MenuBarActionChipMetricsStyle {
    /// `labelColor`, not the accent; see `MeetingProgressStyleMetrics.fillColor`.
    static let color: NSColor = .labelColor
    /// Interior opacity; low so the label underneath stays readable.
    static let fillAlpha: CGFloat = 0.12
    static let borderAlpha: CGFloat = 0.45
    static let borderWidth: CGFloat = 1
}

/// A transparent overlay that strokes the Join chip's capsule.
final class MenuBarActionChipOverlayView: NSView {
    /// The capsule to draw, in this view's coordinates, or `nil` for no chip.
    var chipRect: CGRect? {
        didSet { if chipRect != oldValue { needsDisplay = true } }
    }

    /// Passes all clicks through; the status item's click handler hit-tests the chip.
    override func hitTest(_: NSPoint) -> NSView? { nil }

    override var isFlipped: Bool { false }

    override func draw(_: NSRect) {
        guard let chipRect, !chipRect.isEmpty else { return }

        let radius = chipRect.height / 2
        let capsule = NSBezierPath(roundedRect: chipRect, xRadius: radius, yRadius: radius)

        MenuBarActionChipMetricsStyle.color
            .withAlphaComponent(MenuBarActionChipMetricsStyle.fillAlpha).setFill()
        capsule.fill()

        capsule.lineWidth = MenuBarActionChipMetricsStyle.borderWidth
        MenuBarActionChipMetricsStyle.color
            .withAlphaComponent(MenuBarActionChipMetricsStyle.borderAlpha).setStroke()
        capsule.stroke()
    }
}
