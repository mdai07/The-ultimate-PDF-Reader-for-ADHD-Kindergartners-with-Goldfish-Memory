import AppKit
import SwiftUI

@main
struct UprakigoApp: App {
    @NSApplicationDelegateAdaptor(UprakigoAppDelegate.self) private var appDelegate
    @StateObject private var state = ReaderAppState()
    @State private var openedInitialURL = false

    var body: some Scene {
        Window("uprakigo", id: "main") {
            MainWindowView()
                .environmentObject(state)
                .frame(minWidth: 900, minHeight: 620)
                .onAppear {
                    appDelegate.installOpenPDFURLsHandler { urls in
                        for url in urls {
                            state.open(url: url)
                        }
                    }
                    guard !openedInitialURL else {
                        return
                    }
                    openedInitialURL = true
                    for url in Self.initialPDFURLsFromArguments() {
                        state.open(url: url)
                    }
                }
                .onOpenURL { url in
                    guard url.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame else {
                        return
                    }
                    state.open(url: url)
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open PDF...") {
                    state.presentOpenPanel()
                }
                .keyboardShortcut("o")

                Button("Save") {
                    state.saveCurrentPDFWithHiddenMetadata()
                }
                .keyboardShortcut("s")

                Button("Reveal Current PDF in Finder") {
                    state.revealCurrentPDFInFinder()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(state.currentPDFURL == nil)

                Button("Export Annotated PDF...") {
                    state.presentExportPanel()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .sidebar) {
                Button(state.isLeftSidebarVisible ? "Hide Left Sidebar" : "Show Left Sidebar") {
                    state.toggleLeftSidebar()
                }
                .keyboardShortcut("l", modifiers: [.command, .control])

                Button(state.isAISidebarVisible ? "Hide AI Sidebar" : "Show AI Sidebar") {
                    state.toggleAISidebar()
                }
                .keyboardShortcut("r", modifiers: [.command, .control])
            }
        }

        Settings {
            UprakigoPreferencesView()
                .environmentObject(state)
        }
    }

    private static func initialPDFURLsFromArguments() -> [URL] {
        CommandLine.arguments
            .dropFirst()
            .filter { $0.lowercased().hasSuffix(".pdf") }
            .map { URL(fileURLWithPath: $0) }
    }
}

@MainActor
final class UprakigoAppDelegate: NSObject, NSApplicationDelegate {
    private var openPDFURLsHandler: (([URL]) -> Void)?
    private var pendingOpenURLs: [URL] = []

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        return enqueueOpenPDFURLs([URL(fileURLWithPath: filename)])
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let didAcceptPDFs = enqueueOpenPDFURLs(filenames.map { URL(fileURLWithPath: $0) })
        sender.reply(toOpenOrPrint: didAcceptPDFs ? .success : .failure)
    }

    func installOpenPDFURLsHandler(_ handler: @escaping ([URL]) -> Void) {
        openPDFURLsHandler = handler
        guard !pendingOpenURLs.isEmpty else {
            return
        }
        let urls = pendingOpenURLs
        pendingOpenURLs.removeAll()
        handler(urls)
    }

    @discardableResult
    private func enqueueOpenPDFURLs(_ urls: [URL]) -> Bool {
        let pdfURLs = urls.filter { $0.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame }
        guard !pdfURLs.isEmpty else {
            return false
        }

        if let openPDFURLsHandler {
            openPDFURLsHandler(pdfURLs)
        } else {
            pendingOpenURLs.append(contentsOf: pdfURLs)
        }
        return true
    }
}
