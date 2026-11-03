import SwiftUI
import AppKit

private struct ChadderBubble: Identifiable, Equatable {
    let id = UUID()
    let say: ChadderSay
}

/// Chadder, NXM's orange cat in the sidebar footer. Every so often he pops up a speech bubble:
/// a question you can answer (saved to Chadder's Fan Survey), a reminder, or a line built from your data.
/// Click him (or a reminder bubble) for the next line. Animations use transform and opacity only.
struct ChadderMascot: View {
    @Environment(AppState.self) private var appState

    @State private var hops = 0
    @State private var happy = false
    @State private var blinking = false
    @State private var wagging = false
    @State private var hovering = false
    @State private var hearts: [FloatingHeart] = []

    @State private var bubble: ChadderBubble?
    @State private var answer = ""
    @FocusState private var answerFocused: Bool
    @State private var hideTask: Task<Void, Never>?
    @State private var lastLine: String?
    @State private var clickTimes: [Date] = []

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                ChadderCat(happy: happy, blinking: blinking, wagging: happy || wagging)
                    .keyframeAnimator(initialValue: HopPose(), trigger: hops) { cat, pose in
                        cat
                            .scaleEffect(x: pose.scaleX, y: pose.scaleY, anchor: .bottom)
                            .rotationEffect(.degrees(pose.tilt), anchor: .bottom)
                            .offset(y: pose.lift)
                    } keyframes: { _ in
                        KeyframeTrack(\.lift) {
                            CubicKeyframe(0, duration: 0.10)
                            CubicKeyframe(-16, duration: 0.18)
                            CubicKeyframe(0, duration: 0.16)
                            SpringKeyframe(0, duration: 0.3, spring: .bouncy)
                        }
                        KeyframeTrack(\.scaleY) {
                            CubicKeyframe(0.78, duration: 0.10)
                            CubicKeyframe(1.12, duration: 0.18)
                            CubicKeyframe(0.85, duration: 0.16)
                            SpringKeyframe(1.0, duration: 0.3, spring: .bouncy)
                        }
                        KeyframeTrack(\.scaleX) {
                            CubicKeyframe(1.15, duration: 0.10)
                            CubicKeyframe(0.92, duration: 0.18)
                            CubicKeyframe(1.12, duration: 0.16)
                            SpringKeyframe(1.0, duration: 0.3, spring: .bouncy)
                        }
                        KeyframeTrack(\.tilt) {
                            CubicKeyframe(0, duration: 0.10)
                            CubicKeyframe(-8, duration: 0.12)
                            CubicKeyframe(8, duration: 0.12)
                            SpringKeyframe(0, duration: 0.4, spring: .bouncy)
                        }
                    }
                    .scaleEffect(hovering ? 1.06 : 1, anchor: .bottom)

