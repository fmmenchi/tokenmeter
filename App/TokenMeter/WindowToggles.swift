import SwiftUI

/// The windows a provider's card can show, one row each with a switch, chosen independently (ADR 0006). The rows are the
/// windows the data lists, so a plan with one has one. A model's limit is a row under the window it is part of, indented and
/// joined by the same bracket as in the bars, with the same switch; it is off, and cannot be chosen, while its window is off.
/// The last window that is on cannot be turned off: the provider's own switch is what hides it. While the provider is off
/// the list stays, dimmed and not touchable, with the choice it has.
struct WindowToggles: View {
    struct Row: Identifiable {
        let id: String
        let label: String
        let isOn: Bool
        var models: [Row] = []
    }

    let rows: [Row]
    /// False while the provider is off: the list is dimmed and cannot be touched.
    let isActive: Bool
    let onToggle: (String) -> Void
    let onToggleModel: (String) -> Void

    /// The row that is the only one on, which cannot be turned off.
    private var lockedID: String? {
        let on = rows.filter(\.isOn)
        return on.count == 1 ? on[0].id : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rows) { row in
                line(row, isLocked: row.id == lockedID, isModel: false, action: { onToggle(row.id) })
                    .help(row.id == lockedID ? "The last window stays on: turn the provider off to hide it" : "")
                ForEach(row.models) { model in
                    HStack(spacing: 6) {
                        Bracket().frame(width: 8, height: 8).offset(y: -6)
                        line(model, isLocked: false, isModel: true, action: { onToggleModel(model.id) })
                            .disabled(!row.isOn)
                            .opacity(row.isOn ? 1 : 0.45)
                    }
                    .padding(.leading, 16)
                    .help("Part of \(row.label): shown only with it")
                }
            }
        }
        .padding(.leading, 36)
        .disabled(!isActive)
        .opacity(isActive ? 1 : 0.45)
    }

    private func line(_ row: Row, isLocked: Bool, isModel: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Text(row.label).font(isModel ? .callout : .body)
            Spacer()
            Toggle(row.label, isOn: Binding(get: { row.isOn }, set: { _ in action() }))
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(isLocked)
        }
    }

    /// The elbow that joins a model to its window, as in ScopedWindowRow.
    private struct Bracket: View {
        var body: some View {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 5))
                path.addQuadCurve(to: CGPoint(x: 3, y: 8), control: CGPoint(x: 0, y: 8))
                path.addLine(to: CGPoint(x: 8, y: 8))
            }
            .stroke(Color.secondary.opacity(0.6), lineWidth: 1)
        }
    }
}
