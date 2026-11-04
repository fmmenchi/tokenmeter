import Foundation

/// What the Codex CLI adds beyond its logs (ADR 0014): nothing to set up and nothing to fix, but the integration knows
/// the tool's folders, so an account's folder nobody named can be found and its login read.
public struct CodexIntegration: ProviderIntegration {
    public let id = "codex"
    public let tool: AccountTool? = .codexCLI
    public let kinds: [ProblemKind] = []
    public let fixes: [FixDescriptor] = []

    public init() {}

    public func problems(for provider: ProviderConfig, in context: ProblemContext) -> [Problem] { [] }

    public func run(fix: String, for provider: ProviderConfig, in context: ProblemContext) -> FixResult {
        .failed("The Codex CLI has nothing to fix. Nothing was changed.")
    }
}
