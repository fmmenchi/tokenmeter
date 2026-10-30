import SwiftUI
import TokenMeterCore

/// One problem in the panel: its topic, message, a fix when there is one, Dismiss and Learn more (ADR 0030).
struct ProblemBanner: View {
    let problem: Problem
    let topicTitle: String
    let fix: FixDescriptor?
    let state: Meter.FixState?
    let onFix: () -> Void
    let onDismiss: () -> Void
    @State private var explained = false

    private static let guideBase = "https://fmmenchi.github.io/tokenmeter/"

    var body: some View {
        if state == .done {
            Text("Done: \(problem.message) is fixed.")
                .font(.caption.weight(.medium)).padding(10)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12)).foregroundStyle(.orange)
                    Text(topicTitle.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(0.5)
                        .foregroundStyle(.secondary)
                    Text(problem.message).font(.caption.weight(.semibold))
                }
                if case .failed(let reason) = state {
                    Text("Could not \(fix?.label.lowercased() ?? "fix") it: \(reason)").font(.caption2)
                } else if let detail = problem.detail {
                    Text(detail).font(.caption2).foregroundStyle(.secondary)
                }
                if explained { explanation }
                HStack(spacing: 8) {
                    if let fix {
                        Button(buttonLabel(fix), action: onFix).disabled(state == .running)
                    }
                    Button("Dismiss", action: onDismiss).disabled(state == .running)
                    Spacer()
                    Button(explained ? "Hide" : "Learn more") { explained.toggle() }
                        .buttonStyle(.plain).font(.caption2).foregroundStyle(.tint)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.15)))
        }
    }

    private func buttonLabel(_ fix: FixDescriptor) -> String {
        switch state {
        case .running: fix.runningLabel
        case .failed: "Try again"
        default: fix.label
        }
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(fix?.explanation ?? "There is no automatic fix for this one. Nothing on your Mac changes.")
            if let guide = problem.guide, let url = URL(string: Self.guideBase + guide) {
                Link("Open the guide", destination: url)
            }
        }
        .font(.caption2)
        .padding(.vertical, 6).padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
    }
}
