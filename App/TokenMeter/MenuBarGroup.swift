import SwiftUI

/// A group of General (docs/features/2026-11-17-menu-bar-quota): whether the menu bar writes the quota beside the gauge. Off at
/// first; what it shows is said under it.
struct MenuBarGroup: View {
    let meter: Meter

    var body: some View {
        Section {
            Toggle("Show the quota in the menu bar", isOn: Binding(
                get: { meter.showsMenuBarFigures },
                set: { meter.showsMenuBarFigures = $0 }))
            Text("A figure for each card, in the order of the panel: the window with the least left. The panel shows the cards in the same order.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
