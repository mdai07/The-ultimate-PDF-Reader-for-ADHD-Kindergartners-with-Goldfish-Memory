import Foundation

public struct EmbeddedMetadataEnvelope: Codable, Equatable {
    public static let format = "local.aireader.sidecar-json"
    public static let version = 1

    public enum EnvelopeError: Error, Equatable {
        case unsupportedFormat
        case unsupportedVersion
        case invalidPayload
        case checksumMismatch
    }

    public var format: String
    public var version: Int
    public var byteCount: Int
    public var checksum: String
    public var encodedSessionJSON: String

    public init(session: DocumentSession) throws {
        let sessionData = try Self.sessionEncoder.encode(session)
        self.format = Self.format
        self.version = Self.version
        self.byteCount = sessionData.count
        self.checksum = Self.checksum(for: sessionData)
        self.encodedSessionJSON = sessionData.base64EncodedString()
    }

    public init(jsonString: String) throws {
        guard let data = jsonString.data(using: .utf8) else {
            throw EnvelopeError.invalidPayload
        }
        self = try Self.envelopeDecoder.decode(Self.self, from: data)
    }

    public func encodedJSONString() throws -> String {
        let data = try Self.envelopeEncoder.encode(self)
        guard let json = String(data: data, encoding: .utf8) else {
            throw EnvelopeError.invalidPayload
        }
        return json
    }

    public func decodedSession() throws -> DocumentSession {
        guard format == Self.format else {
            throw EnvelopeError.unsupportedFormat
        }
        guard version == Self.version else {
            throw EnvelopeError.unsupportedVersion
        }
        guard let data = Data(base64Encoded: encodedSessionJSON), data.count == byteCount else {
            throw EnvelopeError.invalidPayload
        }
        guard Self.checksum(for: data) == checksum else {
            throw EnvelopeError.checksumMismatch
        }
        return try Self.sessionDecoder.decode(DocumentSession.self, from: data)
    }

    private static var sessionEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var sessionDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static var envelopeEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static var envelopeDecoder: JSONDecoder {
        JSONDecoder()
    }

    private static func checksum(for data: Data) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in data {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
    }
}
