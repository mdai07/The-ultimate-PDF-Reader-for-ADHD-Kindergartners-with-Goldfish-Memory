import XCTest
@testable import PaperReaderCore

final class DeepSeekAPIKeyResolverTests: XCTestCase {
    func testEnvironmentVariableWinsOverStoredKey() {
        let key = DeepSeekAPIKeyResolver.resolve(
            environment: ["DEEPSEEK_API_KEY": " env-key "],
            storedKey: "stored-key"
        )

        XCTAssertEqual(key, "env-key")
    }

    func testStoredKeyUsedWhenEnvironmentVariableIsEmpty() {
        let key = DeepSeekAPIKeyResolver.resolve(
            environment: ["DEEPSEEK_API_KEY": "   "],
            storedKey: " stored-key "
        )

        XCTAssertEqual(key, "stored-key")
    }
}
