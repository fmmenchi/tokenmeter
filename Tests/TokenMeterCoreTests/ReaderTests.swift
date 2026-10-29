import XCTest
@testable import TokenMeterCore

/// The built-in providers (ADR 0017) run end to end against a temporary home directory.
final class ReaderTests: XCTestCase {
    private var home: URL!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let home = home!
        addTeardownBlock { try? FileManager.default.removeItem(at: home) }
    }

    private let epoch = Date(timeIntervalSince1970: 0)

    private func source(_ provider: Provider) -> any ProviderSource {
        Providers.standard(config: home.appendingPathComponent("none.json"), home: home)
            .first { $0.info.provider == provider }!
    }

    private func write(_ text: String, to relative: String) throws -> URL {
        let url = home.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testClaudeKeepsLastUsagePerStreamedMessage() throws {
        let lines = [
            #"{"type":"assistant","timestamp":"2026-10-28T10:00:00.000Z","requestId":"r1","message":{"id":"m1","usage":{"input_tokens":2,"output_tokens":10,"cache_read_input_tokens":100,"cache_creation_input_tokens":5}}}"#,
            #"{"type":"assistant","timestamp":"2026-10-28T10:00:01.000Z","requestId":"r1","message":{"id":"m1","usage":{"input_tokens":2,"output_tokens":50,"cache_read_input_tokens":100,"cache_creation_input_tokens":5}}}"#,
            #"{"type":"user","timestamp":"2026-10-28T10:00:02.000Z","message":{"id":"x"}}"#,
            "not json",
        ].joined(separator: "\n") + "\n"
        _ = try write(lines, to: ".claude/projects/p/s.jsonl")

        let events = source(.claude).read(since: epoch).events

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].tokens, TokenCounts(input: 2, output: 50, cacheRead: 100, cacheWrite: 5))
    }

    func testClaudeMergesLinesWithAnIdAndNoRequestId() throws {
        let lines = [
            #"{"type":"assistant","timestamp":"2026-10-28T10:00:00.000Z","message":{"id":"m1","usage":{"output_tokens":5}}}"#,
            #"{"type":"assistant","timestamp":"2026-10-28T10:00:01.000Z","message":{"id":"m1","usage":{"output_tokens":9}}}"#,
            #"{"type":"assistant","timestamp":"2026-10-28T10:00:02.000Z","message":{"usage":{"output_tokens":3}}}"#,
        ].joined(separator: "\n") + "\n"
        _ = try write(lines, to: ".claude/projects/p/s.jsonl")

        XCTAssertEqual(source(.claude).read(since: epoch).events.map(\.tokens.output), [9, 3])
    }

    func testCodexTurnsCumulativeCountersIntoDeltasAndReadsQuota() throws {
        func line(_ ts: String, input: Int, cached: Int, out: Int, limits: String) -> String {
            #"{"timestamp":"\#(ts)","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":\#(input),"cached_input_tokens":\#(cached),"output_tokens":\#(out)}},"rate_limits":\#(limits)}}"#
        }
        let lines = [
            line("2026-10-28T10:00:00.000Z", input: 100, cached: 40, out: 10, limits: "null"),
            line("2026-10-28T10:01:00.000Z", input: 100, cached: 40, out: 10, limits: "null"),
            line("2026-10-28T10:02:00.000Z", input: 300, cached: 140, out: 30,
                 limits: #"{"primary":{"used_percent":42.5,"window_minutes":300,"resets_at":1793000000},"secondary":{"used_percent":9,"window_minutes":10080,"resets_at":1793500000},"plan_type":"team"}"#),
        ].joined(separator: "\n") + "\n"
        _ = try write(lines, to: ".codex/sessions/2026/rollout-a.jsonl")

        let reading = source(.chatgpt).read(since: epoch)

        XCTAssertEqual(reading.events.count, 2, "an unchanged counter must not produce an event")
        XCTAssertEqual(reading.events.map(\.tokens.total).reduce(0, +), 330)
        XCTAssertEqual(reading.events.map(\.tokens.input), [60, 100], "input is the total minus what was cached")
        XCTAssertEqual(reading.quotas.map(\.usedPercent), [42.5, 9])
        XCTAssertEqual(reading.quotas.map(\.windowMinutes), [300, 10_080])
        XCTAssertEqual(reading.plan, "Team")
        XCTAssertNotNil(reading.quotaUpdatedAt)
    }

    func testIncrementalReadPicksUpAppendsAndIgnoresPartialLine() throws {
        func message(_ id: String, out: Int) -> String {
            // Distinct seconds keep the sort order deterministic.
            #"{"type":"assistant","timestamp":"2026-10-28T10:00:0\#(out).000Z","message":{"id":"\#(id)","usage":{"output_tokens":\#(out)}}}"#
        }
        let file = try write(message("a", out: 1) + "\n", to: ".claude/projects/p/s.jsonl")
        let claude = source(.claude)
        XCTAssertEqual(claude.read(since: epoch).events.map(\.tokens.output), [1])

        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        // Second message is complete; the third is still being written (no newline yet).
        try handle.write(contentsOf: Data((message("b", out: 2) + "\n" + message("c", out: 4)).utf8))
        try handle.close()
        XCTAssertEqual(claude.read(since: epoch).events.map(\.tokens.output), [1, 2])

        let finish = try FileHandle(forWritingTo: file)
        try finish.seekToEnd()
        try finish.write(contentsOf: Data("\n".utf8))
        try finish.close()
        XCTAssertEqual(claude.read(since: epoch).events.map(\.tokens.output), [1, 2, 4])
    }

    func testClaudeQuotaReadsBothWindows() throws {
        let json = #"{"cwd":"/x","rate_limits":{"five_hour":{"used_percentage":23.5,"resets_at":1800003600},"seven_day":{"used_percentage":61,"resets_at":1799990000}}}"#
        _ = try write(json, to: ".tokenmeter/claude-statusline.json")

        let reading = source(.claude).read(since: epoch)

        XCTAssertEqual(reading.quotas.map(\.windowMinutes), [300, 10_080])
        XCTAssertEqual(reading.quotas.first?.usedPercent, 23.5)
        XCTAssertNotNil(reading.quotaUpdatedAt)
    }

    func testNothingOnDiskReadsAsNothing() {
        let reading = source(.claude).read(since: epoch)
        XCTAssertEqual(reading.events.count, 0)
        XCTAssertEqual(reading.quotas, [])
        XCTAssertNil(reading.quotaUpdatedAt)
        XCTAssertNil(reading.plan)
    }

    func testClaudePlanLabels() throws {
        func plan(_ account: String) throws -> String? {
            _ = try write(#"{"oauthAccount":{"emailAddress":"x@y.z"\#(account)}}"#, to: ".claude.json")
            return source(.claude).read(since: epoch).plan
        }
        XCTAssertEqual(try plan(#","organizationType":"claude_max","organizationRateLimitTier":"default_claude_max_20x""#), "Max 20x")
        XCTAssertEqual(try plan(#","organizationType":"claude_max","organizationRateLimitTier":"default_claude_max_5x""#), "Max 5x")
        XCTAssertEqual(try plan(#","organizationType":"claude_max""#), "Max")
        XCTAssertEqual(try plan(#","organizationType":"claude_pro""#), "Pro")
        XCTAssertEqual(try plan(#","organizationType":"claude_team""#), "Team")
        XCTAssertEqual(try plan(#","organizationType":"claude_something_new""#), "Something New")
        XCTAssertNil(try plan(""))
    }

    func testBuiltInProvidersDecodeAndComeInOrder() {
        let providers = ProviderConfigFile.builtIn().providers
        XCTAssertEqual(providers.map(\.id), ["claude", "chatgpt"])
    }
}
