import SwiftUI
import TokenMeterCore

struct MenuContent: View {
    let meter: Meter
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if case .available(let version, let notes) = meter.updater.state {
                UpdateNotice(version: version, notes: notes) { meter.updater.checkNow() }
            }
            ForEach(meter.problems) { problem in
                ProblemBanner(
                    problem: problem, topicTitle: title(of: problem.topic), fix: meter.fixDescriptor(for: problem),
                    state: meter.fixStates[problem.id], onFix: { meter.runFix(problem) },
                    onDismiss: { meter.dismiss(problem) })
            }
            if meter.showsStats {
                StatsView(meter: meter)
            } else if let snapshot = meter.snapshot {
                ForEach(snapshot.providers, id: \.provider) {
                    ProviderCard(snapshot: $0, problemCount: snapshot.problemCount(for: $0), showsPace: true)
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
                IconButton(systemName: "gearshape", label: "Settings") {
                    // An accessory app cannot show a regular window in front: become a regular app
                    // while Settings is open (SettingsView puts it back on disappear).
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    openWindow(id: SettingsWindow.id)
                }
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
            meter.rollEasterEgg()
        }
        .environment(\.easterEgg, meter.easterEgg)
        .task { await meter.refresh() }
        // The skin's own colour in place of the window's translucent material (ADR 0013); System keeps the material.
        .background { PanelFill() }
        .skinned(meter.skin)
    }

    private func title(of topic: String) -> String {
        meter.snapshot?.providers.first { $0.provider.rawValue == topic }?.title
            ?? (topic == Problem.general ? "General" : topic)
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
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Group {
                if isBusy { ProgressView().controlSize(.small) } else { Image(systemName: systemName) }
            }
            .frame(width: 28, height: 24)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(hovering ? 0.14 : 0.07)))
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}
