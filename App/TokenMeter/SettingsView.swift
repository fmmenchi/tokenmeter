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
    /// The section shown. The window opens on General.
    @State private var tab = SettingsTab.general

    var body: some View {
        VStack(spacing: 0) {
            SettingsTabs(selection: $tab)
            Divider()
            // A fixed height, so the window does not jump when the tab changes; a section taller than it scrolls.
            Form { section }
                .formStyle(.grouped)
                .frame(height: 410)
        }
        .frame(width: 500)
        .onDisappear { NSApplication.shared.setActivationPolicy(.accessory) }
    }

    @ViewBuilder private var section: some View {
        switch tab {
        case .general: general
        case .accounts: AccountsTab(meter: meter)
        case .skin: SkinGroup(meter: meter)
        case .notifications: NotificationsGroup(meter: meter)
        case .updates: UpdatesGroup(updater: meter.updater)
        }
    }

    @ViewBuilder private var general: some View {
        Group {
            Toggle("Launch at login", isOn: Binding(
                get: { meter.launchAtLogin },
                set: { meter.setLaunchAtLogin($0) }))
            Text("tokenmeter registers itself the first time it runs. Turning this off is respected: it will not turn itself back on.")
                .font(.caption).foregroundStyle(.secondary)
            ClaudeSetupGroup(meter: meter)
            Button("Show the welcome again") { WelcomeWindow.shared.showAgain() }
        }
    }

    @ViewBuilder private var providers: some View {
        Group {
            Section("Providers") {
                Text("Drag a provider, or use the arrows, to reorder its card. Turn a provider off to take its card off the panel and the widget. Choose the windows each card shows.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(Array(meter.cardProviders.enumerated()), id: \.element.id) { index, provider in
                    ProviderRow(
                        provider: provider, isFirst: index == 0, isLast: index == meter.cardProviders.count - 1,
                        isDropTarget: dropTarget == provider.id,
                        canHide: !provider.isShown || meter.cardProviders.filter(\.isShown).count > 1,
                        onChange: { meter.setShownWindows($0, for: provider.id) },
                        onChangeModel: { meter.setModel($0, shown: $1, for: provider.id) },
                        onMove: { meter.moveProvider(provider.id, by: $0) },
                        onToggleShown: { meter.setProviderShown(!provider.isShown, for: provider.id) },
                        onDragStart: { dragging = provider.id })
                        .onDrop(of: [.plainText], delegate: ProviderDropDelegate(
                            target: provider.id, dragging: $dragging, dropTarget: $dropTarget,
                            move: { meter.moveProvider($0, onto: $1) }))
                }
            }
        }
    }
}

/// One provider in the list: its name with a switch that shows or hides its card, and the windows it shows, chosen in a
/// `WindowToggles` with a switch for each window the data lists (ADR 0006, 0002, 0006).
private struct ProviderRow: View {
    let provider: Meter.CardProvider
    let isFirst: Bool
    let isLast: Bool
    let isDropTarget: Bool
    let canHide: Bool
    let onChange: (Set<String>) -> Void
    let onChangeModel: (String, Bool) -> Void
    let onMove: (Int) -> Void
    let onToggleShown: () -> Void
    let onDragStart: () -> Void

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
                Text(provider.title).lineLimit(1).layoutPriority(1).opacity(provider.isShown ? 1 : 0.45)
                Spacer()
                Button { onMove(-1) } label: { Image(systemName: "chevron.up") }
                    .buttonStyle(.borderless).disabled(isFirst).accessibilityLabel("Move \(provider.title) up")
                Button { onMove(1) } label: { Image(systemName: "chevron.down") }
                    .buttonStyle(.borderless).disabled(isLast).accessibilityLabel("Move \(provider.title) down")
                Toggle(provider.title, isOn: Binding(get: { provider.isShown }, set: { _ in onToggleShown() }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(!canHide)
                    .help(canHide ? "" : "One provider always stays on")
            }
            // A provider that is off keeps its list, dimmed, with the choice it has (ADR 0006).
            WindowToggles(
                rows: provider.windows.map { id in
                    WindowToggles.Row(
                        id: id, label: WindowSpec(name: id, duration: 0).label, isOn: provider.shown.contains(id),
                        models: provider.models.filter { $0.parent == id }.map { model in
                            WindowToggles.Row(id: model.id, label: model.label, isOn: provider.shownModels.contains(model.id))
                        })
                },
                isActive: provider.isShown,
                onToggle: { id in
                    let on = provider.shown
                    onChange(on.contains(id) ? on.subtracting([id]) : on.union([id]))
                },
                onToggleModel: { id in onChangeModel(id, !provider.shownModels.contains(id)) })
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
