import SwiftUI
import TokenMeterCore

/// The eight pages of the welcome wizard: a title, a short text, a picture with the part outlined, and the footer.
struct WelcomeView: View {
    let welcome: WelcomeWindow

    var body: some View {
        if let page = welcome.state.page {
            VStack(alignment: .leading, spacing: 14) {
                Text(page.title).font(.title2.bold())
                Text(page.text)
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                WelcomePicture(page: page)
                Spacer(minLength: 0)
                footer(page)
            }
            .padding(24)
            .frame(width: 680, height: page == .stats ? 600 : page == .suggestion ? 560 : 500)
        }
    }

    private func footer(_ page: WelcomeState.Page) -> some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                ForEach(WelcomeState.Page.allCases, id: \.self) { dot in
                    Circle().fill(dot == page ? Color.accentColor : Color.secondary.opacity(0.35)).frame(width: 7, height: 7)
                }
            }
            Button("Skip") { welcome.apply(.skip) }.buttonStyle(.plain).foregroundStyle(.secondary)
            Spacer()
            if !page.isFirst { Button("Back") { welcome.apply(.back) } }
            Button(page.isLast ? "Done" : "Next") { welcome.apply(.next) }
                .keyboardShortcut(.defaultAction)
        }
    }
}

extension WelcomeState.Page {
    var title: String {
        switch self {
        case .whereItLives: "Where it lives"
        case .bars: "The bars"
        case .tick: "The tick"
        case .buttons: "Refresh, stats, settings and quit"
        case .stats: "The stats"
        case .suggestion: "The suggestion"
        case .accounts: "An account is a folder"
        case .settings: "Settings has five tabs"
        }
    }

    var text: String {
        switch self {
        case .whereItLives:
            "It lives in the menu bar: click the gauge icon to see how much of your Claude and ChatGPT plans is left. A small dot on the icon means something needs a look: a problem the panel lists, or an update to install."
        case .bars:
            "Green is plenty left, orange under 40%, red under 15%. The figure says how much is left; if you would rather read how much is used, change it in Settings, in General. tokenmeter reads the files that Claude Code and the Codex CLI leave on this Mac, with no API calls, no login and no key, so the bars update as you use them: at the first launch, until you do, they stay empty."
        case .tick:
            "Where the bar would be at a steady use. If the bar ends before it, the quota runs out before the reset. With Show on the bars on Used the bar fills the other way, and the mark with it: then the bar that ends after the mark is the one that runs out."
        case .buttons:
            "The lines above say how fresh each quota is. Refresh reads the files now; on its own tokenmeter reads every minute. Open /usage on a Claude card opens its model limits in Claude Code, which the app otherwise refreshes on its own every 15 minutes. The chart switches to the stats, the gear opens Settings, the lock lets you reorder and hide the cards, power quits."
        case .stats:
            "The chart in the panel switches to the stats. Pick a period at the top: each provider's card shows its windows as strips, one block for each window: green when plenty was left, orange when little, red when the ceiling was reached. Point at a block for its figure; a dashed one is a window the app did not see. The goal is to see whether your plan fits the way you use it. The tokens are only those this Mac counted."
        case .suggestion:
            "The word at the top of a provider's card is the app's suggestion: Wait, Stay, Move up or Move down. It comes from the quota percentages only, the 5-hour windows and the weekly ones, and never looks at tokens. Move up says the ceiling is reached often; it does not say which plan to take."
        case .accounts:
            "A work account and a personal one? Each is a folder that Claude Code or the Codex CLI reads. Name it in providers.json and it gets a card of its own, with its own bars and history. When a folder nobody named is found, the panel says so, and Add it gives it a card."
        case .settings:
            "General, Accounts, Skin, Notifications and Updates. In General you choose whether the bars show how much is left or how much is used, and the Claude quota for each account. Accounts is where an account is added, renamed or removed. Choose a skin and turn on notifications there. The daily check for updates is in Updates, where you can turn it off. You can see this tour again from General."
        }
    }
}

/// The picture of a page: the real icon, a screenshot of the panel with a part outlined, the real tabs of Settings, or the
/// real cards of two accounts drawn with sample data.
private struct WelcomePicture: View {
    let page: WelcomeState.Page

    /// A part of a screenshot, as fractions of its width and height.
    private struct Outline { let x, y, width, height: Double }

