import XCTest
@testable import PaperReaderCore

final class TemporarySuggestionTimingTests: XCTestCase {
    func testTemporarySuggestionFadesAndClickExtensionsGrow() {
        let timing = TemporarySuggestionTiming(
            visibleSeconds: 10,
            fadeSeconds: 5,
            extensionStepSeconds: 4
        )
        let start = Date(timeIntervalSince1970: 100)
        var state = timing.initialState(now: start)

        XCTAssertEqual(state.extensionCount, 0)
        XCTAssertEqual(state.fadeStartAt.timeIntervalSince1970, 110, accuracy: 0.001)
        XCTAssertEqual(state.expiresAt.timeIntervalSince1970, 115, accuracy: 0.001)
        XCTAssertEqual(timing.opacity(at: start.addingTimeInterval(9), state: state), 1, accuracy: 0.001)
        XCTAssertEqual(timing.opacity(at: start.addingTimeInterval(12.5), state: state), 0.5, accuracy: 0.001)
        XCTAssertEqual(timing.opacity(at: start.addingTimeInterval(15), state: state), 0, accuracy: 0.001)

        state = timing.extendedState(from: state, now: start.addingTimeInterval(12))
        XCTAssertEqual(state.extensionCount, 1)
        XCTAssertEqual(state.fadeStartAt.timeIntervalSince1970, 126, accuracy: 0.001)
        XCTAssertEqual(state.expiresAt.timeIntervalSince1970, 131, accuracy: 0.001)

        state = timing.extendedState(from: state, now: start.addingTimeInterval(20))
        XCTAssertEqual(state.extensionCount, 2)
        XCTAssertEqual(state.fadeStartAt.timeIntervalSince1970, 138, accuracy: 0.001)
        XCTAssertEqual(state.expiresAt.timeIntervalSince1970, 143, accuracy: 0.001)
    }
}
