import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum DeepSeekModel: String, Codable, Equatable {
    case paperQA = "deepseek-v4-pro"
    case quickSuggestion = "deepseek-v4-flash"
}

public final class DeepSeekProvider: AIProvider {
    public enum ProviderError: Error, Equatable {
        case missingChoice
        case invalidHTTPStatus(Int)
    }

    public struct ChatRequestBody: Codable, Equatable {
        public var model: String
        public var messages: [RequestMessage]
        public var stream: Bool

        public init(model: String, messages: [RequestMessage], stream: Bool) {
            self.model = model
            self.messages = messages
            self.stream = stream
        }
    }

    public struct RequestMessage: Codable, Equatable {
        public var role: String
        public var content: String

        public init(role: String, content: String) {
            self.role = role
            self.content = content
        }
    }

    private struct ChatResponseBody: Codable {
        var choices: [Choice]

        struct Choice: Codable {
            var message: ResponseMessage
        }

        struct ResponseMessage: Codable {
            var role: String
            var content: String
        }
    }

    public let profile: AgentProfile
    private let apiKey: String
    private let model: String
    private let session: URLSession

    public init(
        apiKey: String,
        model: String = DeepSeekModel.paperQA.rawValue,
        displayName: String? = nil,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
        profile = AgentProfile(
            id: "deepseek-\(Self.profileIDComponent(for: model))",
            displayName: displayName ?? Self.defaultDisplayName(for: model),
            kind: .hostedAPI,
            model: model,
            supportsStreaming: true
        )
    }

    public convenience init(
        apiKey: String,
        model: DeepSeekModel,
        session: URLSession = .shared
    ) {
        self.init(apiKey: apiKey, model: model.rawValue, session: session)
    }

    public func complete(messages: [AIMessage]) async throws -> AIMessage {
        let request = try Self.makeRequest(apiKey: apiKey, model: model, messages: messages, stream: false)
        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw ProviderError.invalidHTTPStatus(httpResponse.statusCode)
        }

        return try Self.parseChatResponse(data)
    }

    public func stream(messages: [AIMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let message = try await complete(messages: messages)
                    continuation.yield(message.content)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public static func makeRequest(
        apiKey: String,
        model: String,
        messages: [AIMessage],
        stream: Bool
    ) throws -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.deepseek.com/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ChatRequestBody(
            model: model,
            messages: messages.map { RequestMessage(role: $0.role.rawValue, content: $0.contentIncludingAttachmentSummaries) },
            stream: stream
        )
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    public static func makeRequest(
        apiKey: String,
        model: DeepSeekModel,
        messages: [AIMessage],
        stream: Bool
    ) throws -> URLRequest {
        try makeRequest(apiKey: apiKey, model: model.rawValue, messages: messages, stream: stream)
    }

    public static func parseChatResponse(_ data: Data) throws -> AIMessage {
        let response = try JSONDecoder().decode(ChatResponseBody.self, from: data)
        guard let first = response.choices.first else {
            throw ProviderError.missingChoice
        }

        return AIMessage(
            role: ChatRole(rawValue: first.message.role) ?? .assistant,
            content: first.message.content
        )
    }

    private static func defaultDisplayName(for model: String) -> String {
        switch model {
        case DeepSeekModel.paperQA.rawValue:
            return "DeepSeek V4 Pro"
        case DeepSeekModel.quickSuggestion.rawValue:
            return "DeepSeek V4 Flash"
        default:
            return "DeepSeek \(model)"
        }
    }

    private static func profileIDComponent(for model: String) -> String {
        model
            .lowercased()
            .map { character in
                character.isLetter || character.isNumber ? character : "-"
            }
            .reduce(into: "") { result, character in
                if character == "-", result.last == "-" {
                    return
                }
                result.append(character)
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
