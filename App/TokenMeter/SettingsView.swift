import AppKit
import SwiftUI
import TokenMeterCore

enum SettingsWindow {
    static let id = "settings"
}

struct SettingsView: View {
    let meter: Meter

    private var claudeStatusText: String {
        guard meter.autoSetUpClaude else { return "Off: tokenmeter does not touch Claude Code's settings." }
        switch meter.claudeStatusLine {
        case .set: return "Done: Claude's status line now feeds tokenmeter."
        case .alreadySet: return "Claude's status line already feeds tokenmeter."
        case .notInstalled: return "Claude Code not found. Checked again at every launch."
        case .wrapped: return "Your status line is wrapped: it still prints as before, and also feeds tokenmeter."
        case .otherStatusLine: return "Another status line is in use and was left alone. Wrap it from the panel to feed tokenmeter too."
        case .unreadableSettings: return "Claude's settings.json could not be read, so it was left alone."
        case nil: return "Checked at every launch; never replaces a status line you set."
        }
    }

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: Binding(
                get: { meter.launchAtLogin },
                set: { meter.setLaunchAtLogin($0) }))
            Text("tokenmeter registers itself the first time it runs. Turning this off is respected: it will not turn itself back on.")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("Set up the Claude quota automatically", isOn: Binding(
                get: { meter.autoSetUpClaude },
                set: { meter.setAutoSetUpClaude($0) }))
            Text(claudeStatusText)
                .font(.caption).foregroundStyle(.secondary)
            if meter.autoSetUpClaude {
                switch meter.claudeStatusLine {
                case .wrapped: Button("Restore original") { meter.restoreClaudeStatusLine() }
                default: EmptyView()
                }
            }
            Section("Providers") {
                Text("Drag a provider, or use the arrows, to reorder its card. Choose the windows each card shows.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(Array(meter.cardProviders.enumerated()), id: \.element.id) { index, provider in
                    ProviderRow(
                        provider: provider, isFirst: index == 0, isLast: index == meter.cardProviders.count - 1,
                        onChange: { meter.setShownWindows($0, for: provider.id) },
                        onMove: { meter.moveProvider(provider.id, by: $0) })
                        .draggable(provider.id)
                        .dropDestination(for: String.self) { ids, _ in
                            guard let id = ids.first else { return false }
                            meter.moveProvider(id, onto: provider.id)
                            return true
                        }
                }
                Text("The percentage in the menu bar counts only the windows you show.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 380)
        .padding()
        .onDisappear { NSApplication.shared.setActivationPolicy(.accessory) }
    }
}

/// One provider in the list: its name and which windows its card shows. Two windows are a choice of one or both; more
/// than two are a menu of checkmarks, so any window of any provider can be chosen (ADR 0035).
private struct ProviderRow: View {
    let provider: Meter.CardProvider
    let isFirst: Bool
    let isLast: Bool
    let onChange: (Set<String>) -> Void
    let onMove: (Int) -> Void

    private static let all = "all"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary).accessibilityHidden(true)
                Text(provider.title).lineLimit(1).layoutPriority(1)
                Spacer()
                Button { onMove(-1) } label: { Image(systemName: "chevron.up") }
                    .buttonStyle(.borderless).disabled(isFirst).accessibilityLabel("Move \(provider.title) up")
                Button { onMove(1) } label: { Image(systemName: "chevron.down") }
                    .buttonStyle(.borderless).disabled(isLast).accessibilityLabel("Move \(provider.title) down")
            }
            if provider.windows.count == 2 {
                Picker(provider.title, selection: Binding(
                    get: { provider.shown.count == provider.windows.count ? Self.all : provider.shown.first ?? Self.all },
                    set: { onChange($0 == Self.all ? Set(provider.windows) : [$0]) })) {
                    ForEach(provider.windows, id: \.self) { name in Text(WindowSpec(name: name, duration: 0).label).tag(name) }
                    Text("Both").tag(Self.all)
                }
                .pickerStyle(.segmented).labelsHidden()
            } else if provider.windows.count > 2 {
                Menu("Windows") {
                    ForEach(provider.windows, id: \.self) { name in
                        Toggle(WindowSpec(name: name, duration: 0).label, isOn: Binding(
                            get: { provider.shown.contains(name) },
                            set: { on in onChange(on ? provider.shown.union([name]) : provider.shown.subtracting([name])) }))
                    }
                }
                .fixedSize()
            }
        }
    }
}
