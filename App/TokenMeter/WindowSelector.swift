import SwiftUI

/// The windows a provider's card can show, one segment each, chosen independently (ADR 0037). The segments are the windows
/// the data lists, so a plan with one has one. A model's limit is a sub-segment under the window it is part of, joined by the
/// same bracket as in the bars; it is off, and cannot be chosen, while its window is off. A chosen segment is the accent colour.
struct WindowSelector: View {
    struct Segment: Identifiable {
        let id: String
        let label: String
        let isOn: Bool
        var models: [Segment] = []
        /// A model segment cannot be chosen while its window is off.
        var isEnabled = true
    }

    let segments: [Segment]
    let onToggle: (String) -> Void
    let onToggleModel: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 2) {
                ForEach(segments) { segment in
                    chip(segment) { onToggle(segment.id) }
                }
            }
            .padding(2)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.07)))
            if segments.contains(where: { !$0.models.isEmpty }) {
                // The same columns as above, so a model sits under its window.
                HStack(alignment: .top, spacing: 4) {
                    ForEach(segments) { segment in
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(segment.models) { model in
                                HStack(alignment: .center, spacing: 4) {
                                    Bracket().frame(width: 8, height: 8).offset(y: -6)
                                    chip(model) { onToggleModel(model.id) }
                                        .padding(2)
                                        .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.07)))
                                }
                                .help("Part of \(segment.label): shown only with it")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func chip(_ segment: Segment, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(segment.label)
                .font(.caption).fontWeight(segment.isOn ? .semibold : .regular)
                .foregroundStyle(segment.isOn ? Color.white : Color.primary)
                .padding(.vertical, 3).padding(.horizontal, 10)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 5).fill(segment.isOn ? Color.accentColor : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!segment.isEnabled)
        .opacity(segment.isEnabled ? 1 : 0.45)
        .accessibilityAddTraits(segment.isOn ? .isSelected : [])
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
