import SwiftUI
import TokenMeterCore

/// The track and the fill of a bar, in the shape a skin gives it (feature "skins"). It draws only these two; the tick and the icon
/// of an event are laid over it by `QuotaBar`, which knows the pace.
struct SkinBarBody: View {
    let fraction: Double?
    let tint: Color
    let shape: BarShape
    let track: Color

    /// The blocks of a bar of blocks, and the air between two of them.
    private static let blocks = 20
    private static let gap: CGFloat = 2

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let share = min(max(fraction ?? 0, 0), 1)
            switch shape {
            case .blocks:
                // A share that is not nothing fills at least one block, so a bar that is almost out is not drawn empty.
                let filled = fraction == nil || share == 0 ? 0 : max(1, Int((share * Double(Self.blocks)).rounded()))
                HStack(spacing: Self.gap) {
                    ForEach(0..<Self.blocks, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1).fill(index < filled ? tint : track)
                    }
                }
            case .line:
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1).fill(track)
                    if fraction != nil { RoundedRectangle(cornerRadius: 1).fill(tint).frame(width: width * share) }
                }
            case .outline:
                ZStack(alignment: .leading) {
                    Capsule().strokeBorder(track, lineWidth: 1)
                    if fraction != nil {
                        Capsule().fill(LinearGradient(colors: [tint, tint.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(height - 4, (width - 4) * share), height: height - 4)
                            .padding(2)
                    }
                }
            case .pill, .thick:
                ZStack(alignment: .leading) {
                    Capsule().fill(track)
                    if fraction != nil { Capsule().fill(tint).frame(width: max(height, width * share)) }
                }
            }
        }
    }
}
