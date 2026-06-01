import Foundation

public enum DeepSeekAPIKeyResolver {
    public static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        storedKey: String?
    ) -> String {
        let environmentKey = environment["DEEPSEEK_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !environmentKey.isEmpty {
            return environmentKey
        }

        return storedKey?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    public static func isEnvironmentBacked(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        let environmentKey = environment["DEEPSEEK_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !environmentKey.isEmpty
    }
}
