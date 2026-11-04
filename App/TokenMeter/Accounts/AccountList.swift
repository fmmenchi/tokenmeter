import Foundation
import TokenMeterCore

/// An entry of the file as the Accounts tab shows it: the title, the tool, the folder and who is signed in there
/// (ADR 0014). Built off the main actor, because the email is read from the folder.
struct AccountSummary: Identifiable, Equatable {
    let id: String
    let title: String
    /// Nil for an entry whose integration is not a tool's: it is shown, but has no folder to speak of.
    let tool: AccountTool?
    /// The folder as the file names it, `~/.claude` for an entry without a home.
    let home: String
    let email: String?

    /// The entries in the file's order, each with the email its folder is signed in with when it has one.
    static func list(_ providers: [ProviderConfig], integrations: Integrations,
                     userHome: URL = FileManager.default.homeDirectoryForCurrentUser) -> [AccountSummary] {
        providers.map { provider in
            let tool = provider.integration.flatMap { integrations[$0]?.tool }
            let email = tool.map { AccountFolders.email(in: AccountFolders.folder(of: provider.home, tool: $0, userHome: userHome), tool: $0) }
            return AccountSummary(
                id: provider.id, title: provider.title, tool: tool,
                home: provider.home ?? tool?.defaultHome ?? "", email: email ?? nil)
        }
    }
}
