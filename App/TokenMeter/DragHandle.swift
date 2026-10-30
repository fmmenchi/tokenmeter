import AppKit
import SwiftUI

/// The place to grab a card: a tinted area that gets darker and shows an open hand under the pointer, so it reads as
/// something to act on (ADR 0035).
struct DragHandle: View {
    @State private var hovering = false

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .foregroundStyle(hovering ? .secondary : .tertiary)
            .frame(width: 28, height: 24)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(hovering ? 0.14 : 0.07)))
            .onHover { inside in
                guard inside != hovering else { return }
                hovering = inside
                if inside { NSCursor.openHand.push() } else { NSCursor.pop() }
            }
            .onDisappear {
                if hovering { NSCursor.pop() }
                hovering = false
            }
            .help("Drag to reorder")
            .accessibilityHidden(true)
    }
}
