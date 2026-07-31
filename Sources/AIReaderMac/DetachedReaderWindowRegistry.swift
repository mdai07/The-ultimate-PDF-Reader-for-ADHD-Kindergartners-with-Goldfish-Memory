import AppKit
import SwiftUI

enum ReaderWindowLayoutPersistence {
    static let mainWindowFrame = "uprakigo.main-window"
    static let detachedWindowFrame = "uprakigo.detached-window"
    static let sourceListSplit = "uprakigo.source-list-split"
    static let aiSidebarSplit = "uprakigo.ai-sidebar-split"
    static let commentRailSplit = "uprakigo.comment-rail-split"
    static let documentComparisonSplit = "uprakigo.document-comparison-split"
}

@MainActor
final class DetachedReaderWindowRegistry {
    static let shared = DetachedReaderWindowRegistry()

    private final class WindowEntry {
        weak var state: ReaderAppState?
        weak var window: NSWindow?
        var retainedWindow: NSWindow?

        init(state: ReaderAppState, window: NSWindow, retainWindow: Bool) {
            self.state = state
            self.window = window
            retainedWindow = retainWindow ? window : nil
        }
    }

    private var entries: [WindowEntry] = []
    private var windowCloseObserver: NSObjectProtocol?

    private init() {
        windowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else {
                return
            }
            Task { @MainActor in
                self?.entries.removeAll { $0.window === window }
            }
        }
    }

    func register(state: ReaderAppState, window: NSWindow, retainWindow: Bool = false) {
        removeReleasedEntries()
        if let entry = entries.first(where: { $0.state === state }) {
            entry.window = window
            if retainWindow {
                entry.retainedWindow = window
            }
            return
        }
        entries.append(WindowEntry(state: state, window: window, retainWindow: retainWindow))
    }

    @discardableResult
    func focusDocument(at url: URL, excluding requestingState: ReaderAppState) -> Bool {
        removeReleasedEntries()
        for entry in entries {
            guard let state = entry.state,
                  state !== requestingState,
                  state.selectOpenTab(for: url) else {
                continue
            }
            let window = entry.window
            DispatchQueue.main.async {
                window?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            return true
        }
        return false
    }

    func open(url: URL) {
        let state = ReaderAppState()
        state.open(url: url)
        openWindow(state: state, title: url.lastPathComponent)
    }

    func open(tab: ReaderDocumentTab) {
        let state = ReaderAppState()
        state.installDetachedTab(tab)
        openWindow(state: state, title: tab.pdfURL.lastPathComponent)
    }

    private func openWindow(state: ReaderAppState, title: String) {

        let rootView = MainWindowView(
            windowAutosaveName: ReaderWindowLayoutPersistence.detachedWindowFrame
        )
            .environmentObject(state)
            .frame(minWidth: 900, minHeight: 620)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1120, height: 780),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "uprakigo - \(title)"
        window.contentViewController = hostingController
        if !window.setFrameUsingName(ReaderWindowLayoutPersistence.detachedWindowFrame) {
            window.center()
        }
        window.setFrameAutosaveName(ReaderWindowLayoutPersistence.detachedWindowFrame)
        window.makeKeyAndOrderFront(nil)
        register(state: state, window: window, retainWindow: true)
    }

    private func removeReleasedEntries() {
        entries.removeAll { $0.state == nil || $0.window == nil }
    }
}

struct ReaderWindowRegistrationView: NSViewRepresentable {
    let state: ReaderAppState
    let frameAutosaveName: String

    func makeNSView(context: Context) -> ReaderWindowRegistrationNSView {
        let view = ReaderWindowRegistrationNSView()
        view.state = state
        view.frameAutosaveName = frameAutosaveName
        return view
    }

    func updateNSView(_ view: ReaderWindowRegistrationNSView, context: Context) {
        view.state = state
        view.frameAutosaveName = frameAutosaveName
        view.registerWindowIfAvailable()
    }
}

final class ReaderWindowRegistrationNSView: NSView {
    weak var state: ReaderAppState?
    var frameAutosaveName = ""
    private weak var configuredWindow: NSWindow?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        registerWindowIfAvailable()
    }

    func registerWindowIfAvailable() {
        guard let state, let window else {
            return
        }
        if configuredWindow !== window {
            configuredWindow = window
            if !frameAutosaveName.isEmpty {
                window.setFrameUsingName(frameAutosaveName)
                window.setFrameAutosaveName(frameAutosaveName)
            }
        }
        DetachedReaderWindowRegistry.shared.register(state: state, window: window)
    }
}

struct SplitViewAutosaveConfigurator: NSViewRepresentable {
    let name: String
    let preservedPane: SplitViewPreservedPane

    func makeNSView(context: Context) -> SplitViewAutosaveNSView {
        let view = SplitViewAutosaveNSView(frame: .zero)
        view.autosaveName = name
        view.preservedPane = preservedPane
        return view
    }

    func updateNSView(_ view: SplitViewAutosaveNSView, context: Context) {
        view.autosaveName = name
        view.preservedPane = preservedPane
        view.configureSplitViewIfAvailable()
    }

    static func dismantleNSView(_ view: SplitViewAutosaveNSView, coordinator: Void) {
        view.detachFromSplitView()
    }
}

enum SplitViewPreservedPane {
    case leading
    case trailing
}

