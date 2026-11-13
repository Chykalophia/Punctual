//
//  DropdownDensityTests.swift
//  PunctualLogicTests
//
//  Tests for the three dropdown density presets and how they relate.
//

import XCTest

@testable import PunctualLogic

final class DropdownDensityTests: XCTestCase {
    private let all = DropdownDensity.allCases

    // MARK: - The shipping look must not move

    /// Values are spelled out so a change to the shipping panel is a deliberate decision.
    /// The time column is 58, not the mockup's 54, so "12:00 PM" fits at this font.
    func test_standardMatchesTheShippingPanel() {
        let grid = DropdownDensity.standard.metrics
        XCTAssertEqual(grid.panelWidth, 360)
        XCTAssertEqual(grid.rowOuterPadding, 8)
        XCTAssertEqual(grid.rowInnerPadding, 10)
        XCTAssertEqual(grid.rowVerticalPadding, 6)
        XCTAssertEqual(grid.columnSpacing, 9)
        XCTAssertEqual(grid.timeColumnWidth, 58)
        XCTAssertEqual(grid.rowFontSize, 12.5)
    }

    // MARK: - Invariants across all three

    func test_panelWidthIsIdenticalAcrossDensities() {
        XCTAssertEqual(Set(all.map { $0.metrics.panelWidth }).count, 1)
    }

    func test_rowOuterPaddingIsIdenticalAcrossDensities() {
        XCTAssertEqual(Set(all.map { $0.metrics.rowOuterPadding }).count, 1)
    }

    func test_everyDensityProducesAUsableContentWidth() {
        for density in all {
            let grid = density.metrics
            let content = grid.panelWidth - 2 * (grid.rowOuterPadding + grid.rowInnerPadding)
            XCTAssertGreaterThan(content, 240, "\(density) leaves too little room for a title")
        }
    }

    // MARK: - Ordering

    func test_densitiesAreOrderedByRowHeight() {
        XCTAssertLessThan(
            DropdownDensity.compact.metrics.rowVerticalPadding,
            DropdownDensity.standard.metrics.rowVerticalPadding
        )
        XCTAssertLessThan(
            DropdownDensity.standard.metrics.rowVerticalPadding,
            DropdownDensity.roomy.metrics.rowVerticalPadding
        )
    }

    func test_densitiesAreOrderedByTypeSize() {
        XCTAssertLessThan(
            DropdownDensity.compact.metrics.rowFontSize,
            DropdownDensity.standard.metrics.rowFontSize
        )
        XCTAssertLessThan(
            DropdownDensity.standard.metrics.rowFontSize,
            DropdownDensity.roomy.metrics.rowFontSize
        )
    }

    func test_cardPaddingTracksDensity() {
        let byRow = all.sorted { $0.metrics.rowVerticalPadding < $1.metrics.rowVerticalPadding }
        XCTAssertEqual(
            byRow.map(\.metrics.cardVerticalPadding),
            byRow.map(\.metrics.cardVerticalPadding).sorted(),
            "card padding must grow with row padding"
        )
        XCTAssertEqual(
            byRow.map(\.metrics.cardHorizontalPadding),
            byRow.map(\.metrics.cardHorizontalPadding).sorted()
        )
    }

    func test_cardCornerRadiusTracksCardPadding() {
        let byPadding = all.sorted {
            $0.metrics.cardHorizontalPadding < $1.metrics.cardHorizontalPadding
        }
        let radii = byPadding.map(\.metrics.cardCornerRadius)
        XCTAssertEqual(radii, radii.sorted())
    }

    func test_cardHighlightClearsContentAndStaysInsideCard() {
        for density in all {
            let metrics = density.metrics
            XCTAssertGreaterThanOrEqual(metrics.cardHighlightOutset, 4, "\(density)")
            XCTAssertLessThan(
                metrics.cardHighlightOutset,
                metrics.cardHorizontalPadding,
                "\(density)"
            )
            XCTAssertEqual(
                metrics.cardHighlightCornerRadius,
                metrics.cardCornerRadius
                    - (metrics.cardHorizontalPadding - metrics.cardHighlightOutset),
                "highlight corners must be concentric with the card: \(density)"
            )
        }
    }

    func test_cardsLeaveUsableContentWidthAtEveryDensity() {
        for density in all {
            let metrics = density.metrics
            let inner = metrics.rowContentWidth - metrics.cardHorizontalPadding * 2
            XCTAssertGreaterThan(inner, 200, "\(density)")
        }
    }

    func test_timeColumnTracksTypeSize() {
        let byFont = all.sorted { $0.metrics.rowFontSize < $1.metrics.rowFontSize }
        let widths = byFont.map { $0.metrics.timeColumnWidth }
        XCTAssertEqual(widths, widths.sorted(), "time column must grow with the font")
    }

    func test_secondaryTypeIsAlwaysSmallerThanPrimary() {
        for density in all {
            XCTAssertLessThan(
                density.metrics.secondaryFontSize,
                density.metrics.rowFontSize,
                "\(density) would render supporting text at or above title size"
            )
        }
    }

    // MARK: - The row solver still works at every density

    func test_everyDensitySolvesToANonOverlappingRow() {
        for density in all {
            let grid = density.metrics
            for marker in AgendaMarker.allCases {
                for position in AgendaMarkerPosition.allCases {
                    for timeColumn in AgendaTimeColumn.allCases {
                        for icon in [true, false] {
                            let layout = AgendaRowLayout.resolve(
                                metrics: grid,
                                marker: marker,
                                position: position,
                                timeColumn: timeColumn,
                                showsServiceIcon: icon
                            )
                            XCTAssertGreaterThan(
                                layout.titleWidth, 0,
                                "\(density)/\(marker)/\(position)/\(timeColumn)/icon:\(icon) left no title room"
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Persistence shape

    /// Stored as raw strings in Defaults, so renaming a case resets that user's choice.
    func test_rawValuesAreStable() {
        XCTAssertEqual(DropdownDensity.compact.rawValue, "compact")
        XCTAssertEqual(DropdownDensity.standard.rawValue, "standard")
        XCTAssertEqual(DropdownDensity.roomy.rawValue, "roomy")
        XCTAssertEqual(DropdownDensity(rawValue: "standard"), .standard)
        XCTAssertNil(DropdownDensity(rawValue: "medium"))
    }
}
