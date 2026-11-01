import SwiftUI

/// The `i` beside a provider's name: a click opens a popover that explains the mark on the bars (ADR 0039). It closes with
/// its `x`, with a second click on the `i`, or with a click outside it.
struct PaceInfo: View {
    @State private var shown = false
    @Environment(\.openURL) private var openURL

    /// The section of the Bars page of the docs that explains the mark; the same site the problems' Learn more links to.
    private static let guide = URL(string: "https://fmmenchi.github.io/tokenmeter/use/bars#reading-the-mark")!

    var body: some View {
        Button { shown.toggle() } label: {
            Image(systemName: "info.circle").font(.system(size: 11))
                .foregroundStyle(shown ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("What the mark on the bar means")
        .popover(isPresented: $shown) { explanation }
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("The mark is how much you'd have left if you used it steadily until the reset. "
                 + "A bar shorter than the mark means you are going too fast. Hover the bar to see when.")
                .font(.caption).fixedSize(horizontal: false, vertical: true)
            Button("Learn more") { openURL(Self.guide) }.buttonStyle(.plain).font(.caption).foregroundStyle(.tint)
        }
        .frame(width: 220, alignment: .leading)
        .padding(.vertical, 8).padding(.leading, 10).padding(.trailing, 24)
        .overlay(alignment: .topTrailing) {
            Button { shown = false } label: { Image(systemName: "xmark").font(.system(size: 8, weight: .semibold)) }
                .buttonStyle(.plain).foregroundStyle(.secondary).padding(8).accessibilityLabel("Close")
        }
    }
}
