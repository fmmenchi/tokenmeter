import Foundation

/// Puts the problems of every source in one list (ADR 0031). It reads nothing itself: each source hands over what it found.
public enum ProblemDetector {
    /// `general` problems first, then each provider's in the order given (the order of `providers.json`).
    /// A repeated `id` keeps its first occurrence.
    public static func merge(general: [Problem], providers: [[Problem]]) -> [Problem] {
        var seen = Set<String>()
        return (general + providers.flatMap { $0 }).filter { seen.insert($0.id).inserted }
    }
}
