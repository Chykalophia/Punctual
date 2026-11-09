//
//  MeetingProgressRenderer.swift
//  Punctual
//
//  Draws menu-bar meeting progress resolved by `MeetingProgressPolicy`.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import AppKit

/// Colours and dimensions for the menu-bar indicator.
enum MeetingProgressStyleMetrics {
    /// Colour of the unfilled track.
    static let trackColor: NSColor = .labelColor

    /// Fill colour for a phase.
    ///
    /// `labelColor` (phase shown as brightness) rather than the accent colour: the
    /// menu bar's tint follows the wallpaper and can match the accent. Red = running.
    static func fillColor(for phase: MeetingProgressPresentation.Phase) -> NSColor {
        switch phase {
        case .upcoming: NSColor.labelColor.withAlphaComponent(0.70)
        case .imminent: .labelColor
        case .running: .systemRed
        }
    }

    /// Opacity of the unfilled track.
    static let trackAlpha: CGFloat = 0.28

    static let underlineHeight: CGFloat = 2
    /// Gap between the underline and the bottom of the item.
    static let underlineBottomInset: CGFloat = 2
    static let ringLineWidth: CGFloat = 1.75
    static let capsuleLineWidth: CGFloat = 1
    /// Opacities of the capsule's background and unfilled border.
    static let capsuleBackgroundAlpha: CGFloat = 0.14
    static let capsuleBorderAlpha: CGFloat = 0.26
    /// Line width of the filled part of the capsule's border.
    static let capsuleProgressLineWidth: CGFloat = 2.5
    /// Width of the standalone bar, in the status item's image slot.
    static let barSize = NSSize(width: 22, height: 5)
    /// Inset the ring keeps from the icon box so it never touches the glyph.
    static let ringPadding: CGFloat = 1.5
    /// Diameter of the standalone ring (no icon to encircle); matches the menu-bar icon size.
    static let standaloneRingSide: CGFloat = 14
}

/// A transparent, click-through overlay on the status-item button that draws the
/// indicator on top of AppKit's own rendering.
///
/// An overlay on purpose: redrawing the item would mean reimplementing AppKit's
/// native title rendering (appearance adaptation, highlight inversion).
final class MeetingProgressOverlayView: NSView {
    var style: MeetingProgressStyle = .none {
        didSet { if style != oldValue { needsDisplay = true } }
    }

    var presentation: MeetingProgressPresentation? {
        didSet { if presentation != oldValue { needsDisplay = true } }
    }

    /// Width of the leading icon for the ring to encircle. Supplied by the caller,
    /// since the status item does not expose the icon's frame.
    var iconWidth: CGFloat = 0

    /// Passes all clicks through to the status item underneath.
    override func hitTest(_: NSPoint) -> NSView? { nil }

    override var isFlipped: Bool { false }

    override func draw(_: NSRect) {
        guard let presentation, style.drawsSomething, !bounds.isEmpty else { return }
        let color = MeetingProgressStyleMetrics.fillColor(for: presentation.phase)

        switch style {
        case .none, .bar:
            // `.bar` is drawn into the image slot by `MeetingProgressRenderer.barImage`.
            break
        case .underline:
            drawUnderline(fraction: presentation.fraction, color: color)
        case .ring:
            drawRing(fraction: presentation.fraction, color: color)
        case .capsule:
            drawCapsule(fraction: presentation.fraction, color: color)
        }
    }

    private func drawUnderline(fraction: Double, color: NSColor) {
        let height = MeetingProgressStyleMetrics.underlineHeight
        let baseline = MeetingProgressStyleMetrics.underlineBottomInset
        let track = NSRect(x: 0, y: baseline, width: bounds.width, height: height)
        MeetingProgressStyleMetrics.trackColor
            .withAlphaComponent(MeetingProgressStyleMetrics.trackAlpha).setFill()
        NSBezierPath(roundedRect: track, xRadius: height / 2, yRadius: height / 2).fill()

        guard fraction > 0 else { return }
        let filled = NSRect(x: 0, y: baseline, width: bounds.width * fraction, height: height)
        color.setFill()
        NSBezierPath(roundedRect: filled, xRadius: height / 2, yRadius: height / 2).fill()
    }

