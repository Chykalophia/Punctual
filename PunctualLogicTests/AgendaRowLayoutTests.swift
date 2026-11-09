//
//  AgendaRowLayoutTests.swift
//  PunctualLogicTests
//
//  Tests for the dropdown panel's agenda row grid.
//

import CoreGraphics
import XCTest

@testable import PunctualLogic

final class AgendaRowLayoutTests: XCTestCase {
    private let metrics = DropdownMetrics.standard

    /// One point in the marker × position × time-column × service-icon matrix.
    private struct Combination: CustomStringConvertible {
        let marker: AgendaMarker
        let position: AgendaMarkerPosition
        let timeColumn: AgendaTimeColumn
        let serviceIcon: Bool

        var description: String {
            "\(marker)/\(position)/\(timeColumn)/icon:\(serviceIcon)"
        }
    }

    private var allCombinations: [Combination] {
        AgendaMarker.allCases.flatMap { marker in
            AgendaMarkerPosition.allCases.flatMap { position in
                AgendaTimeColumn.allCases.flatMap { timeColumn in
                    [false, true].map {
                        Combination(
                            marker: marker,
                            position: position,
                            timeColumn: timeColumn,
                            serviceIcon: $0
                        )
                    }
                }
            }
        }
    }

    private func layout(_ combination: Combination) -> AgendaRowLayout {
        layout(
            combination.marker,
            combination.position,
            combination.timeColumn,
            serviceIcon: combination.serviceIcon
        )
    }

    private func layout(
        _ marker: AgendaMarker,
        _ position: AgendaMarkerPosition,
        _ timeColumn: AgendaTimeColumn,
        serviceIcon: Bool = false
    ) -> AgendaRowLayout {
        AgendaRowLayout.resolve(
            metrics: metrics,
            marker: marker,
            position: position,
            timeColumn: timeColumn,
            showsServiceIcon: serviceIcon
        )
    }

    // MARK: - The grid itself

    func testTheRowContentBoxAndTheSectionHeaderShareOneIndent() {
        XCTAssertEqual(metrics.rowLeadingInset, metrics.rowOuterPadding + metrics.rowInnerPadding)
        XCTAssertEqual(metrics.sectionHeaderInset, metrics.rowLeadingInset)
    }

    func testDetailIndentIsDerivedFromTheGrid() {
        XCTAssertEqual(metrics.detailIndent, metrics.rowLeadingInset + metrics.columnSpacing * 2)
        XCTAssertGreaterThan(metrics.detailIndent, metrics.rowLeadingInset)
    }

    func testContentWidthIsThePanelMinusBothRowInsets() {
        XCTAssertEqual(metrics.rowContentWidth, metrics.panelWidth - metrics.rowLeadingInset * 2)
    }

    // MARK: - Time column

    func testHiddenTimeColumnTakesNoWidth() {
        XCTAssertEqual(metrics.timeColumnWidth(for: .hidden), 0)
    }

    func testStartAndEndKeepsTheSameColumnWidthAsStartOnly() {
        XCTAssertEqual(
            metrics.timeColumnWidth(for: .startAndEnd),
            metrics.timeColumnWidth(for: .startOnly)
        )
        XCTAssertEqual(metrics.timeColumnWidth(for: .startOnly), metrics.timeColumnWidth)
    }

    func testLayoutReportsTheTimeColumnWidthForItsMode() {
        for combination in allCombinations {
            XCTAssertEqual(
                layout(combination).timeColumnWidth,
                metrics.timeColumnWidth(for: combination.timeColumn),
                combination.description
            )
        }
    }

    // MARK: - Service icon slot

    func testServiceIconShiftsTheTitleByExactlyOneSlot() {
        for combination in allCombinations {
            let without = layout(
                combination.marker,
                combination.position,
                combination.timeColumn,
                serviceIcon: false
            )
            let with = layout(
                combination.marker,
                combination.position,
                combination.timeColumn,
                serviceIcon: true
            )
            XCTAssertEqual(
                with.titleOrigin - without.titleOrigin,
                metrics.serviceIconWidth + metrics.columnSpacing,
                accuracy: 0.001,
                combination.description
            )
        }
    }

    // MARK: - Marker resolution

    func testLeftBorderBarAlwaysResolvesToFarLeft() {
        for position in AgendaMarkerPosition.allCases {
            for timeColumn in AgendaTimeColumn.allCases {
                XCTAssertEqual(
                    layout(.leftBorderBar, position, timeColumn).resolvedPosition,
                    .farLeft,
                    "\(position)/\(timeColumn)"
                )
            }
        }
    }

    func testDotHonoursTheRequestedPosition() {
        for position in AgendaMarkerPosition.allCases {
            XCTAssertEqual(layout(.dot, position, .startOnly).resolvedPosition, position)
        }
    }

    func testNoMarkerDrawsNothingAndDoesNotEscapeThePadding() {
        for position in AgendaMarkerPosition.allCases {
            for timeColumn in AgendaTimeColumn.allCases {
                let result = layout(.none, position, timeColumn)
                XCTAssertNil(result.markerFrame, "\(position)/\(timeColumn)")
                XCTAssertEqual(result.leadingInset, 0, "\(position)/\(timeColumn)")
            }
        }
    }

    // MARK: - Far left genuinely escapes the row padding

