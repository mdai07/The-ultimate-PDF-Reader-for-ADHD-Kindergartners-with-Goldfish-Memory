import Foundation

public enum DocumentContextComposer {
    public struct AdditionalContext: Equatable {
        public var title: String
        public var context: DocumentContext

        public init(title: String, context: DocumentContext) {
            self.title = title
            self.context = context
        }
    }

    public static func chatContext(
        primaryTitle: String,
        primary: DocumentContext,
        additional: [AdditionalContext]
    ) -> DocumentContext {
        var sections = [
            "Current paper context: \(primaryTitle)",
            primary.prompt
        ]
        var citations = primary.citations

        for item in additional {
            sections.append("Additional paper context: \(item.title)\n\(item.context.prompt)")
            citations.append(contentsOf: item.context.citations.map { citation in
                SourceCitation(pageIndex: citation.pageIndex, label: "\(item.title): \(citation.label)")
            })
        }

        return DocumentContext(
            prompt: sections.joined(separator: "\n\n"),
            citations: citations,
            imageAttachments: primary.imageAttachments
        )
    }
}
