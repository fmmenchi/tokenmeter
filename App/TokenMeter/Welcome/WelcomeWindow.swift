import AppKit
import SwiftUI
import TokenMeterCore

/// The welcome wizard's window and its state (feature "welcome tour"). An `NSWindow` hosting a SwiftUI view, not a scene, so the app
/// can open it by itself at the first launch; it needs nothing of the `Meter` and nothing else in the app depends on it.
@MainActor @Observable
final class WelcomeWindow: NSObject, NSWindowDelegate {
    static let shared = WelcomeWindow()

    private(set) var state = WelcomeState.idle
    @ObservationIgnored private let store: any WelcomeSeenStore = DefaultsWelcomeSeenStore()
    @ObservationIgnored private var window: NSWindow?

    /// At launch: opens it if it was never seen, on a fresh install and on the first update alike.
    func showIfUnseen() {
        guard !store.seen else { return }
        open(.atLaunch(seen: false))
    }

    /// "Show the welcome again" in Settings.
    func showAgain() { open(.again) }

    /// What the person does in the footer. Reaching Done or skipping counts as seen.
    func apply(_ action: WelcomeState.Action) {
        if state.endedBy(action) { store.markSeen() }
        state = state.applying(action)
        if !state.isShowing { window?.close() }
    }

    private func open(_ state: WelcomeState) {
        self.state = state
        if let window {
            window.makeKeyAndOrderFront(nil)
        } else {
            let window = NSWindow(contentViewController: NSHostingController(rootView: WelcomeView(welcome: self)))
            window.styleMask = [.titled, .closable]
            window.title = "Welcome to tokenmeter"
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            window.makeKeyAndOrderFront(nil)
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    /// The red button counts as skipping.
    func windowWillClose(_ notification: Notification) {
        if state.isShowing { apply(.close) }
        window = nil
    }
}

/// Opens the welcome at launch. The menu-bar item and the other scenes are untouched.
final class TokenMeterDelegate: NSObject, NSApplicationDelegate {
    @MainActor func applicationDidFinishLaunching(_ notification: Notification) {
        WelcomeWindow.shared.showIfUnseen()
    }
}
