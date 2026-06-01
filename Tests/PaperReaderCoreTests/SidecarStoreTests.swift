import XCTest
@testable import PaperReaderCore

final class SidecarStoreTests: XCTestCase {
    func testLegacySessionJSONRoundTripPreservesAnnotationsOutsidePageCommentsAndOCR() throws {
        let session = DocumentSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            pdfURL: URL(fileURLWithPath: "/tmp/paper.pdf"),
            title: "A Useful Paper",
            pages: [PageModel(index: 0, size: PageSize(width: 612, height: 792), embeddedText: "embedded alpha text")],
            annotations: [
                Annotation(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                    pageIndex: 0,
                    kind: .highlight,
                    bounds: NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.04),
                    contents: "important",
                    colorHex: "#F7D154",
                    createdAt: Date(timeIntervalSince1970: 10)
                ),
                Annotation(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000009")!,
                    pageIndex: 0,
                    kind: .ink,
                    bounds: NormalizedRect(x: 0, y: 0, width: 1, height: 1),
                    contents: "Ink",
                    colorHex: "#D13B3B",
                    inkPoints: [
                        NormalizedPoint(x: 0.1, y: 0.2),
                        NormalizedPoint(x: 0.2, y: 0.3),
                        NormalizedPoint(x: 0.3, y: 0.25)
                    ],
                    createdAt: Date(timeIntervalSince1970: 12)
                )
            ],
            signatures: [
                Signature(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                    pageIndex: 0,
                    bounds: NormalizedRect(x: 0.2, y: 0.8, width: 0.2, height: 0.06),
                    imageData: Data([1, 2, 3]),
                    createdAt: Date(timeIntervalSince1970: 20)
                )
            ],
            comments: [
                CommentThread(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
                    pageIndex: 0,
                    anchor: .outsidePage(MarginAnchor(edge: .trailing, offset: 96, y: 0.42)),
                    messages: [
                        CommentMessage(
                            id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
                            author: "reader",
                            body: "Check the assumption.",
                            createdAt: Date(timeIntervalSince1970: 30)
                        )
                    ]
                )
            ],
            regionSelections: [
                RegionSelection(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
                    pageIndex: 0,
                    kind: .figure,
                    bounds: NormalizedRect(x: 0.12, y: 0.18, width: 0.6, height: 0.4),
                    label: "Figure 2",
                    nearbyText: "caption text",
                    imageDigest: "sha256:abc",
                    createdAt: Date(timeIntervalSince1970: 40)
                )
            ],
            ocrBlocks: [
                OCRBlock(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!,
                    pageIndex: 0,
                    bounds: NormalizedRect(x: 0.1, y: 0.1, width: 0.8, height: 0.05),
                    text: "ocr beta text",
                    confidence: 0.91,
                    source: .appleVision
                )
            ],
            chats: [
                ChatThread(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000008")!,
                    agentID: "deepseek",
                    messages: [
                        ChatMessage(
                            role: .user,
                            content: "Summarize this.",
                            citations: [],
                            createdAt: Date(timeIntervalSince1970: 45)
                        )
                    ],
                    createdAt: Date(timeIntervalSince1970: 50)
                )
            ],
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 60)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let loaded = try decoder.decode(DocumentSession.self, from: encoder.encode(session))

        XCTAssertEqual(loaded, session)
        XCTAssertEqual(loaded.comments.first?.anchor, .outsidePage(MarginAnchor(edge: .trailing, offset: 96, y: 0.42)))
        XCTAssertEqual(loaded.ocrBlocks.first?.source, .appleVision)
    }
}
