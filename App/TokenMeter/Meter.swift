import Foundation
import Observation
import TokenMeterCore
import WidgetKit

@MainActor
@Observable
final class Meter {
    private(set) var snapshot: Snapshot?
    private(set) var isRefreshing = false
    var limits: LimitSettings {
        didSet { saveLimits(); Task { await refresh() } }
    }

    private let defaults = UserDefaults(suiteName: SnapshotStore.appGroup) ?? .standard
    private let collector = Collector()
    private let store = SnapshotStore.appGroupStore()
    private var timer: Timer?

    init() {
        limits = LimitSettings(
            claudeSession: defaults.object(forKey: "claudeSession") as? Int,
            claudeWeek: defaults.object(forKey: "claudeWeek") as? Int,
            chatgptSession: defaults.object(forKey: "chatgptSession") as? Int,
            chatgptWeek: defaults.object(forKey: "chatgptWeek") as? Int)
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
        let limits = limits
        let result = await Task.detached { collector.snapshot(limits: limits) }.value
        snapshot = result
        if let store {
            try? store.write(result)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func saveLimits() {
        for (key, value) in [("claudeSession", limits.claudeSession), ("claudeWeek", limits.claudeWeek),
                             ("chatgptSession", limits.chatgptSession), ("chatgptWeek", limits.chatgptWeek)] {
            if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
    }

    var widgetCanRead: Bool { store != nil }
}
