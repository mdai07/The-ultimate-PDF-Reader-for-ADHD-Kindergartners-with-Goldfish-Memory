import PaperReaderCore
import SwiftUI

struct UprakigoPreferencesView: View {
    @EnvironmentObject private var state: ReaderAppState

    var body: some View {
        Form {
            Section("AI Agents") {
                Picker("Sidebar chat", selection: $state.selectedAgentID) {
                    ForEach(state.agentProfiles) { profile in
                        Text(profile.displayName + (profile.isExperimental ? " (experimental)" : ""))
                            .tag(profile.id)
                    }
                }

                Picker("Inline suggestions", selection: $state.inlineAgentID) {
                    ForEach(state.agentProfiles) { profile in
                        Text(profile.displayName + (profile.isExperimental ? " (experimental)" : ""))
                            .tag(profile.id)
                    }
                }

                if state.selectedChatAgentIsLocalCLI {
                    Picker("Chat thinking effort", selection: $state.chatThinkingEffort) {
                        ForEach(LocalAgentThinkingEffort.allCases) { effort in
                            Text(effort.title).tag(effort)
                        }
                    }
                }

                if state.selectedInlineAgentIsLocalCLI {
                    Picker("Inline thinking effort", selection: $state.inlineThinkingEffort) {
                        ForEach(LocalAgentThinkingEffort.allCases) { effort in
                            Text(effort.title).tag(effort)
                        }
                    }
                }

                if state.selectedChatAgentIsLocalCLI || state.selectedInlineAgentIsLocalCLI {
                    Text("Thinking effort applies to local Codex and Claude CLI agents.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if state.selectedLocalCodexAgent {
                    if state.selectedChatLocalCodexAgent {
                        HStack {
                            TextField("Codex chat model, e.g. gpt-5.3-codex", text: $state.codexModelName)
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
                                Label("Choose", systemImage: "list.bullet")
                            }
                        }
                    }

                    if state.selectedInlineLocalCodexAgent {
                        HStack {
                            TextField("Codex inline model, e.g. \(LocalAgentCommandBuilder.codexMiniModel)", text: $state.codexInlineModelName)
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
                                Label("Choose", systemImage: "list.bullet")
                            }
                        }
                    }

                    Toggle("Codex fast mode", isOn: $state.codexFastModeEnabled)

                    Text("Leave a model empty for the Codex CLI default. Inline suggestions can use GPT mini; fast mode uses \(LocalAgentCommandBuilder.codexFastModel) only when the active Codex model field is empty.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if state.selectedLocalClaudeAgent {
                    HStack {
                        TextField("Claude model, e.g. sonnet", text: $state.claudeModelName)
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
                            Label("Choose", systemImage: "list.bullet")
                        }
                    }

                    Text("Leave the model empty for the Claude CLI default. Thinking effort is passed to Claude with --effort.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("DeepSeek") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label(
                            deepSeekKeyStatus,
                            systemImage: "key.fill"
                        )
                        Spacer()
                        Button {
                            state.reloadDeepSeekConfiguration()
                        } label: {
                            Label("Reload", systemImage: "arrow.clockwise")
                        }
                    }
                    Text("Active chat model: \(state.deepSeekChatModel)")
                    Text("Active inline model: \(state.deepSeekFastModel)")
                    Text("Custom values below override DEEPSEEK_API_KEY, DEEPSEEK_MODEL, and DEEPSEEK_MODEL_FAST when filled. API keys are saved in macOS Keychain.")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)

                SecureField("Custom DeepSeek API key", text: $state.customDeepSeekAPIKey)
                    .textFieldStyle(.roundedBorder)
                TextField("Custom chat model, e.g. deepseek-v4-pro", text: $state.customDeepSeekChatModel)
                    .textFieldStyle(.roundedBorder)
                TextField("Custom inline model, e.g. deepseek-v4-flash", text: $state.customDeepSeekFastModel)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button {
                        state.persistDeepSeekConfiguration()
                    } label: {
                        Label("Save DeepSeek Settings", systemImage: "checkmark")
                    }

                    Button {
                        state.customDeepSeekAPIKey = ""
                        state.customDeepSeekChatModel = ""
                        state.customDeepSeekFastModel = ""
                        state.persistDeepSeekConfiguration()
                    } label: {
                        Label("Use Environment", systemImage: "arrow.uturn.backward")
                    }
                }
            }

            Section("Gemini") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label(
                            geminiKeyStatus,
                            systemImage: "sparkles"
                        )
                        Spacer()
                        Button {
                            state.reloadGeminiConfiguration()
                        } label: {
                            Label("Reload", systemImage: "arrow.clockwise")
                        }
                    }
                    Text("Active chat model: \(state.geminiChatModel)")
                    Text("Active inline model: \(state.geminiFastModel)")
                    Text("Custom values below override GEMINI_API_KEY, GEMINI_MODEL, and GEMINI_MODEL_FAST when filled. API keys are saved in macOS Keychain.")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)

                SecureField("Custom Gemini API key", text: $state.customGeminiAPIKey)
                    .textFieldStyle(.roundedBorder)
                TextField("Custom chat model, e.g. gemini-3.1-pro-preview", text: $state.customGeminiChatModel)
                    .textFieldStyle(.roundedBorder)
                TextField("Custom inline model, e.g. gemini-3.5-flash", text: $state.customGeminiFastModel)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button {
                        state.persistGeminiConfiguration()
                    } label: {
                        Label("Save Gemini Settings", systemImage: "checkmark")
                    }

                    Button {
                        state.customGeminiAPIKey = ""
                        state.customGeminiChatModel = ""
                        state.customGeminiFastModel = ""
                        state.persistGeminiConfiguration()
                    } label: {
                        Label("Use Environment", systemImage: "arrow.uturn.backward")
                    }
                }
            }

            Section("AI Prompts") {
                DisclosureGroup("Customize prompts") {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(AIPromptTemplateKey.allCases) { key in
                            promptEditor(for: key)
                        }
                    }
                    .padding(.top, 6)
                }
            }

            Section("Selection Shortcuts") {
                ForEach(SelectionShortcutAction.allCases) { action in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.title)
                            Text(shortcutDescription(for: action))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        TextField(
                            "",
                            text: Binding(
                                get: {
                                    state.selectionShortcutBindings.key(for: action)
                                },
                                set: { value in
                                    state.updateSelectionShortcut(action, key: value)
                                }
                            )
                        )
                        .multilineTextAlignment(.center)
                        .frame(width: 44)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 620, height: 680)
    }

    private var deepSeekKeyStatus: String {
        if state.isDeepSeekKeyFromCustomOverride {
            return "Using saved DeepSeek API key"
        }
        if state.isDeepSeekKeyFromEnvironment {
            return "Using DEEPSEEK_API_KEY"
        }
        return "DeepSeek API key not loaded"
    }

    private var geminiKeyStatus: String {
        if state.isGeminiKeyFromCustomOverride {
            return "Using saved Gemini API key"
        }
        if state.isGeminiKeyFromEnvironment {
            return "Using GEMINI_API_KEY"
        }
        return "Gemini API key not loaded"
    }

    @ViewBuilder
    private func promptEditor(for key: AIPromptTemplateKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(promptTitle(for: key))
                        .font(.headline)
                    Text(promptPlaceholderDescription(for: key))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Use Default") {
                    state.resetPromptTemplate(key)
                }
                .controlSize(.small)
            }

            Text(state.hasPromptOverride(key) ? "Using custom prompt." : "Using built-in default. Add text here to override it.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(
                text: Binding(
                    get: { state.promptTemplate(for: key) },
                    set: { state.setPromptTemplate($0, for: key) }
                )
            )
            .font(.system(.caption, design: .monospaced))
            .frame(minHeight: promptEditorHeight(for: key))
            .padding(6)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func shortcutDescription(for action: SelectionShortcutAction) -> String {
        switch action {
        case .inlineSuggestions:
            return "Show the inline AI suggestion box for the selected text."
        case .marginComment:
            return "Save the current inline explanation as a side margin comment."
        case .highlight:
            return "Highlight the selected text using the current highlight color."
        }
    }

    private func promptTitle(for key: AIPromptTemplateKey) -> String {
        switch key {
        case .sidebarSystem:
            return "Sidebar system prompt"
        case .sidebarUser:
            return "Sidebar chat prompt"
        case .paperMemory:
            return "Paper memory prompt"
        case .inlineSuggestions:
            return "Inline suggestion prompt"
        case .inlineAnswer:
            return "Inline answer prompt"
        }
    }

    private func promptPlaceholderDescription(for key: AIPromptTemplateKey) -> String {
        switch key {
        case .sidebarSystem:
            return "No placeholders required."
        case .sidebarUser:
            return "Available: {paperContext}, {paperMemory}, {question}"
        case .paperMemory:
            return "Available: {wholePaper}"
        case .inlineSuggestions:
            return "Available: {paperMemory}, {selectionTitle}, {selectionDetail}"
        case .inlineAnswer:
            return "Available: {paperMemory}, {selectionTitle}, {selectionDetail}, {question}"
        }
    }

    private func promptEditorHeight(for key: AIPromptTemplateKey) -> CGFloat {
        switch key {
        case .sidebarSystem:
            return 72
        case .sidebarUser, .inlineAnswer:
            return 140
        case .paperMemory:
            return 150
        case .inlineSuggestions:
            return 260
        }
    }
}
