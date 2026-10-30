import Foundation

/// Something the person should know about, and sometimes can fix from the panel (ADR 0030).
public struct Problem: Codable, Equatable, Sendable, Identifiable {
    /// A provider id, or `general` for what concerns the app itself.
    public typealias Topic = String

    public static let general: Topic = "general"

    /// Stable from one check to the next, written `<topic>.<check>[.<detail>]`; Dismiss is keyed by it.
    public let id: String
    public let topic: Topic
    public let message: String
    public let detail: String?
    /// What is wrong and what to do, for Learn more; nil falls back to a generic line in the interface.
    public let explanation: String?
    /// The id of a fix its provider's integration declared; nil when there is nothing to run.
    public let fix: String?
    /// A docs path for Learn more.
    public let guide: String?

    public init(id: String, topic: Topic, message: String, detail: String? = nil, explanation: String? = nil,
                fix: String? = nil, guide: String? = nil) {
        self.id = id
        self.topic = topic
        self.message = message
        self.detail = detail
        self.explanation = explanation
        self.fix = fix
        self.guide = guide
    }
}

/// What an integration says about one of its fixes: the interface draws these and knows nothing else about them (ADR 0031).
public struct FixDescriptor: Equatable, Sendable {
    public let id: String
    /// The button, e.g. "Wrap it".
    public let label: String
    /// The button while it runs, e.g. "Wrapping…".
    public let runningLabel: String
    /// The technical text of Learn more.
    public let explanation: String

    public init(id: String, label: String, runningLabel: String, explanation: String) {
        self.id = id
        self.label = label
        self.runningLabel = runningLabel
        self.explanation = explanation
    }
}

/// A kind of problem the app knows about: the census (ADR 0030). A check only decides whether a kind applies and what its
/// message says this time; the topic, the explanation, the guide and the fix belong to the kind.
public struct ProblemKind: Equatable, Sendable {
    /// `<topic>.<check>`; a problem of this kind has this id, or this id and `.<detail>`.
    public let id: String
    public let topic: Problem.Topic
    /// One line saying what the kind is, for the list in the docs.
    public let summary: String
    /// What is wrong and what to do about it, for Learn more.
    public let explanation: String
    public let guide: String?
    /// The id of the fix an integration declares for this kind; nil when there is none.
    public let fix: String?

    public init(id: String, topic: Problem.Topic, summary: String, explanation: String,
                guide: String? = nil, fix: String? = nil) {
        self.id = id
        self.topic = topic
        self.summary = summary
        self.explanation = explanation
        self.guide = guide
        self.fix = fix
    }

    /// A problem of this kind. `message` defaults to the summary; `withFix: false` when the fix cannot apply this time.
    public func problem(message: String? = nil, detail: String? = nil, detailID: String? = nil,
                        withFix: Bool = true) -> Problem {
        Problem(id: detailID.map { "\(id).\($0)" } ?? id, topic: topic, message: message ?? summary, detail: detail,
                explanation: explanation, fix: withFix ? fix : nil, guide: guide)
    }
}
