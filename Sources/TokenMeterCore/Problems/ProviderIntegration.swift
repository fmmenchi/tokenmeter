import Foundation

/// What an integration may look at while it checks or fixes something.
public struct ProblemContext: Sendable {
    public let home: URL
    public let now: Date

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser, now: Date = Date()) {
        self.home = home
        self.now = now
    }
}

public enum FixResult: Equatable, Sendable {
    case done
    /// Nothing was changed; the reason is shown in place of the detail.
    case failed(String)
}

/// What one provider adds beyond reading its quota: its own problems and the fixes for them (ADR 0005).
/// One implementation per tool; it is asked about one entry at a time, with the entry's id and folder (ADR 0014), so
/// nothing outside it names the provider.
public protocol ProviderIntegration: Sendable {
    var id: String { get }
    /// The tool whose folders this integration knows (ADR 0014); nil for an integration of none.
    var tool: AccountTool? { get }
    /// Every kind of problem this integration can report: its part of the census.
    var kinds: [ProblemKind] { get }
    var fixes: [FixDescriptor] { get }
    /// The problems of `provider`, an entry that names this integration; their topic is the entry's id.
    func problems(for provider: ProviderConfig, in context: ProblemContext) -> [Problem]
    func run(fix: String, for provider: ProviderConfig, in context: ProblemContext) -> FixResult
}

public extension ProviderIntegration {
    var tool: AccountTool? { nil }
}
