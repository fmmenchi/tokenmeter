import XCTest
@testable import TokenMeterCore

final class ModelLimitSourceTests: XCTestCase {
    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func source(file: URL) throws -> ConfiguredSource {
        let json = """
        {"id":"p","title":"P","windows":[300,10080],
         "quota":{"windows":[
           {"file":"\(file.path)","each":"usage.limits","where":{"kind":"weekly_scoped"},"scope":"scope.model.display_name",
            "minutes":10080,"usedPercent":"percent","resetsAt":"resets_at","resetsAtFormat":"iso8601",
            "observedAt":"usage.fetchedAtMs","observedAtFormat":"epochMilliseconds"}]}}
        """
        return ConfiguredSource(try JSONDecoder().decode(ProviderConfig.self, from: Data(json.utf8)))
    }

    private let limits = """
    {"usage":{"fetchedAtMs":1792097167273,"limits":[
      {"kind":"session","percent":9,"resets_at":"2026-10-15T22:00:00.371110+00:00","scope":null},
      {"kind":"weekly_all","percent":26,"resets_at":"2026-10-20T10:00:00.371127+00:00","scope":null},
      {"kind":"weekly_scoped","percent":13,"resets_at":"2026-11-03T10:00:00.371262+00:00",
       "scope":{"model":{"id":null,"display_name":"Fable"}}},
      {"kind":"weekly_scoped","percent":40,"resets_at":"2026-11-03T10:00:00.371262+00:00",
       "scope":{"model":{"display_name":"Other"}}}]}}
    """

    func testALimitForEachModelInAListIsReadWithItsScope() throws {
        let file = try tempDir().appendingPathComponent("usage.json")
        try Data(limits.utf8).write(to: file)

        let quotas = try source(file: file).read(since: Date(timeIntervalSince1970: 0)).quotas
        XCTAssertEqual(quotas.map(\.scope), ["Fable", "Other"], "only the entries that match, and no model is named in the code")
        XCTAssertEqual(quotas[0].usedPercent, 13)
        XCTAssertEqual(quotas[0].windowMinutes, 10080)
        XCTAssertNotNil(quotas[0].resetsAt)
        XCTAssertEqual(quotas[0].observedAt, Date(timeIntervalSince1970: 1_792_097_167.273))
    }

    func testAMissingFileOrAListThatIsNotThereGivesNoLimits() throws {
        let dir = try tempDir()
        XCTAssertEqual(try source(file: dir.appendingPathComponent("none.json")).read(since: Date(timeIntervalSince1970: 0)).quotas.count, 0)
        let file = dir.appendingPathComponent("usage.json")
        try Data(#"{"usage":{}}"#.utf8).write(to: file)
        XCTAssertEqual(try source(file: file).read(since: Date(timeIntervalSince1970: 0)).quotas.count, 0)
    }

    func testAPlanWithoutAModelLimitHasNoEntryForIt() throws {
        let file = try tempDir().appendingPathComponent("usage.json")
        try Data(#"{"usage":{"fetchedAtMs":1,"limits":[{"kind":"session","percent":9}]}}"#.utf8).write(to: file)
        XCTAssertEqual(try source(file: file).read(since: Date(timeIntervalSince1970: 0)).quotas.count, 0)
    }
}

final class WindowsByPlanTests: XCTestCase {
    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func source(file: URL, maxAge: String = "") throws -> ConfiguredSource {
        let json = """
        {"id":"p","title":"P","windows":[300,10080],
         "quota":{"windows":[
           {"file":"\(file.path)","minutes":300,"usedPercent":"p","existsIf":{"file":"\(file.path)","each":"usage.limits",
            "where":{"kind":"session"},"observedAt":"usage.fetchedAtMs","observedAtFormat":"epochMilliseconds"\(maxAge)}}]}}
        """
        return ConfiguredSource(try JSONDecoder().decode(ProviderConfig.self, from: Data(json.utf8)))
    }

    private func write(_ limits: String, fetched: Date, to file: URL) throws {
        let ms = Int(fetched.timeIntervalSince1970 * 1000)
        try Data(#"{"usage":{"fetchedAtMs":\#(ms),"limits":\#(limits)}}"#.utf8).write(to: file)
    }

    private let epoch = Date(timeIntervalSince1970: 0)

    func testAWindowThatAFreshListDoesNotNameIsAbsent() throws {
        let file = try tempDir().appendingPathComponent("u.json")
        try write(#"[{"kind":"weekly_all","percent":51}]"#, fetched: Date(), to: file)
        XCTAssertEqual(try source(file: file).read(since: epoch).absent, [300])
    }

    func testAWindowThatTheListNamesIsThere() throws {
        let file = try tempDir().appendingPathComponent("u.json")
        try write(#"[{"kind":"session","percent":9},{"kind":"weekly_all","percent":51}]"#, fetched: Date(), to: file)
        XCTAssertEqual(try source(file: file).read(since: epoch).absent, [])
    }

    func testUnknownIsNotAbsent() throws {
        let dir = try tempDir()
        XCTAssertEqual(try source(file: dir.appendingPathComponent("none.json")).read(since: epoch).absent, [], "no file")
        let file = dir.appendingPathComponent("u.json")
        try write("[]", fetched: Date(), to: file)
        XCTAssertEqual(try source(file: file).read(since: epoch).absent, [], "an empty list says nothing")
        try write(#"[{"kind":"weekly_all"}]"#, fetched: Date().addingTimeInterval(-7 * 3600), to: file)
        XCTAssertEqual(try source(file: file).read(since: epoch).absent, [], "a list older than six hours says nothing")
        XCTAssertEqual(try source(file: file, maxAge: #","maxAgeHours":24"#).read(since: epoch).absent, [300], "unless the rule allows it")
    }

    func testTheBuilderLeavesAnAbsentWindowOut() {
        let result = SnapshotBuilder.providerSnapshot(provider: .claude, events: [], windows: [.session, .week], absent: [300])
        XCTAssertEqual(result.windows.map(\.window.id), ["7d"])
    }

    func testAModelOfAnAbsentWindowGoesWithIt() {
        let model = ReportedQuota(usedPercent: 10, windowMinutes: 300, resetsAt: nil, scope: "Fable")
        let result = SnapshotBuilder.providerSnapshot(provider: .claude, events: [], windows: [.session, .week],
                                                      reported: [model], absent: [300])
        XCTAssertEqual(result.windows.map(\.window.id), ["7d"])
    }
}
