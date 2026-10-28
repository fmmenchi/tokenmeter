import XCTest
@testable import TokenMeterCore

final class ReaderTests: XCTestCase {
    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private let epoch = Date(timeIntervalSince1970: 0)

    func testClaudeKeepsLastUsagePerStreamedMessage() throws {
        let dir = try tempDir()
        let lines = [
            #"{"type":"assistant","timestamp":"2026-10-28T10:00:00.000Z","requestId":"r1","message":{"id":"m1","usage":{"input_tokens":2,"output_tokens":10,"cache_read_input_tokens":100,"cache_creation_input_tokens":5}}}"#,
            #"{"type":"assistant","timestamp":"2026-10-28T10:00:01.000Z","requestId":"r1","message":{"id":"m1","usage":{"input_tokens":2,"output_tokens":50,"cache_read_input_tokens":100,"cache_creation_input_tokens":5}}}"#,
            #"{"type":"user","timestamp":"2026-10-28T10:00:02.000Z","message":{"id":"x"}}"#,
            "not json",
        ].joined(separator: "\n") + "\n"
        try lines.write(to: dir.appendingPathComponent("s.jsonl"), atomically: true, encoding: .utf8)

        let events = ClaudeLogReader(root: dir).events(since: epoch)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].tokens, TokenCounts(input: 2, output: 50, cacheRead: 100, cacheWrite: 5))
    }

    func testCodexTurnsCumulativeCountersIntoDeltasAndReadsQuota() throws {
        let dir = try tempDir()
        func line(_ ts: String, input: Int, cached: Int, out: Int, limits: String) -> String {
            #"{"timestamp":"\#(ts)","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":\#(input),"cached_input_tokens":\#(cached),"output_tokens":\#(out)}},"rate_limits":\#(limits)}}"#
        }
        let lines = [
            line("2026-10-28T10:00:00.000Z", input: 100, cached: 40, out: 10, limits: "null"),
            line("2026-10-28T10:01:00.000Z", input: 100, cached: 40, out: 10, limits: "null"),
            line("2026-10-28T10:02:00.000Z", input: 300, cached: 140, out: 30,
                 limits: #"{"primary":{"used_percent":42.5,"window_minutes":300,"resets_at":1793000000}}"#),
        ].joined(separator: "\n") + "\n"
        try lines.write(to: dir.appendingPathComponent("rollout-a.jsonl"), atomically: true, encoding: .utf8)

        let result = CodexLogReader(root: dir).read(since: epoch)

        XCTAssertEqual(result.events.count, 2, "an unchanged counter must not produce an event")
        XCTAssertEqual(result.events.map(\.tokens.total).reduce(0, +), 330)
        XCTAssertEqual(result.latestQuotas.map(\.usedPercent), [42.5])
        XCTAssertEqual(result.latestQuotas.map(\.windowMinutes), [300])
    }

    func testIncrementalReadPicksUpAppendsAndIgnoresPartialLine() throws {
        let dir = try tempDir()
        let file = dir.appendingPathComponent("s.jsonl")
        func message(_ id: String, out: Int) -> String {
            // Distinct seconds keep the sort order deterministic.
            #"{"type":"assistant","timestamp":"2026-10-28T10:00:0\#(out).000Z","message":{"id":"\#(id)","usage":{"output_tokens":\#(out)}}}"#
        }
        try (message("a", out: 1) + "\n").write(to: file, atomically: true, encoding: .utf8)
        let reader = ClaudeLogReader(root: dir)
        XCTAssertEqual(reader.events(since: epoch).map(\.tokens.output), [1])

        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        // Second message is complete; the third is still being written (no newline yet).
        try handle.write(contentsOf: Data((message("b", out: 2) + "\n" + message("c", out: 4)).utf8))
        try handle.close()
        XCTAssertEqual(reader.events(since: epoch).map(\.tokens.output), [1, 2])

        let finish = try FileHandle(forWritingTo: file)
        try finish.seekToEnd()
        try finish.write(contentsOf: Data("\n".utf8))
        try finish.close()
        XCTAssertEqual(reader.events(since: epoch).map(\.tokens.output), [1, 2, 4])
    }

    func testClaudeQuotaReadsBothWindowsAndDropsExpired() throws {
        let dir = try tempDir()
        let file = dir.appendingPathComponent("claude-statusline.json")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let json = #"{"cwd":"/x","rate_limits":{"five_hour":{"used_percentage":23.5,"resets_at":1800003600},"seven_day":{"used_percentage":61,"resets_at":1799990000}}}"#
        try json.write(to: file, atomically: true, encoding: .utf8)

        let quotas = ClaudeQuotaReader(file: file).quotas(now: now)

        XCTAssertEqual(quotas.map(\.windowMinutes), [300], "the 7d window already reset")
        XCTAssertEqual(quotas.first?.usedPercent, 23.5)
        XCTAssertEqual(ClaudeQuotaReader(file: dir.appendingPathComponent("missing.json")).quotas(now: now), [])
    }
}
