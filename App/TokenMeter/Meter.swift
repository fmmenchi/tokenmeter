import Foundation
import Observation
import OSLog
import TokenMeterCore
import WidgetKit

@MainActor
@Observable
final class Meter {
    private(set) var snapshot: Snapshot?
    private(set) var isRefreshing = false
    private(set) var launchAtLogin = false
    private(set) var autoSetUpClaude = UserDefaults.standard.object(forKey: Meter.autoSetUpKey) as? Bool ?? true
    private(set) var claudeStatusLine: ClaudeStatusLine.Outcome?
    private static let autoSetUpKey = "autoSetUpClaudeStatusLine"
    private let collector = Collector()
    private let store = SnapshotStore.appGroupStore()
    private var timer: Timer?
    private static let log = Logger(subsystem: "com.fmmenchi.tokenmeter.app", category: "snapshot")

    init() {
        LaunchAtLogin.enableOnFirstRun()
        launchAtLogin = LaunchAtLogin.isEnabled
        setUpClaudeStatusLine()
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    /// Lowest known remaining fraction across providers, for the menu bar label.
    var menuBarTitle: String {
        let fractions = snapshot?.providers.flatMap(\.windows).compactMap(\.remainingFraction) ?? []
        guard let lowest = fractions.min() else { return "tokenmeter" }
        return "\(Int((lowest * 100).rounded()))%"
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let collector = collector
        let result = await Task.detached { collector.snapshot() }.value
        snapshot = result
        if let store {
            do {
                try store.write(result)
                WidgetCenter.shared.reloadAllTimelines()
            } catch {
                Self.log.error("Could not write \(store.url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    var widgetCanRead: Bool { store != nil }

    func setAutoSetUpClaude(_ enabled: Bool) {
        autoSetUpClaude = enabled
        UserDefaults.standard.set(enabled, forKey: Self.autoSetUpKey)
        setUpClaudeStatusLine()
    }

    /// ADR 0025: only on the user's click, never at launch.
    func wrapClaudeStatusLine() { changeClaudeStatusLine { try ClaudeStatusLine.wrap(script: $0) } }

    func restoreClaudeStatusLine() { changeClaudeStatusLine { _ in try ClaudeStatusLine.restore() } }

    private func changeClaudeStatusLine<Result>(_ change: (Data) throws -> Result) {
        guard let url = Bundle.main.url(forResource: "claude-statusline", withExtension: "sh"),
              let script = try? Data(contentsOf: url) else { return }
        do {
            _ = try change(script)
        } catch {
            Self.log.error("Could not change the Claude status line: \(error.localizedDescription, privacy: .public)")
        }
        setUpClaudeStatusLine()
    }

    /// ADR 0024: only while the switch is on, at every launch and when it is turned on.
    private func setUpClaudeStatusLine() {
        guard autoSetUpClaude else { claudeStatusLine = nil; return }
        guard let url = Bundle.main.url(forResource: "claude-statusline", withExtension: "sh"),
              let script = try? Data(contentsOf: url) else { return }
        do {
            claudeStatusLine = try ClaudeStatusLine.setUp(script: script)
        } catch {
            claudeStatusLine = nil
            Self.log.error("Could not set up the Claude status line: \(error.localizedDescription, privacy: .public)")
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        try? LaunchAtLogin.set(enabled)
        // Show what macOS actually did: registration can fail for some signatures.
        launchAtLogin = LaunchAtLogin.isEnabled
    }
}
