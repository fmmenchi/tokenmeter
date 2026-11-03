import SwiftUI
import TokenMeterCore

/// A small panel in the look of a skin, for the choice in Settings: three bars on the skin's panel colour, drawn with the same
/// views as the real ones, so what the choice shows is what the panel will be.
struct SkinPreview: View {
    let skin: Skin
    /// The width of the small panel, 132 points unless the place is narrower.
    var width: CGFloat = 132
    @Environment(\.colorScheme) private var colorScheme

    private func tint(_ share: Double, _ style: SkinStyle?) -> Color {
        style?.tint(for: share) ?? (share < 0.15 ? .red : share < 0.4 ? .orange : .green)
    }

    var body: some View {
        let style = SkinStyle(skin: skin, appearance: colorScheme == .dark ? .dark : .light)
        VStack(spacing: 5) {
            ForEach([0.7, 0.3, 0.1], id: \.self) { share in
                QuotaBar(fraction: share, tint: tint(share, style))
            }
        }
        .padding(7)
        .frame(width: width)
        .background(RoundedRectangle(cornerRadius: min(CGFloat(skin.cardRadius), 12)).fill(style?.panel ?? Color.primary.opacity(0.07)))
        .environment(\.skinStyle, style)
        .accessibilityHidden(true)
    }
}
