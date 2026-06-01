import Foundation

public enum AgentKind: String, Codable, Equatable {
    case hostedAPI
    case localCLI
}

public struct AgentProfile: Codable, Equatable, Identifiable {
    public var id: String
    public var displayName: String
    public var kind: AgentKind
    public var model: String
    public var isExperimental: Bool
    public var supportsStreaming: Bool

    public init(
        id: String,
        displayName: String,
        kind: AgentKind,
        model: String,
        isExperimental: Bool = false,
        supportsStreaming: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.model = model
        self.isExperimental = isExperimental
        self.supportsStreaming = supportsStreaming
    }
}

public struct AIImageAttachment: Codable, Equatable {
    public var label: String
    public var mimeType: String
    public var base64Data: String

    public init(label: String, mimeType: String, base64Data: String) {
        self.label = label
        self.mimeType = mimeType
        self.base64Data = base64Data
    }
}

public struct AIMessage: Codable, Equatable {
    public var role: ChatRole
    public var content: String
    public var imageAttachments: [AIImageAttachment]

    public init(role: ChatRole, content: String, imageAttachments: [AIImageAttachment] = []) {
        self.role = role
        self.content = content
        self.imageAttachments = imageAttachments
    }

    private enum CodingKeys: String, CodingKey {
        case role
        case content
        case imageAttachments
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = try container.decode(ChatRole.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        imageAttachments = try container.decodeIfPresent([AIImageAttachment].self, forKey: .imageAttachments) ?? []
    }

    public var contentIncludingAttachmentSummaries: String {
        guard !imageAttachments.isEmpty else {
            return content
        }
        let summaries = imageAttachments.map { attachment in
            "[Image attachment unavailable to this provider: \(attachment.label), \(attachment.mimeType)]"
        }
        return ([content] + summaries).joined(separator: "\n\n")
    }
}

public protocol AIProvider {
    var profile: AgentProfile { get }

    func complete(messages: [AIMessage]) async throws -> AIMessage
    func stream(messages: [AIMessage]) -> AsyncThrowingStream<String, Error>
}
