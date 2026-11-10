import SwiftUI
import TokenMeterCore

struct MenuContent: View {
    let meter: Meter
    @Environment(\.openWindow) private var openWindow
    /// The lock (ADR 0014): open, the cards show their arrows and eyes and drag; it closes with the panel.
    @State private var isUnlocked = false
    @State private var dragging: String?
    @State private var dropTarget: String?
    @State private var usageOpenError = ""
    @State private var showsUsageOpenError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if case .available(let version, let notes) = meter.updater.state {
                UpdateNotice(version: version, notes: notes) { meter.updater.checkNow() }
            }
            ForEach(meter.problems) { problem in
                ProblemBanner(
                    problem: problem, topicTitle: title(of: problem.topic), fix: meter.fixDescriptor(for: problem),
                    state: meter.fixStates[problem.id], onFix: { meter.runFix(problem) },
                    onDismiss: { meter.dismiss(problem) },
                    action: meter.foundFolder(for: problem).map { found in
                        // Add it: the sheet of Settings › Accounts, on this folder (ADR 0014).
                        ("Add it", { meter.pendingAccount = found; openSettings() })
                    })
            }
            if meter.showsStats {
                StatsView(meter: meter)
            } else if isUnlocked {
                let items = meter.arrangeable
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    ArrangeableCard(
                        item: item, isFirst: index == 0, isLast: index == items.count - 1,
                        canHide: items.filter(\.card.isShown).count > 1, isDropTarget: dropTarget == item.id,
                        onMove: { meter.moveProvider(item.id, by: $0) },
                        onToggleShown: { meter.setProviderShown(!item.card.isShown, for: item.id) },
                        onToggleWindow: { id in
                            let on = item.card.shown
                            meter.setShownWindows(on.contains(id) ? on.subtracting([id]) : on.union([id]), for: item.id)
                        },
                        onToggleModel: { meter.setModel($0, shown: $1, for: item.id) })
                        .onDrag {
                            dragging = item.id
                            return NSItemProvider(object: item.id as NSString)
                        }
                        .onDrop(of: [.plainText], delegate: CardDropDelegate(
                            target: item.id, dragging: $dragging, dropTarget: $dropTarget,
                            move: { meter.moveProvider($0, onto: $1) }))
                }
                Text("Drag a card to reorder it. The eye hides it; a hidden card stays here, dimmed, until the lock closes.")
                    .font(.caption2).captionColour().multilineTextAlignment(.center).frame(maxWidth: .infinity)
            } else if let snapshot = meter.snapshot {
                ForEach(snapshot.providers, id: \.provider) { provider in
                    ProviderCard(snapshot: provider, problemCount: snapshot.problemCount(for: provider), showsPace: true,
                                 modelUsageAction: meter.claudeAccount(for: provider.provider).map { account in
                                     ("Open /usage", { openClaudeUsage(for: account) })
                                 })
                }
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(snapshot.providers, id: \.provider) { provider in
                        if let quotaAge = provider.quotaUpdatedAt {
                            Text("\(provider.title) quota from \(quotaAge, style: .relative) ago")
                        } else if let hint = provider.setupHint {
                            Text(hint)
                        }
                    }
                }
                .font(.caption2).captionColour()
            } else {
                ProgressView()
            }
            Divider()
            HStack(spacing: 6) {
                IconButton(systemName: "arrow.clockwise", label: "Refresh", isBusy: meter.isRefreshing) {
                    Task { await meter.refresh(userInitiated: true) }
                }
                .disabled(meter.isRefreshing)
                // The icon says where it takes you: to the stats from the quota, back to the quota from the stats (ADR 0010).
                IconButton(systemName: meter.showsStats ? "speedometer" : "chart.bar.fill",
                           label: meter.showsStats ? "Show the current quota" : "Show the stats") {
                    meter.showsStats.toggle()
                }
                IconButton(systemName: "gearshape", label: "Settings", action: openSettings)
                // The lock (ADR 0014): nothing drags and nothing hides while it is closed.
                IconButton(systemName: isUnlocked ? "lock.open" : "lock",
                           label: isUnlocked ? "Lock the cards" : "Unlock the cards to reorder or hide them",
                           isOn: isUnlocked) {
                    isUnlocked.toggle()
                    if !isUnlocked { dragging = nil; dropTarget = nil }
                }
                .disabled(meter.showsStats)
                #if DEBUG
                DevMenu(meter: meter)
                #endif
                Spacer()
                IconButton(systemName: "power", label: "Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(12)
        .frame(width: 300)
        // Every time the panel opens it shows the current quota: the stats are for when they are asked for.
        .onAppear {
            meter.showsStats = false
            isUnlocked = false
            meter.rollEasterEgg()
        }
        .onDisappear { isUnlocked = false }
        .environment(\.easterEgg, meter.easterEgg)
        .task { await meter.refresh() }
        // The skin's own colour in place of the window's translucent material (ADR 0013); System keeps the material.
        .background { PanelFill() }
        .skinned(meter.skin)
        .environment(\.barsDisplay, meter.barsDisplay)
        .alert("Could not open Claude usage", isPresented: $showsUsageOpenError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(usageOpenError)
        }
    }

    /// An accessory app cannot show a regular window in front: become a regular app while Settings is open (SettingsView
    /// puts it back on disappear).
    private func openSettings() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        openWindow(id: SettingsWindow.id)
    }

    private func title(of topic: String) -> String {
        meter.snapshot?.providers.first { $0.provider.rawValue == topic }?.title
            ?? (topic == Problem.general ? "General" : topic)
    }

    private func openClaudeUsage(for account: ClaudeStatusLine.Account) {
        Task {
            do {
                let command = try await Task.detached(priority: .userInitiated) {
                    try ClaudeUsageCommand.write(for: account)
                }.value
                guard NSWorkspace.shared.open(command) else {
                    usageOpenError = "Terminal could not open the Claude usage command."
                    showsUsageOpenError = true
                    return
                }
            } catch {
                usageOpenError = error.localizedDescription
                showsUsageOpenError = true
            }
        }
    }
}

/// The colour of the skin behind the panel, nothing for System.
private struct PanelFill: View {
    @Environment(\.skinStyle) private var skin

    var body: some View {
        if let skin { skin.panel }
    }
}

/// A button that is an icon, with the name a screen reader says and the tooltip a pointer shows.
private struct IconButton: View {
    let systemName: String
    let label: String
    var isBusy = false
    /// True while what the button toggles is on: the lock, open. Drawn in the accent colour on its soft fill.
    var isOn = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Group {
                if isBusy { ProgressView().controlSize(.small) } else { Image(systemName: systemName) }
            }
            .frame(width: 28, height: 24)
            .foregroundStyle(isOn ? Color.accentColor : Color.primary)
            .background(RoundedRectangle(cornerRadius: 6).fill(
                isOn ? Color.accentColor.opacity(hovering ? 0.22 : 0.15) : Color.primary.opacity(hovering ? 0.14 : 0.07)))
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}
