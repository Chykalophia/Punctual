//
//  DropdownMetrics.swift
//  Punctual
//
//  The dropdown panel's layout grid and the pure agenda-row solver built on it.
//  Hostless (PunctualLogic): no AppKit, SwiftUI or Defaults, so it is unit-testable.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import CoreGraphics
import Foundation

// MARK: - Agenda row vocabulary

/// The calendar-colour marker on an agenda row. `.none` is the off state of
/// `showEventCalendarColor`.
public enum AgendaMarker: String, Codable, CaseIterable, Sendable {
    case none
    case dot
    case leftBorderBar
}

public enum AgendaMarkerPosition: String, Codable, CaseIterable, Sendable {
    /// Outside the row's padding, flush with the panel edge.
    case farLeft
    /// In the gutter between the time and the title.
    case betweenTimeAndTitle
}

/// What the leading time column shows. `showEventEndTime` selects between
/// `.startOnly` and `.startAndEnd`.
public enum AgendaTimeColumn: String, Codable, CaseIterable, Sendable {
    case hidden
    case startOnly
    case startAndEnd
}

// MARK: - Density

/// How tightly the dropdown packs its rows.
///
/// Three fixed steps rather than a free value, because each step's metrics are tuned
/// as a set. Density never changes the panel width.
public enum DropdownDensity: String, Codable, CaseIterable, Sendable {
    case compact
    /// Matches macOS menu row rhythm.
    case standard
    case roomy

    public var metrics: DropdownMetrics {
        switch self {
        case .compact: DropdownMetrics.compact
        case .standard: DropdownMetrics.standard
        case .roomy: DropdownMetrics.roomy
        }
    }
}

// MARK: - Metrics

/// Every fixed dimension in the dropdown panel, in points.
public struct DropdownMetrics: Equatable, Sendable {
    /// The panel's fixed width (`MeetingSummaryView.preferredWidth`).
    public var panelWidth: CGFloat
    /// Gap between the panel edge and a row's highlight capsule.
    public var rowOuterPadding: CGFloat
    /// Gap between the highlight capsule and the row's content.
    public var rowInnerPadding: CGFloat
    public var rowVerticalPadding: CGFloat
    /// The single gutter between adjacent columns in a row.
    public var columnSpacing: CGFloat
    /// Width of the leading time column when it is shown.
    public var timeColumnWidth: CGFloat
    public var markerDotDiameter: CGFloat
    public var markerBarWidth: CGFloat
    public var markerBarHeight: CGFloat
    /// Slot reserved for a meeting-service icon on an agenda row.
    public var serviceIconWidth: CGFloat
    /// Slot reserved for the leading SF Symbol on an action row.
    public var actionSymbolWidth: CGFloat
    /// Width of the hover-revealed Join pill. The pill is an overlay, so rows reserve
    /// only `trailingGlyphWidth` for it.
    public var trailingAffordanceWidth: CGFloat
    /// Slot reserved for the detail disclosure chevron.
    public var disclosureWidth: CGFloat
    /// Type size for a row's primary text (event title, action label).
    public var rowFontSize: CGFloat
    /// Type size for supporting text on a row (the time column, metadata).
    public var secondaryFontSize: CGFloat
    /// Inset between a card's edge and its content.
    public var cardHorizontalPadding: CGFloat
    public var cardVerticalPadding: CGFloat
    /// Card corner radius; scales with the card padding.
    public var cardCornerRadius: CGFloat
    /// Gap between stacked cards (`cardVerticalPadding` is the inset inside one).
    public var cardSpacing: CGFloat

