import Foundation
import Observation
import TokenMeterCore
import WidgetKit

@MainActor
@Observable
final class Meter {
    private(set) var snapshot: Snapshot?
    private(set) var isRefreshing = false
    private let collector = Collector()
    private let store = SnapshotStore.appGroupStore()
    private var timer: Timer?

    init() {
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
            try? store.write(result)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    var widgetCanRead: Bool { store != nil }
}
