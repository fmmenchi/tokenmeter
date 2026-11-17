import AppKit
import SwiftUI
import TokenMeterCore

/// What is new since the version last seen (feature "what's new"): the card in the panel says it, and this window lists it. Only the
/// features, never the fixes. An `NSWindow`, as the welcome, so the card can open it from the menu-bar panel.
@MainActor @Observable
final class WhatsNew: NSObject, NSWindowDelegate {
    static let shared = WhatsNew()
    private static let lastSeenKey = "lastVersionSeen"
    private static let fromKey = "whatsNewFrom"

    /// The features the card announces; empty when there is nothing to say.
    private(set) var pending: [WhatsNewEntry] = []
    /// The version the person came from, when it is known: "3 new features since 0.13.0".
    private(set) var from: String?
    @ObservationIgnored private var window: NSWindow?

    var installed: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0" }

    /// At launch, before the welcome: a first launch has nothing new, and every launch with nothing new records the version.
    func atLaunch(firstLaunch: Bool) {
        let defaults = UserDefaults.standard
        let lastSeen = defaults.string(forKey: Self.lastSeenKey)
        let new = TokenMeterCore.WhatsNew.new(since: lastSeen, installed: installed, firstLaunch: firstLaunch)
        if new.isEmpty {
            defaults.set(installed, forKey: Self.lastSeenKey)
        } else {
            pending = new
            from = lastSeen
            defaults.set(lastSeen, forKey: Self.fromKey)
        }
    }

    /// Dismiss, See what's new or Done: the card goes, and the window can still be opened from Settings.
    func markSeen() {
        pending = []
        UserDefaults.standard.set(installed, forKey: Self.lastSeenKey)
    }

    /// The card's button, and "Show what's new again" in Settings: the list of the last update, or the installed version's own.
    func showList() {
        let shown = pending.isEmpty
            ? TokenMeterCore.WhatsNew.new(since: UserDefaults.standard.string(forKey: Self.fromKey), installed: installed, firstLaunch: false)
            : pending
        let from = pending.isEmpty ? UserDefaults.standard.string(forKey: Self.fromKey) : self.from
        markSeen()
        let view = WhatsNewList(entries: shown, from: from, installed: installed) { [weak self] in self?.window?.close() }
        if let window {
            window.contentViewController = NSHostingController(rootView: view)
            window.makeKeyAndOrderFront(nil)
        } else {
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.styleMask = [.titled, .closable]
            window.title = "What's new in tokenmeter"
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            window.makeKeyAndOrderFront(nil)
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) { window = nil }

    /// "3 new features since 0.13.0", or "New in 0.16.0" when the version the person came from is not known.
    static func headline(count: Int, from: String?, installed: String) -> String {
        guard let from else { return "New in \(installed)" }
        return "\(count) new feature\(count == 1 ? "" : "s") since \(from)"
    }
}

/// The window's content: the headline, one block per feature, newest first, a link to the changelog and Done.
private struct WhatsNewList: View {
    let entries: [WhatsNewEntry]
    let from: String?
    let installed: String
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(WhatsNew.headline(count: entries.count, from: from, installed: installed)).font(.title2.bold())
                Text(from.map { "You updated from \($0) to \(installed). Fixes are in the changelog." }
                     ?? "Fixes are in the changelog.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.version).font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
                            Text(entry.title).font(.headline)
                            Text(entry.detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))
                    }
                }
            }
            HStack {
                Link("Read the full changelog", destination: URL(string: "https://fmmenchi.github.io/tokenmeter/use/changelog")!)
                    .font(.callout)
                Spacer()
                Button("Done", action: done).keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 560, height: 460)
    }
}

/// The card at the top of the panel, under the update notice: how many features are new, their titles in a line, Dismiss and See
/// what's new. It stays until one of the two is pressed.
struct WhatsNewNotice: View {
    let whatsNew: WhatsNew

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(WhatsNew.headline(count: whatsNew.pending.count, from: whatsNew.from, installed: whatsNew.installed))
                .font(.subheadline.weight(.semibold))
            Text(whatsNew.pending.map(\.title).joined(separator: " · ")).font(.caption2).captionColour()
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Spacer()
                Button("Dismiss") { whatsNew.markSeen() }
                Button("See what's new") { whatsNew.showList() }.buttonStyle(.borderedProminent)
            }
            .controlSize(.small)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.15)))
    }
}
