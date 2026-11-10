import SwiftUI
import TokenMeterCore

/// A provider's card on the unlocked panel (ADR 0014): the same block, with an arrow up and down and an eye in its title
/// row, an eye on each window and each model's limit, and the whole card draggable onto another. A hidden card stays in
/// sight, dimmed, with a crossed eye to show it again. The widget never draws this: it has no interaction.
struct ArrangeableCard: View {
    let item: Meter.Arrangeable
    let isFirst: Bool
    let isLast: Bool
    /// False on the last shown card: one provider always stays (ADR 0006).
    let canHide: Bool
    let isDropTarget: Bool
    let onMove: (Int) -> Void
    let onToggleShown: () -> Void
    let onToggleWindow: (String) -> Void
    let onToggleModel: (String, Bool) -> Void
    @Environment(\.skinStyle) private var skin
    @Environment(\.barsDisplay) private var display
    private var now: Date { Date() }

    private var card: Meter.CardProvider { item.card }
    private var snapshot: ProviderSnapshot { item.snapshot }
    /// The one window that is on, which cannot be turned off: the card's eye is what hides the provider (ADR 0006).
    private var lockedWindow: String? { card.shown.count == 1 ? card.shown.first : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(snapshot.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                if let plan = snapshot.plan { PlanChip(plan: plan) }
                Spacer(minLength: 0)
                arrow("chevron.up", label: "Move \(snapshot.title) up", disabled: isFirst) { onMove(-1) }
                arrow("chevron.down", label: "Move \(snapshot.title) down", disabled: isLast) { onMove(1) }
                Eye(isOn: card.isShown, label: card.isShown ? "Hide \(snapshot.title)" : "Show \(snapshot.title)",
                    disabled: card.isShown && !canHide, help: card.isShown && !canHide ? "One provider always stays" : "",
                    action: onToggleShown)
            }
            ForEach(snapshot.windows.filter { $0.window.scope == nil }, id: \.window.id) { window in
                let usage = snapshot.resolved(window, at: now)
                let id = window.window.id
                let shown = card.shown.contains(id)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(usage.window.label).font(.caption.weight(.medium))
                        Spacer()
                        Text(figure(of: usage))
                            .font(.caption.bold().monospacedDigit())
                        let isLocked = id == lockedWindow
                        let eyeLabel: String = shown ? "Hide \(usage.window.label)" : "Show \(usage.window.label)"
                        let eyeHelp: String = isLocked ? "The last window stays on: hide the card instead" : ""
                        Eye(isOn: shown, label: eyeLabel, disabled: isLocked, help: eyeHelp, action: { onToggleWindow(id) })
                    }
                    QuotaBar(fraction: usage.remainingFraction.map { display.fraction(remaining: $0) },
                             tint: usage.tint(in: skin), faded: usage.isApproximate(at: now), emptyIsEmpty: display == .used)
                    ForEach(card.models.filter { $0.parent == id }) { model in
                        if let usage = snapshot.windows.first(where: { $0.window.id == model.id }).map({ snapshot.resolved($0, at: now) }) {
                            let on = card.shownModels.contains(model.id)
                            HStack(spacing: 6) {
                                ScopedWindowRow(usage: usage)
                                Eye(isOn: on, label: on ? "Hide \(model.label)" : "Show \(model.label)", disabled: !shown,
                                    help: shown ? "" : "Part of \(usage.window.label): shown only with it", action: { onToggleModel(model.id, !on) })
                            }
                        }
                    }
                    Text(usage.detailText(at: now)).font(.caption2).captionColour()
                }
                .opacity(shown ? 1 : 0.45)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardChrome()
        .opacity(card.isShown ? 1 : 0.45)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.accentColor, lineWidth: isDropTarget ? 2 : 0))
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(isDropTarget ? 0.12 : 0)))
        .help("Drag to reorder")
    }

    /// The figure of a window in the card: what is left, or "unknown" when no quota was seen.
    private func figure(of usage: WindowUsage) -> String {
        if usage.remainingFraction == nil { return "unknown" }
        return "\(usage.figureText(display, at: now)) \(display.word)"
    }

    private func arrow(_ symbol: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 10, weight: .semibold)).frame(width: 16, height: 16) }
            .buttonStyle(.plain).foregroundStyle(.tint).disabled(disabled).opacity(disabled ? 0.35 : 1)
            .accessibilityLabel(label)
    }
}

/// An eye that shows, a crossed one that hides: the switch of the unlocked panel.
private struct Eye: View {
    let isOn: Bool
    let label: String
    var disabled = false
    var help = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isOn ? "eye" : "eye.slash").font(.system(size: 10))
                .frame(width: 18, height: 16)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.07)))
        }
        .buttonStyle(.plain).disabled(disabled).opacity(disabled ? 0.35 : 1)
        .help(help).accessibilityLabel(label)
    }
}

/// Moves the dragged card onto the one it is dropped on. A card is never a target for itself.
struct CardDropDelegate: DropDelegate {
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
