import AppKit
import PDFKit
import PaperReaderCore

enum PDFDocumentController {
    static func makeSession(from document: PDFDocument, pdfURL: URL) -> DocumentSession {
        var pages: [PageModel] = []

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else {
                continue
            }
            let bounds = page.bounds(for: .mediaBox)
            pages.append(
                PageModel(
                    index: index,
                    size: PageSize(width: bounds.width, height: bounds.height),
                    embeddedText: page.string
                )
            )
        }

        return DocumentSession(
            pdfURL: pdfURL,
            title: pdfURL.deletingPathExtension().lastPathComponent,
            pages: pages
        )
    }

    static func importExternalHighlights(from document: PDFDocument, into session: DocumentSession) -> DocumentSession {
        var updated = session

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex),
                  let pageModel = updated.pages.first(where: { $0.index == pageIndex }) else {
                continue
            }

            for pdfAnnotation in page.annotations where isHighlight(pdfAnnotation) {
                let normalized = NormalizedRect(pageRect: PageRect(
                    x: pdfAnnotation.bounds.origin.x,
                    y: pdfAnnotation.bounds.origin.y,
                    width: pdfAnnotation.bounds.width,
                    height: pdfAnnotation.bounds.height
                ), pageSize: pageModel.size)
                let text = page.selection(for: pdfAnnotation.bounds)?.string?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? pdfAnnotation.contents
                    ?? "Imported highlight"
                let key = AnnotationIdentity.key(
                    pageIndex: pageIndex,
                    kind: .highlight,
                    bounds: normalized,
                    contents: text
                )
                if let index = updated.annotations.firstIndex(where: { annotation in
                    annotation.kind == .highlight
                        && annotation.externalPDFAnnotationKey == nil
                        && AnnotationIdentity.key(
                            pageIndex: annotation.pageIndex,
                            kind: annotation.kind,
                            bounds: annotation.bounds,
                            contents: annotation.contents
                        ) == key
                }) {
                    if updated.hiddenExternalAnnotationKeys.contains(key) {
                        updated.annotations.remove(at: index)
                        continue
                    }
                    updated.annotations[index].externalPDFAnnotationKey = key
                    continue
                }
                guard !updated.hiddenExternalAnnotationKeys.contains(key) else {
                    continue
                }
                guard updated.shouldImportExternalAnnotation(key: key) else {
                    continue
                }
                updated.annotations.append(
                    Annotation(
                        pageIndex: pageIndex,
                        kind: .highlight,
                        bounds: normalized,
                        contents: text.isEmpty ? "Imported highlight" : text,
                        externalPDFAnnotationKey: key
                    )
                )
            }
        }

        return updated
    }

    static func makeOutline(from document: PDFDocument, session: DocumentSession?) -> [PaperOutlineItem] {
        var sectionItems: [PaperOutlineItem] = []
        if let root = document.outlineRoot {
            collectPDFOutline(root, document: document, level: 0, into: &sectionItems)
        }

        if let session {
            let captions = detectFigureAndTableCaptions(from: session)
            if sectionItems.isEmpty || !sectionItems.contains(where: { sectionTitle(from: $0.title) != nil }) {
                sectionItems = inferSectionOutline(from: session)
            }
            return outlineWithCaptions(sectionItems: sectionItems, captions: captions, pageCount: document.pageCount)
        }

        return sectionItems
    }

    static func applyStoredAnnotations(session: DocumentSession, to document: PDFDocument) {
        removeSidecarAnnotations(in: document)
        hideExternalAnnotations(session: session, in: document)

        for annotation in session.annotations {
            guard annotation.externalPDFAnnotationKey == nil else {
                continue
            }
            guard let page = document.page(at: annotation.pageIndex),
                  let pageModel = session.pages.first(where: { $0.index == annotation.pageIndex }) else {
                continue
            }
            let pageRect = annotation.bounds.pageRect(in: pageModel.size).cgRect
            page.addAnnotation(PDFAnnotationFactory.makeAnnotation(from: annotation, bounds: pageRect))
        }

        for signature in session.signatures {
            guard let page = document.page(at: signature.pageIndex),
                  let pageModel = session.pages.first(where: { $0.index == signature.pageIndex }) else {
                continue
            }
            let pageRect = signature.bounds.pageRect(in: pageModel.size).cgRect
            page.addAnnotation(PDFAnnotationFactory.makeSignatureAnnotation(signature, bounds: pageRect))
        }
    }

    static func removeSidecarAnnotations(in document: PDFDocument) {
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else {
                continue
            }
            for annotation in page.annotations where PDFAnnotationFactory.isSidecarAnnotation(annotation) {
                page.removeAnnotation(annotation)
            }
        }
    }

    static func hideExternalAnnotations(session: DocumentSession, in document: PDFDocument) {
        guard !session.hiddenExternalAnnotationKeys.isEmpty else {
            return
        }
        let hiddenKeys = Set(session.hiddenExternalAnnotationKeys)
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex),
                  let pageModel = session.pages.first(where: { $0.index == pageIndex }) else {
                continue
            }
            for annotation in page.annotations where isHighlight(annotation) {
                let normalized = NormalizedRect(pageRect: PageRect(
                    x: annotation.bounds.origin.x,
                    y: annotation.bounds.origin.y,
                    width: annotation.bounds.width,
                    height: annotation.bounds.height
                ), pageSize: pageModel.size)
                let text = page.selection(for: annotation.bounds)?.string?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? annotation.contents
                let key = AnnotationIdentity.key(
                    pageIndex: pageIndex,
                    kind: .highlight,
                    bounds: normalized,
                    contents: text
                )
                if hiddenKeys.contains(key) {
                    page.removeAnnotation(annotation)
                }
            }
        }
    }

    static func pageImageData(document: PDFDocument, pageIndex: Int, crop normalizedCrop: NormalizedRect? = nil) -> Data? {
        guard let page = document.page(at: pageIndex) else {
            return nil
        }

        let bounds = page.bounds(for: .mediaBox)
        let cropRect = resolvedCropRect(normalizedCrop, pageBounds: bounds)
        let renderScale: CGFloat = normalizedCrop == nil ? 1 : 2
        let imageSize = CGSize(width: max(1, cropRect.width * renderScale), height: max(1, cropRect.height * renderScale))
        let image = NSImage(size: imageSize)
        image.lockFocus()
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }
        NSColor.white.setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: imageSize)).fill()
        context.scaleBy(x: renderScale, y: renderScale)
        context.translateBy(x: -cropRect.minX, y: -cropRect.minY)
        page.draw(with: .mediaBox, to: context)
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let representation = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return representation.representation(using: .png, properties: [:])
    }

    private static func resolvedCropRect(_ normalizedCrop: NormalizedRect?, pageBounds: CGRect) -> CGRect {
        guard let normalizedCrop else {
            return pageBounds
        }

        let pageSize = PageSize(width: pageBounds.width, height: pageBounds.height)
        let pageRect = normalizedCrop.pageRect(in: pageSize).cgRect
            .offsetBy(dx: pageBounds.minX, dy: pageBounds.minY)
            .insetBy(dx: -10, dy: -10)
        let clamped = pageRect.intersection(pageBounds)
        if clamped.isNull || clamped.isEmpty {
            return pageBounds
        }
        return clamped
    }

    private static func collectPDFOutline(
        _ outline: PDFOutline,
        document: PDFDocument,
        level: Int,
        into items: inout [PaperOutlineItem]
    ) {
        for index in 0..<outline.numberOfChildren {
            guard let child = outline.child(at: index) else {
                continue
            }
            if let destination = child.destination,
               let page = destination.page {
                let pageIndex = document.index(for: page)
                if pageIndex != NSNotFound {
                    items.append(PaperOutlineItem(title: child.label ?? "Section", pageIndex: pageIndex, level: level))
                }
            }
            collectPDFOutline(child, document: document, level: level + 1, into: &items)
        }
    }

    private static func inferSectionOutline(from session: DocumentSession) -> [PaperOutlineItem] {
        var sections: [PaperOutlineItem] = []
        var seenTitles = Set<String>()

        for page in session.pages {
            for title in PaperOutlineInference.sectionTitles(in: page.embeddedText ?? "") {
                let key = title.lowercased()
                if seenTitles.insert(key).inserted {
                    sections.append(PaperOutlineItem(title: title, pageIndex: page.index, level: 0))
                }
            }
        }

        return sections
    }

    private static func detectFigureAndTableCaptions(from session: DocumentSession) -> [PaperOutlineItem] {
        var captions: [PaperOutlineItem] = []
        var seen = Set<String>()

        for page in session.pages {
            let lines = (page.embeddedText ?? "")
                .components(separatedBy: .newlines)
                .map(cleanLine)
                .filter { !$0.isEmpty }

            for line in lines {
                guard let caption = figureOrTableCaption(from: line) else {
                    continue
                }
                let key = "\(page.index)-\(caption.lowercased())"
                if seen.insert(key).inserted {
                    captions.append(PaperOutlineItem(title: caption, pageIndex: page.index, level: 1))
                }
            }
        }

        return captions
    }

    private static func outlineWithCaptions(
        sectionItems: [PaperOutlineItem],
        captions: [PaperOutlineItem],
        pageCount: Int
    ) -> [PaperOutlineItem] {
        let sections = sectionItems
            .compactMap { item -> PaperOutlineItem? in
                guard let title = sectionTitle(from: item.title) else {
                    return nil
                }
                return PaperOutlineItem(title: title, pageIndex: item.pageIndex, level: 0)
            }
            .sorted { lhs, rhs in
                if lhs.pageIndex == rhs.pageIndex {
                    return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }
                return lhs.pageIndex < rhs.pageIndex
            }

        let sortedCaptions = captions.sorted { lhs, rhs in
            if lhs.pageIndex == rhs.pageIndex {
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
            return lhs.pageIndex < rhs.pageIndex
        }

        if sections.isEmpty {
            return sortedCaptions.map { caption in
                PaperOutlineItem(title: caption.title, pageIndex: min(caption.pageIndex, max(pageCount - 1, 0)), level: 0)
            }
        }

        var result: [PaperOutlineItem] = []
        for (index, section) in sections.enumerated() {
            result.append(PaperOutlineItem(title: section.title, pageIndex: min(section.pageIndex, max(pageCount - 1, 0)), level: 0))

            let nextPage = sections.indices.contains(index + 1) ? sections[index + 1].pageIndex : pageCount
            for caption in sortedCaptions where caption.pageIndex >= section.pageIndex && caption.pageIndex < nextPage {
                result.append(PaperOutlineItem(title: caption.title, pageIndex: caption.pageIndex, level: 1))
            }
        }

        return result
    }

    private static func sectionTitle(from line: String) -> String? {
        PaperOutlineInference.sectionTitle(from: line)
    }

    private static func figureOrTableCaption(from line: String) -> String? {
        let trimmed = cleanLine(line)
        return PaperOutlineInference.figureOrTableLabel(from: trimmed)
    }

    private static func cleanLine(_ line: String) -> String {
        line
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func trimmedTitle(_ title: String, maxLength: Int = 82) -> String {
        let clean = cleanLine(title)
        guard clean.count > maxLength else {
            return clean
        }
        return String(clean.prefix(maxLength - 1)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func isHighlight(_ annotation: PDFAnnotation) -> Bool {
        guard let type = annotation.type else {
            return false
        }
        return type == PDFAnnotationSubtype.highlight.rawValue
            || type.localizedCaseInsensitiveContains("highlight")
    }
}

private extension PageRect {
    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}
