import SwiftUI

/// Remove… asks first (ADR 0014), and says what goes and what stays: the card and the entry go, the history, the
/// folder and its login stay; the file keeps a copy as providers.json.tokenmeter.bak.
struct RemoveAccountSheet: View {
    let meter: Meter
    let account: AccountSummary
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?
    @State private var removing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remove \(account.title)?").font(.headline)
            Text("Its card leaves the panel and the widget, and its entry leaves providers.json (a copy is kept as providers.json.tokenmeter.bak). Its history stays in the stats. The folder \(account.home) and its login are not touched.")
                .font(.callout).foregroundStyle(.secondary)
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Remove", role: .destructive, action: remove).keyboardShortcut(.defaultAction).disabled(removing)
            }
        }
        .padding(20)
        .frame(width: 500)
    }

    private func remove() {
        removing = true
        error = nil
        Task {
            let failure = await meter.removeAccount(account.id)
            removing = false
            if let failure { error = failure } else { dismiss() }
        }
    }
}
