import XCTest
@testable import TokenMeterCore

final class FixRunnerTests: XCTestCase {
    private struct Stub: ProviderIntegration {
        let id = "stub"
        let result: FixResult
        var kinds: [ProblemKind] { [] }
        var fixes: [FixDescriptor] { [FixDescriptor(id: "go", label: "Go", runningLabel: "Going…", explanation: "e")] }
        func problems(in context: ProblemContext) -> [Problem] { [] }
        func run(fix: String, in context: ProblemContext) -> FixResult { result }
    }

    private func providers(integration: String? = "stub") throws -> [ProviderConfig] {
        let field = integration.map { #","integration":"\#($0)""# } ?? ""
        let json = #"{"version":1,"providers":[{"id":"p","title":"P","windows":[60]\#(field)}]}"#
        return try ProviderConfigFile.decode(Data(json.utf8), origin: "test").providers
    }

    private let problem = Problem(id: "p.x", topic: "p", message: "m", fix: "go")

    func testItRunsTheFixOfTheIntegrationOfTheTopic() throws {
        let integrations = Integrations([Stub(result: .done)])
        XCTAssertEqual(FixRunner.run(problem, providers: try providers(), integrations: integrations, context: ProblemContext()), .done)
        XCTAssertEqual(FixRunner.descriptor(for: problem, providers: try providers(), integrations: integrations)?.label, "Go")
    }

    func testAFailureCarriesItsReason() throws {
        let integrations = Integrations([Stub(result: .failed("no"))])
        XCTAssertEqual(FixRunner.run(problem, providers: try providers(), integrations: integrations, context: ProblemContext()),
                       .failed("no"))
    }

    func testAProblemWithoutAFixFails() throws {
        let bare = Problem(id: "p.y", topic: "p", message: "m")
        guard case .failed = FixRunner.run(bare, providers: try providers(), integrations: Integrations([Stub(result: .done)]),
                                           context: ProblemContext()) else { return XCTFail("expected a failure") }
    }

    func testAFixNobodyDeclaredFailsWithoutRunning() throws {
        let undeclared = Problem(id: "p.z", topic: "p", message: "m", fix: "other")
        guard case .failed = FixRunner.run(undeclared, providers: try providers(), integrations: Integrations([Stub(result: .done)]),
                                           context: ProblemContext()) else { return XCTFail("expected a failure") }
        XCTAssertNil(FixRunner.descriptor(for: undeclared, providers: try providers(), integrations: Integrations([Stub(result: .done)])))
    }

    func testATopicWithoutAnIntegrationFails() throws {
        guard case .failed = FixRunner.run(problem, providers: try providers(integration: nil),
                                           integrations: Integrations([Stub(result: .done)]),
                                           context: ProblemContext()) else { return XCTFail("expected a failure") }
    }
}
