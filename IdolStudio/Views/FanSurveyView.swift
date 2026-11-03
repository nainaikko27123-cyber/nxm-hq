import SwiftUI

/// "Chadder's Fan Survey": every question you answered in Chadder's bubbles, newest first.
struct FanSurveyView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let answers = appState.company.chadder.answers.sorted { $0.date > $1.date }
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(eyebrow: "Fan Club", title: "Chadder's Fan Survey")

                HStack(spacing: 16) {
                    ChadderCat(happy: !answers.isEmpty).scaleEffect(1.3).frame(width: 74, height: 68)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(answers.isEmpty ? "No answers yet" : "\(answers.count) \(answers.count == 1 ? "answer" : "answers")")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("Chadder asks questions in the sidebar. Type an answer in his bubble and press Save, and it shows up here. You can edit or delete answers any time.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .card(padding: 20)

                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(answers) { answer in
                        SurveyAnswerCard(answer: answer)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .animation(Theme.bouncy, value: answers.map(\.id))
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
    }
}

private struct SurveyAnswerCard: View {
    let answer: SurveyAnswer
    @Environment(AppState.self) private var appState
    @State private var editing = false
    @State private var draft = ""
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Label(answer.question, systemImage: "questionmark.bubble.fill")
                    .font(.headline)
                    .labelStyle(TintedIconLabel())
                Spacer()
                Text(answer.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            if editing {
                TextField("Your answer", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .padding(8)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .onSubmit(save)
                HStack {
                    Spacer()
                    Button("Cancel") { editing = false }
                        .buttonStyle(SpringyButtonStyle(kind: .secondary))
                        .keyboardShortcut(.cancelAction)
                    Button("Save", action: save)
                        .buttonStyle(SpringyButtonStyle(kind: .primary, dimmed: draft.trimmingCharacters(in: .whitespaces).isEmpty))
                }
            } else {
                Text(answer.answer)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Spacer()
                    Button {
                        draft = answer.answer
                        editing = true
                    } label: { Label("Edit", systemImage: "pencil") }
                        .buttonStyle(SpringyButtonStyle(kind: .secondary))
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
                        .buttonStyle(SpringyButtonStyle(kind: .destructive))
                }
            }
        }
        .card(padding: 16)
        .confirmationDialog("Delete this answer?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                withAnimation(Theme.bouncy) { appState.company.chadder.answers.removeAll { $0.id == answer.id } }
            }
        } message: {
            Text("\"\(answer.question)\": \(answer.answer)")
        }
    }

    private func save() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { NSSound.beep(); return }
        if let index = appState.company.chadder.answers.firstIndex(where: { $0.id == answer.id }) {
            appState.company.chadder.answers[index].answer = text
        }
        editing = false
    }
}

private struct TintedIconLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            configuration.icon.foregroundStyle(Theme.red)
            configuration.title
        }
    }
}
