import AppKit
import SwiftUI

/// The pace tick over a bar: 2 points wide, `reach` above and below the bar, with an outline of what the bar is drawn over. In the
/// middle colour of the skin, orange without one, where the quota will not last; solid white in the dark appearance and black in the
/// light one where it does, or the skin's own tick colour.
///
/// The colour is explicit, not `Color.primary`: over the panel's translucent material that one is composed as vibrancy and came out
/// dark grey on the bright green bar in the dark appearance, where the tick could not be read.
struct PaceTick: View {
    let runsOut: Bool
    let height: CGFloat
    /// How far the tick sticks out of the bar, above and below together.
    var reach: CGFloat = 4
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.skinStyle) private var skin

    private var core: Color {
        if runsOut { return skin?.middle ?? .orange }
        return skin?.tick ?? (colorScheme == .dark ? .white : .black)
    }

    var body: some View {
        Capsule().fill(core)
            .frame(width: 2, height: height + reach)
            .background(Capsule().fill(skin?.surface ?? Color(nsColor: .windowBackgroundColor)).padding(-1))
    }
}
