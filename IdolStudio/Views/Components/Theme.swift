import SwiftUI
import AppKit

enum Theme {
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.82)
    /// Springier animation for playful layout changes and click feedback.
    static let bouncy = Animation.spring(response: 0.45, dampingFraction: 0.62)
    static let red = Color(hex: "#E50914")
    static let darkRed = Color(hex: "#8B0000")
    static let brandColors = [red, darkRed]
    /// Glass-look card fill. A flat translucent color is far cheaper to scroll than a live blur on every card.
    static let glass = Color.white.opacity(0.055)
    /// Same hue mixed toward black, used for the second stop of a group's gradient.
    static func darkerHex(_ hex: String, by fraction: CGFloat = 0.45) -> String {
        guard let base = NSColor(Color(hex: hex)).usingColorSpace(.sRGB),
              let dark = base.blended(withFraction: fraction, of: .black) else { return hex }
        return Color(nsColor: dark).hexString
    }

    static let brand = LinearGradient(colors: brandColors, startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        guard s.count == 6, Scanner(string: s).scanHexInt64(&value) else {
            self = .accentColor
            return
        }
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }

    /// True for pale colors that need dark text or icons on top.
    var isLight: Bool {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return false }
        return 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent > 0.75
    }

    /// Same hue lifted toward white when it's too dark to read as text on the black theme.
    var readableOnDark: Color {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return self }
        let luminance = 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent
        guard luminance < 0.4, let lifted = c.blended(withFraction: 0.45, of: .white) else { return self }
        return Color(nsColor: lifted)
    }

    var hexString: String {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return "#FFFFFF" }
        return String(
            format: "#%02X%02X%02X",
            Int((c.redComponent * 255).rounded()),
            Int((c.greenComponent * 255).rounded()),
            Int((c.blueComponent * 255).rounded())
        )
    }
}

extension IdolGroup {
    var colors: [Color] {
        let hexes = themeColors.isEmpty ? ["#E50914", "#8B0000"] : themeColors
        return hexes.map(Color.init(hex:))
    }
    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    /// Text color for the group's banner: dark on light accents (e.g. baby pink), white otherwise.
    var bannerText: Color { colors[0].isLight ? .black : .white }
}

/// Wraps NSVisualEffectView so the window gets real behind-window translucency on macOS 14.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = .active
        view.material = material
        view.blendingMode = blending
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
    }
}

struct CardStyle: ViewModifier {
    var padding: CGFloat = 18
    var radius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.glass, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            )
    }
}

extension View {
    func card(padding: CGFloat = 18, radius: CGFloat = 18) -> some View {
        modifier(CardStyle(padding: padding, radius: radius))
    }
}

/// Lifts a card slightly on hover.
struct HoverLift: ViewModifier {
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering ? 1.015 : 1)
            .shadow(color: .black.opacity(hovering ? 0.12 : 0), radius: 16, y: 8)
            .animation(Theme.spring, value: hovering)
            .onHover { hovering = $0 }
    }
}

extension View {
    func hoverLift() -> some View { modifier(HoverLift()) }
}
