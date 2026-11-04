import SwiftUI
import TokenMeterCore

/// The Accounts tab of Settings (ADR 0014): one row per entry of providers.json, with its title, the email its folder is
/// signed in with, the tool, and Edit… and Remove…; under the list, Add an account…. The order and the visibility of the
/// cards are not here: they are set on the panel, behind its lock.
struct AccountsTab: View {
    let meter: Meter
    /// The sheet that is open: Edit… on a row, or Add an account….
    @State private var editing: AccountSheet.Target?
    /// The entry Remove… asks about.
    @State private var removing: AccountSummary?

    var body: some View {
        Section("Accounts") {
            Text("An account is a folder Claude Code or the Codex CLI reads, with its own login. Each one here is an entry of providers.json: the title is yours, the email is who is signed in there, the folder shows on hover. Edit renames it or points it at another folder; Remove takes the entry out, its card with it, and is disabled on the last account. The order of the cards, and which are shown, is set on the panel, with the lock.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(meter.accounts) { account in
                AccountRow(account: account, canRemove: meter.accounts.count > 1,
                           onEdit: { editing = .existing(account) }, onRemove: { removing = account })
            }
            Button("Add an account…") { editing = .new }
        }
        .sheet(item: $editing) { target in AccountSheet(meter: meter, target: target) }
        .sheet(item: $removing) { account in RemoveAccountSheet(meter: meter, account: account) }
    }
}

/// One entry: the title over the email, the tool as a chip, the folder as the tooltip, and the two actions.
private struct AccountRow: View {
    let account: AccountSummary
    let canRemove: Bool
    let onEdit: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(account.title).lineLimit(1)
                Text(account.email ?? account.home).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .layoutPriority(1)
            if let tool = account.tool {
                Text(tool.name).font(.caption.weight(.medium))
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Capsule().fill(Color.primary.opacity(0.12)))
            }
            Spacer()
            Button("Edit…", action: onEdit).controlSize(.small)
            Button("Remove…", action: onRemove).controlSize(.small).disabled(!canRemove)
                .help(canRemove ? "" : "The last account stays")
        }
        .help(account.home)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(account.title), \(account.email ?? account.home)")
    }
}
