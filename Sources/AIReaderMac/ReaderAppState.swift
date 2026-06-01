import AppKit
import CryptoKit
import PDFKit
import PaperReaderCore
import SwiftUI
import UniformTypeIdentifiers

enum ReaderTool: String, CaseIterable, Identifiable, Hashable {
    case magicWand
    case highlight
    case note
    case textBox
    case ink
    case signature
    case region
    case outsideComment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .magicWand: return "AI Wand"
        case .highlight: return "Highlight"
        case .note: return "Note"
        case .textBox: return "Text Box"
        case .ink: return "Ink"
        case .signature: return "Sign"
        case .region: return "Figure/Table"
        case .outsideComment: return "Margin Comment"
        }
    }

    var symbolName: String {
        switch self {
        case .magicWand: return "wand.and.stars"
        case .highlight: return "highlighter"
        case .note: return "note.text"
        case .textBox: return "character.textbox"
        case .ink: return "scribble"
        case .signature: return "signature"
        case .region: return "rectangle.dashed"
        case .outsideComment: return "text.bubble"
        }
    }
}

extension ReaderTool {
    var statusName: String {
        switch self {
        case .magicWand: return "AI wand"
        case .highlight: return "highlight"
        case .note: return "note"
        case .textBox: return "text box"
        case .ink: return "ink"
        case .signature: return "signature"
        case .region: return "figure/table selection"
        case .outsideComment: return "margin comment"
        }
    }
}

extension SelectionShortcutAction {
    var userDefaultsKey: String {
        switch self {
        case .inlineSuggestions:
            return "SelectionShortcutInlineSuggestions"
        case .marginComment:
            return "SelectionShortcutMarginComment"
        case .highlight:
            return "SelectionShortcutHighlight"
        }
    }
}

enum ReaderSelectionContext: Equatable {
    case text(String, pageIndex: Int, bounds: NormalizedRect?)
    case region(RegionSelection)

    var title: String {
        switch self {
        case .text(_, let pageIndex, _):
            return "Text on page \(pageIndex + 1)"
        case .region(let region):
            return "\(region.kind.rawValue.capitalized) on page \(region.pageIndex + 1)"
        }
    }

    var detail: String {
        switch self {
        case .text(let text, _, _):
            return text
        case .region(let region):
            return [region.label, region.nearbyText, region.imageDigest]
                .compactMap { $0 }
                .joined(separator: "\n")
        }
    }

    var pageIndex: Int {
        switch self {
        case .text(_, let pageIndex, _):
            return pageIndex
        case .region(let region):
            return region.pageIndex
        }
    }

    var sourceBounds: NormalizedRect? {
        switch self {
        case .text(_, _, let bounds):
            return bounds
        case .region(let region):
            return region.bounds
        }
    }
}

struct PaperOutlineItem: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var pageIndex: Int
    var level: Int
}

struct InlineSuggestion: Identifiable, Equatable {
    var id = UUID()
    var question: String
    var answer: String
    var isLoading: Bool = false
}

struct LingeringInlineSuggestionGroup: Identifiable, Equatable {
    var id = UUID()
    var context: ReaderSelectionContext
    var suggestions: [InlineSuggestion]
    var sourceYFraction: Double
    var retention: TemporarySuggestionTiming.State
    var colorHex = CommentThread.attachedColorHex
    var createdAt = Date()
}

struct ReaderDocumentTab: Identifiable {
    var id = UUID()
    var pdfURL: URL
    var pdfDocument: PDFDocument
    var session: DocumentSession
    var currentPageIndex: Int
    var pdfScaleFactor: Double
    var pdfAutoScales: Bool
    var paperOutline: [PaperOutlineItem]
    var paperMemory: String
    var chatMessages: [ChatMessage] = []
    var chatInput: String = ""
    var includedContextTabIDs: Set<UUID> = []
    var isThinking = false

    var title: String {
        session.title
    }
}

struct DeepSeekKeyState {
    var key: String
    var isEnvironmentBacked: Bool
}

private enum AIModelPurpose {
    case sidebarChat
    case inlineSuggestion
}

private enum AIProviderResolution {
    case hosted(any AIProvider)
    case missingCredential(String)
    case localCLI(String)
}

@MainActor
final class ReaderAppState: ObservableObject {
    private static let deepSeekProAgentID = "deepseek-deepseek-v4-pro"
    private static let deepSeekFlashAgentID = "deepseek-deepseek-v4-flash"
    private static let geminiChatAgentID = "gemini-chat"
    private static let geminiFastAgentID = "gemini-fast"
    private static let equationReferenceURLScheme = "aireader-equation"

    @Published var pdfDocument: PDFDocument?
    @Published var session: DocumentSession?
    @Published var currentPDFURL: URL?
    @Published var openTabs: [ReaderDocumentTab] = []
    @Published var activeTabID: UUID?
    @Published var splitTabID: UUID?
    @Published var isSplitViewEnabled = false
    @Published var currentPageIndex = 0
    @Published var pdfScaleFactor: Double = 1.0
    @Published var pdfAutoScales = true
    @Published var recentFiles: [URL] = []
    @Published private(set) var selectedTool: ReaderTool?
    @Published private(set) var toolActivationMode: ToolActivationMode?
    @Published var selectionContext: ReaderSelectionContext?
    @Published var quickSuggestions: [InlineSuggestion] = []
    @Published var isQuickSuggestionVisible = false
    @Published var quickSuggestionAnchor: CGPoint?
    @Published private var selectionImageAttachment: AIImageAttachment?
    @Published var lingeringInlineSuggestionGroups: [LingeringInlineSuggestionGroup] = []
    @Published var pdfViewportSize: CGSize = .zero
    @Published var pdfViewportSnapshot = PDFViewportSnapshot(viewSize: .zero, pageFrames: [:])
    @Published var inlineQuestionInput = ""
    @Published var paperOutline: [PaperOutlineItem] = []
    @Published var requestedPageIndex: Int?
    @Published var paperMemory = ""
    @Published var chatInput = ""
    @Published var findQuery = ""
    @Published private(set) var findResults: [SearchResult] = []
    @Published private(set) var findResultIndex: Int?
    @Published var findFocusToken = UUID()
    @Published var isJumpCommandVisible = false
    @Published var jumpCommandInput = ""
    @Published var jumpCommandFocusToken = UUID()
    @Published var isThinking = false
    @Published var includedContextTabIDs: Set<UUID> = []
    @Published var statusMessage = "Open an academic PDF to begin."
    @Published var pendingAnchorCommentID: UUID?
    @Published var selectedAgentID = UserDefaults.standard.string(forKey: "SidebarAgentID") ?? ReaderAppState.deepSeekProAgentID {
        didSet {
            UserDefaults.standard.set(selectedAgentID, forKey: "SidebarAgentID")
        }
    }
    @Published var inlineAgentID = UserDefaults.standard.string(forKey: "InlineAgentID") ?? ReaderAppState.deepSeekFlashAgentID {
        didSet {
            UserDefaults.standard.set(inlineAgentID, forKey: "InlineAgentID")
        }
    }
    @Published var customDeepSeekAPIKey = ""
    @Published var customDeepSeekChatModel = UserDefaults.standard.string(forKey: "DeepSeekChatModel") ?? ""
    @Published var customDeepSeekFastModel = UserDefaults.standard.string(forKey: "DeepSeekFastModel") ?? ""
    @Published var customGeminiAPIKey = ""
    @Published var customGeminiChatModel = UserDefaults.standard.string(forKey: "GeminiChatModel") ?? ""
    @Published var customGeminiFastModel = UserDefaults.standard.string(forKey: "GeminiFastModel") ?? ""
    @Published var deepSeekAPIKey = ""
    @Published var deepSeekChatModel = DeepSeekConfigurationResolver.defaultChatModel
    @Published var deepSeekFastModel = DeepSeekConfigurationResolver.defaultFastModel
    @Published var isDeepSeekKeyFromEnvironment = false
    @Published var geminiAPIKey = ""
    @Published var geminiChatModel = GeminiConfigurationResolver.defaultChatModel
    @Published var geminiFastModel = GeminiConfigurationResolver.defaultFastModel
    @Published var isGeminiKeyFromEnvironment = false
    @Published var chatThinkingEffort = ReaderAppState.storedThinkingEffort(
        forKey: "ChatThinkingEffort",
        defaultValue: .high
    ) {
        didSet { UserDefaults.standard.set(chatThinkingEffort.rawValue, forKey: "ChatThinkingEffort") }
    }
    @Published var inlineThinkingEffort = ReaderAppState.storedThinkingEffort(
        forKey: "InlineThinkingEffort",
        defaultValue: .low
    ) {
        didSet { UserDefaults.standard.set(inlineThinkingEffort.rawValue, forKey: "InlineThinkingEffort") }
    }
    @Published var codexFastModeEnabled = UserDefaults.standard.bool(forKey: "CodexFastModeEnabled") {
        didSet { UserDefaults.standard.set(codexFastModeEnabled, forKey: "CodexFastModeEnabled") }
    }
    @Published var codexModelName = UserDefaults.standard.string(forKey: "CodexModelName") ?? "" {
        didSet { UserDefaults.standard.set(codexModelName, forKey: "CodexModelName") }
    }
    @Published var codexInlineModelName = UserDefaults.standard.string(forKey: "CodexInlineModelName") ?? "" {
        didSet { UserDefaults.standard.set(codexInlineModelName, forKey: "CodexInlineModelName") }
    }
    @Published var claudeModelName = UserDefaults.standard.string(forKey: "ClaudeModelName") ?? "" {
        didSet { UserDefaults.standard.set(claudeModelName, forKey: "ClaudeModelName") }
    }
    @Published var sidebarSystemPrompt = ReaderAppState.storedPromptOverride(for: .sidebarSystem) {
        didSet { Self.persistPromptTemplate(sidebarSystemPrompt, for: .sidebarSystem) }
    }
    @Published var sidebarUserPrompt = ReaderAppState.storedPromptOverride(for: .sidebarUser) {
        didSet { Self.persistPromptTemplate(sidebarUserPrompt, for: .sidebarUser) }
    }
    @Published var paperMemoryPrompt = ReaderAppState.storedPromptOverride(for: .paperMemory) {
        didSet { Self.persistPromptTemplate(paperMemoryPrompt, for: .paperMemory) }
    }
    @Published var inlineSuggestionsPrompt = ReaderAppState.storedPromptOverride(for: .inlineSuggestions) {
        didSet { Self.persistPromptTemplate(inlineSuggestionsPrompt, for: .inlineSuggestions) }
    }
    @Published var inlineAnswerPrompt = ReaderAppState.storedPromptOverride(for: .inlineAnswer) {
        didSet { Self.persistPromptTemplate(inlineAnswerPrompt, for: .inlineAnswer) }
    }
    @Published var codexCLIPath = UserDefaults.standard.string(forKey: "CodexCLIPath") ?? ""
    @Published var claudeCLIPath = UserDefaults.standard.string(forKey: "ClaudeCLIPath") ?? ""
    @Published var highlightColorHex = UserDefaults.standard.string(forKey: "HighlightColorHex") ?? "#F7D154"
    @Published var selectionShortcutBindings = SelectionShortcutBindings(
        inlineSuggestionsKey: UserDefaults.standard.string(forKey: SelectionShortcutAction.inlineSuggestions.userDefaultsKey)
            ?? SelectionShortcutAction.inlineSuggestions.defaultKey,
        marginCommentKey: UserDefaults.standard.string(forKey: SelectionShortcutAction.marginComment.userDefaultsKey)
            ?? SelectionShortcutAction.marginComment.defaultKey,
        highlightKey: UserDefaults.standard.string(forKey: SelectionShortcutAction.highlight.userDefaultsKey)
            ?? SelectionShortcutAction.highlight.defaultKey
    )
    @Published var chatMessages: [ChatMessage] = []
    @Published var agentProfiles: [AgentProfile] = []
    @Published var focusedConnectorID: String?
    @Published private(set) var visibleChatHighlightToken: String?
    @Published private(set) var selectedCommentID: UUID?

    private let legacySidecarStore = SidecarStore()
    private var lastSuggestedSelection: ReaderSelectionContext?
    private var quickSuggestionRequestID = UUID()
    private var suggestionClearTask: Task<Void, Never>?
    private var isSelectionHovering = false
    private var isSuggestionPopoverHovering = false
    private var temporaryHighlightAnnotations: [(page: PDFPage, annotation: PDFAnnotation)] = []
    private var temporarySuggestionHighlightAnnotations: [UUID: [(page: PDFPage, annotation: PDFAnnotation)]] = [:]
    private var isLoadingTabState = false
    private var focusedConnectorClearTask: Task<Void, Never>?
    private var toolActivation = ToolActivationState<ReaderTool>()
    private var documentEditHistory = DocumentEditHistory()
    private var commentSelection = CommentSelectionState()
    private let temporarySuggestionTiming = TemporarySuggestionTiming(
        visibleSeconds: 20,
        fadeSeconds: 10,
        extensionStepSeconds: 10
    )
    private let marginAttachmentLayout = MarginAttachmentLayout()

    init() {
        reloadDeepSeekConfiguration()
        reloadGeminiConfiguration()
        discoverLocalAgentPathsOnStartup()
        refreshAgentProfiles()
        loadStoredAPICredentials()
    }

    private func loadStoredAPICredentials() {
        Task.detached(priority: .utility) { [weak self] in
            let deepSeekKey = Self.storedAPICredential(for: .deepSeekAPIKey)
            let geminiKey = Self.storedAPICredential(for: .geminiAPIKey)

            guard let self else {
                return
            }

            await self.applyStoredAPICredentials(deepSeekKey: deepSeekKey, geminiKey: geminiKey)
        }
    }

    private func applyStoredAPICredentials(deepSeekKey: String, geminiKey: String) {
        customDeepSeekAPIKey = deepSeekKey
        customGeminiAPIKey = geminiKey
        reloadDeepSeekConfiguration()
        reloadGeminiConfiguration()
    }

    func activateTool(_ tool: ReaderTool, gesture: ToolActivationGesture) {
        if tool == .outsideComment, gesture == .singleClick {
            addManualComment(at: nil)
            clearActiveTool()
            return
        }

        toolActivation.activate(tool, gesture: gesture)
        publishToolActivation()

        if selectedTool == nil {
            statusMessage = "Returned to preview mode."
            return
        }

        switch gesture {
        case .singleClick:
            statusMessage = "Armed \(tool.statusName) for one use."
        case .doubleClick:
            statusMessage = "Locked \(tool.statusName). Single-click it again to return to preview mode."
        }

        if tool == .highlight {
            highlightCurrentSelectionIfAvailable()
        } else if tool == .magicWand {
            showMagicWandForCurrentSelectionIfAvailable()
        }
    }

