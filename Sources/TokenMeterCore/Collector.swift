import Foundation

/// Collects every provider into one snapshot. It names no provider (ADR 0015).
public struct Collector: Sendable {
    public var sources: [any ProviderSource]

    public init(sources: [any ProviderSource] = Providers.standard()) {
        self.sources = sources
    }

    public func snapshot(now: Date = Date()) -> Snapshot {
        let since = now.addingTimeInterval(-WindowSpec.week.duration)
        let providers = sources.map { source -> ProviderSnapshot in
            let reading = source.read(since: since)
            return SnapshotBuilder.providerSnapshot(
                provider: source.info.provider, title: source.info.title, events: reading.events,
                windows: source.info.windows, reported: reading.quotas, plan: reading.plan,
                quotaUpdatedAt: reading.quotaUpdatedAt, setupHint: source.info.setupHint, absent: reading.absent, now: now)
        }
        return Snapshot(generatedAt: now, providers: providers)
    }
}
