import XCTest
@testable import TokenMeterCore

final class ConfiguredSourceTests: XCTestCase {
    private let epoch = Date(timeIntervalSince1970: 0)

    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func source(_ json: String) throws -> ConfiguredSource {
        ConfiguredSource(try JSONDecoder().decode(ProviderConfig.self, from: Data(json.utf8)))
    }

    private func claudeConfig(logs: URL, quota: URL) -> String {
        """
        {"id":"claude2","title":"Claude 2","windows":[300,10080],
         "log":{"root":"\(logs.path)","contains":"\\"usage\\":","where":{"type":"assistant"},"timestamp":"timestamp"},
         "usage":{"mode":"perEvent","dedupeBy":["message.id","requestId"],"tokens":{
           "input":"message.usage.input_tokens","output":"message.usage.output_tokens",
           "cacheRead":"message.usage.cache_read_input_tokens","cacheWrite":"message.usage.cache_creation_input_tokens"}},
         "quota":{"file":"\(quota.path)","windows":[
           {"at":"rate_limits.five_hour","minutes":300,"usedPercent":"used_percentage","resetsAt":"resets_at"},
           {"at":"rate_limits.seven_day","minutes":10080,"usedPercent":"used_percentage","resetsAt":"resets_at"}]}}
        """
    }

    func testConfigReadsEventsAndQuotaFromAFile() throws {
        let dir = try tempDir()
        let lines = [
            #"{"type":"assistant","timestamp":"2026-10-28T10:00:00.000Z","requestId":"r1","message":{"id":"m1","usage":{"input_tokens":2,"output_tokens":10,"cache_read_input_tokens":100,"cache_creation_input_tokens":5}}}"#,
            #"{"type":"assistant","timestamp":"2026-10-28T10:00:01.000Z","requestId":"r1","message":{"id":"m1","usage":{"input_tokens":2,"output_tokens":50,"cache_read_input_tokens":100,"cache_creation_input_tokens":5}}}"#,
            #"{"type":"assistant","timestamp":"2026-10-28T10:00:03.000Z","message":{"usage":{"output_tokens":7}}}"#,
            #"{"type":"user","timestamp":"2026-10-28T10:00:02.000Z","message":{"id":"x"}}"#,
            "not json",
        ].joined(separator: "\n") + "\n"
        try lines.write(to: dir.appendingPathComponent("s.jsonl"), atomically: true, encoding: .utf8)
        let quota = dir.appendingPathComponent("q.json")
        try #"{"rate_limits":{"five_hour":{"used_percentage":23.5,"resets_at":1800003600},"seven_day":{"used_percentage":61,"resets_at":1799990000}}}"#
            .write(to: quota, atomically: true, encoding: .utf8)

        let configured = try source(claudeConfig(logs: dir, quota: quota)).read(since: epoch)

        XCTAssertEqual(configured.events.map(\.tokens.output), [50, 7])
        XCTAssertEqual(configured.quotas.map(\.usedPercent), [23.5, 61])
        XCTAssertNotNil(configured.quotaUpdatedAt)
    }

    func testAnEventCarriesItsModelAndAKeyThatIdentifiesIt() throws {
        let dir = try tempDir()
        let lines = [
            #"{"type":"assistant","timestamp":"2026-10-28T10:00:00.000Z","requestId":"r1","message":{"id":"m1","model":"claude-fable-5-1","usage":{"output_tokens":10}}}"#,
            #"{"type":"assistant","timestamp":"2026-10-28T10:00:01.000Z","requestId":"r1","message":{"id":"m1","model":"claude-fable-5-1","usage":{"output_tokens":50}}}"#,
            #"{"type":"assistant","timestamp":"2026-10-28T10:00:02.000Z","requestId":"r2","message":{"id":"m2","usage":{"output_tokens":7}}}"#,
            #"{"type":"assistant","timestamp":"2026-10-28T10:00:03.000Z","message":{"model":"claude-opus-5-5","usage":{"output_tokens":3}}}"#,
        ].joined(separator: "\n") + "\n"
        try lines.write(to: dir.appendingPathComponent("s.jsonl"), atomically: true, encoding: .utf8)
        let config = """
        {"id":"c","title":"C","windows":[300],
         "log":{"root":"\(dir.path)","contains":"\\"usage\\":","where":{"type":"assistant"},"timestamp":"timestamp"},
         "usage":{"mode":"perEvent","dedupeBy":["message.id","requestId"],"model":"message.model",
           "tokens":{"output":"message.usage.output_tokens"}}}
        """

        let events = try source(config).read(since: epoch).events

        XCTAssertEqual(events.map(\.tokens.output), [50, 7, 3], "the repeated message counts once")
        XCTAssertEqual(events.map(\.model), ["claude-fable-5-1", nil, "claude-opus-5-5"], "a line with no model leaves it empty")
        XCTAssertEqual(events[0].key, "message.id=m1\u{1f}requestId=r1")
        XCTAssertEqual(events[2].key, "s.jsonl|2026-10-28T10:00:03.000Z", "a line with no ids is known by where it was read")
        XCTAssertEqual(Set(events.compactMap(\.key)).count, 3)
    }

