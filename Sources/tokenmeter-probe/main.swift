import Foundation
import TokenMeterCore

let now = Date()
let since = now.addingTimeInterval(-WindowSpec.week.duration)
let windows: [WindowSpec] = [.session, .week]

func line(_ p: ProviderSnapshot) {
    print(p.provider.rawValue)
    for w in p.windows {
        let remaining = w.remainingFraction.map { String(format: "%.0f%% left", $0 * 100) } ?? "quota unknown"
        print("  \(w.window.name): \(w.tokens.total) tokens "
            + "(in \(w.tokens.input), out \(w.tokens.output), cache r/w \(w.tokens.cacheRead)/\(w.tokens.cacheWrite)) "
            + "— \(remaining) [\(w.source.rawValue)]")
    }
}

let claude = ClaudeLogReader().events(since: since)
line(SnapshotBuilder.providerSnapshot(provider: .claude, events: claude, windows: windows, reported: ClaudeQuotaReader().quotas(), now: now))

let codex = CodexLogReader().read(since: since)
line(SnapshotBuilder.providerSnapshot(provider: .chatgpt, events: codex.events, windows: windows,
                                      reported: codex.latestQuotas, now: now))
print("codex reported quotas:", codex.latestQuotas.map { "\($0.windowMinutes ?? 0)m \($0.usedPercent)% used" })
