import Foundation

public extension CommentThread {
    static func linkedHighlightNote(
        pageIndex: Int,
        bounds: NormalizedRect,
        colorHex: String,
        author: String,
        body: String = "New note"
    ) -> CommentThread {
        CommentThread(
            pageIndex: pageIndex,
            anchor: .inPage(bounds),
            messages: [CommentMessage(author: author, body: body)],
            colorHex: colorHex
        )
    }
}

public extension Annotation {
    static func sourceMarker(
        for comment: CommentThread,
        bounds: NormalizedRect,
        kind: AnnotationKind = .highlight,
        contents: String = "Comment source"
    ) -> Annotation {
        Annotation(
            pageIndex: comment.pageIndex,
            kind: kind,
            bounds: bounds,
            contents: contents,
            colorHex: comment.colorHex
        )
    }
}
