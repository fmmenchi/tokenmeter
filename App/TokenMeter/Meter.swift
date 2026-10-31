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
    /// The problems the person has not hidden (ADR 0030); the panel draws these and the snapshot carries them.
    private(set) var problems: [Problem] = []
    /// Interface state of the fixes being run, by problem id. Not in the model or the snapshot (the plan of the feature).
    private(set) var fixStates: [String: FixState] = [:]

    enum FixState: Equatable {
        case running
        case failed(String)
        case done
    }

    private var detected: [Problem] = []
    private var providers: [ProviderConfig] = []
    private var lastDetection: Date?
    private var lastUsageRefresh: Date?
    private var isRefreshingUsage = false
    private var base: Snapshot?
    private let dismissals = DefaultsDismissals()
    private let preferences = DefaultsDisplayPreferences()
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
        let percent = fractions.min().map { "\(Int(($0 * 100).rounded()))%" } ?? "tokenmeter"
        return problems.isEmpty ? percent : "\(percent)  ▲ \(problems.count)"
    }

    func refresh(userInitiated: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let collector = collector
        detectProblemsIfDue()
        base = await Task.detached { collector.snapshot() }.value
        publish()
        refreshClaudeUsageIfDue(force: userInitiated)
    }

    /// ADR 0034: Claude Code writes a copy of the usage, including each model's limit, when it runs `/usage`. Ask it to,
    /// on a slow timer and when the person refreshes, in the background and only while the Claude quota switch is on.
    /// Claude Code reads its own credentials; tokenmeter handles none.
    private func refreshClaudeUsageIfDue(force: Bool) {
        guard autoSetUpClaude, !isRefreshingUsage else { return }
        if !force, let last = lastUsageRefresh, Date().timeIntervalSince(last) < 900 { return }
        isRefreshingUsage = true
        lastUsageRefresh = Date()
        Task(priority: .utility) {
            let outcome = await Task.detached(priority: .utility) { ClaudeUsageRefresh.refresh() }.value
            isRefreshingUsage = false
            if outcome == .refreshed { await refresh() }
            else { Self.log.info("Claude usage not refreshed: \(String(describing: outcome), privacy: .public)") }
        }
    }

    /// A provider as Settings lists it: every window it has, and which of them its card shows (ADR 0035).
    struct CardProvider: Identifiable {
        /// A model's limit, a part of the window named `parent`: a switch of its own in Settings (ADR 0034).
        struct Model: Identifiable {
            let id: String
            let label: String
            let parent: String
            /// What the switch says it is part of, for example "Weekly".
            let parentLabel: String
        }

        let id: String
        let title: String
        let plan: String?
        /// Names of windows the plan does not have (ADR 0037).
        let missing: [String]
        /// The provider's own windows, by id, in order.
        let windows: [String]
        let models: [Model]
        let shown: Set<String>
        let shownModels: Set<String>
        /// False when the person hid the provider: its card is not drawn and its row is dimmed.
        let isShown: Bool
    }

    /// The providers in the person's order, from the full reading, so Settings can offer windows that are hidden.
    /// Stored, and set by `publish()`, so a change of order or windows redraws Settings at once.
    private(set) var cardProviders: [CardProvider] = []

    private func makeCardProviders() -> [CardProvider] {
        let all = base?.providers ?? []
        let ids = preferences.ordered(all.map(\.provider.rawValue))
        let hidden = preferences.hidden
        // One provider always stays: when every one is hidden, the first in order is shown (Snapshot.applying).
        let shownIDs = ids.filter { !hidden.contains($0) }
        let visible = shownIDs.isEmpty ? Set(ids.prefix(1)) : Set(shownIDs)
        return ids.compactMap { id in
            guard let provider = all.first(where: { $0.provider.rawValue == id }) else { return nil }
            let own = provider.windows.map(\.window).filter { $0.scope == nil }
            let models = provider.windows.map(\.window).filter { $0.scope != nil }.map {
                CardProvider.Model(id: $0.id, label: $0.scope ?? $0.name, parent: $0.name,
                                   parentLabel: WindowSpec(name: $0.name, duration: 0).label)
            }
            let ownIDs = own.map(\.id)
            let chosen = preferences.windows(for: id)
            let chosenOwn = chosen.map { $0.intersection(ownIDs) }
            return CardProvider(
                id: id, title: provider.title, plan: provider.plan, missing: provider.missing, windows: ownIDs, models: models,
                shown: chosenOwn.flatMap { $0.isEmpty ? nil : $0 } ?? Set(ownIDs),
                shownModels: chosen.map { $0.intersection(models.map(\.id)) } ?? Set(models.map(\.id)),
                isShown: visible.contains(id))
        }
    }

    /// Moves a provider's card one place up or down.
    func moveProvider(_ id: String, by offset: Int) {
        var ids = cardProviders.map(\.id)
        guard let from = ids.firstIndex(of: id), ids.indices.contains(from + offset) else { return }
        ids.swapAt(from, from + offset)
        preferences.setOrder(ids)
        publish()
    }

    /// Drops a provider's card on another: it takes that card's place, and the ones in between shift.
    func moveProvider(_ id: String, onto target: String) {
        var ids = cardProviders.map(\.id)
        guard id != target, let from = ids.firstIndex(of: id), let to = ids.firstIndex(of: target) else { return }
        ids.insert(ids.remove(at: from), at: to)
        preferences.setOrder(ids)
        publish()
    }

    /// Hides or shows a provider's card. The last shown provider cannot be hidden.
    func setProviderShown(_ shown: Bool, for provider: String) {
        guard shown || cardProviders.filter(\.isShown).contains(where: { $0.id != provider }) else { return }
        preferences.setHidden(!shown, for: provider)
        publish()
    }

    /// One window always stays: an empty choice is ignored.
    func setShownWindows(_ windows: Set<String>, models: Set<String>, for provider: String) {
        guard !windows.isEmpty, let card = cardProviders.first(where: { $0.id == provider }) else { return }
        let everything = windows == Set(card.windows) && models == Set(card.models.map(\.id))
        preferences.setWindows(everything ? nil : windows.union(models), for: provider)
        publish()
    }

    /// Puts the visible problems on the latest reading and gives it to the widget.
    private func publish() {
        guard let base else { return }
        problems = dismissals.visible(detected)
        cardProviders = makeCardProviders()
        let result = base.applying(preferences).with(problems: problems)
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

    func setAutoSetUpClaude(_ enabled: Bool) {
        autoSetUpClaude = enabled
        UserDefaults.standard.set(enabled, forKey: Self.autoSetUpKey)
        setUpClaudeStatusLine()
    }

    /// Restore original stays in Settings (ADR 0030); the wrap itself is a fix in the panel.
    func restoreClaudeStatusLine() {
        do {
            _ = try ClaudeStatusLine.restore()
        } catch {
            Self.log.error("Could not restore the Claude status line: \(error.localizedDescription, privacy: .public)")
        }
        setUpClaudeStatusLine()
        detectProblems()
    }

    private var claudeScript: Data? {
        Bundle.main.url(forResource: "claude-statusline", withExtension: "sh").flatMap { try? Data(contentsOf: $0) }
    }

    /// ADR 0024: only while the switch is on, at every launch and when it is turned on.
    private func setUpClaudeStatusLine() {
        guard autoSetUpClaude else { claudeStatusLine = nil; return }
        guard let script = claudeScript else { return }
        do {
            claudeStatusLine = try ClaudeStatusLine.setUp(script: script)
        } catch {
            claudeStatusLine = nil
            Self.log.error("Could not set up the Claude status line: \(error.localizedDescription, privacy: .public)")
        }
        detectProblems()
    }

    private func makeIntegrations() -> Integrations {
        Integrations([ClaudeIntegration(script: claudeScript, enabled: autoSetUpClaude)])
    }

    /// ADR 0027: in the background at utility priority, at most every 10 minutes between changes.
    private func detectProblemsIfDue() {
        if let last = lastDetection, Date().timeIntervalSince(last) < 600 { return }
        detectProblems()
    }

    private func detectProblems() {
        lastDetection = Date()
        let hasAppGroup = store != nil
        let integrations = makeIntegrations()
        Task(priority: .utility) {
            let (found, configured) = await Task.detached(priority: .utility) {
                // A file that cannot be used falls back to the seed, as the collector does (ADR 0018).
                let configured = ((try? ProviderConfigFile.load()) ?? nil)?.providers ?? ProviderConfigFile.seed().providers
                let found = ProblemDetector.detect(
                    general: AppProblems.check(hasAppGroup: hasAppGroup), providers: configured,
                    integrations: integrations, context: ProblemContext())
                return (found, configured)
            }.value
            detected = found
            providers = configured
            for (id, state) in fixStates where state == .done { fixStates[id] = nil }
            publish()
        }
    }

    /// The button and the text of Learn more for a problem's fix; nil when it has none.
    func fixDescriptor(for problem: Problem) -> FixDescriptor? {
        FixRunner.descriptor(for: problem, providers: providers, integrations: makeIntegrations())
    }

    /// Runs the fix of a problem; the banner goes at the next check once the problem is gone.
    func runFix(_ problem: Problem) {
        guard fixStates[problem.id] != .running else { return }
        fixStates[problem.id] = .running
        let providers = providers
        let integrations = makeIntegrations()
        Task {
            let result = await Task.detached {
                FixRunner.run(problem, providers: providers, integrations: integrations, context: ProblemContext())
            }.value
            switch result {
            case .done:
                fixStates[problem.id] = .done
                setUpClaudeStatusLine()
            case .failed(let reason):
                fixStates[problem.id] = .failed(reason)
            }
        }
    }

    func dismiss(_ problem: Problem) {
        dismissals.hide(problem)
        fixStates[problem.id] = nil
        publish()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        try? LaunchAtLogin.set(enabled)
        // Show what macOS actually did: registration can fail for some signatures.
        launchAtLogin = LaunchAtLogin.isEnabled
    }
}
