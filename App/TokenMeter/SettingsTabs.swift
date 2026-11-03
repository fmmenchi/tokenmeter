import SwiftUI

/// The sections of Settings, one tab each (feature "settings in tabs").
enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case providers
    case skin
    case notifications
    case updates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .providers: "Providers"
        case .skin: "Skin"
        case .notifications: "Notifications"
        case .updates: "Updates"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .providers: "list.bullet"
        case .skin: "paintpalette"
        case .notifications: "bell"
        case .updates: "arrow.down.circle"
        }
    }
}

/// The row of tabs under the title bar: an icon over a name, the chosen one in the accent colour on a soft fill, as in the system
/// settings of the Mac. Drawn by the app because a `TabView` in a plain window is a segmented control, not this.
struct SettingsTabs: View {
    @Binding var selection: SettingsTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(SettingsTab.allCases) { tab in
                let chosen = tab == selection
                Button { selection = tab } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbol).font(.system(size: 16))
                        Text(tab.title).font(.caption2.weight(.medium))
                    }
                    .frame(minWidth: 70)
                    .padding(.vertical, 6).padding(.horizontal, 6)
                    .foregroundStyle(chosen ? Color.accentColor : Color.secondary)
                    .background(RoundedRectangle(cornerRadius: 8).fill(chosen ? Color.primary.opacity(0.1) : Color.clear))
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(chosen ? .isSelected : [])
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }
}
