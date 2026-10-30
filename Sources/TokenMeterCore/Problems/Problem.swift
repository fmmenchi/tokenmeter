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
    /// The id of a fix its provider's integration declared; nil when there is nothing to run.
    public let fix: String?
    /// A docs path for Learn more.
    public let guide: String?

    public init(id: String, topic: Topic, message: String, detail: String? = nil,
                fix: String? = nil, guide: String? = nil) {
        self.id = id
        self.topic = topic
        self.message = message
        self.detail = detail
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