final class SplitViewAutosaveNSView: NSView {
    var autosaveName = "" {
        didSet { configureSplitViewIfAvailable() }
    }
    var preservedPane = SplitViewPreservedPane.leading {
        didSet { configureSplitViewIfAvailable() }
    }
    private weak var configuredSplitView: NSSplitView?
    private var resizeObserver: NSObjectProtocol?
    private var isRestoringPaneSize = false
    private var preservedPaneSize: CGFloat?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureSplitViewIfAvailable()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        configureSplitViewIfAvailable()
    }

    func configureSplitViewIfAvailable() {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.autosaveName.isEmpty else {
                return
            }
            var descendant: NSView = self
            var ancestor = self.superview
            while let view = ancestor {
                if let splitView = view as? NSSplitView,
                   self.isRequestedPane(descendant, in: splitView),
                   self.isMeaningfulPane(descendant, in: splitView) {
                    if self.configuredSplitView !== splitView {
                        self.detachFromSplitView()
                        splitView.autosaveName = self.autosaveName
                        self.configuredSplitView = splitView
                        self.loadPreservedPaneSize()
                        self.isRestoringPaneSize = true
                        self.resizeObserver = NotificationCenter.default.addObserver(
                            forName: NSSplitView.didResizeSubviewsNotification,
                            object: splitView,
                            queue: .main
                        ) { [weak self, weak splitView] _ in
                            guard let self, let splitView else {
                                return
                            }
                            let isDraggingDivider = NSEvent.pressedMouseButtons & 1 == 1
                            if !self.isRestoringPaneSize, isDraggingDivider {
                                self.savePreservedPaneSize(in: splitView)
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self, weak splitView] in
                            guard let self,
                                  let splitView,
                                  self.configuredSplitView === splitView else {
                                return
                            }
                            self.restorePreservedPaneSize(in: splitView)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self, weak splitView] in
                                guard let self,
                                      let splitView,
                                      self.configuredSplitView === splitView else {
                                    return
                                }
                                self.restorePreservedPaneSize(in: splitView)
                                self.isRestoringPaneSize = false
                            }
                        }
                    } else if splitView.autosaveName != self.autosaveName {
                        splitView.autosaveName = self.autosaveName
                    }
                    return
                }
                descendant = view
                ancestor = view.superview
            }
        }
    }

    func detachFromSplitView() {
        if let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
        }
        resizeObserver = nil
        configuredSplitView = nil
        isRestoringPaneSize = false
    }

    private var paneSizeDefaultsKey: String {
        "\(autosaveName).preserved-pane-size"
    }

    private func loadPreservedPaneSize() {
        guard preservedPaneSize == nil,
              UserDefaults.standard.object(forKey: paneSizeDefaultsKey) != nil else {
            return
        }
        let savedSize = UserDefaults.standard.double(forKey: paneSizeDefaultsKey)
        if savedSize > 40 {
            preservedPaneSize = CGFloat(savedSize)
        }
    }

    private func meaningfulPanes(in splitView: NSSplitView) -> [NSView] {
        splitView.subviews
            .filter { pane in
                let size = splitView.isVertical ? pane.frame.width : pane.frame.height
                return size > 40
            }
            .sorted { lhs, rhs in
                if splitView.isVertical {
                    return lhs.frame.minX < rhs.frame.minX
                }
                return lhs.frame.minY < rhs.frame.minY
            }
    }

    private func isRequestedPane(_ pane: NSView, in splitView: NSSplitView) -> Bool {
        let panes = meaningfulPanes(in: splitView)
        switch preservedPane {
        case .leading:
            return panes.first === pane
        case .trailing:
            return panes.last === pane
        }
    }

    private func isMeaningfulPane(_ pane: NSView, in splitView: NSSplitView) -> Bool {
        let paneSize = splitView.isVertical ? pane.frame.width : pane.frame.height
        let totalSize = splitView.isVertical ? splitView.bounds.width : splitView.bounds.height
        return paneSize > 40 && totalSize - paneSize - splitView.dividerThickness > 40
    }

    private func restorePreservedPaneSize(in splitView: NSSplitView) {
        let panes = meaningfulPanes(in: splitView)
        guard panes.count >= 2,
              let savedSize = preservedPaneSize,
              savedSize > 40 else {
            savePreservedPaneSize(in: splitView)
            return
        }

        let totalSize = splitView.isVertical ? splitView.bounds.width : splitView.bounds.height
        let dividerPosition: CGFloat
        switch preservedPane {
        case .leading:
            dividerPosition = savedSize
        case .trailing:
            dividerPosition = totalSize - savedSize - splitView.dividerThickness
        }
        let pane = preservedPane == .leading ? panes[0] : panes[panes.count - 1]
        guard let paneIndex = splitView.subviews.firstIndex(where: { $0 === pane }) else {
            return
        }
        let dividerIndex = preservedPane == .leading ? paneIndex : paneIndex - 1
        guard dividerIndex >= 0, dividerIndex < splitView.subviews.count - 1 else {
            return
        }
        splitView.setPosition(
            max(0, min(dividerPosition, totalSize - splitView.dividerThickness)),
            ofDividerAt: dividerIndex
        )
    }

    private func savePreservedPaneSize(in splitView: NSSplitView) {
        let panes = meaningfulPanes(in: splitView)
        guard panes.count >= 2 else {
            return
        }
        let pane = preservedPane == .leading
            ? panes[0]
            : panes[panes.count - 1]
        let size = splitView.isVertical ? pane.frame.width : pane.frame.height
        guard size > 40 else {
            return
        }
        preservedPaneSize = size
        UserDefaults.standard.set(Double(size), forKey: paneSizeDefaultsKey)
    }
}
