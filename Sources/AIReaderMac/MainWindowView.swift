import PaperReaderCore
import AppKit
import PDFKit
import SwiftUI
import WebKit

struct MainWindowView: View {
    @EnvironmentObject private var state: ReaderAppState

    var body: some View {
        VStack(spacing: 0) {
            ReaderChromeTabStrip()
            HStack {
                Spacer(minLength: 0)
                ReaderTopToolStrip()
            }
            .background(.bar)

            HSplitView {
                SourceListView()
                    .frame(minWidth: 178, idealWidth: 205, maxWidth: 300)

                HSplitView {
                    ReaderPaneView()
                        .frame(minWidth: 520)
                    AISidebarView()
                        .frame(minWidth: 180, idealWidth: 220, maxWidth: 340)
                }
                .frame(minWidth: 700)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Text(state.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let session = state.session {
                    Text("\(session.pages.count) pages")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)
        }
        .background(WindowChromeConfigurator())
        .background(KeyCommandMonitor(
            selectionShortcutBindings: state.selectionShortcutBindings,
            onTemporaryStay: {
                state.keepCurrentSuggestionsTemporarily()
            },
            onSaveComment: {
                state.saveCurrentSuggestionsAsComment()
            },
            onSelectionShortcut: { action in
                state.performSelectionShortcut(action)
            },
            onUndo: {
                state.undoDocumentEdit()
            },
            onRedo: {
                state.redoDocumentEdit()
            },
            onFindCommand: {
                state.focusFindField()
            },
            onJumpCommand: {
                state.showJumpCommand()
            },
            onDeleteSelectedComment: {
                state.deleteSelectedComment()
            }
        ))
        .overlay(alignment: .top) {
            JumpCommandBox()
                .padding(.top, 58)
        }
    }
}

private struct ReaderChromeTabStrip: View {
    @EnvironmentObject private var state: ReaderAppState

    var body: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(state.openTabs) { tab in
                        ReaderChromeTab(tab: tab)
                    }
                }
                .padding(.leading, 8)
                .padding(.vertical, 4)
            }

            Button {
                state.presentOpenPanel()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Open PDF in New Tab")
            .delayedIconTooltip("New Tab")
            .padding(.trailing, 8)
        }
        .frame(height: 38)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct ReaderChromeTab: View {
    @EnvironmentObject private var state: ReaderAppState
    let tab: ReaderDocumentTab

    private var isActive: Bool {
        tab.id == state.activeTabID
    }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: isActive ? "doc.fill" : "doc")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)

            Text(tab.title)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                state.closeTab(tab.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 17, height: 17)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.secondary)
            .help("Close Tab")
        }
        .padding(.leading, 10)
        .padding(.trailing, 5)
        .frame(width: 190, height: 30)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color(nsColor: .textBackgroundColor) : Color.secondary.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.secondary.opacity(0.24) : Color.secondary.opacity(0.12), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            state.selectTab(tab.id)
        }
        .contextMenu {
            Button("Open in Split View") {
                state.splitView(withTab: tab.id)
            }
            .disabled(state.openTabs.count < 2)

            Button("Move Tab to New Window") {
                state.moveTabToNewWindow(tab.id)
            }

            Divider()

            Button("Close Tab") {
                state.closeTab(tab.id)
            }
        }
        .accessibilityLabel(Text(tab.title))
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}

private struct ReaderTopToolStrip: View {
    @EnvironmentObject private var state: ReaderAppState
    @FocusState private var isFindFieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            IconActionButton(
                systemName: "doc.badge.plus",
                title: "Open PDF"
            ) {
                state.presentOpenPanel()
            }

            verticalDivider

            ForEach(ReaderTool.allCases) { tool in
                ReaderToolButton(tool: tool)
            }

            verticalDivider

            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                TextField("Find", text: $state.findQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                    .focused($isFindFieldFocused)
                    .onSubmit {
                        state.performFind()
                    }
                    .onChange(of: state.findQuery) { _ in
                        state.updateFindResults(jumpToFirst: false)
                    }
                Text(state.findResultSummary)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .trailing)
                IconActionButton(
                    systemName: "chevron.up",
                    title: "Previous Result",
                    isDisabled: state.findResults.isEmpty
                ) {
                    state.findPrevious()
                }
                IconActionButton(
                    systemName: "chevron.down",
                    title: "Next Result",
                    isDisabled: state.findResults.isEmpty
                ) {
                    state.findNext()
                }
            }
            .onChange(of: state.findFocusToken) { _ in
                isFindFieldFocused = true
            }

            verticalDivider

            IconActionButton(
                systemName: "text.viewfinder",
                title: "OCR",
                isDisabled: state.pdfDocument == nil
            ) {
                state.runVisionOCRForCurrentDocument()
            }

            IconActionButton(
                systemName: "rectangle.split.2x1",
                title: "Split View",
                isDisabled: state.openTabs.count < 2
            ) {
                state.toggleSplitView()
            }

            verticalDivider

            IconActionButton(
                systemName: "minus.magnifyingglass",
                title: "Zoom Out",
                isDisabled: state.pdfDocument == nil
            ) {
                state.zoomPDFOut()
            }

            Text("\(Int(state.pdfScaleFactor * 100))%")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 42)

            IconActionButton(
                systemName: "arrow.up.left.and.down.right.magnifyingglass",
                title: "Fit PDF",
                isDisabled: state.pdfDocument == nil
            ) {
                state.fitPDFToWidth()
            }

            IconActionButton(
                systemName: "plus.magnifyingglass",
                title: "Zoom In",
                isDisabled: state.pdfDocument == nil
            ) {
                state.zoomPDFIn()
            }

            verticalDivider

            IconActionButton(
                systemName: "square.and.arrow.down",
                title: "Save",
                isDisabled: state.session == nil
            ) {
                state.saveCurrentPDFWithHiddenMetadata()
            }

            IconActionButton(
                systemName: "square.and.arrow.up",
                title: "Export PDF",
                isDisabled: state.session == nil
            ) {
                state.presentExportPanel()
            }

        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(height: 42)
        .fixedSize(horizontal: true, vertical: false)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.22))
            .frame(width: 1, height: 22)
            .padding(.horizontal, 2)
    }
}

private struct IconActionButton: View {
    let systemName: String
    let title: String
    var isDisabled = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .regular))
                .frame(width: 23, height: 23)
                .padding(4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isDisabled ? Color.secondary.opacity(0.45) : Color.primary)
        .disabled(isDisabled)
        .help(title)
        .delayedIconTooltip(title)
        .accessibilityLabel(Text(title))
    }
}

private struct JumpCommandBox: View {
    @EnvironmentObject private var state: ReaderAppState
    @FocusState private var isFocused: Bool

    var body: some View {
        if state.isJumpCommandVisible {
            HStack(spacing: 8) {
                Image(systemName: "arrow.turn.down.right")
                    .foregroundStyle(.secondary)
                TextField("Page, eq 12, fig 2, table 1", text: $state.jumpCommandInput)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit {
                        state.submitJumpCommand()
                    }
                Button {
                    state.cancelJumpCommand()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(width: 330)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 12, y: 4)
            .onAppear {
                isFocused = true
            }
            .onChange(of: state.jumpCommandFocusToken) { _ in
                isFocused = true
            }
        }
    }
}

private struct ReaderColorChoice: Identifiable {
    var id: String { colorHex }
    let name: String
    let colorHex: String
}

private let highlightColorChoices = [
    ReaderColorChoice(name: "Yellow", colorHex: "#F7D154"),
    ReaderColorChoice(name: "Green", colorHex: "#B7C824"),
    ReaderColorChoice(name: "Blue", colorHex: "#3B82F6"),
    ReaderColorChoice(name: "Purple", colorHex: "#8B5CF6"),
    ReaderColorChoice(name: "Orange", colorHex: "#F59E0B"),
    ReaderColorChoice(name: "Red", colorHex: "#D13B3B")
]

private let commentColorChoices = [
    ReaderColorChoice(name: "Gray", colorHex: CommentThread.defaultColorHex),
    ReaderColorChoice(name: "Highlight Green", colorHex: CommentThread.attachedColorHex),
    ReaderColorChoice(name: "Blue", colorHex: "#3B82F6"),
    ReaderColorChoice(name: "Purple", colorHex: "#8B5CF6"),
    ReaderColorChoice(name: "Orange", colorHex: "#F59E0B"),
    ReaderColorChoice(name: "Red", colorHex: "#D13B3B")
]

private struct ColorChoiceMenuLabel: View {
    let choice: ReaderColorChoice
    let isSelected: Bool

    var body: some View {
        Label {
            Text(isSelected ? "\(choice.name) Selected" : choice.name)
        } icon: {
            Circle()
                .fill(Color(hex: choice.colorHex) ?? .secondary)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
        }
    }
}

private struct DelayedIconTooltipModifier: ViewModifier {
    let title: String
    @State private var isHovering = false
    @State private var showsTooltip = false
    @State private var tooltipTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovering = hovering
                tooltipTask?.cancel()
                if hovering {
                    tooltipTask = Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1))
                        guard !Task.isCancelled, isHovering else {
                            return
                        }
                        showsTooltip = true
                    }
                } else {
                    showsTooltip = false
                }
            }
            .popover(isPresented: $showsTooltip, arrowEdge: .bottom) {
                Text(title)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
            }
            .onDisappear {
                tooltipTask?.cancel()
            }
    }
}

