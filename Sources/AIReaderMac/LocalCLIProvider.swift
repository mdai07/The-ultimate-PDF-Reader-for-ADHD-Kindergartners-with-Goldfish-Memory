import Foundation
import PaperReaderCore

final class LocalCLIProvider: AIProvider {
    enum ProviderError: LocalizedError {
        case missingExecutable
        case timedOut(TimeInterval)
        case failed(status: Int32, stderr: String)
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .missingExecutable:
                return "Local CLI executable is not available."
            case .timedOut(let timeout):
                return "Local CLI timed out after \(Int(timeout)) seconds."
            case .failed(let status, let stderr):
                let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                return detail.isEmpty
                    ? "Local CLI exited with status \(status)."
                    : "Local CLI exited with status \(status): \(detail)"
            case .emptyResponse:
                return "Local CLI returned an empty response."
            }
        }
    }

    let profile: AgentProfile

    private let executableURL: URL
    private let effort: LocalAgentThinkingEffort
    private let codexFastMode: Bool
    private let codexModelName: String
    private let claudeModelName: String
    private let timeoutSeconds: TimeInterval

    init(
        profile: AgentProfile,
        executableURL: URL,
        effort: LocalAgentThinkingEffort,
        codexFastMode: Bool = false,
        codexModelName: String = "",
        claudeModelName: String = "",
        timeoutSeconds: TimeInterval = 180
    ) {
        self.profile = profile
        self.executableURL = executableURL
        self.effort = effort
        self.codexFastMode = codexFastMode
        self.codexModelName = codexModelName
        self.claudeModelName = claudeModelName
        self.timeoutSeconds = timeoutSeconds
    }

    func complete(messages: [AIMessage]) async throws -> AIMessage {
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw ProviderError.missingExecutable
        }

        let prompt = Self.prompt(from: messages)
        let codexOutputURL = profile.model == "codex"
            ? FileManager.default.temporaryDirectory
                .appendingPathComponent("aireader-codex-\(UUID().uuidString).txt")
            : nil
        let arguments = LocalAgentCommandBuilder.arguments(
            forModel: profile.model,
            effort: effort,
            codexFastMode: codexFastMode,
            codexModelName: codexModelName,
            claudeModelName: claudeModelName,
            codexOutputPath: codexOutputURL?.path
        )
        let content = try await Self.runProcess(
            executableURL: executableURL,
            arguments: arguments,
            prompt: prompt,
            preferredOutputURL: codexOutputURL,
            timeoutSeconds: timeoutSeconds
        )
        if let codexOutputURL {
            try? FileManager.default.removeItem(at: codexOutputURL)
        }
        return AIMessage(role: .assistant, content: content)
    }

    func stream(messages: [AIMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let reply = try await complete(messages: messages)
                    continuation.yield(reply.content)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private static func prompt(from messages: [AIMessage]) -> String {
        messages.map { message in
            let role = message.role.rawValue.uppercased()
            return "\(role):\n\(message.contentIncludingAttachmentSummaries)"
        }
        .joined(separator: "\n\n")
    }

    private static func runProcess(
        executableURL: URL,
        arguments: [String],
        prompt: String,
        preferredOutputURL: URL?,
        timeoutSeconds: TimeInterval
    ) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            let inputPipe = Pipe()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = executableURL
            process.arguments = arguments
            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()

            let outputReader = asyncReadData(from: outputPipe.fileHandleForReading)
            let errorReader = asyncReadData(from: errorPipe.fileHandleForReading)

            if let data = prompt.data(using: .utf8) {
                inputPipe.fileHandleForWriting.write(data)
            }
            try? inputPipe.fileHandleForWriting.close()

            let startedAt = Date()
            while process.isRunning {
                if Date().timeIntervalSince(startedAt) > timeoutSeconds {
                    process.terminate()
                    throw ProviderError.timedOut(timeoutSeconds)
                }
                try Task.checkCancellation()
                try await Task.sleep(nanoseconds: 50_000_000)
            }

            let outputData = outputReader()
            let errorData = errorReader()
            let output = String(data: outputData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let error = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard process.terminationStatus == 0 else {
                throw ProviderError.failed(status: process.terminationStatus, stderr: error)
            }
            if let preferredOutputURL,
               let preferredOutput = try? String(contentsOf: preferredOutputURL, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !preferredOutput.isEmpty {
                return preferredOutput
            }
            guard !output.isEmpty else {
                if !error.isEmpty {
                    return error
                }
                throw ProviderError.emptyResponse
            }
            return output
        }
        .value
    }

    private static func asyncReadData(from handle: FileHandle) -> () -> Data {
        let group = DispatchGroup()
        let storage = LockedData()
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            storage.data = handle.readDataToEndOfFile()
            group.leave()
        }
        return {
            group.wait()
            return storage.data
        }
    }
}

private final class LockedData: @unchecked Sendable {
    private let lock = NSLock()
    private var _data = Data()

    var data: Data {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _data
        }
        set {
            lock.lock()
            _data = newValue
            lock.unlock()
        }
    }
}
