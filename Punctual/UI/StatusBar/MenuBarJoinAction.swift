//
//  MenuBarJoinAction.swift
//  Punctual
//
//  Hostless policy and geometry for the menu bar's "Join" chip: whether it shows
//  and where it sits. The drawn capsule and the click hit-test share one rect.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Foundation

/// The user's answers on the Menu Bar pane, snapshotted for the policy.
struct MenuBarJoinActionSettings: Equatable {
    /// "Show a Join button in the menu bar".
    var isEnabled: Bool
    /// Minutes before the start that the chip appears; `0` means only while running.
    var leadMinutes: Int
    /// The chip's text, localized by the caller (`"Join"`).
    var label: String

    /// Settings that never show a chip; the default for `MenuBarComposedSettings`.
    static let disabled = MenuBarJoinActionSettings(isEnabled: false, leadMinutes: 0, label: "")
}

enum MenuBarJoinActionPolicy {
    /// The chip's text, or `""` when the menu bar should not show one.
    ///
    /// Shown only when enabled, the event has a meeting link, the label is
    /// non-empty, and the meeting is imminent per `EventActionProminence`.
    static func label(
        event: StatusBarEventPresentationInput,
        settings: MenuBarJoinActionSettings,
        now: Date
    ) -> String {
        guard settings.isEnabled, event.hasMeetingLink else { return "" }

        let trimmed = settings.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        guard EventActionProminence.isImminent(
            start: event.startDate,
            end: event.endDate,
            now: now,
            leadMinutes: settings.leadMinutes
        ) else { return "" }

        return trimmed
    }

    /// The instant the chip becomes due for `eventStart`, used to schedule an
    /// exact redraw for meetings that do not start on a whole minute.
    ///
    /// - Returns: `nil` when the chip is disabled.
    static func appearanceDate(
        eventStart: Date,
        settings: MenuBarJoinActionSettings
    ) -> Date? {
        guard settings.isEnabled else { return nil }
        return eventStart.addingTimeInterval(-Double(max(0, settings.leadMinutes)) * 60)
    }
}

/// The status-item measurements the chip's geometry depends on.
struct MenuBarActionChipMetrics: Equatable {
    /// The status item's bounds, in its own (non-flipped, y-up) coordinates.
    var buttonBounds: CGRect
    /// Width of the status icon, or `0` when the item has no image.
    var imageWidth: CGFloat
    /// Whether that icon draws after the text (the user put the icon block last).
    var imageIsTrailing: Bool
    /// The widest rendered line, which the item is sized to.
    var titleWidth: CGFloat
    /// Width of the line the chip sits on: `titleWidth` on one line, the lower
    /// (detail) line on two.
    var lineWidth: CGFloat
    /// Rendered width of the chip's own text.
    var labelWidth: CGFloat
    /// The two-line layout, where the chip rides the lower line.
    var isStacked: Bool
}

/// Where the Join chip sits inside the status item, in the button's own
/// (non-flipped, y-up) coordinates.
///
/// The chip is the last run of the last line and anchors to the end of that
/// line, not the item's edge: each line is centred independently.
enum MenuBarActionChipGeometry {
    /// Breathing room drawn around the label run, per side.
    static let horizontalPadding: CGFloat = 4
    /// Gap kept between the capsule and the top and bottom of the menu bar.
    static let verticalInset: CGFloat = 2
    /// Fraction of the item's height the capsule takes on the two-line layout.
    static let stackedHeightFraction: CGFloat = 0.46
    /// Approximate gap `NSButton` leaves between image and title (unpublished by AppKit).
    static let imageTitleSpacing: CGFloat = 2
    /// Used when the derived inset is implausible; see `edgeInset`.
    static let fallbackEdgeInset: CGFloat = 4
    /// Widest inset `edgeInset` will believe.
    static let maximumEdgeInset: CGFloat = 12

    /// The padding `NSStatusBarButton` puts either side of its content.
    ///
    /// Derived as half the difference between button and content width, since
    /// AppKit does not publish it. Values outside `0...maximumEdgeInset` fall back
    /// to `fallbackEdgeInset`.
    static func edgeInset(buttonWidth: CGFloat, contentWidth: CGFloat) -> CGFloat {
        let derived = (buttonWidth - contentWidth) / 2
        guard derived >= 0, derived <= maximumEdgeInset else { return fallbackEdgeInset }
        return derived
    }

    /// The capsule to draw, or `nil` when there is nothing to draw or no room.
    static func rect(_ metrics: MenuBarActionChipMetrics) -> CGRect? {
        let bounds = metrics.buttonBounds
        guard metrics.labelWidth > 0, bounds.width > 0, bounds.height > 0 else { return nil }

        let imageSlot = metrics.imageWidth > 0 ? metrics.imageWidth + imageTitleSpacing : 0
        let inset = edgeInset(
            buttonWidth: bounds.width,
            contentWidth: metrics.titleWidth + imageSlot
        )

        // The box the title is centred in.
        let titleMinX = bounds.minX + inset + (metrics.imageIsTrailing ? 0 : imageSlot)
        let titleMaxX = bounds.maxX - inset - (metrics.imageIsTrailing ? imageSlot : 0)
        guard titleMaxX > titleMinX else { return nil }

        let lineMaxX = (titleMinX + titleMaxX) / 2 + metrics.lineWidth / 2
        let maxX = min(lineMaxX + horizontalPadding, bounds.maxX)
        let minX = lineMaxX - metrics.labelWidth - horizontalPadding
        guard minX >= bounds.minX, maxX > minX else { return nil }

        let height = metrics.isStacked
            ? bounds.height * stackedHeightFraction
            : bounds.height - verticalInset * 2
        guard height > 0 else { return nil }
        // y-up, so the stack's lower line sits at the bottom of the item.
        let minY = metrics.isStacked
            ? bounds.minY + verticalInset / 2
            : bounds.minY + verticalInset

        return CGRect(x: minX, y: minY, width: maxX - minX, height: height)
    }

    /// The click target for a drawn chip: the chip's horizontal span at the full
    /// button height, since the stacked capsule is only a few points tall.
    static func hitRect(chip: CGRect, buttonBounds: CGRect) -> CGRect {
        CGRect(x: chip.minX, y: buttonBounds.minY, width: chip.width, height: buttonBounds.height)
    }
}
