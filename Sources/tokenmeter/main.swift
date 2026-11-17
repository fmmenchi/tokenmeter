import Foundation
import TokenMeterCore

// The `tokenmeter` command (ADR 0017): it reads the snapshot the app wrote for the widget and the usage store, and prints them. It
// collects nothing itself, so it says what the panel says.

let usage = """
    Usage: tokenmeter [--json] [--left | --used]
           tokenmeter stats [--range month|quarter|year|lifetime] [--json]
           tokenmeter --help | --version

    Prints the quota the tokenmeter app last read, or with `stats` what it kept: the suggestion, each window's summary, the tokens
    by model and their cost at API list prices. It reads only what the app wrote; the app must have run.

    Exit status: 0 a fresh reading, 1 nothing to read (the app never ran), 2 a reading older than 10 minutes.
    """

var arguments = Array(CommandLine.arguments.dropFirst())
@MainActor func take(_ flag: String) -> Bool {
    guard let index = arguments.firstIndex(of: flag) else { return false }
    arguments.remove(at: index)
    return true
}

func fail(_ message: String, _ code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

if take("--help") || take("-h") { print(usage); exit(0) }
if take("--version") {
    print(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development build")
    exit(0)
}
let json = take("--json")
let forced: BarsDisplay? = take("--used") ? .used : take("--left") ? .left : nil
let wantsStats = take("stats")
var range = StatsRange.month
if let index = arguments.firstIndex(of: "--range") {
    guard index + 1 < arguments.count, let chosen = StatsRange(rawValue: arguments[index + 1]) else {
        fail("--range takes month, quarter, year or lifetime.", 64)
    }
    range = chosen
    arguments.removeSubrange(index...index + 1)
}
if let unknown = arguments.first { fail("Unknown argument: \(unknown)\n\n\(usage)", 64) }

/// The copy of the snapshot the app keeps for this command, beside the usage store (ADR 0017). `TOKENMETER_SNAPSHOT` names another file.
func snapshotURL() -> URL {
    if let path = ProcessInfo.processInfo.environment["TOKENMETER_SNAPSHOT"] { return URL(fileURLWithPath: path) }
    return SnapshotStore.commandStore().url
}

let now = Date()
let snapshot = SnapshotStore(url: snapshotURL()).read()

if wantsStats {
    let storeURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/TokenMeter/usage.sqlite")
    let store: UsageStore
    do { store = try UsageStore.readOnly(url: storeURL) } catch {
        fail("No history to read at \(storeURL.path): open the tokenmeter app once. (\(error))", CommandOutput.Exit.missing.rawValue)
    }
    let configured = ((try? ProviderConfigFile.load()) ?? nil)?.providers ?? ProviderConfigFile.seed().providers
    var titles = Dictionary(uniqueKeysWithValues: (snapshot?.providers ?? []).map { ($0.provider, $0.title) })
    let shown = configured.filter { config in snapshot?.providers.contains { $0.provider.rawValue == config.id } ?? true }
    let stats = shown.map { config -> ProviderStats in
        let provider = Provider(rawValue: config.id)
        if titles[provider] == nil { titles[provider] = config.id }
        return UsageStats.stats(for: provider, windows: config.windows, families: config.usage?.families ?? [], store: store, range: range)
    }
    if json {
        guard let data = try? CommandOutput.statsJSON(stats, titles: titles, range: range) else { fail("Could not write the JSON.", 70) }
        print(String(decoding: data, as: UTF8.self))
    } else {
        print(CommandOutput.statsText(stats, titles: titles, range: range))
    }
    exit(0)
}

guard let snapshot else {
    fail("Nothing to read at \(snapshotURL().path): open tokenmeter 0.16 or later once, so it writes what it sees.",
         CommandOutput.Exit.missing.rawValue)
}
let display = forced ?? snapshot.barsDisplay
if json {
    guard let data = try? CommandOutput.quotaJSON(snapshot, display: display, now: now) else { fail("Could not write the JSON.", 70) }
    print(String(decoding: data, as: UTF8.self))
} else {
    print(CommandOutput.quotaText(snapshot, display: display, now: now))
}
exit(CommandOutput.exit(for: snapshot, now: now).rawValue)
