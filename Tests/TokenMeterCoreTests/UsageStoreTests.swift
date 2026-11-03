import SQLite3
import XCTest
@testable import TokenMeterCore

final class UsageStoreTests: XCTestCase {
    private let claude = Provider.claude
    private let chatgpt = Provider.chatgpt
    private let day: TimeInterval = 86_400

    private func fileURL(_ name: String = "usage.sqlite") throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder.appendingPathComponent("a/b").appendingPathComponent(name)
    }

    private func message(_ key: String, at seconds: TimeInterval = 1_000, model: String? = "fable", output: Int = 10,
                         provider: Provider = .claude) -> UsageStore.Message {
        UsageStore.Message(provider: provider, key: key, at: Date(timeIntervalSince1970: seconds), model: model,
                           tokens: TokenCounts(input: 1, output: output, cacheRead: 100, cacheWrite: 5))
    }

    private func reading(percent: Double, resets: TimeInterval = 7 * 86_400, first: TimeInterval? = nil,
                         last: TimeInterval? = nil, source: String = "log", scope: String? = nil) -> UsageStore.Reading {
        UsageStore.Reading(provider: chatgpt, windowMinutes: 10_080, scope: scope, resetsAt: Date(timeIntervalSince1970: resets),
                           usedPercent: percent, firstObserved: first.map { Date(timeIntervalSince1970: $0) },
                           lastObserved: last.map { Date(timeIntervalSince1970: $0) }, source: source)
    }

    func testANewFileIsMadeWithItsFolderAndTheSchemaVersion() throws {
        let url = try fileURL()
        _ = try UsageStore(url: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "PRAGMA user_version", -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
        XCTAssertEqual(Int(sqlite3_column_int64(statement, 0)), UsageStore.schemaVersion)
    }

    func testAMessageWithTheSameKeyIsIgnored() throws {
        let store = try UsageStore(url: try fileURL())
        XCTAssertEqual(store.insert([message("a"), message("b")]), 2)
        XCTAssertEqual(store.insert([message("a", output: 999), message("c")]), 1, "a is there, c is new")
        XCTAssertEqual(store.messageCount(), 3)
        XCTAssertEqual(store.modelTotals(provider: claude).first?.output, 30, "the first a stays, the second is ignored")
    }

    func testTheSameKeyForAnotherProviderIsAnotherMessage() throws {
        let store = try UsageStore(url: try fileURL())
        store.insert([message("a"), message("a", provider: chatgpt)])
        XCTAssertEqual(store.messageCount(), 2)
        XCTAssertEqual(store.messageCount(provider: chatgpt), 1)
    }

    func testAReadingKeepsTheHighestPercentageAndTheFirstAndLastTimeSeen() throws {
        let store = try UsageStore(url: try fileURL())
        store.upsert([reading(percent: 40, first: 200, last: 300)])
        store.upsert([reading(percent: 70, first: 250, last: 500), reading(percent: 55, first: 100, last: 150, source: "live")])
        let stored = store.readings(provider: chatgpt)
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored[0].usedPercent, 70, "a percentage does not go down: the highest is kept")
        XCTAssertEqual(stored[0].firstObserved, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(stored[0].lastObserved, Date(timeIntervalSince1970: 500))
        XCTAssertEqual(stored[0].source, "log", "the first source stays")
    }

    func testAReadingWithNoTimeSeenTakesTheOneThatHas() throws {
        let store = try UsageStore(url: try fileURL())
        store.upsert([reading(percent: 10)])
        store.upsert([reading(percent: 20, first: 200, last: 300)])
        let stored = store.readings(provider: chatgpt)
        XCTAssertEqual(stored[0].firstObserved, Date(timeIntervalSince1970: 200))
        XCTAssertEqual(stored[0].lastObserved, Date(timeIntervalSince1970: 300))
    }

    func testTwoResetTimesWithinHalfAMinuteAreOneWindow() throws {
        let store = try UsageStore(url: try fileURL())
        store.upsert([reading(percent: 10, resets: 604_800.0), reading(percent: 30, resets: 604_800.4)])
        XCTAssertEqual(store.readings(provider: chatgpt).count, 1)
        store.upsert([reading(percent: 5, resets: 604_800.0 + 600)])
        XCTAssertEqual(store.readings(provider: chatgpt).count, 2, "ten minutes later is another window")
    }

    func testTheScopeOfALimitIsPartOfItsIdentity() throws {
        let store = try UsageStore(url: try fileURL())
        store.upsert([reading(percent: 10), reading(percent: 20, scope: "Fable")])
        let stored = store.readings(provider: chatgpt)
        XCTAssertEqual(stored.count, 2)
        XCTAssertEqual(Set(stored.map(\.scope)), [nil, "Fable"])
    }

    func testResetTimesEitherSideOfARoundingBoundaryAreOneWindow() throws {
        let store = try UsageStore(url: try fileURL())
        // 29 and 31 seconds past a minute: rounded to the minute they are two windows, and they are one.
        store.upsert([reading(percent: 47, resets: 604_800 + 29, first: 100, last: 200), reading(percent: 31, resets: 604_800 + 31, first: 50, last: 150)])
        let stored = store.readings(provider: chatgpt)
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored[0].usedPercent, 47)
        XCTAssertEqual(stored[0].firstObserved, Date(timeIntervalSince1970: 50))
        XCTAssertEqual(stored[0].lastObserved, Date(timeIntervalSince1970: 200))
    }

    func testTheToleranceIsTwoMinutes() throws {
        let store = try UsageStore(url: try fileURL())
        store.upsert([reading(percent: 10, resets: 604_800), reading(percent: 20, resets: 604_800 + 119), reading(percent: 30, resets: 604_800 + 300)])
        XCTAssertEqual(store.readings(provider: chatgpt).map(\.usedPercent), [20, 30], "119 seconds is the same window, five minutes is not")
    }

    func testAFileOfTheFirstVersionHasItsSplitWindowsPutBackTogether() throws {
        let url = try fileURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK)
        let sql = """
            CREATE TABLE messages(provider TEXT NOT NULL, key TEXT NOT NULL, at REAL NOT NULL, model TEXT, input INTEGER NOT NULL,
              output INTEGER NOT NULL, cache_read INTEGER NOT NULL, cache_write INTEGER NOT NULL, PRIMARY KEY(provider, key)) WITHOUT ROWID;
            CREATE TABLE readings(provider TEXT NOT NULL, window_minutes INTEGER NOT NULL, scope TEXT NOT NULL, resets_at INTEGER NOT NULL,
              used_percent REAL NOT NULL, first_observed REAL, last_observed REAL, source TEXT NOT NULL,
              PRIMARY KEY(provider, window_minutes, scope, resets_at)) WITHOUT ROWID;
            INSERT INTO readings VALUES('chatgpt', 10080, '', 604800, 47, 100, 200, 'log');
            INSERT INTO readings VALUES('chatgpt', 10080, '', 604860, 31, 50, 150, 'log');
            INSERT INTO readings VALUES('chatgpt', 10080, '', 1209600, 19, 300, 400, 'log');
            INSERT INTO readings VALUES('chatgpt', 300, '', 604800, 5, 10, 20, 'log');
            PRAGMA user_version = 1;
            """
        XCTAssertEqual(sqlite3_exec(db, sql, nil, nil, nil), SQLITE_OK)
        sqlite3_close(db)

        let store = try UsageStore(url: url)

        let weekly = store.readings(provider: chatgpt).filter { $0.windowMinutes == 10_080 }
        XCTAssertEqual(weekly.map(\.usedPercent), [47, 19], "the two that were one window are one, the other stays")
        XCTAssertEqual(weekly[0].firstObserved, Date(timeIntervalSince1970: 50))
        XCTAssertEqual(weekly[0].lastObserved, Date(timeIntervalSince1970: 200))
        XCTAssertEqual(store.readings(provider: chatgpt).filter { $0.windowMinutes == 300 }.count, 1, "another length is not merged")

        var raw: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(url.path, &raw, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(raw) }
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(raw, "PRAGMA user_version", -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
        XCTAssertEqual(Int(sqlite3_column_int64(statement, 0)), UsageStore.schemaVersion)
    }

    func testWhenAProviderWasLastReadIsKeptForEachProvider() throws {
        let url = try fileURL()
        let store = try UsageStore(url: url)
        XCTAssertNil(store.lastIngest(provider: claude))
        store.setLastIngest(Date(timeIntervalSince1970: 1_000), provider: claude)
        store.setLastIngest(Date(timeIntervalSince1970: 2_000), provider: chatgpt)
        store.setLastIngest(Date(timeIntervalSince1970: 3_000), provider: claude)
        XCTAssertEqual(store.lastIngest(provider: claude), Date(timeIntervalSince1970: 3_000), "the later mark replaces the earlier")
        XCTAssertEqual(store.lastIngest(provider: chatgpt), Date(timeIntervalSince1970: 2_000))
        XCTAssertEqual(try UsageStore(url: url).lastIngest(provider: claude), Date(timeIntervalSince1970: 3_000), "kept across opens")
    }

    func testAFileOfVersionTwoGainsTheTableOfWhatWasLastRead() throws {
        let url = try fileURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK)
        let sql = """
            CREATE TABLE messages(provider TEXT NOT NULL, key TEXT NOT NULL, at REAL NOT NULL, model TEXT, input INTEGER NOT NULL,
              output INTEGER NOT NULL, cache_read INTEGER NOT NULL, cache_write INTEGER NOT NULL, PRIMARY KEY(provider, key)) WITHOUT ROWID;
            CREATE TABLE readings(provider TEXT NOT NULL, window_minutes INTEGER NOT NULL, scope TEXT NOT NULL, resets_at INTEGER NOT NULL,
              used_percent REAL NOT NULL, first_observed REAL, last_observed REAL, source TEXT NOT NULL,
              PRIMARY KEY(provider, window_minutes, scope, resets_at)) WITHOUT ROWID;
            INSERT INTO messages VALUES('claude', 'k', 100, 'm', 1, 2, 3, 4);
            PRAGMA user_version = 2;
            """
        XCTAssertEqual(sqlite3_exec(db, sql, nil, nil, nil), SQLITE_OK)
        sqlite3_close(db)

        let store = try UsageStore(url: url)

        XCTAssertEqual(store.messageCount(), 1, "what was kept stays")
        XCTAssertNil(store.lastIngest(provider: claude), "and nothing says it was read, so the next pass reads everything once")
        store.setLastIngest(Date(timeIntervalSince1970: 5), provider: claude)
        XCTAssertEqual(store.lastIngest(provider: claude), Date(timeIntervalSince1970: 5))
    }

    func testClosingAndOpeningAgainKeepsEverything() throws {
        let url = try fileURL()
        do {
            let store = try UsageStore(url: url)
            store.insert([message("a")])
            store.upsert([reading(percent: 40)])
        }
        let again = try UsageStore(url: url)
        XCTAssertEqual(again.messageCount(), 1)
        XCTAssertEqual(again.readings(provider: chatgpt).first?.usedPercent, 40)
    }

    func testAFileThatIsNotADatabaseIsMadeAgainEmpty() throws {
        let url = try fileURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("this is not a database, just some text that is long enough to look like a file".utf8).write(to: url)
        let store = try UsageStore(url: url)
        XCTAssertEqual(store.messageCount(), 0)
        store.insert([message("a")])
        XCTAssertEqual(store.messageCount(), 1, "and it works")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path + ".damaged"), "what was there is set aside, not thrown away")
    }

    func testAFileThatIsLockedByAnotherCopyIsNotWipedAndTheStoreIsRefused() throws {
        let url = try fileURL()
        do {
            let first = try UsageStore(url: url)
            first.insert([message("a")])
        }
        // Another process holds the file for longer than the store waits.
        var other: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &other), SQLITE_OK)
        defer { sqlite3_close(other) }
        XCTAssertEqual(sqlite3_exec(other, "PRAGMA journal_mode=DELETE; BEGIN EXCLUSIVE;", nil, nil, nil), SQLITE_OK)
        let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int
        XCTAssertThrowsError(try UsageStore(url: url, busyMilliseconds: 50))
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int, size, "the history is still there")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path + ".damaged"))
        sqlite3_exec(other, "ROLLBACK;", nil, nil, nil)
        XCTAssertEqual(try UsageStore(url: url).messageCount(), 1, "and once the lock is gone, it opens with its history")
    }

    func testAFileFromANewerVersionIsRefusedAndLeftAlone() throws {
        let url = try fileURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, "CREATE TABLE keep(x); PRAGMA user_version = 99;", nil, nil, nil), SQLITE_OK)
        sqlite3_close(db)
        XCTAssertThrowsError(try UsageStore(url: url))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "it is not wiped")
    }

    func testTokensAreSummedForEachModelFromADateOn() throws {
        let store = try UsageStore(url: try fileURL())
        store.insert([message("a", at: 1_000, model: "fable", output: 10), message("b", at: 2_000, model: "fable", output: 20),
                      message("c", at: 3_000, model: "opus", output: 5), message("d", at: 4_000, model: nil, output: 1)])
        let all = Dictionary(uniqueKeysWithValues: store.modelTotals(provider: claude).map { ($0.model ?? "none", $0) })
        XCTAssertEqual(all["fable"]?.output, 30)
        XCTAssertEqual(all["fable"]?.messages, 2)
        XCTAssertEqual(all["opus"]?.output, 5)
        XCTAssertEqual(all["none"]?.output, 1, "a message with no model is its own group")
        let late = store.modelTotals(provider: claude, since: Date(timeIntervalSince1970: 2_500))
        XCTAssertEqual(Set(late.map { $0.model ?? "none" }), ["opus", "none"])
        XCTAssertEqual(store.oldest(provider: claude), Date(timeIntervalSince1970: 1_000))
        XCTAssertNil(store.oldest(provider: chatgpt))
    }

    func testReadingsFromADateOnAreOldestFirst() throws {
        let store = try UsageStore(url: try fileURL())
        store.upsert([reading(percent: 1, resets: 3 * day), reading(percent: 2, resets: 1 * day), reading(percent: 3, resets: 2 * day)])
        XCTAssertEqual(store.readings(provider: chatgpt).map(\.usedPercent), [2, 3, 1])
        XCTAssertEqual(store.readings(provider: chatgpt, since: Date(timeIntervalSince1970: 1.5 * day)).map(\.usedPercent), [3, 1])
    }
}
