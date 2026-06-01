import Foundation

public struct DocumentSession: Codable, Equatable {
    public var id: UUID
    public var pdfURL: URL
    public var title: String
    public var pages: [PageModel]
    public var annotations: [Annotation]
    public var hiddenExternalAnnotationKeys: [String]
    public var signatures: [Signature]
    public var comments: [CommentThread]
    public var regionSelections: [RegionSelection]
    public var ocrBlocks: [OCRBlock]
    public var chats: [ChatThread]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        pdfURL: URL,
        title: String,
        pages: [PageModel] = [],
        annotations: [Annotation] = [],
        hiddenExternalAnnotationKeys: [String] = [],
        signatures: [Signature] = [],
        comments: [CommentThread] = [],
        regionSelections: [RegionSelection] = [],
        ocrBlocks: [OCRBlock] = [],
        chats: [ChatThread] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.pdfURL = pdfURL
        self.title = title
        self.pages = pages
        self.annotations = annotations
        self.hiddenExternalAnnotationKeys = hiddenExternalAnnotationKeys
        self.signatures = signatures
        self.comments = comments
        self.regionSelections = regionSelections
        self.ocrBlocks = ocrBlocks
        self.chats = chats
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case pdfURL
        case title
        case pages
        case annotations
        case hiddenExternalAnnotationKeys
        case signatures
        case comments
        case regionSelections
        case ocrBlocks
        case chats
        case createdAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        pdfURL = try container.decode(URL.self, forKey: .pdfURL)
        title = try container.decode(String.self, forKey: .title)
        pages = try container.decode([PageModel].self, forKey: .pages)
        annotations = try container.decode([Annotation].self, forKey: .annotations)
        hiddenExternalAnnotationKeys = try container.decodeIfPresent([String].self, forKey: .hiddenExternalAnnotationKeys) ?? []
        signatures = try container.decode([Signature].self, forKey: .signatures)
        comments = try container.decode([CommentThread].self, forKey: .comments)
        regionSelections = try container.decode([RegionSelection].self, forKey: .regionSelections)
        ocrBlocks = try container.decode([OCRBlock].self, forKey: .ocrBlocks)
        chats = try container.decode([ChatThread].self, forKey: .chats)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(pdfURL, forKey: .pdfURL)
        try container.encode(title, forKey: .title)
        try container.encode(pages, forKey: .pages)
        try container.encode(annotations, forKey: .annotations)
        try container.encode(hiddenExternalAnnotationKeys, forKey: .hiddenExternalAnnotationKeys)
        try container.encode(signatures, forKey: .signatures)
        try container.encode(comments, forKey: .comments)
        try container.encode(regionSelections, forKey: .regionSelections)
        try container.encode(ocrBlocks, forKey: .ocrBlocks)
        try container.encode(chats, forKey: .chats)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    public func shouldImportExternalAnnotation(key: String) -> Bool {
        !hiddenExternalAnnotationKeys.contains(key)
            && !annotations.contains { $0.externalPDFAnnotationKey == key }
    }
}

public struct PageModel: Codable, Equatable {
    public var index: Int
    public var size: PageSize
    public var embeddedText: String?

    public init(index: Int, size: PageSize, embeddedText: String? = nil) {
        self.index = index
        self.size = size
        self.embeddedText = embeddedText
    }
}

public enum AnnotationKind: String, Codable, Equatable, CaseIterable {
    case highlight
    case note
    case textBox
    case ink
    case rectangle
}

public struct Annotation: Codable, Equatable {
    public var id: UUID
    public var pageIndex: Int
    public var kind: AnnotationKind
    public var bounds: NormalizedRect
    public var contents: String
    public var colorHex: String
    public var inkPoints: [NormalizedPoint]?
    public var externalPDFAnnotationKey: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        pageIndex: Int,
        kind: AnnotationKind,
        bounds: NormalizedRect,
        contents: String = "",
        colorHex: String = "#F7D154",
        inkPoints: [NormalizedPoint]? = nil,
        externalPDFAnnotationKey: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.kind = kind
        self.bounds = bounds
        self.contents = contents
        self.colorHex = colorHex
        self.inkPoints = inkPoints
        self.externalPDFAnnotationKey = externalPDFAnnotationKey
        self.createdAt = createdAt
    }
}

public struct Signature: Codable, Equatable {
    public var id: UUID
    public var pageIndex: Int
    public var bounds: NormalizedRect
    public var imageData: Data
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        pageIndex: Int,
        bounds: NormalizedRect,
        imageData: Data,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.bounds = bounds
        self.imageData = imageData
        self.createdAt = createdAt
    }
}

public enum MarginEdge: String, Codable, Equatable, CaseIterable {
    case leading
    case trailing
    case top
    case bottom
}

public struct MarginAnchor: Codable, Equatable {
    public var edge: MarginEdge
    public var offset: Double
    public var y: Double

    public init(edge: MarginEdge, offset: Double, y: Double) {
        self.edge = edge
        self.offset = offset
        self.y = y
    }
}

public enum CommentAnchor: Codable, Equatable {
    case inPage(NormalizedRect)
    case pagePoint(NormalizedPoint)
    case outsidePage(MarginAnchor)
    case pageOnly
}

public struct CommentThread: Codable, Equatable {
    public static let defaultColorHex = "#8E8E93"
    public static let attachedColorHex = "#B7C824"

    public var id: UUID
    public var pageIndex: Int
    public var anchor: CommentAnchor
    public var messages: [CommentMessage]
    public var colorHex: String
    public var displayHeight: Double?
    public var displayYOffset: Double?

