//
//  DropdownPanelPlacement.swift
//  Punctual
//
//  Hostless placement math for the dropdown panel: hangs below the status item
//  and stays inside the screen's visible frame.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import CoreGraphics

/// Where the dropdown panel's window goes, in AppKit screen coordinates
/// (bottom-left origin, y increasing upwards).
enum DropdownPanelPlacement {
    /// Breathing room kept between the panel and the edges of the visible frame.
    static let screenEdgeInset: CGFloat = 8

    /// Gap between the bottom of the status-item button and the top of the panel.
    static let statusItemGap: CGFloat = 4

    /// Minimum height when the space below the status item is very small; the
    /// panel scrolls its content beyond that.
    static let minimumHeight: CGFloat = 160

    /// The panel frame for a status item at `anchor` (its button rect in screen
    /// coordinates) on the screen whose visible frame is `screen`.
    ///
    /// Hangs directly below the anchor, centered on it, clamped to the visible
    /// frame's left/right edges, with height trimmed by `resolvedHeight`.
    static func frame(for anchor: CGRect, panelSize: CGSize, screen: CGRect) -> CGRect {
        let height = resolvedHeight(panelHeight: panelSize.height, anchor: anchor, screen: screen)
        let top = anchor.minY - statusItemGap
        let originY = max(screen.minY + screenEdgeInset, top - height)

        let centered = anchor.midX - panelSize.width / 2
        let rightLimit = screen.maxX - screenEdgeInset - panelSize.width
        let originX = max(screen.minX + screenEdgeInset, min(centered, rightLimit))

        return CGRect(x: originX, y: originY, width: panelSize.width, height: height)
    }

    /// The panel height once trimmed to the space between the status item and the
    /// bottom of the visible frame, never below `minimumHeight` (or the panel's
    /// own height, when the content is shorter than that floor).
    static func resolvedHeight(
        panelHeight: CGFloat,
        anchor: CGRect,
        screen: CGRect
    ) -> CGFloat {
        let available = anchor.minY - statusItemGap - (screen.minY + screenEdgeInset)
        guard available < panelHeight else { return panelHeight }
        return max(available, min(panelHeight, minimumHeight))
    }
}
