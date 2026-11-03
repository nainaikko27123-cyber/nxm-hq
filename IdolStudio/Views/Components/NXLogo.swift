import SwiftUI

/// The NXM company mark: "NX" in white on the red rounded square.
struct NXLogo: View {
    var size: CGFloat = 88

    var body: some View {
        let radius = size * 0.25
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Theme.brand)
            // Soft inner bevel for the same glossy look as before.
            RoundedRectangle(cornerRadius: radius * 0.8, style: .continuous)
                .fill(.white.opacity(0.12))
                .padding(size * 0.07)
                .blendMode(.overlay)
            Text("NX")
                .font(.system(size: size * 0.40, weight: .black, design: .rounded))
                .tracking(-size * 0.015)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: size * 0.02, y: size * 0.015)
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.red.opacity(size > 50 ? 0.35 : 0.4), radius: size * 0.16, y: size * 0.07)
        .accessibilityLabel("NXM logo")
    }
}

#Preview {
    HStack(spacing: 20) {
        NXLogo(size: 88)
        NXLogo(size: 34)
    }
    .padding(40)
    .background(.black)
}
