import XCTest
@testable import PaperReaderCore

final class EmbeddedMetadataEnvelopeTests: XCTestCase {
    func testEmbeddedMetadataEnvelopeRoundTripsSessionAndValidatesChecksum() throws {
        let fixedDate = Date(timeIntervalSince1970: 100)
        let session = DocumentSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000111")!,
            pdfURL: URL(fileURLWithPath: "/tmp/paper.pdf"),
            title: "Paper",
            pages: [PageModel(index: 0, size: PageSize(width: 612, height: 792), embeddedText: "alpha")],
            annotations: [
                Annotation(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000222")!,
                    pageIndex: 0,
                    kind: .highlight,
                    bounds: NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.04),
                    contents: "important",
                    createdAt: fixedDate
                )
            ],
            comments: [
                CommentThread(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000333")!,
                    pageIndex: 0,
                    anchor: .inPage(NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.04)),
                    messages: [
                        CommentMessage(
                            id: UUID(uuidString: "00000000-0000-0000-0000-000000000444")!,
                            author: "reader",
                            body: "Side comment",
                            createdAt: fixedDate
                        )
                    ]
                )
            ],
            createdAt: fixedDate,
            updatedAt: fixedDate
        )

        let encoded = try EmbeddedMetadataEnvelope(session: session).encodedJSONString()
        let decoded = try EmbeddedMetadataEnvelope(jsonString: encoded).decodedSession()
        var corrupted = try EmbeddedMetadataEnvelope(jsonString: encoded)
        corrupted.encodedSessionJSON = Data("corrupted".utf8).base64EncodedString()

        XCTAssertEqual(decoded, session)
        XCTAssertThrowsError(try corrupted.decodedSession())
    }
}
