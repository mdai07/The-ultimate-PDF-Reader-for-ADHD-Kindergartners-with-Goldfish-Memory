import XCTest
@testable import PaperReaderCore

final class MarginAttachmentLayoutTests: XCTestCase {
    func testVisibleAnchorIsExpandedAtSourceY() {
        let layout = MarginAttachmentLayout()
        let placement = layout.placement(sourceYFraction: 0.42)

        XCTAssertEqual(placement.yFraction, 0.42, accuracy: 0.001)
        XCTAssertEqual(placement.sourceYFraction!, 0.42, accuracy: 0.001)
        XCTAssertEqual(placement.visibility, .expanded)
        XCTAssertEqual(placement.lineLimit, nil)
        XCTAssertEqual(placement.scale, 1, accuracy: 0.001)
        XCTAssertEqual(placement.opacity, 1, accuracy: 0.001)
    }

    func testNearOffscreenAnchorReducesTextAndPinsConnector() {
        let layout = MarginAttachmentLayout(edgePadding: 0.04, hiddenDistance: 1.2)
        let placement = layout.placement(sourceYFraction: -0.12)

        XCTAssertEqual(placement.visibility, .reduced)
        XCTAssertEqual(placement.yFraction, 0.04, accuracy: 0.001)
        XCTAssertEqual(placement.sourceYFraction!, 0.0, accuracy: 0.001)
        XCTAssertEqual(placement.lineLimit, 3)
        XCTAssertLessThan(placement.scale, 1)
        XCTAssertGreaterThan(placement.opacity, 0.4)
    }

    func testDistantOffscreenAnchorMinimizes() {
        let layout = MarginAttachmentLayout(edgePadding: 0.04, hiddenDistance: 1.2)
        let placement = layout.placement(sourceYFraction: 1.55)

        XCTAssertEqual(placement.visibility, .minimized)
        XCTAssertEqual(placement.yFraction, 0.96, accuracy: 0.001)
        XCTAssertEqual(placement.sourceYFraction!, 1.0, accuracy: 0.001)
        XCTAssertEqual(placement.lineLimit, 1)
        XCTAssertLessThan(placement.scale, 0.75)
    }

    func testUnanchoredPageCommentStaysExpandedWithoutConnector() {
        let layout = MarginAttachmentLayout()
        let placement = layout.placement(sourceYFraction: nil)

        XCTAssertEqual(placement.visibility, .expanded)
        XCTAssertEqual(placement.yFraction, 0.5, accuracy: 0.001)
        XCTAssertNil(placement.sourceYFraction)
        XCTAssertNil(placement.lineLimit)
    }

    func testPlacementListKeepsTwoMinimizedAboveAndTwoBelow() {
        let layout = MarginAttachmentLayout(edgePadding: 0.04, hiddenDistance: 1.2)
        let inputs = [
            MarginAttachmentInput(id: "above-1", sourceYFraction: -1.1),
            MarginAttachmentInput(id: "above-2", sourceYFraction: -1.2),
            MarginAttachmentInput(id: "above-3", sourceYFraction: -1.3),
            MarginAttachmentInput(id: "below-1", sourceYFraction: 2.1),
            MarginAttachmentInput(id: "below-2", sourceYFraction: 2.2),
            MarginAttachmentInput(id: "below-3", sourceYFraction: 2.3)
        ]

        let placements = layout.placements(for: inputs)

        XCTAssertEqual(placements["above-1"]?.visibility, .minimized)
        XCTAssertEqual(placements["above-2"]?.visibility, .minimized)
        XCTAssertEqual(placements["above-3"]?.visibility, .hidden)
        XCTAssertEqual(placements["below-1"]?.visibility, .minimized)
        XCTAssertEqual(placements["below-2"]?.visibility, .minimized)
        XCTAssertEqual(placements["below-3"]?.visibility, .hidden)
        XCTAssertEqual(placements["above-1"]!.yFraction, 0.04, accuracy: 0.001)
        XCTAssertEqual(placements["above-2"]!.yFraction, 0.12, accuracy: 0.001)
        XCTAssertEqual(placements["below-1"]!.yFraction, 0.96, accuracy: 0.001)
        XCTAssertEqual(placements["below-2"]!.yFraction, 0.88, accuracy: 0.001)
    }

    func testVisiblePlacementsAreSeparatedWhenAnchorsAreDense() {
        let layout = MarginAttachmentLayout(edgePadding: 0.04)
        let inputs = [
            MarginAttachmentInput(id: "a", sourceYFraction: 0.40),
            MarginAttachmentInput(id: "b", sourceYFraction: 0.42),
            MarginAttachmentInput(id: "c", sourceYFraction: 0.44),
            MarginAttachmentInput(id: "d", sourceYFraction: 0.46)
        ]

        let placements = layout.placements(for: inputs)
        let yValues = ["a", "b", "c", "d"].compactMap { placements[$0]?.yFraction }.sorted()

        XCTAssertEqual(yValues.count, 4)
        for pair in zip(yValues, yValues.dropFirst()) {
            XCTAssertGreaterThanOrEqual(pair.1 - pair.0, 0.099)
        }
        XCTAssertGreaterThanOrEqual(yValues.first!, 0.04)
        XCTAssertLessThanOrEqual(yValues.last!, 0.96)
    }

    func testEqualHeightAnchorsPlaceLeftAnchorAboveRightAnchor() {
        let layout = MarginAttachmentLayout(edgePadding: 0.04)
        let placements = layout.placements(for: [
            MarginAttachmentInput(id: "right", sourceYFraction: 0.42, sourceXFraction: 0.74),
            MarginAttachmentInput(id: "left", sourceYFraction: 0.42, sourceXFraction: 0.22)
        ])

        XCTAssertLessThan(placements["left"]!.yFraction, placements["right"]!.yFraction)
    }

    func testDisplayYOffsetMovesVisibleCommentWithinRailBounds() {
        let layout = MarginAttachmentLayout(edgePadding: 0.04)
        let placements = layout.placements(for: [
            MarginAttachmentInput(id: "moved", sourceYFraction: 0.42, displayYOffset: 0.22),
            MarginAttachmentInput(id: "clamped", sourceYFraction: 0.92, displayYOffset: 0.30)
        ])

        XCTAssertEqual(placements["moved"]!.yFraction, 0.64, accuracy: 0.001)
        XCTAssertEqual(placements["clamped"]!.yFraction, 0.96, accuracy: 0.001)
        XCTAssertEqual(placements["moved"]!.sourceYFraction!, 0.42, accuracy: 0.001)
    }

    func testDisplayYOffsetDoesNotMoveMinimizedOffscreenComment() {
        let layout = MarginAttachmentLayout(edgePadding: 0.04, hiddenDistance: 1.2)
        let placements = layout.placements(for: [
            MarginAttachmentInput(id: "offscreen", sourceYFraction: 1.55, displayYOffset: -0.35)
        ])

        XCTAssertEqual(placements["offscreen"]!.visibility, .minimized)
        XCTAssertEqual(placements["offscreen"]!.yFraction, 0.96, accuracy: 0.001)
    }
}
