import Foundation

public struct LocalAgentProvider {
    public struct LocalAgent: Codable, Equatable {
        public var profile: AgentProfile
        public var executableURL: URL

        public init(profile: AgentProfile, executableURL: URL) {
            self.profile = profile
            self.executableURL = executableURL
        }
    }

    private let environment: [String: String]
    private let configuredExecutables: [String: URL]

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        configuredExecutables: [String: URL] = [:]
    ) {
        self.environment = environment
        self.configuredExecutables = configuredExecutables
    }

    public func availableAgents() -> [LocalAgent] {
        var agents: [LocalAgent] = []

        if let codex = executable(named: "codex") {
            agents.append(
                LocalAgent(
                    profile: AgentProfile(
                        id: "local-codex",
                        displayName: "Codex Local",
                        kind: .localCLI,
                        model: "codex",
                        isExperimental: true,
                        supportsStreaming: false
                    ),
                    executableURL: codex
                )
            )
        }

        if let claude = executable(named: "claude") {
            agents.append(
                LocalAgent(
                    profile: AgentProfile(
                        id: "local-claude",
                        displayName: "Claude Local",
                        kind: .localCLI,
                        model: "claude",
                        isExperimental: true,
                        supportsStreaming: false
                    ),
                    executableURL: claude
                )
            )
        }

        return agents
    }

    private func executable(named name: String) -> URL? {
        if let configured = configuredExecutables[name],
           FileManager.default.isExecutableFile(atPath: configured.path) {
            return configured
        }

        let pathValue = environment["PATH"] ?? ""
        for directory in pathValue.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }
}
