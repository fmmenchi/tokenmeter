import SwiftUI
import TokenMeterCore

/// A skin in one appearance, as the views use it (feature "skins", ADR 0013). The panel, the widget and Settings' previews put one
/// in the environment with `skinned(_:)`; a view that finds none draws as it always did, which is the System skin.
struct SkinStyle: Equatable {
    let skin: Skin
    let palette: SkinPalette

    init?(skin: Skin, appearance: SkinAppearance) {
        guard let palette = skin.palette(for: appearance) else { return nil }
        self.skin = skin
        self.palette = palette
    }

    var panel: Color { Color(argb: palette.panel) }
    var card: Color { Color(argb: palette.card) }
    var track: Color { Color(argb: palette.track) }
    var text: Color { Color(argb: palette.text) }
    var secondaryText: Color { Color(argb: palette.secondaryText) }
    var accent: Color { Color(argb: palette.accent) }
    var plenty: Color { Color(argb: palette.plenty) }
    var middle: Color { Color(argb: palette.middle) }
    var low: Color { Color(argb: palette.low) }
    var tick: Color { Color(argb: palette.tick) }
    var border: Color? { palette.border.map { Color(argb: $0) } }

    /// What the bars are drawn over: the card, or the panel where the card is only an outline. It is the colour round a tick.
    var surface: Color { skin.fillsCard ? card : panel }

    /// The colour of a bar with this share left, by the thresholds of ADR 0002: under 15% low, under 40% middle.
    func tint(for fraction: Double?) -> Color {
        guard let fraction else { return .gray }
        return fraction < 0.15 ? low : fraction < 0.4 ? middle : plenty
    }
}

extension Color {
    init(argb: UInt32) {
        self.init(.sRGB, red: Double((argb >> 16) & 0xFF) / 255, green: Double((argb >> 8) & 0xFF) / 255,
                  blue: Double(argb & 0xFF) / 255, opacity: Double((argb >> 24) & 0xFF) / 255)
    }
}

private struct SkinStyleKey: EnvironmentKey {
    static let defaultValue: SkinStyle? = nil
}

extension EnvironmentValues {
    /// The look the panel or the widget is drawn with, nil for System.
    var skinStyle: SkinStyle? {
        get { self[SkinStyleKey.self] }
        set { self[SkinStyleKey.self] = newValue }
    }
}

private struct SkinnedModifier: ViewModifier {
    let skin: Skin
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let style = SkinStyle(skin: skin, appearance: colorScheme == .dark ? .dark : .light)
        if let style {
            content
                .environment(\.skinStyle, style)
                .fontDesign(skin.typeface == .monospaced ? .monospaced : nil)
                .foregroundStyle(style.text)
        } else {
            content.environment(\.skinStyle, nil)
        }
    }
}

extension View {
    /// Draws this view and everything in it with `skin`: its colours, its bars and its typeface. System changes nothing.
    func skinned(_ skin: Skin) -> some View { modifier(SkinnedModifier(skin: skin)) }
}
