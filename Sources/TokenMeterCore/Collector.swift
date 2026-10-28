import Foundation

/// Collects both providers into one snapshot.
public struct Collector: Sendable {
    public var claude: ClaudeLogReader
    public var codex: CodexLogReader
    public var claudeQuota: ClaudeQuotaReader
    public var claudePlan: ClaudePlanReader

    public init(claude: ClaudeLogReader = ClaudeLogReader(), codex: CodexLogReader = CodexLogReader(),
                claudeQuota: ClaudeQuotaReader = ClaudeQuotaReader(),
                claudePlan: ClaudePlanReader = ClaudePlanReader()) {
        self.claude = claude
        self.codex = codex
        self.claudeQuota = claudeQuota
        self.claudePlan = claudePlan
    }

    public func snapshot(now: Date = Date()) -> Snapshot {
        let since = now.addingTimeInterval(-WindowSpec.week.duration)
        let codexResult = codex.read(since: since)
        let providers = [
            SnapshotBuilder.providerSnapshot(
                provider: .claude, events: claude.events(since: since),
                windows: [.session, .week], reported: claudeQuota.quotas(), plan: claudePlan.plan(), now: now),
            SnapshotBuilder.providerSnapshot(
                provider: .chatgpt, events: codexResult.events,
                windows: [.session, .week], reported: codexResult.latestQuotas,
                plan: PlanName.chatgpt(planType: codexResult.latestPlanType), now: now),
        ]
        return Snapshot(generatedAt: now, providers: providers, claudeQuotaUpdatedAt: claudeQuota.updatedAt())
    }
}
