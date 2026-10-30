import AppKit
import SwiftUI
import TokenMeterCore

enum SettingsWindow {
    static let id = "settings"
}

struct SettingsView: View {
    let meter: Meter
    /// The provider a dragged card is over: its row is outlined, so it is clear where the card will land.
    @State private var dropTarget: String?
    /// The provider whose handle was grabbed: it is never a drop target for itself.
    @State private var dragging: String?

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
                        isDropTarget: dropTarget == provider.id,
                        onChange: { meter.setShownWindows($0, for: provider.id) },
                        onMove: { meter.moveProvider(provider.id, by: $0) },
                        onDragStart: { dragging = provider.id })
                        .onDrop(of: [.plainText], delegate: ProviderDropDelegate(
                            target: provider.id, dragging: $dragging, dropTarget: $dropTarget,
                            move: { meter.moveProvider($0, onto: $1) }))
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
    let isDropTarget: Bool
    let onChange: (Set<String>) -> Void
    let onMove: (Int) -> Void
    let onDragStart: () -> Void

    private static let all = "all"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                DragHandle()
                    .onDrag {
                        onDragStart()
                        return NSItemProvider(object: provider.id as NSString)
                    } preview: {
                        Text(provider.title).padding(.horizontal, 10).padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 6).fill(.background))
                    }
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
        .padding(isDropTarget ? 6 : 0)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(isDropTarget ? 0.12 : 0)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.accentColor, lineWidth: isDropTarget ? 2 : 0))
    }
}

/// Moves the dragged card onto the one it is dropped on. A card is never a target for itself, so it is not outlined
/// while it is over its own row.
private struct ProviderDropDelegate: DropDelegate {
    let target: String
    @Binding var dragging: String?
    @Binding var dropTarget: String?
    let move: (String, String) -> Void

    func validateDrop(info: DropInfo) -> Bool { dragging != nil && dragging != target }

    func dropEntered(info: DropInfo) {
        if dragging != target { dropTarget = target }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: dragging == target ? .cancel : .move) }

    func dropExited(info: DropInfo) {
        if dropTarget == target { dropTarget = nil }
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { dragging = nil; dropTarget = nil }
        guard let source = dragging, source != target else { return false }
        move(source, target)
        return true
    }
}
