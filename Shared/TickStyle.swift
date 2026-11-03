import AppKit
import SwiftUI

/// How the pace tick of a bar is drawn. The panel only ever uses `.plain`; the other two are for comparing looks in a debug build,
/// chosen from the developer menu, and the widget never sets the value.
enum TickStyle: String, CaseIterable {
    /// Solid white in the dark appearance and black in the light one, with an outline of the window's colour.
    case plain
    /// The plain tick with a small head above the bar, so its position reads even where it meets the edge of the fill.
    case pin
    /// The opposite colours: a black tick with a white outline in the dark appearance, white with a black outline in the light one.
    case inverted
}

private struct TickStyleKey: EnvironmentKey {
    static let defaultValue = TickStyle.plain
}

extension EnvironmentValues {
    var tickStyle: TickStyle {
        get { self[TickStyleKey.self] }
        set { self[TickStyleKey.self] = newValue }
    }
}

/// The pace tick over a bar: 2 points wide, 2 above and 2 below the bar. Orange where the quota will not last.
///
/// The colour is explicit, not `Color.primary`: over the panel's translucent material that one is composed as vibrancy and came out
/// dark grey on the bright green bar in the dark appearance, where the tick could not be read.
struct PaceTick: View {
    let runsOut: Bool
    let height: CGFloat
    @Environment(\.tickStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        let inverted = style == .inverted
        let core: Color = runsOut ? .orange : (dark != inverted ? .white : .black)
        let outline: Color = inverted ? (dark ? .white : .black) : Color(nsColor: .windowBackgroundColor)
        Capsule().fill(core)
            .frame(width: 2, height: height + 4)
            .background(Capsule().fill(outline).padding(inverted ? -1.5 : -1))
            .overlay(alignment: .top) {
                if style == .pin {
                    PinHead().fill(core).frame(width: 8, height: 5).offset(y: -5)
                }
            }
    }
}

private struct PinHead: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
