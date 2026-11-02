import Foundation

/// Puts what the sources see into the usage store (ADR 0010).
///
/// It has sources of its own, not the snapshot's: the first pass reads every file the CLIs still keep, the next ones only what
/// is new, and neither shares state with the collector that draws the panel, so the panel never waits for the store. Everything
/// it writes is inserted under a unique key, so reading a file twice, or overlapping passes, change nothing.
public final class UsageIngestor: @unchecked Sendable {
    public struct Summary: Equatable, Sendable {
        public var messages = 0
        public var readings = 0
    }

    private let sources: [any ProviderSource]
    private let store: UsageStore
    private let lock = NSLock()
    private var firstPassDone = false
    /// After the first pass, how far back a pass looks. Overlap is harmless and covers a pass that was missed.
    private let overlap: TimeInterval

    public init(sources: [any ProviderSource] = Providers.standard(), store: UsageStore, overlap: TimeInterval = 2 * 86_400) {
        self.sources = sources
        self.store = store
        self.overlap = overlap
    }

    /// Reads what the sources have and stores it. Safe to call from any queue; calls are serialised.
    @discardableResult
    public func ingest(now: Date = Date()) -> Summary {
        lock.lock()
        defer { lock.unlock() }
        let since = firstPassDone ? now.addingTimeInterval(-overlap) : .distantPast
        var summary = Summary()
        for source in sources {
            let provider = source.info.provider
            let reading = source.read(since: since)

            let messages = reading.events.compactMap { event -> UsageStore.Message? in
                guard let key = event.key else { return nil }
                return UsageStore.Message(provider: provider, key: key, at: event.date, model: event.model, tokens: event.tokens)
            }
            summary.messages += store.insert(messages)

            // A window a log reported, with the first and last time it was seen; and the readings of the files the CLIs keep
            // (the status line, the usage copy), which say the same of the present.
            let logged = reading.history.map {
                UsageStore.Reading(provider: provider, windowMinutes: $0.windowMinutes, resetsAt: $0.resetsAt, usedPercent: $0.usedPercent,
                                   firstObserved: $0.firstObserved, lastObserved: $0.lastObserved, source: "log")
            }
            let live = reading.quotas.compactMap { quota -> UsageStore.Reading? in
                guard let minutes = quota.windowMinutes, let resets = quota.resetsAt else { return nil }
                return UsageStore.Reading(provider: provider, windowMinutes: minutes, scope: quota.scope, resetsAt: resets,
                                          usedPercent: quota.usedPercent, firstObserved: quota.observedAt,
                                          lastObserved: quota.observedAt, source: "live")
            }
            store.upsert(logged + live)
            summary.readings += logged.count + live.count
        }
        firstPassDone = true
        return summary
    }
}
