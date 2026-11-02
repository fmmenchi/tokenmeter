import XCTest
@testable import TokenMeterCore

final class UsageIngestorTests: XCTestCase {
    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func claude(logs: URL, quota: URL) throws -> ConfiguredSource {
        let json = """
        {"id":"claude","title":"Claude","windows":[300,10080],
         "log":{"root":"\(logs.path)","contains":"\\"usage\\":","where":{"type":"assistant"},"timestamp":"timestamp"},
         "usage":{"mode":"perEvent","dedupeBy":["message.id","requestId"],"model":"message.model",
           "tokens":{"input":"message.usage.input_tokens","output":"message.usage.output_tokens"}},
         "quota":{"file":"\(quota.path)","windows":[
           {"at":"rate_limits.seven_day","minutes":10080,"usedPercent":"used_percentage","resetsAt":"resets_at"},
           {"file":"\(quota.path)","each":"limits","where":{"kind":"weekly_scoped"},"scope":"scope.model.display_name","minutes":10080,
            "usedPercent":"percent","resetsAt":"resets_at"}]}}
        """
        return ConfiguredSource(try JSONDecoder().decode(ProviderConfig.self, from: Data(json.utf8)))
    }

    private func line(_ stamp: String, id: String, model: String? = "claude-fable-5-1", output: Int) -> String {
        let model = model.map { #""model":"\#($0)","# } ?? ""
        return #"{"type":"assistant","timestamp":"\#(stamp)","requestId":"r-\#(id)","message":{"id":"\#(id)",\#(model)"usage":{"input_tokens":1,"output_tokens":\#(output)}}}"#
    }

    private func append(_ text: String, to file: URL) throws {
        if !FileManager.default.fileExists(atPath: file.path) { try "".write(to: file, atomically: true, encoding: .utf8) }
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(text.utf8))
        try handle.close()
    }

    private struct Rig {
        let logs: URL
        let quota: URL
        let store: UsageStore
        let ingestor: UsageIngestor
    }

    private func rig() throws -> Rig {
        let dir = try tempDir()
        let logs = dir.appendingPathComponent("logs")
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        let quota = dir.appendingPathComponent("quota.json")
        try #"{"rate_limits":{"seven_day":{"used_percentage":61,"resets_at":1799990000}},"limits":[{"kind":"weekly_scoped","percent":53,"resets_at":1799990000,"scope":{"model":{"display_name":"Fable"}}}]}"#
            .write(to: quota, atomically: true, encoding: .utf8)
        let store = try UsageStore(url: dir.appendingPathComponent("db/usage.sqlite"))
        let ingestor = UsageIngestor(sources: [try claude(logs: logs, quota: quota)], store: store)
        return Rig(logs: logs, quota: quota, store: store, ingestor: ingestor)
    }

    func testEveryMessageOfEveryFileIsKeptOnceWhateverItsAge() throws {
        let rig = try rig()
        try append([line("2025-01-05T10:00:00.000Z", id: "old", output: 4)].joined(separator: "\n") + "\n",
                   to: rig.logs.appendingPathComponent("a.jsonl"))
        try append([line("2026-10-28T10:00:00.000Z", id: "m1", output: 10), line("2026-10-28T10:00:01.000Z", id: "m1", output: 50),
                    line("2026-10-28T10:00:02.000Z", id: "m2", model: nil, output: 7)].joined(separator: "\n") + "\n",
                   to: rig.logs.appendingPathComponent("b.jsonl"))

        let summary = rig.ingestor.ingest(now: LogDate.parse("2026-10-29T00:00:00.000Z")!)

        XCTAssertEqual(summary.messages, 3, "m1 is repeated in the log and counts once")
        let totals = Dictionary(uniqueKeysWithValues: rig.store.modelTotals(provider: .claude).map { ($0.model ?? "none", $0.output) })
        XCTAssertEqual(totals, ["claude-fable-5-1": 54, "none": 7], "the message from 2025 is there, with the last count of m1")
    }

    func testIngestingAgainAddsNothingAndANewLineIsAdded() throws {
        let rig = try rig()
        let file = rig.logs.appendingPathComponent("a.jsonl")
        let now = LogDate.parse("2026-10-29T00:00:00.000Z")!
        try append(line("2026-10-28T10:00:00.000Z", id: "m1", output: 10) + "\n", to: file)
        XCTAssertEqual(rig.ingestor.ingest(now: now).messages, 1)
        XCTAssertEqual(rig.ingestor.ingest(now: now).messages, 0, "the same file again")
        try append(line("2026-10-28T11:00:00.000Z", id: "m2", output: 5) + "\n", to: file)
        XCTAssertEqual(rig.ingestor.ingest(now: now).messages, 1, "only the new line")
        XCTAssertEqual(rig.store.messageCount(), 2)
    }

    func testTwoIngestorsOverTheSameFilesDoNotDoubleTheCount() throws {
        let rig = try rig()
        try append(line("2026-10-28T10:00:00.000Z", id: "m1", output: 10) + "\n", to: rig.logs.appendingPathComponent("a.jsonl"))
        let other = UsageIngestor(sources: [try claude(logs: rig.logs, quota: rig.quota)], store: rig.store)
        let now = LogDate.parse("2026-10-29T00:00:00.000Z")!
        rig.ingestor.ingest(now: now)
        XCTAssertEqual(other.ingest(now: now).messages, 0, "another copy of the app, or a restart")
        XCTAssertEqual(rig.store.messageCount(), 1)
    }

    func testTheReadingsOfTheFilesTheCLIsKeepAreStoredWithTheirScope() throws {
        let rig = try rig()
        rig.ingestor.ingest(now: LogDate.parse("2026-10-29T00:00:00.000Z")!)
        rig.ingestor.ingest(now: LogDate.parse("2026-10-29T00:01:00.000Z")!)

        let readings = rig.store.readings(provider: .claude)

        XCTAssertEqual(readings.count, 2, "the weekly window and the limit of one model, once each")
        XCTAssertEqual(Set(readings.map(\.scope)), [nil, "Fable"])
        XCTAssertEqual(readings.first { $0.scope == nil }?.usedPercent, 61)
        XCTAssertEqual(Set(readings.map(\.source)), ["live"])
    }

    func testAHigherPercentageOfTheSameWindowReplacesTheLowerOne() throws {
        let rig = try rig()
        let now = LogDate.parse("2026-10-29T00:00:00.000Z")!
        rig.ingestor.ingest(now: now)
        try #"{"rate_limits":{"seven_day":{"used_percentage":80,"resets_at":1799990000}},"limits":[]}"#
            .write(to: rig.quota, atomically: true, encoding: .utf8)
        rig.ingestor.ingest(now: now)
        try #"{"rate_limits":{"seven_day":{"used_percentage":70,"resets_at":1799990000}},"limits":[]}"#
            .write(to: rig.quota, atomically: true, encoding: .utf8)
        rig.ingestor.ingest(now: now)

        XCTAssertEqual(rig.store.readings(provider: .claude).first { $0.scope == nil }?.usedPercent, 80,
                       "a percentage does not go down inside a window: a lower value is a late or stale reading")
    }

    func testABrokenLineIsSkippedAndTheRestIsKept() throws {
        let rig = try rig()
        try append("not json at all\n" + line("2026-10-28T10:00:00.000Z", id: "m1", output: 10) + "\n{\"type\":\"assistant\",\"usage\":\n",
                   to: rig.logs.appendingPathComponent("a.jsonl"))
        XCTAssertEqual(rig.ingestor.ingest(now: LogDate.parse("2026-10-29T00:00:00.000Z")!).messages, 1)
    }
}