private extension View {
    func delayedIconTooltip(_ title: String) -> some View {
        modifier(DelayedIconTooltipModifier(title: title))
    }
}

private func colorHexesMatch(_ lhs: String, _ rhs: String) -> Bool {
    lhs.trimmingCharacters(in: .whitespacesAndNewlines)
        .caseInsensitiveCompare(rhs.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
}

private struct ReaderToolButton: View {
    @EnvironmentObject private var state: ReaderAppState
    let tool: ReaderTool

    private var isActive: Bool {
        state.selectedTool == tool
    }

    private var isLocked: Bool {
        isActive && state.toolActivationMode == .locked
    }

    private var activeColor: Color {
        if tool == .highlight {
            return Color(hex: state.highlightColorHex) ?? .accentColor
        }
        return .accentColor
    }

    var body: some View {
        Group {
            if tool == .highlight {
                RightClickableSwiftUIView(menuProvider: makeHighlightColorMenu) {
                    buttonContent
                }
            } else {
                buttonContent
            }
        }
    }

    private var buttonContent: some View {
        ToolIconView(
            tool: tool,
            isActive: isActive,
            highlightColor: Color(hex: state.highlightColorHex) ?? .yellow
        )
            .frame(width: 23, height: 23)
            .padding(4)
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(isActive ? activeColor.opacity(isLocked ? 0.20 : 0.11) : Color.clear)
            }
            .overlay(alignment: .bottomTrailing) {
                if isLocked {
                    Circle()
                        .fill(activeColor)
                        .frame(width: 5, height: 5)
                        .offset(x: 1.5, y: 1.5)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                TapGesture(count: 2)
                    .onEnded {
                        state.activateTool(tool, gesture: .doubleClick)
                    }
                    .exclusively(before:
                        TapGesture(count: 1)
                            .onEnded {
                                state.activateTool(tool, gesture: .singleClick)
                            }
                    )
            )
            .help(toolHelp)
            .delayedIconTooltip(tool.title)
            .accessibilityLabel(Text(tool.title))
            .accessibilityAddTraits(.isButton)
    }

    private func makeHighlightColorMenu() -> NSMenu? {
        let menu = NSMenu()
        menu.allowsContextMenuPlugIns = false
        for choice in highlightColorChoices {
            let isSelected = colorHexesMatch(state.highlightColorHex, choice.colorHex)
            menu.addClosureItem(title: isSelected ? "\(choice.name) Selected" : choice.name) {
                Task { @MainActor in
                    state.updateHighlightColor(choice.colorHex)
                }
            }
        }
        return menu
    }

    private var toolHelp: String {
        if isLocked {
            return "\(tool.title) locked. Single-click to return to preview mode."
        }
        return "\(tool.title). Single-click for one use, double-click to lock."
    }
}

private struct RightClickableSwiftUIView<Content: View>: NSViewRepresentable {
    var menuProvider: () -> NSMenu?
    @ViewBuilder var content: () -> Content

    func makeNSView(context: Context) -> RightClickableHostingView<Content> {
        let view = RightClickableHostingView(rootView: content())
        view.menuProvider = menuProvider
        return view
    }

    func updateNSView(_ nsView: RightClickableHostingView<Content>, context: Context) {
        nsView.rootView = content()
        nsView.menuProvider = menuProvider
    }
}

private final class RightClickableHostingView<Content: View>: NSHostingView<Content> {
    var menuProvider: () -> NSMenu? = { nil }

    override func menu(for event: NSEvent) -> NSMenu? {
        menuProvider()
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = menuProvider() else {
            super.rightMouseDown(with: event)
            return
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}

private final class ToolbarClosureMenuItem: NSMenuItem {
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
        addItem(ToolbarClosureMenuItem(title: title, handler: handler))
    }
}

private struct ToolIconView: View {
    let tool: ReaderTool
    let isActive: Bool
    let highlightColor: Color

    var body: some View {
        if tool == .magicWand {
            MagicWandToolbarIcon(isActive: isActive)
        } else {
            Image(systemName: tool.symbolName)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(iconColor)
        }
    }

    private var iconColor: Color {
        if tool == .highlight {
            return highlightColor
        }
        return isActive ? Color.accentColor : Color.primary
    }
}

private struct MagicWandToolbarIcon: View {
    let isActive: Bool

    var body: some View {
        Canvas { context, size in
            let accent = isActive ? Color.accentColor : Color.primary
            let metal = isActive ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(0.55)
            let gold = Color(red: 0.78, green: 0.58, blue: 0.22)
            let start = CGPoint(x: size.width * 0.16, y: size.height * 0.86)
            let end = CGPoint(x: size.width * 0.84, y: size.height * 0.16)
            var wand = Path()
            wand.move(to: start)
            wand.addLine(to: end)
            context.stroke(
                wand,
                with: .color(accent),
                style: StrokeStyle(lineWidth: max(2.8, size.width * 0.13), lineCap: .round)
            )

            for point in [
                CGPoint(x: size.width * 0.40, y: size.height * 0.61),
                CGPoint(x: size.width * 0.56, y: size.height * 0.44),
                CGPoint(x: size.width * 0.70, y: size.height * 0.30)
            ] {
                let radius = size.width * 0.105
                let circle = Path(ellipseIn: CGRect(
                    x: point.x - radius,
                    y: point.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
                context.fill(circle, with: .color(metal))
                context.stroke(circle, with: .color(Color.white.opacity(isActive ? 0.65 : 0.45)), lineWidth: 0.8)
            }

            for offset in [CGFloat(-0.12), 0, 0.12] {
                var band = Path()
                band.move(to: CGPoint(x: size.width * (0.30 + offset), y: size.height * 0.67))
                band.addLine(to: CGPoint(x: size.width * (0.43 + offset), y: size.height * 0.60))
                context.stroke(band, with: .color(gold), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
            }

            drawStar(
                context: &context,
                center: CGPoint(x: size.width * 0.83, y: size.height * 0.18),
                radius: size.width * 0.12,
                color: isActive ? Color.accentColor : Color.secondary.opacity(0.75)
            )
            drawStar(
                context: &context,
                center: CGPoint(x: size.width * 0.23, y: size.height * 0.73),
                radius: size.width * 0.06,
                color: Color.secondary.opacity(0.7)
            )
        }
    }

    private func drawStar(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, color: Color) {
        var star = Path()
        star.move(to: CGPoint(x: center.x, y: center.y - radius))
        star.addLine(to: CGPoint(x: center.x + radius * 0.28, y: center.y - radius * 0.28))
        star.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        star.addLine(to: CGPoint(x: center.x + radius * 0.28, y: center.y + radius * 0.28))
        star.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        star.addLine(to: CGPoint(x: center.x - radius * 0.28, y: center.y + radius * 0.28))
        star.addLine(to: CGPoint(x: center.x - radius, y: center.y))
        star.addLine(to: CGPoint(x: center.x - radius * 0.28, y: center.y - radius * 0.28))
        star.closeSubpath()
        context.fill(star, with: .color(color))
    }
}

private struct WindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else {
            return
        }
        window.titlebarAppearsTransparent = false
        window.styleMask.remove(.fullSizeContentView)
        window.toolbarStyle = .unified
        window.toolbar?.allowsUserCustomization = false
        window.toolbar?.autosavesConfiguration = false
    }
}

private struct KeyCommandMonitor: NSViewRepresentable {
    var selectionShortcutBindings: SelectionShortcutBindings
    var onTemporaryStay: () -> Void
    var onSaveComment: () -> Void
    var onSelectionShortcut: (SelectionShortcutAction) -> Bool
    var onUndo: () -> Void
    var onRedo: () -> Void
    var onFindCommand: () -> Void
    var onJumpCommand: () -> Void
    var onDeleteSelectedComment: () -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            selectionShortcutBindings: selectionShortcutBindings,
            onTemporaryStay: onTemporaryStay,
            onSaveComment: onSaveComment,
            onSelectionShortcut: onSelectionShortcut,
            onUndo: onUndo,
            onRedo: onRedo,
            onFindCommand: onFindCommand,
            onJumpCommand: onJumpCommand,
            onDeleteSelectedComment: onDeleteSelectedComment
        )
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.install()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.selectionShortcutBindings = selectionShortcutBindings
        context.coordinator.onTemporaryStay = onTemporaryStay
        context.coordinator.onSaveComment = onSaveComment
        context.coordinator.onSelectionShortcut = onSelectionShortcut
        context.coordinator.onUndo = onUndo
        context.coordinator.onRedo = onRedo
        context.coordinator.onFindCommand = onFindCommand
        context.coordinator.onJumpCommand = onJumpCommand
        context.coordinator.onDeleteSelectedComment = onDeleteSelectedComment
        context.coordinator.install()
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.remove()
    }

    final class Coordinator {
        var selectionShortcutBindings: SelectionShortcutBindings
        var onTemporaryStay: () -> Void
        var onSaveComment: () -> Void
        var onSelectionShortcut: (SelectionShortcutAction) -> Bool
        var onUndo: () -> Void
        var onRedo: () -> Void
        var onFindCommand: () -> Void
        var onJumpCommand: () -> Void
        var onDeleteSelectedComment: () -> Bool
        private var monitor: Any?

        init(
            selectionShortcutBindings: SelectionShortcutBindings,
            onTemporaryStay: @escaping () -> Void,
            onSaveComment: @escaping () -> Void,
            onSelectionShortcut: @escaping (SelectionShortcutAction) -> Bool,
            onUndo: @escaping () -> Void,
            onRedo: @escaping () -> Void,
            onFindCommand: @escaping () -> Void,
            onJumpCommand: @escaping () -> Void,
            onDeleteSelectedComment: @escaping () -> Bool
        ) {
            self.selectionShortcutBindings = selectionShortcutBindings
            self.onTemporaryStay = onTemporaryStay
            self.onSaveComment = onSaveComment
            self.onSelectionShortcut = onSelectionShortcut
            self.onUndo = onUndo
            self.onRedo = onRedo
            self.onFindCommand = onFindCommand
            self.onJumpCommand = onJumpCommand
            self.onDeleteSelectedComment = onDeleteSelectedComment
        }

        func install() {
            guard monitor == nil else {
                return
            }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        func remove() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.charactersIgnoringModifiers?.lowercased() == "z",
               flags.contains(.command),
               flags.intersection([.control, .option]).isEmpty {
                guard !isTextInputActive() else {
                    return event
                }
                if flags.contains(.shift) {
                    onRedo()
                } else {
                    onUndo()
                }
                return nil
            }

            if event.charactersIgnoringModifiers?.lowercased() == "f",
               flags.contains(.command),
               flags.intersection([.control, .option, .shift]).isEmpty {
                onFindCommand()
                return nil
            }

            if [36, 76].contains(Int(event.keyCode)),
               flags.intersection([.command, .control, .option, .shift]).isEmpty {
                guard !isTextInputActive() else {
                    return event
                }
                onJumpCommand()
                return nil
            }

            if [51, 117].contains(Int(event.keyCode)),
               flags.intersection([.command, .control, .option]).isEmpty {
                guard !isTextInputActive() else {
                    return event
                }
                return onDeleteSelectedComment() ? nil : event
            }

            if flags.intersection([.command, .control, .option, .shift]).isEmpty,
               let key = event.charactersIgnoringModifiers,
               let action = selectionShortcutBindings.action(for: key) {
                guard !isTextInputActive() else {
                    return event
                }
                return onSelectionShortcut(action) ? nil : event
            }

            guard event.charactersIgnoringModifiers?.lowercased() == "a" else {
                return event
            }

            guard flags.intersection([.command, .control, .option]).isEmpty else {
                return event
            }
            guard !isTextInputActive() else {
                return event
            }

            if flags.contains(.shift) {
                onSaveComment()
            } else {
                onTemporaryStay()
            }
            return nil
        }

        private func isTextInputActive() -> Bool {
            guard let responder = NSApp.keyWindow?.firstResponder else {
                return false
            }
            if responder is NSTextView || responder is NSTextField {
                return true
            }
            if let view = responder as? NSView,
               view.enclosingScrollView?.documentView is NSTextView {
                return true
            }
            return false
        }
    }
}

struct SourceListView: View {
    @EnvironmentObject private var state: ReaderAppState

    var body: some View {
        List {
            Section("Document") {
                if let session = state.session {
                    Label(session.title, systemImage: "doc.richtext")
                    Label("Page \(state.currentPageIndex + 1)", systemImage: "number")
                    Label("\(session.annotations.count) annotations", systemImage: "highlighter")
                    Label("\(session.comments.count) comments", systemImage: "text.bubble")
                    Label("\(session.ocrBlocks.count) OCR blocks", systemImage: "text.viewfinder")
                } else {
                    Text("No PDF open")
                        .foregroundStyle(.secondary)
                }
            }

            if !state.openTabs.isEmpty {
                Section("Open PDFs") {
                    ForEach(state.openTabs) { tab in
                        HStack {
                            Button {
                                state.selectTab(tab.id)
                            } label: {
                                Label(tab.title, systemImage: tab.id == state.activeTabID ? "doc.fill" : "doc")
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)

                            Button {
                                state.closeTab(tab.id)
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

            if !state.paperOutline.isEmpty {
                Section("Outline") {
                    OutlineCatalogView(
                        items: state.paperOutline,
                        currentPageIndex: state.currentPageIndex,
                        onSelect: { item in
                            state.jumpToOutline(item)
                        }
                    )
                }
            }

            Section("Recent") {
                ForEach(state.recentFiles, id: \.self) { url in
                    Button(url.lastPathComponent) {
                        state.open(url: url)
                    }
                    .lineLimit(1)
                    .truncationMode(.middle)
                }
            }
        }
        .listStyle(.sidebar)
    }
}

private struct OutlineCatalogView: View {
    let items: [PaperOutlineItem]
    let currentPageIndex: Int
    var onSelect: (PaperOutlineItem) -> Void

    @State private var expandedIDs = Set<UUID>()

    private var catalog: OutlineCatalog {
        OutlineCatalog(items: items, currentPageIndex: currentPageIndex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(catalog.roots) { node in
                OutlineCatalogNodeView(
                    node: node,
                    activeID: catalog.activeID,
                    expandedIDs: $expandedIDs,
                    onSelect: onSelect
                )
            }
        }
        .onAppear {
            expandedIDs = catalog.autoExpandedIDs
        }
        .onChange(of: currentPageIndex) { _ in
            withAnimation(.easeInOut(duration: 0.18)) {
                expandedIDs = catalog.autoExpandedIDs
            }
        }
        .onChange(of: items) { _ in
            expandedIDs = catalog.autoExpandedIDs
        }
    }
}

private struct OutlineCatalogNodeView: View {
    let node: OutlineCatalogNode
    let activeID: UUID?
    @Binding var expandedIDs: Set<UUID>
    var onSelect: (PaperOutlineItem) -> Void

    private var isExpanded: Bool {
        expandedIDs.contains(node.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                if node.children.isEmpty {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.clear)
                        .frame(width: 12)
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                    }
                    .buttonStyle(.plain)
                    .help(isExpanded ? "Fold section" : "Unfold section")
                }

                Button {
                    onSelect(node.item)
                } label: {
                    HStack(spacing: 6) {
                        Text(node.item.title)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(node.item.pageIndex + 1)")
                            .font(.caption)
                            .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(isActive ? Color.accentColor.opacity(0.14) : Color.clear)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(isActive ? Color.accentColor : Color.primary)
            }
            .padding(.leading, CGFloat(node.depth) * 10)

            if isExpanded {
                ForEach(node.children) { child in
                    OutlineCatalogNodeView(
                        node: child,
                        activeID: activeID,
                        expandedIDs: $expandedIDs,
                        onSelect: onSelect
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var isActive: Bool {
        node.id == activeID
    }

    private func toggle() {
        if isExpanded {
            expandedIDs.remove(node.id)
        } else {
            expandedIDs.insert(node.id)
        }
    }
}

private final class OutlineCatalogNode: Identifiable {
    let id: UUID
    let item: PaperOutlineItem
    let depth: Int
    weak var parent: OutlineCatalogNode?
    var children: [OutlineCatalogNode] = []

    init(item: PaperOutlineItem, depth: Int, parent: OutlineCatalogNode?) {
        self.id = item.id
        self.item = item
        self.depth = depth
        self.parent = parent
    }
}

private struct OutlineCatalog {
    let roots: [OutlineCatalogNode]
    let activeID: UUID?
    let autoExpandedIDs: Set<UUID>

    init(items: [PaperOutlineItem], currentPageIndex: Int) {
        var roots: [OutlineCatalogNode] = []
        var stack: [OutlineCatalogNode] = []
        var nodeByID: [UUID: OutlineCatalogNode] = [:]

        for item in items {
            let depth = max(0, item.level)
            while stack.count > depth {
                stack.removeLast()
            }

            let parent = depth > 0 ? stack.last : nil
            let node = OutlineCatalogNode(item: item, depth: depth, parent: parent)
            nodeByID[node.id] = node
            if let parent {
                parent.children.append(node)
            } else {
                roots.append(node)
            }

            if stack.count == depth {
                stack.append(node)
            } else if stack.indices.contains(depth) {
                stack[depth] = node
            }
        }

        self.roots = roots

        let activeItem = items.last { $0.pageIndex <= currentPageIndex } ?? items.first
        self.activeID = activeItem?.id

        var expanded = Set<UUID>()
        if let activeID = activeItem?.id,
           var node = nodeByID[activeID] {
            if !node.children.isEmpty {
                expanded.insert(node.id)
            }
            while let parent = node.parent {
                expanded.insert(parent.id)
                node = parent
            }
        }
        self.autoExpandedIDs = expanded
    }
}

struct ReaderPaneView: View {
    @EnvironmentObject private var state: ReaderAppState

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let document = state.pdfDocument {
                HSplitView {
                    ReaderDocumentPanel(document: document)
                    if let splitTab = state.splitTab {
                        SecondaryReaderDocumentPanel(tab: splitTab)
                            .frame(minWidth: 320)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 46))
                        .foregroundStyle(.secondary)
                    Text("Open a PDF")
                        .font(.title2)
                    Text("Use the toolbar or Command-O to open an academic paper.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            QuickSuggestionPopover()
                .padding(16)
        }
    }
}

struct ReaderDocumentPanel: View {
    @EnvironmentObject private var state: ReaderAppState
    let document: PDFDocument
    @State private var commentDragYFractions: [UUID: Double] = [:]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                HSplitView {
                    PDFReaderCanvas(document: document)
                        .frame(minWidth: 380)
                    OutsideCommentRailView(commentDragYFractions: $commentDragYFractions)
                        .frame(minWidth: 120, idealWidth: 150, maxWidth: 280)
                }

                MarginConnectorOverlay(size: proxy.size, commentDragYFractions: commentDragYFractions)
            }
        }
    }
}

struct SecondaryReaderDocumentPanel: View {
    @EnvironmentObject private var state: ReaderAppState
    let tab: ReaderDocumentTab
    @State private var scaleFactor = 1.0
    @State private var autoScales = true
    @State private var requestedPageIndex: Int?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Compare", selection: Binding(
                    get: { state.splitTabID },
                    set: { state.setSplitTab($0) }
                )) {
                    ForEach(state.openTabs.filter { $0.id != state.activeTabID }) { tab in
                        Text(tab.title).tag(Optional(tab.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 260)

                Spacer()

                Button {
                    state.setSplitTab(nil)
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.bar)

            PDFKitView(
                document: tab.pdfDocument,
                scaleFactor: $scaleFactor,
                autoScales: $autoScales,
                requestedPageIndex: $requestedPageIndex,
                onSelectedText: { text, pageIndex, anchor, bounds in
                    state.selectTab(tab.id)
                    state.handleSelectedText(text, pageIndex: pageIndex, anchor: anchor, bounds: bounds)
                },
                onPageChanged: { _ in },
                onSelectionHover: { isHovering in
                    state.handleSelectionHover(isHovering: isHovering)
                },
                onSelectionCleared: {
                    state.handleSelectionCleared()
                },
                onLinkActivated: { url in
                    state.openLinkedPaper(url)
                },
                onPageAnchorSelected: { pageIndex, point in
                    state.selectTab(tab.id)
                    state.applyPendingCommentAnchor(pageIndex: pageIndex, point: point)
                },
                onViewportChanged: { _ in
                },
                onAnnotationRemovalRequested: { request in
                    state.selectTab(tab.id)
                    state.removePDFAnnotation(request)
                },
                onHighlightNoteRequested: { request in
                    state.selectTab(tab.id)
                    state.addHighlightLinkedNote(request)
                },
                onPageMarginCommentRequested: { pageIndex, point in
                    state.selectTab(tab.id)
                    state.addManualComment(at: point, pageIndex: pageIndex)
                },
                onOCRPageRequested: { pageIndex in
                    state.selectTab(tab.id)
                    state.runVisionOCRForPage(pageIndex)
                },
                onRegionSelected: { pageIndex, bounds in
                    state.selectTab(tab.id)
                    state.captureRegion(pageIndex: pageIndex, bounds: bounds, kind: .figure)
                },
                highlightColorHex: state.highlightColorHex
            )
        }
    }
}

struct PDFReaderCanvas: View {
    @EnvironmentObject private var state: ReaderAppState
    let document: PDFDocument

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PDFKitView(
                    document: document,
                    scaleFactor: $state.pdfScaleFactor,
                    autoScales: $state.pdfAutoScales,
                    requestedPageIndex: $state.requestedPageIndex,
                    onSelectedText: { text, pageIndex, anchor, bounds in
                        state.handleSelectedText(text, pageIndex: pageIndex, anchor: anchor, bounds: bounds)
                    },
                    onPageChanged: { pageIndex in
                        state.handlePageChange(pageIndex: pageIndex)
                    },
                    onSelectionHover: { isHovering in
                        state.handleSelectionHover(isHovering: isHovering)
                    },
                    onSelectionCleared: {
                        state.handleSelectionCleared()
                    },
                    onLinkActivated: { url in
                        state.openLinkedPaper(url)
                    },
                    onPageAnchorSelected: { pageIndex, point in
                        state.applyPendingCommentAnchor(pageIndex: pageIndex, point: point)
                    },
                    onViewportChanged: { snapshot in
                        state.handlePDFViewportChanged(snapshot)
                    },
                    onAnnotationRemovalRequested: { request in
                        state.removePDFAnnotation(request)
                    },
                    onHighlightNoteRequested: { request in
                        state.addHighlightLinkedNote(request)
                    },
                    onPageMarginCommentRequested: { pageIndex, point in
                        state.addManualComment(at: point, pageIndex: pageIndex)
                    },
                    onOCRPageRequested: { pageIndex in
                        state.runVisionOCRForPage(pageIndex)
                    },
                    onRegionSelected: { pageIndex, bounds in
                        state.captureRegion(pageIndex: pageIndex, bounds: bounds, kind: .figure)
                    },
                    activeTool: state.selectedTool,
                    highlightColorHex: state.highlightColorHex,
                    onAnnotationCreated: { annotation in
                        state.recordAnnotation(annotation)
                    },
                    onSignatureCreated: { signature in
                        state.recordSignature(signature)
                    }
                )

                if state.selectedTool == .region {
                    RegionSelectionOverlay { rect in
                        state.captureRegion(bounds: normalized(rect: rect, in: proxy.size), kind: .figure)
                    }
                }
            }
            .onAppear {
                state.updatePDFViewportSize(proxy.size)
            }
            .onChange(of: proxy.size) { newSize in
                state.updatePDFViewportSize(newSize)
            }
        }
    }

    private func normalized(rect: CGRect, in size: CGSize) -> NormalizedRect {
        NormalizedRect(
            x: max(0, min(1, rect.minX / max(size.width, 1))),
            y: max(0, min(1, rect.minY / max(size.height, 1))),
            width: max(0, min(1, rect.width / max(size.width, 1))),
            height: max(0, min(1, rect.height / max(size.height, 1)))
        )
    }
}

struct RegionSelectionOverlay: View {
    var onComplete: (CGRect) -> Void
    @State private var start: CGPoint?
    @State private var current: CGPoint?

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .topLeading) {
                if let rect {
                    Rectangle()
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .background(Color.accentColor.opacity(0.12))
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        if start == nil {
                            start = value.startLocation
                        }
                        current = value.location
                    }
                    .onEnded { _ in
                        if let rect, rect.width > 10, rect.height > 10 {
                            onComplete(rect)
                        }
                        start = nil
                        current = nil
                    }
            )
        }
    }

    private var rect: CGRect? {
        guard let start, let current else {
            return nil
        }
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }
}

