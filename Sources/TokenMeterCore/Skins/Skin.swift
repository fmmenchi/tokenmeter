import Foundation

/// The appearance a palette is for: the Mac's own, light or dark.
public enum SkinAppearance: String, CaseIterable, Sendable {
    case light
    case dark
}

/// How a bar is drawn in a skin (feature "skins").
public enum BarShape: String, Sendable {
    /// A rounded bar, as the panel always drew it.
    case pill
    /// A row of square blocks, filled from the left.
    case blocks
    /// A thin flat line.
    case line
    /// A thick bar with fully round ends.
    case thick
    /// A bar drawn as an outline with the fill inside it.
    case outline
}

/// The typeface of the numbers and the labels.
public enum Typeface: String, Sendable {
    case system
    case monospaced
}

/// The colours of a skin in one appearance, as `0xAARRGGBB`. Plain numbers, so the core needs no framework and a test can say
/// that a palette is the theme's.
public struct SkinPalette: Equatable, Sendable {
    public let panel: UInt32
    public let card: UInt32
    public let track: UInt32
    public let text: UInt32
    public let secondaryText: UInt32
    public let accent: UInt32
    /// The colours of a bar with plenty left, one under 40% and one under 15% (ADR 0002).
    public let plenty: UInt32
    public let middle: UInt32
    public let low: UInt32
    /// The pace tick of a quota that lasts. The tick of one that will not is the `middle` colour.
    public let tick: UInt32
    /// A hairline round a card, if the skin has one.
    public let border: UInt32?
}

/// A look for the panel, the widget and the stats: colours, the shape of the bar and the typeface. System is the look of
/// before the skins and has no palette: the views draw it as they always did ([ADR 0013](../../../docs/adr/0013-skins.md)).
///
/// The colours of the four others are those of well-known editor themes under the MIT licence, listed with their notices in the
/// licences page. Dracula's light palette, One Light's card and track, nine quota colours that were under 3 : 1 against what the
/// bar is drawn on, and five secondary text colours that were under 4.5 : 1 on the card are derived, not the theme's, and are marked.
/// `secondaryText` is opaque in every palette: a caption is read on the surface, and an alpha would make its contrast depend on it.
public enum Skin: String, CaseIterable, Codable, Sendable {
    case system
    case dracula
    case oneDark
    case catppuccin
    case nord

    public var title: String {
        switch self {
        case .system: "System"
        case .dracula: "Dracula"
        case .oneDark: "One Dark"
        case .catppuccin: "Catppuccin"
        case .nord: "Nord"
        }
    }

    public var shape: BarShape {
        switch self {
        case .system: .pill
        case .dracula: .blocks
        case .oneDark: .line
        case .catppuccin: .thick
        case .nord: .outline
        }
    }

    public var typeface: Typeface {
        switch self {
        case .dracula, .oneDark: .monospaced
        default: .system
        }
    }

    /// The thickness of a window's bar, in points. A model's line is always 4.
    public var barHeight: Double {
        switch self {
        case .system, .nord: 10
        case .dracula: 12
        case .oneDark: 3
        case .catppuccin: 16
        }
    }

    public var cardRadius: Double {
        switch self {
        case .system: 10
        case .dracula: 3
        case .oneDark: 2
        case .catppuccin: 18
        case .nord: 6
        }
    }

    /// False where the card is drawn as an outline only, over the panel.
    public var fillsCard: Bool { self != .nord }

    /// The short note under the name in Settings.
    public var note: String {
        switch self {
        case .system: "Default"
        case .dracula: "Terminal: square blocks"
        case .oneDark: "Editor: a thin line"
        case .catppuccin: "Soft: thick round bars"
        case .nord: "Frost: outlined bars"
        }
    }

