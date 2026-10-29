import Foundation

/// A provider declared in `providers.json` instead of written in Swift (ADR 0016).
public final class ConfiguredSource: ProviderSource, @unchecked Sendable {
    public let info: ProviderInfo
    private let config: ProviderConfig

    private struct FileState {
        var offset: UInt64 = 0
        var previous = TokenCounts()
        var byKey: [String: UsageEvent] = [:]
        var anonymous: [UsageEvent] = []
        var quotas: [Int: (Date, ReportedQuota)] = [:]
        var plan: (Date, String)?
    }

    private let lock = NSLock()
    private var states: [URL: FileState] = [:]
    private let marker: Data

    public init(_ config: ProviderConfig) {
        self.config = config
        info = ProviderInfo(
            provider: Provider(rawValue: config.id), title: config.title,
            windows: config.windows.map { WindowSpec(name: Self.label(minutes: $0), duration: TimeInterval($0) * 60) },
            setupHint: config.setupHint)
        marker = Data((config.log?.contains ?? "{").utf8)
    }

    static func label(minutes: Int) -> String {
        if minutes % 1440 == 0 { return "\(minutes / 1440)d" }
        if minutes % 60 == 0 { return "\(minutes / 60)h" }
        return "\(minutes)m"
    }

    public func read(since: Date) -> ProviderReading {
        var reading = ProviderReading()
        var quotas: [Int: (Date, ReportedQuota)] = [:]
        var plan: (Date, String)?

        if let log = config.log {
            lock.lock()
            let logged = scan(log, since: since)
            lock.unlock()
            reading.events = logged.events
            quotas = logged.quotas
            plan = logged.plan
        }

        if let spec = config.quota {
            if let file = spec.file {
                let url = Self.expand(file)
                let observed = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
                reading.quotaUpdatedAt = observed
                if let root = Self.object(at: url) {
                    reading.quotas = spec.windows.compactMap { Self.quota($0, in: root, observedAt: observed) }
                }
            } else {
                reading.quotas = quotas.values.map(\.1).sorted { ($0.windowMinutes ?? 0) < ($1.windowMinutes ?? 0) }
                reading.quotaUpdatedAt = reading.quotas.compactMap(\.observedAt).max()
            }
        }

        if let spec = config.plan {
            if let file = spec.file {
                reading.plan = Self.object(at: Self.expand(file)).flatMap { Self.string(Self.value(spec.path, in: $0)) }
                    .map(PlanName.prettified)
            } else {
                reading.plan = plan.map { PlanName.prettified($0.1) }
            }
        }
        return reading
    }

    // MARK: Log scanning

    private func scan(_ log: ProviderConfig.Log, since: Date)
        -> (events: [UsageEvent], quotas: [Int: (Date, ReportedQuota)], plan: (Date, String)?) {
        let files = LogFiles.jsonl(under: Self.expand(log.root), modifiedSince: since)
        states = states.filter { files.contains($0.key) }

        var events: [UsageEvent] = []
        var quotas: [Int: (Date, ReportedQuota)] = [:]
        var plan: (Date, String)?
        for file in files {
            var state = states[file] ?? FileState()
            let (lines, next) = LogFiles.newLines(in: file, from: state.offset, containing: marker)
            if next < state.offset { state = FileState() }
            state.offset = next
            for data in lines {
                guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                      (log.where ?? [:]).allSatisfy({ Self.string(Self.value($0.key, in: root)) == $0.value }),
                      let stamp = Self.string(Self.value(log.timestamp, in: root)), let date = LogDate.parse(stamp)
                else { continue }
                if let usage = config.usage { record(usage, root, date, into: &state) }
                if let quota = config.quota, quota.file == nil {
                    for window in quota.windows {
                        guard let reported = Self.quota(window, in: root, observedAt: date),
                              let minutes = reported.windowMinutes,
                              state.quotas[minutes] == nil || date > state.quotas[minutes]!.0 else { continue }
                        state.quotas[minutes] = (date, reported)
                    }
                }
                if let spec = config.plan, spec.file == nil, let raw = Self.string(Self.value(spec.path, in: root)),
                   state.plan == nil || date > state.plan!.0 {
                    state.plan = (date, raw)
                }
            }
            state.byKey = state.byKey.filter { $0.value.date >= since }
            state.anonymous.removeAll { $0.date < since }
            states[file] = state
            events += state.byKey.values + state.anonymous
            if let candidate = state.plan, plan == nil || candidate.0 > plan!.0 { plan = candidate }
            for (minutes, candidate) in state.quotas where quotas[minutes] == nil || candidate.0 > quotas[minutes]!.0 {
                quotas[minutes] = candidate
            }
        }
        return (events.sorted { $0.date < $1.date }, quotas, plan)
    }