struct MarginNoteCard<Content: View>: View {
    let placement: MarginAttachmentPlacement
    let accentColor: Color
    let isTemporary: Bool
    var isSelected = false
    var suppressLineLimit = false
    var fixedHeight: CGFloat?
    var showsResizeHandle = false
    var onResizeChanged: ((CGFloat) -> Void)?
    var onResizeEnded: ((CGFloat) -> Void)?
    var onMeasuredHeight: ((CGFloat) -> Void)?
    @ViewBuilder var content: () -> Content

    var body: some View {
        Group {
            if placement.visibility != .hidden {
                if placement.visibility == .minimized {
                    Circle()
                        .fill(accentColor.opacity(0.75))
                        .frame(width: 18, height: 18)
                        .overlay {
                            Image(systemName: isTemporary ? "sparkles" : "text.bubble")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    expandedCard
                }
            }
        }
        .scaleEffect(placement.scale, anchor: .topLeading)
        .opacity(placement.opacity)
        .overlay {
            if isSelected, placement.visibility != .hidden {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(accentColor.opacity(0.72), lineWidth: 1.6)
            }
        }
    }

    @ViewBuilder
    private var expandedCard: some View {
        let cardContent = VStack(alignment: .leading, spacing: 6) {
            content()
        }
        .lineLimit(suppressLineLimit ? nil : placement.lineLimit)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .preference(key: CommentCardHeightPreferenceKey.self, value: proxy.size.height)
            }
        }