    public func palette(for appearance: SkinAppearance) -> SkinPalette? {
        switch (self, appearance) {
        case (.system, _): nil
        case (.dracula, .dark):
            // `low` is derived: the theme's red, FF5555, is 2.9 : 1 against the track, and is lightened to 3 : 1.
            SkinPalette(panel: 0xFF21222C, card: 0xFF282A36, track: 0xFF44475A, text: 0xFFF8F8F2, secondaryText: 0xFF8692B9,
                        accent: 0xFFBD93F9, plenty: 0xFF50FA7B, middle: 0xFFFFB86C, low: 0xFFFF5F5F, tick: 0xFFF8F8F2,
                        border: 0xFF44475A)
        case (.dracula, .light):
            // Derived from the dark palette: each colour darkened to 3 : 1 against the track. Not an official Dracula theme.
            SkinPalette(panel: 0xFFE9E9E0, card: 0xFFF8F8F2, track: 0xFFD6D6CC, text: 0xFF282A36, secondaryText: 0xFF5F6FA2,
                        accent: 0xFF731AF2, plenty: 0xFF048926, middle: 0xFFB85F00, low: 0xFFEE0000, tick: 0xFF282A36,
                        border: 0xFF44475A)
        case (.oneDark, .dark):
            // `low` is derived (the theme's E05561 is 2.6 : 1 against the track).
            SkinPalette(panel: 0xFF21252B, card: 0xFF282C34, track: 0xFF3E4452, text: 0xFFABB2BF, secondaryText: 0xFF91959E,
                        accent: 0xFF4AA5F0, plenty: 0xFF4AA5F0, middle: 0xFFD18F52, low: 0xFFE46B75, tick: 0xFFABB2BF,
                        border: 0xFF3E4452)
        case (.oneDark, .light):
            // One Light: the text and the accent are the theme's, the card and the track are derived from its background, and so are
            // the three quota colours, each darkened from the theme's (4078F2, C18401, E45649) to 3 : 1 against the track.
            SkinPalette(panel: 0xFFFAFAFA, card: 0xFFFFFFFF, track: 0xFFDBDBDC, text: 0xFF383A42, secondaryText: 0xFF696C77,
                        accent: 0xFF4078F2, plenty: 0xFF3973F2, middle: 0xFFA57101, low: 0xFFE03F31, tick: 0xFF383A42,
                        border: 0xFF3E4452)
        case (.catppuccin, .dark):
            SkinPalette(panel: 0xFF181825, card: 0xFF1E1E2E, track: 0xFF45475A, text: 0xFFCDD6F4, secondaryText: 0xFFA6ADC8,
                        accent: 0xFFCBA6F7, plenty: 0xFF94E2D5, middle: 0xFFFAB387, low: 0xFFF38BA8, tick: 0xFFCDD6F4,
                        border: nil)
        case (.catppuccin, .light):
            // The quota colours are derived, each darkened from Latte's (teal 179299, peach FE640B, red D20F39) to 3 : 1 against
            // the track.
            SkinPalette(panel: 0xFFE6E9EF, card: 0xFFEFF1F5, track: 0xFFBCC0CC, text: 0xFF4C4F69, secondaryText: 0xFF696B81,
                        accent: 0xFF8839EF, plenty: 0xFF127278, middle: 0xFFB44201, low: 0xFFCD0F38, tick: 0xFF4C4F69,
                        border: nil)
        case (.nord, .dark):
            SkinPalette(panel: 0xFF2E3440, card: 0xFF3B4252, track: 0xFF4C566A, text: 0xFFD8DEE9, secondaryText: 0xFF989EA8,
                        accent: 0xFF88C0D0, plenty: 0xFF88C0D0, middle: 0xFFEBCB8B, low: 0xFFBF616A, tick: 0xFFECEFF4,
                        border: 0xFF434C5E)
        case (.nord, .light):
            // `middle` is derived: Nord's D08770 is 2.3 : 1 against the panel the outlined bar is drawn on, and is darkened to 3 : 1.
            SkinPalette(panel: 0xFFE5E9F0, card: 0xFFECEFF4, track: 0xFFD8DEE9, text: 0xFF2E3440, secondaryText: 0xFF4C566A,
                        accent: 0xFF5E81AC, plenty: 0xFF5E81AC, middle: 0xFFC56C4F, low: 0xFFBF616A, tick: 0xFF2E3440,
                        border: 0xFF434C5E)
        }
    }
}
