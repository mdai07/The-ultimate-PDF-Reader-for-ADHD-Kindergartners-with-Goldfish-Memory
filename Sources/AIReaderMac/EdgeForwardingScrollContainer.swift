import AppKit
import SwiftUI

struct EdgeForwardingScrollContainer<Content: View>: NSViewRepresentable {
    let maxHeight: CGFloat
    let content: Content

    init(maxHeight: CGFloat, @ViewBuilder content: () -> Content) {
        self.maxHeight = maxHeight
        self.content = content()
    }

    func makeNSView(context: Context) -> EdgeForwardingScrollView {
        let scrollView = EdgeForwardingScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.verticalScrollElasticity = .none
        scrollView.horizontalScrollElasticity = .none
        scrollView.maxIntrinsicHeight = maxHeight

        let hostingView = NSHostingView(rootView: AnyView(content))
        scrollView.hostingView = hostingView
        scrollView.documentView = hostingView
        return scrollView
    }

    func updateNSView(_ scrollView: EdgeForwardingScrollView, context: Context) {
        scrollView.maxIntrinsicHeight = maxHeight
        scrollView.hostingView?.rootView = AnyView(content)
        scrollView.updateDocumentFrame()
        scrollView.invalidateIntrinsicContentSize()
        DispatchQueue.main.async {
            scrollView.updateDocumentFrame()
            scrollView.invalidateIntrinsicContentSize()
        }
    }
}

final class EdgeForwardingScrollView: NSScrollView {
    var maxIntrinsicHeight: CGFloat = 120
    var hostingView: NSHostingView<AnyView>?

    override var intrinsicContentSize: NSSize {
        guard let hostingView else {
            return NSSize(width: NSView.noIntrinsicMetric, height: maxIntrinsicHeight)
        }

        updateDocumentFrame()
        let height = min(max(hostingView.fittingSize.height, 28), maxIntrinsicHeight)
        return NSSize(width: NSView.noIntrinsicMetric, height: height)
    }

    override func layout() {
        super.layout()
        updateDocumentFrame()
    }

    func updateDocumentFrame() {
        guard let hostingView else {
            return
        }

        let width = max(contentSize.width, 1)
        hostingView.frame.size.width = width
        hostingView.layoutSubtreeIfNeeded()
        let contentHeight = max(hostingView.fittingSize.height, contentSize.height)
        hostingView.frame = CGRect(x: 0, y: 0, width: width, height: contentHeight)
    }

    override func scrollWheel(with event: NSEvent) {
        let before = contentView.bounds.origin.y
        super.scrollWheel(with: event)
        layoutSubtreeIfNeeded()
        let after = contentView.bounds.origin.y

        if abs(after - before) < 0.5, let parentScrollView {
            parentScrollView.scrollWheel(with: event)
        }
    }

    private var parentScrollView: NSScrollView? {
        var current = superview
        while let view = current {
            if let scrollView = view as? NSScrollView, scrollView !== self {
                return scrollView
            }
            current = view.superview
        }
        return nil
    }
}