        if let fixedHeight {
            cardChrome {
                VStack(spacing: 0) {
                    ScrollView(.vertical) {
                        cardContent
                    }
                    .scrollIndicators(.automatic)
                    .frame(
                        height: CGFloat(CommentBoxSizing.scrollViewportHeight(
                            for: Double(fixedHeight),
                            showsResizeHandle: showsResizeHandle
                        )),
                        alignment: .top
                    )
                    if showsResizeHandle {
                        resizeHandle
                    }
                }
                .frame(height: fixedHeight, alignment: .top)
            }
        } else {
            cardChrome {
                VStack(spacing: 0) {
                    cardContent
                    if showsResizeHandle {
                        resizeHandle
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cardChrome<Body: View>(@ViewBuilder content: () -> Body) -> some View {
        content()
            .background(isTemporary ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.regularMaterial))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 3)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onPreferenceChange(CommentCardHeightPreferenceKey.self) { height in
                guard height > 0 else {
                    return
                }
                onMeasuredHeight?(height)
            }
    }

    @ViewBuilder
    private var resizeHandle: some View {
        if showsResizeHandle {
            CommentResizeHandle(accentColor: accentColor)
                .frame(height: CGFloat(CommentBoxSizing.resizeHandleHeight))
                .highPriorityGesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            onResizeChanged?(value.translation.height)
                        }
                        .onEnded { value in
                            onResizeEnded?(value.translation.height)
                        }
                )
                .help("Drag to resize comment")
        }
    }
}

