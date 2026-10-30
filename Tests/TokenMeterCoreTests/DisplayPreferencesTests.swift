import XCTest
@testable import TokenMeterCore

final class DisplayPreferencesTests: XCTestCase {
    private func check(_ preferences: any DisplayPreferences) {
        XCTAssertEqual(preferences.order, [])
        XCTAssertNil(preferences.windows(for: "claude"), "nothing chosen means every window")

        preferences.setOrder(["chatgpt", "claude"])
        preferences.setWindows(["7d"], for: "chatgpt")
        XCTAssertEqual(preferences.order, ["chatgpt", "claude"])
        XCTAssertEqual(preferences.windows(for: "chatgpt"), ["7d"])
        XCTAssertNil(preferences.windows(for: "claude"))

        preferences.setWindows(nil, for: "chatgpt")
        XCTAssertNil(preferences.windows(for: "chatgpt"), "clearing the choice shows every window again")
    }

    func testMemoryKeepsWhatIsSet() { check(MemoryDisplayPreferences()) }

    func testTheDefaultsKeepWhatIsSetAndAnotherInstanceReadsIt() {
        let name = "tokenmeter.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        check(DefaultsDisplayPreferences(defaults: defaults))

        let first = DefaultsDisplayPreferences(defaults: defaults)
        first.setOrder(["b", "a"])
        first.setWindows(["5h", "7d"], for: "a")
        let second = DefaultsDisplayPreferences(defaults: defaults)
        XCTAssertEqual(second.order, ["b", "a"])
        XCTAssertEqual(second.windows(for: "a"), ["5h", "7d"])
    }

    func testTheOrderPutsChosenProvidersFirstAndANewOneLast() {
        let preferences = MemoryDisplayPreferences()
        preferences.setOrder(["chatgpt", "claude", "gone"])
        XCTAssertEqual(preferences.ordered(["claude", "chatgpt", "gemini"]), ["chatgpt", "claude", "gemini"])
        XCTAssertEqual(preferences.ordered(["gemini", "claude"]), ["claude", "gemini"],
                       "a provider that left the file is ignored; the rest keep the file's order")
    }

    func testWithNoPreferenceTheFileOrderHolds() {
        XCTAssertEqual(MemoryDisplayPreferences().ordered(["claude", "chatgpt"]), ["claude", "chatgpt"])
    }
}
