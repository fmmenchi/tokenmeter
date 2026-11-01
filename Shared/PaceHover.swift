import SwiftUI
import TokenMeterCore

extension View {
    /// Reports whether the pointer is on this view (ADR 0039). The target is 3 points taller than the view, above and below,
    /// without moving anything: a bar is 10 points tall, a model's 4. `enabled` false never reports it.
    func hovered(_ isHovering: Binding<Bool>, enabled: Bool = true) -> some View {
        padding(.vertical, 3).contentShape(Rectangle())
            .onHover { isHovering.wrappedValue = enabled && $0 }
            .padding(.vertical, -3)
    }
}

extension WindowUsage {
    /// The colour of the figure while the pointer is on the bar (ADR 0039): the notice colour where the quota runs out, the
    /// quiet one for a reading that is out of date, the text colour otherwise.
    func paceFigureStyle(at now: Date) -> Color {
        guard let pace = pace(at: now) else { return .primary }
        return pace.runsOut ? .orange : pace.isStale ? .secondary : .primary
    }
}
