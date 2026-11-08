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
    /// Only the host app offers this action; the widget has no way to open Terminal.
    var modelUsageAction: (label: String, run: () -> Void)?

    private var modelSeenAt: Date? {
        snapshot.windows.filter { $0.window.scope != nil }.compactMap(\.observedAt).max()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProviderBlock(snapshot: snapshot, problemCount: problemCount, showsPace: showsPace, showsRunOut: showsRunOut)
            if let modelUsageAction {
                HStack(spacing: 6) {
                    if let modelSeenAt {
                        Text("Model limits seen \(modelSeenAt, style: .relative)").captionColour()
                    } else {
                        Text("Model limits not read yet").captionColour()
                    }
                    Spacer(minLength: 0)
                    Button(modelUsageAction.label, action: modelUsageAction.run)
                        .buttonStyle(.plain).foregroundStyle(.tint)
                }
                .font(.caption2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardChrome()
        .easterEggCorner()
    }
}
