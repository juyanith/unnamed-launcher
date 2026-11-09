import SwiftUI

/// A key in a small rounded rectangle: "E", "Space", "esc". Used in the
/// Guide's rows and footer (DESIGN-SYSTEM.md, Components).
struct Keycap: View {
    let label: String
    var font: Font = .system(.callout, design: .monospaced).weight(.medium)

    var body: some View {
        Text(label)
            .font(font)
            .lineLimit(1)
            .padding(.horizontal, Space.sm)
            .padding(.vertical, Space.xs / 2)
            .frame(minWidth: Layout.keycapMinWidth)
            .background(Surfaces.keycap, in: .rect(cornerRadius: Radius.xs))
            .overlay(RoundedRectangle(cornerRadius: Radius.xs).strokeBorder(Surfaces.keycapStroke))
    }
}
