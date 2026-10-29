import Foundation

/// Reads and writes the snapshot the host app hands to the widget.
public struct SnapshotStore: Sendable {
    /// The App Group id, put in the Info.plist at build time as `<TeamID>.tokenmeter` (ADR 0023);
    /// nil in a process that has none (the probe, the tests).
    public static var appGroup: String? {
        Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
    }

    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// The App Group container location, or nil when the process has no App Group entitlement.
    public static func appGroupStore() -> SnapshotStore? {
        guard let appGroup else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
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
