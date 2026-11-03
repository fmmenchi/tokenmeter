import Foundation

/// What the panel carries during an event: one icon for the bars and one piece for the corners of the cards, named as the images
/// of the app are (feature "seasonal easter eggs"). They are picked at random each time the panel opens and kept while it stays open.
public struct EasterEgg: Equatable, Sendable {
    public let occasion: Occasion
    /// The name of the image that takes the place of the pace tick on a bar whose quota lasts.
    public let mark: String
    /// The name of the image that sits across the top right corner of a card.
    public let corner: String

    /// The pick for `seed`: the same seed always gives the same pick, and any seed gives a pick of the event's own set.
    public static func pick(for occasion: Occasion, seed: UInt64) -> EasterEgg {
        var generator = SplitMix64(state: seed)
        let marks = occasion.marks, corners = occasion.corners
        let mark = marks[Int(generator.next() % UInt64(marks.count))]
        let corner = corners[Int(generator.next() % UInt64(corners.count))]
        return EasterEgg(occasion: occasion, mark: mark, corner: corner)
    }

    /// A pick with a seed of its own, for the moment the panel opens.
    public static func random(for occasion: Occasion) -> EasterEgg {
        pick(for: occasion, seed: UInt64.random(in: .min ... .max))
    }
}

extension Occasion {
    /// The icons for the bars. The names are the files of the app's `EasterEggs/Pieces` folder, without the extension.
    public var marks: [String] { Self.names(for: self, kind: "mark", pieces: markPieces) }
    /// The pieces for the corners of the cards.
    public var corners: [String] { Self.names(for: self, kind: "corner", pieces: cornerPieces) }

    private var markPieces: [String] {
        switch self {
        case .halloween: ["pumpkin", "ghost", "bat", "candy", "skull", "witch"]
        case .christmas: ["tree", "santa", "reindeer", "snowman", "gift", "bell"]
        case .easter: ["bunny", "chick", "egg", "basket", "carrot", "lamb"]
        }
    }

    private var cornerPieces: [String] {
        switch self {
        case .halloween: ["pumpkin", "ghost", "bat", "web", "skull", "witch"]
        case .christmas: ["branch", "santa", "reindeer", "snowman", "gift", "bell"]
        case .easter: ["bunny", "chick", "egg", "basket", "carrot", "lamb"]
        }
    }

    private static func names(for occasion: Occasion, kind: String, pieces: [String]) -> [String] {
        pieces.map { "egg-\(occasion.rawValue)-\(kind)-\($0)" }
    }
}

/// A small, fixed generator: the same state gives the same sequence on every machine, which the tests rely on.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