    /// A ring that fills clockwise from 12 o'clock, like a countdown timer.
    private func drawRing(fraction: Double, color: NSColor) {
        let side = min(iconWidth > 0 ? iconWidth : bounds.height, bounds.height)
            - MeetingProgressStyleMetrics.ringPadding
        guard side > 4 else { return }

        let center = NSPoint(x: side / 2 + MeetingProgressStyleMetrics.ringPadding, y: bounds.midY)
        let radius = side / 2

        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = MeetingProgressStyleMetrics.ringLineWidth
        MeetingProgressStyleMetrics.trackColor
            .withAlphaComponent(MeetingProgressStyleMetrics.trackAlpha).setStroke()
        track.stroke()

        guard fraction > 0 else { return }
        // AppKit angles run counter-clockwise from 3 o'clock; sweep clockwise from 12.
        let arc = NSBezierPath()
        arc.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 90,
            endAngle: 90 - 360 * fraction,
            clockwise: true
        )
        arc.lineWidth = MeetingProgressStyleMetrics.ringLineWidth
        arc.lineCapStyle = .round
        color.setStroke()
        arc.stroke()
    }

    /// A capsule whose border fills left to right over a faint interior tint.
    ///
    /// The border, not the interior, carries progress: this overlay draws on top of
    /// the title, so a visible interior fill would obscure it.
    private func drawCapsule(fraction: Double, color: NSColor) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        guard rect.width > 4, rect.height > 4 else { return }
        let radius = rect.height / 2
        let outline = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

        NSGraphicsContext.saveGraphicsState()
        outline.addClip()
        MeetingProgressStyleMetrics.trackColor
            .withAlphaComponent(MeetingProgressStyleMetrics.capsuleBackgroundAlpha).setFill()
        rect.fill()
        NSGraphicsContext.restoreGraphicsState()

        outline.lineWidth = MeetingProgressStyleMetrics.capsuleLineWidth
        MeetingProgressStyleMetrics.trackColor
            .withAlphaComponent(MeetingProgressStyleMetrics.capsuleBorderAlpha).setStroke()
        outline.stroke()

        guard fraction > 0 else { return }
        // Full-strength outline clipped to the progress fraction.
        NSGraphicsContext.saveGraphicsState()
        NSRect(
            x: bounds.minX,
            y: bounds.minY,
            width: rect.minX + rect.width * fraction,
            height: bounds.height
        ).clip()
        let progress = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        progress.lineWidth = MeetingProgressStyleMetrics.capsuleProgressLineWidth
        color.setStroke()
        progress.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }
}

enum MeetingProgressRenderer {
    /// The ring as a standalone image for the status item's image slot, used when
    /// the item shows no icon (an overlay ring would land on the title text).
    @MainActor
    static func ringImage(for presentation: MeetingProgressPresentation) -> NSImage {
        let side = MeetingProgressStyleMetrics.standaloneRingSide
        let color = MeetingProgressStyleMetrics.fillColor(for: presentation.phase)
        let lineWidth = MeetingProgressStyleMetrics.ringLineWidth

        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius = side / 2 - lineWidth / 2

            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            track.lineWidth = lineWidth
            MeetingProgressStyleMetrics.trackColor
                .withAlphaComponent(MeetingProgressStyleMetrics.trackAlpha).setStroke()
            track.stroke()

            guard presentation.fraction > 0 else { return true }
            let arc = NSBezierPath()
            arc.appendArc(
                withCenter: center,
                radius: radius,
                startAngle: 90,
                endAngle: 90 - 360 * presentation.fraction,
                clockwise: true
            )
            arc.lineWidth = lineWidth
            arc.lineCapStyle = .round
            color.setStroke()
            arc.stroke()
            return true
        }
        image.isTemplate = false
        return image
    }

    /// The standalone mini-bar as an image for the status item's image slot.
    ///
    /// Not a template image, so the phase colour is not flattened to the menu-bar tint.
    @MainActor
    static func barImage(for presentation: MeetingProgressPresentation) -> NSImage {
        let size = MeetingProgressStyleMetrics.barSize
        let color = MeetingProgressStyleMetrics.fillColor(for: presentation.phase)
        let image = NSImage(size: size, flipped: false) { rect in
            let radius = rect.height / 2
            MeetingProgressStyleMetrics.trackColor
                .withAlphaComponent(MeetingProgressStyleMetrics.trackAlpha).setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()

            guard presentation.fraction > 0 else { return true }
            let filled = NSRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width * presentation.fraction,
                height: rect.height
            )
            color.setFill()
            NSBezierPath(roundedRect: filled, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
