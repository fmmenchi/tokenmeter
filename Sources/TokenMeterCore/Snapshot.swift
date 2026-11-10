import Foundation

public struct WindowSpec: Codable, Equatable, Sendable {
    public let name: String
    public let duration: TimeInterval
    /// What the window applies to when it is not the provider as a whole: a model's name, from the data (ADR 0002). A
    /// scoped window is a part of the unscoped window of the same name.
    public let scope: String?

    public init(name: String, duration: TimeInterval, scope: String? = nil) {
        self.name = name
        self.duration = duration
        self.scope = scope
    }

    /// Unique among a provider's windows: the name, and the scope after a colon for a scoped one. Preferences use it.
    public var id: String { scope.map { "\(name):\($0)" } ?? name }

    public static let session = WindowSpec(name: "5h", duration: 5 * 3600)
    public static let week = WindowSpec(name: "7d", duration: 7 * 24 * 3600)
}

public struct WindowUsage: Codable, Equatable, Sendable {
    public enum Source: String, Codable, Sendable {
        /// Percentage reported by the provider in its own logs.
        case reported
        /// The last reported window has expired and nothing was used since: it is full again.
        /// Inferred, not reported (ADR 0002).
        case reset
        /// Consumption only; no remaining quota can be stated.
        case consumptionOnly
    }

    public let window: WindowSpec
    public let tokens: TokenCounts
    /// 0...1 when known.
    public let remainingFraction: Double?
    public let source: Source
    public let resetsAt: Date?
    /// When the provider last reported the figure behind `remainingFraction`; nil if not reported.
    public let observedAt: Date?

    public init(window: WindowSpec, tokens: TokenCounts, remainingFraction: Double?, source: Source,
                resetsAt: Date?, observedAt: Date?) {
        self.window = window
        self.tokens = tokens
        self.remainingFraction = remainingFraction
        self.source = source
        self.resetsAt = resetsAt
        self.observedAt = observedAt
    }

    /// The window as it reads at `now`. A reported figure whose reset time has passed reads as reset,
    /// except an exhausted reading, which remains the last known quota until a replacement arrives (ADR 0002/0008).
    public func resolved(at now: Date) -> WindowUsage {
        guard source == .reported, let resetsAt, resetsAt <= now else { return self }
        // An exhausted reading remains the last known quota until the provider reports a replacement.
        if remainingFraction == 0 { return self }
        return WindowUsage(window: window, tokens: tokens, remainingFraction: 1, source: .reset,
                           resetsAt: nil, observedAt: nil)
    }
}

public struct ProviderSnapshot: Codable, Equatable, Sendable {
    public let provider: Provider
    /// Display name; falls back to the provider id for a snapshot written before it existed.
    public let title: String
    public let windows: [WindowUsage]
    /// Subscription label such as "Max 20x"; nil when the CLI recorded none (ADR 0007).
    public let plan: String?
    /// When the provider's quota was last written; nil if it never was.
    public let quotaUpdatedAt: Date?
    /// Shown while no quota has been seen; nil when the provider has nothing to set up (ADR 0003).
    public let setupHint: String?

    public init(provider: Provider, title: String? = nil, windows: [WindowUsage], plan: String? = nil,
                quotaUpdatedAt: Date? = nil, setupHint: String? = nil) {
        self.provider = provider
        self.title = title ?? provider.rawValue
        self.windows = windows
        self.plan = plan
        self.quotaUpdatedAt = quotaUpdatedAt
        self.setupHint = setupHint
    }

    /// The window as it reads at `now`, in the context of this provider. A limit for one model is part of the window of the same
    /// length: when that window has moved on to a later reset, by at least half its length, the limit ended with it and reads as
    /// reset, even when it was exhausted and nothing has replaced it, because the quota that renewed it is a fact the app has and
    /// the clock is not. Anything else reads as `WindowUsage.resolved(at:)` says.
    public func resolved(_ window: WindowUsage, at now: Date) -> WindowUsage {
        guard window.window.scope != nil, window.source == .reported, let resetsAt = window.resetsAt,
              let parent = windows.first(where: { $0.window.scope == nil && $0.window.name == window.window.name }),
              parent.source == .reported, let parentResetsAt = parent.resetsAt,
              parentResetsAt.timeIntervalSince(resetsAt) >= window.window.duration / 2 else { return window.resolved(at: now) }
        return WindowUsage(window: window.window, tokens: window.tokens, remainingFraction: 1, source: .reset,
                           resetsAt: nil, observedAt: nil)
    }

