import SwiftUI

/// The bubble that says when a quota runs out (ADR 0039), drawn by the app above what the pointer is on. It is not `.help`: the
/// app has no Dock icon and its panel opens without making the app active, and a system tooltip did not show in it.
private struct PaceBubble: ViewModifier {
    let text: String?
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            // The target is 3 points taller than a thin bar, above and below, without moving anything.
            .padding(.vertical, 3).contentShape(Rectangle())
            .onHover { hovering = text != nil && $0 }
            .padding(.vertical, -3)
            .overlay(alignment: .top) {
                if hovering, let text {
                    Text(text)
                        .font(.caption2).foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 220, alignment: .leading)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .windowBackgroundColor)))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.15)))
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 1)
                        .alignmentGuide(.top) { $0[.bottom] + 4 }
                        .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    /// A bubble above this view while the pointer is on it; nothing when there is no text.
    func paceBubble(_ text: String?) -> some View { modifier(PaceBubble(text: text)) }
}
