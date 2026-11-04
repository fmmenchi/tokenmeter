import Foundation

/// Puts the problems of every source in one list (ADR 0005). It reads nothing itself: each source hands over what it found.
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
    /// nothing the app knows is itself a `general` problem, not a crash (ADR 0005). `folders` are the folders of a tool the
    /// caller found at the top of the home (`AccountFolders.scan`): one that no entry names is a `general` problem (ADR 0014).
    public static func detect(general: [Problem], providers: [ProviderConfig], integrations: Integrations,
                              context: ProblemContext, folders: [AccountFolders.Found] = []) -> [Problem] {
        var unknown = unnamed(folders, providers: providers, integrations: integrations, context: context)
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
            // Each entry is checked in its own folder, and its problems name it (ADR 0014).
            found.append(integration.problems(for: provider, in: context))
        }
        return merge(general: general + unknown, providers: found)
    }

    /// The folders no entry's home names. An entry names the folder its integration's tool reads for it, the default
    /// folder when it has no `home`; an entry whose integration the app does not know names nothing.
    static func unnamed(_ folders: [AccountFolders.Found], providers: [ProviderConfig], integrations: Integrations,
                        context: ProblemContext) -> [Problem] {
        let named = Set(providers.compactMap { provider -> String? in
            guard let name = provider.integration, let tool = integrations[name]?.tool else { return nil }
            return AccountFolders.folder(of: provider.home, tool: tool, userHome: context.home).standardizedFileURL.path
        })
        return folders.filter { !named.contains($0.folder.standardizedFileURL.path) }
            .map { AppProblems.folderNotNamed($0, userHome: context.home) }
    }
}
