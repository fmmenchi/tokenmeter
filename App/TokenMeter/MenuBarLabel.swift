import SwiftUI
import TokenMeterCore

/// The menu-bar item's label (docs/features/2026-11-17-menu-bar-quota): the gauge, and, when chosen in Settings, one figure for each
/// card in the panel's order. The tooltip and VoiceOver name every figure. It is read again every minute, so a reading that turns
/// old gets its "~" without waiting for the next refresh.
struct MenuBarLabel: View {
    let meter: Meter

    var body: some View {
        TimelineView(.everyMinute) { context in
            let figures = meter.showsMenuBarFigures
                ? meter.snapshot.map { MenuBarFigures.figures(of: $0, display: meter.barsDisplay, at: context.date) } ?? []
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
}
