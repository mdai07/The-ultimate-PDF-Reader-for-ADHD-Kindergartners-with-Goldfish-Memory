import SwiftUI

@main
struct UprakigoApp: App {
    @StateObject private var state = ReaderAppState()
    @State private var openedInitialURL = false

    var body: some Scene {
        WindowGroup("uprakigo") {
            MainWindowView()
                .environmentObject(state)
                .frame(minWidth: 900, minHeight: 620)
                .onAppear {
                    guard !openedInitialURL else {
                        return
                    }
                    openedInitialURL = true
                    for url in Self.initialPDFURLsFromArguments() {
                        state.open(url: url)
                    }
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
