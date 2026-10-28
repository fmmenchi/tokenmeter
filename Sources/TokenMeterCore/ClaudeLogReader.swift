import Foundation

/// Reads Claude Code transcripts (`~/.claude/projects/*/*.jsonl`) incrementally (ADR 0004).
public final class ClaudeLogReader: @unchecked Sendable {
    public let root: URL

    private struct FileState {
        var offset: UInt64 = 0
        // A streamed message is logged several times with growing usage: keep the last per id.
        var byID: [String: UsageEvent] = [:]
        var anonymous: [UsageEvent] = []
    }

    private let lock = NSLock()
    private var states: [URL: FileState] = [:]
    /// Only assistant lines carry usage; the others are skipped before decoding.
    private let marker = Data(#""usage":"#.utf8)

    public init(root: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/projects")) {
        self.root = root
    }

    private struct Line: Decodable {
        struct Message: Decodable {
            struct Usage: Decodable {
                let input_tokens: Int?
                let output_tokens: Int?
                let cache_read_input_tokens: Int?
                let cache_creation_input_tokens: Int?
            }
            let id: String?
            let usage: Usage?
        }
        let type: String?
        let timestamp: String?
        let requestId: String?
        let message: Message?
    }

    public func events(since: Date) -> [UsageEvent] {
        lock.lock()
        defer { lock.unlock() }
        let decoder = JSONDecoder()
        let files = LogFiles.jsonl(under: root, modifiedSince: since)
        states = states.filter { files.contains($0.key) }

        var result: [UsageEvent] = []
        for file in files {
            var state = states[file] ?? FileState()
            let (lines, next) = LogFiles.newLines(in: file, from: state.offset, containing: marker)
            if next < state.offset { state = FileState() }
            state.offset = next
            for data in lines {
                guard let line = try? decoder.decode(Line.self, from: data),
                      line.type == "assistant",
                      let usage = line.message?.usage,
                      let stamp = line.timestamp, let date = LogDate.parse(stamp) else { continue }
                let event = UsageEvent(provider: .claude, date: date, tokens: TokenCounts(
                    input: usage.input_tokens ?? 0,
                    output: usage.output_tokens ?? 0,
                    cacheRead: usage.cache_read_input_tokens ?? 0,
                    cacheWrite: usage.cache_creation_input_tokens ?? 0))
                if let id = line.message?.id {
                    state.byID[id + (line.requestId ?? "")] = event
                } else {
                    state.anonymous.append(event)
                }
            }
            state.byID = state.byID.filter { $0.value.date >= since }
            state.anonymous.removeAll { $0.date < since }
            states[file] = state
            result += state.byID.values + state.anonymous
        }
        return result.sorted { $0.date < $1.date }
    }
}