    func testACumulativeEventIsKnownByItsFileAndItsTime() throws {
        let dir = try tempDir()
        try """
        {"ts":"2026-10-28T10:00:01.000Z","used":{"total":10}}
        {"ts":"2026-10-28T10:00:02.000Z","used":{"total":25}}

        """.write(to: dir.appendingPathComponent("rollout-a.jsonl"), atomically: true, encoding: .utf8)
        let config = """
        {"id":"x","title":"X","windows":[60],"log":{"root":"\(dir.path)","timestamp":"ts"},
         "usage":{"mode":"cumulative","tokens":{"output":"used.total"}}}
        """

        let events = try source(config).read(since: epoch).events

        XCTAssertEqual(events.map(\.key), ["rollout-a.jsonl|2026-10-28T10:00:01.000Z", "rollout-a.jsonl|2026-10-28T10:00:02.000Z"])
        XCTAssertEqual(events.map(\.model), [nil, nil])
    }

    func testEveryWindowALogReportedIsKeptWithItsHighestPercentage() throws {
        let dir = try tempDir()
        func line(_ ts: String, primary: Double, resets: Int, weekly: Double) -> String {
            #"{"timestamp":"\#(ts)","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1,"output_tokens":1}},"rate_limits":{"primary":{"used_percent":\#(primary),"window_minutes":300,"resets_at":\#(resets)},"secondary":{"used_percent":\#(weekly),"window_minutes":10080,"resets_at":1793500000}}}}"#
        }
        let lines = [
            line("2026-10-28T10:00:00.000Z", primary: 10, resets: 1793000000, weekly: 5),
            line("2026-10-28T10:30:00.000Z", primary: 40, resets: 1793000000, weekly: 7),
            line("2026-10-28T10:45:00.000Z", primary: 35, resets: 1793000000, weekly: 7),
            line("2026-10-28T16:00:00.000Z", primary: 3, resets: 1793018000, weekly: 9),
        ].joined(separator: "\n") + "\n"
        try lines.write(to: dir.appendingPathComponent("rollout-a.jsonl"), atomically: true, encoding: .utf8)
        let config = """
        {"id":"codex3","title":"Codex 3","windows":[300,10080],
         "log":{"root":"\(dir.path)","contains":"\\"token_count\\"","where":{"type":"event_msg","payload.type":"token_count"},"timestamp":"timestamp"},
         "usage":{"mode":"cumulative","tokens":{"output":"payload.info.total_token_usage.output_tokens"}},
         "quota":{"windows":[
           {"at":"payload.rate_limits.primary","minutesPath":"window_minutes","usedPercent":"used_percent","resetsAt":"resets_at"},
           {"at":"payload.rate_limits.secondary","minutesPath":"window_minutes","usedPercent":"used_percent","resetsAt":"resets_at"}]}}
        """

        let configured = try source(config).read(since: epoch)

        XCTAssertEqual(configured.quotas.map(\.usedPercent), [3, 9], "the last reading of each length is as it was")
        let history = configured.history
        XCTAssertEqual(history.map(\.windowMinutes), [300, 300, 10080])
        XCTAssertEqual(history.map(\.usedPercent), [40, 3, 9], "a window keeps the highest percentage, not the last")
        let first = LogDate.parse("2026-10-28T10:00:00.000Z")!
        let last = LogDate.parse("2026-10-28T10:45:00.000Z")!
        XCTAssertEqual(history[0].firstObserved, first)
        XCTAssertEqual(history[0].lastObserved, last)
        XCTAssertEqual(history[0].resetsAt, Date(timeIntervalSince1970: 1793000000))
        XCTAssertEqual(history[2].firstObserved, first, "the weekly window is one window across the lines")
    }

