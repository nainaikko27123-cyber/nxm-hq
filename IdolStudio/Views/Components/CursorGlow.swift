import SwiftUI
import AppKit
import QuartzCore

/// Faint red glow that follows the mouse inside the window.
/// Drawn by a Core Animation layer moved directly on mouse events, so it never re-renders SwiftUI views.
struct CursorGlow: NSViewRepresentable {
    var diameter: CGFloat = 340

    func makeNSView(context: Context) -> CursorGlowView {
        CursorGlowView(diameter: diameter)
    }

    func updateNSView(_ view: CursorGlowView, context: Context) {}
}

final class CursorGlowView: NSView {
    private let glow = CAGradientLayer()
    private var trackingArea: NSTrackingArea?

    init(diameter: CGFloat) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true

        let red = NSColor(srgbRed: 229 / 255, green: 9 / 255, blue: 20 / 255, alpha: 1)
        glow.type = .radial
        glow.colors = [
            red.withAlphaComponent(0.20).cgColor,
            red.withAlphaComponent(0.08).cgColor,
            red.withAlphaComponent(0.0).cgColor,
        ]
        glow.locations = [0, 0.4, 1]
        glow.startPoint = CGPoint(x: 0.5, y: 0.5)
        glow.endPoint = CGPoint(x: 1, y: 1)
        glow.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        glow.opacity = 0
        layer?.addSublayer(glow)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Clicks, scrolling and hovers pass straight through to the app underneath.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.09)  // slight trail so it feels soft
        glow.position = point
        CATransaction.commit()
        if glow.opacity == 0 { setVisible(true) }
    }

    override func mouseEntered(with event: NSEvent) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glow.position = convert(event.locationInWindow, from: nil)
        CATransaction.commit()
        setVisible(true)
    }

    override func mouseExited(with event: NSEvent) { setVisible(false) }

    private func setVisible(_ visible: Bool) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.25)
        glow.opacity = visible ? 1 : 0
        CATransaction.commit()
    }
}
