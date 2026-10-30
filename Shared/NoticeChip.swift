import SwiftUI

/// A small count of problems, next to a provider's name in the widget and the panel (ADR 0030).
struct NoticeChip: View {
    let count: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 8)).foregroundStyle(.orange)
            Text("\(count)").font(.system(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 6)
        .frame(height: 14)
        .background(Capsule().fill(Color.orange.opacity(0.15)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(count == 1 ? "1 problem" : "\(count) problems")
    }
}
