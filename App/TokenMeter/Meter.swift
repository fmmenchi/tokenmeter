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
    /// The problems the person has not hidden (ADR 0005); the panel draws these and the snapshot carries them.
    private(set) var problems: [Problem] = []
    /// Interface state of the fixes being run, by problem id. Not in the model or the snapshot (the plan of the feature).
    private(set) var fixStates: [String: FixState] = [:]
    /// The app updating itself (ADR 0011). Here so that the dot and the panel read it with the problems.
    let updater = Updater()

    // MARK: Easter eggs (feature "seasonal easter eggs")

    /// What the panel carries in the week of an event: an icon for the bars and a piece for the cards. Nil on every other day.
    private(set) var easterEgg: EasterEgg?

    /// Picked again each time the panel opens, from the event of that day, and kept while it stays open.
    func rollEasterEgg(now: Date = Date()) {
        easterEgg = Occasion.active(on: now).map { EasterEgg.random(for: $0) }
    }

    // MARK: Notices (ADR 0012)

    /// The kinds of notice the person turned on. None at first: a notice is something the person asked for.
    private(set) var enabledNotices: Set<NoticeKind> = Set(
        (UserDefaults.standard.stringArray(forKey: Meter.noticeKindsKey) ?? []).compactMap(NoticeKind.init(rawValue:)))
    /// Where the permission of macOS stands; nothing is posted until it is allowed.
    private(set) var noticePermission = Notifier.Permission.unknown
    var noticesBlocked: Bool { noticePermission == .denied }
    @ObservationIgnored private let notifier = Notifier()
    /// What was already told, kept across launches so a restart does not tell it again.
    @ObservationIgnored private var noticeLedger = (UserDefaults.standard.data(forKey: Meter.noticeLedgerKey)
        .flatMap { try? JSONDecoder().decode(NoticeLedger.self, from: $0) }) ?? NoticeLedger()

    // MARK: Usage stats (ADR 0010)

    /// What the stats view says for each provider, from the store, for every range, so that choosing a range is a lookup and the view
    /// does not draw the old range while the new one is worked out. Empty until the first pass has run.
    private(set) var statsByRange: [StatsRange: [ProviderStats]] = [:]
    var stats: [ProviderStats] { statsByRange[statsRange] ?? [] }
    /// True while the ingestor is reading, so the view can say it is reading the history.
    private(set) var isIngesting = false
    /// False when the store could not be opened: the stats view says so, and nothing else depends on it.
    private(set) var storeAvailable = false
    /// Which view the panel shows. Not kept: the panel opens on the current quota, and the stats are one click away.
    var showsStats = false
    var statsRange = StatsRange(rawValue: UserDefaults.standard.string(forKey: Meter.statsRangeKey) ?? "") ?? .quarter {
        didSet { UserDefaults.standard.set(statsRange.rawValue, forKey: Meter.statsRangeKey) }
    }
    /// The one stats card that is open to its detail, so the panel keeps a height that fits the screen: opening another closes this
    /// one, and a click on it closes it. Nil until the person chooses, and then the first card is open; "" is none. Kept across launches.
    private(set) var openStatsCard = UserDefaults.standard.string(forKey: Meter.openStatsCardKey)
    func toggleStatsDetail(_ card: String, defaultOpen: String?) {
        let current = openStatsCard ?? defaultOpen
        openStatsCard = current == card ? "" : card
        UserDefaults.standard.set(openStatsCard, forKey: Meter.openStatsCardKey)
    }
    private var lastStatsAt = Date.distantPast
    private let usageStore: UsageStore?
    private let ingestor: UsageIngestor?
    private static let noticeKindsKey = "noticeKinds"
    private static let noticeLedgerKey = "noticeLedger"
    private static let statsRangeKey = "statsRange"
    private static let openStatsCardKey = "statsOpenCard"
    /// The id of the card for all providers, next to the ids of the providers.
    static let allProvidersCard = "all-providers"

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
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("TokenMeter", isDirectory: true)
        do {
            guard let folder else { throw UsageStore.Failure(description: "no Application Support folder") }
            let opened = try UsageStore(url: folder.appendingPathComponent("usage.sqlite"))
            usageStore = opened
            ingestor = UsageIngestor(store: opened)
            storeAvailable = true
        } catch {
            usageStore = nil
            ingestor = nil
            Self.log.error("Could not open the usage store: \(error.localizedDescription, privacy: .public)")
        }
        LaunchAtLogin.enableOnFirstRun()
        launchAtLogin = LaunchAtLogin.isEnabled
        setUpClaudeStatusLine()
        Task { await refreshNoticePermission() }
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    /// Whether the menu bar item carries its dot: something the panel lists, and that is worth opening it for, a problem or an update
    /// that waits. The count and the detail are in the panel; one figure across several providers says nothing about any of them,
    /// so the bar shows none.
    var needsAttention: Bool { !problems.isEmpty || updater.hasUpdate }

    func refresh(userInitiated: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let collector = collector
        detectProblemsIfDue()
        base = await Task.detached { collector.snapshot() }.value
        publish()
        refreshClaudeUsageIfDue(force: userInitiated)
        ingestInBackground()
    }

    /// ADR 0010: after the snapshot, off the main thread at utility priority, so the panel never waits for the store. The
    /// first pass reads every file the CLIs still keep; later ones only what is new.
    private func ingestInBackground() {
        guard let ingestor, let usageStore, !isIngesting else { return }
        isIngesting = true
        // The figures are worked out again when something new was read, and at least every ten minutes: a window ends with time.
        let due = statsByRange.isEmpty || Date().timeIntervalSince(lastStatsAt) > 600
        Task(priority: .utility) {
            let computed = await Task.detached(priority: .utility) { () -> [StatsRange: [ProviderStats]]? in
                let read = ingestor.ingest()
                return read.messages > 0 || due ? Self.computeStats(store: usageStore) : nil
            }.value
            if let computed {
                statsByRange = computed
                lastStatsAt = Date()
            }
            isIngesting = false
        }
    }

    /// Every range from the same facts: the configured providers, as the collector reads them (ADR 0003), each with its windows and
    /// its family rules. A few queries for each, so a change of range needs no wait.
    nonisolated private static func computeStats(store: UsageStore) -> [StatsRange: [ProviderStats]] {
        let configured = ((try? ProviderConfigFile.load()) ?? nil)?.providers ?? ProviderConfigFile.seed().providers
        return Dictionary(uniqueKeysWithValues: StatsRange.allCases.map { range in
            (range, configured.map {
                UsageStats.stats(for: Provider(rawValue: $0.id), windows: $0.windows, families: $0.usage?.families ?? [],
                                 store: store, range: range)
            })
        })
    }

    /// ADR 0002: Claude Code writes a copy of the usage, including each model's limit, when it runs `/usage`. Ask it to,
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

    /// A provider as Settings lists it: every window it has, and which of them its card shows (ADR 0006).
    struct CardProvider: Identifiable {
        /// A model's limit, a part of the window named `parent`: a switch of its own in Settings (ADR 0002).
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
            let shownOwn = chosenOwn.flatMap { $0.isEmpty ? nil : $0 } ?? Set(ownIDs)
            let off = preferences.hiddenModels(for: id)
            let shownModels = Set(models.filter { shownOwn.contains($0.parent) && !off.contains($0.id) }.map(\.id))
            return CardProvider(
                id: id, title: provider.title, plan: provider.plan, windows: ownIDs, models: models,
                shown: shownOwn, shownModels: shownModels, isShown: visible.contains(id))
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

    /// Hides or shows a provider's card with its switch. The last shown provider cannot be hidden. Its windows are kept (ADR 0006).
    func setProviderShown(_ shown: Bool, for provider: String) {
        guard shown || canHide(provider) else { return }
        preferences.setShown(shown, for: provider)
        publish()
    }

    private func canHide(_ provider: String) -> Bool {
        cardProviders.filter(\.isShown).contains { $0.id != provider }
    }

    /// The person chooses windows. The last one cannot be turned off, and a window never hides the provider (ADR 0006).
    func setShownWindows(_ windows: Set<String>, for provider: String) {
        guard let card = cardProviders.first(where: { $0.id == provider }) else { return }
        let choice = WindowChoice(windows: card.windows, models: Dictionary(uniqueKeysWithValues: card.models.map {
            ($0.id, $0.parent)
        }))
        guard preferences.select(windows, among: choice, for: provider) else { return }
        publish()
    }

    /// Turns a model's limit on or off.
    func setModel(_ model: String, shown: Bool, for provider: String) {
        preferences.setModel(model, shown: shown, for: provider)
        publish()
    }

    /// Puts the visible problems on the latest reading and gives it to the widget.
    private func publish() {
        guard let base else { return }
        problems = dismissals.visible(detected)
        cardProviders = makeCardProviders()
        let result = base.applying(preferences).with(problems: problems)
        snapshot = result
        deliverNotices(now: Date())
        if let store {
            do {
                try store.write(result)
                WidgetCenter.shared.reloadAllTimelines()
            } catch {
                Self.log.error("Could not write \(store.url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// A switch of Settings. The permission of macOS is asked the first time one is turned on, and a notice still due is told at once.
    func setNotice(_ kind: NoticeKind, enabled: Bool) {
        if enabled { enabledNotices.insert(kind) } else { enabledNotices.remove(kind) }
        UserDefaults.standard.set(enabledNotices.map(\.rawValue).sorted(), forKey: Self.noticeKindsKey)
        guard enabled else { return }
        Task {
            noticePermission = await notifier.requestIfNeeded()
            deliverNotices(now: Date())
        }
    }

    /// Settings asks again each time it opens, because the person may have changed it in System Settings.
    func refreshNoticePermission() async {
        noticePermission = await notifier.permission()
        // Allowed just now: whatever is due is told at once.
        deliverNotices(now: Date())
    }

    private func deliverNotices(now: Date) {
        guard !enabledNotices.isEmpty, noticePermission == .allowed, let snapshot else { return }
        let outcome = LimitNotices.evaluate(snapshot: snapshot, enabled: enabledNotices, ledger: noticeLedger, now: now)
        noticeLedger = outcome.ledger
        if let data = try? JSONEncoder().encode(noticeLedger) { UserDefaults.standard.set(data, forKey: Self.noticeLedgerKey) }
        for notice in outcome.notices { notifier.post(notice) }
    }

    func setAutoSetUpClaude(_ enabled: Bool) {
        autoSetUpClaude = enabled
        UserDefaults.standard.set(enabled, forKey: Self.autoSetUpKey)
        setUpClaudeStatusLine()
    }

    /// Restore original stays in Settings (ADR 0005); the wrap itself is a fix in the panel.
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

    /// ADR 0004: only while the switch is on, at every launch and when it is turned on.
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

    /// ADR 0005: in the background at utility priority, at most every 10 minutes between changes.
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
                // A file that cannot be used falls back to the seed, as the collector does (ADR 0003).
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
