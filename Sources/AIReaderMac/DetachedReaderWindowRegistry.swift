import AppKit
import SwiftUI

@MainActor
final class DetachedReaderWindowRegistry {
    static let shared = DetachedReaderWindowRegistry()

    private var windows: [NSWindow] = []

    private init() {}

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

        let rootView = MainWindowView()
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
        window.center()
        window.makeKeyAndOrderFront(nil)

        windows.append(window)
    }
}