    func updateHighlightColor(_ colorHex: String) {
        highlightColorHex = colorHex
        UserDefaults.standard.set(colorHex, forKey: "HighlightColorHex")
        statusMessage = "Highlight color changed."
    }

    func updateSelectionShortcut(_ action: SelectionShortcutAction, key rawKey: String) {
        let updated = selectionShortcutBindings.updating(action, key: rawKey)
        selectionShortcutBindings = updated
        UserDefaults.standard.set(updated.key(for: action), forKey: action.userDefaultsKey)
        statusMessage = "\(action.title) shortcut set to \(updated.key(for: action).uppercased())."
    }

    @discardableResult
    func performSelectionShortcut(_ action: SelectionShortcutAction) -> Bool {
        guard selectedTool == nil else {
            return false
        }

        switch action {
        case .inlineSuggestions:
            return showInlineSuggestionsForCurrentSelection()
        case .marginComment:
            return saveCurrentSuggestionsAsComment()
        case .highlight:
            return highlightCurrentSelectionIfAvailable()
        }
    }

    func consumeToolUse(_ tool: ReaderTool) {
        guard toolActivation.consume(tool) else {
            return
        }
        publishToolActivation()
    }

    func clearActiveTool() {
        toolActivation.clear()
        publishToolActivation()
    }

    private func publishToolActivation() {
        selectedTool = toolActivation.activeTool
        toolActivationMode = toolActivation.mode
    }

    func refreshAgentProfiles() {
        var profiles = [
            AgentProfile(
                id: Self.deepSeekProAgentID,
                displayName: deepSeekDisplayName(for: deepSeekChatModel, defaultName: "DeepSeek V4 Pro"),
                kind: .hostedAPI,
                model: deepSeekChatModel,
                supportsStreaming: true
            ),
            AgentProfile(
                id: Self.deepSeekFlashAgentID,
                displayName: deepSeekDisplayName(for: deepSeekFastModel, defaultName: "DeepSeek V4 Flash"),
                kind: .hostedAPI,
                model: deepSeekFastModel,
                supportsStreaming: true
            ),
            AgentProfile(
                id: Self.geminiChatAgentID,
                displayName: "Gemini \(geminiChatModel)",
                kind: .hostedAPI,
                model: geminiChatModel,
                supportsStreaming: true
            ),
            AgentProfile(
                id: Self.geminiFastAgentID,
                displayName: "Gemini Fast \(geminiFastModel)",
                kind: .hostedAPI,
                model: geminiFastModel,
                supportsStreaming: true
            )
        ]
        profiles.append(
            contentsOf: LocalAgentProvider(
                configuredExecutables: configuredLocalAgentExecutables()
            )
            .availableAgents()
            .map(\.profile)
        )
        agentProfiles = profiles
        if !profiles.contains(where: { $0.id == selectedAgentID }) {
            selectedAgentID = profiles.first?.id ?? selectedAgentID
        }
        if !profiles.contains(where: { $0.id == inlineAgentID }) {
            inlineAgentID = Self.deepSeekFlashAgentID
        }
    }

    var hostedAgentProfiles: [AgentProfile] {
        agentProfiles.filter { $0.kind == .hostedAPI }
    }

    var selectedChatAgentIsLocalCLI: Bool {
        agentProfiles.first(where: { $0.id == selectedAgentID })?.kind == .localCLI
    }

    var selectedInlineAgentIsLocalCLI: Bool {
        agentProfiles.first(where: { $0.id == inlineAgentID })?.kind == .localCLI
    }

    var selectedChatLocalCodexAgent: Bool {
        agentProfiles.contains { profile in
            profile.id == "local-codex"
                && profile.model == "codex"
                && profile.id == selectedAgentID
        }
    }

    var selectedInlineLocalCodexAgent: Bool {
        agentProfiles.contains { profile in
            profile.id == "local-codex"
                && profile.model == "codex"
                && profile.id == inlineAgentID
        }
    }

    var selectedLocalCodexAgent: Bool {
        selectedChatLocalCodexAgent || selectedInlineLocalCodexAgent
    }

    var selectedLocalClaudeAgent: Bool {
        agentProfiles.contains { profile in
            profile.id == "local-claude"
                && profile.model == "claude"
                && (profile.id == selectedAgentID || profile.id == inlineAgentID)
        }
    }

    private func deepSeekDisplayName(for model: String, defaultName: String) -> String {
        switch model {
        case DeepSeekModel.paperQA.rawValue, DeepSeekModel.quickSuggestion.rawValue:
            return defaultName
        default:
            return "DeepSeek \(model)"
        }
    }

    var isDeepSeekKeyFromCustomOverride: Bool {
        !customDeepSeekAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isGeminiKeyFromCustomOverride: Bool {
        !customGeminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func persistDeepSeekKey() {
        customDeepSeekAPIKey = deepSeekAPIKey
        persistDeepSeekConfiguration()
    }

    func reloadDeepSeekKey() {
        reloadDeepSeekConfiguration()
    }

    func persistDeepSeekConfiguration() {
        let didPersistCredential = Self.persistAPICredential(
            customDeepSeekAPIKey,
            for: .deepSeekAPIKey
        )
        Self.persistOptionalDefault(customDeepSeekChatModel, forKey: "DeepSeekChatModel")
        Self.persistOptionalDefault(customDeepSeekFastModel, forKey: "DeepSeekFastModel")
        reloadDeepSeekConfiguration()
        statusMessage = didPersistCredential
            ? "Saved DeepSeek provider settings."
            : "Could not save DeepSeek API key to Keychain."
    }

    func reloadDeepSeekConfiguration() {
        let configuration = Self.resolveDeepSeekConfiguration(
            storedAPIKey: customDeepSeekAPIKey,
            storedChatModel: customDeepSeekChatModel,
            storedFastModel: customDeepSeekFastModel
        )
        deepSeekAPIKey = configuration.apiKey
        deepSeekChatModel = configuration.chatModel
        deepSeekFastModel = configuration.fastModel
        isDeepSeekKeyFromEnvironment = configuration.isEnvironmentBacked
        refreshAgentProfiles()
        if configuration.isEnvironmentBacked {
            statusMessage = "Loaded DeepSeek configuration from environment."
        }
    }

    func persistGeminiConfiguration() {
        let didPersistCredential = Self.persistAPICredential(
            customGeminiAPIKey,
            for: .geminiAPIKey
        )
        Self.persistOptionalDefault(customGeminiChatModel, forKey: "GeminiChatModel")
        Self.persistOptionalDefault(customGeminiFastModel, forKey: "GeminiFastModel")
        reloadGeminiConfiguration()
        statusMessage = didPersistCredential
            ? "Saved Gemini provider settings."
            : "Could not save Gemini API key to Keychain."
    }

    func reloadGeminiConfiguration() {
        let configuration = Self.resolveGeminiConfiguration(
            storedAPIKey: customGeminiAPIKey,
            storedChatModel: customGeminiChatModel,
            storedFastModel: customGeminiFastModel
        )
        geminiAPIKey = configuration.apiKey
        geminiChatModel = configuration.chatModel
        geminiFastModel = configuration.fastModel
        isGeminiKeyFromEnvironment = configuration.isEnvironmentBacked
        refreshAgentProfiles()
        if configuration.isEnvironmentBacked {
            statusMessage = "Loaded Gemini configuration from GEMINI_API_KEY, GEMINI_MODEL, and GEMINI_MODEL_FAST."
        }
    }

    func promptTemplate(for key: AIPromptTemplateKey) -> String {
        switch key {
        case .sidebarSystem:
            return sidebarSystemPrompt
        case .sidebarUser:
            return sidebarUserPrompt
        case .paperMemory:
            return paperMemoryPrompt
        case .inlineSuggestions:
            return inlineSuggestionsPrompt
        case .inlineAnswer:
            return inlineAnswerPrompt
        }
    }

    func setPromptTemplate(_ value: String, for key: AIPromptTemplateKey) {
        switch key {
        case .sidebarSystem:
            sidebarSystemPrompt = value
        case .sidebarUser:
            sidebarUserPrompt = value
        case .paperMemory:
            paperMemoryPrompt = value
        case .inlineSuggestions:
            inlineSuggestionsPrompt = value
        case .inlineAnswer:
            inlineAnswerPrompt = value
        }
    }

    func resetPromptTemplate(_ key: AIPromptTemplateKey) {
        setPromptTemplate("", for: key)
        statusMessage = "Using the built-in default for the \(key.displayTitle) prompt."
    }

    func hasPromptOverride(_ key: AIPromptTemplateKey) -> Bool {
        !promptTemplate(for: key).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func persistLocalAgentPaths() {
        UserDefaults.standard.set(codexCLIPath, forKey: "CodexCLIPath")
        UserDefaults.standard.set(claudeCLIPath, forKey: "ClaudeCLIPath")
        refreshAgentProfiles()
        statusMessage = "Updated local CLI agent paths."
    }

    private func discoverLocalAgentPathsOnStartup() {
        var didUpdate = false
        if let codexURL = LocalAgentExecutableDiscovery.discover(toolName: "codex"),
           codexURL.path != codexCLIPath {
            codexCLIPath = codexURL.path
            UserDefaults.standard.set(codexURL.path, forKey: "CodexCLIPath")
            didUpdate = true
        }
        if let claudeURL = LocalAgentExecutableDiscovery.discover(toolName: "claude"),
           claudeURL.path != claudeCLIPath {
            claudeCLIPath = claudeURL.path
            UserDefaults.standard.set(claudeURL.path, forKey: "ClaudeCLIPath")
            didUpdate = true
        }
        if didUpdate {
            UserDefaults.standard.synchronize()
        }
    }

    func chooseCLIPath(for toolName: String) {
        let panel = NSOpenPanel()
        panel.title = "Choose \(toolName) CLI"
        panel.message = "Select the executable file for the \(toolName) command."
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.showsHiddenFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            switch toolName {
            case "codex":
                codexCLIPath = url.path
            case "claude":
                claudeCLIPath = url.path
            default:
                return
            }
            persistLocalAgentPaths()
        }
    }

    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            for url in panel.urls {
                open(url: url)
            }
        }
    }

    func open(url: URL) {
        guard let document = PDFDocument(url: url) else {
            statusMessage = "Could not open \(url.lastPathComponent)."
            return
        }

        clearTemporaryHighlights()
        clearTemporarySourceHighlights()
        if !recentFiles.contains(url) {
            recentFiles.insert(url, at: 0)
        }

        do {
            let sidecarURL = try? legacySidecarStore.sidecarURL(for: url)
            var loadedSession: DocumentSession
            var shouldPersistHiddenMetadata = false

            if let embeddedSession = try? PDFEmbeddedMetadataStore.loadSession(from: document, pdfURL: url) {
                loadedSession = embeddedSession
            } else if let sidecarURL,
                      FileManager.default.fileExists(atPath: sidecarURL.path) {
                loadedSession = try legacySidecarStore.load(from: sidecarURL)
                shouldPersistHiddenMetadata = true
            } else {
                loadedSession = PDFDocumentController.makeSession(from: document, pdfURL: url)
            }

            let beforeExternalImport = loadedSession
            loadedSession = PDFDocumentController.importExternalHighlights(from: document, into: loadedSession)
            PDFDocumentController.applyStoredAnnotations(session: loadedSession, to: document)
            let commentMigration = Self.normalizeLegacyAICommentBodies(in: loadedSession)
            loadedSession = commentMigration.session
            if commentMigration.didChange || loadedSession != beforeExternalImport || shouldPersistHiddenMetadata {
                loadedSession.updatedAt = Date()
                try PDFExportService().saveInPlaceWithHiddenMetadata(
                    document: document,
                    session: loadedSession,
                    to: url
                )
            }
            let outline = PDFDocumentController.makeOutline(from: document, session: loadedSession)
            let memory = Self.localPaperMemory(for: loadedSession)

            let tab = ReaderDocumentTab(
                pdfURL: url,
                pdfDocument: document,
                session: loadedSession,
                currentPageIndex: 0,
                pdfScaleFactor: 1.0,
                pdfAutoScales: true,
                paperOutline: outline,
                paperMemory: memory
            )
            openTabs.append(tab)
            activeTabID = tab.id
            loadActiveTabState()
            documentEditHistory.clear()
            primePaperMemory()
            statusMessage = "Opened \(url.lastPathComponent)."
        } catch {
            statusMessage = "Opened PDF, but hidden metadata failed: \(error.localizedDescription)"
        }
    }

    func selectTab(_ id: UUID) {
        guard activeTabID != id else {
            return
        }
        syncActiveTabState()
        activeTabID = id
        keepSplitTabDistinctFromActive()
        loadActiveTabState()
    }

    func installDetachedTab(_ tab: ReaderDocumentTab) {
        openTabs = [tab]
        activeTabID = tab.id
        splitTabID = nil
        isSplitViewEnabled = false
        loadActiveTabState()
        documentEditHistory.clear()
        statusMessage = "Moved \(tab.title) to a new window."
    }

    var activePaperTitle: String {
        session?.title ?? "No paper"
    }

    var contextCandidateTabs: [ReaderDocumentTab] {
        openTabs.filter { $0.id != activeTabID }
    }

    func isContextTabIncluded(_ id: UUID) -> Bool {
        includedContextTabIDs.contains(id)
    }

    func setContextTab(_ id: UUID, included: Bool) {
        guard openTabs.contains(where: { $0.id == id }),
              id != activeTabID else {
            return
        }
        if included {
            includedContextTabIDs.insert(id)
        } else {
            includedContextTabIDs.remove(id)
        }
        syncActiveTabState()
        statusMessage = included
            ? "Added tab to AI context."
            : "Removed tab from AI context."
    }

    func closeTab(_ id: UUID) {
        syncActiveTabState()
        openTabs.removeAll { $0.id == id }
        for index in openTabs.indices {
            openTabs[index].includedContextTabIDs.remove(id)
        }
        includedContextTabIDs.remove(id)
        if splitTabID == id {
            splitTabID = nil
            isSplitViewEnabled = false
        }
        if activeTabID == id {
            activeTabID = openTabs.first?.id
            keepSplitTabDistinctFromActive()
            loadActiveTabState()
        }
        if openTabs.isEmpty {
            pdfDocument = nil
            session = nil
            currentPDFURL = nil
            paperOutline = []
            paperMemory = ""
            chatMessages = []
            chatInput = ""
            isThinking = false
            includedContextTabIDs = []
            statusMessage = "Open an academic PDF to begin."
        }
    }

