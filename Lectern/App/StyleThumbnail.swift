import SwiftUI
import LecternCore

/// The palette strip shown on every style card.
struct SwatchRow: View {
    let colors: [Color]
    var size: CGFloat = 20
    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(colors.prefix(5).enumerated()), id: \.offset) { _, c in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(c)
                    .frame(width: size, height: size)
                    .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(.black.opacity(0.08)))
            }
        }
    }
}

/// A gallery card: rendered hero + name + Vibe·Theme pill + swatches (§6.2).
struct StyleCard: View {
    let style: Style
    let isSelected: Bool
    let isFavorite: Bool
    var onSelect: () -> Void
    var onFavorite: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                ThumbImage(url: style.thumbnailURL, fallback: style.swatchColors)
                    .aspectRatio(16.0 / 9.0, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipShape(.rect(cornerRadius: 12, style: .continuous))

                Button(action: onFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isFavorite ? .pink : .white)
                        .padding(7)
                        .background(.ultraThinMaterial, in: .circle)
                }
                .buttonStyle(.plain)
                .padding(8)
                #if os(macOS)
                // Hover-reveal is a pointer affordance; on touch the heart must
                // always be visible or favoriting is unreachable.
                .opacity(isFavorite || hovering ? 1 : 0)
                #endif
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(style.name).font(.headline).lineLimit(1)
                    Spacer(minLength: 6)
                    if !style.badge.isEmpty {
                        Text(style.badge.uppercased())
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.4)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .overlay(Capsule().strokeBorder(.quaternary))
                            .fixedSize()
                    }
                }
                SwatchRow(colors: style.swatchColors)
            }
            .padding(.horizontal, 2)
        }
        .padding(10)
        .background(.regularMaterial, in: .rect(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2.5)
        )
        .shadow(color: .black.opacity(hovering ? 0.16 : 0), radius: 12, y: 6)
        .scaleEffect(hovering ? 1.015 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: hovering)
        .onHover { hovering = $0 }
        .contentShape(.rect(cornerRadius: 18))
        .onTapGesture(perform: onSelect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(style.name), \(style.badge)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The Compose control that shows the current style and opens the picker.
struct StyleButton: View {
    let style: Style?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Group {
                    if let style {
                        ThumbImage(url: style.thumbnailURL, fallback: style.swatchColors)
                            .aspectRatio(16.0 / 9.0, contentMode: .fill)
                    } else {
                        Image(systemName: "paintpalette").imageScale(.large).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.quaternary)
                    }
                }
                .frame(width: 96, height: 54)
                .clipShape(.rect(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(style?.name ?? "Choose a style").font(.headline)
                    Text(style?.badge ?? "150 bundled designs")
                        .font(.caption).foregroundStyle(.secondary)
                    if let style { SwatchRow(colors: style.swatchColors, size: 12) }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
