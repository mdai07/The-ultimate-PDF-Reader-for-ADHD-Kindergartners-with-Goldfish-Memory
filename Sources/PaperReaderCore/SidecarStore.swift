import Foundation

public struct SidecarStore {
    public enum StoreError: Error, Equatable {
        case invalidPDFURL
    }

    private let decoder: JSONDecoder

    public init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func sidecarURL(for pdfURL: URL) throws -> URL {
        guard pdfURL.isFileURL else {
            throw StoreError.invalidPDFURL
        }

        let baseName = pdfURL.deletingPathExtension().lastPathComponent
        return pdfURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(baseName).aireader.json")
    }

    public func load(from url: URL) throws -> DocumentSession {
        let data = try Data(contentsOf: url)
        return try decoder.decode(DocumentSession.self, from: data)
    }
}