struct OutsideCommentRailView: View {
    @EnvironmentObject private var state: ReaderAppState
    @Binding var commentDragYFractions: [UUID: Double]
    @State private var editingCommentID: UUID?
    @State private var editingCommentDraft = ""
    @State private var measuredCommentHeights: [UUID: CGFloat] = [:]
    @State private var draftCommentHeights: [UUID: CGFloat] = [:]
    @State private var resizeStartHeights: [UUID: CGFloat] = [:]
    @State private var dragStartYOffsets: [UUID: Double] = [:]

    var body: some View {
        if state.lingeringInlineSuggestionGroups.isEmpty {
            railContent(timelineDate: nil)
        } else {
            TimelineView(.periodic(from: Date(), by: 0.25)) { timeline in
                railContent(timelineDate: timeline.date)
            }
        }
    }

    @ViewBuilder
    private func railContent(timelineDate: Date?) -> some View {
        let temporaryPlacements = state.marginPlacementsForTemporarySuggestions()
        let commentPlacements = state.marginPlacementsForVisibleComments()

        GeometryReader { proxy in
                let railWidth = max(proxy.size.width, 1)
                let railHeight = max(proxy.size.height, 1)
                let cardWidth = max(92, railWidth - 20)

                ZStack(alignment: .topLeading) {
                    ForEach(currentPageLingeringSuggestions, id: \.id) { group in
                        if let placement = temporaryPlacements[group.id], placement.visibility != .hidden {
                            let accentColor = Color(hex: group.colorHex) ?? .accentColor
                            let opacity = timelineDate.map { state.opacity(for: group, at: $0) } ?? 1
                            MarginNoteCard(placement: placement, accentColor: accentColor, isTemporary: true) {
                                Label(group.context.title, systemImage: "sparkles")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(group.suggestions.prefix(2)) { suggestion in
                                    MarkdownText(
                                        AISuggestionNoteFormatter.explanation(
                                            for: AISuggestionExplanation(
                                                prompt: suggestion.question,
                                                explanation: suggestion.answer
                                            )
                                        ),
                                        allowsTextSelection: false
                                    )
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .opacity(opacity)
                            .animation(.easeOut(duration: 0.8), value: opacity)
                            .gesture(
                                TapGesture(count: 2)
                                    .onEnded {
                                        state.focusConnector(forTemporarySuggestionID: group.id)
                                        state.jumpToSelectionContext(group.context)
                                    }
                                    .exclusively(before:
                                        TapGesture(count: 1)
                                            .onEnded {
                                                state.focusConnector(forTemporarySuggestionID: group.id)
                                                state.extendLingeringSuggestionGroup(group.id)
                                            }
                                    )
                            )
                            .contextMenu {
                                Button("Remove Temporary Note", role: .destructive) {
                                    state.removeLingeringSuggestionGroup(group.id)
                                }
                            }
                            .frame(width: cardWidth, alignment: .leading)
                            .position(x: railWidth / 2, y: CGFloat(placement.yFraction) * railHeight)
                        }
                    }

                    ForEach(currentPageComments, id: \.id) { thread in
                        if let placement = commentPlacements[thread.id], placement.visibility != .hidden {
                            let displayPlacement = placement.applyingCommentDrag(commentDragYFractions[thread.id])
                            let accentColor = Color(hex: thread.colorHex) ?? Color.secondary.opacity(0.55)
                            let isEditing = editingCommentID == thread.id
                            MarginNoteCard(
                                placement: displayPlacement,
                                accentColor: accentColor,
                                isTemporary: false,
                                isSelected: state.selectedCommentID == thread.id,
                                suppressLineLimit: isEditing,
                                fixedHeight: displayPlacement.visibility == .expanded ? commentDisplayHeight(for: thread) : nil,
                                showsResizeHandle: !isEditing && displayPlacement.visibility == .expanded,
                                onResizeChanged: { translation in
                                    updateDraftCommentHeight(for: thread, translation: translation)
                                },
                                onResizeEnded: { translation in
                                    commitCommentHeight(for: thread, translation: translation)
                                },
                                onMeasuredHeight: { height in
                                    measuredCommentHeights[thread.id] = height
                                }
                            ) {
                                if isEditing {
                                    CommentEditorView(
                                        text: $editingCommentDraft,
                                        onSave: {
                                            state.updateCommentBody(thread.id, body: editingCommentDraft)
                                            stopEditingComment()
                                        },
                                        onCancel: {
                                            stopEditingComment()
                                        }
                                    )
                                } else {
                                    ForEach(thread.messages, id: \.id) { message in
                                        MarkdownText(
                                            AISuggestionNoteFormatter.commentBodyForDisplay(message.body),
                                            allowsTextSelection: false
                                        )
                                        .font(.callout)
                                        Text(message.author)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .commentCardInteraction(
                                isEditing: isEditing,
                                onDoubleClick: {
                                    state.selectComment(thread.id)
                                    startEditingComment(thread)
                                },
                                onSingleClick: {
                                    state.selectComment(thread.id)
                                }
                            )
                            .contentShape(Rectangle())
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 8)
                                    .onChanged { value in
                                        updateDraftCommentYOffset(
                                            for: thread,
                                            placement: displayPlacement,
                                            isEditing: isEditing,
                                            startY: value.startLocation.y,
                                            translation: value.translation.height,
                                            railHeight: railHeight
                                        )
                                    }
                                    .onEnded { value in
                                        commitCommentYOffset(
                                            for: thread,
                                            placement: displayPlacement,
                                            isEditing: isEditing,
                                            startY: value.startLocation.y,
                                            translation: value.translation.height,
                                            railHeight: railHeight
                                        )
                                    }
                            )
                            .contextMenu {
                                Button("Edit Comment") {
                                    state.selectComment(thread.id)
                                    startEditingComment(thread)
                                }
                                Button("Set Anchor") {
                                    state.beginEditingCommentAnchor(thread.id)
                                }
                                Button("Remove Anchor") {
                                    state.removeCommentAnchor(thread.id)
                                }
                                if thread.displayHeight != nil {
                                    Button("Reset Comment Size") {
                                        state.updateCommentDisplayHeight(thread.id, height: nil)
                                        draftCommentHeights[thread.id] = nil
                                        resizeStartHeights[thread.id] = nil
                                    }
                                }
                                if thread.displayYOffset != nil {
                                    Button("Reset Comment Position") {
                                        state.updateCommentDisplayYOffset(thread.id, yOffset: nil)
                                        dragStartYOffsets[thread.id] = nil
                                        commentDragYFractions[thread.id] = nil
                                    }
                                }
                                Divider()
                                ForEach(commentColorChoices) { choice in
                                    Button {
                                        state.updateCommentColor(thread.id, colorHex: choice.colorHex)
                                    } label: {
                                        ColorChoiceMenuLabel(
                                            choice: choice,
                                            isSelected: colorHexesMatch(thread.colorHex, choice.colorHex)
                                        )
                                    }
                                }
                                Divider()
                                Button("Remove Comment", role: .destructive) {
                                    state.removeComment(thread.id)
                                }
                            }
                            .frame(width: cardWidth, alignment: .leading)
                            .position(x: railWidth / 2, y: CGFloat(displayPlacement.yFraction) * railHeight)
                        }
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
    }

    private var currentPageComments: [CommentThread] {
        let placements = state.marginPlacementsForVisibleComments()
        return (state.session?.comments ?? []).sorted {
            (placements[$0.id]?.yFraction ?? 0.5) < (placements[$1.id]?.yFraction ?? 0.5)
        }
    }

    private var currentPageLingeringSuggestions: [LingeringInlineSuggestionGroup] {
        let placements = state.marginPlacementsForTemporarySuggestions()
        return state.lingeringInlineSuggestionGroups.sorted {
            (placements[$0.id]?.yFraction ?? 0.5) < (placements[$1.id]?.yFraction ?? 0.5)
        }
    }

    private func startEditingComment(_ thread: CommentThread) {
        editingCommentID = thread.id
        editingCommentDraft = thread.messages.first?.body ?? "New note"
        state.focusConnector(forCommentID: thread.id)
    }

    private func stopEditingComment() {
        editingCommentID = nil
        editingCommentDraft = ""
    }

    private func commentDisplayHeight(for thread: CommentThread) -> CGFloat? {
        if let draftHeight = draftCommentHeights[thread.id] {
            return draftHeight
        }
        guard let displayHeight = thread.displayHeight else {
            return nil
        }
        return CGFloat(CommentBoxSizing.clampedHeight(displayHeight))
    }

    private func baseCommentHeight(for thread: CommentThread) -> CGFloat {
        if let draftHeight = draftCommentHeights[thread.id] {
            return draftHeight
        }
        if let displayHeight = thread.displayHeight {
            return CGFloat(CommentBoxSizing.clampedHeight(displayHeight))
        }
        if let measuredHeight = measuredCommentHeights[thread.id], measuredHeight > 0 {
            return CGFloat(CommentBoxSizing.totalHeightForMeasuredContent(Double(measuredHeight)))
        }
        return CGFloat(CommentBoxSizing.fallbackHeight)
    }

    private func updateDraftCommentHeight(for thread: CommentThread, translation: CGFloat) {
        let startHeight = resizeStartHeights[thread.id] ?? baseCommentHeight(for: thread)
        resizeStartHeights[thread.id] = startHeight
        let nextHeight = CommentBoxSizing.resizedHeight(from: Double(startHeight), dragTranslation: Double(translation))
        draftCommentHeights[thread.id] = CGFloat(nextHeight)
    }

    private func commitCommentHeight(for thread: CommentThread, translation: CGFloat) {
        let startHeight = resizeStartHeights[thread.id] ?? baseCommentHeight(for: thread)
        let nextHeight = CommentBoxSizing.resizedHeight(from: Double(startHeight), dragTranslation: Double(translation))
        draftCommentHeights[thread.id] = nil
        resizeStartHeights[thread.id] = nil
        state.updateCommentDisplayHeight(thread.id, height: nextHeight)
    }

    private func updateDraftCommentYOffset(
        for thread: CommentThread,
        placement: MarginAttachmentPlacement,
        isEditing: Bool,
        startY: CGFloat,
        translation: CGFloat,
        railHeight: CGFloat
    ) {
        guard canDragComment(thread, placement: placement, isEditing: isEditing, startY: startY) else {
            return
        }
        let startOffset = dragStartYOffsets[thread.id] ?? (thread.displayYOffset ?? 0)
        dragStartYOffsets[thread.id] = startOffset
        let nextOffset = CommentBoxSizing.displayYOffset(
            startOffset: startOffset,
            dragTranslation: Double(translation),
            railHeight: Double(railHeight)
        )
        commentDragYFractions[thread.id] = nextOffset - startOffset
    }

    private func commitCommentYOffset(
        for thread: CommentThread,
        placement: MarginAttachmentPlacement,
        isEditing: Bool,
        startY: CGFloat,
        translation: CGFloat,
        railHeight: CGFloat
    ) {
        defer {
            dragStartYOffsets[thread.id] = nil
            commentDragYFractions[thread.id] = nil
        }
        guard canDragComment(thread, placement: placement, isEditing: isEditing, startY: startY) else {
            return
        }
        let startOffset = dragStartYOffsets[thread.id] ?? (thread.displayYOffset ?? 0)
        let nextOffset = CommentBoxSizing.displayYOffset(
            startOffset: startOffset,
            dragTranslation: Double(translation),
            railHeight: Double(railHeight)
        )
        state.updateCommentDisplayYOffset(thread.id, yOffset: nextOffset)
    }

    private func canDragComment(
        _ thread: CommentThread,
        placement: MarginAttachmentPlacement,
        isEditing: Bool,
        startY: CGFloat
    ) -> Bool {
        guard !isEditing, placement.visibility == .expanded else {
            return false
        }
        let height = commentDisplayHeight(for: thread) ?? baseCommentHeight(for: thread)
        let resizeHandleTop = height - CGFloat(CommentBoxSizing.resizeHandleHeight) - 8
        return startY < resizeHandleTop
    }
}

private struct CommentCardHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct CommentResizeHandle: View {
    let accentColor: Color
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 3) {
            Spacer(minLength: 0)
            Capsule()
                .fill(accentColor.opacity(isHovering ? 0.72 : 0.46))
                .frame(width: 46, height: 4)
            Rectangle()
                .fill(accentColor.opacity(isHovering ? 0.24 : 0.12))
                .frame(height: 1)
        }
        .frame(height: 24)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .background(Color.clear)
        .onHover { hovering in
            if hovering, !isHovering {
                NSCursor.resizeUpDown.push()
            } else if !hovering, isHovering {
                NSCursor.pop()
            }
            isHovering = hovering
        }
        .onDisappear {
            if isHovering {
                NSCursor.pop()
                isHovering = false
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func commentCardInteraction(
        isEditing: Bool,
        onDoubleClick: @escaping () -> Void,
        onSingleClick: @escaping () -> Void
    ) -> some View {
        if isEditing {
            self
        } else {
            self.gesture(
                TapGesture(count: 2)
                    .onEnded {
                        onDoubleClick()
                    }
                    .exclusively(before:
                        TapGesture(count: 1)
                            .onEnded {
                                onSingleClick()
                            }
                    )
            )
        }
    }
}

private struct CommentEditorView: View {
    @Binding var text: String
    var onSave: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $text)
                .font(.callout)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 86, maxHeight: 180)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
                }

            HStack(spacing: 8) {
                Button("Cancel") {
                    onCancel()
                }
                .controlSize(.small)

                Spacer()

                Button("Done") {
                    onSave()
                }
                .controlSize(.small)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
    }
}

struct MarginConnectorOverlay: View {
    @EnvironmentObject private var state: ReaderAppState
    let size: CGSize
    var commentDragYFractions: [UUID: Double] = [:]
    @State private var hoverCandidateID: String?
    @State private var litConnectorID: String?
    @State private var hoverTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Canvas { context, canvasSize in
                for item in connectorItems {
                    guard item.visibility != .hidden,
                          let geometry = connectorGeometry(for: item, canvasSize: canvasSize) else {
                        continue
                    }

                    let isLit = litConnectorID == item.id || state.focusedConnectorID == item.id
                    let lineWidth = isLit
                        ? max(2.8, 4.2 * CGFloat(item.scale))
                        : max(1.2, 2.0 * CGFloat(item.scale))
                    var branchPath = Path()
                    branchPath.move(to: geometry.source)
                    branchPath.addCurve(to: geometry.target, control1: geometry.control1, control2: geometry.control2)

                    if isLit {
                        context.stroke(
                            branchPath,
                            with: .color(item.color.opacity(item.opacity * 0.18)),
                            style: StrokeStyle(lineWidth: lineWidth + 6, lineCap: .round, lineJoin: .round)
                        )
                    }
                    context.stroke(
                        branchPath,
                        with: .color(item.color.opacity(item.opacity * (isLit ? 0.72 : 0.24))),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )

                    let nodeRadius: CGFloat = isLit ? 5 : 3
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: geometry.node.x - nodeRadius,
                            y: geometry.node.y - nodeRadius,
                            width: nodeRadius * 2,
                            height: nodeRadius * 2
                        )),
                        with: .color(item.color.opacity(item.opacity * (isLit ? 0.82 : 0.26)))
                    )
                    if isLit {
                        context.stroke(
                            Path(ellipseIn: CGRect(x: geometry.node.x - 5, y: geometry.node.y - 5, width: 10, height: 10)),
                            with: .color(Color.white.opacity(item.opacity * 0.8)),
                            lineWidth: 1.5
                        )
                    }
                }
            }
            .allowsHitTesting(false)
            ConnectorHoverTrackingView(
                onMove: { point in
                    updateHover(at: point, canvasSize: size)
                },
                onExit: {
                    clearHover()
                }
            )
            .frame(width: size.width, height: size.height)
        }
        .frame(width: size.width, height: size.height)
        .onDisappear {
            clearHover()
        }
    }

    private var connectorItems: [MarginConnectorItem] {
        let temporaryPlacements = state.marginPlacementsForTemporarySuggestions()
        var items = state.lingeringInlineSuggestionGroups.compactMap { group -> MarginConnectorItem? in
            guard let placement = temporaryPlacements[group.id] else {
                return nil
            }
            let color = Color(hex: group.colorHex) ?? .accentColor
            return MarginConnectorItem(
                id: "temporary-\(group.id.uuidString)",
                yFraction: placement.yFraction,
                sourcePoint: state.connectorSourcePoint(for: group, placement: placement),
                scale: placement.scale,
                opacity: placement.opacity,
                visibility: placement.visibility,
                color: color
            )
        }

        let commentPlacements = state.marginPlacementsForVisibleComments()
        let comments = state.session?.comments ?? []
        items.append(contentsOf: comments.compactMap { thread -> MarginConnectorItem? in
            guard let placement = commentPlacements[thread.id] else {
                return nil
            }
            let displayPlacement = placement.applyingCommentDrag(commentDragYFractions[thread.id])
            let color = Color(hex: thread.colorHex) ?? Color.secondary.opacity(0.7)
            return MarginConnectorItem(
                id: "comment-\(thread.id.uuidString)",
                yFraction: displayPlacement.yFraction,
                sourcePoint: state.connectorSourcePoint(for: thread, placement: displayPlacement),
                scale: displayPlacement.scale,
                opacity: displayPlacement.opacity,
                visibility: displayPlacement.visibility,
                color: color
            )
        })
        return items
    }

    private func updateHover(at point: CGPoint, canvasSize: CGSize) {
        let nextID = connectorID(near: point, canvasSize: canvasSize)
        guard nextID != hoverCandidateID else {
            return
        }

        hoverTask?.cancel()
        hoverCandidateID = nextID
        litConnectorID = nil

        guard let nextID else {
            return
        }

        hoverTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                guard hoverCandidateID == nextID else {
                    return
                }
                litConnectorID = nextID
            }
        }
    }

    private func clearHover() {
        hoverTask?.cancel()
        hoverTask = nil
        hoverCandidateID = nil
        litConnectorID = nil
    }

    private func connectorID(near point: CGPoint, canvasSize: CGSize) -> String? {
        connectorItems
            .compactMap { item -> (id: String, distance: CGFloat)? in
                guard item.visibility != .hidden,
                      let geometry = connectorGeometry(for: item, canvasSize: canvasSize) else {
                    return nil
                }
                let distance = cubicDistance(
                    from: point,
                    source: geometry.source,
                    control1: geometry.control1,
                    control2: geometry.control2,
                    target: geometry.target
                )
                return distance <= 11 ? (item.id, distance) : nil
            }
            .min { $0.distance < $1.distance }?
            .id
    }

    private func connectorGeometry(for item: MarginConnectorItem, canvasSize: CGSize) -> MarginConnectorGeometry? {
        guard let sourcePoint = item.sourcePoint else {
            return nil
        }

        let measuredRailStartX = CGFloat(state.pdfViewportSize.width)
        let fallbackRailStartX = max(canvasSize.width - 178, canvasSize.width * 0.72)
        let railStartX = min(max(measuredRailStartX > 1 ? measuredRailStartX : fallbackRailStartX, 32), canvasSize.width - 18)
        let targetX = min(canvasSize.width - 18, railStartX + 26)
        let documentEndX = max(24, railStartX - 20)
        let sourceX = min(documentEndX, max(16, sourcePoint.x))
        let sourceY = min(canvasSize.height, max(0, sourcePoint.y))
        let targetY = CGFloat(item.yFraction) * canvasSize.height
        let distanceX = max(1, targetX - sourceX)
        let bend = min(190, max(64, distanceX * 0.62))

        return MarginConnectorGeometry(
            source: CGPoint(x: sourceX, y: sourceY),
            target: CGPoint(x: targetX, y: targetY),
            control1: CGPoint(x: sourceX + bend * 0.45, y: sourceY),
            control2: CGPoint(x: targetX - bend, y: targetY),
            node: CGPoint(x: railStartX + 4, y: targetY)
        )
    }

    private func cubicDistance(
        from point: CGPoint,
        source: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        target: CGPoint
    ) -> CGFloat {
        var minimum = CGFloat.greatestFiniteMagnitude
        var previous = source

        for step in 1...24 {
            let t = CGFloat(step) / 24
            let current = cubicPoint(t: t, source: source, control1: control1, control2: control2, target: target)
            minimum = min(minimum, distance(from: point, toSegmentFrom: previous, to: current))
            previous = current
        }

        return minimum
    }

    private func cubicPoint(
        t: CGFloat,
        source: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        target: CGPoint
    ) -> CGPoint {
        let inverse = 1 - t
        let a = inverse * inverse * inverse
        let b = 3 * inverse * inverse * t
        let c = 3 * inverse * t * t
        let d = t * t * t
        return CGPoint(
            x: a * source.x + b * control1.x + c * control2.x + d * target.x,
            y: a * source.y + b * control1.y + c * control2.y + d * target.y
        )
    }

    private func distance(from point: CGPoint, toSegmentFrom start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            return hypot(point.x - start.x, point.y - start.y)
        }
        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        let projection = CGPoint(x: start.x + t * dx, y: start.y + t * dy)
        return hypot(point.x - projection.x, point.y - projection.y)
    }
}

