import XCTest
@testable import PaperReaderCore

final class AnnotationIdentityTests: XCTestCase {
    func testAnnotationIdentityKeyIsStableAcrossSmallCoordinateDrift() {
        let first = AnnotationIdentity.key(
            pageIndex: 2,
            kind: .highlight,
            bounds: NormalizedRect(x: 0.1234001, y: 0.5678001, width: 0.1111001, height: 0.2222001),
            contents: "  Main   Result\n"
        )
        let second = AnnotationIdentity.key(
            pageIndex: 2,
            kind: .highlight,
            bounds: NormalizedRect(x: 0.1234004, y: 0.5678004, width: 0.1111004, height: 0.2222004),
            contents: "main result"
        )

        XCTAssertEqual(first, second)
    }

    func testHiddenExternalAnnotationRoundTripsAndSkipsImport() throws {
        let key = AnnotationIdentity.key(
            pageIndex: 0,
            kind: .highlight,
            bounds: NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.04),
            contents: "Imported highlight"
        )
        let session = DocumentSession(
            pdfURL: URL(fileURLWithPath: "/tmp/paper.pdf"),
            title: "paper",
            hiddenExternalAnnotationKeys: [key]
        )

        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(DocumentSession.self, from: data)

        XCTAssertEqual(decoded.hiddenExternalAnnotationKeys, [key])
        XCTAssertFalse(decoded.shouldImportExternalAnnotation(key: key))
    }

    func testExternalAnnotationKeyRoundTripsOnAnnotation() throws {
        let key = "external-highlight-key"
        let annotation = Annotation(
            pageIndex: 1,
            kind: .highlight,
            bounds: NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.04),
            contents: "Imported",
            externalPDFAnnotationKey: key
        )

        let data = try JSONEncoder().encode(annotation)
        let decoded = try JSONDecoder().decode(Annotation.self, from: data)

        XCTAssertEqual(decoded.externalPDFAnnotationKey, key)
    }
}
