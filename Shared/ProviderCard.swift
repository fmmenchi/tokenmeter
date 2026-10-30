import SwiftUI
import TokenMeterCore

/// A provider drawn as a card: its block on a soft fill with a hairline, so the grouping reads on a light panel and on a
/// dark one. Only system colours and their opacities, so both appearances hold (ADR 0035).
struct ProviderCard: View {
    let snapshot: ProviderSnapshot
    var problemCount = 0

    var body: some View {
        ProviderBlock(snapshot: snapshot, problemCount: problemCount)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.1)))
    }
}