    func toggleSplitView() {
        guard openTabs.count > 1 else {
            isSplitViewEnabled = false
            statusMessage = "Open another PDF before splitting the view."
            return
        }
        isSplitViewEnabled.toggle()
        if isSplitViewEnabled, splitTabID == nil {
            splitTabID = openTabs.first(where: { $0.id != activeTabID })?.id
        }
        keepSplitTabDistinctFromActive()
    }

    func setSplitTab(_ id: UUID?) {
        splitTabID = id == activeTabID ? openTabs.first(where: { $0.id != activeTabID })?.id : id
        isSplitViewEnabled = id != nil
        keepSplitTabDistinctFromActive()
    }

    func splitView(withTab id: UUID) {
        guard openTabs.count > 1 else {
            isSplitViewEnabled = false
            statusMessage = "Open another PDF before splitting the view."
            return
        }

        if id == activeTabID {
            splitTabID = openTabs.first(where: { $0.id != activeTabID })?.id
        } else {
            splitTabID = id
        }
        isSplitViewEnabled = splitTabID != nil
        keepSplitTabDistinctFromActive()
        statusMessage = isSplitViewEnabled ? "Opened split view." : "Could not find another tab for split view."
    }

    func moveTabToNewWindow(_ id: UUID) {
        syncActiveTabState()
        guard let tab = openTabs.first(where: { $0.id == id }) else {
            statusMessage = "Could not find that tab."
            return
        }

        DetachedReaderWindowRegistry.shared.open(tab: tab)
        closeTab(id)
        statusMessage = "Moved \(tab.title) to a new window."
    }

    var splitTab: ReaderDocumentTab? {
        guard isSplitViewEnabled, let splitTabID else {
            return nil
        }
        return openTabs.first(where: { $0.id == splitTabID })
    }

    private func keepSplitTabDistinctFromActive() {
        guard isSplitViewEnabled else {
            return
        }
        if splitTabID == activeTabID || splitTabID == nil || !openTabs.contains(where: { $0.id == splitTabID }) {
            splitTabID = openTabs.first(where: { $0.id != activeTabID })?.id
        }
        if splitTabID == nil {
            isSplitViewEnabled = false
        }
    }

    func openLinkedPaper(_ url: URL) {
        if url.isFileURL {
            open(url: url)
            return
        }

        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            NSWorkspace.shared.open(url)
            return
        }

