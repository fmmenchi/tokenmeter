import AppKit
import Observation
import Sparkle

/// The app updating itself (ADR 0011). It owns Sparkle and says, for the interface, what the last check found.
///
/// Sparkle asks, downloads, verifies the signature, quits the app, replaces it and opens it again; nothing is installed without a
/// yes in its window. What the app adds is what the user sees outside that window: a status line in Settings, and a notice in the
/// panel and a dot on the menu-bar icon for whoever missed the window (a scheduled check in an app with no Dock icon).
///
/// It starts only when the build has the public half of the signing key: Sparkle refuses an update it cannot verify, so a build
/// without one (a development build) would only fail at launch.
@MainActor @Observable
final class Updater: NSObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        /// `notes` is the changelog page of that version, when the feed gives one.
        case available(version: String, notes: URL?)
        case failed
    }

    private(set) var state = State.idle
    private(set) var lastChecked: Date?
    /// Whether Sparkle runs in this build: the key and the feed address are there.
    let isConfigured: Bool
    private(set) var automaticallyChecks = false

    @ObservationIgnored private var controller: SPUStandardUpdaterController?

    /// The version and the build, read from the app's own Info.plist and never written by hand.
    static var versionText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    override init() {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
        isConfigured = !key.isEmpty && URL(string: feed) != nil
        super.init()
        guard isConfigured else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: self)
        self.controller = controller
        lastChecked = controller.updater.lastUpdateCheckDate
        automaticallyChecks = controller.updater.automaticallyChecksForUpdates
    }

    /// The switch in Settings. Sparkle keeps it, so it holds across launches.
    func setAutomaticallyChecks(_ on: Bool) {
        controller?.updater.automaticallyChecksForUpdates = on
        automaticallyChecks = controller?.updater.automaticallyChecksForUpdates ?? false
    }

    /// "Check now", and "Install" in the panel: the app has no Dock icon, so it comes forward first or Sparkle's window
    /// would open behind the other windows.
    func checkNow() {
        guard let controller, state != .checking else { return }
        state = .checking
        NSApp.activate()
        controller.checkForUpdates(nil)
    }

    /// Whether the panel notice and the menu-bar dot show: an update was found and not yet installed.
    var hasUpdate: Bool {
        if case .available = state { return true }
        return false
    }

    private func finish(_ next: State) {
        lastChecked = controller?.updater.lastUpdateCheckDate ?? Date()
        state = next
    }
}

extension Updater: SPUUpdaterDelegate {
    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        let notes = item.releaseNotesURL
        Task { @MainActor in self.finish(.available(version: version, notes: notes)) }
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        Task { @MainActor in self.finish(.upToDate) }
    }

    nonisolated func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        // Sparkle reports "no update" as an abort too; the line above already said so.
        let nsError = error as NSError
        guard !(nsError.domain == SUSparkleErrorDomain && nsError.code == Int(SUError.noUpdateError.rawValue)) else { return }
        Task { @MainActor in
            // An update that is waiting stays: a failed second look does not take the notice away.
            if !self.hasUpdate { self.finish(.failed) }
        }
    }
}

extension Updater: SPUStandardUserDriverDelegate {
    /// A scheduled check in an app with no Dock icon must not open a window by surprise: Sparkle asks, and the answer is yes only
    /// when the app is already in front. Otherwise the panel notice and the dot say it, and "Install" opens the window.
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        immediateFocus
    }
}
