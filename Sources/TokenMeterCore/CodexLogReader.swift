import Foundation

/// Reads Codex CLI rollouts (`~/.codex/sessions/**/rollout-*.jsonl`), the ChatGPT-plan side.
public final class CodexLogReader: @unchecked Sendable {
    public let root: URL

    private struct FileState {
        var offset: UInt64 = 0
        /// Counters are cumulative per session: events are the deltas between them.
        var previous = TokenCounts()
        var events: [UsageEvent] = []
        var quota: (Date, ReportedQuota)?
    }

    private let lock = NSLock()
    private var states: [URL: FileState] = [:]

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

    private let marker = Data(#""token_count""#.utf8)

    public func read(since: Date) -> Result {
        lock.lock()
        defer { lock.unlock() }
        let decoder = JSONDecoder()
        let files = LogFiles.jsonl(under: root, modifiedSince: since)
        states = states.filter { files.contains($0.key) }

        var events: [UsageEvent] = []
        var quota: (Date, ReportedQuota)?
        for file in files {
            var state = states[file] ?? FileState()
            let (lines, next) = LogFiles.newLines(in: file, from: state.offset, containing: marker)
            if next < state.offset { state = FileState() }
            state.offset = next
            for data in lines {
                guard let line = try? decoder.decode(Line.self, from: data),
                      line.type == "event_msg", line.payload?.type == "token_count",
                      let stamp = line.timestamp, let date = LogDate.parse(stamp) else { continue }

                if let usage = line.payload?.info?.total_token_usage {
                    let cached = usage.cached_input_tokens ?? 0
                    let current = TokenCounts(
                        input: max((usage.input_tokens ?? 0) - cached, 0),
                        output: usage.output_tokens ?? 0,
                        cacheRead: cached,
                        cacheWrite: usage.cache_write_input_tokens ?? 0)
                    let delta = TokenCounts(
                        input: max(current.input - state.previous.input, 0),
                        output: max(current.output - state.previous.output, 0),
                        cacheRead: max(current.cacheRead - state.previous.cacheRead, 0),
                        cacheWrite: max(current.cacheWrite - state.previous.cacheWrite, 0))
                    state.previous = current
                    if delta.total > 0 {
                        state.events.append(UsageEvent(provider: .chatgpt, date: date, tokens: delta))
                    }
                }

                if let window = line.payload?.rate_limits?.primary, let used = window.used_percent,
                   state.quota == nil || date > state.quota!.0 {
                    state.quota = (date, ReportedQuota(
                        usedPercent: used, windowMinutes: window.window_minutes,
                        resetsAt: window.resets_at.map { Date(timeIntervalSince1970: $0) }))
                }
            }
            state.events.removeAll { $0.date < since }
            states[file] = state
            events += state.events
            if let candidate = state.quota, quota == nil || candidate.0 > quota!.0 { quota = candidate }
        }
        return Result(events: events.sorted { $0.date < $1.date }, latestQuota: quota?.1)
    }
}
