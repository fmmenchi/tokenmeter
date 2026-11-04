import Foundation
import TokenMeterCore

/// The Claude entries of the file as the status line and `/usage` see them: one account per entry, in its own folder
/// (ADR 0014). Read from the entries the app has; nothing here touches the disk.
enum ClaudeAccounts {
    struct Entry: Identifiable {
        let provider: ProviderConfig
        let account: ClaudeStatusLine.Account
        var id: String { provider.id }
    }

    /// The entries whose integration is Claude's, each with the folder Claude Code reads for it.
    static func entries(in providers: [ProviderConfig], integrations: Integrations,
                        home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [Entry] {
        providers.compactMap { provider in
            guard let name = provider.integration, integrations[name]?.tool == .claudeCode else { return nil }
            return Entry(provider: provider, account: ClaudeStatusLine.Account(
                id: provider.id, configDir: AccountFolders.folder(of: provider.home, tool: .claudeCode, userHome: home)))
        }
    }
}
