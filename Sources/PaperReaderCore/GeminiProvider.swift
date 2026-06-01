import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class GeminiProvider: AIProvider {
    public enum ProviderError: Error, Equatable {
        case invalidModel
        case missingCandidate
        case invalidHTTPStatus(Int)
    }

    public struct GenerateContentRequestBody: Codable, Equatable {
        public var contents: [Content]
        public var systemInstruction: Content?

        public init(contents: [Content], systemInstruction: Content? = nil) {
            self.contents = contents
            self.systemInstruction = systemInstruction
        }
    }

    public struct Content: Codable, Equatable {
        public var role: String?
        public var parts: [Part]

        public init(role: String? = nil, parts: [Part]) {
            self.role = role
            self.parts = parts
        }
    }

    public struct Part: Codable, Equatable {
        public var text: String?
        public var inlineData: InlineData?

        public init(text: String) {
            self.text = text
            self.inlineData = nil
        }

        public init(inlineData: InlineData) {
            self.text = nil
            self.inlineData = inlineData
        }
    }

    public struct InlineData: Codable, Equatable {
        public var mimeType: String
        public var data: String

        public init(mimeType: String, data: String) {
            self.mimeType = mimeType
            self.data = data
        }
    }

    private struct GenerateContentResponseBody: Codable {
        var candidates: [Candidate]

        struct Candidate: Codable {
            var content: Content
        }
    }

    public let profile: AgentProfile
    private let apiKey: String
    private let model: String
    private let session: URLSession

    public init(
        apiKey: String,
        model: String,
        displayName: String? = nil,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
        profile = AgentProfile(
            id: "gemini-\(Self.profileIDComponent(for: model))",
            displayName: displayName ?? "Gemini \(model)",
            kind: .hostedAPI,
            model: model,
            supportsStreaming: true
        )
    }

    public func complete(messages: [AIMessage]) async throws -> AIMessage {
        let request = try Self.makeRequest(apiKey: apiKey, model: model, messages: messages)
        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw ProviderError.invalidHTTPStatus(httpResponse.statusCode)
        }

        return try Self.parseGenerateContentResponse(data)
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
        messages: [AIMessage]
    ) throws -> URLRequest {
        let modelPath = normalizedModelPath(model)
        guard !modelPath.isEmpty else {
            throw ProviderError.invalidModel
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "generativelanguage.googleapis.com"
        components.path = "/v1beta/\(modelPath):generateContent"
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        guard let url = components.url else {
            throw ProviderError.invalidModel
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(makeBody(messages: messages))
        return request
    }

    public static func parseGenerateContentResponse(_ data: Data) throws -> AIMessage {
        let response = try JSONDecoder().decode(GenerateContentResponseBody.self, from: data)
        guard let first = response.candidates.first else {
            throw ProviderError.missingCandidate
        }

        let content = first.content.parts
            .compactMap(\.text)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            throw ProviderError.missingCandidate
        }

        return AIMessage(role: .assistant, content: content)
    }

    public static func profileIDComponent(for model: String) -> String {
        model
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "models/", with: "")
            .map { character in
                character.isLetter || character.isNumber || character == "-" ? character : "-"
            }
            .reduce(into: "") { $0.append($1) }
    }

    private static func makeBody(messages: [AIMessage]) -> GenerateContentRequestBody {
        let systemText = messages
            .filter { $0.role == .system }
            .map(\.content)
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let contents = messages.compactMap { message -> Content? in
            switch message.role {
            case .system:
                return nil
            case .assistant:
                return Content(role: "model", parts: [Part(text: message.content)])
            case .user, .tool:
                var parts = [Part(text: message.content)]
                parts.append(contentsOf: message.imageAttachments.map { attachment in
                    Part(inlineData: InlineData(mimeType: attachment.mimeType, data: attachment.base64Data))
                })
                return Content(role: "user", parts: parts)
            }
        }

        let systemInstruction = systemText.isEmpty ? nil : Content(parts: [Part(text: systemText)])
        return GenerateContentRequestBody(contents: contents, systemInstruction: systemInstruction)
    }

    private static func normalizedModelPath(_ model: String) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ""
        }
        if trimmed.hasPrefix("models/") {
            return trimmed
        }
        return "models/\(trimmed)"
    }
}
