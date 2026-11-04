import SwiftUI
import TokenMeterCore

/// The switch "Set up the Claude quota automatically" and, under it, a line for each Claude account saying what the setup
/// found in its folder, with Restore original beside the one whose status line is wrapped (ADR 0004, 0014).
struct ClaudeSetupGroup: View {
    let meter: Meter

    var body: some View {
        Toggle("Set up the Claude quota automatically", isOn: Binding(
            get: { meter.autoSetUpClaude },
            set: { meter.setAutoSetUpClaude($0) }))
        Text(caption).font(.caption).foregroundStyle(.secondary)
        if meter.autoSetUpClaude {
            ForEach(meter.claudeAccounts) { entry in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("**\(entry.provider.title)** · \(Self.text(for: meter.claudeStatusLines[entry.id]))")
                        .font(.caption).foregroundStyle(.secondary)
                    if meter.claudeStatusLines[entry.id] == .wrapped {
                        Spacer()
                        Button("Restore original") { meter.restoreClaudeStatusLine(for: entry.id) }
                            .controlSize(.small)
                    }
                }
                .padding(.leading, 12)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var caption: String {
        guard meter.autoSetUpClaude else { return "Off: tokenmeter does not touch Claude Code's settings." }
        return meter.claudeAccounts.isEmpty
            ? "Checked at every launch; never replaces a status line you set."
            : "For every Claude account, in its own folder. Never replaces a status line you set."
    }

    /// What the setup found for one account.
    static func text(for outcome: ClaudeStatusLine.Outcome?) -> String {
        switch outcome {
        case .set: "done: its status line now feeds tokenmeter."
        case .alreadySet: "its status line already feeds tokenmeter."
        case .notInstalled: "its folder was not found. Checked again at every launch."
        case .wrapped: "the original status line is wrapped; it still runs."
        case .otherStatusLine: "another status line is in use and was left alone. Wrap it from the panel."
        case .unreadableSettings: "its settings.json could not be read, so it was left alone."
        case nil: "not checked yet."
        }
    }
}
