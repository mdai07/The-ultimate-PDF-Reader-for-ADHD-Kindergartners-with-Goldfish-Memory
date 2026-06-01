import AppKit
import PDFKit
import PaperReaderCore

enum PDFExportMode: CaseIterable {
    case pdfWithoutMetadata
    case pdfWithHiddenMetadata
    case apparentChanges

    var title: String {
        switch self {
        case .pdfWithoutMetadata:
            return "PDF Only (No uprakigo Metadata)"
        case .pdfWithHiddenMetadata:
            return "PDF with Hidden uprakigo Metadata"
        case .apparentChanges:
            return "Expanded Visible PDF"
        }
    }

    var fileSuffix: String {
        switch self {
        case .pdfWithoutMetadata:
            return "pdf-only"
        case .pdfWithHiddenMetadata:
            return "hidden-metadata"
        case .apparentChanges:
            return "visible-changes"
        }
    }
}

struct PDFExportService {
    enum ExportError: Error {
        case missingPage(Int)
        case couldNotCreateContext
        case couldNotCloneDocument
    }

    func export(
        document: PDFDocument,
        session: DocumentSession,
        to outputURL: URL,
        mode: PDFExportMode
    ) throws {
        let exportDocument = try clone(document)
        switch mode {
        case .pdfWithoutMetadata:
            PDFEmbeddedMetadataStore.remove(from: exportDocument)
            PDFDocumentController.removeSidecarAnnotations(in: exportDocument)
            if !exportDocument.write(to: outputURL) {
                throw ExportError.couldNotCreateContext
            }
        case .pdfWithHiddenMetadata:
            PDFEmbeddedMetadataStore.remove(from: exportDocument)
            PDFDocumentController.removeSidecarAnnotations(in: exportDocument)
            if !exportDocument.write(to: outputURL) {
                throw ExportError.couldNotCreateContext
            }
            try PDFEmbeddedMetadataStore.append(session: session, to: outputURL)
        case .apparentChanges:
            PDFEmbeddedMetadataStore.remove(from: exportDocument)
            PDFDocumentController.removeSidecarAnnotations(in: exportDocument)
            try exportExpandedMargin(document: exportDocument, session: session, to: outputURL)
        }
    }

