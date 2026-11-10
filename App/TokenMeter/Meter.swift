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
    /// What the setup of the status line found, by Claude entry (ADR 0014); empty while the switch is off or before launch.
    private(set) var claudeStatusLines: [String: ClaudeStatusLine.Outcome] = [:]
    /// The Claude entries the setup knows, in the file's order, so Settings can say a line for each (ADR 0014).
    private(set) var claudeAccounts: [ClaudeAccounts.Entry] = []
    /// Every entry of the file as the Accounts tab lists it, with who is signed in, read with the problems (ADR 0014).
    private(set) var accounts: [AccountSummary] = []
    /// The folders of a tool found at the last detection, so Add it on a banner knows which folder it is about.
    private var foundFolders: [AccountFolders.Found] = []
    /// A folder Add it was pressed for: the Accounts tab opens its sheet on it, filled in, and clears this.
    var pendingAccount: AccountFolders.Found?
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
        #if DEBUG
        let occasion = DevOptions.occasion ?? Occasion.active(on: now)
        #else
        let occasion = Occasion.active(on: now)
        #endif
        easterEgg = occasion.map { EasterEgg.random(for: $0) }
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
    /// True from launch until the store answers: opening it may migrate it, so it is done off the main actor (ADR 0005).
    private(set) var storeIsOpening = true
    /// Which view the panel shows. Not kept: the panel opens on the current quota, and the stats are one click away.
    var showsStats = false
    /// The look the person chose in Settings (ADR 0013): kept in the defaults, and written to the snapshot so the widget draws the same.
    var skin = Skin(rawValue: UserDefaults.standard.string(forKey: Meter.skinKey) ?? "") ?? .system {
        didSet {
            guard skin != oldValue else { return }
            UserDefaults.standard.set(skin.rawValue, forKey: Self.skinKey)
            publish()
        }
    }

    /// How the bars read, chosen in Settings (ADR 0006): kept in the defaults, and written to the snapshot like the skin.
    var barsDisplay = BarsDisplay(rawValue: UserDefaults.standard.string(forKey: Meter.barsDisplayKey) ?? "") ?? .left {
        didSet {
            guard barsDisplay != oldValue else { return }
            UserDefaults.standard.set(barsDisplay.rawValue, forKey: Self.barsDisplayKey)
            publish()
        }
    }

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
    private var usageStore: UsageStore?
    private var ingestor: UsageIngestor?
    private static let noticeKindsKey = "noticeKinds"
    private static let noticeLedgerKey = "noticeLedger"
    private static let statsRangeKey = "statsRange"
    private static let skinKey = "skin"
    private static let barsDisplayKey = "barsDisplay"
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
    /// The last outcome of what the app tried, kept so a failure is a problem and not only a line in Console (ADR 0005). Nil is good,
    /// or not asked yet.
    private var providersFileError: String?
    private var snapshotWriteError: String?
    /// The script the app installs as the Claude status line, read once at launch off the main actor.
    private var claudeScript: Data?
    /// Snapshots are written one after the other, in the order they were made, and never on the main actor.
    @ObservationIgnored private let writer = DispatchQueue(label: "com.fmmenchi.tokenmeter.snapshot-writer", qos: .utility)
    private var base: Snapshot?
    private let dismissals = DefaultsDismissals()
    private let preferences = DefaultsDisplayPreferences()
    private static let autoSetUpKey = "autoSetUpClaudeStatusLine"
    /// Rebuilt when the file changes: after a write of the app, or by hand between two detections (ADR 0014).
    private var collector = Collector()
    private var providersFileStamp = Meter.providersFileStamp()
    private let store = SnapshotStore.appGroupStore()
    private var timer: Timer?
    private static let log = Logger(subsystem: "com.fmmenchi.tokenmeter.app", category: "snapshot")

    init() {
        LaunchAtLogin.enableOnFirstRun()
        launchAtLogin = LaunchAtLogin.isEnabled
        Task { await refreshNoticePermission() }
        Task { await launch() }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    /// What the app does once at launch, in an order that matters, and off the main actor where it touches the disk (ADR 0005): the
    /// store is opened (which may migrate it) and the status line script is read together, then the status line is set up, and the
    /// first reading follows.
    private func launch() async {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("TokenMeter", isDirectory: true)
        let (script, opened) = await Task.detached(priority: .utility) { () -> (Data?, Result<UsageStore, Error>) in
            let script = Bundle.main.url(forResource: "claude-statusline", withExtension: "sh").flatMap { try? Data(contentsOf: $0) }
            guard let folder else { return (script, .failure(UsageStore.Failure(description: "no Application Support folder"))) }
            return (script, Result { try UsageStore(url: folder.appendingPathComponent("usage.sqlite")) })
        }.value
        claudeScript = script
        switch opened {
        case .success(let store):
            usageStore = store
            ingestor = UsageIngestor(store: store)
            storeAvailable = true
        case .failure(let error):
            Self.log.error("Could not open the usage store: \(error.localizedDescription, privacy: .public)")
        }
        storeIsOpening = false
        await setUpClaudeStatusLine()
        await refresh()
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
        refreshClaudeUsageIfDue(userInitiated: userInitiated)
        ingestInBackground()
    }

    /// ADR 0015, amended on 2026-11-10: Claude Code writes each model's limit into `~/.claude.json` when it runs `/usage`, so
    /// ask it to, in the background, every 15 minutes and when the person refreshes, but never twice in a minute, only while the
    /// Claude quota switch is on, once for each Claude account in its own folder (ADR 0014). Claude Code reads its own
    /// credentials; tokenmeter handles none. A run that changes nothing, fails or cannot find `claude` says nothing: the card
    /// keeps saying when the limits were last seen, and **Open /usage** stays there.
    private func refreshClaudeUsageIfDue(userInitiated: Bool) {
        guard autoSetUpClaude, !isRefreshingUsage else { return }
        if let last = lastUsageRefresh, Date().timeIntervalSince(last) < (userInitiated ? 60 : 900) { return }
        isRefreshingUsage = true
        lastUsageRefresh = Date()
        let accounts = ClaudeAccounts.entries(in: providers, integrations: makeIntegrations()).map(\.account)
        Task(priority: .utility) {
            var outcomes: [ClaudeUsageRefresh.Outcome] = []
            for account in accounts.isEmpty ? [.default()] : accounts {
                outcomes.append(await ClaudeUsageRefresh.refresh(account: account))
            }
            isRefreshingUsage = false
            Self.log.info("Claude usage refresh: \(String(describing: outcomes), privacy: .public)")
            if outcomes.contains(.refreshed) { await refresh() }
        }
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

    /// A card as the unlocked panel draws it (ADR 0014): the provider's full reading, hidden or not, with what the person chose.
    struct Arrangeable: Identifiable {
        let snapshot: ProviderSnapshot
        let card: CardProvider
        var id: String { card.id }
    }

    /// Every card in the person's order, the hidden ones too, from the full reading, so the unlocked panel can show and
    /// arrange them all (ADR 0006, 0014).
    var arrangeable: [Arrangeable] {
        cardProviders.compactMap { card in
            base?.providers.first { $0.provider.rawValue == card.id }.map { Arrangeable(snapshot: $0, card: card) }
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

    /// The account whose interactive Usage screen can refresh this Claude card's model limits (ADR 0015).
    func claudeAccount(for provider: Provider) -> ClaudeStatusLine.Account? {
        ClaudeAccounts.entries(in: providers, integrations: makeIntegrations())
            .first { $0.id == provider.rawValue }?.account
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
        // What the app met itself comes first, then what the detector found; a repeated id keeps its first occurrence.
        let own = AppProblems.check(hasAppGroup: store != nil, providersFileError: providersFileError,
                                    snapshotWriteError: snapshotWriteError)
        problems = dismissals.visible(ProblemDetector.merge(general: own, providers: [detected]))
        cardProviders = makeCardProviders()
        let result = base.applying(preferences).with(problems: problems).with(skin: skin).with(barsDisplay: barsDisplay)
        snapshot = result
        deliverNotices(now: Date())
        write(result)
    }

    /// Off the main actor and in order. The outcome comes back: a failure is a problem, and the one that follows a good write or the
    /// other way round publishes again so the panel and the widget say it.
    private func write(_ result: Snapshot) {
        guard let store else { return }
        writer.async { [weak self] in
            var failure: String?
            do { try store.write(result) } catch { failure = error.localizedDescription }
            Task { @MainActor in self?.wrote(failure: failure, path: store.url.path) }
        }
    }

    private func wrote(failure: String?, path: String) {
        if let failure {
            Self.log.error("Could not write \(path, privacy: .public): \(failure, privacy: .public)")
        } else {
            WidgetCenter.shared.reloadAllTimelines()
        }
        guard failure != snapshotWriteError else { return }
        snapshotWriteError = failure
        publish()
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
        for notice in outcome.notices { notifier.post(notice, reading: barsDisplay) }
    }

    func setAutoSetUpClaude(_ enabled: Bool) {
        autoSetUpClaude = enabled
        UserDefaults.standard.set(enabled, forKey: Self.autoSetUpKey)
        Task { await setUpClaudeStatusLine() }
    }

    /// Restore original stays in Settings (ADR 0005); the wrap itself is a fix in the panel.
    /// Puts the account's own status line back, in its folder (ADR 0014).
    func restoreClaudeStatusLine(for id: String) {
        guard let entry = ClaudeAccounts.entries(in: providers, integrations: makeIntegrations()).first(where: { $0.id == id })
        else { return }
        let account = entry.account
        Task {
            let failure = await Task.detached(priority: .utility) { () -> String? in
                do { _ = try ClaudeStatusLine.restore(account: account); return nil } catch { return error.localizedDescription }
            }.value
            if let failure { Self.log.error("Could not restore the Claude status line of \(id, privacy: .public): \(failure, privacy: .public)") }
            await setUpClaudeStatusLine()
            detectProblems()
        }
    }

    /// ADR 0004: only while the switch is on, at every launch and when it is turned on, for each Claude entry in its own
    /// folder (ADR 0014). The file and the settings are read and written off the main actor (ADR 0005).
    private func setUpClaudeStatusLine() async {
        guard autoSetUpClaude else { claudeStatusLines = [:]; claudeAccounts = []; return }
        guard let script = claudeScript else { return }
        let integrations = makeIntegrations()
        let (outcomes, failures, configured) = await Task.detached(priority: .utility) {
            () -> ([String: ClaudeStatusLine.Outcome], [String], [ProviderConfig]) in
            let loaded = Self.loadProviders()
            var outcomes: [String: ClaudeStatusLine.Outcome] = [:]
            var failures: [String] = []
            for entry in ClaudeAccounts.entries(in: loaded.providers, integrations: integrations) {
                do { outcomes[entry.id] = try ClaudeStatusLine.setUp(script: script, account: entry.account) } catch {
                    failures.append("\(entry.id): \(error.localizedDescription)")
                }
            }
            return (outcomes, failures, loaded.providers)
        }.value
        for failure in failures { Self.log.error("Could not set up the Claude status line: \(failure, privacy: .public)") }
        claudeStatusLines = outcomes
        providers = configured
        claudeAccounts = ClaudeAccounts.entries(in: configured, integrations: integrations)
        detectProblems()
    }

    private func makeIntegrations() -> Integrations {
        Integrations([ClaudeIntegration(script: claudeScript, enabled: autoSetUpClaude), CodexIntegration()])
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
        let stamp = providersFileStamp
        Task(priority: .utility) {
            // A change by hand wins at the next detection (ADR 0014): the sources are built again from the file.
            let changed = await Task.detached(priority: .utility) { Self.providersFileStamp() != stamp }.value
            if changed { await reloadProviders(); return }
            let (found, configured, fileError, listed, folders) = await Task.detached(priority: .utility) {
                // A file that cannot be used falls back to the seed, as the collector does (ADR 0003), and says so (ADR 0005).
                let loaded = Self.loadProviders()
                // The folders of a tool at the top of the home, for the one nobody named (ADR 0014).
                let folders = AccountFolders.scan()
                let found = ProblemDetector.detect(
                    general: AppProblems.check(hasAppGroup: hasAppGroup), providers: loaded.providers,
                    integrations: integrations, context: ProblemContext(), folders: folders)
                return (found, loaded.providers, loaded.error, AccountSummary.list(loaded.providers, integrations: integrations), folders)
            }.value
            detected = found
            providers = configured
            accounts = listed
            foundFolders = folders
            providersFileError = fileError
            for (id, state) in fixStates where state == .done { fixStates[id] = nil }
            publish()
        }
    }

    /// The providers as the collector sees them: the file, or the seed where it is missing or cannot be used, with what is wrong.
    nonisolated private static func loadProviders() -> (providers: [ProviderConfig], error: String?) {
        do {
            return (try ProviderConfigFile.load()?.providers ?? ProviderConfigFile.seed().providers, nil)
        } catch {
            return (ProviderConfigFile.seed().providers, error.localizedDescription)
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
                await setUpClaudeStatusLine()
            case .failed(let reason):
                fixStates[problem.id] = .failed(reason)
            }
        }
    }

    // MARK: Accounts (ADR 0014)

    /// The folder a problem of the kind "a folder nobody named" is about, for Add it; nil for any other problem.
    func foundFolder(for problem: Problem) -> AccountFolders.Found? {
        guard problem.id.hasPrefix(AppProblems.folderNotNamed.id + ".") else { return nil }
        return foundFolders.first { AppProblems.folderNotNamed($0, userHome: FileManager.default.homeDirectoryForCurrentUser).id == problem.id }
    }

    /// What the sheet says about a folder the person typed or chose.
    enum FolderCheck: Equatable {
        /// Not a folder on disk.
        case missing
        /// A folder, but not one the tool left its files in: it may be new, or the wrong one.
        case notTheTools
        case found(email: String?)
    }

    /// Looks at the folder off the main actor: it reads the folder's files.
    func checkFolder(_ path: String, tool: AccountTool) async -> FolderCheck {
        let url = AccountFolders.folder(of: Self.tilde(path), tool: tool)
        return await Task.detached(priority: .userInitiated) {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                return .missing
            }
            guard AccountFolders.isFolder(url, of: tool) else { return .notTheTools }
            return .found(email: AccountFolders.email(in: url, tool: tool))
        }.value
    }

    /// Writes the entry of a new account: the tool's template, with an id made from the title. The error, or nil.
    func addAccount(tool: AccountTool, folder: String, title: String) async -> String? {
        let id = ProviderConfigFile.id(for: title, taken: Set(providers.map(\.id)))
        let entry = ProviderConfigFile.entry(for: tool, id: id, title: title, home: Self.tilde(folder))
        let error = await Task.detached(priority: .userInitiated) { () -> String? in
            do { try ProviderConfigFile.add(entry); return nil } catch { return "\(error)" }
        }.value
        if error == nil { await reloadProviders() }
        return error
    }

    /// Changes an entry's title and folder; its id stays, so its history, its order and its notices do. The error, or nil.
    func editAccount(_ id: String, title: String, folder: String?) async -> String? {
        let tool = accounts.first { $0.id == id }?.tool
        let home = folder.map(Self.tilde)
        let error = await Task.detached(priority: .userInitiated) { () -> String? in
            do {
                guard let data = try? Data(contentsOf: ProviderConfigFile.defaultURL),
                      let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                      let entry = (object["providers"] as? [[String: Any]])?.first(where: { $0["id"] as? String == id })
                else { return "providers.json could not be read." }
                var changed = entry
                if let tool, let home {
                    changed = ProviderConfigFile.edited(entry, tool: tool, title: title, home: home)
                } else {
                    changed["title"] = title
                }
                try ProviderConfigFile.replace(id, with: changed)
                return nil
            } catch { return "\(error)" }
        }.value
        if error == nil { await reloadProviders() }
        return error
    }

    /// Takes the entry out of the file, and nothing else: the preferences, the history and the folder stay. The error, or nil.
    func removeAccount(_ id: String) async -> String? {
        let error = await Task.detached(priority: .userInitiated) { () -> String? in
            do { try ProviderConfigFile.remove(id); return nil } catch { return "\(error)" }
        }.value
        if error == nil { await reloadProviders() }
        return error
    }

    /// The file was written: the sources are built again from it, the status lines set up, and a reading taken.
    private func reloadProviders() async {
        collector = await Task.detached(priority: .userInitiated) { Collector() }.value
        providersFileStamp = Self.providersFileStamp()
        await setUpClaudeStatusLine()
        await refresh()
    }

    /// `~/…` for a path under the home, so the file reads the same on another Mac; a path elsewhere as it is.
    nonisolated static func tilde(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if trimmed == home { return "~" }
        if trimmed.hasPrefix(home + "/") { return "~" + trimmed.dropFirst(home.count) }
        return trimmed
    }

    nonisolated private static func providersFileStamp() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: ProviderConfigFile.defaultURL.path))?[.modificationDate] as? Date
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
