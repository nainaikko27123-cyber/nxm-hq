import SwiftUI

/// Custom title bar shown at the top of each page (the system title bar is hidden).
struct PageHeader<Trailing: View>: View {
    let eyebrow: String
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)
                Text(title.isEmpty ? "Untitled" : title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }
            Spacer()
            trailing
        }
        .padding(.top, 34)
    }
}

extension PageHeader where Trailing == EmptyView {
    init(eyebrow: String, title: String) {
        self.init(eyebrow: eyebrow, title: title) { EmptyView() }
    }
}

/// A member's avatar: their photo if they have one, otherwise the letter (or icon) in their accent color.
/// Always has a thin ring in the accent color.
struct MemberAvatar: View {
    let member: IdolMember
    var size: CGFloat = 52
    /// nil = circle; a value = rounded square with that corner radius.
    var cornerRadius: CGFloat? = nil
    var zoomOnHover = false

    var body: some View {
        AvatarView(
            photoFileName: member.photoFileName,
            initial: member.initial,
            symbol: member.avatarSymbol,
            colorHex: member.colorAccent,
            size: size,
            cornerRadius: cornerRadius,
            zoomOnHover: zoomOnHover
        )
    }
}

/// Avatar drawn from plain values, so the editor can preview a draft before it's saved.
struct AvatarView: View {
    var photoFileName: String?
    var initial: String
    var symbol: String
    var colorHex: String
    var size: CGFloat
    var cornerRadius: CGFloat? = nil
    var zoomOnHover = false

    @State private var hovering = false

    private var shape: AnyShape {
        if let cornerRadius { AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)) }
        else { AnyShape(Circle()) }
    }

    var body: some View {
        let color = Color(hex: colorHex)
        let hasPhoto = photoFileName != nil
        ZStack {
            fallback(color: color)
            if let photoFileName {
                // Tiny avatars use the 128px thumbnail; larger ones the 512px profile.
                StoredPhoto(fileName: photoFileName, thumbnail: size <= 64)
                    .id(photoFileName)   // fresh state when the photo changes
            }
        }
        .scaleEffect(zoomOnHover && hovering ? 1.08 : 1)   // transform only
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay(
            shape.stroke(hasPhoto || symbol.isEmpty ? color.opacity(0.85) : .white.opacity(0.35),
                         lineWidth: max(1.2, size * (hasPhoto ? 0.035 : 0.025)))
        )
        .animation(Theme.bouncy, value: hovering)
        .onHover { if zoomOnHover { hovering = $0 } }
    }

    @ViewBuilder private func fallback(color: Color) -> some View {
        if symbol.isEmpty {
            // Letter avatar: first letter of the stage name in the member's accent color.
            Rectangle().fill(Color.black.opacity(0.55))
            Rectangle().fill(color.opacity(0.16))
            Text(initial)
                .font(.system(size: size * 0.48, weight: .heavy, design: .rounded))
                .foregroundStyle(color.readableOnDark)
                .shadow(color: color.opacity(0.6), radius: size * 0.08)
        } else {
            Rectangle().fill(LinearGradient(colors: [color, color.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(color.isLight ? .black : .white)
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        }
    }
}

/// Loads a saved photo lazily (only once the avatar is on screen) and fades it in.
struct StoredPhoto: View {
    let fileName: String
    let thumbnail: Bool
    @State private var image: NSImage?

    init(fileName: String, thumbnail: Bool) {
        self.fileName = fileName
        self.thumbnail = thumbnail
        // Already decoded? Show it immediately with no fade.
        _image = State(initialValue: PhotoCache.shared.cached(fileName, thumbnail: thumbnail))
    }

    var body: some View {
        Color.clear
            .overlay {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .transition(.opacity)
                }
            }
            .task(id: fileName + (thumbnail ? "|t" : "|f")) {
                if let hit = PhotoCache.shared.cached(fileName, thumbnail: thumbnail) {
                    image = hit
                    return
                }
                let loaded = await PhotoCache.shared.image(fileName, thumbnail: thumbnail)
                withAnimation(.easeOut(duration: 0.2)) { image = loaded }
            }
    }
}

struct AvatarStack: View {
    let members: [IdolMember]
    var size: CGFloat = 28

    var body: some View {
        HStack(spacing: -size * 0.32) {
            ForEach(members) { member in
                MemberAvatar(member: member, size: size)
                    .overlay(Circle().strokeBorder(.background.opacity(0.6), lineWidth: 2))
            }
        }
    }
}

struct Chip: View {
    let text: String
    var tint: Color = .secondary
    var filled = false

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(filled ? (tint.isLight ? .black : .white) : tint)
            .background(
                Capsule().fill(filled ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.14)))
            )
    }
}