    func saveInPlaceWithHiddenMetadata(
        document: PDFDocument,
        session: DocumentSession,
        to pdfURL: URL
    ) throws {
        let temporaryURL = pdfURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(pdfURL.deletingPathExtension().lastPathComponent)-\(UUID().uuidString).aireader-save.pdf")
        do {
            try export(document: document, session: session, to: temporaryURL, mode: .pdfWithHiddenMetadata)
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: pdfURL.path) {
                _ = try fileManager.replaceItemAt(pdfURL, withItemAt: temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: pdfURL)
            }
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }
    }

    private func clone(_ document: PDFDocument) throws -> PDFDocument {
        guard let data = document.dataRepresentation(),
              let clone = PDFDocument(data: data) else {
            throw ExportError.couldNotCloneDocument
        }
        return clone
    }

    func export(
        document: PDFDocument,
        session: DocumentSession,
        to outputURL: URL,
        includeExpandedMargin: Bool
    ) throws {
        if includeExpandedMargin {
            try export(document: document, session: session, to: outputURL, mode: .apparentChanges)
        } else if !document.write(to: outputURL) {
            throw ExportError.couldNotCreateContext
        }
    }

    private func exportExpandedMargin(document: PDFDocument, session: DocumentSession, to outputURL: URL) throws {
        let marginWidth: CGFloat = 220
        guard let firstPage = document.page(at: 0) else {
            throw ExportError.missingPage(0)
        }

        var mediaBox = firstPage.bounds(for: .mediaBox)
        mediaBox.size.width += marginWidth
        guard let context = CGContext(outputURL as CFURL, mediaBox: &mediaBox, nil) else {
            throw ExportError.couldNotCreateContext
        }

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else {
                throw ExportError.missingPage(pageIndex)
            }

            let bounds = page.bounds(for: .mediaBox)
            context.beginPDFPage(nil)
            context.saveGState()
            page.draw(with: .mediaBox, to: context)
            for annotation in page.annotations {
                annotation.draw(with: .mediaBox, in: context)
            }
            context.restoreGState()

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            drawSidecarAnnotations(
                session.annotations.filter { $0.pageIndex == pageIndex },
                signatures: session.signatures.filter { $0.pageIndex == pageIndex },
                session: session,
                pageIndex: pageIndex
            )
            drawMarginComments(
                session.comments.filter { $0.pageIndex == pageIndex },
                pageBounds: bounds,
                marginWidth: marginWidth
            )
            NSGraphicsContext.restoreGraphicsState()
            context.endPDFPage()
        }

        context.closePDF()
    }

    private func drawSidecarAnnotations(
        _ annotations: [Annotation],
        signatures: [Signature],
        session: DocumentSession,
        pageIndex: Int
    ) {
        guard let pageModel = session.pages.first(where: { $0.index == pageIndex }) else {
            return
        }

        for annotation in annotations {
            guard annotation.externalPDFAnnotationKey == nil else {
                continue
            }
            let rect = annotation.bounds.pageRect(in: pageModel.size).cgRect
            let color = NSColor(hex: annotation.colorHex) ?? .systemYellow
            switch annotation.kind {
            case .highlight:
                color.withAlphaComponent(0.36).setFill()
                NSBezierPath(roundedRect: rect.insetBy(dx: -1, dy: -0.8), xRadius: 5, yRadius: 5).fill()
            case .rectangle:
                color.withAlphaComponent(0.14).setFill()
                NSBezierPath(rect: rect).fill()
                color.withAlphaComponent(0.8).setStroke()
                let path = NSBezierPath(rect: rect)
                path.lineWidth = 1.4
                path.stroke()
            case .note:
                drawLabel(annotation.contents.isEmpty ? "Note" : annotation.contents, in: rect, color: color)
            case .textBox:
                drawLabel(annotation.contents, in: rect, color: color)
            case .ink:
                drawInk(annotation, in: rect, color: color)
            }
        }

        for signature in signatures {
            let rect = signature.bounds.pageRect(in: pageModel.size).cgRect
            drawLabel("Signed", in: rect, color: .systemYellow)
        }
    }

    private func drawInk(_ annotation: Annotation, in rect: CGRect, color: NSColor) {
        guard let points = annotation.inkPoints, !points.isEmpty else {
            return
        }
        let path = NSBezierPath()
        for (index, point) in points.enumerated() {
            let pagePoint = NSPoint(
                x: rect.minX + CGFloat(point.x) * rect.width,
                y: rect.minY + CGFloat(point.y) * rect.height
            )
            if index == 0 {
                path.move(to: pagePoint)
            } else {
                path.line(to: pagePoint)
            }
        }
        color.withAlphaComponent(0.9).setStroke()
        path.lineWidth = 2.5
        path.stroke()
    }

    private func drawLabel(_ text: String, in rect: CGRect, color: NSColor) {
        let drawRect = rect.insetBy(dx: -2, dy: -2)
        let shape = NSBezierPath(roundedRect: drawRect, xRadius: 4, yRadius: 4)
        color.withAlphaComponent(0.34).setFill()
        shape.fill()
        darker(color).withAlphaComponent(0.88).setStroke()
        shape.lineWidth = 1
        shape.stroke()
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: max(9, min(14, rect.height * 0.28))),
            .foregroundColor: printTextColor,
            .paragraphStyle: paragraph
        ]
        (text as NSString).draw(in: rect.insetBy(dx: 4, dy: 4), withAttributes: attributes)
    }

    private func drawMarginComments(_ comments: [CommentThread], pageBounds: CGRect, marginWidth: CGFloat) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: printTextColor,
            .paragraphStyle: paragraph
        ]

        for (index, thread) in comments.enumerated() {
            let body = thread.messages
                .map { AISuggestionNoteFormatter.commentBodyForDisplay($0.body) }
                .joined(separator: "\n")
            guard !body.isEmpty else {
                continue
            }
            let y = pageBounds.maxY - 72 - CGFloat(index * 92)
            let rect = CGRect(x: pageBounds.maxX + 18, y: max(36, y), width: marginWidth - 36, height: 78)
            let color = NSColor(hex: thread.colorHex) ?? .systemGray
            drawCommentConnector(from: thread.anchor, to: rect, pageBounds: pageBounds, color: color)
            let shape = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
            color.withAlphaComponent(0.38).setFill()
            shape.fill()
            darker(color).withAlphaComponent(0.95).setStroke()
            shape.lineWidth = 1.2
            shape.stroke()
            (body as NSString).draw(in: rect.insetBy(dx: 8, dy: 8), withAttributes: attributes)
        }
    }

    private var printTextColor: NSColor {
        NSColor(calibratedWhite: 0.06, alpha: 1)
    }

    private func drawCommentConnector(
        from anchor: CommentAnchor,
        to commentRect: CGRect,
        pageBounds: CGRect,
        color: NSColor
    ) {
        guard let start = connectorStartPoint(for: anchor, pageBounds: pageBounds) else {
            return
        }
        let end = CGPoint(x: commentRect.minX, y: commentRect.midY)
        let deltaX = max(24, end.x - start.x)
        let path = NSBezierPath()
        path.move(to: start)
        path.curve(
            to: end,
            controlPoint1: CGPoint(x: start.x + deltaX * 0.38, y: start.y),
            controlPoint2: CGPoint(x: end.x - deltaX * 0.38, y: end.y)
        )
        darker(color, amount: 0.34).withAlphaComponent(0.82).setStroke()
        path.lineWidth = 1.6
        path.stroke()
    }

    private func connectorStartPoint(for anchor: CommentAnchor, pageBounds: CGRect) -> CGPoint? {
        switch anchor {
        case .inPage(let rect):
            return CGPoint(
                x: pageBounds.minX + (rect.x + rect.width) * pageBounds.width,
                y: pageBounds.minY + (rect.y + rect.height / 2) * pageBounds.height
            )
        case .pagePoint(let point):
            return CGPoint(
                x: pageBounds.minX + point.x * pageBounds.width,
                y: pageBounds.minY + point.y * pageBounds.height
            )
        case .outsidePage(let anchor):
            return CGPoint(
                x: pageBounds.maxX,
                y: pageBounds.minY + anchor.y * pageBounds.height
            )
        case .pageOnly:
            return nil
        }
    }

    private func darker(_ color: NSColor, amount: CGFloat = 0.25) -> NSColor {
        guard let rgb = color.usingColorSpace(.deviceRGB) else {
            return color
        }
        return NSColor(
            calibratedRed: max(0, rgb.redComponent * (1 - amount)),
            green: max(0, rgb.greenComponent * (1 - amount)),
            blue: max(0, rgb.blueComponent * (1 - amount)),
            alpha: rgb.alphaComponent
        )
    }
}

private extension PageRect {
    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

private extension NSColor {
    convenience init?(hex: String) {
        var value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if value.count == 3 {
            value = value.map { "\($0)\($0)" }.joined()
        }
        guard value.count == 6, let number = Int(value, radix: 16) else {
            return nil
        }
        self.init(
            calibratedRed: CGFloat((number >> 16) & 0xff) / 255,
            green: CGFloat((number >> 8) & 0xff) / 255,
            blue: CGFloat(number & 0xff) / 255,
            alpha: 1
        )
    }
}
