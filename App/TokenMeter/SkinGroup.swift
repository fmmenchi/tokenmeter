import SwiftUI
import TokenMeterCore

/// The group "Skin" in Settings (ADR 0013): the five skins as a grid of tiles, each a small preview of its look and its name, the
/// chosen one with a ring. Settings itself keeps the system look; the choice changes the panel, the widget and the stats.
struct SkinGroup: View {
    let meter: Meter

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3)

    var body: some View {
        Section {
            Text("Changes the look of the panel, the widget and the stats: colours, the shape of the bars and the typeface. Settings keeps the system look.")
                .font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: columns, alignment: .center, spacing: 10) {
                ForEach(Skin.allCases, id: \.self) { skin in tile(skin) }
            }
        } header: {
            Text("Skin")
        }
    }

    private func tile(_ skin: Skin) -> some View {
        let chosen = meter.skin == skin
        return Button { meter.skin = skin } label: {
            VStack(spacing: 6) {
                SkinPreview(skin: skin, width: 118)
                Text(skin.title).font(.callout)
            }
            .padding(6)
            .frame(maxWidth: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(chosen ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: chosen ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .help(skin.note)
        .accessibilityLabel(skin.title)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}
