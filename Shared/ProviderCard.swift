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

    var body: some View {
        ProviderBlock(snapshot: snapshot, problemCount: problemCount, showsPace: showsPace, showsRunOut: showsRunOut)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardChrome()
            .easterEggCorner()
    }
}
