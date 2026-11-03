import SwiftUI

/// Popover from the gear next to Chadder: bubbles on/off, how often, and your own lines.
struct ChadderSettingsView: View {
    var close: () -> Void = {}
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var company = appState.company

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ChadderCat().scaleEffect(0.7).frame(width: 40, height: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Chadder Settings").font(.headline)
                    Text("Your fan-club mascot").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Speech bubbles", isOn: $company.chadder.settings.enabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .help("Turn speech bubbles on or off")
                Button("Done", action: close)
                    .buttonStyle(SpringyButtonStyle(kind: .primary))
                    .keyboardShortcut(.cancelAction)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("How often").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Picker("How often", selection: $company.chadder.settings.frequency) {
                    ForEach(ChadderFrequency.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text("A new bubble \(company.chadder.settings.frequency.summary).")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            .disabled(!company.chadder.settings.enabled)
            .opacity(company.chadder.settings.enabled ? 1 : 0.5)

            Divider().opacity(0.4)

            HStack {
                Text("Your lines").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button {
                    withAnimation(Theme.bouncy) {
                        company.chadder.settings.customLines.append(ChadderLine(text: "", isQuestion: false))
                    }
                } label: {
                    Label("Add Line", systemImage: "plus")
                }
                .buttonStyle(SpringyButtonStyle(kind: .secondary))
            }

            if company.chadder.settings.customLines.isEmpty {
                Text("No custom lines yet. Questions you add here also go to Chadder's Fan Survey when you answer them.")
                    .font(.caption).foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach($company.chadder.settings.customLines) { $line in
                            HStack(spacing: 8) {
                                TextField(line.isQuestion ? "Ask something…" : "Say something…", text: $line.text)
                                    .textFieldStyle(.plain)
                                    .font(.callout)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                                Picker("Kind", selection: $line.isQuestion) {
                                    Text("Reminder").tag(false)
                                    Text("Question").tag(true)
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                                .fixedSize()
                                Button {
                                    withAnimation(Theme.bouncy) {
                                        company.chadder.settings.customLines.removeAll { $0.id == line.id }
                                    }
                                } label: {
                                    Image(systemName: "trash").foregroundStyle(Theme.red)
                                }
                                .buttonStyle(.plain)
                                .help("Delete line")
                            }
                            .transition(.opacity)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(18)
    }
}
