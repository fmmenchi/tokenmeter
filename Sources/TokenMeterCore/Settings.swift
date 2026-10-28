import Foundation

/// User-set token budgets for the windows whose plan limit no provider publishes (ADR 0002).
public struct LimitSettings: Equatable, Sendable {
    public var claudeSession: Int?
    public var claudeWeek: Int?
    public var chatgptSession: Int?
    public var chatgptWeek: Int?

    public init(claudeSession: Int? = nil, claudeWeek: Int? = nil,
                chatgptSession: Int? = nil, chatgptWeek: Int? = nil) {
        self.claudeSession = claudeSession
        self.claudeWeek = claudeWeek
        self.chatgptSession = chatgptSession
        self.chatgptWeek = chatgptWeek
    }

    public func windows(for provider: Provider) -> [WindowSpec] {
        let (session, week) = provider == .claude ? (claudeSession, claudeWeek) : (chatgptSession, chatgptWeek)
        return [
            WindowSpec(name: WindowSpec.session.name, duration: WindowSpec.session.duration, tokenLimit: session),
            WindowSpec(name: WindowSpec.week.name, duration: WindowSpec.week.duration, tokenLimit: week),
        ]
    }
}

/// Collects both providers into one snapshot.
public struct Collector: Sendable {
    public var claude: ClaudeLogReader
    public var codex: CodexLogReader
    public var claudeQuota: ClaudeQuotaReader

    public init(claude: ClaudeLogReader = ClaudeLogReader(), codex: CodexLogReader = CodexLogReader(),
                claudeQuota: ClaudeQuotaReader = ClaudeQuotaReader()) {
        self.claude = claude
        self.codex = codex
        self.claudeQuota = claudeQuota
    }

    public func snapshot(limits: LimitSettings, now: Date = Date()) -> Snapshot {
        let since = now.addingTimeInterval(-WindowSpec.week.duration)
        let codexResult = codex.read(since: since)
        return Snapshot(generatedAt: now, providers: [
            SnapshotBuilder.providerSnapshot(
                provider: .claude, events: claude.events(since: since),
                windows: limits.windows(for: .claude), reported: claudeQuota.quotas(now: now), now: now),
            SnapshotBuilder.providerSnapshot(
                provider: .chatgpt, events: codexResult.events,
                windows: limits.windows(for: .chatgpt), reported: codexResult.latestQuotas, now: now),
        ])
    }
}