    public init(
        panelWidth: CGFloat,
        rowOuterPadding: CGFloat,
        rowInnerPadding: CGFloat,
        rowVerticalPadding: CGFloat,
        columnSpacing: CGFloat,
        timeColumnWidth: CGFloat,
        markerDotDiameter: CGFloat,
        markerBarWidth: CGFloat,
        markerBarHeight: CGFloat,
        serviceIconWidth: CGFloat,
        actionSymbolWidth: CGFloat,
        trailingAffordanceWidth: CGFloat,
        disclosureWidth: CGFloat,
        rowFontSize: CGFloat = 13,
        secondaryFontSize: CGFloat = 12,
        cardHorizontalPadding: CGFloat = 10,
        cardVerticalPadding: CGFloat = 9,
        cardCornerRadius: CGFloat = 11,
        cardSpacing: CGFloat = 3
    ) {
        self.rowFontSize = rowFontSize
        self.secondaryFontSize = secondaryFontSize
        self.cardHorizontalPadding = cardHorizontalPadding
        self.cardVerticalPadding = cardVerticalPadding
        self.cardCornerRadius = cardCornerRadius
        self.cardSpacing = cardSpacing
        self.panelWidth = panelWidth
        self.rowOuterPadding = rowOuterPadding
        self.rowInnerPadding = rowInnerPadding
        self.rowVerticalPadding = rowVerticalPadding
        self.columnSpacing = columnSpacing
        self.timeColumnWidth = timeColumnWidth
        self.markerDotDiameter = markerDotDiameter
        self.markerBarWidth = markerBarWidth
        self.markerBarHeight = markerBarHeight
        self.serviceIconWidth = serviceIconWidth
        self.actionSymbolWidth = actionSymbolWidth
        self.trailingAffordanceWidth = trailingAffordanceWidth
        self.disclosureWidth = disclosureWidth
    }

    public static let standard = DropdownMetrics(
        panelWidth: 360,
        rowOuterPadding: 8,
        rowInnerPadding: 10,
        rowVerticalPadding: 6,
        columnSpacing: 9,
        timeColumnWidth: 58,
        markerDotDiameter: 7,
        markerBarWidth: 3,
        markerBarHeight: 16,
        serviceIconWidth: 14,
        actionSymbolWidth: 16,
        trailingAffordanceWidth: 48,
        disclosureWidth: 14,
        rowFontSize: 12.5,
        secondaryFontSize: 11.5,
        cardHorizontalPadding: 10,
        cardVerticalPadding: 9,
        cardCornerRadius: 11,
        cardSpacing: 3
    )

    /// Tighter vertical rhythm and a step down in type. The time column is sized
    /// to fit "12:00 PM" at this font.
    public static let compact = DropdownMetrics(
        panelWidth: 360,
        rowOuterPadding: 8,
        rowInnerPadding: 10,
        rowVerticalPadding: 3.5,
        columnSpacing: 8,
        timeColumnWidth: 54,
        markerDotDiameter: 6,
        markerBarWidth: 3,
        markerBarHeight: 13,
        serviceIconWidth: 14,
        actionSymbolWidth: 15,
        trailingAffordanceWidth: 46,
        disclosureWidth: 14,
        rowFontSize: 12,
        secondaryFontSize: 11,
        cardHorizontalPadding: 8,
        cardVerticalPadding: 6,
        cardCornerRadius: 9,
        cardSpacing: 1.5
    )

    /// More space per row; marker and column widths scale with the larger type.
    public static let roomy = DropdownMetrics(
        panelWidth: 360,
        rowOuterPadding: 8,
        rowInnerPadding: 11,
        rowVerticalPadding: 9,
        columnSpacing: 10,
        timeColumnWidth: 62,
        markerDotDiameter: 8,
        markerBarWidth: 3,
        markerBarHeight: 19,
        serviceIconWidth: 15,
        actionSymbolWidth: 17,
        trailingAffordanceWidth: 50,
        disclosureWidth: 15,
        rowFontSize: 14,
        secondaryFontSize: 12.5,
        cardHorizontalPadding: 12,
        cardVerticalPadding: 12,
        cardCornerRadius: 13,
        cardSpacing: 5
    )

    /// Distance from the panel's leading edge to a row's content box.
    public var rowLeadingInset: CGFloat { rowOuterPadding + rowInnerPadding }

    /// Leading inset for section headers; equal to `rowLeadingInset` so headers align with rows.
    public var sectionHeaderInset: CGFloat { rowLeadingInset }

    /// Indent of the inline detail disclosure.
    public var detailIndent: CGFloat { rowLeadingInset + columnSpacing * 2 }

    /// Width available to a row's content, between the two row insets.
    public var rowContentWidth: CGFloat { panelWidth - rowLeadingInset * 2 }

    /// Space a row reserves at its trailing edge for the resting meeting glyph.
    ///
    /// Density-independent, because the glyph is a fixed 10pt SF Symbol. The hover
    /// Join pill is an overlay and reserves nothing.
    public var trailingGlyphWidth: CGFloat { 16 }

