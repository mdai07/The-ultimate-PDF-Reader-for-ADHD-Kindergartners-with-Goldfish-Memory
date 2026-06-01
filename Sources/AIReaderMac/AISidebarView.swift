import PaperReaderCore
import SwiftUI

struct AISidebarView: View {
    @EnvironmentObject private var state: ReaderAppState
    @State private var isEditingDeepSeekKey = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Chat", selection: $state.selectedAgentID) {
                    ForEach(state.agentProfiles) { profile in
                        Text(profile.displayName + (profile.isExperimental ? " (experimental)" : ""))
                            .tag(profile.id)
                    }
                }
                .pickerStyle(.menu)

                Picker("Inline", selection: $state.inlineAgentID) {
                    ForEach(state.agentProfiles) { profile in
                        Text(profile.displayName + (profile.isExperimental ? " (experimental)" : ""))
                            .tag(profile.id)
                    }
                }
                .pickerStyle(.menu)

                if state.selectedChatAgentIsLocalCLI || state.selectedInlineAgentIsLocalCLI {
                    HStack(spacing: 10) {
                        if state.selectedChatAgentIsLocalCLI {
                            Picker("Chat effort", selection: $state.chatThinkingEffort) {
                                ForEach(LocalAgentThinkingEffort.allCases) { effort in
                                    Text(effort.title).tag(effort)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        if state.selectedInlineAgentIsLocalCLI {
                            Picker("Inline effort", selection: $state.inlineThinkingEffort) {
                                ForEach(LocalAgentThinkingEffort.allCases) { effort in
                                    Text(effort.title).tag(effort)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    .font(.caption)
                    .help("Thinking effort is used by local Codex and Claude CLI agents.")
                }

                if state.selectedLocalCodexAgent {
                    VStack(alignment: .leading, spacing: 6) {
                        if state.selectedChatLocalCodexAgent {
                            HStack(spacing: 6) {
                                TextField("Codex chat model", text: $state.codexModelName)
                                    .textFieldStyle(.roundedBorder)
                                Menu {
                                    Button("Codex CLI default") {
                                        state.codexModelName = ""
                                    }
                                    Divider()
                                    ForEach(LocalAgentCommandBuilder.commonCodexModels, id: \.self) { model in
                                        Button(model) {
                                            state.codexModelName = model
                                        }
                                    }
                                } label: {
                                    Image(systemName: "list.bullet")
                                }
                                .help("Choose a common Codex chat model")
                            }
                        }

                        if state.selectedInlineLocalCodexAgent {
                            HStack(spacing: 6) {
                                TextField("Codex inline model", text: $state.codexInlineModelName)
                                    .textFieldStyle(.roundedBorder)
                                Menu {
                                    Button("Codex CLI default") {
                                        state.codexInlineModelName = ""
                                    }
                                    Divider()
                                    ForEach(LocalAgentCommandBuilder.commonCodexInlineModels, id: \.self) { model in
                                        Button(model == LocalAgentCommandBuilder.codexMiniModel ? "GPT mini (\(model))" : model) {
                                            state.codexInlineModelName = model
                                        }
                                    }
                                } label: {
                                    Image(systemName: "list.bullet")
                                }
                                .help("Choose a common Codex inline model")
                            }
                        }

                        Toggle("Codex fast mode", isOn: $state.codexFastModeEnabled)
                            .help("Uses \(LocalAgentCommandBuilder.codexFastModel) when the active Codex model field is empty.")

                        Text("Leave a model empty for the Codex CLI default. Inline suggestions can use GPT mini; a custom model overrides fast mode.")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }

                if state.selectedLocalClaudeAgent {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            TextField("Claude model", text: $state.claudeModelName)
                                .textFieldStyle(.roundedBorder)
                            Menu {
                                Button("Claude CLI default") {
                                    state.claudeModelName = ""
                                }
                                Divider()
                                ForEach(LocalAgentCommandBuilder.commonClaudeModels, id: \.self) { model in
                                    Button(model) {
                                        state.claudeModelName = model
                                    }
                                }
                            } label: {
                                Image(systemName: "list.bullet")
                            }
                            .help("Choose a common Claude model alias")
                        }

                        Text("Leave the model empty for the Claude CLI default. Effort is passed with --effort.")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }

                deepSeekKeySection
                geminiEnvironmentSection

                DisclosureGroup("Local CLI Agents") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Path to codex CLI", text: $state.codexCLIPath)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    state.persistLocalAgentPaths()
                                }
                            Button {
                                state.chooseCLIPath(for: "codex")
                            } label: {
                                Image(systemName: "folder")
                            }
                            .help("Choose Codex CLI")
                        }

                        HStack {
                            TextField("Path to claude CLI", text: $state.claudeCLIPath)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    state.persistLocalAgentPaths()
                                }
                            Button {
                                state.chooseCLIPath(for: "claude")
                            } label: {
                                Image(systemName: "folder")
                            }
                            .help("Choose Claude CLI")
                        }

                        Button {
                            state.persistLocalAgentPaths()
                        } label: {
                            Label("Update Agents", systemImage: "arrow.clockwise")
                        }

                    }
                    .padding(.top, 6)
                }
                .font(.caption)

                contextScopeSection

                if let selection = state.selectionContext {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selection.title)
                            .font(.headline)
                        Text(selection.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(5)
                    }
                } else {
                    Text("Ask about the whole paper, or select text/drag a figure region to focus the context.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)

            Divider()

            ScrollViewReader { proxy in
                GeometryReader { chatProxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(state.chatMessages.enumerated()), id: \.offset) { index, message in
                                ChatBubbleView(message: message, viewportHeight: chatProxy.size.height)
                                    .id(index)
                            }

                            if state.isThinking {
                                ProgressView("Thinking")
                                    .padding(.horizontal, 12)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .onReceive(state.$chatMessages) { messages in
                        if let last = messages.indices.last {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            VStack(spacing: 8) {
                TextField("Ask about this paper", text: $state.chatInput, axis: .vertical)
                    .lineLimit(2...6)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        state.sendChat()
                    }

                HStack {
                    Button {
                        state.chatInput = ""
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .help("Clear")

                    Spacer()

                    Button {
                        state.sendChat()
                    } label: {
                        Label("Ask", systemImage: "paperplane.fill")
                    }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(state.chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(12)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    @ViewBuilder
    private var contextScopeSection: some View {
        DisclosureGroup("AI Context") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                    Text(state.activePaperTitle)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text("current")
                        .foregroundStyle(.secondary)
                }

                if state.contextCandidateTabs.isEmpty {
                    Text("Open another PDF tab to add it.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(state.contextCandidateTabs) { tab in
                        Toggle(isOn: Binding(
                            get: { state.isContextTabIncluded(tab.id) },
                            set: { state.setContextTab(tab.id, included: $0) }
                        )) {
                            Text(tab.title)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            }
            .padding(.top, 6)
        }
        .font(.caption)
    }

    @ViewBuilder
    private var deepSeekKeySection: some View {
        let hasKey = !state.deepSeekAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if hasKey && !isEditingDeepSeekKey {
            HStack(spacing: 8) {
                Label(
                    deepSeekKeyStatus,
                    systemImage: "key.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    state.reloadDeepSeekKey()
                    isEditingDeepSeekKey = false
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Reload DEEPSEEK_API_KEY")

                Button("Change") {
                    isEditingDeepSeekKey = true
                }
                .font(.caption)
            }
        } else {
            HStack {
                SecureField("Custom DeepSeek API key", text: $state.customDeepSeekAPIKey)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        state.persistDeepSeekConfiguration()
                        isEditingDeepSeekKey = false
                    }

                Button {
                    state.persistDeepSeekConfiguration()
                    isEditingDeepSeekKey = false
                } label: {
                    Image(systemName: "checkmark")
                }
                .help("Save DeepSeek API key")

                Button {
                    state.reloadDeepSeekKey()
                    isEditingDeepSeekKey = false
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Reload DEEPSEEK_API_KEY")
            }

            Text("Paste a key here to save it in Keychain, or launch with DEEPSEEK_API_KEY set.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var geminiEnvironmentSection: some View {
        if state.selectedAgentID.hasPrefix("gemini") || state.inlineAgentID.hasPrefix("gemini") {
            HStack(spacing: 8) {
                Label(
                    geminiKeyStatus,
                    systemImage: "sparkles"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    state.reloadGeminiConfiguration()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Reload GEMINI_API_KEY, GEMINI_MODEL, and GEMINI_MODEL_FAST")
            }
            Text("Gemini: \(state.geminiChatModel); fast: \(state.geminiFastModel)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var deepSeekKeyStatus: String {
        if state.isDeepSeekKeyFromCustomOverride {
            return "Saved"
        }
        if state.isDeepSeekKeyFromEnvironment {
            return "Env"
        }
        return "Saved"
    }

    private var geminiKeyStatus: String {
        if state.isGeminiKeyFromCustomOverride {
            return "Saved"
        }
        if state.isGeminiKeyFromEnvironment {
            return "Env"
        }
        return "Missing"
    }
}

struct ChatBubbleView: View {
    @EnvironmentObject private var state: ReaderAppState
    let message: ChatMessage
    let viewportHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.role.rawValue.capitalized)
                .font(.caption)
                .foregroundStyle(.secondary)
            ChatBubbleMessageBody(message: message, viewportHeight: viewportHeight)

            if !message.citations.isEmpty {
                HStack {
                    ForEach(message.citations, id: \.self) { citation in
                        Text("p. \(citation.pageIndex + 1) \(citation.label)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if message.role == .assistant {
                HStack {
                    Button {
                        state.addOutsidePageComment(body: message.content)
                    } label: {
                        Label("Comment", systemImage: "text.bubble")
                    }
                    .controlSize(.small)

                    if !message.citations.isEmpty {
                        Button {
                            state.toggleTemporaryHighlight(for: message)
                        } label: {
                            if state.isTemporaryHighlightShowing(for: message) {
                                Label("Hide", systemImage: "highlighter")
                            } else {
                                Label("Show", systemImage: "highlighter")
                            }
                        }
                        .controlSize(.small)
                        .help(
                            state.isTemporaryHighlightShowing(for: message)
                                ? "Hide the temporary relevance highlight"
                                : "Show the temporary relevance highlight"
                        )
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(message.role == .user ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 12)
    }
}

private struct ChatBubbleMessageBody: View {
    let message: ChatMessage
    let viewportHeight: CGFloat

    var body: some View {
        if SidebarChatScrollPolicy.needsNestedScroll(message.content) {
            EdgeForwardingScrollContainer(
                maxHeight: CGFloat(SidebarChatScrollPolicy.bubbleMaxHeight(viewportHeight: Double(viewportHeight)))
            ) {
                chatText
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.trailing, 6)
            }
        } else {
            chatText
        }
    }

    private var chatText: some View {
        MarkdownText(message.content)
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
