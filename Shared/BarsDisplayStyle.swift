import SwiftUI
import TokenMeterCore

private struct BarsDisplayKey: EnvironmentKey {
    static let defaultValue = BarsDisplay.left
}

extension EnvironmentValues {
    /// How the bars read, set once at the root of the panel and of the widget (ADR 0006). A view that does not find one draws what is left.
    var barsDisplay: BarsDisplay {
        get { self[BarsDisplayKey.self] }
        set { self[BarsDisplayKey.self] = newValue }
    }
}
