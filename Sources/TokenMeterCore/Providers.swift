import Foundation

/// Claude Code: usage from its logs, quota from the status line, plan from `~/.claude.json`.
public struct ClaudeSource: ProviderSource {
    public let info = ProviderInfo(
        provider: .claude, title: "Claude", windows: [.session, .week],
        setupHint: "Claude quota: status line has not run yet")
    private let logs: ClaudeLogReader
    private let quota: ClaudeQuotaReader
    private let plan: ClaudePlanReader

    public init(logs: ClaudeLogReader = ClaudeLogReader(), quota: ClaudeQuotaReader = ClaudeQuotaReader(),
                plan: ClaudePlanReader = ClaudePlanReader()) {
        self.logs = logs
        self.quota = quota
        self.plan = plan
    }

    public func read(since: Date) -> ProviderReading {
        ProviderReading(events: logs.events(since: since), quotas: quota.quotas(), plan: plan.plan(),
                        quotaUpdatedAt: quota.updatedAt())
    }
}

/// Codex CLI, the ChatGPT-plan side: everything comes from its rollouts.
public struct CodexSource: ProviderSource {
    public let info = ProviderInfo(provider: .chatgpt, title: "ChatGPT", windows: [.session, .week])
    private let logs: CodexLogReader

    public init(logs: CodexLogReader = CodexLogReader()) {
        self.logs = logs
    }

    public func read(since: Date) -> ProviderReading {
        let result = logs.read(since: since)
        return ProviderReading(events: result.events, quotas: result.latestQuotas,
                               plan: PlanName.chatgpt(planType: result.latestPlanType),
                               quotaUpdatedAt: result.latestQuotas.compactMap(\.observedAt).max())
    }
}

/// The one list of providers. Adding one is a `ProviderSource` and a line here (ADR 0015).
public enum Providers {
    /// Fresh sources each call: the log readers keep per-file state.
    public static func standard() -> [any ProviderSource] {
        [ClaudeSource(), CodexSource()]
    }
}
