import Foundation

/// The three notices of ADR 0012, in the order of their urgency: the first that is due for a window is the one posted.
public enum NoticeKind: String, CaseIterable, Codable, Sendable {
    /// Under 10% of the window is left.
    case almostOut
    /// The pace says the quota does not last until the reset.
    case willRunOut
    /// Under 30% of the window is left.
    case runningLow
    /// The weekly window still has most of its quota with under two days to go: the rest of the week would be wasted.
    case plentyLeft
}

/// One notice that is due: what it is about, and the identifier under which it is told once.
public struct LimitNotice: Equatable, Sendable {
    public let id: String
    public let kind: NoticeKind
    public let providerTitle: String
    /// The window as it reads at the moment of the evaluation.
    public let window: WindowUsage

    public init(id: String, kind: NoticeKind, providerTitle: String, window: WindowUsage) {
        self.id = id
        self.kind = kind
        self.providerTitle = providerTitle
        self.window = window
    }
}

/// What was already told, each with the moment its window resets (ADR 0012). A window that resets has a new moment and so new
/// identifiers; an entry is dropped a day after its reset, so the ledger does not grow.
public struct NoticeLedger: Codable, Equatable, Sendable {
    public private(set) var told: [String: Date]

    public init(told: [String: Date] = [:]) {
        self.told = told
    }

    /// How long after its reset an entry is kept.
    public static let keepAfterReset: TimeInterval = 24 * 3600

    public func contains(_ id: String) -> Bool { told[id] != nil }

    public mutating func record(_ id: String, resetsAt: Date) {
        told[id] = resetsAt
    }

    public mutating func prune(now: Date) {
        told = told.filter { $0.value.addingTimeInterval(Self.keepAfterReset) > now }
    }
}

/// Which notices are due, as a function of the snapshot and of what was already told (ADR 0012). It reads no clock and touches no
/// framework: the caller gives it `now` and keeps the ledger it returns.
public enum LimitNotices {
    /// Under this share left, a window is almost out.
    public static let almostOutBelow = 0.10
    /// Under this share left, a window is running low.
    public static let runningLowBelow = 0.30
    /// At or above this share left near its reset, a weekly window is mostly unused.
    public static let plentyLeftAtLeast = 0.50
    /// How close to its reset a weekly window must be for its quota left to count as unused.
    public static let plentyLeftWithin: TimeInterval = 2 * 86_400

    public struct Outcome: Equatable, Sendable {
        public let notices: [LimitNotice]
        public let ledger: NoticeLedger
    }

    /// `snapshot` is the one the app draws, so it holds only what the person chose to show. A window counts only with a reported
    /// figure that is recent and a reset still ahead; an inferred, old or quota-less figure notifies nothing. For each window only the
    /// most urgent kind that is on and due and not yet told is posted; the others due at that moment are written as told, and a kind
    /// that is off is never written.
    public static func evaluate(snapshot: Snapshot, enabled: Set<NoticeKind>, ledger: NoticeLedger, now: Date) -> Outcome {
        var ledger = ledger
        ledger.prune(now: now)
        guard !enabled.isEmpty else { return Outcome(notices: [], ledger: ledger) }
        var notices: [LimitNotice] = []
        for provider in snapshot.providers {
            for original in provider.windows {
                let window = provider.resolved(original, at: now)
                guard let resetsAt = window.resetsAt, let due = dueKinds(of: window, at: now) else { continue }
                let fresh = NoticeKind.allCases.filter { due.contains($0) && enabled.contains($0) }
                    .map { (kind: $0, id: identifier(provider.provider, window, resetsAt, $0)) }
                    .filter { !ledger.contains($0.id) }
                guard let first = fresh.first else { continue }
                notices.append(LimitNotice(id: first.id, kind: first.kind, providerTitle: provider.title, window: window))
                for item in fresh { ledger.record(item.id, resetsAt: resetsAt) }
            }
        }
        return Outcome(notices: notices, ledger: ledger)
    }

    /// The kinds that hold for the window now, or nil when it cannot notify at all.
    private static func dueKinds(of window: WindowUsage, at now: Date) -> Set<NoticeKind>? {
        guard window.source == .reported, let left = window.remainingFraction, let resetsAt = window.resetsAt, resetsAt > now,
              let observedAt = window.observedAt, now.timeIntervalSince(observedAt) <= WindowUsage.staleAfter else { return nil }
        var due: Set<NoticeKind> = []
        if left < almostOutBelow { due.insert(.almostOut) }
        if left < runningLowBelow { due.insert(.runningLow) }
        if let pace = window.pace(at: now), !pace.isStale, pace.runsOut { due.insert(.willRunOut) }
        if window.hasPlentyLeftNearReset(at: now) { due.insert(.plentyLeft) }
        return due
    }

    private static func identifier(_ provider: Provider, _ window: WindowUsage, _ resetsAt: Date, _ kind: NoticeKind) -> String {
        "\(provider.rawValue)|\(window.window.id)|\(Int(resetsAt.timeIntervalSince1970))|\(kind.rawValue)"
    }
}

extension WindowUsage {
    /// The weekly window, with a recent reported figure, has half its quota or more left and under two days before its reset. The panel
    /// says so on the bar, and the notice `plentyLeft` tells it once. A model's limit and the 5 hours never count: the 5 hours reset
    /// too often for it to matter.
    public func hasPlentyLeftNearReset(at now: Date) -> Bool {
        guard window.scope == nil, window.name == WindowSpec.week.name, source == .reported, let left = remainingFraction,
              let resetsAt, resetsAt > now, let observedAt, now.timeIntervalSince(observedAt) <= WindowUsage.staleAfter else { return false }
        return left >= LimitNotices.plentyLeftAtLeast && resetsAt.timeIntervalSince(now) < LimitNotices.plentyLeftWithin
    }
}
