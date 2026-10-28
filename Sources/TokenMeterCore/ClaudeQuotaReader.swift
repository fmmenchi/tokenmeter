import Foundation

/// Reads the quota Claude Code reports to its status line (ADR 0005).
public struct ClaudeQuotaReader: Sendable {
    public let file: URL

    public init(file: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".tokenmeter/claude-statusline.json")) {
        self.file = file
    }

    private struct Input: Decodable {
        struct Window: Decodable {
            let used_percentage: Double?
            let resets_at: Double?
        }
        struct Limits: Decodable {
            let five_hour: Window?
            let seven_day: Window?
        }
        let rate_limits: Limits?
    }

    public func quotas(now: Date = Date()) -> [ReportedQuota] {
        guard let data = try? Data(contentsOf: file),
              let limits = (try? JSONDecoder().decode(Input.self, from: data))?.rate_limits else { return [] }
        let windows: [(Input.Window?, Int)] = [(limits.five_hour, 300), (limits.seven_day, 10_080)]
        return windows.compactMap { window, minutes in
            guard let window, let used = window.used_percentage else { return nil }
            let resets = window.resets_at.map { Date(timeIntervalSince1970: $0) }
            if let resets, resets <= now { return nil }
            return ReportedQuota(usedPercent: used, windowMinutes: minutes, resetsAt: resets)
        }
    }
}
