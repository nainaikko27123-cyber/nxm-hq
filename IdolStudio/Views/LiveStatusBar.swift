import SwiftUI

/// Strip at the top of the Overview with one pill per group showing what they're doing right now.
struct LiveStatusBar: View {
    @Environment(AppState.self) private var appState

    @State private var scrollTarget: UUID?

    var body: some View {
        let groups = appState.company.groups
        HStack(spacing: 8) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    // Re-render once a minute so "since 2h ago" stays current.
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        HStack(spacing: 10) {
                            ForEach(groups) { group in
                                StatusPill(group: group, now: context.date)
                                    .id(group.id)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 14)
                    }
                }
                .scrollIndicators(.never)
                // Soft fade at both edges so pills slide in and out instead of being cut off.
                .mask(
                    LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.03),
                                           .init(color: .black, location: 0.97), .init(color: .clear, location: 1)],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .onChange(of: scrollTarget) { _, target in
                    guard let target else { return }
                    withAnimation(Theme.spring) { proxy.scrollTo(target, anchor: .center) }
                }
            }
            if groups.count > 2 {
                ScrollArrows(groups: groups, target: $scrollTarget)
            }
            RecentChangesButton()
        }
    }
}

/// The last 10 status changes, newest first.
private struct RecentChangesList: View {
    let close: () -> Void
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent changes").font(.headline)
                Spacer()
                Button("Close", action: close)
                    .buttonStyle(SpringyButtonStyle(kind: .secondary))
                    .keyboardShortcut(.cancelAction)
            }
            let log = appState.company.statusLog
            if log.isEmpty {
                Text("No status changes yet.").font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(log) { entry in
                    HStack(alignment: .top, spacing: 9) {
                        StatusDot(color: entry.kind?.color ?? .white.opacity(0.3))
                            .padding(.top, 3)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.text).font(.callout)
                            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .padding(18)
    }
}

/// Clock button that opens the last 10 status changes.
private struct RecentChangesButton: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            appState.present(maxWidth: 400) { close in RecentChangesList(close: close) }
        } label: {
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption.weight(.bold))
                .frame(width: 26, height: 26)
                .background(Circle().fill(.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .help("Recent status changes")
    }
}

/// ‹ › buttons to step through pills when there are many groups.
private struct ScrollArrows: View {
    let groups: [IdolGroup]
    @Binding var target: UUID?

    var body: some View {
        HStack(spacing: 4) {
            arrow("chevron.left", step: -1)
            arrow("chevron.right", step: 1)
        }
    }

    private func arrow(_ symbol: String, step: Int) -> some View {
        Button {
            let ids = groups.map(\.id)
            let current = target.flatMap { ids.firstIndex(of: $0) } ?? (step > 0 ? 0 : ids.count - 1)
            let next = min(max(current + step, 0), ids.count - 1)
            target = ids[next]
        } label: {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .frame(width: 26, height: 26)
                .background(Circle().fill(.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

private struct StatusPill: View {
    let group: IdolGroup
    var now: Date = .now
    @Environment(AppState.self) private var appState
    @State private var hovering = false

    var body: some View {
        Button {
            appState.present(maxWidth: 380) { close in StatusEditor(group: group, close: close) }
        } label: { pill }
            .buttonStyle(.plain)
            .scaleEffect(hovering ? 1.03 : 1)
            .onHover { hovering = $0 }
            .animation(Theme.bouncy, value: hovering)
            .help("Change \(group.name)'s status")
    }

    @ViewBuilder private var pill: some View {
        let status = group.liveStatus
        let tint = status?.kind.color ?? .white.opacity(0.3)
        HStack(spacing: 10) {
            StatusDot(color: tint, pulsing: status?.kind == .performing)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(group.name).font(.caption.weight(.bold)).foregroundStyle(Color.white)
                    if let status {
                        Image(systemName: status.kind.symbol)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(tint)
                    }
                }
                if let status {
                    Text(status.sentence(for: group.name))
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.85))
                        .lineLimit(1)
                    Text("since \(Self.ago(status.since, now: now))")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.45))
                } else {
                    Text("No status set")
                        .font(.caption.italic())
                        .foregroundStyle(Color.white.opacity(0.45))
                }
            }
        }
        .opacity(status == nil ? 0.7 : 1)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Self.shape.fill(Theme.glass))
        .background(Self.shape.fill(tint.opacity(status == nil ? 0 : 0.10)))
        .overlay(Self.shape.stroke(tint.opacity(status == nil ? 0.25 : 0.45), lineWidth: 1))
    }
}

