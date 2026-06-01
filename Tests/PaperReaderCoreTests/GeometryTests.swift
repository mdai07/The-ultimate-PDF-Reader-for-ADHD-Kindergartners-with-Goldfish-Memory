import XCTest
@testable import PaperReaderCore

final class GeometryTests: XCTestCase {
    func testNormalizedRectangleConvertsToAndFromPageCoordinates() {
        let pageSize = PageSize(width: 612, height: 792)
        let pageRect = PageRect(x: 153, y: 198, width: 306, height: 396)

        let normalized = NormalizedRect(pageRect: pageRect, pageSize: pageSize)
        let roundTrip = normalized.pageRect(in: pageSize)

        XCTAssertEqual(normalized.x, 0.25, accuracy: 0.0001)
        XCTAssertEqual(normalized.y, 0.25, accuracy: 0.0001)
        XCTAssertEqual(normalized.width, 0.5, accuracy: 0.0001)
        XCTAssertEqual(normalized.height, 0.5, accuracy: 0.0001)
        XCTAssertEqual(roundTrip.x, pageRect.x, accuracy: 0.0001)
        XCTAssertEqual(roundTrip.y, pageRect.y, accuracy: 0.0001)
        XCTAssertEqual(roundTrip.width, pageRect.width, accuracy: 0.0001)
        XCTAssertEqual(roundTrip.height, pageRect.height, accuracy: 0.0001)
    }
}