                ForEach(hearts) { heart in
                    HeartParticle(heart: heart)
                }
            }
            .frame(width: 56, height: 52)

            VStack(alignment: .leading, spacing: 1) {
                Text("Chadder")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text("Chief Morale Officer")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)

            Button {
                appState.present(maxWidth: 480) { close in ChadderSettingsView(close: close) }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
            .help("Chadder settings")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.06))
                .opacity(hovering ? 1 : 0)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: pet)
        .onHover { hovering = $0 }
        .animation(Theme.bouncy, value: hovering)
        // Bubble sits above Chadder, its tail pointing down at him.
        .overlay(alignment: .topLeading) {
            if let bubble {
                ChadderBubbleView(
                    say: bubble.say,
                    answer: $answer,
                    answerFocused: $answerFocused,
                    onTap: { if !bubble.say.isQuestion { sayNext() } },
                    onSave: saveAnswer,
                    onSkip: skipQuestion
                )
                .alignmentGuide(.top) { $0[.bottom] + 4 }
                .id(bubble.id)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.6, anchor: .bottomLeading).combined(with: .opacity),
                    removal: .opacity
                ))
                .zIndex(1)
            }
        }
        .accessibilityLabel("Chadder the cat")
        .task { await blinkLoop() }
        .task { await chatLoop() }
    }

    // MARK: Talking

    private var settings: ChadderSettings { appState.company.chadder.settings }

    /// Don't interrupt: no bubble while one is showing, a sheet/popup/settings is open,
    /// you're typing, or the app isn't in front.
    private var isBusy: Bool {
        bubble != nil || appState.isPresentingSheet || appState.profileMember != nil
            || ChadderBrain.userIsTyping || !NSApp.isActive
    }

    private func chatLoop() async {
        ChadderBrain.startWatchingKeys()
        if appState.chadderWelcomeBack {
            try? await Task.sleep(for: .seconds(3))
            appState.chadderWelcomeBack = false
            if settings.enabled && !Task.isCancelled { say(ChadderBrain.welcomeBack) }
        }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: settings.frequency.interval)))
            while isBusy && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
            }
            guard !Task.isCancelled, settings.enabled else { continue }
            sayNext()
        }
    }

    private func sayNext() {
        guard let line = ChadderBrain.next(appState.company, after: lastLine) else { return }
        say(line)
    }

    private func say(_ line: ChadderSay, stay seconds: Double = 8) {
        hideTask?.cancel()
        answer = ""
        lastLine = line.text
        withAnimation(.spring(response: 0.35, dampingFraction: 0.62)) {
            bubble = ChadderBubble(say: line)
        }
        // Little tail wiggle while he talks.
        wagging = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { wagging = false }
        scheduleHide(after: seconds)
    }

    private func scheduleHide(after seconds: Double) {
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            // Keep a question open while you're answering it.
            while !Task.isCancelled, bubble?.say.isQuestion == true, !answer.isEmpty || answerFocused {
                try? await Task.sleep(for: .seconds(2))
            }
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.35)) { bubble = nil }
        }
    }

    private func saveAnswer() {
        guard let question = bubble?.say, question.isQuestion else { return }
        let text = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        appState.company.chadder.answers.insert(SurveyAnswer(question: question.text, answer: text, date: .now), at: 0)
        answerFocused = false
        sendHearts()
        say(ChadderSay(text: "Saved to your Fan Survey!", isQuestion: false), stay: 3)
    }

    private func skipQuestion() {
        guard let question = bubble?.say, question.isQuestion else { return }
        appState.company.chadder.skippedUntil[question.text] = Date().addingTimeInterval(ChadderBrain.skipDays * 86_400)
        hideTask?.cancel()
        answerFocused = false
        withAnimation(.easeOut(duration: 0.3)) { bubble = nil }
    }

    // MARK: Clicking

    private func pet() {
        hops += 1
        sendHearts()
        let now = Date()
        clickTimes = clickTimes.filter { now.timeIntervalSince($0) < 4 } + [now]
        if clickTimes.count >= 10 {
            clickTimes = []
            say(ChadderBrain.easterEgg)
            return
        }
        // Don't throw away an answer you've started typing.
        if bubble?.say.isQuestion == true, !answer.isEmpty { return }
        sayNext()
    }

    private func sendHearts() {
        withAnimation(Theme.bouncy) { happy = true }
        for i in 0..<3 {
            let heart = FloatingHeart(xDrift: CGFloat.random(in: -22...22), delay: Double(i) * 0.12,
                                      size: CGFloat.random(in: 9...14))
            hearts.append(heart)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4 + heart.delay) {
                hearts.removeAll { $0.id == heart.id }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(Theme.bouncy) { happy = false }
        }
    }

    /// A blink every few seconds so he feels alive. Cheap: one tiny state flip, no continuous redraw.
    private func blinkLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 3...6)))
            guard !happy else { continue }
            withAnimation(.easeInOut(duration: 0.08)) { blinking = true }
            try? await Task.sleep(for: .seconds(0.14))
            withAnimation(.easeInOut(duration: 0.08)) { blinking = false }
        }
    }
}

