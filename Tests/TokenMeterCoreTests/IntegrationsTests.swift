import XCTest
@testable import TokenMeterCore

final class IntegrationsTests: XCTestCase {
    private struct Stub: ProviderIntegration {
        let id: String
        var fixes: [FixDescriptor] { [] }
        func problems(in context: ProblemContext) -> [Problem] { [] }
        func run(fix: String, in context: ProblemContext) -> FixResult { .done }
    }

    func testAnIntegrationIsFoundByItsId() {
        let integrations = Integrations([Stub(id: "a"), Stub(id: "b")])
        XCTAssertEqual(integrations["b"]?.id, "b")
        XCTAssertNil(integrations["c"])
    }

    func testAConfigWithoutTheFieldDecodesWithNoIntegration() throws {
        let file = try ProviderConfigFile.decode(Data(#"{"version":1,"providers":[{"id":"x","title":"X","windows":[60]}]}"#.utf8),
                                                 origin: "test")
        XCTAssertNil(file.providers[0].integration)
    }

    func testTheFieldIsRead() throws {
        let json = #"{"version":1,"providers":[{"id":"x","title":"X","windows":[60],"integration":"x-thing"}]}"#
        XCTAssertEqual(try ProviderConfigFile.decode(Data(json.utf8), origin: "test").providers[0].integration, "x-thing")
    }
}