    private func record(_ usage: ProviderConfig.Usage, _ root: [String: Any], _ date: Date, into state: inout FileState) {
        func count(_ field: ProviderConfig.Field?) -> Int {
            guard let field else { return 0 }
            let value = Self.number(Self.value(field.path, in: root)) ?? 0
            return max(value - (field.minus.flatMap { Self.number(Self.value($0, in: root)) } ?? 0), 0)
        }
        let tokens = usage.tokens
        let current = TokenCounts(input: count(tokens.input), output: count(tokens.output),
                                  cacheRead: count(tokens.cacheRead), cacheWrite: count(tokens.cacheWrite))
        let provider = info.provider
        switch usage.mode {
        case .perEvent:
            let event = UsageEvent(provider: provider, date: date, tokens: current)
            // The paths a line has make its key; a line with none is never merged with another.
            let keys = (usage.dedupeBy ?? []).compactMap { path in
                Self.string(Self.value(path, in: root)).map { "\(path)=\($0)" }
            }
            if keys.isEmpty {
                state.anonymous.append(event)
            } else {
                state.byKey[keys.joined(separator: "\u{1f}")] = event
            }
        case .cumulative:
            let delta = TokenCounts(
                input: max(current.input - state.previous.input, 0), output: max(current.output - state.previous.output, 0),
                cacheRead: max(current.cacheRead - state.previous.cacheRead, 0),
                cacheWrite: max(current.cacheWrite - state.previous.cacheWrite, 0))
            state.previous = current
            if delta.total > 0 { state.anonymous.append(UsageEvent(provider: provider, date: date, tokens: delta)) }
        }
    }

    // MARK: Paths

    private static func quota(_ window: ProviderConfig.Quota.Window, in root: [String: Any],
                              observedAt: Date?) -> ReportedQuota? {
        let scope = window.at.map { value($0, in: root) as? [String: Any] } ?? root
        guard let scope, let used = (value(window.usedPercent, in: scope) as? NSNumber)?.doubleValue,
              used >= 0 else { return nil }
        let minutes = window.minutes ?? window.minutesPath.flatMap { number(value($0, in: scope)) }
        let resets = window.resetsAt.flatMap { value($0, in: scope) }.flatMap { raw -> Date? in
            if window.resetsAtFormat == .iso8601 { return string(raw).flatMap(LogDate.parse) }
            return (raw as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
        }
        return ReportedQuota(usedPercent: used, windowMinutes: minutes, resetsAt: resets, observedAt: observedAt)
    }

    static func value(_ path: String, in root: [String: Any]) -> Any? {
        var current: Any = root
        for key in path.split(separator: ".") {
            guard let next = (current as? [String: Any])?[String(key)] else { return nil }
            current = next
        }
        return current
    }

    private static func number(_ value: Any?) -> Int? { (value as? NSNumber).map { Int(truncating: $0) } }

    private static func string(_ value: Any?) -> String? {
        switch value {
        case let text as String: return text
        case let number as NSNumber: return number.stringValue
        default: return nil
        }
    }

    private static func object(at url: URL) -> [String: Any]? {
        (try? Data(contentsOf: url)).flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? [String: Any] }
    }

    static func expand(_ path: String) -> URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }
}
