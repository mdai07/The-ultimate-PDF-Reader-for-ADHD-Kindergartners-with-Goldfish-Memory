import XCTest
@testable import PaperReaderCore

final class ProviderCredentialDescriptorTests: XCTestCase {
    func testDeepSeekCredentialDescriptorHasStableKeychainAndLegacyDefaultsNames() {
        let descriptor = ProviderCredentialDescriptor.deepSeekAPIKey

        XCTAssertEqual(descriptor.keychainService, "AIReader.APIKeys")
        XCTAssertEqual(descriptor.keychainAccount, "deepseek")
        XCTAssertEqual(descriptor.legacyDefaultsKey, "DeepSeekAPIKey")
        XCTAssertEqual(descriptor.environmentVariableName, "DEEPSEEK_API_KEY")
    }

    func testGeminiCredentialDescriptorHasStableKeychainAndLegacyDefaultsNames() {
        let descriptor = ProviderCredentialDescriptor.geminiAPIKey

        XCTAssertEqual(descriptor.keychainService, "AIReader.APIKeys")
        XCTAssertEqual(descriptor.keychainAccount, "gemini")
        XCTAssertEqual(descriptor.legacyDefaultsKey, "GeminiAPIKey")
        XCTAssertEqual(descriptor.environmentVariableName, "GEMINI_API_KEY")
    }
}
