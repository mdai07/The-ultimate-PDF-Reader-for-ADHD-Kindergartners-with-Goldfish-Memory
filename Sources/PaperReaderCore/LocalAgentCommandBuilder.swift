import Foundation

public enum LocalAgentThinkingEffort: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high
    case xhigh
    case max

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        case .xhigh:
            return "Extra High"
        case .max:
            return "Max"
        }
    }

    public var codexReasoningValue: String {
        switch self {
        case .max:
            return LocalAgentThinkingEffort.xhigh.rawValue
        default:
            return rawValue
        }
    }
}

public enum LocalAgentCommandBuilder {
    public static let codexFastModel = "gpt-5.3-codex-spark"
    public static let codexMiniModel = "gpt-5.4-mini"
    public static let commonCodexModels = [
        "gpt-5.5",
        "gpt-5.4",
        codexMiniModel,
        "gpt-5.3-codex",
        "gpt-5.3-codex-spark",
        "gpt-5.2"
    ]
    public static let commonCodexInlineModels = [
        codexMiniModel,
        codexFastModel,
        "gpt-5.4",
        "gpt-5.3-codex",
        "gpt-5.2"
    ]
    public static let commonClaudeModels = [
        "sonnet",
        "opus",
        "haiku",
        "claude-sonnet-4-6"
    ]

    public static func arguments(
        forModel model: String,
        effort: LocalAgentThinkingEffort,
        codexFastMode: Bool = false,
        codexModelName: String? = nil,
        claudeModelName: String? = nil,
        codexOutputPath: String? = nil
    ) -> [String] {
        switch model.lowercased() {
        case "codex":
            let selectedModel = codexModelName?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty
            var arguments = [
                "exec",
                "--skip-git-repo-check",
                "--sandbox", "read-only",
                "--color", "never",
                "--config", "model_reasoning_effort=\"\(effort.codexReasoningValue)\""
            ]
            if let selectedModel {
                arguments.append(contentsOf: ["--model", selectedModel])
            } else if codexFastMode {
                arguments.append(contentsOf: ["--model", codexFastModel])
            }
            if let codexOutputPath,
               !codexOutputPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                arguments.append(contentsOf: ["--output-last-message", codexOutputPath])
            }
            arguments.append("-")
            return arguments
        case "claude":
            let selectedModel = claudeModelName?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty
            var arguments = [
                "--print",
                "--input-format", "text",
                "--output-format", "text",
                "--no-session-persistence",
                "--permission-mode", "dontAsk",
                "--tools", "",
                "--effort", effort.rawValue
            ]
            if let selectedModel {
                arguments.append(contentsOf: ["--model", selectedModel])
            }
            return arguments
        default:
            return ["-"]
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
