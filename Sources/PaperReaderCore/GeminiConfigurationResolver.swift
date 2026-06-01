import Foundation

public struct GeminiConfiguration: Codable, Equatable {
    public var apiKey: String
    public var chatModel: String
    public var fastModel: String
    public var isEnvironmentBacked: Bool

    public init(
        apiKey: String,
        chatModel: String,
        fastModel: String,
        isEnvironmentBacked: Bool
    ) {
        self.apiKey = apiKey
        self.chatModel = chatModel
        self.fastModel = fastModel
        self.isEnvironmentBacked = isEnvironmentBacked
    }
}

public enum GeminiConfigurationResolver {
    public static let defaultChatModel = "gemini-2.5-pro"
    public static let defaultFastModel = "gemini-2.5-flash-lite"

    public static func resolve(
        environment: [String: String],
        storedAPIKey: String? = nil,
        storedChatModel: String? = nil,
        storedFastModel: String? = nil
    ) -> GeminiConfiguration {
        let environmentAPIKey = trimmed(environment["GEMINI_API_KEY"])
        let storedAPIKey = trimmed(storedAPIKey)
        let apiKey = storedAPIKey.isEmpty ? environmentAPIKey : storedAPIKey
        let chatModel = firstNonEmpty(
            storedChatModel,
            environment["GEMINI_MODEL"],
            defaultChatModel
        )
        let fastModel = firstNonEmpty(
            storedFastModel,
            environment["GEMINI_MODEL_FAST"],
            defaultFastModel
        )

        return GeminiConfiguration(
            apiKey: apiKey,
            chatModel: chatModel,
            fastModel: fastModel,
            isEnvironmentBacked: storedAPIKey.isEmpty && !environmentAPIKey.isEmpty
        )
    }

    private static func trimmed(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func firstNonEmpty(_ values: String?...) -> String {
        for value in values {
            let trimmedValue = trimmed(value)
            if !trimmedValue.isEmpty {
                return trimmedValue
            }
        }
        return ""
    }
}
