import AppKit
import PDFKit
import PaperReaderCore

enum PDFAnnotationFactory {
    private static let sidecarUserNamePrefix = "AIReader:"

    static func makeAnnotation(from annotation: Annotation, bounds: CGRect) -> PDFAnnotation {
        let pdfAnnotation: PDFAnnotation
        switch annotation.kind {
        case .highlight:
            pdfAnnotation = makeRoundedHighlight(
                bounds: bounds,
                color: NSColor(hex: annotation.colorHex) ?? .systemYellow,
                alpha: 0.42,
                contents: annotation.contents
            )
        case .note:
            pdfAnnotation = PDFAnnotation(bounds: bounds, forType: .text, withProperties: nil)
        case .textBox:
            pdfAnnotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        case .ink:
            pdfAnnotation = PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
        case .rectangle:
            pdfAnnotation = PDFAnnotation(bounds: bounds, forType: .square, withProperties: nil)
        }

        pdfAnnotation.contents = annotation.contents
        if annotation.kind != .highlight {
            pdfAnnotation.color = NSColor(hex: annotation.colorHex) ?? .systemYellow
        }
        markSidecarAnnotation(pdfAnnotation, id: annotation.id)
        if annotation.kind == .ink, let inkPoints = annotation.inkPoints, !inkPoints.isEmpty {
            let path = NSBezierPath()
            for (index, point) in inkPoints.enumerated() {
                let pagePoint = NSPoint(
                    x: bounds.minX + CGFloat(point.x) * bounds.width,
                    y: bounds.minY + CGFloat(point.y) * bounds.height
                )
                if index == 0 {
                    path.move(to: pagePoint)
                } else {
                    path.line(to: pagePoint)
                }
            }
            path.lineWidth = 2.5
            pdfAnnotation.add(path)
        }
        if annotation.kind == .textBox {
            pdfAnnotation.font = NSFont.systemFont(ofSize: max(11, min(18, bounds.height * 0.26)))
            pdfAnnotation.fontColor = .labelColor
            pdfAnnotation.color = (NSColor(hex: annotation.colorHex) ?? .systemYellow).withAlphaComponent(0.22)
        }
        return pdfAnnotation
    }

    static func makeRoundedHighlight(
        bounds: CGRect,
        color: NSColor,
        alpha: CGFloat,
        contents: String
    ) -> PDFAnnotation {
        let annotation = RoundedHighlightPDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
        annotation.color = color.withAlphaComponent(alpha)
        annotation.contents = contents
        return annotation
    }

    static func makeSignatureAnnotation(_ signature: Signature, bounds: CGRect) -> PDFAnnotation {
        let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        annotation.contents = "Signed"
        annotation.font = NSFont.systemFont(ofSize: max(11, min(18, bounds.height * 0.42)), weight: .semibold)
        annotation.fontColor = .labelColor
        annotation.color = NSColor.systemYellow.withAlphaComponent(0.18)
        markSidecarAnnotation(annotation, id: signature.id)
        return annotation
    }

    static func markSidecarAnnotation(_ annotation: PDFAnnotation, id: UUID) {
        annotation.userName = "\(sidecarUserNamePrefix)\(id.uuidString)"
    }

    static func sidecarID(from annotation: PDFAnnotation) -> UUID? {
        guard let userName = annotation.userName,
              userName.hasPrefix(sidecarUserNamePrefix) else {
            return nil
        }
        return UUID(uuidString: String(userName.dropFirst(sidecarUserNamePrefix.count)))
    }

    static func isSidecarAnnotation(_ annotation: PDFAnnotation) -> Bool {
        sidecarID(from: annotation) != nil
    }
}

private final class RoundedHighlightPDFAnnotation: PDFAnnotation {
    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        guard let fillColor = color.usingColorSpace(.deviceRGB)?.cgColor else {
            return
        }

        let radius = max(2, min(7, bounds.height * 0.45))
        let drawRect = bounds.insetBy(dx: -1.2, dy: -0.8)
        context.saveGState()
        context.setFillColor(fillColor)
        context.addPath(CGPath(
            roundedRect: drawRect,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        ))
        context.fillPath()
        context.restoreGState()
    }
}

private extension NSColor {
    convenience init?(hex: String) {
        var normalized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasPrefix("#") {
            normalized.removeFirst()
        }
        guard normalized.count == 6, let value = Int(normalized, radix: 16) else {
            return nil
        }
        self.init(
            calibratedRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 0.55
        )
    }
}