private struct MarginConnectorItem: Identifiable {
    var id: String
    var yFraction: Double
    var sourcePoint: CGPoint?
    var scale: Double
    var opacity: Double
    var visibility: MarginAttachmentVisibility
    var color: Color
}

private struct MarginConnectorGeometry {
    var source: CGPoint
    var target: CGPoint
    var control1: CGPoint
    var control2: CGPoint
    var node: CGPoint
}

private extension MarginAttachmentPlacement {
    func applyingCommentDrag(_ yFractionDelta: Double?) -> MarginAttachmentPlacement {
        guard let yFractionDelta,
              abs(yFractionDelta) > 0.0001,
              visibility == .expanded else {
            return self
        }
        var placement = self
        placement.yFraction = max(0.04, min(0.96, placement.yFraction + yFractionDelta))
        return placement
    }
}

private struct ConnectorHoverTrackingView: NSViewRepresentable {
    var onMove: (CGPoint) -> Void
    var onExit: () -> Void

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onMove = onMove
        view.onExit = onExit
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        nsView.onMove = onMove
        nsView.onExit = onExit
    }

    final class TrackingView: NSView {
        var onMove: ((CGPoint) -> Void)?
        var onExit: (() -> Void)?
        private var trackingArea: NSTrackingArea?

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.acceptsMouseMovedEvents = true
            updateTrackingAreas()
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let trackingArea {
                removeTrackingArea(trackingArea)
            }
            let nextArea = NSTrackingArea(
                rect: bounds,
                options: [.activeAlways, .enabledDuringMouseDrag, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(nextArea)
            trackingArea = nextArea
        }

        override func mouseMoved(with event: NSEvent) {
            onMove?(convert(event.locationInWindow, from: nil))
        }

        override func mouseEntered(with event: NSEvent) {
            onMove?(convert(event.locationInWindow, from: nil))
        }

        override func mouseDragged(with event: NSEvent) {
            onMove?(convert(event.locationInWindow, from: nil))
        }

        override func mouseExited(with event: NSEvent) {
            onExit?()
        }
    }
}