struct StatTile: View {
    let value: String
    let label: String
    let symbol: String
    let colors: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .contentTransition(.opacity)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct SectionTitle: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .padding(.top, 6)
    }
}

/// Lets an image be dropped onto a view, with a highlight ring that fades in (opacity only).
private struct PhotoDropTarget: ViewModifier {
    @Binding var isTargeted: Bool
    var tint: Color
    var cornerRadius: CGFloat?
    var perform: ([NSItemProvider]) -> Bool

    func body(content: Content) -> some View {
        let shape = cornerRadius.map { AnyShape(RoundedRectangle(cornerRadius: $0 + 4, style: .continuous)) } ?? AnyShape(Circle())
        content
            .overlay(
                shape
                    .stroke(tint, style: StrokeStyle(lineWidth: 2.5, dash: [6, 4]))
                    .padding(-4)
                    .opacity(isTargeted ? 1 : 0)
            )
            .scaleEffect(isTargeted ? 1.05 : 1)
            .animation(Theme.bouncy, value: isTargeted)
            .onDrop(of: [.fileURL, .image], isTargeted: $isTargeted, perform: perform)
            .help("Drop an image here")
    }
}

extension View {
    func photoDropTarget(isTargeted: Binding<Bool>, tint: Color, cornerRadius: CGFloat? = nil,
                         perform: @escaping ([NSItemProvider]) -> Bool) -> some View {
        modifier(PhotoDropTarget(isTargeted: isTargeted, tint: tint, cornerRadius: cornerRadius, perform: perform))
    }
}

/// Soft "Not added yet" text for use on top of colored group banners.
struct BannerPlaceholder: View {
    var text = "Not added yet"
    var color: Color = .white

    var body: some View {
        Text(text)
            .italic()
            .foregroundStyle(color.opacity(0.55))
    }
}

/// Grid that behaves like CSS `repeat(auto-fit, minmax(260px, 1fr))` with `align-items: stretch`:
/// columns are at least `minColumnWidth` and share the full width, and every card in a row
/// takes the height of the tallest one. When cards would wrap, columns are balanced
/// (4 cards → 2 × 2 rather than 3 + 1) so the last row doesn't leave a gap on the right.
struct AutoFitGrid: Layout {
    var minColumnWidth: CGFloat = 260
    var spacing: CGFloat = 16

    private func columnCount(width: CGFloat, items: Int) -> Int {
        guard items > 0 else { return 1 }
        // An unlimited (or broken) width proposal means "as wide as you like": one row.
        guard width.isFinite, width > 0 else { return items }
        let fit = max(1, Int((width + spacing) / (minColumnWidth + spacing)))
        if items <= fit { return items }                  // all in one row, stretched to full width
        let rows = Int((Double(items) / Double(fit)).rounded(.up))
        return Int((Double(items) / Double(rows)).rounded(.up))
    }

    private func metrics(width: CGFloat, subviews: Subviews) -> (columns: Int, columnWidth: CGFloat, rowHeights: [CGFloat]) {
        let columns = columnCount(width: width, items: subviews.count)
        let columnWidth = max(0, (width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
        var rowHeights: [CGFloat] = []
        for start in stride(from: 0, to: subviews.count, by: columns) {
            let row = subviews[start..<min(start + columns, subviews.count)]
            rowHeights.append(row.map { $0.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height }.max() ?? 0)
        }
        return (columns, columnWidth, rowHeights)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ideal = minColumnWidth * CGFloat(max(subviews.count, 1)) + spacing * CGFloat(max(subviews.count - 1, 0))
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? ideal
        let m = metrics(width: width, subviews: subviews)
        let height = m.rowHeights.reduce(0, +) + spacing * CGFloat(max(m.rowHeights.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let m = metrics(width: bounds.width, subviews: subviews)
        var y = bounds.minY
        for (row, rowHeight) in m.rowHeights.enumerated() {
            for column in 0..<m.columns {
                let index = row * m.columns + column
                guard index < subviews.count else { break }
                let x = bounds.minX + CGFloat(column) * (m.columnWidth + spacing)
                subviews[index].place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                                      proposal: ProposedViewSize(width: m.columnWidth, height: rowHeight))
            }
            y += rowHeight + spacing
        }
    }
}

/// Small pill in a group banner, e.g. "Formerly Bubble Girls".
struct BannerTag: View {
    let text: String
    var color: Color = .white

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .foregroundStyle(color)
            .background(Capsule().fill(color.opacity(0.14)))
            .overlay(Capsule().strokeBorder(color.opacity(0.35)))
    }
}
