import ServiceManagement

enum LaunchAtLogin {
    private static let decidedKey = "launchAtLoginDecided"

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// Registers once, on first run. Afterwards the user's switch is the only authority (ADR 0011).
    static func enableOnFirstRun() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: decidedKey) else { return }
        defaults.set(true, forKey: decidedKey)
        try? set(true)
    }
}
