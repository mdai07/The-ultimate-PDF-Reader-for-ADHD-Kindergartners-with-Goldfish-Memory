import XCTest
@testable import PaperReaderCore

final class DeepSeekConfigurationResolverTests: XCTestCase {
    func testStoredDeepSeekOverridesWinWhenProvided() {
        let configuration = DeepSeekConfigurationResolver.resolve(
            environment: [
                "DEEPSEEK_API_KEY": " env-key ",
                "DEEPSEEK_MODEL": " env-pro ",
                "DEEPSEEK_MODEL_FAST": " env-flash "
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

    func testBlankStoredDeepSeekOverridesFallBackToEnvironmentAndDefaults() {
        let configuration = DeepSeekConfigurationResolver.resolve(
            environment: [
                "DEEPSEEK_API_KEY": " env-key ",
                "DEEPSEEK_MODEL": " ",
                "DEEPSEEK_MODEL_FAST": " env-flash "
            ],
            storedAPIKey: "",
            storedChatModel: " ",
            storedFastModel: nil
        )

        XCTAssertEqual(configuration.apiKey, "env-key")
        XCTAssertEqual(configuration.chatModel, "deepseek-v4-pro")
        XCTAssertEqual(configuration.fastModel, "env-flash")
        XCTAssertTrue(configuration.isEnvironmentBacked)
    }
}
