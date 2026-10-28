import Foundation

/// Reads and writes the snapshot the host app hands to the widget.
public struct SnapshotStore: Sendable {
    public static let appGroup = "group.com.fmmenchi.tokenmeter"

    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// The App Group container location, or nil when the process has no App Group entitlement.
    public static func appGroupStore() -> SnapshotStore? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            .map { SnapshotStore(url: $0.appendingPathComponent("snapshot.json")) }
    }

    public func write(_ snapshot: Snapshot) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(snapshot).write(to: url, options: .atomic)
    }

    public func read() -> Snapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Snapshot.self, from: data)
    }
}
