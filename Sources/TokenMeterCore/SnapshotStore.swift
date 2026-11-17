import Foundation

/// Reads and writes the snapshot the host app hands to the widget.
public struct SnapshotStore: Sendable {
    /// The App Group id, put in the Info.plist at build time as `<TeamID>.tokenmeter` (ADR 0001);
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

    /// The copy the app keeps for the `tokenmeter` command, beside the usage store (ADR 0017): macOS lets no other process read an App
    /// Group container, so the command could not read the widget's copy.
    public static func commandStore(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> SnapshotStore {
        SnapshotStore(url: home.appendingPathComponent("Library/Application Support/TokenMeter/snapshot.json"))
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
