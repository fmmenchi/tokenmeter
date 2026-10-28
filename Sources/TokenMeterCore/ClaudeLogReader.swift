import Foundation

/// Reads Claude Code transcripts (`~/.claude/projects/*/*.jsonl`).
public struct ClaudeLogReader: Sendable {
    public let root: URL

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
        // A streamed message is logged several times with growing usage: keep the last per id.
        var byID: [String: UsageEvent] = [:]
        var anonymous: [UsageEvent] = []
        let decoder = JSONDecoder()

        for file in LogFiles.jsonl(under: root, modifiedSince: since) {
            LogFiles.forEachLine(in: file) { data in
                guard let line = try? decoder.decode(Line.self, from: data),
                      line.type == "assistant",
                      let usage = line.message?.usage,
                      let stamp = line.timestamp, let date = LogDate.parse(stamp),
                      date >= since else { return }
                let event = UsageEvent(provider: .claude, date: date, tokens: TokenCounts(
                    input: usage.input_tokens ?? 0,
                    output: usage.output_tokens ?? 0,
                    cacheRead: usage.cache_read_input_tokens ?? 0,
                    cacheWrite: usage.cache_creation_input_tokens ?? 0))
                if let id = line.message?.id {
                    byID[id + (line.requestId ?? "")] = event
                } else {
                    anonymous.append(event)
                }
            }
        }
        return (Array(byID.values) + anonymous).sorted { $0.date < $1.date }
    }
}