extension StatusPill {
    /// Rounded pill outline (a plain Capsule border left a stray sliver at its ends on taller pills).
    static let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    /// "just now", "5m ago", "2h ago", "3d ago".
    static func ago(_ date: Date, now: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        switch seconds {
        case ..<60: return "just now"
        case ..<3600: return "\(Int(seconds / 60))m ago"
        case ..<86_400: return "\(Int(seconds / 3600))h ago"
        default: return "\(Int(seconds / 86_400))d ago"
        }
    }
}

/// Small colored dot. When `pulsing`, a ring grows and fades around it like a "live" light
/// (scale and opacity only).
struct StatusDot: View {
    let color: Color
    var pulsing = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            if pulsing {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulse ? 2.6 : 1)
                    .opacity(pulse ? 0 : 0.7)
            }
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: pulsing ? color.opacity(0.9) : .clear, radius: 4)
        }
        .frame(width: 12, height: 12)
        .onAppear { startPulse() }
        .onChange(of: pulsing) { _, _ in startPulse() }
    }

    private func startPulse() {
        pulse = false
        guard pulsing else { return }
        withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true }
    }
}

/// Popup for changing a group's status: pick a type, add the detail if needed, Save.
private struct StatusEditor: View {
    let group: IdolGroup
    let close: () -> Void
    @Environment(AppState.self) private var appState
    @State private var kind: GroupStatusKind
    @State private var detail: String
    @State private var shakeCount = 0
    @FocusState private var detailFocused: Bool

    init(group: IdolGroup, close: @escaping () -> Void) {
        self.group = group
        self.close = close
        _kind = State(initialValue: group.liveStatus?.kind ?? .performing)
        _detail = State(initialValue: group.liveStatus?.detail ?? "")
    }

    private var trimmed: String { detail.trimmingCharacters(in: .whitespaces) }
    private var needsDetail: Bool { kind.detailPrompt?.required == true }
    private var isValid: Bool { !needsDetail || !trimmed.isEmpty }
    private var preview: GroupStatus { GroupStatus(kind: kind, detail: kind.detailPrompt == nil ? "" : trimmed) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(group.name) right now").font(.headline)
                Spacer()
                StatusDot(color: kind.color, pulsing: kind == .performing)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(GroupStatusKind.allCases) { option in
                    kindButton(option)
                }
            }

            if let prompt = kind.detailPrompt {
                VStack(alignment: .leading, spacing: 5) {
                    Text(prompt.label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    TextField(prompt.placeholder, text: $detail)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(!isValid && shakeCount > 0 ? Theme.red : .white.opacity(0.12)))
                        .focused($detailFocused)
                        .onSubmit(save)
                        .modifier(Shake(animatableData: CGFloat(shakeCount)))
                }
                .transition(.opacity)
            }

            Text(isValid ? preview.sentence(for: group.name) : "Type the \(kind.detailPrompt?.label.lowercased() ?? "detail") to continue")
                .font(.callout)
                .foregroundStyle(isValid ? .secondary : .tertiary)
                .lineLimit(2)

            HStack(spacing: 10) {
                if group.liveStatus != nil {
                    Button("Clear Status") {
                        withAnimation(Theme.bouncy) { appState.company.setLiveStatus(nil, for: group) }
                        close()
                    }
                    .buttonStyle(SpringyButtonStyle(kind: .destructive))
                }
                Spacer()
                Button("Cancel", action: close)
                    .buttonStyle(SpringyButtonStyle(kind: .secondary))
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .buttonStyle(SpringyButtonStyle(kind: .primary, dimmed: !isValid))
            }
        }
        .padding(18)
        .animation(Theme.bouncy, value: kind)
    }

    private func kindButton(_ option: GroupStatusKind) -> some View {
        let selected = option == kind
        return Button {
            kind = option
            if option.detailPrompt != nil { detailFocused = true }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: option.symbol).foregroundStyle(option.color)
                Text(option.title).font(.callout.weight(.medium))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.white.opacity(0.05)))
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(option.color.opacity(0.18)).opacity(selected ? 1 : 0))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(option.color.opacity(0.7), lineWidth: 1.5).opacity(selected ? 1 : 0))
            .scaleEffect(selected ? 1.02 : 1)
        }
        .buttonStyle(.plain)
    }

    private func save() {
        guard isValid else {
            withAnimation(.linear(duration: 0.4)) { shakeCount += 1 }
            NSSound.beep()
            return
        }
        withAnimation(Theme.bouncy) { appState.company.setLiveStatus(preview, for: group) }
        close()
    }
}