    /// Width of the time column in a given mode.
    ///
    /// `.startAndEnd` keeps the same width and stacks the two times, since a
    /// single-line range would leave too little room for the title.
    public func timeColumnWidth(for column: AgendaTimeColumn) -> CGFloat {
        switch column {
        case .hidden: 0
        case .startOnly, .startAndEnd: timeColumnWidth
        }
    }
}

// MARK: - Agenda row layout

/// The solved geometry of one agenda row, measured from the leading edge of the
/// row's content box (inside `PanelRow`'s padding). Negative values lie outside
/// the padding, which is how a far-left marker reaches the panel edge.
public struct AgendaRowLayout: Equatable, Sendable {
    public struct MarkerFrame: Equatable, Sendable {
        public var x: CGFloat
        public var width: CGFloat
        public var height: CGFloat

        public var maxX: CGFloat { x + width }
    }

    public let marker: AgendaMarker
    /// The position actually used, which can differ from the one requested
    /// (a left border bar is only a border at the left edge).
    public let resolvedPosition: AgendaMarkerPosition
    public let timeColumn: AgendaTimeColumn
    /// Leading offset the row's content needs so the marker can escape the row
    /// padding. `0` unless a marker is drawn at the far left.
    public let leadingInset: CGFloat
    public let timeColumnWidth: CGFloat
    /// `nil` when no marker is drawn.
    public let markerFrame: MarkerFrame?
    /// `nil` when `showMeetingServiceIcon` is off; no slot is reserved then.
    public let serviceIconOrigin: CGFloat?
    public let titleOrigin: CGFloat
    public let titleWidth: CGFloat

    public static func resolve(
        metrics: DropdownMetrics = .standard,
        marker: AgendaMarker,
        position: AgendaMarkerPosition,
        timeColumn: AgendaTimeColumn,
        showsServiceIcon: Bool = false
    ) -> AgendaRowLayout {
        let resolvedPosition: AgendaMarkerPosition = marker == .leftBorderBar ? .farLeft : position
        let timeWidth = metrics.timeColumnWidth(for: timeColumn)
        // The gutter only exists when there is something to its left.
        let afterTime = timeWidth > 0 ? timeWidth + metrics.columnSpacing : 0

        var markerFrame: MarkerFrame?
        var leadingInset: CGFloat = 0
        var titleOrigin = afterTime

        switch marker {
        case .none:
            break
        case .dot, .leftBorderBar:
            let size = markerSize(marker, metrics: metrics)
            switch resolvedPosition {
            case .farLeft:
                leadingInset = -metrics.rowLeadingInset
                markerFrame = MarkerFrame(
                    x: leadingInset,
                    width: size.width,
                    height: size.height
                )
            case .betweenTimeAndTitle:
                markerFrame = MarkerFrame(
                    x: afterTime,
                    width: size.width,
                    height: size.height
                )
                titleOrigin = afterTime + size.width + metrics.columnSpacing
            }
        }

        var serviceIconOrigin: CGFloat?
        if showsServiceIcon {
            serviceIconOrigin = titleOrigin
            titleOrigin += metrics.serviceIconWidth + metrics.columnSpacing
        }

        // Reserves the resting glyph, not the wider hover pill; see `trailingGlyphWidth`.
        let trailing = metrics.trailingGlyphWidth
            + metrics.columnSpacing
            + metrics.disclosureWidth
            + metrics.columnSpacing
        let titleWidth = metrics.rowContentWidth - titleOrigin - trailing

        return AgendaRowLayout(
            marker: marker,
            resolvedPosition: resolvedPosition,
            timeColumn: timeColumn,
            leadingInset: leadingInset,
            timeColumnWidth: timeWidth,
            markerFrame: markerFrame,
            serviceIconOrigin: serviceIconOrigin,
            titleOrigin: titleOrigin,
            titleWidth: titleWidth
        )
    }

    private static func markerSize(
        _ marker: AgendaMarker,
        metrics: DropdownMetrics
    ) -> CGSize {
        switch marker {
        case .none:
            CGSize(width: 0, height: 0)
        case .dot:
            CGSize(width: metrics.markerDotDiameter, height: metrics.markerDotDiameter)
        case .leftBorderBar:
            CGSize(width: metrics.markerBarWidth, height: metrics.markerBarHeight)
        }
    }
}