    var body: some View {
        switch page {
        case .whereItLives: MenuBarPicture()
        case .bars:
            HStack(alignment: .top, spacing: 24) {
                picture("WelcomePanel", height: 411, shown: 190, from: .top, outline: Outline(x: 0.03, y: 0.097, width: 0.94, height: 0.231))
                    .frame(width: 300)
                BarsDisplayPicture()
            }
            .frame(maxWidth: .infinity)
        case .tick: picture("WelcomePanel", height: 411, shown: 190, from: .top, outline: Outline(x: 0.40, y: 0.134, width: 0.09, height: 0.067))
        case .buttons: picture("WelcomePanel", height: 411, shown: 160, from: .bottom, outline: Outline(x: 0.02, y: 0.785, width: 0.96, height: 0.19))
        case .stats: picture("WelcomeStats", height: 590, shown: 400, from: .top, outline: Outline(x: 0.063, y: 0.286, width: 0.873, height: 0.268))
        case .suggestion:
            HStack(alignment: .top, spacing: 16) {
                picture("WelcomeStats", height: 590, shown: 190, from: .top, outline: Outline(x: 0.067, y: 0.132, width: 0.867, height: 0.149))
                    .frame(width: 300)
                VStack(spacing: 8) {
                    VerdictBox(verdict: Verdict(word: .wait, reason: .fewWindows(window: "7d", seen: 2, needed: 4)))
                    VerdictBox(verdict: Verdict(word: .stay, reason: .hitCeiling(window: "5h", hits: 1, closed: 33)))
                    VerdictBox(verdict: Verdict(word: .moveUp, reason: .tightPlan(window: "5h", hits: 6, closed: 33)))
                    VerdictBox(verdict: Verdict(word: .moveDown, reason: .plentyOfMargin(window: "7d", left: 62)))
                }
            }
            .frame(maxWidth: .infinity)
        case .accounts: AccountsPicture()
        case .settings:
            SettingsTabs(selection: .constant(.general))
                .frame(width: 460)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor, lineWidth: 3))
                .frame(maxWidth: .infinity)
        }
    }

    /// The screenshot at its natural 300 points wide, cut to `shown` points from the top or the bottom, with the part outlined.
    private func picture(_ name: String, height: Double, shown: Double, from edge: Alignment, outline: Outline) -> some View {
        ZStack(alignment: .topLeading) {
            Image(name).resizable().frame(width: 300, height: height)
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor, lineWidth: 3)
                .frame(width: 300 * outline.width, height: height * outline.height)
                .offset(x: 300 * outline.x, y: height * outline.y)
        }
        .frame(width: 300, height: shown, alignment: edge)
        .clipped()
        .frame(maxWidth: .infinity)
        .accessibilityLabel(Text(page.title))
    }
}

/// The real control of Settings, General, outlined, on the page about the bars: it says where the figure is chosen. It shows the
/// default, left, and changes nothing: the window is a picture of the app, not a second place to set it.
private struct BarsDisplayPicture: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings · General").font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            Picker("Show on the bars", selection: .constant(BarsDisplay.left)) {
                Text("Left").tag(BarsDisplay.left)
                Text("Used").tag(BarsDisplay.used)
            }
            .pickerStyle(.segmented)
            Text("Left: 65% left. Used: 35% used.").font(.caption).foregroundStyle(.secondary)
        }
        .allowsHitTesting(false)
        .padding(12)
        .frame(width: 250)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor, lineWidth: 3))
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }
}

/// Two Claude cards, a work one and a personal one, the second ringed: the app's own card drawn with invented figures,
/// as the panel would show two accounts (ADR 0014). Nothing here is read from the Mac.
private struct AccountsPicture: View {
    private static let now = Date()

    private static func card(_ id: String, title: String, plan: String, fiveHours: Double, weekly: Double) -> ProviderSnapshot {
        func window(_ spec: WindowSpec, left: Double, resetsIn: TimeInterval, tokens: Int) -> WindowUsage {
            WindowUsage(window: spec, tokens: TokenCounts(input: tokens, output: tokens / 4), remainingFraction: left,
                        source: .reported, resetsAt: now.addingTimeInterval(resetsIn), observedAt: now)
        }
        return ProviderSnapshot(
            provider: Provider(rawValue: id), title: title,
            windows: [window(.session, left: fiveHours, resetsIn: 3 * 3600 + 20 * 60, tokens: 720_000),
                      window(.week, left: weekly, resetsIn: 2 * 86_400 + 4 * 3600, tokens: 7_800_000)],
            plan: plan, quotaUpdatedAt: now)
    }

    var body: some View {
        VStack(spacing: 12) {
            ProviderCard(snapshot: Self.card("claude-work", title: "Claude · work", plan: "Max", fiveHours: 0.62, weekly: 0.38))
            ProviderCard(snapshot: Self.card("claude-personal", title: "Claude · personal", plan: "Pro", fiveHours: 0.91, weekly: 0.24))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor, lineWidth: 3))
        }
        .padding(12)
        .frame(width: 300)
        .background(RoundedRectangle(cornerRadius: 10).fill(.background))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary, lineWidth: 1))
        .frame(maxWidth: .infinity)
        .accessibilityLabel(Text("Two Claude cards, a work account and a personal one"))
    }
}

/// The menu bar with the app's own icon and its dot, ringed, on a desktop that follows the appearance.
private struct MenuBarPicture: View {
    @Environment(\.colorScheme) private var colorScheme

    private var desktop: LinearGradient {
        let colors: [Color] = colorScheme == .dark
            ? [Color(red: 0.106, green: 0.133, blue: 0.2), Color(red: 0.169, green: 0.125, blue: 0.212)]
            : [Color(red: 0.804, green: 0.851, blue: 0.925), Color(red: 0.914, green: 0.851, blue: 0.902)]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Spacer()
                RoundedRectangle(cornerRadius: 3).fill(.secondary.opacity(0.4)).frame(width: 12, height: 12)
                RoundedRectangle(cornerRadius: 2).fill(.secondary.opacity(0.4)).frame(width: 16, height: 10)
                Image(nsImage: MenuBarIcon.withDot).renderingMode(.template).resizable().scaledToFit()
                    .frame(height: 16).foregroundStyle(.primary).padding(5)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: 2))
                Text("Mon 9:41").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(.regularMaterial)
            Spacer(minLength: 0)
        }
        .frame(height: 100)
        .background(desktop)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel(Text("The menu bar, with the tokenmeter icon"))
    }
}
