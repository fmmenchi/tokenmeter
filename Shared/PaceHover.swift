import SwiftUI
import TokenMeterCore

extension View {
    /// Reports whether the pointer is on this view (ADR 0002). The target is 3 points taller than the view, above and below,
    /// without moving anything: a bar is 10 points tall, a model's 4. `enabled` false never reports it. The change is animated, so
    /// what depends on it, the figure and the length of a model's bar, moves smoothly.
    func hovered(_ isHovering: Binding<Bool>, enabled: Bool = true) -> some View {
        padding(.vertical, 3).contentShape(Rectangle())
            .onHover { over in withAnimation(.easeInOut(duration: 0.15)) { isHovering.wrappedValue = enabled && over } }
            .padding(.vertical, -3)
    }
}

extension WindowUsage {
    /// The colour of the figure while the pointer is on the bar (ADR 0002): the notice colour where the quota runs out, the
    /// text colour otherwise. It only shows while the figure says a date.
    func paceFigureStyle(at now: Date) -> Color {
        guard let pace = pace(at: now) else { return .primary }
        return pace.runsOut ? .orange : .primary
    }
}
