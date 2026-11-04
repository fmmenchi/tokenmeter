import Foundation

/// Runs a problem's fix through the integration that declared it (ADR 0005).
public enum FixRunner {
    /// The descriptor of the fix a problem offers; nil when it offers none or nobody declared it.
    public static func descriptor(for problem: Problem, providers: [ProviderConfig],
                                  integrations: Integrations) -> FixDescriptor? {
        guard let fix = problem.fix, let integration = integration(for: problem, providers: providers, integrations: integrations)
        else { return nil }
        return integration.fixes.first { $0.id == fix }
    }

    public static func run(_ problem: Problem, providers: [ProviderConfig], integrations: Integrations,
                           context: ProblemContext) -> FixResult {
        guard let fix = problem.fix else { return .failed("This problem has no fix. Nothing was changed.") }
        guard let provider = providers.first(where: { $0.id == problem.topic }),
              let integration = integration(for: problem, providers: providers, integrations: integrations),
              integration.fixes.contains(where: { $0.id == fix }) else {
            return .failed("Nothing in this version can run that fix. Nothing was changed.")
        }
        // The entry the problem is about: the fix runs in its folder (ADR 0014).
        return integration.run(fix: fix, for: provider, in: context)
    }

    private static func integration(for problem: Problem, providers: [ProviderConfig],
                                    integrations: Integrations) -> (any ProviderIntegration)? {
        providers.first { $0.id == problem.topic }?.integration.flatMap { integrations[$0] }
    }
}
