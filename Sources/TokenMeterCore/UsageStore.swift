import Foundation
import SQLite3

/// The facts the app has seen, kept in one small SQLite file (ADR 0010).
///
/// A fact is something measured or counted: a *message* with its tokens and, when the source says it, its model, or a *reading*
/// of a window's percentage. Nothing derived and nothing estimated is stored. Both kinds are inserted under a unique key and
/// ignored when present, so reading the same file twice changes nothing; a reading keeps the highest percentage, because a
/// window's percentage does not go down.
///
/// One object serialises its calls, so a writer on a background queue and the panel reading do not meet.
public final class UsageStore: @unchecked Sendable {
    public static let schemaVersion = 3
    /// Two readings of the same window can name a reset time that differs by a second or two, and a rounding to the minute
    /// splits them when they fall either side of a boundary: those within this many seconds are one window. Different windows
    /// of one length are at least five hours apart.
    static let sameWindowWithin: Int64 = 120

    public struct Message: Equatable, Sendable {
        public let provider: Provider
        /// Unique for the provider: reading the same line again is the same message.
        public let key: String
        public let at: Date
        public let model: String?
        public let tokens: TokenCounts

        public init(provider: Provider, key: String, at: Date, model: String?, tokens: TokenCounts) {
            self.provider = provider
            self.key = key
            self.at = at
            self.model = model
            self.tokens = tokens
        }
    }

    /// The highest percentage seen in one window of one provider, from when it was first to when it was last seen.
    public struct Reading: Equatable, Sendable {
        public let provider: Provider
        public let windowMinutes: Int
        /// What the limit applies to when it is not the provider's own, such as a model.
        public let scope: String?
        public let resetsAt: Date
        public let usedPercent: Double
        public let firstObserved: Date?
        public let lastObserved: Date?
        /// Where it came from, for example `log` or `live`. Not part of what makes a reading the same reading.
        public let source: String

        public init(provider: Provider, windowMinutes: Int, scope: String? = nil, resetsAt: Date, usedPercent: Double,
                    firstObserved: Date? = nil, lastObserved: Date? = nil, source: String) {
            self.provider = provider
            self.windowMinutes = windowMinutes
            self.scope = scope
            self.resetsAt = resetsAt
            self.usedPercent = usedPercent
            self.firstObserved = firstObserved
            self.lastObserved = lastObserved
            self.source = source
        }
    }

    public struct ModelTotal: Equatable, Sendable {
        public let model: String?
        public let input: Int
        public let output: Int
        public let messages: Int
    }

    public struct Failure: Error, Equatable, CustomStringConvertible {
        public let description: String

        public init(description: String) {
            self.description = description
        }
    }

