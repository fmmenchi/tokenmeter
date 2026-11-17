import AppKit
import SwiftUI

/// The row of Settings › General that says where the `tokenmeter` command is and copies the line that puts it on the PATH (ADR 0017).
/// The app runs nothing itself: writing to /usr/local/bin is the person's step, in their own terminal.
struct CommandLineGroup: View {
    @State private var copied = false

    private var path: String { Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/tokenmeter").path }
    private var installLine: String { "sudo mkdir -p /usr/local/bin && sudo ln -sf '\(path)' /usr/local/bin/tokenmeter" }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Command line")
                Spacer()
                Button(copied ? "Copied" : "Copy install command") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(installLine, forType: .string)
                    copied = true
                }
            }
            Text("Paste it in Terminal to use `tokenmeter` and `tokenmeter --json`. It reads what this app last saw; it moves with the app when it updates.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .help(path)
    }
}
