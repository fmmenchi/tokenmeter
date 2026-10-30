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
    private var base: Snapshot?
    private let dismissals = DefaultsDismissals()
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

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let collector = collector
        detectProblemsIfDue()
        base = await Task.detached { collector.snapshot() }.value
        publish()
    }

    /// Puts the visible problems on the latest reading and gives it to the widget.
    private func publish() {
        guard let base else { return }
        problems = dismissals.visible(detected)
        let result = base.with(problems: problems)
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
