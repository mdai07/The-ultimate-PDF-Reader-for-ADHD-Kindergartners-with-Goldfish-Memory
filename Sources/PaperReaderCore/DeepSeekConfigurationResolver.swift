import Foundation

public struct DeepSeekConfiguration: Codable, Equatable {
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

public enum DeepSeekConfigurationResolver {
    public static let defaultChatModel = DeepSeekModel.paperQA.rawValue
    public static let defaultFastModel = DeepSeekModel.quickSuggestion.rawValue

    public static func resolve(
        environment: [String: String],
        storedAPIKey: String? = nil,
        storedChatModel: String? = nil,
        storedFastModel: String? = nil
    ) -> DeepSeekConfiguration {
        let environmentAPIKey = trimmed(environment["DEEPSEEK_API_KEY"])
        let storedAPIKey = trimmed(storedAPIKey)
        let apiKey = storedAPIKey.isEmpty ? environmentAPIKey : storedAPIKey
        let chatModel = firstNonEmpty(
            storedChatModel,
            environment["DEEPSEEK_MODEL"],
            defaultChatModel
        )
        let fastModel = firstNonEmpty(
            storedFastModel,
            environment["DEEPSEEK_MODEL_FAST"],
            defaultFastModel
        )

        return DeepSeekConfiguration(
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