        NSWorkspace.shared.open(url)
        statusMessage = "Opened link in browser. Looking for a paper PDF..."
        downloadAndOpenLinkedPaperPDF(from: url, sourcePaperURL: currentPDFURL)
    }

    func saveCurrentPDFWithHiddenMetadata() {
        guard let session else {
            return
        }
        guard let savedSession = persistSession(session, statusMessage: nil) else {
            return
        }
        statusMessage = "Saved \(savedSession.pdfURL.lastPathComponent) with hidden uprakigo metadata."
    }

    func revealCurrentPDFInFinder() {
        guard let currentPDFURL else {
            statusMessage = "Open a PDF before revealing it in Finder."
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([currentPDFURL])
        statusMessage = "Revealed \(currentPDFURL.lastPathComponent) in Finder."
    }

    @discardableResult
    private func persistSession(_ session: DocumentSession, statusMessage message: String?) -> DocumentSession? {
        do {
            var updated = session
            updated.updatedAt = Date()
            let document = try pdfDocumentForPersistence(of: updated)
            try PDFExportService().saveInPlaceWithHiddenMetadata(
                document: document,
                session: updated,
                to: updated.pdfURL
            )
            self.session = updated
            syncActiveTabState()
            statusMessage = message ?? "Saved \(updated.pdfURL.lastPathComponent) with hidden uprakigo metadata."
            return updated
        } catch {
            statusMessage = "Could not save hidden PDF metadata: \(error.localizedDescription)"
            return nil
        }
    }

    private func pdfDocumentForPersistence(of session: DocumentSession) throws -> PDFDocument {
        if let pdfDocument, currentPDFURL == session.pdfURL {
            return pdfDocument
        }
        guard let document = PDFDocument(url: session.pdfURL) else {
            throw PDFExportService.ExportError.couldNotCloneDocument
        }
        PDFDocumentController.applyStoredAnnotations(session: session, to: document)
        return document
    }

    private func performDocumentEdit(
        statusMessage message: String,
        resyncPDF: Bool = false,
        _ edit: (inout DocumentSession) -> Void
    ) {
        guard var draft = session else {
            return
        }
        let before = draft
        edit(&draft)
        guard draft != before else {
            return
        }
        draft.updatedAt = Date()
        documentEditHistory.record(before: before, after: draft)
        persistSession(draft, statusMessage: message)
        if resyncPDF {
            resyncPDFDocumentFromSession()
        }
    }

    func undoDocumentEdit() {
        guard let current = session,
              let restored = documentEditHistory.undo(current: current) else {
            statusMessage = "Nothing to undo."
            return
        }
        persistSession(restored, statusMessage: "Undid document edit.")
        resyncPDFDocumentFromSession()
    }

    func redoDocumentEdit() {
        guard let current = session,
              let restored = documentEditHistory.redo(current: current) else {
            statusMessage = "Nothing to redo."
            return
        }
        persistSession(restored, statusMessage: "Redid document edit.")
        resyncPDFDocumentFromSession()
    }

    private func resyncPDFDocumentFromSession() {
        guard let currentPDFURL,
              let session,
              let document = PDFDocument(url: currentPDFURL) else {
            syncActiveTabState()
            return
        }
        PDFDocumentController.applyStoredAnnotations(session: session, to: document)
        pdfDocument = document
        paperOutline = PDFDocumentController.makeOutline(from: document, session: session)
        paperMemory = Self.localPaperMemory(for: session)
        requestedPageIndex = currentPageIndex
        syncActiveTabState()
    }

    func presentExportPanel() {
        guard let pdfDocument, let session else {
            statusMessage = "Open a PDF before exporting."
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        let defaultMode = PDFExportMode.apparentChanges
        panel.nameFieldStringValue = "\(session.title)-\(defaultMode.fileSuffix).pdf"
        let modePicker = NSPopUpButton(frame: .zero, pullsDown: false)
        for mode in PDFExportMode.allCases {
            modePicker.addItem(withTitle: mode.title)
        }
        modePicker.selectItem(withTitle: defaultMode.title)
        let stack = NSStackView(views: [
            NSTextField(labelWithString: "Export"),
            modePicker
        ])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        panel.accessoryView = stack

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let mode = PDFExportMode.allCases[max(0, modePicker.indexOfSelectedItem)]
                try PDFExportService().export(document: pdfDocument, session: session, to: url, mode: mode)
                statusMessage = "Exported \(url.lastPathComponent)."
            } catch {
                statusMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    func handlePageChange(pageIndex: Int) {
        let resolvedPageIndex = max(0, pageIndex)
        guard currentPageIndex != resolvedPageIndex else {
            return
        }
        currentPageIndex = resolvedPageIndex
        syncActiveTabState()
    }

    func fitPDFToWidth() {
        pdfAutoScales = true
        syncActiveTabState()
        statusMessage = "PDF zoom set to fit."
    }

    func zoomPDFIn() {
        pdfAutoScales = false
        pdfScaleFactor = min(5.0, max(0.25, pdfScaleFactor) * 1.15)
        syncActiveTabState()
        statusMessage = "PDF zoom \(Int(pdfScaleFactor * 100))%."
    }

    func zoomPDFOut() {
        pdfAutoScales = false
        pdfScaleFactor = max(0.25, min(5.0, pdfScaleFactor) / 1.15)
        syncActiveTabState()
        statusMessage = "PDF zoom \(Int(pdfScaleFactor * 100))%."
    }

    func focusFindField() {
        findFocusToken = UUID()
    }

    func updateFindResults(jumpToFirst: Bool = false) {
        guard let session else {
            findResults = []
            findResultIndex = nil
            return
        }

        let query = findQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            findResults = []
            findResultIndex = nil
            clearTemporaryHighlights()
            return
        }

        findResults = SearchIndex(session: session).search(query, limit: 80)
        if findResults.isEmpty {
            findResultIndex = nil
            statusMessage = "No results for \(query)."
            return
        }

        if jumpToFirst || findResultIndex == nil || (findResultIndex ?? 0) >= findResults.count {
            findResultIndex = 0
            showFindResult(at: 0)
        }
    }

    func performFind() {
        updateFindResults(jumpToFirst: true)
        if findResults.isEmpty {
            statusMessage = "No results for \(findQuery.trimmingCharacters(in: .whitespacesAndNewlines))."
        }
    }

    func findNext() {
        updateFindResults(jumpToFirst: false)
        guard !findResults.isEmpty else {
            return
        }
        let next = ((findResultIndex ?? -1) + 1) % findResults.count
        findResultIndex = next
        showFindResult(at: next)
    }

    func findPrevious() {
        updateFindResults(jumpToFirst: false)
        guard !findResults.isEmpty else {
            return
        }
        let previous = ((findResultIndex ?? 0) - 1 + findResults.count) % findResults.count
        findResultIndex = previous
        showFindResult(at: previous)
    }

    var findResultSummary: String {
        guard !findResults.isEmpty, let findResultIndex else {
            return findQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "0"
        }
        return "\(findResultIndex + 1)/\(findResults.count)"
    }

    func showJumpCommand() {
        guard session != nil else {
            statusMessage = "Open a PDF before jumping."
            return
        }
        jumpCommandInput = ""
        isJumpCommandVisible = true
        jumpCommandFocusToken = UUID()
    }

    func cancelJumpCommand() {
        isJumpCommandVisible = false
        jumpCommandInput = ""
    }

    func submitJumpCommand() {
        let rawQuery = jumpCommandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let query = NavigationQueryParser.parse(rawQuery) else {
            statusMessage = "Use a page number, eq 12, fig 2, or table 1."
            return
        }

        guard navigate(to: query) else {
            statusMessage = "Could not find \(rawQuery)."
            return
        }

        isJumpCommandVisible = false
        jumpCommandInput = ""
    }

    private func showFindResult(at index: Int) {
        guard findResults.indices.contains(index) else {
            return
        }
        let result = findResults[index]
        let query = findQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let citation = SourceCitation(
            pageIndex: result.pageIndex,
            label: "Search result",
            highlightText: result.bounds == nil ? query : nil,
            bounds: result.bounds
        )
        applyTemporaryHighlight(for: [citation])
        statusMessage = "Search \(index + 1) of \(findResults.count) on page \(result.pageIndex + 1)."
    }

    private func navigate(to query: NavigationQuery) -> Bool {
        guard let session else {
            return false
        }

        switch query {
        case .page(let oneBasedPage):
            guard oneBasedPage >= 1, oneBasedPage <= session.pages.count else {
                return false
            }
            let pageIndex = oneBasedPage - 1
            requestedPageIndex = pageIndex
            currentPageIndex = pageIndex
            statusMessage = "Jumped to page \(oneBasedPage)."
            syncActiveTabState()
            return true
        case .equation(let identifier):
            guard let citation = EquationReferenceResolver.citation(
                forEquationIdentifier: identifier,
                in: session
            ) else {
                return false
            }
            applyTemporaryHighlight(for: [citation])
            statusMessage = "Jumped to \(citation.label)."
            return true
        case .figure(let identifier):
            guard let citation = labeledObjectCitation(kind: "figure", identifier: identifier) else {
                return false
            }
            applyTemporaryHighlight(for: [citation])
            statusMessage = "Jumped to \(citation.label)."
            return true
        case .table(let identifier):
            guard let citation = labeledObjectCitation(kind: "table", identifier: identifier) else {
                return false
            }
            applyTemporaryHighlight(for: [citation])
            statusMessage = "Jumped to \(citation.label)."
            return true
        }
    }

    private func labeledObjectCitation(kind: String, identifier: String) -> SourceCitation? {
        let normalizedKind = kind.lowercased()
        let normalizedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let labelPatterns = labelVariants(kind: normalizedKind, identifier: normalizedIdentifier)

        if let outlineItem = paperOutline.first(where: { item in
            labelPatterns.contains { label in
                item.title.range(of: label, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }) {
            let label = labelPatterns.first { pattern in
                outlineItem.title.range(of: pattern, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            } ?? "\(normalizedKind.capitalized) \(normalizedIdentifier)"
            return SourceCitation(
                pageIndex: outlineItem.pageIndex,
                label: outlineItem.title,
                highlightText: label
            )
        }

        guard let session else {
            return nil
        }

        let index = SearchIndex(session: session)
        for label in labelPatterns {
            if let result = index.search(label, limit: 1).first {
                return SourceCitation(
                    pageIndex: result.pageIndex,
                    label: "\(normalizedKind.capitalized) \(normalizedIdentifier)",
                    highlightText: result.bounds == nil ? label : nil,
                    bounds: result.bounds
                )
            }
        }
        return nil
    }

    private func labelVariants(kind: String, identifier: String) -> [String] {
        switch kind {
        case "figure":
            return ["Figure \(identifier)", "Fig. \(identifier)", "Fig \(identifier)"]
        case "table":
            return ["Table \(identifier)", "Tab. \(identifier)", "Tab \(identifier)"]
        default:
            return ["\(kind.capitalized) \(identifier)"]
        }
    }

    func handleSelectedText(_ text: String, pageIndex: Int, anchor: CGPoint? = nil, bounds: NormalizedRect? = nil) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else {
            clearSelectionSuggestions()
            return
        }

        let context = ReaderSelectionContext.text(cleanText, pageIndex: pageIndex, bounds: bounds)
        selectionImageAttachment = visualAttachmentForSelectedText(cleanText, pageIndex: pageIndex, bounds: bounds)
        focusConnector(for: context)
        guard selectedTool == .magicWand else {
            selectionContext = context
            quickSuggestionAnchor = anchor
            quickSuggestions = []
            lastSuggestedSelection = nil
            quickSuggestionRequestID = UUID()
            isQuickSuggestionVisible = false
            statusMessage = "Selected text on page \(pageIndex + 1)."
            return
        }

        quickSuggestionAnchor = anchor
        updateSelectionContext(context)
        isSelectionHovering = true
        isQuickSuggestionVisible = true
            statusMessage = "Selected text on page \(pageIndex + 1). Inline explanation is ready."
        generateQuickSuggestionsIfNeeded(for: context)
        consumeToolUse(.magicWand)
    }

    func handleSelectionHover(isHovering: Bool) {
        isSelectionHovering = isHovering
        if !isQuickSuggestionVisible, selectedTool != .magicWand {
            suggestionClearTask?.cancel()
            return
        }
        guard isHovering else {
            suggestionClearTask?.cancel()
            guard selectionContext == nil else {
                isQuickSuggestionVisible = true
                return
            }
            suggestionClearTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else {
                    return
                }
                guard !isSuggestionPopoverHovering else {
                    return
                }
                isQuickSuggestionVisible = false
            }
            return
        }

        suggestionClearTask?.cancel()
        guard let selectionContext else {
            isQuickSuggestionVisible = false
            quickSuggestions = []
            return
        }

        isQuickSuggestionVisible = true
        generateQuickSuggestionsIfNeeded(for: selectionContext)
    }

    private func showMagicWandForCurrentSelectionIfAvailable() {
        if showInlineSuggestionsForCurrentSelection() {
            consumeToolUse(.magicWand)
        }
    }

    @discardableResult
    func showInlineSuggestionsForCurrentSelection() -> Bool {
        guard let selectionContext else {
            statusMessage = "Select text or a region before showing inline suggestions."
            return false
        }
        suggestionClearTask?.cancel()
        isSelectionHovering = true
        isQuickSuggestionVisible = true
        statusMessage = "Inline explanation is ready."
        generateQuickSuggestionsIfNeeded(for: selectionContext)
        return true
    }

    func handleSelectionCleared() {
        suggestionClearTask?.cancel()
        isSelectionHovering = false
        isSuggestionPopoverHovering = false
        clearSelectionSuggestions()
    }

    func handleSuggestionPopoverHover(isHovering: Bool) {
        isSuggestionPopoverHovering = isHovering
        if isHovering {
            suggestionClearTask?.cancel()
            isQuickSuggestionVisible = true
        } else if !isSelectionHovering {
            handleSelectionHover(isHovering: false)
        }
    }

    var displayedQuickSuggestions: [InlineSuggestion] {
        if !quickSuggestions.isEmpty {
            return quickSuggestions
        }
        guard let selectionContext else {
            return []
        }
        return heuristicSuggestions(for: selectionContext)
    }

    var inlineAutocompleteCandidates: [String] {
        InlineAutocompleteEngine().candidates(
            typed: inlineQuestionInput,
            preferredQuestions: Self.inlineQuestionFallbacks(for: selectionContext)
        )
    }

    func acceptInlineAutocomplete(_ question: String) {
        inlineQuestionInput = question
        isQuickSuggestionVisible = true
        suggestionClearTask?.cancel()
    }

    func keepCurrentSuggestionsTemporarily() {
        guard let selectionContext else {
            statusMessage = "Select text or a region before keeping an AI note temporarily."
            return
        }

        let suggestions = suggestionsForCurrentSelection()
        guard !suggestions.isEmpty else {
            statusMessage = "No inline suggestions are ready to keep."
            return
        }

        let viewportHeight = max(pdfViewportSize.height, 1)
        let anchorY = quickSuggestionAnchor?.y ?? viewportHeight * 0.24
        let fallbackSourceYFraction = max(0.08, min(0.92, anchorY / viewportHeight))
        let group = LingeringInlineSuggestionGroup(
            context: selectionContext,
            suggestions: suggestions,
            sourceYFraction: sourceYFraction(for: selectionContext) ?? fallbackSourceYFraction,
            retention: temporarySuggestionTiming.initialState(now: Date())
        )

        lingeringInlineSuggestionGroups.removeAll { $0.context == selectionContext }
        lingeringInlineSuggestionGroups.insert(group, at: 0)
        applyTemporarySourceHighlight(for: group)
        isQuickSuggestionVisible = false
        statusMessage = "Kept AI suggestions temporarily in the margin."
        scheduleLingeringSuggestionRemoval(group.id)
    }

    @discardableResult
    func saveCurrentSuggestionsAsComment() -> Bool {
        guard let selectionContext else {
            statusMessage = "Select text or a region before saving an AI note."
            return false
        }

        let suggestions = suggestionsForCurrentSelection()
        guard !suggestions.isEmpty else {
            statusMessage = "No inline suggestions are ready to save."
            return false
        }

        let body = readableMarginNoteBody(context: selectionContext, suggestions: suggestions)
        if let bounds = selectionContext.sourceBounds {
            addAnchoredComment(
                body: body,
                pageIndex: selectionContext.pageIndex,
                bounds: bounds,
                sourceContext: selectionContext
            )
        } else {
            addOutsidePageComment(body: body)
        }
        isQuickSuggestionVisible = false
        statusMessage = "Saved AI note as a margin comment."
        return true
    }

    func extendLingeringSuggestionGroup(_ id: UUID) {
        guard let index = lingeringInlineSuggestionGroups.firstIndex(where: { $0.id == id }) else {
            return
        }

        lingeringInlineSuggestionGroups[index].retention = temporarySuggestionTiming.extendedState(
            from: lingeringInlineSuggestionGroups[index].retention,
            now: Date()
        )
        let count = lingeringInlineSuggestionGroups[index].retention.extensionCount
        statusMessage = "Kept temporary AI note longer. Extension \(count)."
        scheduleLingeringSuggestionRemoval(id)
    }

    func removeLingeringSuggestionGroup(_ id: UUID) {
        lingeringInlineSuggestionGroups.removeAll { $0.id == id }
        clearTemporarySourceHighlight(for: id)
        clearFocusedConnectorIfMatching("temporary-\(id.uuidString)")
        statusMessage = "Removed temporary AI note."
    }

    func removeComment(_ id: UUID) {
        performDocumentEdit(statusMessage: "Removed comment.") { session in
            session.comments.removeAll { $0.id == id }
        }
        commentSelection.clearIfSelected(id)
        selectedCommentID = commentSelection.selectedCommentID
        if pendingAnchorCommentID == id {
            pendingAnchorCommentID = nil
        }
        clearFocusedConnectorIfMatching("comment-\(id.uuidString)")
    }

    func selectComment(_ id: UUID) {
        guard session?.comments.contains(where: { $0.id == id }) == true else {
            return
        }
        commentSelection.select(id)
        selectedCommentID = commentSelection.selectedCommentID
        focusConnector(forCommentID: id)
        statusMessage = "Selected comment. Press Delete to remove it."
    }

    @discardableResult
    func deleteSelectedComment() -> Bool {
        let existingIDs = Set((session?.comments ?? []).map(\.id))
        guard let id = commentSelection.commentIDForDeletion(existingCommentIDs: existingIDs) else {
            selectedCommentID = commentSelection.selectedCommentID
            return false
        }
        removeComment(id)
        return true
    }

    func beginEditingCommentAnchor(_ id: UUID) {
        guard session?.comments.contains(where: { $0.id == id }) == true else {
            return
        }
        pendingAnchorCommentID = id
        toolActivation.activate(.outsideComment, gesture: .singleClick)
        publishToolActivation()
        statusMessage = "Click a point in the PDF to set this comment anchor."
    }

    func applyPendingCommentAnchor(pageIndex: Int, point: NormalizedPoint) {
        guard let pendingAnchorCommentID else {
            statusMessage = "Right-click a comment and choose Set Anchor before clicking the PDF."
            clearActiveTool()
            return
        }
        guard let session,
              let index = session.comments.firstIndex(where: { $0.id == pendingAnchorCommentID }) else {
            self.pendingAnchorCommentID = nil
            clearActiveTool()
            return
        }

        var updated = session
        updated.comments[index].pageIndex = pageIndex
        updated.comments[index].anchor = .pagePoint(point)
        self.pendingAnchorCommentID = nil
        let before = session
        documentEditHistory.record(before: before, after: updated)
        persistSession(updated, statusMessage: "Updated comment anchor on page \(pageIndex + 1).")
        consumeToolUse(.outsideComment)
    }

    func removeCommentAnchor(_ id: UUID) {
        performDocumentEdit(statusMessage: "Removed comment anchor.") { session in
            guard let index = session.comments.firstIndex(where: { $0.id == id }) else {
                return
            }
            session.comments[index].anchor = .pageOnly
        }
        if pendingAnchorCommentID == id {
            pendingAnchorCommentID = nil
        }
    }

    func updateCommentColor(_ id: UUID, colorHex: String) {
        performDocumentEdit(statusMessage: "Updated comment color.") { session in
            guard let index = session.comments.firstIndex(where: { $0.id == id }) else {
                return
            }
            session.comments[index].colorHex = colorHex
        }
    }

    func updateCommentDisplayHeight(_ id: UUID, height: Double?) {
        performDocumentEdit(statusMessage: "Resized comment.") { session in
            guard let index = session.comments.firstIndex(where: { $0.id == id }) else {
                return
            }
            session.comments[index].displayHeight = height.map(CommentBoxSizing.clampedHeight)
        }
    }

    func updateCommentDisplayYOffset(_ id: UUID, yOffset: Double?) {
        performDocumentEdit(statusMessage: "Moved comment.") { session in
            guard let index = session.comments.firstIndex(where: { $0.id == id }) else {
                return
            }
            let clamped = yOffset.map(Self.clampedCommentDisplayYOffset)
            session.comments[index].displayYOffset = clamped.flatMap { abs($0) < 0.0001 ? nil : $0 }
        }
    }

    func updateCommentBody(_ id: UUID, body: String) {
        performDocumentEdit(statusMessage: "Updated comment.") { session in
            guard let commentIndex = session.comments.firstIndex(where: { $0.id == id }) else {
                return
            }
            let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedBody = trimmedBody.isEmpty ? "New note" : body
            if session.comments[commentIndex].messages.isEmpty {
                session.comments[commentIndex].messages.append(
                    CommentMessage(author: NSUserName(), body: resolvedBody)
                )
            } else {
                session.comments[commentIndex].messages[0].body = resolvedBody
            }
        }
    }

    func opacity(for group: LingeringInlineSuggestionGroup, at date: Date) -> Double {
        temporarySuggestionTiming.opacity(at: date, state: group.retention)
    }

    func captureRegion(bounds: NormalizedRect, kind: RegionKind = .figure) {
        captureRegion(pageIndex: currentPageIndex, bounds: bounds, kind: kind)
    }

    func captureRegion(pageIndex: Int, bounds: NormalizedRect, kind: RegionKind = .figure) {
        let resolvedPageIndex = max(0, pageIndex)
        let nearbyText = nearbyText(on: resolvedPageIndex)
        let digestInput = "\(currentPDFURL?.path ?? "")-\(resolvedPageIndex)-\(bounds.x)-\(bounds.y)-\(bounds.width)-\(bounds.height)"
        let digest = SHA256.hash(data: Data(digestInput.utf8)).map { String(format: "%02x", $0) }.joined()
        let region = RegionSelection(
            pageIndex: resolvedPageIndex,
            kind: kind,
            bounds: bounds,
            label: "\(kind.rawValue.capitalized) selection",
            nearbyText: nearbyText,
            imageDigest: "sha256:\(digest)"
        )
        selectionImageAttachment = visualAttachment(
            pageIndex: resolvedPageIndex,
            bounds: bounds,
            label: "selected \(kind.rawValue) crop"
        )

        performDocumentEdit(statusMessage: "Captured \(kind.rawValue) region.") { session in
            session.regionSelections.append(region)
        }

        let context = ReaderSelectionContext.region(region)
        let shouldShowInline = selectedTool == .magicWand || selectedTool == .region
        if shouldShowInline {
            isSelectionHovering = true
            updateSelectionContext(context)
            isQuickSuggestionVisible = true
            generateQuickSuggestionsIfNeeded(for: context)
            if selectedTool == .magicWand {
                consumeToolUse(.magicWand)
            } else {
                consumeToolUse(.region)
            }
        } else {
            selectionContext = context
            quickSuggestionAnchor = nil
            quickSuggestions = []
            lastSuggestedSelection = nil
            quickSuggestionRequestID = UUID()
            isQuickSuggestionVisible = false
            statusMessage = "Selected \(kind.rawValue) region on page \(resolvedPageIndex + 1)."
        }
    }

    func addOutsidePageComment(body: String = "New margin comment") {
        addManualComment(at: nil, pageIndex: currentPageIndex, body: body)
    }

    func addManualComment(at point: NormalizedPoint?, pageIndex: Int? = nil, body: String = "New margin comment") {
        let resolvedPageIndex = max(0, pageIndex ?? currentPageIndex)
        let anchor: CommentAnchor = point.map { .pagePoint($0) } ?? .pageOnly
        let thread = CommentThread(
            pageIndex: resolvedPageIndex,
            anchor: anchor,
            messages: [CommentMessage(author: NSUserName(), body: body)],
            colorHex: CommentThread.defaultColorHex
        )
        performDocumentEdit(
            statusMessage: point == nil
                ? "Added an unanchored page comment."
                : "Added a comment anchored to page \(resolvedPageIndex + 1)."
        ) { session in
            session.comments.append(thread)
        }
    }

    func addHighlightLinkedNote(_ request: PDFHighlightNoteRequest) {
        let note = CommentThread.linkedHighlightNote(
            pageIndex: request.pageIndex,
            bounds: request.bounds,
            colorHex: request.colorHex,
            author: NSUserName()
        )
        performDocumentEdit(statusMessage: "Added note attached to highlighted text.") { session in
            session.comments.append(note)
        }
        focusConnector(forCommentID: note.id)
    }

    func addHighlight(bounds: NormalizedRect, pageIndex: Int? = nil) {
        let targetPageIndex = pageIndex ?? currentPageIndex
        let annotation = Annotation(
            pageIndex: targetPageIndex,
            kind: .highlight,
            bounds: bounds,
            contents: "Highlight",
            colorHex: highlightColorHex
        )
        performDocumentEdit(statusMessage: "Added highlight.", resyncPDF: true) { session in
            session.annotations.append(annotation)
        }
    }

    @discardableResult
    func highlightCurrentSelectionIfAvailable() -> Bool {
        guard case .text(_, let pageIndex, let bounds) = selectionContext,
              let bounds else {
            statusMessage = "Select text before highlighting."
            return false
        }
        addHighlight(bounds: bounds, pageIndex: pageIndex)
        consumeToolUse(.highlight)
        return true
    }

    func recordAnnotation(_ annotation: Annotation) {
        performDocumentEdit(statusMessage: "Added annotation.", resyncPDF: true) { session in
            session.annotations.append(annotation)
        }
        switch annotation.kind {
        case .highlight:
            consumeToolUse(.highlight)
        case .note:
            consumeToolUse(.note)
        case .textBox:
            consumeToolUse(.textBox)
        case .ink:
            consumeToolUse(.ink)
        case .rectangle:
            consumeToolUse(.region)
        }
    }

    func recordSignature(_ signature: Signature) {
        performDocumentEdit(statusMessage: "Added signature.", resyncPDF: true) { session in
            session.signatures.append(signature)
        }
        consumeToolUse(.signature)
    }

    func removePDFAnnotation(_ request: PDFAnnotationRemovalRequest) {
        performDocumentEdit(statusMessage: removalStatusMessage(for: request), resyncPDF: true) { session in
            switch request.kind {
            case .annotation(let kind):
                if kind == .highlight, let externalKey = request.externalPDFAnnotationKey {
                    if !session.hiddenExternalAnnotationKeys.contains(externalKey) {
                        session.hiddenExternalAnnotationKeys.append(externalKey)
                    }
                    session.annotations.removeAll { $0.externalPDFAnnotationKey == externalKey }
                    return
                }

                if let sidecarID = request.sidecarID {
                    session.annotations.removeAll { $0.id == sidecarID }
                    return
                }

                let requestKey = AnnotationIdentity.key(
                    pageIndex: request.pageIndex,
                    kind: kind,
                    bounds: request.bounds,
                    contents: request.contents
                )
                session.annotations.removeAll { annotation in
                    annotation.kind == kind
                        && AnnotationIdentity.key(
                            pageIndex: annotation.pageIndex,
                            kind: annotation.kind,
                            bounds: annotation.bounds,
                            contents: annotation.contents
                        ) == requestKey
                }
            case .signature:
                if let sidecarID = request.sidecarID {
                    session.signatures.removeAll { $0.id == sidecarID }
                    return
                }
                session.signatures.removeAll { signature in
                    signature.pageIndex == request.pageIndex
                        && signature.bounds.approximatelyEquals(request.bounds)
                }
            }
        }
    }

    private func removalStatusMessage(for request: PDFAnnotationRemovalRequest) -> String {
        switch request.kind {
        case .annotation(.highlight):
            return "Removed highlight."
        case .annotation:
            return "Removed annotation."
        case .signature:
            return "Removed signature."
        }
    }

    func sendChat() {
        let question = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else {
            return
        }
        chatInput = ""
        syncActiveTabState()
        askAI(question: question)
    }

    func askAI(question: String) {
        guard let session,
              let activeTabID else {
            return
        }

        let context = contextForCurrentSelection(session: session)
        let userMessage = ChatMessage(role: .user, content: question, citations: context.citations)
        appendChatMessage(userMessage, to: activeTabID)

        switch resolveAIProvider(agentID: selectedAgentID, purpose: .sidebarChat) {
        case .localCLI(let message):
            appendChatMessage(
                ChatMessage(
                    role: .assistant,
                    content: "\(message)\n\n\(context.prompt)",
                    citations: context.citations
                ),
                to: activeTabID
            )
            return
        case .missingCredential(let message):
            appendChatMessage(
                ChatMessage(
                    role: .assistant,
                    content: "\(message) Suggested local question: \(question)",
                    citations: context.citations
                ),
                to: activeTabID
            )
            return
        case .hosted(let provider):
            setThinking(true, for: activeTabID)
            let messages = [
                AIMessage(
                    role: .system,
                    content: renderedPrompt(.sidebarSystem, values: [:])
                ),
                AIMessage(
                    role: .user,
                    content: renderedPrompt(
                        .sidebarUser,
                        values: [
                            "paperContext": context.prompt,
                            "paperMemory": paperMemoryPrefix,
                            "question": question
                        ]
                    ),
                    imageAttachments: context.imageAttachments
                )
            ]

            Task {
                do {
                    let reply = try await provider.complete(messages: messages)
                    await MainActor.run {
                        let refinedCitations = PreciseHighlightResolver.refinedCitations(
                            question: question,
                            answer: reply.content,
                            session: session,
                            baseCitations: context.citations
                        )
                        let assistantMessage = ChatMessage(
                            role: .assistant,
                            content: reply.content,
                            citations: refinedCitations
                        )
                        self.appendChatMessage(
                            assistantMessage,
                            to: activeTabID
                        )
                        if self.activeTabID == activeTabID {
                            self.applyTemporaryHighlight(
                                for: refinedCitations,
                                token: Self.chatHighlightToken(for: assistantMessage)
                            )
                        }
                        self.setThinking(false, for: activeTabID)
                    }
                } catch {
                    await MainActor.run {
                        self.appendChatMessage(
                            ChatMessage(role: .assistant, content: "AI request failed: \(error.localizedDescription)", citations: context.citations),
                            to: activeTabID
                        )
                        self.setThinking(false, for: activeTabID)
                    }
                }
            }
        }
    }

    func askInlineSuggestionQuestion() {
        let question = inlineQuestionInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, let selectionContext else {
            return
        }
        inlineQuestionInput = ""
        isQuickSuggestionVisible = true
        let item = InlineSuggestion(question: question, answer: "Thinking...", isLoading: true)
        quickSuggestions.insert(item, at: 0)
        answerInlineSuggestion(itemID: item.id, question: question, context: selectionContext)
    }

    func addInlineAnswerAsComment(_ suggestion: InlineSuggestion) {
        let body = readableMarginNoteBody(context: selectionContext, suggestions: [suggestion])
        if let selectionContext, let bounds = selectionContext.sourceBounds {
            addAnchoredComment(
                body: body,
                pageIndex: selectionContext.pageIndex,
                bounds: bounds,
                sourceContext: selectionContext
            )
        } else {
            addOutsidePageComment(body: body)
        }
    }

    func addAnchoredComment(
        body: String,
        pageIndex: Int,
        bounds: NormalizedRect,
        sourceContext: ReaderSelectionContext? = nil
    ) {
        let thread = CommentThread(
            pageIndex: pageIndex,
            anchor: .inPage(bounds),
            messages: [CommentMessage(author: NSUserName(), body: body)],
            colorHex: CommentThread.attachedColorHex
        )
        let sourceMarker = sourceContext.map {
            sourceMarkerAnnotation(for: thread, context: $0, bounds: bounds)
        }
        performDocumentEdit(
            statusMessage: "Added anchored margin comment.",
            resyncPDF: sourceMarker != nil
        ) { session in
            session.comments.append(thread)
            if let sourceMarker,
               !session.annotations.contains(where: { existing in
                   existing.pageIndex == sourceMarker.pageIndex
                       && existing.kind == sourceMarker.kind
                       && existing.bounds.approximatelyEquals(sourceMarker.bounds)
                       && existing.colorHex.lowercased() == sourceMarker.colorHex.lowercased()
               }) {
                session.annotations.append(sourceMarker)
            }
        }
        focusConnector(forCommentID: thread.id)
    }

    private func sourceMarkerAnnotation(
        for comment: CommentThread,
        context: ReaderSelectionContext,
        bounds: NormalizedRect
    ) -> Annotation {
        Annotation.sourceMarker(
            for: comment,
            bounds: bounds,
            kind: sourceMarkerKind(for: context),
            contents: sourceMarkerContents(for: context)
        )
    }

    private func sourceMarkerKind(for context: ReaderSelectionContext) -> AnnotationKind {
        switch context {
        case .text:
            return .highlight
        case .region:
            return .rectangle
        }
    }

    private func sourceMarkerContents(for context: ReaderSelectionContext) -> String {
        let text = context.detail
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return context.title
        }
        if text.count <= 180 {
            return text
        }
        return "\(text.prefix(177))..."
    }

    func updatePDFViewportSize(_ size: CGSize) {
        guard abs(pdfViewportSize.width - size.width) > 0.5
            || abs(pdfViewportSize.height - size.height) > 0.5 else {
            return
        }
        pdfViewportSize = size
    }

    func handlePDFViewportChanged(_ snapshot: PDFViewportSnapshot) {
        if pdfViewportSnapshot != snapshot {
            pdfViewportSnapshot = snapshot
        }
        if abs(pdfViewportSize.width - snapshot.viewSize.width) > 0.5
            || abs(pdfViewportSize.height - snapshot.viewSize.height) > 0.5 {
            pdfViewportSize = snapshot.viewSize
        }
    }

    func marginPlacement(for group: LingeringInlineSuggestionGroup) -> MarginAttachmentPlacement {
        marginAttachmentLayout.placement(
            sourceYFraction: liveSourceYFraction(for: group.context) ?? group.sourceYFraction
        )
    }

    func marginPlacement(for thread: CommentThread) -> MarginAttachmentPlacement {
        let input = MarginAttachmentInput(
            id: thread.id,
            sourceYFraction: liveSourceYFraction(for: thread),
            sourceXFraction: liveSourceXFraction(for: thread),
            displayYOffset: thread.displayYOffset
        )
        return marginAttachmentLayout.placements(for: [input])[thread.id]
            ?? marginAttachmentLayout.placement(sourceYFraction: liveSourceYFraction(for: thread))
    }

    func marginPlacementsForVisibleComments() -> [UUID: MarginAttachmentPlacement] {
        let inputs = (session?.comments ?? []).map { thread in
            MarginAttachmentInput(
                id: thread.id,
                sourceYFraction: liveSourceYFraction(for: thread),
                sourceXFraction: liveSourceXFraction(for: thread),
                displayYOffset: thread.displayYOffset
            )
        }
        return marginAttachmentLayout.placements(for: inputs)
    }

    func marginPlacementsForTemporarySuggestions() -> [UUID: MarginAttachmentPlacement] {
        let inputs = lingeringInlineSuggestionGroups.map { group in
            MarginAttachmentInput(
                id: group.id,
                sourceYFraction: liveSourceYFraction(for: group.context) ?? group.sourceYFraction,
                sourceXFraction: liveSourceXFraction(for: group.context)
            )
        }
        return marginAttachmentLayout.placements(for: inputs)
    }

    func connectorSourcePoint(for group: LingeringInlineSuggestionGroup, placement: MarginAttachmentPlacement) -> CGPoint? {
        guard let sourceYFraction = placement.sourceYFraction else {
            return nil
        }
        let x = liveSourceXFraction(for: group.context)
            .map { CGFloat($0) * max(pdfViewportSize.width, 1) }
            ?? max(pdfViewportSize.width * 0.72, 24)
        return CGPoint(
            x: x,
            y: CGFloat(sourceYFraction) * max(pdfViewportSize.height, 1)
        )
    }

    func connectorSourcePoint(for thread: CommentThread, placement: MarginAttachmentPlacement) -> CGPoint? {
        if case .pageOnly = thread.anchor {
            return nil
        }
        guard let sourceYFraction = placement.sourceYFraction else {
            return nil
        }
        let x = liveSourceXFraction(for: thread)
            .map { CGFloat($0) * max(pdfViewportSize.width, 1) }
            ?? max(pdfViewportSize.width * 0.72, 24)
        return CGPoint(
            x: x,
            y: CGFloat(sourceYFraction) * max(pdfViewportSize.height, 1)
        )
    }

    func jumpToSelectionContext(_ context: ReaderSelectionContext) {
        switch context {
        case .text(_, let pageIndex, _):
            requestedPageIndex = pageIndex
            currentPageIndex = pageIndex
            statusMessage = "Jumped to selected text on page \(pageIndex + 1)."
        case .region(let region):
            requestedPageIndex = region.pageIndex
            currentPageIndex = region.pageIndex
            statusMessage = "Jumped to selected \(region.kind.rawValue) on page \(region.pageIndex + 1)."
        }
    }

    func jumpToComment(_ thread: CommentThread) {
        focusConnector(forCommentID: thread.id)
        requestedPageIndex = thread.pageIndex
        currentPageIndex = thread.pageIndex
        statusMessage = "Jumped to comment on page \(thread.pageIndex + 1)."
    }

    func focusConnector(forCommentID id: UUID, duration: TimeInterval? = nil) {
        focusConnector(id: "comment-\(id.uuidString)", duration: duration)
    }

    func focusConnector(forTemporarySuggestionID id: UUID, duration: TimeInterval? = nil) {
        focusConnector(id: "temporary-\(id.uuidString)", duration: duration)
    }

    func focusConnector(for context: ReaderSelectionContext, duration: TimeInterval? = nil) {
        guard let commentID = nearestAnchoredCommentID(matching: context) else {
            clearFocusedConnector()
            return
        }
        focusConnector(forCommentID: commentID, duration: duration)
    }

    private func focusConnector(id: String, duration: TimeInterval?) {
        focusedConnectorClearTask?.cancel()
        focusedConnectorClearTask = nil
        focusedConnectorID = id
        guard let duration else {
            return
        }
        focusedConnectorClearTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else {
                return
            }
            if focusedConnectorID == id {
                focusedConnectorID = nil
            }
        }
    }

    private func clearFocusedConnector() {
        focusedConnectorClearTask?.cancel()
        focusedConnectorClearTask = nil
        focusedConnectorID = nil
    }

    private func clearFocusedConnectorIfMatching(_ id: String) {
        guard focusedConnectorID == id else {
            return
        }
        clearFocusedConnector()
    }

    private func nearestAnchoredCommentID(matching context: ReaderSelectionContext) -> UUID? {
        guard let bounds = context.sourceBounds else {
            return nil
        }

        return (session?.comments ?? [])
            .compactMap { thread -> (id: UUID, score: Double)? in
                guard thread.pageIndex == context.pageIndex else {
                    return nil
                }
                switch thread.anchor {
                case .inPage(let anchorBounds):
                    let score = rectMatchScore(anchorBounds, bounds)
                    return score <= 0.08 ? (thread.id, score) : nil
                case .pagePoint(let point):
                    let score = pointMatchScore(point, bounds)
                    return score <= 0.12 ? (thread.id, score) : nil
                case .outsidePage, .pageOnly:
                    return nil
                }
            }
            .min { $0.score < $1.score }?
            .id
    }

    private func rectMatchScore(_ lhs: NormalizedRect, _ rhs: NormalizedRect) -> Double {
        let centerDistance = hypot(rectCenterX(lhs) - rectCenterX(rhs), rectCenterY(lhs) - rectCenterY(rhs))
        let overlapPenalty = 1 - intersectionOverUnion(lhs, rhs)
        return centerDistance + overlapPenalty * 0.03
    }

    private func pointMatchScore(_ point: NormalizedPoint, _ rect: NormalizedRect) -> Double {
        hypot(point.x - rectCenterX(rect), point.y - rectCenterY(rect))
    }

    private func rectCenterX(_ rect: NormalizedRect) -> Double {
        rect.x + rect.width / 2
    }

    private func rectCenterY(_ rect: NormalizedRect) -> Double {
        rect.y + rect.height / 2
    }

    private func intersectionOverUnion(_ lhs: NormalizedRect, _ rhs: NormalizedRect) -> Double {
        let left = max(lhs.x, rhs.x)
        let right = min(lhs.x + lhs.width, rhs.x + rhs.width)
        let bottom = max(lhs.y, rhs.y)
        let top = min(lhs.y + lhs.height, rhs.y + rhs.height)
        let intersection = max(0, right - left) * max(0, top - bottom)
        guard intersection > 0 else {
            return 0
        }

        let lhsArea = max(0, lhs.width) * max(0, lhs.height)
        let rhsArea = max(0, rhs.width) * max(0, rhs.height)
        let union = lhsArea + rhsArea - intersection
        return union <= 0 ? 0 : intersection / union
    }

    func jumpToOutline(_ item: PaperOutlineItem) {
        requestedPageIndex = item.pageIndex
        currentPageIndex = item.pageIndex
        statusMessage = "Jumped to \(item.title)."
    }

    func runVisionOCRForCurrentDocument() {
        guard let pdfDocument, var session else {
            return
        }

        statusMessage = "Running local Apple Vision OCR..."
        Task {
            var blocks: [OCRBlock] = []
            let provider = VisionOCRProvider()
            for index in 0..<pdfDocument.pageCount {
                guard let data = PDFDocumentController.pageImageData(document: pdfDocument, pageIndex: index) else {
                    continue
                }
                do {
                    blocks.append(contentsOf: try await provider.recognizeText(in: OCRRequest(pageIndex: index, imageData: data)))
                } catch {
                    await MainActor.run {
                        self.statusMessage = "OCR failed on page \(index + 1): \(error.localizedDescription)"
                    }
                }
            }

            await MainActor.run {
                session.ocrBlocks = blocks
                session.updatedAt = Date()
                self.session = session
                self.saveCurrentPDFWithHiddenMetadata()
                self.statusMessage = "OCR indexed \(blocks.count) text blocks."
            }
        }
    }

    func runVisionOCRForPage(_ pageIndex: Int) {
        guard let pdfDocument, var session else {
            return
        }
        guard let data = PDFDocumentController.pageImageData(document: pdfDocument, pageIndex: pageIndex) else {
            statusMessage = "Could not render page \(pageIndex + 1) for OCR."
            return
        }

        statusMessage = "Running OCR on page \(pageIndex + 1)..."
        let provider = VisionOCRProvider()
        Task {
            do {
                let blocks = try await provider.recognizeText(in: OCRRequest(pageIndex: pageIndex, imageData: data))
                await MainActor.run {
                    session.ocrBlocks.removeAll { $0.pageIndex == pageIndex }
                    session.ocrBlocks.append(contentsOf: blocks)
                    session.updatedAt = Date()
                    self.persistSession(session, statusMessage: "OCR indexed page \(pageIndex + 1).")
                }
            } catch {
                await MainActor.run {
                    self.statusMessage = "OCR failed on page \(pageIndex + 1): \(error.localizedDescription)"
                }
            }
        }
    }

    private func contextForCurrentSelection(session: DocumentSession) -> DocumentContext {
        let builder = DocumentContextBuilder(session: session)
        let primary: DocumentContext
        switch selectionContext {
        case .text(let text, let pageIndex, _):
            let selected = builder.selectedTextContext(
                selectedText: text,
                pageIndex: pageIndex,
                visualAttachment: selectionImageAttachment
            )
            primary = DocumentContext(
                prompt: "\(paperMemoryPrefix)\n\n\(selected.prompt)",
                citations: selected.citations,
                imageAttachments: selected.imageAttachments
            )
        case .region(let region):
            let selected = builder.regionContext(region, visualAttachment: selectionImageAttachment)
            primary = DocumentContext(
                prompt: "\(paperMemoryPrefix)\n\n\(selected.prompt)",
                citations: selected.citations,
                imageAttachments: selected.imageAttachments
            )
        case nil:
            primary = builder.wholePaperContext()
        }

        return DocumentContextComposer.chatContext(
            primaryTitle: session.title,
            primary: primary,
            additional: additionalTabContexts()
        )
    }

    private var paperMemoryPrefix: String {
        guard !paperMemory.isEmpty else {
            return "Use the whole paper context already loaded in this session."
        }
        return "Whole-paper memory:\n\(paperMemory)"
    }

    private func additionalTabContexts() -> [DocumentContextComposer.AdditionalContext] {
        includedContextTabIDs
            .compactMap { id in
                openTabs.first(where: { $0.id == id && $0.id != activeTabID })
            }
            .map { tab in
                let builder = DocumentContextBuilder(session: tab.session)
                let whole = builder.wholePaperContext(maxCharacters: 36_000)
                let prompt: String
                if tab.paperMemory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    prompt = whole.prompt
                } else {
                    prompt = "Whole-paper memory:\n\(tab.paperMemory)\n\n\(whole.prompt)"
                }
                return DocumentContextComposer.AdditionalContext(
                    title: tab.title,
                    context: DocumentContext(prompt: prompt, citations: whole.citations)
                )
            }
    }

    private func appendChatMessage(_ message: ChatMessage, to tabID: UUID) {
        if activeTabID == tabID {
            chatMessages.append(message)
        }
        if let index = openTabs.firstIndex(where: { $0.id == tabID }) {
            openTabs[index].chatMessages.append(message)
        }
    }

    private func setThinking(_ value: Bool, for tabID: UUID) {
        if activeTabID == tabID {
            isThinking = value
        }
        if let index = openTabs.firstIndex(where: { $0.id == tabID }) {
            openTabs[index].isThinking = value
        }
    }

    func isTemporaryHighlightShowing(for message: ChatMessage) -> Bool {
        visibleChatHighlightToken == Self.chatHighlightToken(for: message)
            && !temporaryHighlightAnnotations.isEmpty
    }

    func toggleTemporaryHighlight(for message: ChatMessage) {
        let token = Self.chatHighlightToken(for: message)
        if visibleChatHighlightToken == token, !temporaryHighlightAnnotations.isEmpty {
            clearTemporaryHighlights()
            statusMessage = "Hid AI relevance highlight."
            return
        }

        applyTemporaryHighlight(for: message.citations, token: token)
    }

    func equationMarkdownLinks(for text: String) -> [EquationMarkdownLink] {
        guard let session else {
            return []
        }

        return EquationReferenceResolver.references(in: text, session: session).map { reference in
            EquationMarkdownLink(
                text: reference.matchedText,
                url: equationReferenceURL(for: reference.citation)
            )
        }
    }

    func openEquationReferenceLink(_ url: URL) {
        guard url.scheme == Self.equationReferenceURLScheme,
              let citation = equationCitation(from: url) else {
            return
        }

        applyTemporaryHighlight(for: [citation])
        statusMessage = "Jumped to \(citation.label) on page \(citation.pageIndex + 1)."
    }

    private func equationReferenceURL(for citation: SourceCitation) -> String {
        var components = URLComponents()
        components.scheme = Self.equationReferenceURLScheme
        components.host = "jump"
        var queryItems = [
            URLQueryItem(name: "page", value: String(citation.pageIndex)),
            URLQueryItem(name: "label", value: citation.label)
        ]
        if let highlightText = citation.highlightText {
            queryItems.append(URLQueryItem(name: "text", value: highlightText))
        }
        if let bounds = citation.bounds {
            queryItems.append(URLQueryItem(name: "x", value: String(bounds.x)))
            queryItems.append(URLQueryItem(name: "y", value: String(bounds.y)))
            queryItems.append(URLQueryItem(name: "w", value: String(bounds.width)))
            queryItems.append(URLQueryItem(name: "h", value: String(bounds.height)))
        }
        components.queryItems = queryItems
        return components.url?.absoluteString ?? ""
    }

    private func equationCitation(from url: URL) -> SourceCitation? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item -> (String, String)? in
            guard let value = item.value else {
                return nil
            }
            return (item.name, value)
        })
        guard let pageValue = query["page"],
              let pageIndex = Int(pageValue) else {
            return nil
        }

        var bounds: NormalizedRect?
        if let xValue = query["x"],
           let yValue = query["y"],
           let widthValue = query["w"],
           let heightValue = query["h"],
           let x = Double(xValue),
           let y = Double(yValue),
           let width = Double(widthValue),
           let height = Double(heightValue) {
            bounds = NormalizedRect(x: x, y: y, width: width, height: height)
        }

        return SourceCitation(
            pageIndex: pageIndex,
            label: query["label"] ?? "equation",
            highlightText: query["text"],
            bounds: bounds
        )
    }

    private static func chatHighlightToken(for message: ChatMessage) -> String {
        "\(message.createdAt.timeIntervalSinceReferenceDate)-\(message.role.rawValue)-\(message.content.hashValue)"
    }

    private func updateSelectionContext(_ context: ReaderSelectionContext) {
        if selectionContext != context {
            suggestionClearTask?.cancel()
            quickSuggestions = []
            lastSuggestedSelection = nil
            quickSuggestionRequestID = UUID()
        }
        selectionContext = context
        if isSelectionHovering {
            isQuickSuggestionVisible = true
            generateQuickSuggestionsIfNeeded(for: context)
        }
    }

    private func clearSelectionSuggestions() {
        selectionContext = nil
        selectionImageAttachment = nil
        isSelectionHovering = false
        isSuggestionPopoverHovering = false
        isQuickSuggestionVisible = false
        quickSuggestionAnchor = nil
        suggestionClearTask?.cancel()
        quickSuggestions = []
        lastSuggestedSelection = nil
        quickSuggestionRequestID = UUID()
    }

    private func selectionDetailForPrompt(_ context: ReaderSelectionContext) -> String {
        guard let attachment = imageAttachmentsForPrompt(context).first else {
            return context.detail
        }

        return """
        \(context.detail)

        Visual crop attached: \(attachment.label). Use the image crop as the primary source for symbol order, superscripts, subscripts, fractions, Greek letters, and equation layout. Return math in LaTeX/Markdown when useful.
        """
    }

    private func imageAttachmentsForPrompt(_ context: ReaderSelectionContext) -> [AIImageAttachment] {
        guard selectionContext == context, let selectionImageAttachment else {
            return []
        }
        return [selectionImageAttachment]
    }

    private func visualAttachmentForSelectedText(
        _ text: String,
        pageIndex: Int,
        bounds: NormalizedRect?
    ) -> AIImageAttachment? {
        guard MathSelectionAnalyzer.shouldAttachImage(selectedText: text),
              let bounds else {
            return nil
        }

        return visualAttachment(
            pageIndex: pageIndex,
            bounds: bounds,
            label: "selected equation or symbol crop"
        )
    }

    private func visualAttachment(
        pageIndex: Int,
        bounds: NormalizedRect,
        label: String
    ) -> AIImageAttachment? {
        guard let pdfDocument,
              let data = PDFDocumentController.pageImageData(
                document: pdfDocument,
                pageIndex: pageIndex,
                crop: bounds
              ) else {
            return nil
        }

        return AIImageAttachment(
            label: label,
            mimeType: "image/png",
            base64Data: data.base64EncodedString()
        )
    }

    private func scheduleLingeringSuggestionRemoval(_ id: UUID) {
        Task { @MainActor in
            guard let group = self.lingeringInlineSuggestionGroups.first(where: { $0.id == id }) else {
                return
            }
            let delay = max(0.1, group.retention.expiresAt.timeIntervalSinceNow)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else {
                return
            }
            guard let latest = self.lingeringInlineSuggestionGroups.first(where: { $0.id == id }) else {
                return
            }
            if self.temporarySuggestionTiming.isExpired(at: Date(), state: latest.retention) {
                withAnimation(.easeOut(duration: 0.8)) {
                    self.lingeringInlineSuggestionGroups.removeAll { $0.id == id }
                }
                self.clearTemporarySourceHighlight(for: id)
            } else {
                self.scheduleLingeringSuggestionRemoval(id)
            }
        }
    }

    private func suggestionsForCurrentSelection() -> [InlineSuggestion] {
        if !quickSuggestions.isEmpty {
            return quickSuggestions
        }
        guard let selectionContext else {
            return []
        }
        return heuristicSuggestions(for: selectionContext)
    }

    private func readableMarginNoteBody(context: ReaderSelectionContext?, suggestions: [InlineSuggestion]) -> String {
        AISuggestionNoteFormatter.marginNote(
            contextTitle: context?.title,
            suggestions: suggestions.map {
                AISuggestionExplanation(prompt: $0.question, explanation: $0.answer)
            }
        )
    }

    private func generateQuickSuggestionsIfNeeded(for context: ReaderSelectionContext) {
        if lastSuggestedSelection == context, !quickSuggestions.isEmpty {
            return
        }
        lastSuggestedSelection = context
        quickSuggestions = heuristicSuggestions(for: context)
        let requestID = UUID()
        quickSuggestionRequestID = requestID

        guard case .hosted(let provider) = resolveAIProvider(agentID: inlineAgentID, purpose: .inlineSuggestion) else {
            return
        }

        let prompt = renderedPrompt(
            .inlineSuggestions,
            values: [
                "paperMemory": paperMemoryPrefix,
                "selectionTitle": context.title,
                "selectionDetail": selectionDetailForPrompt(context)
            ]
        )
        let requestContext = context
        Task {
            do {
                let reply = try await provider.complete(messages: [
                    AIMessage(
                        role: .user,
                        content: prompt,
                        imageAttachments: imageAttachmentsForPrompt(context)
                    )
                ])
                let parsed = Self.parseInlineExplanations(reply.content)
                await MainActor.run {
                    guard self.quickSuggestionRequestID == requestID,
                          self.selectionContext == requestContext else {
                        return
                    }
                    if !parsed.isEmpty {
                        self.quickSuggestions = parsed
                    }
                }
            } catch {
                await MainActor.run {
                    guard self.quickSuggestionRequestID == requestID else {
                        return
                    }
                    self.statusMessage = "Quick suggestions used local fallback: \(error.localizedDescription)"
                }
            }
        }
    }

    private func heuristicSuggestions(for context: ReaderSelectionContext) -> [InlineSuggestion] {
        let candidates: [InlineSuggestionCandidate]
        switch context {
        case .text(let text, let pageIndex, _):
            candidates = InlineSuggestionHeuristics.suggestions(
                forText: text,
                paperMemory: paperMemory,
                pageLabel: "page \(pageIndex + 1)"
            )
        case .region(let region):
            candidates = InlineSuggestionHeuristics.suggestions(
                forRegionKind: region.kind.rawValue,
                detail: context.detail,
                paperMemory: paperMemory
            )
        }
        return candidates.map {
            InlineSuggestion(question: $0.question, answer: $0.answer)
        }
    }

    private func sourceYFraction(for context: ReaderSelectionContext) -> Double? {
        switch context {
        case .text(_, _, let bounds):
            guard let bounds else {
                return nil
            }
            return max(0.06, min(0.94, 1 - (bounds.y + bounds.height / 2)))
        case .region(let region):
            return max(0.06, min(0.94, region.bounds.y + region.bounds.height / 2))
        }
    }

    private func liveSourceYFraction(for context: ReaderSelectionContext) -> Double? {
        switch context {
        case .text(_, let pageIndex, let bounds):
            guard let bounds else {
                return nil
            }
            return liveSourceYFraction(pageIndex: pageIndex, bounds: bounds)
        case .region(let region):
            return liveSourceYFraction(pageIndex: region.pageIndex, bounds: region.bounds)
        }
    }

    private func liveSourceYFraction(for thread: CommentThread) -> Double? {
        switch thread.anchor {
        case .inPage(let rect):
            return liveSourceYFraction(pageIndex: thread.pageIndex, bounds: rect)
        case .pagePoint(let point):
            return liveSourceYFraction(pageIndex: thread.pageIndex, point: point)
        case .outsidePage(let anchor):
            guard pdfViewportSize.height > 1,
                  let frame = pdfViewportSnapshot.pageFrames[thread.pageIndex] else {
                return anchor.y
            }
            return (frame.minY + anchor.y * frame.height) / max(pdfViewportSize.height, 1)
        case .pageOnly:
            return livePageCenterYFraction(pageIndex: thread.pageIndex)
        }
    }

    private func liveSourceXFraction(for context: ReaderSelectionContext) -> Double? {
        switch context {
        case .text(_, let pageIndex, let bounds):
            guard let bounds else {
                return nil
            }
            return liveSourceXFraction(pageIndex: pageIndex, bounds: bounds)
        case .region(let region):
            return liveSourceXFraction(pageIndex: region.pageIndex, bounds: region.bounds)
        }
    }

    private func liveSourceXFraction(for thread: CommentThread) -> Double? {
        switch thread.anchor {
        case .inPage(let rect):
            return liveSourceXFraction(pageIndex: thread.pageIndex, bounds: rect)
        case .pagePoint(let point):
            return liveSourceXFraction(pageIndex: thread.pageIndex, point: point)
        case .outsidePage:
            guard pdfViewportSize.width > 1,
                  let frame = pdfViewportSnapshot.pageFrames[thread.pageIndex] else {
                return nil
            }
            return frame.maxX / max(pdfViewportSize.width, 1)
        case .pageOnly:
            return nil
        }
    }

    private func liveSourceXFraction(pageIndex: Int, bounds: NormalizedRect) -> Double? {
        guard pdfViewportSize.width > 1,
              let frame = pdfViewportSnapshot.pageFrames[pageIndex] else {
            return nil
        }
        let x = frame.minX + (bounds.x + bounds.width) * frame.width
        return x / max(pdfViewportSize.width, 1)
    }

    private func liveSourceXFraction(pageIndex: Int, point: NormalizedPoint) -> Double? {
        guard pdfViewportSize.width > 1,
              let frame = pdfViewportSnapshot.pageFrames[pageIndex] else {
            return nil
        }
        let x = frame.minX + point.x * frame.width
        return x / max(pdfViewportSize.width, 1)
    }

    private func liveSourceYFraction(pageIndex: Int, bounds: NormalizedRect) -> Double? {
        guard pdfViewportSize.height > 1,
              let frame = pdfViewportSnapshot.pageFrames[pageIndex] else {
            return nil
        }
        let topOriginAnchorInPage = 1 - (bounds.y + bounds.height / 2)
        return (frame.minY + topOriginAnchorInPage * frame.height) / max(pdfViewportSize.height, 1)
    }

    private func liveSourceYFraction(pageIndex: Int, point: NormalizedPoint) -> Double? {
        guard pdfViewportSize.height > 1,
              let frame = pdfViewportSnapshot.pageFrames[pageIndex] else {
            return nil
        }
        let topOriginAnchorInPage = 1 - point.y
        return (frame.minY + topOriginAnchorInPage * frame.height) / max(pdfViewportSize.height, 1)
    }

    private func livePageCenterYFraction(pageIndex: Int) -> Double? {
        guard pdfViewportSize.height > 1,
              let frame = pdfViewportSnapshot.pageFrames[pageIndex] else {
            return nil
        }
        return frame.midY / max(pdfViewportSize.height, 1)
    }

    private func answerInlineSuggestion(itemID: UUID, question: String, context: ReaderSelectionContext) {
        switch resolveAIProvider(agentID: inlineAgentID, purpose: .inlineSuggestion) {
        case .hosted(let provider):
            let prompt = renderedPrompt(
                .inlineAnswer,
                values: [
                    "paperMemory": paperMemoryPrefix,
                    "selectionTitle": context.title,
                    "selectionDetail": selectionDetailForPrompt(context),
                    "question": question
                ]
            )
            Task {
                do {
                    let reply = try await provider.complete(messages: [
                        AIMessage(
                            role: .user,
                            content: prompt,
                            imageAttachments: imageAttachmentsForPrompt(context)
                        )
                    ])
                    await MainActor.run {
                        if let index = self.quickSuggestions.firstIndex(where: { $0.id == itemID }) {
                            self.quickSuggestions[index].answer = reply.content
                            self.quickSuggestions[index].isLoading = false
                        }
                    }
                } catch {
                    await MainActor.run {
                        if let index = self.quickSuggestions.firstIndex(where: { $0.id == itemID }) {
                            self.quickSuggestions[index].answer = "Inline answer failed: \(error.localizedDescription)"
                            self.quickSuggestions[index].isLoading = false
                        }
                    }
                }
            }
        case .missingCredential(let message), .localCLI(let message):
            if let index = quickSuggestions.firstIndex(where: { $0.id == itemID }) {
                quickSuggestions[index].answer = "\(message) The selected context is ready."
                quickSuggestions[index].isLoading = false
            }
            return
        }
    }

    private func primePaperMemory() {
        guard let session,
              let activeTabID else {
            paperMemory = ""
            return
        }

        let whole = DocumentContextBuilder(session: session).wholePaperContext(maxCharacters: 24_000).prompt
        setPaperMemory(Self.localPaperMemory(for: session), for: activeTabID)
        guard case .hosted(let provider) = resolveAIProvider(agentID: selectedAgentID, purpose: .sidebarChat) else {
            if self.activeTabID == activeTabID {
                statusMessage = "Loaded whole-paper context locally."
            }
            return
        }

        let prompt = renderedPrompt(.paperMemory, values: ["wholePaper": whole])
        Task {
            do {
                let reply = try await provider.complete(messages: [AIMessage(role: .user, content: prompt)])
                await MainActor.run {
                    self.setPaperMemory(reply.content, for: activeTabID)
                    if self.activeTabID == activeTabID {
                        self.statusMessage = "Loaded whole-paper AI context."
                    }
                }
            } catch {
                await MainActor.run {
                    if self.activeTabID == activeTabID {
                        self.statusMessage = "Using local paper context: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func setPaperMemory(_ memory: String, for tabID: UUID) {
        if activeTabID == tabID {
            paperMemory = memory
        }
        if let index = openTabs.firstIndex(where: { $0.id == tabID }) {
            openTabs[index].paperMemory = memory
        }
    }

    private func applyTemporaryHighlight(for citations: [SourceCitation], token: String? = nil) {
        clearTemporaryHighlights()
        guard !citations.isEmpty, let pdfDocument else {
            return
        }

        var highlightedPages = Set<Int>()
        for citation in citations.prefix(6) {
            guard let page = pdfDocument.page(at: citation.pageIndex) else {
                continue
            }
            if addPreciseTemporaryHighlight(for: citation, on: page) {
                highlightedPages.insert(citation.pageIndex)
                continue
            }
            guard !highlightedPages.contains(citation.pageIndex), highlightedPages.count < 3 else {
                continue
            }
            let pageBounds = page.bounds(for: .mediaBox).insetBy(dx: 18, dy: 18)
            let annotation = PDFAnnotation(bounds: pageBounds, forType: .square, withProperties: nil)
            annotation.color = NSColor.systemYellow.withAlphaComponent(0.55)
            annotation.border = PDFBorder()
            annotation.border?.lineWidth = 3
            annotation.contents = "Temporary AI relevance highlight"
            page.addAnnotation(annotation)
            temporaryHighlightAnnotations.append((page, annotation))
            highlightedPages.insert(citation.pageIndex)
        }

        if let first = citations.first {
            requestedPageIndex = first.pageIndex
            if !temporaryHighlightAnnotations.isEmpty {
                visibleChatHighlightToken = token
            }
            statusMessage = "Temporarily highlighted likely relevant text on page \(first.pageIndex + 1)."
        }
    }

    private func addPreciseTemporaryHighlight(for citation: SourceCitation, on page: PDFPage) -> Bool {
        if let bounds = citation.bounds {
            let pageBounds = page.bounds(for: .mediaBox)
            let rect = CGRect(
                x: pageBounds.minX + bounds.x * pageBounds.width,
                y: pageBounds.minY + bounds.y * pageBounds.height,
                width: bounds.width * pageBounds.width,
                height: bounds.height * pageBounds.height
            ).insetBy(dx: -2, dy: -2)
            let annotation = PDFAnnotationFactory.makeRoundedHighlight(
                bounds: rect,
                color: NSColor.systemYellow,
                alpha: 0.42,
                contents: "Temporary AI relevance highlight"
            )
            page.addAnnotation(annotation)
            temporaryHighlightAnnotations.append((page, annotation))
            return true
        }

        guard let text = citation.highlightText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty,
              let selection = selection(on: page, matching: text) else {
            return false
        }

        let selections = selection.selectionsByLine().isEmpty ? [selection] : selection.selectionsByLine()
        var added = false
        for lineSelection in selections {
            let bounds = lineSelection.bounds(for: page).insetBy(dx: -2, dy: -1)
            guard bounds.width > 1, bounds.height > 1 else {
                continue
            }
            let annotation = PDFAnnotationFactory.makeRoundedHighlight(
                bounds: bounds,
                color: NSColor.systemYellow,
                alpha: 0.42,
                contents: "Temporary AI relevance highlight: \(text)"
            )
            page.addAnnotation(annotation)
            temporaryHighlightAnnotations.append((page, annotation))
            added = true
        }
        return added
    }

    private func selection(on page: PDFPage, matching text: String) -> PDFSelection? {
        guard let pageText = page.string,
              let range = pageText.range(of: text, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return nil
        }
        return page.selection(for: NSRange(range, in: pageText))
    }

    private func clearTemporaryHighlights() {
        for item in temporaryHighlightAnnotations {
            item.page.removeAnnotation(item.annotation)
        }
        temporaryHighlightAnnotations.removeAll()
        visibleChatHighlightToken = nil
    }

    private func applyTemporarySourceHighlight(for group: LingeringInlineSuggestionGroup) {
        clearTemporarySourceHighlight(for: group.id)
        guard let pdfDocument else {
            return
        }

        let pageIndex = group.context.pageIndex
        guard let page = pdfDocument.page(at: pageIndex),
              let bounds = group.context.sourceBounds else {
            return
        }

        let pageBounds = page.bounds(for: .mediaBox)
        let rect = CGRect(
            x: pageBounds.minX + bounds.x * pageBounds.width,
            y: pageBounds.minY + bounds.y * pageBounds.height,
            width: bounds.width * pageBounds.width,
            height: bounds.height * pageBounds.height
        ).insetBy(dx: -2, dy: -2)

        let annotation = PDFAnnotationFactory.makeRoundedHighlight(
            bounds: rect,
            color: NSColor(hex: group.colorHex) ?? .systemYellow,
            alpha: 0.34,
            contents: "Temporary AI source highlight"
        )
        page.addAnnotation(annotation)
        temporarySuggestionHighlightAnnotations[group.id] = [(page, annotation)]
    }

    private func clearTemporarySourceHighlight(for id: UUID) {
        guard let items = temporarySuggestionHighlightAnnotations.removeValue(forKey: id) else {
            return
        }
        for item in items {
            item.page.removeAnnotation(item.annotation)
        }
    }

    private func clearTemporarySourceHighlights() {
        for id in Array(temporarySuggestionHighlightAnnotations.keys) {
            clearTemporarySourceHighlight(for: id)
        }
    }

    nonisolated private static func parseInlineExplanations(_ text: String) -> [InlineSuggestion] {
        let explanationItems = text
            .components(separatedBy: .newlines)
            .map { line in
                line
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: #"^[-*•]\s*"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"^\d+[\.)]\s*"#, with: "", options: .regularExpression)
            }
            .filter { !$0.isEmpty }
            .filter { !$0.localizedCaseInsensitiveContains("Q:") }
            .filter { !$0.localizedCaseInsensitiveContains("Question:") }
            .map { line in
                line.hasPrefix("A:")
                    ? String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                    : line
            }
            .filter { !$0.isEmpty }

        if !explanationItems.isEmpty {
            return Array(explanationItems.prefix(3)).map {
                InlineSuggestion(question: "", answer: $0)
            }
        }

        let collapsed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else {
            return []
        }
        return [InlineSuggestion(question: "", answer: collapsed)]
    }

    private static func inlineQuestionFallbacks(for context: ReaderSelectionContext?) -> [String] {
        guard let context else {
            return []
        }
        switch context {
        case .text(let text, _, _):
            let selected = text
                .split(whereSeparator: \.isWhitespace)
                .prefix(8)
                .joined(separator: " ")
            guard !selected.isEmpty else {
                return []
            }
            return [
                "Explain \(selected) in context",
                "Where is \(selected) defined?",
                "How does \(selected) support the result?"
            ]
        case .region(let region):
            let kind = region.kind.rawValue
            return [
                "Explain this \(kind)",
                "What does this \(kind) show?",
                "How does this \(kind) support the result?"
            ]
        }
    }

    private func syncActiveTabState() {
        guard !isLoadingTabState,
              let activeTabID,
              let index = openTabs.firstIndex(where: { $0.id == activeTabID }),
              let pdfDocument,
              let session,
              let currentPDFURL else {
            return
        }
        openTabs[index].pdfURL = currentPDFURL
        openTabs[index].pdfDocument = pdfDocument
        openTabs[index].session = session
        openTabs[index].currentPageIndex = currentPageIndex
        openTabs[index].pdfScaleFactor = pdfScaleFactor
        openTabs[index].pdfAutoScales = pdfAutoScales
        openTabs[index].paperOutline = paperOutline
        openTabs[index].paperMemory = paperMemory
        openTabs[index].chatMessages = chatMessages
        openTabs[index].chatInput = chatInput
        openTabs[index].includedContextTabIDs = validIncludedContextTabIDs(includedContextTabIDs, activeTabID: activeTabID)
        openTabs[index].isThinking = isThinking
    }

    private func loadActiveTabState() {
        guard let activeTabID,
              let tab = openTabs.first(where: { $0.id == activeTabID }) else {
            return
        }
        isLoadingTabState = true
        pdfDocument = tab.pdfDocument
        session = tab.session
        currentPDFURL = tab.pdfURL
        currentPageIndex = tab.currentPageIndex
        pdfScaleFactor = tab.pdfScaleFactor
        pdfAutoScales = tab.pdfAutoScales
        paperOutline = tab.paperOutline
        paperMemory = tab.paperMemory
        chatMessages = tab.chatMessages
        chatInput = tab.chatInput
        includedContextTabIDs = validIncludedContextTabIDs(tab.includedContextTabIDs, activeTabID: tab.id)
        isThinking = tab.isThinking
        requestedPageIndex = tab.currentPageIndex
        findResults = []
        findResultIndex = nil
        isJumpCommandVisible = false
        jumpCommandInput = ""
        lingeringInlineSuggestionGroups = []
        clearTemporarySourceHighlights()
        clearSelectionSuggestions()
        isLoadingTabState = false
    }

    private func validIncludedContextTabIDs(_ ids: Set<UUID>, activeTabID: UUID) -> Set<UUID> {
        Set(ids.filter { id in
            id != activeTabID && openTabs.contains(where: { $0.id == id })
        })
    }

    private func downloadAndOpenLinkedPaperPDF(from url: URL, sourcePaperURL: URL?) {
        Task {
            do {
                guard let pdfURL = try await Self.resolveLinkedPDFURL(for: url) else {
                    await MainActor.run {
                        self.statusMessage = "Opened link in browser. No paper PDF was found automatically."
                    }
                    return
                }

                let destination = Self.linkedPDFDestination(for: pdfURL, sourcePaperURL: sourcePaperURL)
                if FileManager.default.fileExists(atPath: destination.path) {
                    await MainActor.run {
                        self.open(url: destination)
                        self.statusMessage = "Opened existing linked PDF \(destination.lastPathComponent)."
                    }
                    return
                }

                await MainActor.run {
                    self.statusMessage = "Downloading linked paper PDF..."
                }
                let temporaryURL = try await Self.downloadPDF(from: pdfURL)
                try FileManager.default.createDirectory(
                    at: destination.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try FileManager.default.moveItem(at: temporaryURL, to: destination)
                await MainActor.run {
                    self.open(url: destination)
                    self.statusMessage = "Downloaded and opened linked PDF \(destination.lastPathComponent)."
                }
            } catch {
                await MainActor.run {
                    self.statusMessage = "Opened link in browser. Could not download a paper PDF: \(error.localizedDescription)"
                }
            }
        }
    }

    nonisolated private static func resolveLinkedPDFURL(for url: URL) async throws -> URL? {
        if let directPDFURL = LinkedPaperPDFResolver.directPDFURL(for: url) {
            return directPDFURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            throw NSError(domain: "AIReader.LinkedPaper", code: http.statusCode)
        }
        if let mimeType = response.mimeType?.lowercased(),
           mimeType.contains("pdf") {
            return url
        }
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return nil
        }
        return LinkedPaperPDFResolver.pdfURL(inHTML: html, pageURL: url)
    }

    nonisolated private static func downloadPDF(from url: URL) async throws -> URL {
        let (temporaryURL, response) = try await URLSession.shared.download(from: url)
        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            throw NSError(domain: "AIReader.LinkDownload", code: http.statusCode)
        }
        if let mimeType = response.mimeType?.lowercased(),
           !mimeType.contains("pdf"),
           url.pathExtension.lowercased() != "pdf" {
            throw NSError(domain: "AIReader.LinkDownload", code: -2)
        }
        return temporaryURL
    }

    nonisolated private static func linkedPDFDestination(for pdfURL: URL, sourcePaperURL: URL?) -> URL {
        if let sourcePaperURL {
            return LinkedPaperPDFResolver.destinationURL(forPDFURL: pdfURL, sourcePaperURL: sourcePaperURL)
        }
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("uprakigo/LinkedPapers", isDirectory: true)
        let placeholderSource = directory.appendingPathComponent("linked-paper.pdf")
        return LinkedPaperPDFResolver.destinationURL(forPDFURL: pdfURL, sourcePaperURL: placeholderSource)
    }

    private static func clampedCommentDisplayYOffset(_ yOffset: Double) -> Double {
        min(1, max(-1, yOffset))
    }

    private static func localPaperMemory(for session: DocumentSession) -> String {
        let whole = DocumentContextBuilder(session: session).wholePaperContext(maxCharacters: 24_000).prompt
        return String(whole.prefix(8_000))
    }

    private static func normalizeLegacyAICommentBodies(in session: DocumentSession) -> (session: DocumentSession, didChange: Bool) {
        var updated = session
        var didChange = false

        for commentIndex in updated.comments.indices {
            for messageIndex in updated.comments[commentIndex].messages.indices {
                let body = updated.comments[commentIndex].messages[messageIndex].body
                let normalized = AISuggestionNoteFormatter.commentBodyForDisplay(body)
                if normalized != body {
                    updated.comments[commentIndex].messages[messageIndex].body = normalized
                    didChange = true
                }
            }
        }

        if didChange {
            updated.updatedAt = Date()
        }
        return (updated, didChange)
    }

    private func nearbyText(on pageIndex: Int) -> String {
        guard let session else {
            return ""
        }

        let embedded = session.pages.first(where: { $0.index == pageIndex })?.embeddedText ?? ""
        let ocr = session.ocrBlocks
            .filter { $0.pageIndex == pageIndex }
            .map(\.text)
            .joined(separator: "\n")
        return [embedded, ocr]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .prefix(2_000)
            .description
    }

    private func resolveAIProvider(agentID: String, purpose: AIModelPurpose) -> AIProviderResolution {
        if agentID.hasPrefix("deepseek") {
            guard !deepSeekAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .missingCredential("Add a DeepSeek API key in Preferences, or set DEEPSEEK_API_KEY in the environment.")
            }
            let model = agentID == Self.deepSeekFlashAgentID ? deepSeekFastModel : deepSeekChatModel
            let displayName = agentID == Self.deepSeekFlashAgentID
                ? deepSeekDisplayName(for: model, defaultName: "DeepSeek V4 Flash")
                : deepSeekDisplayName(for: model, defaultName: "DeepSeek V4 Pro")
            return .hosted(DeepSeekProvider(apiKey: deepSeekAPIKey, model: model, displayName: displayName))
        }

        if agentID == Self.geminiChatAgentID || agentID == Self.geminiFastAgentID {
            guard !geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .missingCredential("Add a Gemini API key in Preferences, or set GEMINI_API_KEY in the environment.")
            }
            let model = agentID == Self.geminiFastAgentID ? geminiFastModel : geminiChatModel
            let displayName: String
            switch purpose {
            case .sidebarChat:
                displayName = "Gemini \(model)"
            case .inlineSuggestion:
                displayName = "Gemini Fast \(model)"
            }
            return .hosted(GeminiProvider(apiKey: geminiAPIKey, model: model, displayName: displayName))
        }

        if let localAgent = LocalAgentProvider(
            configuredExecutables: configuredLocalAgentExecutables()
        )
        .availableAgents()
        .first(where: { $0.profile.id == agentID }) {
            let effort: LocalAgentThinkingEffort
            switch purpose {
            case .sidebarChat:
                effort = chatThinkingEffort
            case .inlineSuggestion:
                effort = inlineThinkingEffort
            }
            return .hosted(
                LocalCLIProvider(
                    profile: localAgent.profile,
                    executableURL: localAgent.executableURL,
                    effort: effort,
                    codexFastMode: localAgent.profile.model == "codex" && codexFastModeEnabled,
                    codexModelName: localAgent.profile.model == "codex" ? codexModelName(for: purpose) : "",
                    claudeModelName: localAgent.profile.model == "claude" ? claudeModelName : ""
                )
            )
        }

        return .missingCredential("Set the local Codex or Claude CLI path in the sidebar or Preferences, then update agents.")
    }

    private func codexModelName(for purpose: AIModelPurpose) -> String {
        switch purpose {
        case .sidebarChat:
            return codexModelName
        case .inlineSuggestion:
            return codexInlineModelName
        }
    }

    private func renderedPrompt(_ key: AIPromptTemplateKey, values: [String: String]) -> String {
        let template = AIPromptTemplates.effectiveTemplate(
            override: promptTemplate(for: key),
            for: key
        )
        return AIPromptTemplates.render(template, values: values)
    }

    private func configuredLocalAgentExecutables() -> [String: URL] {
        var executables: [String: URL] = [:]
        let codexPath = codexCLIPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let claudePath = claudeCLIPath.trimmingCharacters(in: .whitespacesAndNewlines)

        if !codexPath.isEmpty {
            executables["codex"] = URL(fileURLWithPath: codexPath)
        }
        if !claudePath.isEmpty {
            executables["claude"] = URL(fileURLWithPath: claudePath)
        }

        return executables
    }

    private static func resolveDeepSeekConfiguration(
        storedAPIKey: String?,
        storedChatModel: String?,
        storedFastModel: String?
    ) -> DeepSeekConfiguration {
        let environment = environmentIncludingLaunchctlValues(for: [
            "DEEPSEEK_API_KEY",
            "DEEPSEEK_MODEL",
            "DEEPSEEK_MODEL_FAST"
        ])
        return DeepSeekConfigurationResolver.resolve(
            environment: environment,
            storedAPIKey: storedAPIKey,
            storedChatModel: storedChatModel,
            storedFastModel: storedFastModel
        )
    }

    private static func resolveGeminiConfiguration(
        storedAPIKey: String?,
        storedChatModel: String?,
        storedFastModel: String?
    ) -> GeminiConfiguration {
        let environment = environmentIncludingLaunchctlValues(for: [
            "GEMINI_API_KEY",
            "GEMINI_MODEL",
            "GEMINI_MODEL_FAST"
        ])
        return GeminiConfigurationResolver.resolve(
            environment: environment,
            storedAPIKey: storedAPIKey,
            storedChatModel: storedChatModel,
            storedFastModel: storedFastModel
        )
    }

    nonisolated private static func environmentIncludingLaunchctlValues(for keys: [String]) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        for key in keys {
            let processValue = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if processValue.isEmpty {
                let launchctlValue = readLaunchctlEnvironmentValue(key)
                if !launchctlValue.isEmpty {
                    environment[key] = launchctlValue
                }
            }
        }
        return environment
    }

    private static func storedPromptOverride(for key: AIPromptTemplateKey) -> String {
        let stored = UserDefaults.standard.string(forKey: promptTemplateDefaultsKey(for: key)) ?? ""
        if stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ""
        }
        if stored == AIPromptTemplates.defaultTemplate(for: key) {
            return ""
        }
        return stored
    }

    private static func persistPromptTemplate(_ template: String, for key: AIPromptTemplateKey) {
        let defaultsKey = promptTemplateDefaultsKey(for: key)
        if template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || template == AIPromptTemplates.defaultTemplate(for: key) {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        } else {
            UserDefaults.standard.set(template, forKey: defaultsKey)
        }
    }

    private static func persistOptionalDefault(_ value: String, forKey key: String) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedValue.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(trimmedValue, forKey: key)
        }
    }

    private static func storedThinkingEffort(
        forKey key: String,
        defaultValue: LocalAgentThinkingEffort
    ) -> LocalAgentThinkingEffort {
        guard let rawValue = UserDefaults.standard.string(forKey: key),
              let effort = LocalAgentThinkingEffort(rawValue: rawValue) else {
            return defaultValue
        }
        return effort
    }

    nonisolated private static func storedAPICredential(for descriptor: ProviderCredentialDescriptor) -> String {
        if isEnvironmentCredentialAvailable(for: descriptor) {
            return ""
        }

        let keychainStore = KeychainCredentialStore()
        if let keychainValue = try? keychainStore.readCredential(for: descriptor),
           !keychainValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmedValue = keychainValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.removeObject(forKey: descriptor.legacyDefaultsKey)
            return trimmedValue
        }

        let legacyValue = UserDefaults.standard
            .string(forKey: descriptor.legacyDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !legacyValue.isEmpty else {
            UserDefaults.standard.removeObject(forKey: descriptor.legacyDefaultsKey)
            return ""
        }

        do {
            try keychainStore.saveCredential(legacyValue, for: descriptor)
            UserDefaults.standard.removeObject(forKey: descriptor.legacyDefaultsKey)
        } catch {
            return legacyValue
        }

        return legacyValue
    }

    private static func persistAPICredential(
        _ value: String,
        for descriptor: ProviderCredentialDescriptor
    ) -> Bool {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedValue.isEmpty, isEnvironmentCredentialAvailable(for: descriptor) {
            return true
        }

        let keychainStore = KeychainCredentialStore()

        do {
            if trimmedValue.isEmpty {
                try keychainStore.deleteCredential(for: descriptor)
            } else {
                try keychainStore.saveCredential(trimmedValue, for: descriptor)
            }
            UserDefaults.standard.removeObject(forKey: descriptor.legacyDefaultsKey)
            return true
        } catch {
            return false
        }
    }

    nonisolated private static func isEnvironmentCredentialAvailable(for descriptor: ProviderCredentialDescriptor) -> Bool {
        let environment = environmentIncludingLaunchctlValues(for: [descriptor.environmentVariableName])
        let value = environment[descriptor.environmentVariableName]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !value.isEmpty
    }

    private static func promptTemplateDefaultsKey(for key: AIPromptTemplateKey) -> String {
        "AIPromptTemplate.\(key.rawValue)"
    }

    nonisolated private static func readLaunchctlEnvironmentValue(_ name: String) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["getenv", name]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }

        guard process.terminationStatus == 0 else {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

private extension NormalizedRect {
    func approximatelyEquals(_ other: NormalizedRect, tolerance: Double = 0.0005) -> Bool {
        abs(x - other.x) <= tolerance
            && abs(y - other.y) <= tolerance
            && abs(width - other.width) <= tolerance
            && abs(height - other.height) <= tolerance
    }
}

private extension AIPromptTemplateKey {
    var displayTitle: String {
        switch self {
        case .sidebarSystem:
            return "sidebar system"
        case .sidebarUser:
            return "sidebar chat"
        case .paperMemory:
            return "paper memory"
        case .inlineSuggestions:
            return "inline suggestions"
        case .inlineAnswer:
            return "inline answer"
        }
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
