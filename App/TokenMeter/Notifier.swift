import Foundation
import TokenMeterCore
import UserNotifications

/// Shows the notices to macOS (ADR 0012): asks for the permission when it is first needed and posts one notification for each notice.
/// The rule that says which notice is due is in the core; this only speaks.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    enum Permission: Equatable {
        /// Not asked yet.
        case unknown
        case allowed
        case denied
    }

    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func permission() async -> Permission {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional: .allowed
        case .denied: .denied
        default: .unknown
        }
    }

    /// Asks the first time, and says where the permission stands afterwards.
    func requestIfNeeded() async -> Permission {
        if await permission() == .unknown {
            _ = try? await center.requestAuthorization(options: [.alert])
        }
        return await permission()
    }

    func post(_ notice: LimitNotice) {
        let content = UNMutableNotificationContent()
        content.title = notice.title
        content.body = notice.body
        center.add(UNNotificationRequest(identifier: notice.id, content: content, trigger: nil))
    }

    /// The app is a menu-bar item that is always the active one in a way: show the banner even then.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions {
        [.banner]
    }
}

extension LimitNotice {
    /// "Claude · Weekly", and for a model's limit "Claude · Weekly · Fable".
    var title: String {
        ([providerTitle, window.window.label] + [window.window.scope].compactMap { $0 }).joined(separator: " · ")
    }

    /// One line: what is left and when it resets; the notice that the pace gives says where it runs out.
    var body: String {
        let left = window.remainingFraction.map { "\(Int(($0 * 100).rounded()))% left" }
        let pace = kind == .willRunOut ? window.runsOutShortText(at: Date()).map { "at this pace \($0)" } : nil
        let reset = window.resetText.map { "resets \($0)" }
        return [left, pace, reset].compactMap { $0 }.joined(separator: " · ")
    }
}
