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
