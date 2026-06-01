import Foundation

public enum LocalAgentExecutableDiscovery {
    public static let defaultWhichExecutableURL = URL(fileURLWithPath: "/usr/bin/which")
    public static let defaultExtraSearchDirectories = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin"
    ]

    public static func searchPath(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        extraSearchDirectories: [String] = defaultExtraSearchDirectories
    ) -> String {
        var directories: [String] = []
        if let path = environment["PATH"] {
            directories.append(contentsOf: path.split(separator: ":").map(String.init))
        }
        directories.append(contentsOf: extraSearchDirectories)
        directories.append(contentsOf: defaultExtraSearchDirectories)

        var seen = Set<String>()
        return directories
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
            .joined(separator: ":")
    }

    public static func discover(
        toolName: String,
        whichExecutableURL: URL = defaultWhichExecutableURL,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        extraSearchDirectories: [String] = defaultExtraSearchDirectories
    ) -> URL? {
        let trimmedToolName = toolName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToolName.isEmpty,
              FileManager.default.isExecutableFile(atPath: whichExecutableURL.path) else {
            return nil
        }

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = whichExecutableURL
        process.arguments = [trimmedToolName]
        var processEnvironment = environment
        processEnvironment["PATH"] = searchPath(
            environment: environment,
            extraSearchDirectories: extraSearchDirectories
        )
        process.environment = processEnvironment
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard let firstLine = output
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !firstLine.isEmpty,
              FileManager.default.isExecutableFile(atPath: firstLine) else {
            return nil
        }

        return URL(fileURLWithPath: firstLine)
    }
}