struct QuickSuggestionPopover: View {
    @EnvironmentObject private var state: ReaderAppState

    var body: some View {
        GeometryReader { proxy in
            let suggestions = state.displayedQuickSuggestions
            if state.isQuickSuggestionVisible, !suggestions.isEmpty {
                let width = panelWidth(in: proxy.size)
                let height = panelHeight(in: proxy.size)
                let position = panelPosition(in: proxy.size, panelSize: CGSize(width: width, height: height))

                VStack(alignment: .leading, spacing: 8) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(suggestions) { suggestion in
                                VStack(alignment: .leading, spacing: 5) {
                                    if !suggestion.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Button {
                                            state.chatInput = suggestion.question
                                            state.askAI(question: suggestion.question)
                                        } label: {
                                            Text(suggestion.question)
                                                .font(.subheadline.weight(.semibold))
                                                .lineLimit(2)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    InlineSuggestionAnswerView(suggestion: suggestion, panelHeight: height)

                                    HStack {
                                        if suggestion.isLoading {
                                            ProgressView()
                                                .controlSize(.small)
                                        }
                                        Spacer()
                                        Button {
                                            state.addInlineAnswerAsComment(suggestion)
                                        } label: {
                                            Image(systemName: "text.bubble")
                                        }
                                        .buttonStyle(.borderless)
                                        .help("Add as margin comment")
                                    }
                                }
                                Divider()
                            }
                        }
                        .padding(.trailing, 4)
                    }
                    .frame(maxHeight: max(90, height - 54))

                    HStack {
                        InlineAutocompleteTextField(
                            placeholder: "Ask inline",
                            text: $state.inlineQuestionInput,
                            candidates: state.inlineAutocompleteCandidates,
                            onSubmit: {
                                state.askInlineSuggestionQuestion()
                            },
                            onAcceptCandidate: { candidate in
                                state.acceptInlineAutocomplete(candidate)
                            }
                        )
                        .frame(height: 24)
                        Button {
                            state.askInlineSuggestionQuestion()
                        } label: {
                            Image(systemName: "paperplane.fill")
                        }
                        .disabled(state.inlineQuestionInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .controlSize(.small)

                    if !state.inlineAutocompleteCandidates.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(state.inlineAutocompleteCandidates, id: \.self) { candidate in
                                Button {
                                    state.acceptInlineAutocomplete(candidate)
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "text.cursor")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(candidate)
                                            .font(.caption2)
                                            .lineLimit(1)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.82))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(10)
                .frame(width: width, height: height)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 8, y: 3)
                .position(position)
                .onHover { hovering in
                    state.handleSuggestionPopoverHover(isHovering: hovering)
                }
            }
        }
        .allowsHitTesting(state.isQuickSuggestionVisible)
    }

    private func panelWidth(in size: CGSize) -> CGFloat {
        min(340, max(240, size.width * 0.34))
    }

    private func panelHeight(in size: CGSize) -> CGFloat {
        min(230, max(150, size.height * 0.30))
    }

    private func panelPosition(in size: CGSize, panelSize: CGSize) -> CGPoint {
        let margin: CGFloat = 12
        let anchor = state.quickSuggestionAnchor ?? CGPoint(x: size.width * 0.50, y: 96)
        let preferredX = anchor.x + panelSize.width / 2 + 14
        let preferredY = anchor.y + panelSize.height / 2 + 14
        let alternateY = anchor.y - panelSize.height / 2 - 14
        let x = clamp(preferredX, min: panelSize.width / 2 + margin, max: size.width - panelSize.width / 2 - margin)
        let yCandidate = preferredY + panelSize.height / 2 + margin <= size.height ? preferredY : alternateY
        let y = clamp(yCandidate, min: panelSize.height / 2 + margin, max: size.height - panelSize.height / 2 - margin)
        return CGPoint(x: x, y: y)
    }

    private func clamp(_ value: CGFloat, min lower: CGFloat, max upper: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, lower), Swift.max(lower, upper))
    }
}

