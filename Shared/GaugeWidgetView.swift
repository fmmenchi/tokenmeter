import SwiftUI
import TokenMeterCore

/// The two sizes a widget comes in. The view is shared with the welcome wizard, which has no widget family, so it is passed in.
enum GaugeWidgetSize {
    case small
    case medium
}

/// A widget for one card (ADR 0018): its title, at most two gauges, and the limits of the models of a window. The quota and the
/// reset only: tokens, the moment a window runs out and the stats stay in the panel.
struct GaugeWidgetView: View {
    let card: ProviderSnapshot
    let size: GaugeWidgetSize
    var problemCount = 0
    @Environment(\.renderDate) private var renderDate
    @Environment(\.skinStyle) private var skin
    private var now: Date { renderDate ?? Date() }

    var body: some View {
        let gauges = WidgetGauges.gauges(of: card, at: now)
        let modelled = size == .medium ? gauges.first { !$0.models.isEmpty } : nil
        VStack(alignment: .leading, spacing: 10) {
            header(gauges)
            if gauges.isEmpty {
                Spacer(minLength: 0)
                Text("No quota read yet.").font(.system(size: 11)).captionColour()
            } else {
                // The gauges line up at the top: a column with a model's line under it is taller, and must not lift its label.
                HStack(alignment: .top, spacing: size == .small ? 12 : 22) {
                    ForEach(Array(gauges.enumerated()), id: \.offset) { _, gauge in
                        WindowGaugeView(gauge: gauge, size: size, shortReset: modelled != nil)
                            .frame(maxWidth: modelled == nil ? .infinity : nil, alignment: .leading)
                    }
                    if let modelled {
                        ModelColumn(gauge: modelled)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
    }

    private func header(_ gauges: [WidgetGauge]) -> some View {
        HStack(spacing: 6) {
            Text(card.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            if size == .medium, let plan = card.plan { PlanChip(plan: plan, font: .system(size: 11, weight: .medium)) }
            if problemCount > 0 { NoticeChip(count: problemCount) }
            Spacer(minLength: 0)
            // An old reading says its age once, for the card: the gauges are already at half strength.
            if let stale = gauges.map(\.window).first(where: { $0.isStale(at: now) }), let ago = stale.observedAgoText(at: now) {
                Text(ago).font(.system(size: 11)).captionColour()
            }
        }
    }
}

/// One window as a gauge: its label, the figure inside the ring, the reset under it. A model's limit inside the window is a thin
/// inner ring, the lowest of them; the small widget also writes it under the reset.
private struct WindowGaugeView: View {
    let gauge: WidgetGauge
    let size: GaugeWidgetSize
    /// "in 3h 20m" rather than "resets in 3h 20m": the small widget, and a medium one that gives room to its models' column.
    var shortReset = false
    @Environment(\.renderDate) private var renderDate
    @Environment(\.skinStyle) private var skin
    @Environment(\.barsDisplay) private var display
    private var now: Date { renderDate ?? Date() }
    private var window: WindowUsage { gauge.window }
    private var diameter: CGFloat { size == .small ? 54 : 66 }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(window.window.label).font(.system(size: 11, weight: .semibold)).lineLimit(1)
            ring
            Text(resetLine).font(.system(size: 11, weight: exhausted ? .semibold : .regular)).lineLimit(1)
                .modifier(NoticeOrCaption(notice: exhausted))
            if size == .small, let model = gauge.lowestModel {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(model.window.scope ?? model.window.label).font(.system(size: 11, weight: .medium)).captionColour()
                    Text(model.figureText(display, at: now)).font(.system(size: 11, weight: .bold).monospacedDigit())
                        .foregroundStyle(model.tint(in: skin))
                }
                .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var exhausted: Bool { window.source == .reported && window.remainingFraction == 0 }

    private var resetLine: String {
        guard window.remainingFraction != nil else { return "no quota" }
        if window.source == .reset { return "window reset" }
        guard let reset = window.resetText(at: now) else { return exhausted ? "awaiting update" : "" }
        return size == .small || shortReset ? reset : "resets \(reset)"
    }

    private var ring: some View {
        let line = diameter * 8 / 72
        let inner = diameter * 41 / 72
        let track = skin?.track ?? Color.primary.opacity(0.15)
        let fill = window.remainingFraction.map { display.fraction(remaining: $0) } ?? 0
        return ZStack {
            // An old or inferred reading draws its rings at half strength, as a bar does; the figure stays readable, with its "~".
            ZStack {
                Circle().stroke(track, lineWidth: line)
                Circle().trim(from: 0, to: fill)
                    .stroke(window.tint(in: skin), style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if let model = gauge.lowestModel {
                    let modelFill = model.remainingFraction.map { display.fraction(remaining: $0) } ?? 0
                    Circle().stroke(track, lineWidth: line * 3 / 8).frame(width: inner, height: inner)
                    Circle().trim(from: 0, to: max(modelFill, 0.01))
                        .stroke(model.tint(in: skin), style: StrokeStyle(lineWidth: line * 3 / 8, lineCap: .round))
                        .rotationEffect(.degrees(-90)).frame(width: inner, height: inner)
                }
            }
            .opacity(window.isApproximate(at: now) ? 0.5 : 1)
            Text(window.figureText(display, at: now))
                .font(.system(size: size == .small ? 12 : 15, weight: .semibold).monospacedDigit())
                .minimumScaleFactor(0.6).lineLimit(1)
                .frame(width: gauge.lowestModel == nil ? diameter - line * 2.5 : inner - line / 2)
        }
        .padding(line / 2)
        .frame(width: diameter, height: diameter)
    }
}

/// The medium widget's column of a window's model limits: "Weekly by model", one line each.
private struct ModelColumn: View {
    let gauge: WidgetGauge
    @Environment(\.renderDate) private var renderDate
    @Environment(\.skinStyle) private var skin
    @Environment(\.barsDisplay) private var display
    private var now: Date { renderDate ?? Date() }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(gauge.window.window.label) by model").font(.system(size: 11, weight: .semibold)).captionColour()
                .lineLimit(1).minimumScaleFactor(0.8)
            ForEach(Array(gauge.models.enumerated()), id: \.offset) { _, model in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(model.window.scope ?? model.window.label).font(.system(size: 11, weight: .medium)).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(model.figureText(display, at: now)).font(.system(size: 11, weight: .bold).monospacedDigit())
                        .foregroundStyle(model.tint(in: skin))
                }
            }
        }
        .padding(.leading, 14)
        .overlay(alignment: .leading) { Rectangle().fill(skin?.track ?? Color.primary.opacity(0.15)).frame(width: 1) }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The notice colour for an exhausted window's reset, the caption colour otherwise.
private struct NoticeOrCaption: ViewModifier {
    let notice: Bool
    @Environment(\.skinStyle) private var skin

    func body(content: Content) -> some View {
        if notice {
            content.foregroundStyle(skin?.middle ?? .orange)
        } else {
            content.captionColour()
        }
    }
}
