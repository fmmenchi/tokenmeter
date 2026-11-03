import XCTest
@testable import TokenMeterCore

final class SkinsTests: XCTestCase {
    private func luminance(_ argb: UInt32) -> Double {
        func channel(_ shift: UInt32) -> Double {
            let value = Double((argb >> shift) & 0xFF) / 255
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }

    private func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let (high, low) = (max(luminance(a), luminance(b)), min(luminance(a), luminance(b)))
        return (high + 0.05) / (low + 0.05)
    }

    func testSystemHasNoPaletteAndTheOthersHaveBoth() {
        for appearance in SkinAppearance.allCases {
            XCTAssertNil(Skin.system.palette(for: appearance))
            for skin in Skin.allCases where skin != .system {
                XCTAssertNotNil(skin.palette(for: appearance), "\(skin) in \(appearance)")
            }
        }
    }

    func testPalettesAreTheThemesNumbers() {
        // One value of each theme, as in its own file: Dracula's BG and green, One Dark Pro's editor background and blue,
        // Catppuccin's mocha base and latte red, Nord's nord0 and nord11.
        XCTAssertEqual(Skin.dracula.palette(for: .dark)?.card, 0xFF282A36)
        XCTAssertEqual(Skin.dracula.palette(for: .dark)?.plenty, 0xFF50FA7B)
        XCTAssertEqual(Skin.oneDark.palette(for: .dark)?.card, 0xFF282C34)
        XCTAssertEqual(Skin.oneDark.palette(for: .dark)?.plenty, 0xFF4AA5F0)
        XCTAssertEqual(Skin.catppuccin.palette(for: .dark)?.card, 0xFF1E1E2E)
        XCTAssertEqual(Skin.catppuccin.palette(for: .light)?.low, 0xFFD20F39)
        XCTAssertEqual(Skin.nord.palette(for: .dark)?.panel, 0xFF2E3440)
        XCTAssertEqual(Skin.nord.palette(for: .light)?.low, 0xFFBF616A)
    }

    func testTheTextCanBeReadOnTheCard() {
        for skin in Skin.allCases {
            for appearance in SkinAppearance.allCases {
                guard let palette = skin.palette(for: appearance) else { continue }
                XCTAssertGreaterThanOrEqual(contrast(palette.text, palette.card), 4.5, "\(skin) in \(appearance)")
            }
        }
    }

    func testTheTickCanBeSeenOnTheCard() {
        for skin in Skin.allCases {
            for appearance in SkinAppearance.allCases {
                guard let palette = skin.palette(for: appearance) else { continue }
                XCTAssertGreaterThanOrEqual(contrast(palette.tick, palette.card), 4.5, "\(skin) in \(appearance)")
            }
        }
    }

    func testEachSkinDrawsItsOwnBar() {
        XCTAssertEqual(Set(Skin.allCases.map(\.shape)).count, Skin.allCases.count)
        XCTAssertEqual(Skin.dracula.typeface, .monospaced)
        XCTAssertEqual(Skin.nord.typeface, .system)
        XCTAssertFalse(Skin.nord.fillsCard)
    }

    func testTheIdsAreStable() {
        // They are written in the defaults and in the snapshot, so they must not change.
        XCTAssertEqual(Skin.allCases.map(\.rawValue), ["system", "dracula", "oneDark", "catppuccin", "nord"])
    }

    // MARK: The snapshot

    private func encoded(_ snapshot: Snapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    private func decoded(_ data: Data) throws -> Snapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Snapshot.self, from: data)
    }

    func testASnapshotCarriesItsSkin() throws {
        let snapshot = Snapshot(generatedAt: Date(timeIntervalSince1970: 1_000_000), providers: []).with(skin: .nord)
        XCTAssertEqual(try decoded(try encoded(snapshot)).skin, .nord)
    }

    func testASnapshotFromBeforeTheSkinsIsSystem() throws {
        let json = #"{"generatedAt":"2026-11-02T10:00:00Z","providers":[]}"#
        XCTAssertEqual(try decoded(Data(json.utf8)).skin, .system)
    }

    func testASkinThisVersionDoesNotKnowIsSystem() throws {
        let json = #"{"generatedAt":"2026-11-02T10:00:00Z","providers":[],"skin":"solarized"}"#
        XCTAssertEqual(try decoded(Data(json.utf8)).skin, .system)
    }

    func testTheSkinSurvivesTheProblemsAndThePreferences() {
        let snapshot = Snapshot(generatedAt: Date(timeIntervalSince1970: 0), providers: []).with(skin: .dracula)
        XCTAssertEqual(snapshot.with(problems: []).skin, .dracula)
        XCTAssertEqual(snapshot.applying(MemoryDisplayPreferences()).skin, .dracula)
    }
}