    func testReadingTheSameLogAgainAddsNoWindow() throws {
        let dir = try tempDir()
        let file = dir.appendingPathComponent("rollout-a.jsonl")
        let line = #"{"timestamp":"2026-10-28T10:00:00.000Z","payload":{"rate_limits":{"primary":{"used_percent":12,"window_minutes":300,"resets_at":1793000000}}}}"# + "\n"
        try line.write(to: file, atomically: true, encoding: .utf8)
        let config = """
        {"id":"codex4","title":"Codex 4","windows":[300],
         "log":{"root":"\(dir.path)","timestamp":"timestamp"},
         "quota":{"windows":[{"at":"payload.rate_limits.primary","minutesPath":"window_minutes","usedPercent":"used_percent","resetsAt":"resets_at"}]}}
        """
        let codex = try source(config)
        XCTAssertEqual(codex.read(since: epoch).history.count, 1)
        XCTAssertEqual(codex.read(since: epoch).history.count, 1, "a second read of the same bytes")
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(line.replacingOccurrences(of: "12", with: "30").replacingOccurrences(of: "10:00:00", with: "10:05:00").utf8))
        try handle.close()
        let after = codex.read(since: epoch).history
        XCTAssertEqual(after.count, 1)
        XCTAssertEqual(after.first?.usedPercent, 30)
    }

    func testConfigReadsCumulativeUsageAndQuotaFromTheLog() throws {
        let dir = try tempDir()
        func line(_ ts: String, input: Int, cached: Int, out: Int, limits: String) -> String {
            #"{"timestamp":"\#(ts)","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":\#(input),"cached_input_tokens":\#(cached),"output_tokens":\#(out)}},"rate_limits":\#(limits)}}"#
        }
        let limits = #"{"primary":{"used_percent":42.5,"window_minutes":300,"resets_at":1793000000},"secondary":{"used_percent":9,"window_minutes":10080,"resets_at":1793500000},"plan_type":"team"}"#
        let lines = [
            line("2026-10-28T10:00:00.000Z", input: 100, cached: 40, out: 10, limits: "null"),
            line("2026-10-28T10:01:00.000Z", input: 100, cached: 40, out: 10, limits: "null"),
            line("2026-10-28T10:02:00.000Z", input: 300, cached: 140, out: 30, limits: limits),
        ].joined(separator: "\n") + "\n"
        try lines.write(to: dir.appendingPathComponent("rollout-a.jsonl"), atomically: true, encoding: .utf8)
        let config = """
        {"id":"codex2","title":"Codex 2","windows":[300,10080],
         "log":{"root":"\(dir.path)","contains":"\\"token_count\\"","where":{"type":"event_msg","payload.type":"token_count"},"timestamp":"timestamp"},
         "usage":{"mode":"cumulative","tokens":{
           "input":{"path":"payload.info.total_token_usage.input_tokens","minus":"payload.info.total_token_usage.cached_input_tokens"},
           "output":"payload.info.total_token_usage.output_tokens",
           "cacheRead":"payload.info.total_token_usage.cached_input_tokens"}},
         "quota":{"windows":[
           {"at":"payload.rate_limits.primary","minutesPath":"window_minutes","usedPercent":"used_percent","resetsAt":"resets_at"},
           {"at":"payload.rate_limits.secondary","minutesPath":"window_minutes","usedPercent":"used_percent","resetsAt":"resets_at"}]},
         "plan":{"path":"payload.rate_limits.plan_type"}}
        """

        let configured = try source(config).read(since: epoch)

        XCTAssertEqual(configured.events.map(\.tokens.total), [110, 220])
        XCTAssertEqual(configured.quotas.map(\.usedPercent), [42.5, 9])
        XCTAssertEqual(configured.plan, "Team")
    }

    func testIncrementalReadKeepsCumulativeStateAcrossReads() throws {
        let dir = try tempDir()
        let file = dir.appendingPathComponent("a.jsonl")
        func line(_ second: Int, total: Int) -> String {
            #"{"ts":"2026-10-28T10:00:0\#(second).000Z","used":{"total":\#(total)}}"# + "\n"
        }
        try line(1, total: 10).write(to: file, atomically: true, encoding: .utf8)
        let config = """
        {"id":"x","title":"X","windows":[60],"log":{"root":"\(dir.path)","timestamp":"ts"},
         "usage":{"mode":"cumulative","tokens":{"output":"used.total"}}}
        """
        let x = try source(config)
        XCTAssertEqual(x.read(since: epoch).events.map(\.tokens.output), [10])

        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(line(2, total: 25).utf8))
        try handle.close()
        XCTAssertEqual(x.read(since: epoch).events.map(\.tokens.output), [10, 15])
    }

    func testDedupeUsesThePathsALineHasEvenWhenAnotherIsMissing() throws {
        let dir = try tempDir()
        let lines = [
            #"{"type":"assistant","timestamp":"2026-10-28T10:00:00.000Z","message":{"id":"m1","usage":{"output_tokens":5}}}"#,
            #"{"type":"assistant","timestamp":"2026-10-28T10:00:01.000Z","message":{"id":"m1","usage":{"output_tokens":9}}}"#,
        ].joined(separator: "\n") + "\n"
        try lines.write(to: dir.appendingPathComponent("s.jsonl"), atomically: true, encoding: .utf8)

        let events = try source(claudeConfig(logs: dir, quota: dir.appendingPathComponent("none.json"))).read(since: epoch).events

        XCTAssertEqual(events.map(\.tokens.output), [9], "no requestId: the id alone still merges the two lines")
    }

    func testWindowLabelsAndMissingFilesAreHandled() throws {
        let x = try source(#"{"id":"x","title":"X","windows":[300,10080,45],"quota":{"file":"/nonexistent.json","windows":[]}}"#)
        XCTAssertEqual(x.info.windows.map(\.name), ["5h", "7d", "45m"])
        let reading = x.read(since: epoch)
        XCTAssertEqual(reading.events.count, 0)
        XCTAssertNil(reading.quotaUpdatedAt)
    }

    func testConfigFileLoadingRejectsWhatCannotBeUsed() throws {
        let dir = try tempDir()
        let url = dir.appendingPathComponent("providers.json")
        XCTAssertNil(try ProviderConfigFile.load(from: url), "a missing file is fine")

        try #"{"version":2,"providers":[]}"#.write(to: url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ProviderConfigFile.load(from: url))
        try #"{"version":1,"providers":[{"id":"a","title":"A","windows":[60]},{"id":"a","title":"B","windows":[60]}]}"#
            .write(to: url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ProviderConfigFile.load(from: url))
        try "not json".write(to: url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ProviderConfigFile.load(from: url))
    }

    func testMissingFileIsCreatedFromTheSeedAndThenReadLikeAnyOther() throws {
        let dir = try tempDir()
        let url = dir.appendingPathComponent("sub/providers.json")

        XCTAssertEqual(Providers.standard(config: url, home: dir).map(\.info.title), ["Claude", "ChatGPT"])
        XCTAssertEqual(try ProviderConfigFile.load(from: url)?.providers.map(\.id), ["claude", "chatgpt"],
                       "the first run wrote the file")

        try #"{"version":1,"providers":[{"id":"gemini","title":"Gemini","windows":[300]}]}"#
            .write(to: url, atomically: true, encoding: .utf8)
        XCTAssertEqual(Providers.standard(config: url, home: dir).map(\.info.title), ["Gemini"],
                       "the file is the only source: no Claude unless it is in the file")
    }

    func testFileOrderIsPanelOrderAndAnyEntryCanBeEdited() throws {
        let dir = try tempDir()
        let url = dir.appendingPathComponent("providers.json")
        try #"{"version":1,"providers":[{"id":"chatgpt","title":"Mine","windows":[60]},{"id":"claude","title":"Claude","windows":[300]}]}"#
            .write(to: url, atomically: true, encoding: .utf8)
        let sources = Providers.standard(config: url, home: dir)
        XCTAssertEqual(sources.map(\.info.provider.rawValue), ["chatgpt", "claude"])
        XCTAssertEqual(sources[0].info.title, "Mine")
        XCTAssertEqual(sources[0].info.windows.map(\.name), ["1h"])
    }

    func testBrokenFileIsKeptAndTheSeedRunsInItsPlace() throws {
        let dir = try tempDir()
        let url = dir.appendingPathComponent("providers.json")
        try "broken".write(to: url, atomically: true, encoding: .utf8)

        XCTAssertEqual(Providers.standard(config: url, home: dir).map(\.info.title), ["Claude", "ChatGPT"])
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "broken", "never overwrite what the user wrote")
        XCTAssertFalse(ProviderConfigFile.writeSeed(to: url), "an existing file is left alone")
    }

    func testPlanRulesPickTheFirstMatchAndFallBackToTheCapitalisedValue() throws {
        let spec = try JSONDecoder().decode(ProviderConfig.Plan.self, from: Data("""
        {"path":"a.type","stripPrefix":"x_","labels":[
          {"path":"a.tier","contains":"big","label":"Big"},{"equals":"x_one","label":"One"}]}
        """.utf8))
        func label(_ json: String) -> String? {
            ConfiguredSource.planLabel(spec, in: (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:])
        }
        XCTAssertEqual(label(#"{"a":{"type":"x_one","tier":"BIG_ONE"}}"#), "Big", "rules run in order, case-insensitively")
        XCTAssertEqual(label(#"{"a":{"type":"X_ONE"}}"#), "One")
        XCTAssertEqual(label(#"{"a":{"type":"x_new_plan"}}"#), "New Plan")
        XCTAssertNil(label(#"{"a":{}}"#))
    }
}