    /// Far left means a negative offset: anything >= 0 stops at the `PanelRow` padding.
    func testFarLeftMarkerEscapesPanelRowPadding() {
        for marker in [AgendaMarker.dot, .leftBorderBar] {
            for timeColumn in AgendaTimeColumn.allCases {
                let result = layout(marker, .farLeft, timeColumn)
                XCTAssertLessThan(result.leadingInset, 0, "\(marker)/\(timeColumn)")
                XCTAssertEqual(result.leadingInset, -metrics.rowLeadingInset)
                let frame = try? XCTUnwrap(result.markerFrame)
                XCTAssertEqual(frame?.x, -metrics.rowLeadingInset)
                // Reaches the true panel edge, not the content box edge.
                XCTAssertEqual(
                    (frame?.x ?? 0) + metrics.rowLeadingInset,
                    0,
                    accuracy: 0.001
                )
            }
        }
    }

    func testBetweenTimeAndTitleMarkerStaysInsideTheContentBox() {
        for timeColumn in AgendaTimeColumn.allCases {
            let result = layout(.dot, .betweenTimeAndTitle, timeColumn)
            XCTAssertEqual(result.leadingInset, 0, "\(timeColumn)")
            let frame = result.markerFrame
            XCTAssertNotNil(frame, "\(timeColumn)")
            XCTAssertGreaterThanOrEqual(frame?.x ?? -1, result.timeColumnWidth, "\(timeColumn)")
        }
    }

    func testLeftBorderBarIsTallerThanItIsWide() {
        let frame = layout(.leftBorderBar, .farLeft, .startOnly).markerFrame
        XCTAssertNotNil(frame)
        XCTAssertGreaterThan(frame?.height ?? 0, frame?.width ?? 0)
    }

    // MARK: - Every combination is a valid, non-overlapping layout

    func testEveryCombinationProducesANonOverlappingLayout() {
        for combination in allCombinations {
            let result = layout(combination)
            let label = combination.description

            XCTAssertGreaterThanOrEqual(result.titleOrigin, result.timeColumnWidth, label)

            XCTAssertGreaterThan(result.titleWidth, 0, label)
            XCTAssertLessThanOrEqual(
                result.titleOrigin + result.titleWidth,
                metrics.rowContentWidth,
                label
            )

            guard let frame = result.markerFrame else { continue }
            XCTAssertGreaterThan(frame.width, 0, label)
            XCTAssertGreaterThan(frame.height, 0, label)
            XCTAssertLessThanOrEqual(frame.maxX, result.titleOrigin, label)
            switch result.resolvedPosition {
            case .farLeft:
                XCTAssertLessThanOrEqual(frame.maxX, 0, label)
            case .betweenTimeAndTitle:
                XCTAssertGreaterThanOrEqual(frame.x, result.timeColumnWidth, label)
            }
        }
    }

    func testHidingTheTimeColumnMovesTheTitleLeft() {
        for marker in AgendaMarker.allCases {
            for position in AgendaMarkerPosition.allCases {
                let hidden = layout(marker, position, .hidden)
                let shown = layout(marker, position, .startOnly)
                XCTAssertLessThan(hidden.titleOrigin, shown.titleOrigin, "\(marker)/\(position)")
                XCTAssertGreaterThan(hidden.titleWidth, shown.titleWidth, "\(marker)/\(position)")
            }
        }
    }

    /// The expected value is spelled out as arithmetic: time column, gutter, marker, gutter.
    func testTheShippingDefaultRowKeepsItsCurrentGeometry() {
        let result = layout(.dot, .betweenTimeAndTitle, .startOnly)
        XCTAssertEqual(result.timeColumnWidth, 58)
        XCTAssertEqual(result.markerFrame?.x, 58 + 9)
        XCTAssertEqual(result.markerFrame?.width, 7)
        XCTAssertEqual(result.titleOrigin, 58 + 9 + 7 + 9)
    }

    /// The Join pill only exists on hover and is drawn as an overlay, so it reserves no width.
    func testRowReservesTheRestingGlyphNotTheHoverPill() {
        let result = layout(.dot, .betweenTimeAndTitle, .startOnly)
        let reserved = metrics.rowContentWidth - result.titleOrigin - result.titleWidth

        XCTAssertEqual(
            reserved,
            metrics.trailingGlyphWidth + metrics.columnSpacing
                + metrics.disclosureWidth + metrics.columnSpacing
        )
        XCTAssertLessThan(
            metrics.trailingGlyphWidth,
            metrics.trailingAffordanceWidth,
            "the glyph must be cheaper than the pill or the change bought nothing"
        )
    }

    func testEveryDensityGivesTheTitleMoreRoomThanThePillWouldHave() {
        for density in DropdownDensity.allCases {
            let metrics = density.metrics
            let result = AgendaRowLayout.resolve(
                metrics: metrics,
                marker: .dot,
                position: .betweenTimeAndTitle,
                timeColumn: .startOnly
            )
            let withPill = metrics.rowContentWidth
                - result.titleOrigin
                - (metrics.trailingAffordanceWidth + metrics.columnSpacing
                    + metrics.disclosureWidth + metrics.columnSpacing)
            XCTAssertGreaterThan(result.titleWidth, withPill, "\(density)")
        }
    }
}
