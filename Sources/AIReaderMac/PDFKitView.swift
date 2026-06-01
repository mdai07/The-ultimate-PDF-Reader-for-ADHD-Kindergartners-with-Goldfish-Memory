import PDFKit
import PaperReaderCore
import SwiftUI

enum PDFAnnotationRemovalKind: Equatable {
    case annotation(AnnotationKind)
    case signature
}

struct PDFAnnotationRemovalRequest: Equatable {
    var pageIndex: Int
    var kind: PDFAnnotationRemovalKind
    var bounds: NormalizedRect
    var contents: String
    var sidecarID: UUID?
    var externalPDFAnnotationKey: String?
}

struct PDFHighlightNoteRequest: Equatable {
    var pageIndex: Int
    var bounds: NormalizedRect
    var contents: String
    var colorHex: String
}

struct PDFKitView: NSViewRepresentable {
    var document: PDFDocument?
    @Binding var scaleFactor: Double
    @Binding var autoScales: Bool
    @Binding var requestedPageIndex: Int?
    var onSelectedText: (String, Int, CGPoint?, NormalizedRect?) -> Void
    var onPageChanged: (Int) -> Void
    var onSelectionHover: (Bool) -> Void
    var onSelectionCleared: () -> Void
    var onLinkActivated: (URL) -> Void
    var onPageAnchorSelected: (Int, NormalizedPoint) -> Void = { _, _ in }
    var onViewportChanged: (PDFViewportSnapshot) -> Void = { _ in }
    var onAnnotationRemovalRequested: (PDFAnnotationRemovalRequest) -> Void = { _ in }
    var onHighlightNoteRequested: (PDFHighlightNoteRequest) -> Void = { _ in }
    var onPageMarginCommentRequested: (Int, NormalizedPoint) -> Void = { _, _ in }
    var onOCRPageRequested: (Int) -> Void = { _ in }
    var onRegionSelected: (Int, NormalizedRect) -> Void = { _, _ in }
    var activeTool: ReaderTool?
    var highlightColorHex = "#F7D154"
    var onAnnotationCreated: (Annotation) -> Void = { _ in }
    var onSignatureCreated: (Signature) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            scaleFactor: $scaleFactor,
            autoScales: $autoScales,
            requestedPageIndex: $requestedPageIndex,
            onSelectedText: onSelectedText,
            onPageChanged: onPageChanged,
            onSelectionHover: onSelectionHover,
            onSelectionCleared: onSelectionCleared,
            onLinkActivated: onLinkActivated,
            onPageAnchorSelected: onPageAnchorSelected,
            onViewportChanged: onViewportChanged,
            onRegionSelected: onRegionSelected
        )
    }

    func makeNSView(context: Context) -> PDFView {
        let view = ReaderPDFView()
        view.minScaleFactor = 0.10
        view.maxScaleFactor = 12.0
        view.autoScales = autoScales
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .windowBackgroundColor
        view.document = document
        view.onSelectionHover = { isHovering in
            context.coordinator.onSelectionHover(isHovering)
        }
        view.onSelectionCleared = {
            context.coordinator.onSelectionCleared()
        }
        view.onHighlightedTextHover = { text, pageIndex, anchor, bounds in
            context.coordinator.onSelectedText(text, pageIndex, anchor, bounds)
        }
        view.onLinkActivated = { url in
            context.coordinator.onLinkActivated(url)
        }
        view.onPageAnchorSelected = { pageIndex, point in
            context.coordinator.onPageAnchorSelected(pageIndex, point)
        }
        view.onAnnotationRemovalRequested = onAnnotationRemovalRequested
        view.onHighlightNoteRequested = onHighlightNoteRequested
        view.onPageMarginCommentRequested = onPageMarginCommentRequested
        view.onOCRPageRequested = onOCRPageRequested
        view.onRegionSelected = { pageIndex, bounds in
            context.coordinator.onRegionSelected(pageIndex, bounds)
        }
        view.activeTool = activeTool
        view.highlightColorHex = highlightColorHex
        view.onAnnotationCreated = onAnnotationCreated
        view.onSignatureCreated = onSignatureCreated
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if view.document !== document {
            view.document = document
        }
        view.minScaleFactor = 0.10
        view.maxScaleFactor = 12.0
        if autoScales {
            view.autoScales = true
            DispatchQueue.main.async {
                let currentScale = view.scaleFactor
                if abs(scaleFactor - currentScale) > 0.001 {
                    scaleFactor = currentScale
                }
            }
        } else {
            view.autoScales = false
            let nextScale = max(view.minScaleFactor, min(view.maxScaleFactor, scaleFactor))
            if abs(view.scaleFactor - nextScale) > 0.001 {
                view.scaleFactor = nextScale
            }
        }
        if let pageIndex = requestedPageIndex,
           let page = view.document?.page(at: pageIndex) {
            view.go(to: page)
            DispatchQueue.main.async {
                requestedPageIndex = nil
            }
        }
        context.coordinator.scaleFactor = $scaleFactor
        context.coordinator.autoScales = $autoScales
        context.coordinator.requestedPageIndex = $requestedPageIndex
        context.coordinator.onSelectedText = onSelectedText
        context.coordinator.onPageChanged = onPageChanged
        context.coordinator.onSelectionHover = onSelectionHover
        context.coordinator.onSelectionCleared = onSelectionCleared
        context.coordinator.onLinkActivated = onLinkActivated
        context.coordinator.onPageAnchorSelected = onPageAnchorSelected
        context.coordinator.onViewportChanged = onViewportChanged
        context.coordinator.onRegionSelected = onRegionSelected
        context.coordinator.observeScrollViewIfNeeded()
        context.coordinator.emitViewportChanged(deferred: true)
        if let readerView = view as? ReaderPDFView {
            readerView.onSelectionHover = { isHovering in
                context.coordinator.onSelectionHover(isHovering)
            }
            readerView.onSelectionCleared = {
                context.coordinator.onSelectionCleared()
            }
            readerView.onHighlightedTextHover = { text, pageIndex, anchor, bounds in
                context.coordinator.onSelectedText(text, pageIndex, anchor, bounds)
            }
            readerView.onLinkActivated = { url in
                context.coordinator.onLinkActivated(url)
            }
            readerView.onPageAnchorSelected = { pageIndex, point in
                context.coordinator.onPageAnchorSelected(pageIndex, point)
            }
            readerView.onAnnotationRemovalRequested = onAnnotationRemovalRequested
            readerView.onHighlightNoteRequested = onHighlightNoteRequested
            readerView.onPageMarginCommentRequested = onPageMarginCommentRequested
            readerView.onOCRPageRequested = onOCRPageRequested
            readerView.onRegionSelected = { pageIndex, bounds in
                context.coordinator.onRegionSelected(pageIndex, bounds)
            }
            readerView.activeTool = activeTool
            readerView.highlightColorHex = highlightColorHex
            readerView.onAnnotationCreated = onAnnotationCreated
            readerView.onSignatureCreated = onSignatureCreated
        }
    }

    final class Coordinator: NSObject {
        var scaleFactor: Binding<Double>
        var autoScales: Binding<Bool>
        var requestedPageIndex: Binding<Int?>
        var onSelectedText: (String, Int, CGPoint?, NormalizedRect?) -> Void
        var onPageChanged: (Int) -> Void
        var onSelectionHover: (Bool) -> Void
        var onSelectionCleared: () -> Void
        var onLinkActivated: (URL) -> Void
        var onPageAnchorSelected: (Int, NormalizedPoint) -> Void
        var onViewportChanged: (PDFViewportSnapshot) -> Void
        var onRegionSelected: (Int, NormalizedRect) -> Void
        weak var pdfView: PDFView?
        private weak var observedClipView: NSClipView?
        private var lastEmittedPageIndex: Int?

        init(
            scaleFactor: Binding<Double>,
            autoScales: Binding<Bool>,
            requestedPageIndex: Binding<Int?>,
            onSelectedText: @escaping (String, Int, CGPoint?, NormalizedRect?) -> Void,
            onPageChanged: @escaping (Int) -> Void,
            onSelectionHover: @escaping (Bool) -> Void,
            onSelectionCleared: @escaping () -> Void,
            onLinkActivated: @escaping (URL) -> Void,
            onPageAnchorSelected: @escaping (Int, NormalizedPoint) -> Void,
            onViewportChanged: @escaping (PDFViewportSnapshot) -> Void,
            onRegionSelected: @escaping (Int, NormalizedRect) -> Void
        ) {
            self.scaleFactor = scaleFactor
            self.autoScales = autoScales
            self.requestedPageIndex = requestedPageIndex
            self.onSelectedText = onSelectedText
            self.onPageChanged = onPageChanged
            self.onSelectionHover = onSelectionHover
            self.onSelectionCleared = onSelectionCleared
            self.onLinkActivated = onLinkActivated
            self.onPageAnchorSelected = onPageAnchorSelected
            self.onViewportChanged = onViewportChanged
            self.onRegionSelected = onRegionSelected
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func attach(to view: PDFView) {
            pdfView = view
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(selectionChanged(_:)),
                name: Notification.Name.PDFViewSelectionChanged,
                object: view
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(pageChanged(_:)),
                name: Notification.Name.PDFViewPageChanged,
                object: view
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(scaleChanged(_:)),
                name: Notification.Name.PDFViewScaleChanged,
                object: view
            )
            observeScrollViewIfNeeded()
            emitViewportChanged(deferred: true)
        }

        func observeScrollViewIfNeeded() {
            guard let pdfView,
                  let clipView = scrollView(in: pdfView)?.contentView,
                  observedClipView !== clipView else {
                return
            }

            if let observedClipView {
                NotificationCenter.default.removeObserver(
                    self,
                    name: NSView.boundsDidChangeNotification,
                    object: observedClipView
                )
            }

            clipView.postsBoundsChangedNotifications = true
            observedClipView = clipView
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(viewportChanged(_:)),
                name: NSView.boundsDidChangeNotification,
                object: clipView
            )
        }

        @objc private func selectionChanged(_ notification: Notification) {
            guard let view = notification.object as? PDFView else {
                return
            }
            guard let text = view.currentSelection?.string,
                  let page = view.currentSelection?.pages.first,
                  let index = view.document?.index(for: page) else {
                if isFocusInsidePDFView(view) {
                    onSelectionCleared()
                }
                return
            }
            onSelectedText(text, index, selectionAnchor(in: view), selectionBounds(in: view))
            onSelectionHover(true)
        }

        @objc private func pageChanged(_ notification: Notification) {
            guard let view = notification.object as? PDFView,
                  let page = view.currentPage,
                  let index = view.document?.index(for: page) else {
                return
            }
            onPageChanged(index)
            lastEmittedPageIndex = index
            emitViewportChanged()
        }

        @objc private func scaleChanged(_ notification: Notification) {
            guard let view = notification.object as? PDFView else {
                return
            }
            scaleFactor.wrappedValue = view.scaleFactor
            autoScales.wrappedValue = view.autoScales
            emitViewportChanged()
        }

        @objc private func viewportChanged(_ notification: Notification) {
            guard let view = pdfView,
                  let page = view.currentPage,
                  let index = view.document?.index(for: page) else {
                emitViewportChanged()
                return
            }
            if lastEmittedPageIndex != index {
                lastEmittedPageIndex = index
                onPageChanged(index)
            }
            emitViewportChanged()
        }

        func emitViewportChanged(deferred: Bool = false) {
            guard let view = pdfView,
                  let document = view.document else {
                onViewportChanged(PDFViewportSnapshot(viewSize: .zero, pageFrames: [:]))
                return
            }

            let sendSnapshot = { [weak self, weak view, weak document] in
                guard let self,
                      let view,
                      let document else {
                    return
                }
                let viewHeight = max(view.bounds.height, 1)
                var frames: [Int: CGRect] = [:]
                for index in 0..<document.pageCount {
                    guard let page = document.page(at: index) else {
                        continue
                    }
                    let pageRect = view.convert(page.bounds(for: .mediaBox), from: page)
                    frames[index] = CGRect(
                        x: pageRect.minX,
                        y: viewHeight - pageRect.maxY,
                        width: pageRect.width,
                        height: pageRect.height
                    )
                }
                self.onViewportChanged(PDFViewportSnapshot(viewSize: view.bounds.size, pageFrames: frames))
            }

            if deferred {
                DispatchQueue.main.async(execute: sendSnapshot)
            } else {
                sendSnapshot()
            }
        }

        private func selectionAnchor(in view: PDFView) -> CGPoint? {
            guard let selection = view.currentSelection,
                  let page = selection.pages.first else {
                return nil
            }
            let pageRect = selection.bounds(for: page)
            let viewRect = view.convert(pageRect, from: page)
            return CGPoint(
                x: min(view.bounds.maxX - 180, max(16, viewRect.midX)),
                y: min(view.bounds.maxY - 40, max(16, view.bounds.height - viewRect.maxY - 12))
            )
        }

        private func isFocusInsidePDFView(_ view: PDFView) -> Bool {
            guard let responder = view.window?.firstResponder as? NSView else {
                return false
            }
            return responder === view || responder.isDescendant(of: view)
        }

        private func selectionBounds(in view: PDFView) -> NormalizedRect? {
            guard let selection = view.currentSelection,
                  let page = selection.pages.first else {
                return nil
            }
            return normalizedRect(selection.bounds(for: page), on: page)
        }

        private func scrollView(in view: NSView) -> NSScrollView? {
            if let scrollView = view as? NSScrollView {
                return scrollView
            }
            for subview in view.subviews {
                if let match = scrollView(in: subview) {
                    return match
                }
            }
            return nil
        }
    }
}

