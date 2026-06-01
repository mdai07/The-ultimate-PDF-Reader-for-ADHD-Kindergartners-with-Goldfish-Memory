import XCTest
@testable import PaperReaderCore

final class GeminiConfigurationResolverTests: XCTestCase {
    func testEnvironmentValuesWinForGeminiConfiguration() {
        let configuration = GeminiConfigurationResolver.resolve(
            environment: [
                "GEMINI_API_KEY": " gemini-key ",
                "GEMINI_MODEL": " gemini-custom-pro ",
                "GEMINI_MODEL_FAST": " gemini-custom-flash "
            ]
        )

        XCTAssertEqual(configuration.apiKey, "gemini-key")
        XCTAssertEqual(configuration.chatModel, "gemini-custom-pro")
        XCTAssertEqual(configuration.fastModel, "gemini-custom-flash")
        XCTAssertTrue(configuration.isEnvironmentBacked)
    }

    func testMissingModelEnvironmentFallsBackToCurrentGeminiDefaults() {
        let configuration = GeminiConfigurationResolver.resolve(
            environment: [
                "GEMINI_API_KEY": "gemini-key",
                "GEMINI_MODEL": " ",
                "GEMINI_MODEL_FAST": ""
            ]
        )

        XCTAssertEqual(configuration.chatModel, "gemini-2.5-pro")
        XCTAssertEqual(configuration.fastModel, "gemini-2.5-flash-lite")
    }

    func testStoredGeminiOverridesWinWhenProvided() {
        let configuration = GeminiConfigurationResolver.resolve(
            environment: [
                "GEMINI_API_KEY": " env-key ",
                "GEMINI_MODEL": " env-pro ",
                "GEMINI_MODEL_FAST": " env-flash "
            ],
            storedAPIKey: " stored-key ",
            storedChatModel: " stored-pro ",
            storedFastModel: " stored-flash "
        )

        XCTAssertEqual(configuration.apiKey, "stored-key")
        XCTAssertEqual(configuration.chatModel, "stored-pro")
        XCTAssertEqual(configuration.fastModel, "stored-flash")
        XCTAssertFalse(configuration.isEnvironmentBacked)
    }

    func testBlankStoredGeminiOverridesFallBackToEnvironment() {
        let configuration = GeminiConfigurationResolver.resolve(
            environment: [
                "GEMINI_API_KEY": " env-key ",
                "GEMINI_MODEL": " env-pro ",
                "GEMINI_MODEL_FAST": " env-flash "
            ],
            storedAPIKey: " ",
            storedChatModel: "",
            storedFastModel: nil
        )

        XCTAssertEqual(configuration.apiKey, "env-key")
        XCTAssertEqual(configuration.chatModel, "env-pro")
        XCTAssertEqual(configuration.fastModel, "env-flash")
        XCTAssertTrue(configuration.isEnvironmentBacked)
    }
}
