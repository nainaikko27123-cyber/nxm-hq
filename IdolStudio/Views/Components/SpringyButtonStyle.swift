import SwiftUI

/// Pill button that grows on hover and squashes with a bouncy spring when pressed.
struct SpringyButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, destructive }
    var kind: Kind = .primary
    /// Dims the button without disabling it, so a click can still trigger validation feedback.
    var dimmed = false

    func makeBody(configuration: Configuration) -> some View {
        SpringyBody(configuration: configuration, kind: kind, dimmed: dimmed)
    }

    private struct SpringyBody: View {
        let configuration: Configuration
        let kind: Kind
        let dimmed: Bool
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .foregroundStyle(foreground)
                .background(background)
                .overlay(Capsule().strokeBorder(.white.opacity(kind == .secondary ? 0.14 : 0.18), lineWidth: 1))
                .shadow(color: kind == .primary && !dimmed ? Theme.red.opacity(hovering ? 0.55 : 0.3) : .clear,
                        radius: hovering ? 14 : 8, y: 4)
                .opacity(dimmed ? 0.55 : 1)
                .scaleEffect(configuration.isPressed ? 0.9 : (hovering ? 1.05 : 1))
                .animation(.spring(response: 0.28, dampingFraction: 0.5), value: configuration.isPressed)
                .animation(Theme.bouncy, value: hovering)
                .onHover { hovering = $0 }
        }

        private var foreground: Color {
            switch kind {
            case .primary: .white
            case .secondary: .primary
            case .destructive: Theme.red
            }
        }

        @ViewBuilder private var background: some View {
            switch kind {
            case .primary:
                Capsule().fill(Theme.brand)
            case .secondary:
                Capsule().fill(.white.opacity(hovering ? 0.12 : 0.07))
            case .destructive:
                Capsule().fill(Theme.red.opacity(hovering ? 0.18 : 0.1))
            }
        }
    }
}

/// Horizontal shake used to flag invalid input.
struct Shake: GeometryEffect {
    var travel: CGFloat = 7
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(animatableData * .pi * shakes * 2), y: 0))
    }
}
