import Foundation

public struct ProviderCredentialDescriptor: Codable, Equatable, Hashable {
    public var keychainService: String
    public var keychainAccount: String
    public var legacyDefaultsKey: String
    public var environmentVariableName: String

    public init(
        keychainService: String,
        keychainAccount: String,
        legacyDefaultsKey: String,
        environmentVariableName: String
    ) {
        self.keychainService = keychainService
        self.keychainAccount = keychainAccount
        self.legacyDefaultsKey = legacyDefaultsKey
        self.environmentVariableName = environmentVariableName
    }

    public static let deepSeekAPIKey = ProviderCredentialDescriptor(
        keychainService: "AIReader.APIKeys",
        keychainAccount: "deepseek",
        legacyDefaultsKey: "DeepSeekAPIKey",
        environmentVariableName: "DEEPSEEK_API_KEY"
    )

    public static let geminiAPIKey = ProviderCredentialDescriptor(
        keychainService: "AIReader.APIKeys",
        keychainAccount: "gemini",
        legacyDefaultsKey: "GeminiAPIKey",
        environmentVariableName: "GEMINI_API_KEY"
    )
}
