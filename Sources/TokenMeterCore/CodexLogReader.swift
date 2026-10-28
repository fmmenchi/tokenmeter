import Foundation

/// Reads Codex CLI rollouts (`~/.codex/sessions/**/rollout-*.jsonl`), the ChatGPT-plan side.
public struct CodexLogReader: Sendable {
    public let root: URL

    public init(root: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex/sessions")) {
        self.root = root
    }

    public struct Result: Sendable {
        public var events: [UsageEvent]
        /// Most recent non-null provider-reported quota, if any log carried one.
        public var latestQuota: ReportedQuota?
    }

    private struct Line: Decodable {
        struct Payload: Decodable {
            struct Info: Decodable {
                struct Usage: Decodable {
                    let input_tokens: Int?
                    let cached_input_tokens: Int?
                    let cache_write_input_tokens: Int?
                    let output_tokens: Int?
                    let total_tokens: Int?
                }
                let total_token_usage: Usage?
            }
            struct Limits: Decodable {
                struct Window: Decodable {
                    let used_percent: Double?
                    let window_minutes: Int?
                    let resets_at: Double?
                }
                let primary: Window?
                let secondary: Window?
            }
            let type: String?
            let info: Info?
            let rate_limits: Limits?
        }
        let timestamp: String?
        let type: String?
        let payload: Payload?
    }

    public func read(since: Date) -> Result {
        var events: [UsageEvent] = []
        var quota: (Date, ReportedQuota)?
        let decoder = JSONDecoder()

        for file in LogFiles.jsonl(under: root, modifiedSince: since) {
            // Counters are cumulative per session: turn them into per-event deltas.
            var previous = TokenCounts()
            LogFiles.forEachLine(in: file) { data in
                guard let line = try? decoder.decode(Line.self, from: data),
                      line.type == "event_msg", line.payload?.type == "token_count",
                      let stamp = line.timestamp, let date = LogDate.parse(stamp) else { return }

                if let usage = line.payload?.info?.total_token_usage {
                    let cached = usage.cached_input_tokens ?? 0
                    let current = TokenCounts(
                        input: max((usage.input_tokens ?? 0) - cached, 0),
                        output: usage.output_tokens ?? 0,
                        cacheRead: cached,
                        cacheWrite: usage.cache_write_input_tokens ?? 0)
                    let delta = TokenCounts(
                        input: max(current.input - previous.input, 0),
                        output: max(current.output - previous.output, 0),
                        cacheRead: max(current.cacheRead - previous.cacheRead, 0),
                        cacheWrite: max(current.cacheWrite - previous.cacheWrite, 0))
                    previous = current
                    if delta.total > 0, date >= since {
                        events.append(UsageEvent(provider: .chatgpt, date: date, tokens: delta))
                    }
                }

                if let window = line.payload?.rate_limits?.primary, let used = window.used_percent,
                   quota == nil || date > quota!.0 {
                    quota = (date, ReportedQuota(
                        usedPercent: used, windowMinutes: window.window_minutes,
                        resetsAt: window.resets_at.map { Date(timeIntervalSince1970: $0) }))
                }
            }
        }
        return Result(events: events.sorted { $0.date < $1.date }, latestQuota: quota?.1)
    }
}