    public init(
        id: UUID = UUID(),
        pageIndex: Int,
        anchor: CommentAnchor,
        messages: [CommentMessage] = [],
        colorHex: String = CommentThread.defaultColorHex,
        displayHeight: Double? = nil,
        displayYOffset: Double? = nil
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.anchor = anchor
        self.messages = messages
        self.colorHex = colorHex
        self.displayHeight = displayHeight
        self.displayYOffset = displayYOffset
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case pageIndex
        case anchor
        case messages
        case colorHex
        case displayHeight
        case displayYOffset
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        pageIndex = try container.decode(Int.self, forKey: .pageIndex)
        anchor = try container.decode(CommentAnchor.self, forKey: .anchor)
        messages = try container.decode([CommentMessage].self, forKey: .messages)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? CommentThread.defaultColorHex
        displayHeight = try container.decodeIfPresent(Double.self, forKey: .displayHeight)
        displayYOffset = try container.decodeIfPresent(Double.self, forKey: .displayYOffset)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(pageIndex, forKey: .pageIndex)
        try container.encode(anchor, forKey: .anchor)
        try container.encode(messages, forKey: .messages)
        try container.encode(colorHex, forKey: .colorHex)
        try container.encodeIfPresent(displayHeight, forKey: .displayHeight)
        try container.encodeIfPresent(displayYOffset, forKey: .displayYOffset)
    }
}

public enum CommentBoxSizing {
    public static let minimumHeight = 78.0
    public static let maximumHeight = 340.0
    public static let fallbackHeight = 176.0
    public static let resizeHandleHeight = 24.0
    public static let minimumScrollViewportHeight = 44.0

    public static func clampedHeight(_ height: Double) -> Double {
        min(maximumHeight, max(minimumHeight, height))
    }

    public static func resizedHeight(from startHeight: Double, dragTranslation: Double) -> Double {
        clampedHeight(startHeight + dragTranslation)
    }

    public static func scrollViewportHeight(for totalHeight: Double, showsResizeHandle: Bool = true) -> Double {
        let reservedHeight = showsResizeHandle ? resizeHandleHeight : 0
        return max(minimumScrollViewportHeight, clampedHeight(totalHeight) - reservedHeight)
    }

    public static func totalHeightForMeasuredContent(_ contentHeight: Double, showsResizeHandle: Bool = true) -> Double {
        let reservedHeight = showsResizeHandle ? resizeHandleHeight : 0
        return clampedHeight(contentHeight + reservedHeight)
    }

    public static func displayYOffset(startOffset: Double, dragTranslation: Double, railHeight: Double) -> Double {
        let normalizedTranslation = dragTranslation / max(railHeight, 1)
        return min(1, max(-1, startOffset + normalizedTranslation))
    }
}

public struct CommentMessage: Codable, Equatable {
    public var id: UUID
    public var author: String
    public var body: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        author: String,
        body: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.author = author
        self.body = body
        self.createdAt = createdAt
    }
}

public enum RegionKind: String, Codable, Equatable, CaseIterable {
    case figure
    case table
    case plot
    case equation
    case custom
}

public struct RegionSelection: Codable, Equatable {
    public var id: UUID
    public var pageIndex: Int
    public var kind: RegionKind
    public var bounds: NormalizedRect
    public var label: String?
    public var nearbyText: String?
    public var imageDigest: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        pageIndex: Int,
        kind: RegionKind,
        bounds: NormalizedRect,
        label: String? = nil,
        nearbyText: String? = nil,
        imageDigest: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.kind = kind
        self.bounds = bounds
        self.label = label
        self.nearbyText = nearbyText
        self.imageDigest = imageDigest
        self.createdAt = createdAt
    }
}

public enum OCRSource: String, Codable, Equatable, CaseIterable {
    case appleVision
    case cloud
    case imported
}

public struct OCRBlock: Codable, Equatable {
    public var id: UUID
    public var pageIndex: Int
    public var bounds: NormalizedRect
    public var text: String
    public var confidence: Double
    public var source: OCRSource

    public init(
        id: UUID = UUID(),
        pageIndex: Int,
        bounds: NormalizedRect,
        text: String,
        confidence: Double,
        source: OCRSource
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.bounds = bounds
        self.text = text
        self.confidence = confidence
        self.source = source
    }
}

public enum ChatRole: String, Codable, Equatable {
    case system
    case user
    case assistant
    case tool
}

public struct SourceCitation: Codable, Equatable, Hashable {
    public var pageIndex: Int
    public var label: String
    public var highlightText: String?
    public var bounds: NormalizedRect?

    public init(
        pageIndex: Int,
        label: String,
        highlightText: String? = nil,
        bounds: NormalizedRect? = nil
    ) {
        self.pageIndex = pageIndex
        self.label = label
        self.highlightText = highlightText
        self.bounds = bounds
    }
}

public struct ChatMessage: Codable, Equatable {
    public var role: ChatRole
    public var content: String
    public var citations: [SourceCitation]
    public var createdAt: Date

    public init(
        role: ChatRole,
        content: String,
        citations: [SourceCitation] = [],
        createdAt: Date = Date()
    ) {
        self.role = role
        self.content = content
        self.citations = citations
        self.createdAt = createdAt
    }
}

public struct ChatThread: Codable, Equatable {
    public var id: UUID
    public var agentID: String
    public var messages: [ChatMessage]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        agentID: String,
        messages: [ChatMessage] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.agentID = agentID
        self.messages = messages
        self.createdAt = createdAt
    }
}