    private enum CodingKeys: String, CodingKey {
        case provider, title, windows, plan, quotaUpdatedAt, setupHint
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let provider = try c.decode(Provider.self, forKey: .provider)
        self.init(provider: provider, title: try c.decodeIfPresent(String.self, forKey: .title),
                  windows: try c.decode([WindowUsage].self, forKey: .windows),
                  plan: try c.decodeIfPresent(String.self, forKey: .plan),
                  quotaUpdatedAt: try c.decodeIfPresent(Date.self, forKey: .quotaUpdatedAt),
                  setupHint: try c.decodeIfPresent(String.self, forKey: .setupHint))
    }
}

public struct Snapshot: Codable, Equatable, Sendable {
    public let generatedAt: Date
    public let providers: [ProviderSnapshot]
    /// What the person should know about, visible ones only; written by the app, not the collector (ADR 0005).
    public let problems: [Problem]
    /// The look the person chose, written by the app so the widget, which reads only this, draws the same (ADR 0013). A snapshot
    /// from before the skins, or with a skin this version does not know, is `.system`.
    public let skin: Skin
    /// How the bars read, chosen in Settings and written by the app like the skin (ADR 0006). A snapshot from before it, or with
    /// a value this version does not know, is `.left`.
    public let barsDisplay: BarsDisplay

    public init(generatedAt: Date, providers: [ProviderSnapshot], problems: [Problem] = [], skin: Skin = .system,
                barsDisplay: BarsDisplay = .left) {
        self.generatedAt = generatedAt
        self.providers = providers
        self.problems = problems
        self.skin = skin
        self.barsDisplay = barsDisplay
    }

    private enum CodingKeys: String, CodingKey { case generatedAt, providers, problems, skin, barsDisplay }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(generatedAt: try c.decode(Date.self, forKey: .generatedAt),
                  providers: try c.decode([ProviderSnapshot].self, forKey: .providers),
                  problems: try c.decodeIfPresent([Problem].self, forKey: .problems) ?? [],
                  skin: (try c.decodeIfPresent(String.self, forKey: .skin)).flatMap(Skin.init(rawValue:)) ?? .system,
                  barsDisplay: (try c.decodeIfPresent(String.self, forKey: .barsDisplay)).flatMap(BarsDisplay.init(rawValue:)) ?? .left)
    }

    public func with(problems: [Problem]) -> Snapshot {
        Snapshot(generatedAt: generatedAt, providers: providers, problems: problems, skin: skin, barsDisplay: barsDisplay)
    }

    public func with(skin: Skin) -> Snapshot {
        Snapshot(generatedAt: generatedAt, providers: providers, problems: problems, skin: skin, barsDisplay: barsDisplay)
    }

    public func with(barsDisplay: BarsDisplay) -> Snapshot {
        Snapshot(generatedAt: generatedAt, providers: providers, problems: problems, skin: skin, barsDisplay: barsDisplay)
    }
}

extension Snapshot {
    /// The snapshot as the person wants to see it: providers in their order, hidden ones left out, and for each only the
    /// windows they chose (ADR 0006). A provider whose choice matches none of its windows shows them all, and one
    /// provider always stays: if every provider is hidden, the first in order is shown.
    public func applying(_ preferences: any DisplayPreferences) -> Snapshot {
        let order = preferences.ordered(providers.map(\.provider.rawValue))
        let hidden = preferences.hidden
        let kept = order.filter { !hidden.contains($0) }
        let shownIDs = kept.isEmpty ? Array(order.prefix(1)) : kept
        let shown = shownIDs.compactMap { id in providers.first { $0.provider.rawValue == id } }.map { provider -> ProviderSnapshot in
            let id = provider.provider.rawValue
            let chosen = preferences.windows(for: id)
            let offModels = preferences.hiddenModels(for: id)
            // The provider's own windows follow the choice (all when none, or when it names none of them). A model's window
            // is a part of the one of the same name: it shows with it, on by default, unless it was turned off (ADR 0002).
            let own = provider.windows.filter { $0.window.scope == nil }
            let ownKept = chosen.map { set in own.filter { set.contains($0.window.id) } }.flatMap { $0.isEmpty ? nil : $0 } ?? own
            let names = Set(ownKept.map(\.window.name))
            let windows = provider.windows.filter { usage in
                usage.window.scope == nil
                    ? ownKept.contains { $0.window.id == usage.window.id }
                    : names.contains(usage.window.name) && !offModels.contains(usage.window.id)
            }
            return ProviderSnapshot(provider: provider.provider, title: provider.title, windows: windows,
                                    plan: provider.plan, quotaUpdatedAt: provider.quotaUpdatedAt,
                                    setupHint: provider.setupHint)
        }
        return Snapshot(generatedAt: generatedAt, providers: shown, problems: problems, skin: skin, barsDisplay: barsDisplay)
    }
}

