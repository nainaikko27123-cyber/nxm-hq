import SwiftUI

struct CropSource: Identifiable {
    let id = UUID()
    let image: CGImage
}

/// Crop screen: drag to move, pinch or use the slider to zoom, inside a circle guide.
/// The square around the circle is what gets saved. All movement is offset/scale transforms.
struct PhotoCropView: View {
    let source: CGImage
    let tint: Color
    let onSave: (CGImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragStart: CGSize?
    @State private var pinchStart: CGFloat?

    private let viewport: CGFloat = 380
    private let maxZoom: CGFloat = 5

    private var pixelWidth: CGFloat { CGFloat(source.width) }
    private var pixelHeight: CGFloat { CGFloat(source.height) }
    /// Scale that makes the image just cover the square at zoom 1.
    private var baseScale: CGFloat { viewport / min(pixelWidth, pixelHeight) }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Crop Photo").font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Drag to move. Pinch or use the slider to zoom.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }

            ZStack {
                Image(decorative: source, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: pixelWidth * baseScale, height: pixelHeight * baseScale)
                    .scaleEffect(zoom)
                    .offset(offset)
                CropMask(tint: tint)
                    .allowsHitTesting(false)
            }
            .frame(width: viewport, height: viewport)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .simultaneousGesture(magnifyGesture)

            HStack(spacing: 10) {
                Image(systemName: "minus.magnifyingglass").foregroundStyle(.secondary)
                Slider(value: $zoom, in: 1...maxZoom)
                    .tint(tint)
                Image(systemName: "plus.magnifyingglass").foregroundStyle(.secondary)
            }
            .frame(width: viewport)

            HStack(spacing: 10) {
                Button("Reset") {
                    withAnimation(Theme.bouncy) { zoom = 1; offset = .zero }
                }
                .buttonStyle(SpringyButtonStyle(kind: .secondary))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(SpringyButtonStyle(kind: .secondary))
                    .keyboardShortcut(.cancelAction)
                Button(action: save) { Label("Save", systemImage: "checkmark") }
                    .buttonStyle(SpringyButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: viewport + 44)
        .background {
            ZStack {
                VisualEffectBackground(material: .sheet, blending: .withinWindow)
                Color.black.opacity(0.6)
            }
        }
        .onChange(of: zoom) { _, newZoom in offset = clamped(offset, zoom: newZoom) }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = dragStart ?? offset
                dragStart = start
                offset = clamped(CGSize(width: start.width + value.translation.width,
                                        height: start.height + value.translation.height), zoom: zoom)
            }
            .onEnded { _ in dragStart = nil }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = pinchStart ?? zoom
                pinchStart = start
                zoom = min(max(1, start * value.magnification), maxZoom)
            }
            .onEnded { _ in pinchStart = nil }
    }

    /// Keeps the image covering the whole square so there are never empty edges.
    private func clamped(_ proposed: CGSize, zoom: CGFloat) -> CGSize {
        let scale = baseScale * zoom
        let maxX = max(0, (pixelWidth * scale - viewport) / 2)
        let maxY = max(0, (pixelHeight * scale - viewport) / 2)
        return CGSize(width: min(max(proposed.width, -maxX), maxX),
                      height: min(max(proposed.height, -maxY), maxY))
    }

    private func save() {
        let scale = baseScale * zoom
        // Where the image's top-left corner sits inside the square, in points.
        let originX = viewport / 2 + offset.width - pixelWidth * scale / 2
        let originY = viewport / 2 + offset.height - pixelHeight * scale / 2
        var rect = CGRect(x: -originX / scale, y: -originY / scale, width: viewport / scale, height: viewport / scale)
        rect = rect.intersection(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)).integral
        guard let cropped = source.cropping(to: rect) else { return }
        onSave(cropped)
        dismiss()
    }
}

/// Darkens everything outside the circle and draws the circle guide.
private struct CropMask: View {
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            Path { path in
                path.addRect(rect)
                path.addEllipse(in: rect)
            }
            .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
            Circle()
                .stroke(.white.opacity(0.9), lineWidth: 2)
            Circle()
                .stroke(tint.opacity(0.7), lineWidth: 6)
                .blur(radius: 6)
        }
    }
}
