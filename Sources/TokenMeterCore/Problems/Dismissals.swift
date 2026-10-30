import Foundation

/// What the person hid. A problem stays hidden until its message changes (ADR 0030).
public protocol Dismissals: Sendable {
    func isHidden(_ problem: Problem) -> Bool
    func hide(_ problem: Problem)
}

extension Dismissals {
    public func visible(_ problems: [Problem]) -> [Problem] { problems.filter { !isHidden($0) } }
}

/// Kept in memory; for tests.
public final class MemoryDismissals: Dismissals, @unchecked Sendable {
    private let lock = NSLock()
    private var messages: [String: String] = [:]

    public init() {}

    public func isHidden(_ problem: Problem) -> Bool {
        lock.withLock { messages[problem.id] == problem.message }
    }

    public func hide(_ problem: Problem) {
        lock.withLock { messages[problem.id] = problem.message }
    }
}

/// Kept in the app's defaults, as problem id to the message that was hidden.
public final class DefaultsDismissals: Dismissals, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard, key: String = "dismissedProblems") {
        self.defaults = defaults
        self.key = key
    }

    public func isHidden(_ problem: Problem) -> Bool {
        lock.withLock { (defaults.dictionary(forKey: key) as? [String: String])?[problem.id] == problem.message }
    }

    public func hide(_ problem: Problem) {
        lock.withLock {
            var messages = defaults.dictionary(forKey: key) as? [String: String] ?? [:]
            messages[problem.id] = problem.message
            defaults.set(messages, forKey: key)
        }
    }
}
