import Foundation

public struct DocumentContext: Codable, Equatable {
    public var prompt: String
    public var citations: [SourceCitation]
    public var imageAttachments: [AIImageAttachment]

    public init(
        prompt: String,
        citations: [SourceCitation] = [],
        imageAttachments: [AIImageAttachment] = []
    ) {
        self.prompt = prompt
        self.citations = citations
        self.imageAttachments = imageAttachments
    }
}

public struct DocumentContextBuilder {
    private let session: DocumentSession

    public init(session: DocumentSession) {
        self.session = session
    }

    public func wholePaperContext(maxCharacters: Int = 120_000) -> DocumentContext {
        var lines: [String] = [
            "Title: \(session.title)",
            "PDF: \(session.pdfURL.lastPathComponent)"
        ]
        var citations: [SourceCitation] = []

        for page in session.pages.sorted(by: { $0.index < $1.index }) {
            if let text = page.embeddedText, !text.isEmpty {
                lines.append("Page \(page.index + 1) embedded: \(text)")
                citations.append(SourceCitation(pageIndex: page.index, label: "embedded text"))
            }

            let pageOCR = session.ocrBlocks
                .filter { $0.pageIndex == page.index }
                .map(\.text)
                .joined(separator: "\n")
            if !pageOCR.isEmpty {
                lines.append("Page \(page.index + 1) OCR: \(pageOCR)")
                citations.append(SourceCitation(pageIndex: page.index, label: "ocr text"))
            }
        }

        for comment in session.comments {
            let bodies = comment.messages.map(\.body).joined(separator: "\n")
            if !bodies.isEmpty {
                lines.append("Page \(comment.pageIndex + 1) reader comments: \(bodies)")
                citations.append(SourceCitation(pageIndex: comment.pageIndex, label: "reader comments"))
            }
        }

        return DocumentContext(prompt: String(lines.joined(separator: "\n\n").prefix(maxCharacters)), citations: citations)
    }

    public func selectedTextContext(
        selectedText: String,
        pageIndex: Int,
        visualAttachment: AIImageAttachment? = nil
    ) -> DocumentContext {
        var prompt = """
        Title: \(session.title)

        Selected text on page \(pageIndex + 1):
        \(selectedText)
        """
        var imageAttachments: [AIImageAttachment] = []

        if let visualAttachment {
            prompt += """


            Visual crop attached: use the image crop as the primary source for symbols, superscripts, subscripts, fractions, Greek letters, and equation layout. If transcription is needed, return LaTeX/Markdown math.
            """
            imageAttachments.append(visualAttachment)
        }

        return DocumentContext(
            prompt: prompt,
            citations: [SourceCitation(pageIndex: pageIndex, label: "selected text")],
            imageAttachments: imageAttachments
        )
    }

    public func regionContext(_ region: RegionSelection, visualAttachment: AIImageAttachment? = nil) -> DocumentContext {
        var lines = [
            "Title: \(session.title)",
            "Selected \(region.kind.rawValue) on page \(region.pageIndex + 1)."
        ]

        if let label = region.label {
            lines.append("Label: \(label)")
        }
        if let nearbyText = region.nearbyText {
            lines.append("Nearby text or caption: \(nearbyText)")
        }
        if let imageDigest = region.imageDigest {
            lines.append("Image digest: \(imageDigest)")
        }
        var imageAttachments: [AIImageAttachment] = []
        if let visualAttachment {
            lines.append("Visual crop attached: use the image crop as the primary source for plots, tables, symbols, labels, and equation layout. If transcription is needed, return LaTeX/Markdown math.")
            imageAttachments.append(visualAttachment)
        }

        return DocumentContext(
            prompt: lines.joined(separator: "\n\n"),
            citations: [SourceCitation(pageIndex: region.pageIndex, label: region.label ?? region.kind.rawValue)],
            imageAttachments: imageAttachments
        )
    }
}
