import SwiftUI
import TokenMeterCore

/// A provider drawn as a card: its block on a soft fill with a hairline, so the grouping reads on a light panel and on a
/// dark one. Only system colours and their opacities, so both appearances hold (ADR 0006); a skin gives it its own fill, its own
/// hairline and its own roundness (ADR 0013).
struct ProviderCard: View {
    let snapshot: ProviderSnapshot
    var problemCount = 0
    var showsPace = false
    var showsRunOut = false
    @Environment(\.skinStyle) private var skin

    private var radius: CGFloat { skin.map { CGFloat($0.skin.cardRadius) } ?? 10 }
    private var fill: Color { skin.map { $0.skin.fillsCard ? $0.card : .clear } ?? Color.primary.opacity(0.07) }
    private var hairline: Color { skin.map { $0.border ?? .clear } ?? Color.primary.opacity(0.1) }

    var body: some View {
        ProviderBlock(snapshot: snapshot, problemCount: problemCount, showsPace: showsPace, showsRunOut: showsRunOut)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: radius).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(hairline))
            .easterEggCorner()
    }
}
