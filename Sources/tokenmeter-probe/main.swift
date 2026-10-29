import Foundation
import TokenMeterCore

do { _ = try ProviderConfigFile.load() } catch { print("providers.json ignored: \(error)") }
let snapshot = Collector().snapshot()
for p in snapshot.providers {
    print(p.title + (p.plan.map { " (\($0))" } ?? ""))
    for w in p.windows {
        let remaining = w.remainingFraction.map { String(format: "%.0f%% left", $0 * 100) } ?? "quota unknown"
        print("  \(w.window.name): \(w.tokens.total) tokens "
            + "(in \(w.tokens.input), out \(w.tokens.output), cache r/w \(w.tokens.cacheRead)/\(w.tokens.cacheWrite)) "
            + "— \(remaining) [\(w.source.rawValue)]")
    }
    if p.quotaUpdatedAt == nil, let hint = p.setupHint { print("  \(hint)") }
}
