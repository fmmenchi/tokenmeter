import SwiftUI
import TokenMeterCore

// A menu for the author's own builds, to see the seasonal easter eggs outside their week. It exists only in a debug build, the one
// `scripts/preview.sh` makes: the whole file is compiled out of a release, so nobody else can reach it. It is a deliberate exception
// to the rule of no mock modes, asked for by the author, and it forces nothing but which event the panel is drawn for.
#if DEBUG
@MainActor
enum DevOptions {
    /// The event the panel is forced to carry, or nil for the real calendar. It lasts until the app quits.
    static var occasion: Occasion?
}

struct DevMenu: View {
    let meter: Meter

    var body: some View {
        Menu {
            Section("Easter eggs") {
                choice("Real calendar", nil)
                choice("Halloween", .halloween)
                choice("Christmas", .christmas)
                choice("Easter", .easter)
            }
            Button("Pick again") { meter.rollEasterEgg() }
        } label: {
            Image(systemName: "hammer").frame(width: 28, height: 24)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Developer menu: only in a debug build")
        .accessibilityLabel("Developer menu")
    }

    private func choice(_ title: String, _ occasion: Occasion?) -> some View {
        Button {
            DevOptions.occasion = occasion
            meter.rollEasterEgg()
        } label: {
            if DevOptions.occasion == occasion { Label(title, systemImage: "checkmark") } else { Text(title) }
        }
    }
}
#endif