    public let url: URL
    private var db: OpaquePointer?
    private let lock = NSLock()
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    /// Opens the file, making it and its folder when they are missing. A file that cannot be read is made again empty:
    /// the app, the snapshot and the widget do not depend on it. A file written by a newer version is left alone and refused.
    public init(url: URL) throws {
        self.url = url
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            try open()
        } catch let failure as Failure where failure.description.hasPrefix("newer") {
            throw failure
        } catch {
            close()
            for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: url.path + suffix) }
            try open()
        }
    }

    deinit { close() }

    private func close() {
        if let db { sqlite3_close(db) }
        db = nil
    }

    private func open() throws {
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK
        else { throw Failure(description: "open: \(message)") }
        sqlite3_busy_timeout(db, 5000)
        try exec("PRAGMA journal_mode=WAL")
        try exec("PRAGMA synchronous=NORMAL")
        // A file that is not a database fails on the first real statement.
        let version = try scalarInt("PRAGMA user_version")
        if version > Self.schemaVersion { throw Failure(description: "newer schema \(version)") }
        if version == 1 { mergeNearbyReadings() }
        if version == 0 {
            try exec("""
                CREATE TABLE IF NOT EXISTS messages(
                  provider TEXT NOT NULL, key TEXT NOT NULL, at REAL NOT NULL, model TEXT,
                  input INTEGER NOT NULL, output INTEGER NOT NULL, cache_read INTEGER NOT NULL, cache_write INTEGER NOT NULL,
                  PRIMARY KEY(provider, key)) WITHOUT ROWID;
                CREATE INDEX IF NOT EXISTS messages_by_time ON messages(provider, at);
                CREATE TABLE IF NOT EXISTS readings(
                  provider TEXT NOT NULL, window_minutes INTEGER NOT NULL, scope TEXT NOT NULL, resets_at INTEGER NOT NULL,
                  used_percent REAL NOT NULL, first_observed REAL, last_observed REAL, source TEXT NOT NULL,
                  PRIMARY KEY(provider, window_minutes, scope, resets_at)) WITHOUT ROWID;
                CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT NOT NULL) WITHOUT ROWID;
                PRAGMA user_version = \(Self.schemaVersion);
                """)
        } else if version < Self.schemaVersion {
            // From a file of an earlier version: the table of what was last read, which that version did not have.
            try exec("CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT NOT NULL) WITHOUT ROWID")
            try exec("PRAGMA user_version = \(Self.schemaVersion)")
        }
    }

    // MARK: What was last read

    /// When the last complete pass over a provider's files started, so the next launch reads only what changed since and not
    /// everything again; nil when none ever finished (ADR 0010).
    public func lastIngest(provider: Provider) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return rows("SELECT value FROM meta WHERE key = ?", binds: ["last_ingest." + provider.rawValue]) {
            Double(String(cString: sqlite3_column_text($0, 0))).map { Date(timeIntervalSince1970: $0) }
        }.first ?? nil
    }

    public func setLastIngest(_ date: Date, provider: Provider) {
        lock.lock()
        defer { lock.unlock() }
        run("INSERT INTO meta(key, value) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            ["last_ingest." + provider.rawValue, String(date.timeIntervalSince1970)])
    }

    /// Version 1 keyed a window by its reset time rounded to the minute, which split one window into two when the time fell
    /// either side of a boundary. This puts them back together: the highest percentage, the first and the last time seen.
    private func mergeNearbyReadings() {
        struct Row {
            let provider: String, window: Int64, scope: String, resets: Int64
            let used: Double, first: Double?, last: Double?
        }
        let rows = rows("""
            SELECT provider, window_minutes, scope, resets_at, used_percent, first_observed, last_observed FROM readings
            ORDER BY provider, window_minutes, scope, resets_at
            """) { statement -> Row in
            Row(provider: String(cString: sqlite3_column_text(statement, 0)), window: sqlite3_column_int64(statement, 1),
                scope: String(cString: sqlite3_column_text(statement, 2)), resets: sqlite3_column_int64(statement, 3),
                used: sqlite3_column_double(statement, 4), first: Self.date(statement, 5)?.timeIntervalSince1970,
                last: Self.date(statement, 6)?.timeIntervalSince1970)
        }
        var groups: [[Row]] = []
        for row in rows {
            if let head = groups.last?.first, head.provider == row.provider, head.window == row.window, head.scope == row.scope,
               row.resets - head.resets <= Self.sameWindowWithin {
                groups[groups.count - 1].append(row)
            } else {
                groups.append([row])
            }
        }
        transaction {
            for group in groups where group.count > 1 {
                let head = group[0]
                for row in group.dropFirst() {
                    run("DELETE FROM readings WHERE provider = ? AND window_minutes = ? AND scope = ? AND resets_at = ?",
                        [head.provider, row.window, head.scope, row.resets])
                }
                let used = group.map(\.used).max() ?? head.used
                let first = group.compactMap(\.first).min()
                let last = group.compactMap(\.last).max()
                run("""
                    UPDATE readings SET used_percent = ?, first_observed = ?, last_observed = ?
                    WHERE provider = ? AND window_minutes = ? AND scope = ? AND resets_at = ?
                    """, [used, first, last, head.provider, head.window, head.scope, head.resets])
            }
        }
    }

    private func run(_ sql: String, _ values: [Any?]) {
        guard let statement = prepare(sql) else { return }
        defer { sqlite3_finalize(statement) }
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            switch value {
            case let text as String: sqlite3_bind_text(statement, index, text, -1, Self.transient)
            case let number as Int64: sqlite3_bind_int64(statement, index, number)
            case let number as Double: sqlite3_bind_double(statement, index, number)
            default: sqlite3_bind_null(statement, index)
            }
        }
        sqlite3_step(statement)
    }

    /// The reset time a window of this provider, length and scope already has within the tolerance of `resets`, if any.
    private func existingReset(_ provider: String, _ window: Int, _ scope: String, near resets: Int64) -> Int64? {
        rows("""
            SELECT resets_at FROM readings WHERE provider = ? AND window_minutes = ? AND scope = ? AND resets_at BETWEEN ? AND ?
            ORDER BY ABS(resets_at - ?) LIMIT 1
            """, binds: [provider, Double(window), scope, Double(resets - Self.sameWindowWithin), Double(resets + Self.sameWindowWithin),
                         Double(resets)]) { sqlite3_column_int64($0, 0) }.first
    }

    private var message: String { db.map { String(cString: sqlite3_errmsg($0)) } ?? "no database" }

    // MARK: Writing

    /// Messages whose key is already there are ignored. Returns how many were new.
    @discardableResult
    public func insert(_ messages: [Message]) -> Int {
        lock.lock()
        defer { lock.unlock() }
        guard !messages.isEmpty else { return 0 }
        var added = 0
        transaction {
            guard let statement = prepare("""
                INSERT OR IGNORE INTO messages(provider, key, at, model, input, output, cache_read, cache_write)
                VALUES(?,?,?,?,?,?,?,?)
                """) else { return }
            defer { sqlite3_finalize(statement) }
            for item in messages {
                sqlite3_reset(statement)
                bind(statement, 1, item.provider.rawValue)
                bind(statement, 2, item.key)
                sqlite3_bind_double(statement, 3, item.at.timeIntervalSince1970)
                bind(statement, 4, item.model)
                sqlite3_bind_int64(statement, 5, Int64(item.tokens.input))
                sqlite3_bind_int64(statement, 6, Int64(item.tokens.output))
                sqlite3_bind_int64(statement, 7, Int64(item.tokens.cacheRead))
                sqlite3_bind_int64(statement, 8, Int64(item.tokens.cacheWrite))
                if sqlite3_step(statement) == SQLITE_DONE { added += Int(sqlite3_changes(db)) }
            }
        }
        return added
    }

    /// A reading of a window already there keeps the highest percentage, the first time it was seen and the last. A reset time
    /// within two minutes of a window that is there is that window: two readings of one window can differ by a second or two.
    public func upsert(_ readings: [Reading]) {
        lock.lock()
        defer { lock.unlock() }
        guard !readings.isEmpty else { return }
        transaction {
            guard let statement = prepare("""
                INSERT INTO readings(provider, window_minutes, scope, resets_at, used_percent, first_observed, last_observed, source)
                VALUES(?,?,?,?,?,?,?,?)
                ON CONFLICT(provider, window_minutes, scope, resets_at) DO UPDATE SET
                  used_percent = MAX(used_percent, excluded.used_percent),
                  first_observed = CASE WHEN excluded.first_observed IS NULL THEN first_observed
                                        WHEN first_observed IS NULL THEN excluded.first_observed
                                        ELSE MIN(first_observed, excluded.first_observed) END,
                  last_observed = CASE WHEN excluded.last_observed IS NULL THEN last_observed
                                       WHEN last_observed IS NULL THEN excluded.last_observed
                                       ELSE MAX(last_observed, excluded.last_observed) END
                """) else { return }
            defer { sqlite3_finalize(statement) }
            for item in readings {
                sqlite3_reset(statement)
                bind(statement, 1, item.provider.rawValue)
                sqlite3_bind_int64(statement, 2, Int64(item.windowMinutes))
                bind(statement, 3, item.scope ?? "")
                let resets = Self.minute(item.resetsAt)
                sqlite3_bind_int64(statement, 4, existingReset(item.provider.rawValue, item.windowMinutes, item.scope ?? "",
                                                                near: resets) ?? resets)
                sqlite3_bind_double(statement, 5, item.usedPercent)
                bind(statement, 6, item.firstObserved)
                bind(statement, 7, item.lastObserved)
                bind(statement, 8, item.source)
                sqlite3_step(statement)
            }
        }
    }

    private static func minute(_ date: Date) -> Int64 { Int64((date.timeIntervalSince1970 / 60).rounded()) * 60 }

    // MARK: Reading

    public func messageCount(provider: Provider? = nil) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return rows("SELECT COUNT(*) FROM messages" + (provider == nil ? "" : " WHERE provider = ?"),
                    binds: provider.map { [$0.rawValue] } ?? []) { Int(sqlite3_column_int64($0, 0)) }.first ?? 0
    }

    /// Input and output tokens for each model, and how many messages, from `since` on.
    public func modelTotals(provider: Provider, since: Date? = nil) -> [ModelTotal] {
        lock.lock()
        defer { lock.unlock() }
        return rows("""
            SELECT model, SUM(input), SUM(output), COUNT(*) FROM messages
            WHERE provider = ? AND at >= ? GROUP BY model
            """, binds: [provider.rawValue, since?.timeIntervalSince1970 ?? -1e18]) {
            ModelTotal(model: sqlite3_column_type($0, 0) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text($0, 0)),
                       input: Int(sqlite3_column_int64($0, 1)), output: Int(sqlite3_column_int64($0, 2)),
                       messages: Int(sqlite3_column_int64($0, 3)))
        }
    }

    /// The readings of a provider whose window resets from `since` on, oldest first.
    public func readings(provider: Provider, since: Date? = nil) -> [Reading] {
        lock.lock()
        defer { lock.unlock() }
        return rows("""
            SELECT window_minutes, scope, resets_at, used_percent, first_observed, last_observed, source FROM readings
            WHERE provider = ? AND resets_at >= ? ORDER BY resets_at
            """, binds: [provider.rawValue, since?.timeIntervalSince1970 ?? -1e18]) { statement in
            Reading(provider: provider, windowMinutes: Int(sqlite3_column_int64(statement, 0)),
                    scope: sqlite3_column_text(statement, 1).map(String.init(cString:)).flatMap { $0.isEmpty ? nil : $0 },
                    resetsAt: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 2))),
                    usedPercent: sqlite3_column_double(statement, 3),
                    firstObserved: Self.date(statement, 4), lastObserved: Self.date(statement, 5),
                    source: String(cString: sqlite3_column_text(statement, 6)))
        }
    }

    /// The oldest message and reading kept, for "since when".
    public func oldest(provider: Provider) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        let seconds = rows("SELECT MIN(at) FROM messages WHERE provider = ?", binds: [provider.rawValue]) {
            sqlite3_column_type($0, 0) == SQLITE_NULL ? nil : sqlite3_column_double($0, 0)
        }.first ?? nil
        return seconds.map { Date(timeIntervalSince1970: $0) }
    }

    private static func date(_ statement: OpaquePointer, _ column: Int32) -> Date? {
        sqlite3_column_type(statement, column) == SQLITE_NULL ? nil : Date(timeIntervalSince1970: sqlite3_column_double(statement, column))
    }

    // MARK: SQLite helpers

    private func exec(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &error) == SQLITE_OK else {
            let text = error.map { String(cString: $0) } ?? message
            sqlite3_free(error)
            throw Failure(description: text)
        }
    }

    private func scalarInt(_ sql: String) throws -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw Failure(description: "prepare: \(message)")
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { throw Failure(description: "step: \(message)") }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func prepare(_ sql: String) -> OpaquePointer? {
        var statement: OpaquePointer?
        return sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK ? statement : nil
    }

    private func transaction(_ body: () -> Void) {
        sqlite3_exec(db, "BEGIN IMMEDIATE", nil, nil, nil)
        body()
        sqlite3_exec(db, "COMMIT", nil, nil, nil)
    }

    private func bind(_ statement: OpaquePointer, _ index: Int32, _ value: String?) {
        if let value { sqlite3_bind_text(statement, index, value, -1, Self.transient) } else { sqlite3_bind_null(statement, index) }
    }

    private func bind(_ statement: OpaquePointer, _ index: Int32, _ value: Date?) {
        if let value { sqlite3_bind_double(statement, index, value.timeIntervalSince1970) } else { sqlite3_bind_null(statement, index) }
    }

    private func rows<T>(_ sql: String, binds: [Any] = [], _ map: (OpaquePointer) -> T) -> [T] {
        guard let statement = prepare(sql) else { return [] }
        defer { sqlite3_finalize(statement) }
        for (offset, value) in binds.enumerated() {
            let index = Int32(offset + 1)
            switch value {
            case let text as String: sqlite3_bind_text(statement, index, text, -1, Self.transient)
            case let number as Double: sqlite3_bind_double(statement, index, number)
            default: sqlite3_bind_null(statement, index)
            }
        }
        var result: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW { result.append(map(statement)) }
        return result
    }
}
