import SwiftUI
import TokenMeterCore

/// The shape of what is coming, while it comes: in place of a spinner, the panel draws its cards with nothing in them, in the skin's
/// track colour and with the skin's own bars, and no figure is made up. It pulses slowly, and stands still with Reduce Motion. It is
/// drawn only after a moment, so a wait shorter than that (the stats after a restart, read from what is kept) does not flash.
struct LoadingSkeleton: View {
    enum Kind {
        /// The quota cards, before the first snapshot.
        case quota
        /// The stats cards: the first open, the others closed.
        case stats
    }

    let kind: Kind
    /// How many cards: the providers shown when they are known, else two.
    var count = 2
    /// A line above the cards when the wait is long and worth saying, as the first reading of the logs.
    var caption: String?

    @State private var shown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if shown {
                if let caption {
                    Text(caption).font(.caption).captionColour().fixedSize(horizontal: false, vertical: true)
                }
                ForEach(0..<max(count, 1), id: \.self) { index in
                    switch kind {
                    case .quota: QuotaCardSkeleton()
                    case .stats: StatsCardSkeleton(isOpen: index == 0)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption ?? "Loading")
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            shown = true
        }
    }
}

/// A grey shape in the skin's track colour, pulsing with the others.
private struct Bone: View {
    var width: CGFloat?
    var height: CGFloat
    var radius: CGFloat = 3
    @Environment(\.skinStyle) private var skin

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(skin?.track ?? Color.primary.opacity(0.15))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}

/// The slow fade of a skeleton, the same for every bone of a card. Still with Reduce Motion.
private struct Pulse: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    func body(content: Content) -> some View {
        content
            .opacity(dim ? 0.4 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { dim = true }
            }
    }
}

/// The title row of a card: a name and a plan chip.
private struct TitleBones: View {
    var body: some View {
        HStack(spacing: 6) {
            Bone(width: 52, height: 11)
            Bone(width: 38, height: 12, radius: 6)
        }
    }
}

/// A provider card with nothing in it: the name, and two windows with their label, figure, bar and detail line.
private struct QuotaCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TitleBones()
            ForEach([150.0, 128.0], id: \.self) { detail in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Bone(width: 42, height: 8)
                        Spacer()
                        Bone(width: 46, height: 8)
                    }
                    // The skin's own bar with no fill: blocks in Dracula, a line in One Dark, an outline in Nord.
                    QuotaBar(fraction: nil, tint: .clear)
                    Bone(width: detail, height: 8)
                }
            }
        }
        .modifier(Pulse())
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardChrome()
    }
}

/// A stats card with nothing in it. Open: the verdict, the two strips and the ring; closed: a line for each window.
private struct StatsCardSkeleton: View {
    let isOpen: Bool
    /// The blocks of each day of the 5-hour strip: a shape, not a reading.
    private static let days = [2, 3, 1, 0, 3, 4, 2, 3, 3, 2, 1, 4, 2, 3]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TitleBones()
            if isOpen {
                VStack(alignment: .leading, spacing: 6) {
                    Bone(width: 200, height: 9)
                    Bone(width: 150, height: 8)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
                strip(label: 110) {
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(Array(Self.days.enumerated()), id: \.offset) { _, blocks in
                            VStack(spacing: 2) {
                                if blocks == 0 {
                                    Bone(height: 2, radius: 1)
                                } else {
                                    ForEach(0..<blocks, id: \.self) { _ in Bone(height: 8, radius: 2) }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 48, alignment: .bottom)
                }
                strip(label: 96) {
                    HStack(spacing: 2) {
                        ForEach(0..<UsageStats.minimumSlots, id: \.self) { _ in Bone(height: 48) }
                    }
                }
                HStack(spacing: 12) {
                    Bone(width: 68, height: 68, radius: 34)
                    VStack(alignment: .leading, spacing: 6) {
                        Bone(height: 8)
                        Bone(width: 120, height: 8)
                        Bone(width: 90, height: 8)
                    }
                }
            } else {
                line(110)
                line(96)
            }
        }
        .modifier(Pulse())
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardChrome()
    }

    private func line(_ width: CGFloat) -> some View {
        HStack {
            Bone(width: 42, height: 8)
            Spacer()
            Bone(width: width, height: 8)
        }
    }

    private func strip(label width: CGFloat, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            line(width)
            content()
        }
    }
}
