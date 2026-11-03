import SwiftUI
import AppKit

/// "🏆 12 awards" pill on a group card. Click it to edit the count in a small popover.
/// Animations use only scale and opacity.
struct AwardPill: View {
    let group: IdolGroup
    @Environment(AppState.self) private var appState
    @State private var hovering = false

    private var tint: Color { (group.colors.first ?? Theme.red).readableOnDark }

    var body: some View {
        Button {
            let tint = self.tint
            appState.present(maxWidth: 320) { close in
                AwardEditorPopover(group: group, tint: tint, close: close)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "trophy.fill")
                Text(group.awards == 1 ? "1 award" : "\(group.awards) awards")
                    .monospacedDigit()
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(tint)
            .background(Capsule().fill(tint.opacity(0.14)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.25)))
            // Hover ring fades in with opacity only.
            .overlay(Capsule().strokeBorder(tint.opacity(0.8)).opacity(hovering ? 1 : 0))
            .scaleEffect(hovering ? 1.06 : 1)
            // Little pop whenever the count changes.
            .keyframeAnimator(initialValue: 1.0, trigger: group.awards) { pill, scale in
                pill.scaleEffect(scale)
            } keyframes: { _ in
                SpringKeyframe(1.18, duration: 0.12, spring: .snappy)
                SpringKeyframe(1.0, duration: 0.3, spring: .bouncy)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.bouncy, value: hovering)
        .help("Edit awards")
    }
}

private struct AwardEditorPopover: View {
    let group: IdolGroup
    let tint: Color
    let close: () -> Void
    @State private var text: String
    @State private var shakeCount = 0
    @FocusState private var focused: Bool

    init(group: IdolGroup, tint: Color, close: @escaping () -> Void) {
        self.group = group
        self.tint = tint
        self.close = close
        _text = State(initialValue: String(group.awards))
    }

    private var value: Int? { Int(text) }
    private var isValid: Bool { value.map { (0...IdolGroup.maxAwards).contains($0) } ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                Image(systemName: "trophy.fill").foregroundStyle(tint)
                Text("Awards").font(.headline)
                Spacer()
                Text(group.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }

            AwardStepper(text: $text, tint: tint)
                .focused($focused)
                .onSubmit(save)
                .modifier(Shake(animatableData: CGFloat(shakeCount)))

            if !isValid {
                ErrorText("Enter a whole number from 0 to \(IdolGroup.maxAwards).")
                    .transition(.opacity)
            }

            HStack(spacing: 10) {
                Spacer()
                Button("Cancel", action: close)
                    .buttonStyle(SpringyButtonStyle(kind: .secondary))
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .buttonStyle(SpringyButtonStyle(kind: .primary, dimmed: !isValid))
            }
        }
        .padding(18)
        .animation(.easeOut(duration: 0.15), value: isValid)
        .onAppear { focused = true }
    }

    private func save() {
        guard let value, isValid else {
            withAnimation(.linear(duration: 0.4)) { shakeCount += 1 }
            NSSound.beep()
            return
        }
        group.setAwards(value)
        close()
    }
}

/// Number field with − / + buttons. Only digits can be typed, so it can't go negative.
struct AwardStepper: View {
    @Binding var text: String
    var tint: Color = Theme.red
    var maxValue: Int = IdolGroup.maxAwards

    private var value: Int { Int(text) ?? 0 }

    var body: some View {
        HStack(spacing: 10) {
            Button { set(value - 1) } label: { Image(systemName: "minus") }
                .buttonStyle(RoundStepStyle(tint: tint))
                .disabled(value <= 0)
                .help("One fewer")
            TextField("0", text: $text)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                .frame(width: 90)
                .padding(.vertical, 6)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.white.opacity(0.12)))
                .onChange(of: text) { _, newValue in
                    let digits = String(newValue.filter(\.isASCII).filter(\.isNumber).prefix(4))
                    if digits != newValue { text = digits }
                }
            Button { set(value + 1) } label: { Image(systemName: "plus") }
                .buttonStyle(RoundStepStyle(tint: tint))
                .disabled(value >= maxValue)
                .help("One more")
        }
    }

    private func set(_ newValue: Int) {
        text = String(min(max(0, newValue), maxValue))
    }
}

/// Round − / + button that squashes on press (scale only) and fades when disabled (opacity only).
struct RoundStepStyle: ButtonStyle {
    var tint: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(tint.isLight ? .black : .white)
            .frame(width: 32, height: 32)
            .background(Circle().fill(tint))
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .opacity(isEnabled ? 1 : 0.35)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: configuration.isPressed)
    }
}
