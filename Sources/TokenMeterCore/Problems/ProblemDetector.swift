import Foundation

/// Puts the problems of every source in one list (ADR 0031). It reads nothing itself: each source hands over what it found.
public enum ProblemDetector {
    /// `general` problems first, then each provider's in the order given (the order of `providers.json`).
    /// A repeated `id` keeps its first occurrence.
    public static func merge(general: [Problem], providers: [[Problem]]) -> [Problem] {
        var seen = Set<String>()
        return (general + providers.flatMap { $0 }).filter { seen.insert($0.id).inserted }
    }
}

extension ProblemDetector {
    /// The problems of the app and of each configured provider's integration. A provider whose `integration` names
    /// nothing the app knows is itself a `general` problem, not a crash (ADR 0031).
    public static func detect(general: [Problem], providers: [ProviderConfig], integrations: Integrations,
                              context: ProblemContext) -> [Problem] {
        var unknown: [Problem] = []
        var found: [[Problem]] = []
        for provider in providers {
            guard let name = provider.integration else { continue }
            guard let integration = integrations[name] else {
                unknown.append(AppProblems.integrationNotFound.problem(
                    message: "Integration not found for \(provider.title)",
                    detail: "providers.json asks for \"\(name)\", which this version does not have.",
                    detailID: provider.id))
                continue
            }
            found.append(integration.problems(in: context))
        }
        return merge(general: general + unknown, providers: found)
    }
}
