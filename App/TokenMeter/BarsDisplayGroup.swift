import SwiftUI
import TokenMeterCore

/// The first group of General (ADR 0006): how the bars read, as a segmented control. It changes the figure, the fill of the bar and the
/// mark on the panel and the widget; what stays on what is left is said under it. Settings itself has no bars.
struct BarsDisplayGroup: View {
    let meter: Meter

    var body: some View {
        Section {
            Picker("Show on the bars", selection: Binding(get: { meter.barsDisplay }, set: { meter.barsDisplay = $0 })) {
                Text("Left").tag(BarsDisplay.left)
                Text("Used").tag(BarsDisplay.used)
            }
            .pickerStyle(.segmented)
            Text("The figure and the length of the bar: 25% left, or 75% used. The colour and the notices always follow what is left.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