struct PDFViewportSnapshot: Equatable {
    var viewSize: CGSize
    var pageFrames: [Int: CGRect]
}

final class ReaderPDFView: PDFView {
    var onSelectionHover: ((Bool) -> Void)?
    var onSelectionCleared: (() -> Void)?
    var onHighlightedTextHover: ((String, Int, CGPoint?, NormalizedRect?) -> Void)?
    var onLinkActivated: ((URL) -> Void)?
    var onPageAnchorSelected: ((Int, NormalizedPoint) -> Void)?
    var onAnnotationRemovalRequested: ((PDFAnnotationRemovalRequest) -> Void)?
    var onHighlightNoteRequested: ((PDFHighlightNoteRequest) -> Void)?
    var onPageMarginCommentRequested: ((Int, NormalizedPoint) -> Void)?
    var onOCRPageRequested: ((Int) -> Void)?
    var onRegionSelected: ((Int, NormalizedRect) -> Void)?
    var activeTool: ReaderTool?
    var highlightColorHex = "#F7D154"
    var onAnnotationCreated: ((Annotation) -> Void)?
    var onSignatureCreated: ((Signature) -> Void)?
    private var trackingAreaForHover: NSTrackingArea?
    private var isHoveringSelection = false
    private var activeInkPage: PDFPage?
    private var activeInkPoints: [CGPoint] = []
    private var activeInkAnnotation: PDFAnnotation?
    private var signatureStart: (page: PDFPage, point: CGPoint)?
    private var pendingRegionStart: (page: PDFPage, point: CGPoint)?
    private var activeRegionCurrentPoint: CGPoint?
    private var activeRegionAnnotation: PDFAnnotation?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .arrow)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingAreaForHover {
            removeTrackingArea(trackingAreaForHover)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInActiveApp, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaForHover = trackingArea
    }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.arrow.set()
        super.mouseMoved(with: event)
        updateSelectionHover(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        NSCursor.arrow.set()
        switch activeTool {
        case .outsideComment:
            if let (page, point) = pageAndPoint(for: event),
               let pageIndex = page.document?.index(for: page) {
                onPageAnchorSelected?(pageIndex, normalizedPoint(point, on: page))
                return
            }
        case .highlight:
            break
        case .note:
            addNote(at: event)
            return
        case .textBox:
            addTextBox(at: event)
            return
        case .ink:
            beginInk(at: event)
            return
        case .signature:
            beginSignature(at: event)
            return
        default:
            break
        }
        if !isEventInsideCurrentSelection(event) {
            setSelectionHover(false)
            onSelectionCleared?()
        }
        if handleHighlightedTextClick(event) {
            return
        }
        if beginSmartRegionSelectionIfNeeded(at: event) {
            return
        }
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        NSCursor.arrow.set()
        if pendingRegionStart != nil {
            continueSmartRegionSelection(at: event)
            return
        }
        switch activeTool {
        case .ink:
            continueInk(at: event)
            return
        case .signature:
            return
        default:
            break
        }
        super.mouseDragged(with: event)
        updateSelectionHover(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        NSCursor.arrow.set()
        if pendingRegionStart != nil {
            finishSmartRegionSelection(at: event)
            return
        }
        switch activeTool {
        case .ink:
            finishInk(at: event)
            return
        case .signature:
            finishSignature(at: event)
            return
        default:
            break
        }
        if handleLinkClick(event) {
            return
        }
        super.mouseUp(with: event)
        if activeTool == .highlight {
            addHighlightFromCurrentSelection()
        }
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.arrow.set()
        super.mouseEntered(with: event)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        setSelectionHover(false)
    }

    override func magnify(with event: NSEvent) {
        autoScales = false
        let multiplier = max(0.25, min(4.0, 1.0 + event.magnification))
        guard multiplier.isFinite, multiplier > 0 else {
            return
        }
        let nextScale = max(minScaleFactor, min(maxScaleFactor, scaleFactor * multiplier))
        if abs(nextScale - scaleFactor) > 0.0005 {
            scaleFactor = nextScale
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let context = menuContext(for: event) else {
            return nil
        }

        let menu = NSMenu()
        menu.allowsContextMenuPlugIns = false
        if let url = context.linkURL {
            menu.addClosureItem(title: "Open Linked Paper") { [weak self] in
                self?.onLinkActivated?(url)
            }
        }

        if let copyText = context.copyText, !copyText.isEmpty {
            menu.addClosureItem(title: "Copy Text") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(copyText, forType: .string)
            }
        }

        if currentSelection?.string?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            menu.addClosureItem(title: "Highlight Selection") { [weak self] in
                self?.addHighlightFromCurrentSelection()
            }
        }

        if let request = context.removalRequest {
            switch request.kind {
            case .annotation(.highlight):
                menu.addClosureItem(title: "Remove Highlight") { [weak self] in
                    self?.onAnnotationRemovalRequested?(request)
                }
            case .annotation, .signature:
                menu.addClosureItem(title: "Remove Annotation") { [weak self] in
                    self?.onAnnotationRemovalRequested?(request)
                }
            }
        }

        if menu.items.isEmpty == false {
            menu.addItem(.separator())
        }
        menu.addClosureItem(title: "Add Note Here") { [weak self] in
            if let request = context.highlightNoteRequest {
                self?.onHighlightNoteRequested?(request)
            } else {
                self?.addNote(on: context.page, at: context.pagePoint)
            }
        }
        menu.addClosureItem(title: "Add Margin Comment Here") { [weak self] in
            self?.onPageMarginCommentRequested?(context.pageIndex, normalizedPoint(context.pagePoint, on: context.page))
        }
        menu.addClosureItem(title: "OCR This Page") { [weak self] in
            self?.onOCRPageRequested?(context.pageIndex)
        }
        return menu
    }

    private func addHighlightFromCurrentSelection() {
        guard let selection = currentSelection,
              let document,
              !selection.pages.isEmpty else {
            return
        }

        let lineSelections = selection.selectionsByLine()
        let selections = lineSelections.isEmpty ? [selection] : lineSelections
        for lineSelection in selections {
            for page in lineSelection.pages {
                let bounds = lineSelection.bounds(for: page)
                guard bounds.width > 0, bounds.height > 0 else {
                    continue
                }
                let annotation = Annotation(
                    pageIndex: document.index(for: page),
                    kind: .highlight,
                    bounds: normalizedRect(bounds, on: page),
                    contents: lineSelection.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Highlight",
                    colorHex: highlightColorHex
                )
                page.addAnnotation(PDFAnnotationFactory.makeAnnotation(from: annotation, bounds: bounds))
                onAnnotationCreated?(annotation)
            }
        }
    }

    private func addNote(at event: NSEvent) {
        guard let (page, point) = pageAndPoint(for: event),
              document != nil else {
            return
        }
        addNote(on: page, at: point)
    }

    private func addNote(on page: PDFPage, at point: CGPoint) {
        guard let document else {
            return
        }
        let size = CGSize(width: 24, height: 24)
        let bounds = CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height)
        let pdfAnnotation = PDFAnnotation(bounds: bounds, forType: .text, withProperties: nil)
        let annotation = Annotation(
            pageIndex: document.index(for: page),
            kind: .note,
            bounds: normalizedRect(bounds, on: page),
            contents: "Note",
            colorHex: "#F7D154"
        )
        pdfAnnotation.color = NSColor.systemYellow
        pdfAnnotation.contents = "Note"
        PDFAnnotationFactory.markSidecarAnnotation(pdfAnnotation, id: annotation.id)
        page.addAnnotation(pdfAnnotation)

        onAnnotationCreated?(annotation)
    }

    private func addTextBox(at event: NSEvent) {
        guard let (page, point) = pageAndPoint(for: event),
              let document,
              let text = promptForTextBoxText(),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let pageBounds = page.bounds(for: .mediaBox)
        let size = CGSize(
            width: min(220, max(140, pageBounds.width * 0.36)),
            height: 64
        )
        let bounds = CGRect(
            x: min(max(point.x, pageBounds.minX), max(pageBounds.minX, pageBounds.maxX - size.width)),
            y: min(max(point.y - size.height / 2, pageBounds.minY), max(pageBounds.minY, pageBounds.maxY - size.height)),
            width: size.width,
            height: size.height
        )
        let annotation = Annotation(
            pageIndex: document.index(for: page),
            kind: .textBox,
            bounds: normalizedRect(bounds, on: page),
            contents: text.trimmingCharacters(in: .whitespacesAndNewlines),
            colorHex: highlightColorHex
        )
        page.addAnnotation(PDFAnnotationFactory.makeAnnotation(from: annotation, bounds: bounds))
        onAnnotationCreated?(annotation)
    }

    private func promptForTextBoxText() -> String? {
        let alert = NSAlert()
        alert.messageText = "Add Text Box"
        alert.informativeText = "Enter the text to place on the PDF."
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: CGRect(x: 0, y: 0, width: 260, height: 24))
        input.placeholderString = "Text"
        alert.accessoryView = input
        alert.window.initialFirstResponder = input

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }
        return input.stringValue
    }

    private func beginInk(at event: NSEvent) {
        guard let (page, point) = pageAndPoint(for: event) else {
            return
        }
        activeInkPage = page
        activeInkPoints = [point]
        replaceActiveInkAnnotation()
    }

    private func continueInk(at event: NSEvent) {
        guard let activeInkPage,
              let (_, point) = pageAndPoint(for: event, requiring: activeInkPage) else {
            return
        }
        activeInkPoints.append(point)
        replaceActiveInkAnnotation()
    }

    private func finishInk(at event: NSEvent) {
        if let activeInkPage,
           let (_, point) = pageAndPoint(for: event, requiring: activeInkPage) {
            activeInkPoints.append(point)
        }
        replaceActiveInkAnnotation()

        guard let page = activeInkPage,
              let document,
              !activeInkPoints.isEmpty else {
            clearActiveInk()
            return
        }

        let inkSpan = activeInkPoints.reduce(CGRect.null) { partial, point in
            partial.union(CGRect(x: point.x, y: point.y, width: 0.1, height: 0.1))
        }
        if (activeInkPoints.count == 1 || max(inkSpan.width, inkSpan.height) < 1),
           let first = activeInkPoints.first {
            activeInkPoints.append(CGPoint(x: first.x + 1.5, y: first.y + 1.5))
            replaceActiveInkAnnotation()
        }

        let pageBounds = page.bounds(for: .mediaBox)
        let normalizedPoints = activeInkPoints.map { point in
            NormalizedPoint(
                x: max(0, min(1, Double((point.x - pageBounds.minX) / max(pageBounds.width, 1)))),
                y: max(0, min(1, Double((point.y - pageBounds.minY) / max(pageBounds.height, 1))))
            )
        }

        let annotation = Annotation(
            pageIndex: document.index(for: page),
            kind: .ink,
            bounds: normalizedRect(pageBounds, on: page),
            contents: "Ink",
            colorHex: "#D13B3B",
            inkPoints: normalizedPoints
        )
        if let activeInkAnnotation {
            PDFAnnotationFactory.markSidecarAnnotation(activeInkAnnotation, id: annotation.id)
        }
        onAnnotationCreated?(annotation)
        clearActiveInk(keepingAnnotationOnPage: true)
    }

    private func replaceActiveInkAnnotation() {
        guard let page = activeInkPage, !activeInkPoints.isEmpty else {
            return
        }
        if let activeInkAnnotation {
            page.removeAnnotation(activeInkAnnotation)
        }

        let pageBounds = page.bounds(for: .mediaBox)
        let annotation = PDFAnnotation(bounds: pageBounds, forType: .ink, withProperties: nil)
        annotation.color = NSColor.systemRed.withAlphaComponent(0.85)
        annotation.add(inkPath(from: activeInkPoints))
        page.addAnnotation(annotation)
        activeInkAnnotation = annotation
    }

    private func inkPath(from points: [CGPoint]) -> NSBezierPath {
        let path = NSBezierPath()
        path.lineWidth = 2.5
        for (index, point) in points.enumerated() {
            if index == 0 {
                path.move(to: point)
            } else {
                path.line(to: point)
            }
        }
        return path
    }

    private func clearActiveInk(keepingAnnotationOnPage: Bool = false) {
        if !keepingAnnotationOnPage,
           let activeInkPage,
           let activeInkAnnotation {
            activeInkPage.removeAnnotation(activeInkAnnotation)
        }
        activeInkPage = nil
        activeInkPoints = []
        activeInkAnnotation = nil
    }

    private func beginSignature(at event: NSEvent) {
        guard let (page, point) = pageAndPoint(for: event) else {
            return
        }
        signatureStart = (page, point)
    }

    private func finishSignature(at event: NSEvent) {
        guard let signatureStart,
              let document else {
            self.signatureStart = nil
            return
        }
        let endPoint = pageAndPoint(for: event, requiring: signatureStart.page)?.point ?? signatureStart.point
        var bounds = CGRect(
            x: min(signatureStart.point.x, endPoint.x),
            y: min(signatureStart.point.y, endPoint.y),
            width: abs(endPoint.x - signatureStart.point.x),
            height: abs(endPoint.y - signatureStart.point.y)
        )
        if bounds.width < 48 || bounds.height < 18 {
            bounds = CGRect(x: signatureStart.point.x - 60, y: signatureStart.point.y - 18, width: 120, height: 36)
        }

        let signature = Signature(
            pageIndex: document.index(for: signatureStart.page),
            bounds: normalizedRect(bounds, on: signatureStart.page),
            imageData: signatureImageData()
        )
        signatureStart.page.addAnnotation(PDFAnnotationFactory.makeSignatureAnnotation(signature, bounds: bounds))
        onSignatureCreated?(signature)
        self.signatureStart = nil
    }

    private func beginSmartRegionSelectionIfNeeded(at event: NSEvent) -> Bool {
        let startsOnText = eventStartsOnSelectableText(event)
        guard SelectionGesturePolicy.shouldBeginRectangleSelection(
            activeToolID: activeTool?.rawValue,
            startsOnText: startsOnText
        ),
              let (page, point) = pageAndPoint(for: event) else {
            return false
        }

        clearActiveRegionSelection()
        pendingRegionStart = (page, point)
        activeRegionCurrentPoint = point
        return true
    }

    private func continueSmartRegionSelection(at event: NSEvent) {
        guard let start = pendingRegionStart else {
            return
        }
        activeRegionCurrentPoint = pagePoint(for: event, on: start.page)
        replaceActiveRegionAnnotation()
    }

    private func finishSmartRegionSelection(at event: NSEvent) {
        guard let start = pendingRegionStart else {
            clearActiveRegionSelection()
            return
        }

        activeRegionCurrentPoint = pagePoint(for: event, on: start.page)
        let bounds = activeRegionCurrentPoint.flatMap { regionBounds(from: start.point, to: $0, on: start.page) }
        clearActiveRegionSelection()

        guard let bounds,
              bounds.width >= 10,
              bounds.height >= 10,
              let pageIndex = start.page.document?.index(for: start.page) else {
            return
        }

        onRegionSelected?(pageIndex, normalizedRect(bounds, on: start.page))
        setSelectionHover(true)
    }

    private func replaceActiveRegionAnnotation() {
        guard let start = pendingRegionStart,
              let activeRegionCurrentPoint else {
            return
        }

        if let activeRegionAnnotation {
            start.page.removeAnnotation(activeRegionAnnotation)
        }

        guard let bounds = regionBounds(from: start.point, to: activeRegionCurrentPoint, on: start.page),
              bounds.width > 1,
              bounds.height > 1 else {
            activeRegionAnnotation = nil
            return
        }

        let annotation = PDFAnnotation(bounds: bounds, forType: .square, withProperties: nil)
        annotation.color = NSColor.systemBlue.withAlphaComponent(0.72)
        annotation.interiorColor = NSColor.systemBlue.withAlphaComponent(0.10)
        let border = PDFBorder()
        border.lineWidth = 1.4
        annotation.border = border
        start.page.addAnnotation(annotation)
        activeRegionAnnotation = annotation
    }

    private func clearActiveRegionSelection() {
        if let activeRegionAnnotation,
           let page = pendingRegionStart?.page {
            page.removeAnnotation(activeRegionAnnotation)
        }
        pendingRegionStart = nil
        activeRegionCurrentPoint = nil
        activeRegionAnnotation = nil
    }

    private func regionBounds(from start: CGPoint, to end: CGPoint, on page: PDFPage) -> CGRect? {
        let pageBounds = page.bounds(for: .mediaBox)
        let rawBounds = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        let clamped = rawBounds.intersection(pageBounds)
        guard !clamped.isNull,
              clamped.width > 0,
              clamped.height > 0 else {
            return nil
        }
        return clamped
    }

    private func pagePoint(for event: NSEvent, on page: PDFPage) -> CGPoint {
        let viewPoint = convert(event.locationInWindow, from: nil)
        return convert(viewPoint, to: page)
    }

    private func signatureImageData() -> Data {
        let image = NSImage(size: CGSize(width: 240, height: 72))
        image.lockFocus()
        NSColor.clear.setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: image.size)).fill()
        let text = "Signed by \(NSUserName())" as NSString
        text.draw(
            in: CGRect(x: 10, y: 20, width: 220, height: 34),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
        )
        image.unlockFocus()
        return image.tiffRepresentation ?? Data()
    }

    private struct PDFMenuContext {
        var page: PDFPage
        var pageIndex: Int
        var pagePoint: CGPoint
        var linkURL: URL?
        var copyText: String?
        var removalRequest: PDFAnnotationRemovalRequest?
        var highlightNoteRequest: PDFHighlightNoteRequest?
    }

    private func menuContext(for event: NSEvent) -> PDFMenuContext? {
        let viewPoint = convert(event.locationInWindow, from: nil)
        guard let page = page(for: viewPoint, nearest: true),
              let pageIndex = page.document?.index(for: page) else {
            return nil
        }
        let pagePoint = convert(viewPoint, to: page)
        let annotation = page.annotation(at: pagePoint)
        return PDFMenuContext(
            page: page,
            pageIndex: pageIndex,
            pagePoint: pagePoint,
            linkURL: linkURL(from: annotation),
            copyText: copyText(at: pagePoint, on: page),
            removalRequest: annotation.flatMap { removalRequest(for: $0, page: page, pageIndex: pageIndex) },
            highlightNoteRequest: annotation.flatMap { highlightNoteRequest(for: $0, page: page, pageIndex: pageIndex) }
        )
    }

    private func linkURL(from annotation: PDFAnnotation?) -> URL? {
        guard let annotation else {
            return nil
        }
        if let action = annotation.action as? PDFActionURL {
            return action.url
        }
        return annotation.url
    }

    private func copyText(at pagePoint: CGPoint, on page: PDFPage) -> String? {
        if let selected = currentSelection?.string?.trimmingCharacters(in: .whitespacesAndNewlines), !selected.isEmpty {
            return selected
        }
        if let highlighted = highlightedText(at: pagePoint, on: page), !highlighted.isEmpty {
            return highlighted
        }
        return page.selectionForWord(at: pagePoint)?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func removalRequest(for annotation: PDFAnnotation, page: PDFPage, pageIndex: Int) -> PDFAnnotationRemovalRequest? {
        guard linkURL(from: annotation) == nil,
              let kind = removalKind(for: annotation) else {
            return nil
        }
        let normalized = normalizedRect(annotation.bounds, on: page)
        let text = page.selection(for: annotation.bounds)?.string?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? annotation.contents?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
        let externalKey: String?
        if PDFAnnotationFactory.sidecarID(from: annotation) == nil, kind == .annotation(.highlight) {
            externalKey = AnnotationIdentity.key(
                pageIndex: pageIndex,
                kind: .highlight,
                bounds: normalized,
                contents: text
            )
        } else {
            externalKey = nil
        }
        return PDFAnnotationRemovalRequest(
            pageIndex: pageIndex,
            kind: kind,
            bounds: normalized,
            contents: text,
            sidecarID: PDFAnnotationFactory.sidecarID(from: annotation),
            externalPDFAnnotationKey: externalKey
        )
    }

    private func removalKind(for annotation: PDFAnnotation) -> PDFAnnotationRemovalKind? {
        guard let type = annotation.type else {
            return nil
        }
        if type == PDFAnnotationSubtype.highlight.rawValue || type.localizedCaseInsensitiveContains("highlight") {
            return .annotation(.highlight)
        }
        if type == PDFAnnotationSubtype.text.rawValue {
            return .annotation(.note)
        }
        if type == PDFAnnotationSubtype.ink.rawValue {
            return .annotation(.ink)
        }
        if type == PDFAnnotationSubtype.square.rawValue {
            return .annotation(.rectangle)
        }
        if type == PDFAnnotationSubtype.freeText.rawValue {
            if annotation.contents == "Signed" {
                return .signature
            }
            return .annotation(.textBox)
        }
        return nil
    }

    private func highlightNoteRequest(for annotation: PDFAnnotation, page: PDFPage, pageIndex: Int) -> PDFHighlightNoteRequest? {
        guard removalKind(for: annotation) == .annotation(.highlight) else {
            return nil
        }
        let text = page.selection(for: annotation.bounds)?.string?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? annotation.contents?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
        return PDFHighlightNoteRequest(
            pageIndex: pageIndex,
            bounds: normalizedRect(annotation.bounds, on: page),
            contents: text,
            colorHex: colorHex(from: annotation.color)
        )
    }

    private func colorHex(from color: NSColor) -> String {
        guard let rgb = color.usingColorSpace(.sRGB) else {
            return CommentThread.attachedColorHex
        }
        let red = Int((max(0, min(1, rgb.redComponent)) * 255).rounded())
        let green = Int((max(0, min(1, rgb.greenComponent)) * 255).rounded())
        let blue = Int((max(0, min(1, rgb.blueComponent)) * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    private func pageAndPoint(for event: NSEvent, requiring requiredPage: PDFPage? = nil) -> (page: PDFPage, point: CGPoint)? {
        let viewPoint = convert(event.locationInWindow, from: nil)
        guard let page = page(for: viewPoint, nearest: false) else {
            return nil
        }
        if let requiredPage, page !== requiredPage {
            return nil
        }
        return (page, convert(viewPoint, to: page))
    }

    private func eventStartsOnSelectableText(_ event: NSEvent) -> Bool {
        if isEventInsideCurrentSelection(event) {
            return true
        }
        guard let (page, point) = pageAndPoint(for: event) else {
            return false
        }
        if let annotation = page.annotation(at: point),
           linkURL(from: annotation) != nil {
            return true
        }
        if highlightedAnnotation(at: point, on: page) != nil {
            return true
        }
        return wordTextNear(point, on: page) != nil
    }

    private func wordTextNear(_ point: CGPoint, on page: PDFPage) -> String? {
        let offsets = [
            CGPoint.zero,
            CGPoint(x: -3, y: 0),
            CGPoint(x: 3, y: 0),
            CGPoint(x: 0, y: -3),
            CGPoint(x: 0, y: 3),
            CGPoint(x: -3, y: -3),
            CGPoint(x: 3, y: 3)
        ]
        let pageBounds = page.bounds(for: .mediaBox)
        for offset in offsets {
            let candidate = CGPoint(x: point.x + offset.x, y: point.y + offset.y)
            guard pageBounds.contains(candidate),
                  let text = page.selectionForWord(at: candidate)?.string?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else {
                continue
            }
            return text
        }
        return nil
    }

    private func updateSelectionHover(with event: NSEvent) {
        updateSelectionHover(at: convert(event.locationInWindow, from: nil))
    }

    func refreshSelectionHoverFromCurrentPointer() {
        guard let window else {
            setSelectionHover(false)
            return
        }
        updateSelectionHover(at: convert(window.mouseLocationOutsideOfEventStream, from: nil))
    }

    private func updateSelectionHover(at viewPoint: CGPoint) {
        guard let document else {
            setSelectionHover(false)
            return
        }

        guard let page = page(for: viewPoint, nearest: true),
              let pageIndex = page.document?.index(for: page) else {
            setSelectionHover(false)
            return
        }

        let pagePoint = convert(viewPoint, to: page)
        if let selection = currentSelection, selection.pages.contains(page) {
            let isInsideSelection = selection.pages.contains { selectedPage in
                guard document.index(for: selectedPage) == pageIndex else {
                    return false
                }
                return selection.bounds(for: selectedPage).insetBy(dx: -3, dy: -3).contains(pagePoint)
            }
            if isInsideSelection {
                setSelectionHover(true)
                return
            }
        }

        setSelectionHover(false)
    }

    private func setSelectionHover(_ isHovering: Bool) {
        if isHoveringSelection == isHovering, isHovering {
            return
        }
        isHoveringSelection = isHovering
        onSelectionHover?(isHovering)
    }

    private func isEventInsideCurrentSelection(_ event: NSEvent) -> Bool {
        guard let selection = currentSelection,
              let document,
              !selection.pages.isEmpty else {
            return false
        }

        let viewPoint = convert(event.locationInWindow, from: nil)
        guard let page = page(for: viewPoint, nearest: true),
              selection.pages.contains(page) else {
            return false
        }

        let pagePoint = convert(viewPoint, to: page)
        let pageIndex = document.index(for: page)
        return selection.pages.contains { selectedPage in
            document.index(for: selectedPage) == pageIndex
                && selection.bounds(for: selectedPage).insetBy(dx: -3, dy: -3).contains(pagePoint)
        }
    }

    private func handleLinkClick(_ event: NSEvent) -> Bool {
        let viewPoint = convert(event.locationInWindow, from: nil)
        guard let page = page(for: viewPoint, nearest: true) else {
            return false
        }
        let pagePoint = convert(viewPoint, to: page)
        guard let annotation = page.annotation(at: pagePoint) else {
            return false
        }
        if let action = annotation.action as? PDFActionURL,
           let url = action.url {
            onLinkActivated?(url)
            return true
        }
        if let url = annotation.url {
            onLinkActivated?(url)
            return true
        }
        return false
    }

    private func handleHighlightedTextClick(_ event: NSEvent) -> Bool {
        let viewPoint = convert(event.locationInWindow, from: nil)
        guard let page = page(for: viewPoint, nearest: true),
              let pageIndex = page.document?.index(for: page) else {
            return false
        }

        let pagePoint = convert(viewPoint, to: page)
        guard let highlightedText = highlightedText(at: pagePoint, on: page),
              !highlightedText.isEmpty else {
            return false
        }

        let highlightedBounds = highlightedAnnotationBounds(at: pagePoint, on: page)
        onHighlightedTextHover?(
            highlightedText,
            pageIndex,
            CGPoint(
                x: min(bounds.maxX - 180, max(16, viewPoint.x + 12)),
                y: min(bounds.maxY - 40, max(16, bounds.height - viewPoint.y - 12))
            ),
            highlightedBounds.flatMap { normalizedRect($0, on: page) }
        )
        setSelectionHover(true)
        return true
    }

    private func highlightedText(at pagePoint: CGPoint, on page: PDFPage) -> String? {
        guard let annotation = highlightedAnnotation(at: pagePoint, on: page) else {
            return nil
        }

        if let selectedText = page.selection(for: annotation.bounds)?
            .string?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !selectedText.isEmpty {
            return selectedText
        }

        return annotation.contents?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func highlightedAnnotationBounds(at pagePoint: CGPoint, on page: PDFPage) -> CGRect? {
        highlightedAnnotation(at: pagePoint, on: page)?.bounds
    }

    private func highlightedAnnotation(at pagePoint: CGPoint, on page: PDFPage) -> PDFAnnotation? {
        page.annotations.reversed().first { annotation in
            isHighlight(annotation) && annotation.bounds.insetBy(dx: -3, dy: -3).contains(pagePoint)
        }
    }

    private func isHighlight(_ annotation: PDFAnnotation) -> Bool {
        guard let type = annotation.type else {
            return false
        }
        return type == PDFAnnotationSubtype.highlight.rawValue
            || type.localizedCaseInsensitiveContains("highlight")
    }
}

private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func run() {
        handler()
    }
}

private extension NSMenu {
    func addClosureItem(title: String, handler: @escaping () -> Void) {
        addItem(ClosureMenuItem(title: title, handler: handler))
    }
}

private extension NSColor {
    convenience init?(hex: String) {
        var normalized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasPrefix("#") {
            normalized.removeFirst()
        }
        guard normalized.count == 6,
              let value = Int(normalized, radix: 16) else {
            return nil
        }
        self.init(
            calibratedRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

private func normalizedRect(_ rect: CGRect, on page: PDFPage) -> NormalizedRect {
    let bounds = page.bounds(for: .mediaBox)
    return NormalizedRect(
        x: max(0, min(1, (rect.minX - bounds.minX) / max(bounds.width, 1))),
        y: max(0, min(1, (rect.minY - bounds.minY) / max(bounds.height, 1))),
        width: max(0, min(1, rect.width / max(bounds.width, 1))),
        height: max(0, min(1, rect.height / max(bounds.height, 1)))
    )
}

private func normalizedPoint(_ point: CGPoint, on page: PDFPage) -> NormalizedPoint {
    let bounds = page.bounds(for: .mediaBox)
    return NormalizedPoint(
        x: max(0, min(1, (point.x - bounds.minX) / max(bounds.width, 1))),
        y: max(0, min(1, (point.y - bounds.minY) / max(bounds.height, 1)))
    )
}
