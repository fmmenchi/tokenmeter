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

    /// Modification time of the status-line file, i.e. how fresh the quota is.
    public func updatedAt() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date
    }

    /// Expired windows are kept: the snapshot decides what an expired window means (ADR 0007).
    public func quotas() -> [ReportedQuota] {
        let observed = updatedAt()
        guard let data = try? Data(contentsOf: file),
              let limits = (try? JSONDecoder().decode(Input.self, from: data))?.rate_limits else { return [] }
        let windows: [(Input.Window?, Int)] = [(limits.five_hour, 300), (limits.seven_day, 10_080)]
        return windows.compactMap { window, minutes in
            guard let window, let used = window.used_percentage else { return nil }
            let resets = window.resets_at.map { Date(timeIntervalSince1970: $0) }
            return ReportedQuota(usedPercent: used, windowMinutes: minutes, resetsAt: resets, observedAt: observed)
        }
    }
}
