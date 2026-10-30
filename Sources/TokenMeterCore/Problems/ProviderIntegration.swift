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

/// What one provider adds beyond reading its quota: its own problems and the fixes for them (ADR 0031).
/// One implementation per provider that needs one; nothing outside it names the provider.
public protocol ProviderIntegration: Sendable {
    var id: String { get }
    var fixes: [FixDescriptor] { get }
    func problems(in context: ProblemContext) -> [Problem]
    func run(fix: String, in context: ProblemContext) -> FixResult
}