/// Glass speech bubble with a tail pointing down at Chadder. Questions get an answer field.
private struct ChadderBubbleView: View {
    let say: ChadderSay
    @Binding var answer: String
    var answerFocused: FocusState<Bool>.Binding
    let onTap: () -> Void
    let onSave: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                if say.isQuestion {
                    Image(systemName: "questionmark.bubble.fill").foregroundStyle(Theme.red)
                }
                Text(say.text)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if say.isQuestion {
                TextField("Your answer", text: $answer)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(.white.opacity(0.12)))
                    .focused(answerFocused)
                    .onSubmit(onSave)
                HStack {
                    Button("Skip", action: onSkip)
                        .buttonStyle(MiniPillStyle(primary: false))
                        .help("Don't ask this again for a few days")
                    Spacer()
                    Button("Save", action: onSave)
                        .buttonStyle(MiniPillStyle(primary: true))
                        .disabled(answer.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .padding(11)
        .frame(width: 204, alignment: .leading)
        .background(
            BubbleShape(tailX: 30)
                .fill(Color(hex: "#18181B").opacity(0.97))
        )
        .overlay(
            BubbleShape(tailX: 30)
                .stroke(LinearGradient(colors: [Theme.red.opacity(0.7), .white.opacity(0.12)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: Theme.red.opacity(0.25), radius: 12, y: 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

/// Rounded rectangle with a small tail at the bottom, `tailX` points from the left.
private struct BubbleShape: Shape {
    var tailX: CGFloat
    func path(in rect: CGRect) -> Path {
        let bubble = Path(roundedRect: rect, cornerRadius: 14, style: .continuous)
        var tail = Path()
        tail.move(to: CGPoint(x: rect.minX + tailX - 7, y: rect.maxY - 2))
        tail.addLine(to: CGPoint(x: rect.minX + tailX, y: rect.maxY + 8))
        tail.addLine(to: CGPoint(x: rect.minX + tailX + 7, y: rect.maxY - 2))
        tail.closeSubpath()
        // One merged outline, so the border flows around the tail instead of cutting across it.
        return bubble.union(tail)
    }
}

private struct MiniPillStyle: ButtonStyle {
    var primary: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(primary ? .white : .secondary)
            .background(Capsule().fill(primary ? AnyShapeStyle(Theme.brand) : AnyShapeStyle(.white.opacity(0.08))))
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(isEnabled ? 1 : 0.4)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

private struct HopPose {
    var lift: CGFloat = 0
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var tilt: Double = 0
}

private struct FloatingHeart: Identifiable {
    let id = UUID()
    let xDrift: CGFloat
    let delay: Double
    let size: CGFloat
}

private struct HeartParticle: View {
    let heart: FloatingHeart
    @State private var risen = false

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: heart.size, weight: .bold))
            .foregroundStyle(Theme.red)
            .shadow(color: Theme.red.opacity(0.6), radius: 4)
            .offset(x: risen ? heart.xDrift : 0, y: risen ? -46 : -10)
            .scaleEffect(risen ? 1 : 0.3)
            .opacity(risen ? 0 : 1)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 1.1).delay(heart.delay)) { risen = true }
            }
    }
}

// MARK: - The cat

/// Chadder drawn with shapes: an orange tabby sitting down, tail curled to the side.
struct ChadderCat: View {
    var happy = false
    var blinking = false
    var wagging = false

    private let fur = Color(hex: "#FF9F43")
    private let furDark = Color(hex: "#E8730C")
    private let stripe = Color(hex: "#C85A00")
    private let cream = Color(hex: "#FFE3C2")
    private let pink = Color(hex: "#FF9AA2")
    private let ink = Color(hex: "#2B1A10")

    var body: some View {
        ZStack {
            tail
                .offset(x: 15, y: 12)

            // Body
            Ellipse()
                .fill(LinearGradient(colors: [fur, furDark], startPoint: .top, endPoint: .bottom))
                .frame(width: 34, height: 26)
                .overlay(
                    Ellipse().fill(cream).frame(width: 16, height: 14).offset(y: 4)
                )
                .offset(y: 13)

            // Front paws
            HStack(spacing: 6) {
                Capsule().fill(cream).frame(width: 9, height: 6)
                Capsule().fill(cream).frame(width: 9, height: 6)
            }
            .offset(y: 24)

            head
                .offset(y: -6)
        }
        .frame(width: 56, height: 52)
    }

    private var head: some View {
        ZStack {
            // Ears
            HStack(spacing: 13) {
                ear.rotationEffect(.degrees(-14))
                ear.scaleEffect(x: -1).rotationEffect(.degrees(14))
            }
            .offset(y: -11)

            // Face
            Ellipse()
                .fill(LinearGradient(colors: [fur, furDark], startPoint: .top, endPoint: .bottom))
                .frame(width: 34, height: 28)

            // Tabby stripes on the forehead
            HStack(spacing: 2.5) {
                Capsule().fill(stripe).frame(width: 2.5, height: 6).rotationEffect(.degrees(-12))
                Capsule().fill(stripe).frame(width: 2.5, height: 7.5)
                Capsule().fill(stripe).frame(width: 2.5, height: 6).rotationEffect(.degrees(12))
            }
            .offset(y: -10)

            // Muzzle and cheeks
            Ellipse().fill(cream).frame(width: 16, height: 10).offset(y: 6)
            HStack(spacing: 18) {
                Circle().fill(pink.opacity(happy ? 0.75 : 0.45)).frame(width: 6, height: 4)
                Circle().fill(pink.opacity(happy ? 0.75 : 0.45)).frame(width: 6, height: 4)
            }
            .offset(y: 4)

            eyes.offset(y: -1)

            // Nose and mouth
            Triangle().fill(pink).frame(width: 4.5, height: 3).rotationEffect(.degrees(180)).offset(y: 4)
            CatMouth(open: happy)
                .stroke(ink, style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                .frame(width: 8, height: happy ? 4 : 3)
                .offset(y: 7.5)

            whiskers
        }
    }

    private var ear: some View {
        ZStack {
            Triangle().fill(furDark).frame(width: 11, height: 12)
            Triangle().fill(pink).frame(width: 5.5, height: 6.5).offset(y: 2)
        }
    }

    @ViewBuilder private var eyes: some View {
        HStack(spacing: 9) {
            ForEach(0..<2, id: \.self) { _ in
                if happy {
                    // ^ ^ happy eyes
                    HappyEye()
                        .stroke(ink, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                        .frame(width: 6, height: 3.5)
                } else {
                    Ellipse()
                        .fill(ink)
                        .frame(width: 5, height: 6.5)
                        .overlay(Circle().fill(.white).frame(width: 1.8, height: 1.8).offset(x: 1, y: -1.5))
                        .scaleEffect(y: blinking ? 0.12 : 1)
                }
            }
        }
    }

    private var whiskers: some View {
        HStack(spacing: 22) {
            VStack(spacing: 2) {
                Capsule().fill(.white.opacity(0.7)).frame(width: 8, height: 0.8).rotationEffect(.degrees(8))
                Capsule().fill(.white.opacity(0.7)).frame(width: 8, height: 0.8).rotationEffect(.degrees(-6))
            }
            VStack(spacing: 2) {
                Capsule().fill(.white.opacity(0.7)).frame(width: 8, height: 0.8).rotationEffect(.degrees(-8))
                Capsule().fill(.white.opacity(0.7)).frame(width: 8, height: 0.8).rotationEffect(.degrees(6))
            }
        }
        .offset(y: 5)
    }

    private var tail: some View {
        TailShape()
            .stroke(
                LinearGradient(colors: [furDark, fur], startPoint: .bottom, endPoint: .top),
                style: StrokeStyle(lineWidth: 5.5, lineCap: .round)
            )
            .frame(width: 14, height: 20)
            .rotationEffect(.degrees(wagging ? 18 : 0), anchor: .bottomLeading)
            .animation(
                wagging ? .easeInOut(duration: 0.14).repeatCount(7, autoreverses: true) : .spring(duration: 0.3),
                value: wagging
            )
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

private struct HappyEye: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
    }
}

/// Small "w" cat mouth; opens into a little smile when happy.
private struct CatMouth: Shape {
    var open: Bool
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                           control: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                           control: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.maxY))
            if open {
                p.move(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY + rect.height * 0.5))
                p.addQuadCurve(to: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.minY + rect.height * 0.5),
                               control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.6))
            }
        }
    }
}

/// Tail rising from the base and curling over at the tip.
private struct TailShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addCurve(to: CGPoint(x: rect.maxX * 0.75, y: rect.minY + rect.height * 0.15),
                       control1: CGPoint(x: rect.maxX, y: rect.maxY),
                       control2: CGPoint(x: rect.maxX * 1.1, y: rect.minY + rect.height * 0.45))
            p.addQuadCurve(to: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.minY + rect.height * 0.05),
                           control: CGPoint(x: rect.maxX * 0.55, y: rect.minY - rect.height * 0.15))
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        ChadderCat().scaleEffect(3)
        ChadderCat(happy: true).scaleEffect(3)
    }
    .padding(80)
    .background(.black)
}
