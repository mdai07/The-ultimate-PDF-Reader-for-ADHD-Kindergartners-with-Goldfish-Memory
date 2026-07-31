import Foundation

public enum LocalAgentThinkingEffort: String, Codable, CaseIterable, Identifiable {
    case low
    case medium
    case high
    case xhigh
    case max
    case ultra

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
        case .ultra:
            return "Ultra"
        }
    }
}

public enum LocalAgentCommandBuilder {
    public static let gpt56SolModel = "gpt-5.6-sol"
    public static let gpt56TerraModel = "gpt-5.6-terra"
    public static let gpt56LunaModel = "gpt-5.6-luna"
    public static let codexFastModel = "gpt-5.3-codex-spark"
    public static let codexMiniModel = "gpt-5.4-mini"
    public static let commonCodexModels = [
        gpt56SolModel,
        gpt56TerraModel,
        gpt56LunaModel,
        "gpt-5.5",
        "gpt-5.4",
        codexMiniModel,
        "gpt-5.3-codex",
        "gpt-5.3-codex-spark",
        "gpt-5.2"
    ]
    public static let commonCodexInlineModels = [
        codexMiniModel,
        gpt56TerraModel,
        gpt56LunaModel,
        gpt56SolModel,
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

    public static let claudeThinkingEfforts: [LocalAgentThinkingEffort] = [
        .low, .medium, .high, .xhigh, .max
    ]

    public static func codexThinkingEfforts(
        for modelName: String?,
        fastMode: Bool = false
    ) -> [LocalAgentThinkingEffort] {
        let trimmedModel = modelName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        let effectiveModel = trimmedModel ?? (fastMode ? codexFastModel : nil)

        switch effectiveModel {
        case gpt56SolModel, gpt56TerraModel:
            return LocalAgentThinkingEffort.allCases
        case gpt56LunaModel:
            return [.low, .medium, .high, .xhigh, .max]
        default:
            return [.low, .medium, .high, .xhigh]
        }
    }

    public static func codexModelTitle(_ model: String) -> String {
        switch model {
        case gpt56SolModel:
            return "GPT-5.6 Sol (\(model))"
        case gpt56TerraModel:
            return "GPT-5.6 Terra (\(model))"
        case gpt56LunaModel:
            return "GPT-5.6 Luna (\(model))"
        case codexMiniModel:
            return "GPT mini (\(model))"
        default:
            return model
        }
    }

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
            let supportedEfforts = codexThinkingEfforts(
                for: selectedModel,
                fastMode: codexFastMode
            )
            let selectedEffort = supportedEfforts.contains(effort)
                ? effort
                : supportedEfforts.last ?? .high
            var arguments = [
                "exec",
                "--skip-git-repo-check",
                "--sandbox", "read-only",
                "--color", "never",
                "--config", "model_reasoning_effort=\"\(selectedEffort.rawValue)\""
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
            let selectedEffort = claudeThinkingEfforts.contains(effort) ? effort : .max
            var arguments = [
                "--print",
                "--input-format", "text",
                "--output-format", "text",
                "--no-session-persistence",
                "--permission-mode", "dontAsk",
                "--tools", "",
                "--effort", selectedEffort.rawValue
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
