import SwiftUI
import TokenMeterCore

/// The menu-bar item's label (docs/features/2026-11-17-menu-bar-quota): the gauge, and, when chosen in Settings, one figure for each
/// card in the panel's order. The tooltip and VoiceOver name every figure. It is drawn again with every new snapshot; a
/// `TimelineView` here left the menu-bar item empty.
struct MenuBarLabel: View {
    let meter: Meter

    var body: some View {
        let figures = meter.showsMenuBarFigures
            ? meter.snapshot.map { MenuBarFigures.figures(of: $0, display: meter.barsDisplay, at: Date()) } ?? []
            : []
        let attention = meter.needsAttention
        HStack(spacing: 4) {
            Image(nsImage: attention ? MenuBarIcon.withDot : MenuBarIcon.image)
            if !figures.isEmpty {
                Text(MenuBarFigures.shown(figures).map(\.text).joined(separator: "  "))
                    .monospacedDigit()
            }
        }
        .help(MenuBarFigures.tooltip(figures, needsAttention: attention))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(MenuBarFigures.accessibilityLabel(figures, needsAttention: attention))
    }
}
