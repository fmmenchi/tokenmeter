import SwiftUI

/// The eye that hides or shows a provider's card: an open eye when it is shown, a crossed one when it is hidden. A
/// tinted area like the drag handle, in system colours only (ADR 0036).
struct VisibilityButton: View {
    let provider: String
    let isShown: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isShown ? "eye" : "eye.slash")
                .foregroundStyle(isShown ? .primary : .secondary)
                .frame(width: 28, height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.07)))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(isShown ? "Hide" : "Show")
        .accessibilityLabel(isShown ? "Hide \(provider)" : "Show \(provider)")
    }
}
