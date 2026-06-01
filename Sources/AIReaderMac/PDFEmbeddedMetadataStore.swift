import Foundation
import PDFKit
import PaperReaderCore

enum PDFEmbeddedMetadataStore {
    static let attributeKey = "AIReaderMetadata"
    private static let beginMarker = "%AIReaderMetadataBegin"
    private static let endMarker = "%AIReaderMetadataEnd"

    enum MetadataError: Error {
        case missingMetadata
        case invalidMetadataEncoding
    }

    static func embed(session: DocumentSession, in document: PDFDocument) throws {
        var attributes = document.documentAttributes ?? [:]
        attributes[attributeKey] = try EmbeddedMetadataEnvelope(session: session).encodedJSONString()
        document.documentAttributes = attributes
    }

    static func remove(from document: PDFDocument) {
        var attributes = document.documentAttributes ?? [:]
        attributes.removeValue(forKey: attributeKey)
        document.documentAttributes = attributes
    }

    static func append(session: DocumentSession, to pdfURL: URL) throws {
        let envelope = try EmbeddedMetadataEnvelope(session: session).encodedJSONString()
        let trailer = "\n\(beginMarker)\n\(Data(envelope.utf8).base64EncodedString())\n\(endMarker)\n"
        guard let data = trailer.data(using: .utf8) else {
            throw MetadataError.invalidMetadataEncoding
        }
        let handle = try FileHandle(forWritingTo: pdfURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.close()
    }

    static func loadSession(from document: PDFDocument, pdfURL: URL) throws -> DocumentSession {
        if let json = document.documentAttributes?[attributeKey] as? String {
            return try decodedSession(from: json, pdfURL: pdfURL)
        }
        return try loadSession(from: pdfURL)
    }

    static func loadSession(from pdfURL: URL) throws -> DocumentSession {
        let data = try Data(contentsOf: pdfURL)
        let beginData = Data(beginMarker.utf8)
        let endData = Data(endMarker.utf8)
        guard let beginRange = data.range(of: beginData, options: .backwards, in: data.startIndex..<data.endIndex),
              let endRange = data.range(of: endData, options: .backwards, in: data.startIndex..<data.endIndex),
              beginRange.upperBound < endRange.lowerBound else {
            throw MetadataError.missingMetadata
        }
        let encodedData = data[beginRange.upperBound..<endRange.lowerBound]
        guard let encoded = String(data: encodedData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw MetadataError.invalidMetadataEncoding
        }
        guard let envelopeData = Data(base64Encoded: encoded),
              let json = String(data: envelopeData, encoding: .utf8) else {
            throw MetadataError.invalidMetadataEncoding
        }
        return try decodedSession(from: json, pdfURL: pdfURL)
    }

    private static func decodedSession(from json: String, pdfURL: URL) throws -> DocumentSession {
        var session = try EmbeddedMetadataEnvelope(jsonString: json).decodedSession()
        session.pdfURL = pdfURL
        if session.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            session.title = pdfURL.deletingPathExtension().lastPathComponent
        }
        return session
    }
}
