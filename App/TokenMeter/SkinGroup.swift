import SwiftUI
import TokenMeterCore

/// The group "Skin" in Settings (ADR 0013): one choice of five, each with a small preview of its look. Settings itself keeps the
/// system look; the choice changes the panel, the widget and the stats.
struct SkinGroup: View {
    let meter: Meter

    var body: some View {
        Section {
            Text("Changes the look of the panel, the widget and the stats: colours, the shape of the bars and the typeface. Settings keeps the system look.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(Skin.allCases, id: \.self) { skin in
                let chosen = meter.skin == skin
                Button { meter.skin = skin } label: {
                    HStack(spacing: 10) {
                        Image(systemName: chosen ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(chosen ? Color.accentColor : Color.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(skin.title)
                            Text(skin.note).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        SkinPreview(skin: skin)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(skin.title)
                .accessibilityAddTraits(chosen ? .isSelected : [])
            }
        } header: {
            Text("Skin")
        }
    }
}
