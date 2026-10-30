import SwiftUI
import TokenMeterCore

/// A provider drawn as a card: its block on a soft fill. Only system colours, so the light and the dark appearance both
/// hold (ADR 0035).
struct ProviderCard: View {
    let snapshot: ProviderSnapshot
    var problemCount = 0

    var body: some View {
        ProviderBlock(snapshot: snapshot, problemCount: problemCount)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
    }
}
