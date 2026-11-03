import SwiftUI
import TokenMeterCore

/// The six pages of the welcome wizard: a title, a short text, a picture with the part outlined, and the footer.
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
            .frame(width: 560, height: 480)
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
        case .stats: "The stats and the suggestion"
        case .settings: "Settings has five tabs"
        }
    }

    var text: String {
        switch self {
        case .whereItLives:
            "It lives in the menu bar: click the gauge icon to see how much of your Claude and ChatGPT plans is left. A small dot on the icon means something needs a look: a problem the panel lists, or an update to install."
        case .bars:
            "Green is plenty left, orange under 40%, red under 15%. tokenmeter reads the files that Claude Code and the Codex CLI leave on this Mac, with no API calls, no login and no key, so the bars update as you use them: at the first launch, until you do, they stay empty."
        case .tick:
            "Where the bar would be at a steady use. If the bar ends before it, the quota runs out before the reset."
        case .buttons:
            "The lines above say how fresh each quota is. Refresh reads everything now and asks Claude Code for your account's usage; on its own tokenmeter reads every minute. The chart switches to the stats, the gear opens Settings, power quits."
        case .stats:
            "How each window ended and which models used your tokens. The goal: see whether your plan fits the way you use it. The word at the top is the app's suggestion, from percentages only: it never says Move up and never looks at tokens."
        case .settings:
            "General, Providers, Skin, Notifications and Updates. Choose a skin and turn on notifications there. The daily check for updates is in Updates, where you can turn it off. You can see this tour again from General."
        }
    }
}

/// The picture of a page: the real icon, a screenshot of the panel with a part outlined, or the real tabs of Settings.
private struct WelcomePicture: View {
    let page: WelcomeState.Page

    /// A part of a screenshot, as fractions of its width and height.
    private struct Outline { let x, y, width, height: Double }

    var body: some View {
        switch page {
        case .whereItLives:
            HStack {
                Spacer()
                Image(nsImage: MenuBarIcon.withDot).renderingMode(.template).resizable().interpolation(.high).scaledToFit().frame(height: 44).foregroundStyle(.primary)
                Spacer()
            }
            .frame(height: 90)
            .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary))
        case .bars: picture("WelcomePanel", height: 430, shown: 240, from: .top, outline: Outline(x: 0.05, y: 0.095, width: 0.9, height: 0.275))
        case .tick: picture("WelcomePanel", height: 430, shown: 240, from: .top, outline: Outline(x: 0.40, y: 0.125, width: 0.08, height: 0.065))
        case .buttons: picture("WelcomePanel", height: 430, shown: 240, from: .bottom, outline: Outline(x: 0.03, y: 0.765, width: 0.9, height: 0.2))
        case .stats: picture("WelcomeStats", height: 610, shown: 240, from: .top, outline: Outline(x: 0.07, y: 0.125, width: 0.84, height: 0.125))
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
