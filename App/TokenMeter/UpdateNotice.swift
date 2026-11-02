import SwiftUI

/// The notice at the top of the panel when an update was found and not yet installed (ADR 0011). It is for whoever missed Sparkle's
/// window; "Install" opens that window, "What's new" opens the changelog page of the version. It has the look of a problem's banner.
struct UpdateNotice: View {
    let version: String
    let notes: URL?
    let onInstall: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.circle").font(.system(size: 14)).foregroundStyle(.tint)
            Text("Version \(version) is available").font(.caption)
            Spacer(minLength: 6)
            if let notes {
                Button("What's new") { openURL(notes) }.buttonStyle(.plain).font(.caption.weight(.semibold)).foregroundStyle(.tint)
            }
            Button("Install", action: onInstall).buttonStyle(.plain).font(.caption.weight(.semibold)).foregroundStyle(.tint)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.15)))
        .accessibilityElement(children: .contain)
    }
}