public enum SnapshotBuilder {
    public static func providerSnapshot(
        provider: Provider,
        title: String? = nil,
        events: [UsageEvent],
        windows: [WindowSpec],
        reported: [ReportedQuota] = [],
        plan: String? = nil,
        quotaUpdatedAt: Date? = nil,
        setupHint: String? = nil,
        absent: Set<Int> = [],
        now: Date = Date()
    ) -> ProviderSnapshot {
        // A window the plan does not have is not drawn, and neither are the models that were part of it (ADR 0002).
        let gone = windows.filter { spec in absent.contains { abs(Double($0) * 60 - spec.duration) < 60 } }
        let windows = windows.filter { spec in !gone.contains(spec) }
        let usages = windows.map { spec -> WindowUsage in
            let rolling = now.addingTimeInterval(-spec.duration)
            func counted(since start: Date) -> TokenCounts {
                events.lazy.filter { $0.date >= start && $0.date <= now }.reduce(TokenCounts()) { $0 + $1.tokens }
            }
            let tokens = counted(since: rolling)

            if let reported = reported.first(where: { quota in
                guard quota.scope == nil, let minutes = quota.windowMinutes, abs(Double(minutes) * 60 - spec.duration) < 60 else { return false }
                return quota.resetsAt.map { $0 > now || quota.usedPercent >= 100 } ?? true
            }) {
                // A window whose reset time is known counts its tokens in its own period, the one its percentage is about
                // (ADR 0002), and not in the last `duration`, which differs once the provider moves the boundary.
                let own = reported.resetsAt.map { max($0.addingTimeInterval(-spec.duration), rolling) }
                return WindowUsage(window: spec, tokens: own.map { counted(since: $0) } ?? tokens,
                                   remainingFraction: max(0, 1 - reported.usedPercent / 100),
                                   source: .reported, resetsAt: reported.resetsAt, observedAt: reported.observedAt)
            }
            if tokens.total == 0, reported.contains(where: {
                guard $0.scope == nil, let minutes = $0.windowMinutes, abs(Double(minutes) * 60 - spec.duration) < 60 else { return false }
                return $0.resetsAt.map { $0 <= now } ?? false
            }) {
                return WindowUsage(window: spec, tokens: tokens, remainingFraction: 1,
                                   source: .reset, resetsAt: nil, observedAt: nil)
            }
            return WindowUsage(window: spec, tokens: tokens, remainingFraction: nil,
                               source: .consumptionOnly, resetsAt: nil, observedAt: nil)
        }
        // A model's limit is a window of its own, a part of the one with the same length (ADR 0002). It has no token count.
        let scoped = reported.compactMap { quota -> WindowUsage? in
            guard let scope = quota.scope, let minutes = quota.windowMinutes,
                  let parent = windows.first(where: { abs(Double(minutes) * 60 - $0.duration) < 60 }) else { return nil }
            return WindowUsage(window: WindowSpec(name: parent.name, duration: parent.duration, scope: scope),
                               tokens: TokenCounts(), remainingFraction: max(0, 1 - quota.usedPercent / 100),
                               source: .reported, resetsAt: quota.resetsAt, observedAt: quota.observedAt)
        }
        return ProviderSnapshot(provider: provider, title: title, windows: usages + scoped, plan: plan,
                                quotaUpdatedAt: quotaUpdatedAt, setupHint: setupHint)
    }
}
