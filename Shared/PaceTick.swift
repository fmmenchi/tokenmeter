import AppKit
import SwiftUI

/// The pace tick over a bar: 2 points wide, 2 above and 2 below the bar, with an outline of the window's colour. Orange where the
/// quota will not last, solid white in the dark appearance and black in the light one where it does.
///
/// The colour is explicit, not `Color.primary`: over the panel's translucent material that one is composed as vibrancy and came out
/// dark grey on the bright green bar in the dark appearance, where the tick could not be read.
struct PaceTick: View {
    let runsOut: Bool
    let height: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Capsule().fill(runsOut ? Color.orange : (colorScheme == .dark ? .white : .black))
            .frame(width: 2, height: height + 4)
            .background(Capsule().fill(Color(nsColor: .windowBackgroundColor)).padding(-1))
    }
}
