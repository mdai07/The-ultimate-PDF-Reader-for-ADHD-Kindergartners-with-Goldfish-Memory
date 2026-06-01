import XCTest
@testable import PaperReaderCore

final class LocalAgentProviderTests: XCTestCase {
    func testLocalAgentExecutableDiscoveryUsesWhichWithConfiguredPath() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let codexURL = directory.appendingPathComponent("codex")
        try Data().write(to: codexURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: codexURL.path)

        let discovered = LocalAgentExecutableDiscovery.discover(
            toolName: "codex",
            environment: ["PATH": directory.path],
            extraSearchDirectories: []
        )

        XCTAssertEqual(discovered, codexURL)
    }

    func testLocalAgentExecutableDiscoverySearchPathIncludesHomebrewDirectories() {
        let searchPath = LocalAgentExecutableDiscovery.searchPath(
            environment: ["PATH": "/custom/bin"],
            extraSearchDirectories: ["/extra/bin"]
        )

        XCTAssertTrue(searchPath.split(separator: ":").contains("/custom/bin"))
        XCTAssertTrue(searchPath.split(separator: ":").contains("/extra/bin"))
        XCTAssertTrue(searchPath.split(separator: ":").contains("/opt/homebrew/bin"))
        XCTAssertTrue(searchPath.split(separator: ":").contains("/usr/local/bin"))
    }

    func testConfiguredExecutablePathsCreateCodexAndClaudeProfiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let codexURL = directory.appendingPathComponent("codex")
        let claudeURL = directory.appendingPathComponent("claude")
        try Data().write(to: codexURL)
        try Data().write(to: claudeURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: codexURL.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: claudeURL.path)

        let provider = LocalAgentProvider(
            environment: [:],
            configuredExecutables: [
                "codex": codexURL,
                "claude": claudeURL
            ]
        )

        let agents = provider.availableAgents()

        XCTAssertEqual(agents.map(\.profile.id), ["local-codex", "local-claude"])
        XCTAssertEqual(agents.map(\.executableURL), [codexURL, claudeURL])
        XCTAssertTrue(agents.allSatisfy { $0.profile.isExperimental })
    }

    func testConfiguredExecutablePathWinsOverPATHDiscovery() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuredURL = directory.appendingPathComponent("custom-codex")
        let pathURL = directory.appendingPathComponent("codex")
        try Data().write(to: configuredURL)
        try Data().write(to: pathURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: configuredURL.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: pathURL.path)

        let provider = LocalAgentProvider(
            environment: ["PATH": directory.path],
            configuredExecutables: ["codex": configuredURL]
        )

        let codexAgent = provider.availableAgents().first { $0.profile.id == "local-codex" }

        XCTAssertEqual(codexAgent?.executableURL, configuredURL)
    }

    func testCodexCommandUsesExecModeAndMapsMaxEffortToXHigh() {
        let arguments = LocalAgentCommandBuilder.arguments(
            forModel: "codex",
            effort: .max
        )

        XCTAssertEqual(arguments.first, "exec")
        XCTAssertTrue(arguments.contains("--skip-git-repo-check"))
        XCTAssertTrue(arguments.contains("--sandbox"))
        XCTAssertTrue(arguments.contains("read-only"))
        XCTAssertFalse(arguments.contains("--ask-for-approval"))
        XCTAssertTrue(arguments.contains("model_reasoning_effort=\"xhigh\""))
        XCTAssertEqual(arguments.last, "-")
    }

    func testCodexFastModeAddsFastModelOverride() {
        let arguments = LocalAgentCommandBuilder.arguments(
            forModel: "codex",
            effort: .low,
            codexFastMode: true
        )

        XCTAssertTrue(arguments.contains("--model"))
        XCTAssertTrue(arguments.contains(LocalAgentCommandBuilder.codexFastModel))
        XCTAssertTrue(arguments.contains("model_reasoning_effort=\"low\""))
    }

    func testCommonCodexInlineModelsOfferMiniPresetFirst() {
        XCTAssertEqual(LocalAgentCommandBuilder.commonCodexInlineModels.first, LocalAgentCommandBuilder.codexMiniModel)
        XCTAssertTrue(LocalAgentCommandBuilder.commonCodexInlineModels.contains(LocalAgentCommandBuilder.codexMiniModel))
    }

    func testCodexCommandAcceptsMiniModelForInlineSuggestions() {
        let arguments = LocalAgentCommandBuilder.arguments(
            forModel: "codex",
            effort: .low,
            codexModelName: LocalAgentCommandBuilder.codexMiniModel
        )

        XCTAssertTrue(arguments.contains("--model"))
        XCTAssertTrue(arguments.contains(LocalAgentCommandBuilder.codexMiniModel))
        XCTAssertFalse(arguments.contains(LocalAgentCommandBuilder.codexFastModel))
    }

    func testCodexCommandUsesSelectedGPTModel() {
        let arguments = LocalAgentCommandBuilder.arguments(
            forModel: "codex",
            effort: .medium,
            codexModelName: "gpt-5.5"
        )

        XCTAssertTrue(arguments.contains("--model"))
        XCTAssertTrue(arguments.contains("gpt-5.5"))
        XCTAssertFalse(arguments.contains(LocalAgentCommandBuilder.codexFastModel))
    }

    func testSelectedCodexModelWinsOverFastPreset() {
        let arguments = LocalAgentCommandBuilder.arguments(
            forModel: "codex",
            effort: .medium,
            codexFastMode: true,
            codexModelName: "gpt-5.3-codex"
        )

        XCTAssertTrue(arguments.contains("--model"))
        XCTAssertTrue(arguments.contains("gpt-5.3-codex"))
        XCTAssertFalse(arguments.contains(LocalAgentCommandBuilder.codexFastModel))
    }

    func testCodexDefaultModeDoesNotAddFastModelOverride() {
        let arguments = LocalAgentCommandBuilder.arguments(
            forModel: "codex",
            effort: .low,
            codexFastMode: false
        )

        XCTAssertFalse(arguments.contains(LocalAgentCommandBuilder.codexFastModel))
    }

    func testCodexCommandCanWriteLastMessageToOutputFile() {
        let arguments = LocalAgentCommandBuilder.arguments(
            forModel: "codex",
            effort: .low,
            codexOutputPath: "/tmp/aireader-codex-output.txt"
        )

        XCTAssertTrue(arguments.contains("--output-last-message"))
        XCTAssertTrue(arguments.contains("/tmp/aireader-codex-output.txt"))
    }

    func testClaudeCommandUsesPrintModeAndRequestedEffort() {
        let arguments = LocalAgentCommandBuilder.arguments(
            forModel: "claude",
            effort: .high
        )

        XCTAssertTrue(arguments.contains("--print"))
        XCTAssertTrue(arguments.contains("--no-session-persistence"))
        XCTAssertTrue(arguments.contains("--permission-mode"))
        XCTAssertTrue(arguments.contains("dontAsk"))
        XCTAssertTrue(arguments.contains("--effort"))
        XCTAssertTrue(arguments.contains("high"))
        XCTAssertFalse(arguments.contains("--output-last-message"))
        XCTAssertFalse(arguments.contains("exec"))
    }

    func testClaudeCommandUsesSelectedModel() {
        let arguments = LocalAgentCommandBuilder.arguments(
            forModel: "claude",
            effort: .medium,
            claudeModelName: "sonnet"
        )

        XCTAssertTrue(arguments.contains("--model"))
        XCTAssertTrue(arguments.contains("sonnet"))
    }

    func testBlankClaudeModelFallsBackToCLIDefault() {
        let arguments = LocalAgentCommandBuilder.arguments(
            forModel: "claude",
            effort: .medium,
            claudeModelName: "   "
        )

        XCTAssertFalse(arguments.contains("--model"))
    }

    func testThinkingEffortHasReadableTitles() {
        XCTAssertEqual(LocalAgentThinkingEffort.low.title, "Low")
        XCTAssertEqual(LocalAgentThinkingEffort.xhigh.title, "Extra High")
        XCTAssertEqual(LocalAgentThinkingEffort.max.title, "Max")
    }
}