private struct InlineSuggestionAnswerView: View {
    let suggestion: InlineSuggestion
    let panelHeight: CGFloat

    var body: some View {
        if InlineSuggestionScrollPolicy.needsNestedScroll(suggestion.answer) {
            EdgeForwardingScrollContainer(
                maxHeight: CGFloat(InlineSuggestionScrollPolicy.answerMaxHeight(panelHeight: Double(panelHeight)))
            ) {
                InlineSuggestionAnswerText(suggestion: suggestion)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.trailing, 6)
            }
        } else {
            InlineSuggestionAnswerText(suggestion: suggestion)
        }
    }
}

private struct InlineSuggestionAnswerText: View {
    let suggestion: InlineSuggestion

    var body: some View {
        MarkdownText(suggestion.answer)
            .font(suggestion.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .subheadline : .caption)
            .foregroundStyle(suggestion.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .primary : .secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InlineAutocompleteTextField: NSViewRepresentable {
    var placeholder: String
    @Binding var text: String
    var candidates: [String]
    var onSubmit: () -> Void
    var onAcceptCandidate: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            candidates: candidates,
            onSubmit: onSubmit,
            onAcceptCandidate: onAcceptCandidate
        )
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.focusRingType = .none
        field.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.candidates = candidates
        context.coordinator.onSubmit = onSubmit
        context.coordinator.onAcceptCandidate = onAcceptCandidate

        if field.stringValue != text {
            field.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var candidates: [String]
        var onSubmit: () -> Void
        var onAcceptCandidate: (String) -> Void

        init(
            text: Binding<String>,
            candidates: [String],
            onSubmit: @escaping () -> Void,
            onAcceptCandidate: @escaping (String) -> Void
        ) {
            self.text = text
            self.candidates = candidates
            self.onSubmit = onSubmit
            self.onAcceptCandidate = onAcceptCandidate
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else {
                return
            }
            text.wrappedValue = field.stringValue
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                guard let candidate = candidates.first else {
                    return false
                }
                text.wrappedValue = candidate
                control.stringValue = candidate
                textView.string = candidate
                onAcceptCandidate(candidate)
                return true
            }

            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                text.wrappedValue = control.stringValue
                onSubmit()
                return true
            }

            return false
        }
    }
}

struct MarkdownText: View {
    @EnvironmentObject private var state: ReaderAppState
    let bodyText: String
    let allowsTextSelection: Bool
    @State private var measuredEquationHeight: CGFloat = 22

    init(_ bodyText: String, allowsTextSelection: Bool = true) {
        self.bodyText = bodyText
        self.allowsTextSelection = allowsTextSelection
    }

    var body: some View {
        let equationLinks = state.equationMarkdownLinks(for: bodyText)
        if EquationMarkdownRenderer.containsEquationMarkup(bodyText) || !equationLinks.isEmpty {
            EquationMarkdownWebView(
                html: EquationMarkdownRenderer.htmlDocument(for: bodyText, equationLinks: equationLinks),
                minimumHeight: estimatedEquationHeight,
                allowsTextSelection: allowsTextSelection,
                onLinkActivated: { url in
                    state.openEquationReferenceLink(url)
                },
                measuredHeight: $measuredEquationHeight
            )
            .frame(height: max(measuredEquationHeight, estimatedEquationHeight))
        } else {
            if allowsTextSelection {
                renderedText
                    .textSelection(.enabled)
            } else {
                renderedText
                    .textSelection(.disabled)
            }
        }
    }

    private var renderedText: Text {
        if shouldPreservePlainLineBreaks {
            return Text(bodyText)
        }
        if let attributed = try? AttributedString(markdown: bodyText) {
            return Text(attributed)
        }
        return Text(bodyText)
    }

    private var estimatedEquationHeight: CGFloat {
        let lineCount = max(1, bodyText.components(separatedBy: .newlines).count)
        let displayMathCount = bodyText.components(separatedBy: "$$").count / 2
            + bodyText.components(separatedBy: "\\[").count - 1
        return CGFloat(lineCount * 18 + max(0, displayMathCount) * 16 + 8)
    }

    private var shouldPreservePlainLineBreaks: Bool {
        guard bodyText.contains("\n") else {
            return false
        }

        let markdownMarkers = ["**", "`", "$", "](", "# ", "## "]
        return !markdownMarkers.contains { bodyText.contains($0) }
    }
}

private struct EquationMarkdownWebView: NSViewRepresentable {
    let html: String
    let minimumHeight: CGFloat
    let allowsTextSelection: Bool
    let onLinkActivated: (URL) -> Void
    @Binding var measuredHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(measuredHeight: $measuredHeight, onLinkActivated: onLinkActivated)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "height")

        let webView = EquationWKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = false
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.measuredHeight = $measuredHeight
        context.coordinator.onLinkActivated = onLinkActivated
        let resolvedHTML = allowsTextSelection ? html : html.replacingOccurrences(
            of: "</style>",
            with: "body { -webkit-user-select: none; user-select: none; }</style>"
        )

        guard context.coordinator.currentHTML != resolvedHTML else {
            return
        }

        context.coordinator.currentHTML = resolvedHTML
        DispatchQueue.main.async {
            measuredHeight = minimumHeight
        }
        webView.loadHTMLString(resolvedHTML, baseURL: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var measuredHeight: Binding<CGFloat>
        var onLinkActivated: (URL) -> Void
        var currentHTML: String?
        weak var webView: EquationWKWebView?

        init(measuredHeight: Binding<CGFloat>, onLinkActivated: @escaping (URL) -> Void) {
            self.measuredHeight = measuredHeight
            self.onLinkActivated = onLinkActivated
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "height" else {
                return
            }
            let rawHeight: CGFloat?
            if let number = message.body as? NSNumber {
                rawHeight = CGFloat(truncating: number)
            } else if let double = message.body as? Double {
                rawHeight = CGFloat(double)
            } else {
                rawHeight = nil
            }
            guard let rawHeight else {
                return
            }

            let clampedHeight = min(max(rawHeight, 18), 1_600)
            DispatchQueue.main.async {
                self.measuredHeight.wrappedValue = clampedHeight
                self.webView?.refreshContainingScrollViews()
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("reportHeight();")
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if url.scheme == "aireader-equation" {
                onLinkActivated(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }
    }
}

private final class EquationWKWebView: WKWebView {
    private var scrollMonitor: Any?

    deinit {
        removeScrollMonitor()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if window == nil {
            removeScrollMonitor()
        } else {
            installScrollMonitor()
        }
    }

    override func scrollWheel(with event: NSEvent) {
        if let scrollView = parentScrollView {
            scrollView.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }

    private func installScrollMonitor() {
        guard scrollMonitor == nil else {
            return
        }

        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self,
                  let window = self.window,
                  event.window === window else {
                return event
            }

            let localPoint = self.convert(event.locationInWindow, from: nil)
            guard self.bounds.contains(localPoint), let scrollView = self.parentScrollView else {
                return event
            }

            scrollView.scrollWheel(with: event)
            return nil
        }
    }

    private func removeScrollMonitor() {
        guard let scrollMonitor else {
            return
        }

        NSEvent.removeMonitor(scrollMonitor)
        self.scrollMonitor = nil
    }

    private var parentScrollView: NSScrollView? {
        var current = superview
        while let view = current {
            if let scrollView = view as? NSScrollView {
                return scrollView
            }
            current = view.superview
        }
        return nil
    }

    func refreshContainingScrollViews() {
        var current: NSView? = self
        while let view = current {
            view.invalidateIntrinsicContentSize()
            view.needsLayout = true

            if let scrollView = view as? EdgeForwardingScrollView {
                scrollView.updateDocumentFrame()
                scrollView.layoutSubtreeIfNeeded()
            }

            current = view.superview
        }
    }
}

private extension Color {
    init?(hex: String) {
        var normalized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasPrefix("#") {
            normalized.removeFirst()
        }
        guard normalized.count == 6,
              let value = Int(normalized, radix: 16) else {
            return nil
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
