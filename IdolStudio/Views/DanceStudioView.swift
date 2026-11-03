import SwiftUI

extension DanceGroup {
    var colors: [Color] { [Color(hex: accentHex), Color(hex: Theme.darkerHex(accentHex))] }
    var gradient: LinearGradient { LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing) }
    var ink: Color { colors[0].readableOnDark }
}

/// Dance Studio overview: description, stats and a card per crew.
struct DanceStudioView: View {
    @Environment(AppState.self) private var appState
    @State private var crewToDelete: DanceGroup?

    var body: some View {
        @Bindable var company = appState.company
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(eyebrow: "Studio", title: "Dance Studio") {
                    Button { appState.danceSheet = .add } label: {
                        Label("New Dance Group", systemImage: "plus")
                    }
                    .buttonStyle(GradientButtonStyle(colors: Theme.brandColors))
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "figure.dance").font(.title2).foregroundStyle(Theme.red)
                    TextField("Describe the studio…", text: $company.studioDescription, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                }
                .card(padding: 18)

                AutoFitGrid(minColumnWidth: 170, spacing: 14) {
                    StatTile(value: "\(company.totalDancers)", label: "Total dancers",
                             symbol: "figure.dance", colors: [Color(hex: "#FF4D4D"), Theme.red])
                    StatTile(value: "\(company.danceGroups.count)", label: company.danceGroups.count == 1 ? "Dance group" : "Dance groups",
                             symbol: "person.3.fill", colors: [Theme.red, Theme.darkRed])
                    StatTile(value: "\(company.totalCompetitionWins)", label: "Competition wins",
                             symbol: "trophy.fill", colors: [Theme.darkRed, Color(hex: "#1A1A1A")])
                    if let students = company.totalStudents {
                        StatTile(value: "\(students)", label: "Students",
                                 symbol: "graduationcap.fill", colors: [Color(hex: "#3A3A3A"), Color(hex: "#111111")])
                    }
                }

                SectionTitle(title: "Dance Groups")
                if company.danceGroups.isEmpty {
                    Label("No dance groups yet. Click New Dance Group to add one.", systemImage: "figure.dance")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                }
                AutoFitGrid(minColumnWidth: 300, spacing: 14) {
                    ForEach(company.danceGroups) { crew in
                        DanceGroupCard(crew: crew)
                            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .onTapGesture { appState.navigate(to: .danceGroup(crew.id)) }
                            .hoverLift()
                            .contextMenu {
                                Button("Edit…") { appState.danceSheet = .edit(crew) }
                                Button("Delete…", role: .destructive) { crewToDelete = crew }
                            }
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                }
                .animation(Theme.bouncy, value: company.danceGroups.map(\.id))
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
        .deleteDanceGroupDialog($crewToDelete)
    }
}

struct DanceTypeBadge: View {
    let type: DanceGroupType
    var onColor: Color = .white

    var body: some View {
        Label(type.rawValue, systemImage: type.symbol)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .foregroundStyle(onColor)
            .background(Capsule().fill(onColor.opacity(0.16)))
            .overlay(Capsule().strokeBorder(onColor.opacity(0.35)))
    }
}

struct DanceGroupCard: View {
    let crew: DanceGroup
    @Environment(AppState.self) private var appState

    var body: some View {
        let company = appState.company
        let textColor: Color = crew.colors[0].isLight ? .black : .white
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                crew.gradient
                Image(systemName: crew.type.symbol)
                    .font(.system(size: 84, weight: .black))
                    .foregroundStyle(textColor.opacity(0.12))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .offset(x: 6, y: 10)
                DanceTypeBadge(type: crew.type, onColor: textColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(12)
                HStack(spacing: 12) {
                    DanceLogo(crew: crew, size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(crew.name.isEmpty ? "Untitled" : crew.name)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                        if let formed = crew.formedDate {
                            Text("Formed \(formed.formatted(date: .abbreviated, time: .omitted))").font(.caption.weight(.medium)).opacity(0.85)
                        } else {
                            Text("Formed date not added yet").font(.caption.italic()).opacity(0.55)
                        }
                    }
                    .foregroundStyle(textColor)
                }
                .padding(16)
            }
            .frame(height: 108)
            .clipped()

            VStack(alignment: .leading, spacing: 12) {
                SwiftUI.Group {
                    if crew.summary.isEmpty {
                        Text("Description not added yet").italic().foregroundStyle(.tertiary)
                    } else {
                        Text(crew.summary).foregroundStyle(.secondary)
                    }
                }
                .font(.callout)
                .lineLimit(2, reservesSpace: true)

                if crew.styles.isEmpty {
                    NotAddedYet(text: "No styles yet")
                } else {
                    FlowLayout(spacing: 5, lineSpacing: 5) {
                        ForEach(crew.styles.prefix(5), id: \.self) { Chip(text: $0, tint: crew.ink) }
                        if crew.styles.count > 5 { Chip(text: "+\(crew.styles.count - 5)") }
                    }
                }

                if !crew.headChoreographer.isEmpty {
                    Label("\(crew.type.leadTitle): \(crew.headChoreographer)", systemImage: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                switch crew.type {
                case .performanceTeam:
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill").foregroundStyle(crew.competitionWins > 0 ? crew.ink : Color.secondary)
                        Text(crew.competitionSummary)
                    }
                    .font(.caption.weight(.medium))
                    BackupChips(crew: crew, company: company, compact: true)
                case .academy:
                    if crew.teaches.isEmpty {
                        NotAddedYet(text: "Teaches: not added yet")
                    } else {
                        FlowLayout(spacing: 5, lineSpacing: 5) {
                            Text("Teaches").font(.caption).foregroundStyle(.secondary)
                            ForEach(crew.teaches, id: \.self) { Chip(text: $0, tint: .white) }
                        }
                    }
                    Label(crew.classes.isEmpty ? "No classes yet" : "\(crew.classes.count) \(crew.classes.count == 1 ? "class" : "classes")",
                          systemImage: "list.bullet.rectangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Spacer()
                    if crew.type == .academy { StudentsPill(crew: crew) }
                    DancerCountPill(crew: crew)
                }
            }
            .padding(16)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.glass)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(LinearGradient(colors: [crew.colors[0].opacity(0.55), .white.opacity(0.08)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)))
    }
}

/// Crew logo or photo; falls back to the first letter in the crew's accent color.
struct DanceLogo: View {
    let crew: DanceGroup
    var size: CGFloat

    var body: some View {
        AvatarView(photoFileName: crew.logoFileName, initial: crew.initial, symbol: "",
                   colorHex: crew.accentHex, size: size, cornerRadius: size * 0.28)
    }
}

/// "Backs up" chips: each idol group or unit with its members' photos. Click to open that group.
struct BackupChips: View {
    let crew: DanceGroup
    let company: Company
    var compact = false
    @Environment(AppState.self) private var appState

    var body: some View {
        let items = company.worksWithItems(for: crew)
        if items.isEmpty {
            NotAddedYet(text: compact ? "Backs up: not added yet" : "Not added yet")
        } else {
            FlowLayout(spacing: 6, lineSpacing: 6) {
                if compact { Text("Backs up").font(.caption).foregroundStyle(.secondary) }
                ForEach(items, id: \.id) { item in
                    if let group = company.groups.first(where: { $0.id == item.groupID }) {
                        let members: [IdolMember] = {
                            if item.id == group.id { return group.members }
                            let unit = group.subUnits.first { $0.id == item.id }
                            return unit?.memberIDs.compactMap(group.member(with:)) ?? []
                        }()
                        Button { appState.navigate(to: .group(group.id)) } label: {
                            HStack(spacing: 6) {
                                if members.isEmpty {
                                    Circle().fill(group.gradient).frame(width: 16, height: 16)
                                } else {
                                    AvatarStack(members: Array(members.prefix(4)), size: 18)
                                }
                                Text(item.name).font(.caption.weight(.semibold))
                            }
                            .padding(.leading, 4).padding(.trailing, 10).padding(.vertical, 3)
                            .background(group.colors[0].opacity(0.16), in: Capsule())
                            .overlay(Capsule().strokeBorder(group.colors[0].readableOnDark.opacity(0.4)))
                        }
                        .buttonStyle(.plain)
                        .help("Open \(item.name)")
                    }
                }
            }
        }
    }
}

// MARK: - Quick count pills

/// Pill showing a number; click for a − / + / Save popup (never below 0).
struct QuickCountPill: View {
    let symbol: String
    let text: String
    let title: String
    let subtitle: String
    let tint: Color
    let value: Int?
    let maxValue: Int
    let onSave: (Int) -> Void
    var onClear: (() -> Void)? = nil

    @Environment(AppState.self) private var appState
    @State private var hovering = false

    var body: some View {
        Button {
            let (symbol, title, subtitle, tint, start, maxValue, onSave, onClear) =
                (self.symbol, self.title, self.subtitle, self.tint, value ?? 0, self.maxValue, self.onSave, self.onClear)
            appState.present(maxWidth: 340) { close in
                QuickCountEditor(symbol: symbol, title: title, subtitle: subtitle, tint: tint, start: start,
                                 maxValue: maxValue, onSave: onSave, onClear: onClear, close: close)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                Text(text).monospacedDigit()
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(tint)
            .background(Capsule().fill(tint.opacity(0.14)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.3)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.8)).opacity(hovering ? 1 : 0))
            .scaleEffect(hovering ? 1.06 : 1)
            .keyframeAnimator(initialValue: 1.0, trigger: value) { pill, scale in
                pill.scaleEffect(scale)
            } keyframes: { _ in
                SpringKeyframe(1.18, duration: 0.12, spring: .snappy)
                SpringKeyframe(1.0, duration: 0.3, spring: .bouncy)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.bouncy, value: hovering)
        .help("Edit \(title.lowercased())")
    }
}

private struct QuickCountEditor: View {
    let symbol: String
    let title: String
    let subtitle: String
    let tint: Color
    let maxValue: Int
    let onSave: (Int) -> Void
    let onClear: (() -> Void)?
    let close: () -> Void
    @State private var text: String
    @State private var shakeCount = 0

    init(symbol: String, title: String, subtitle: String, tint: Color, start: Int, maxValue: Int,
         onSave: @escaping (Int) -> Void, onClear: (() -> Void)?, close: @escaping () -> Void) {
        self.symbol = symbol; self.title = title; self.subtitle = subtitle; self.tint = tint
        self.maxValue = maxValue; self.onSave = onSave; self.onClear = onClear; self.close = close
        _text = State(initialValue: String(start))
    }

    private var value: Int? { Int(text) }
    private var isValid: Bool { value.map { (0...maxValue).contains($0) } ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                Image(systemName: symbol).foregroundStyle(tint)
                Text(title).font(.headline)
                Spacer()
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            AwardStepper(text: $text, tint: tint, maxValue: maxValue)
                .onSubmit(save)
                .modifier(Shake(animatableData: CGFloat(shakeCount)))
            if !isValid { ErrorText("Enter a whole number from 0 to \(maxValue).") }
            HStack(spacing: 10) {
                if let onClear {
                    Button("Clear") { onClear(); close() }
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
    }

    private func save() {
        guard let value, isValid else {
            withAnimation(.linear(duration: 0.4)) { shakeCount += 1 }
            NSSound.beep()
            return
        }
        onSave(value)
        close()
    }
}

/// "30 dancers" (or "25 instructors" on an academy that chose that label).
struct DancerCountPill: View {
    let crew: DanceGroup
    /// Override the color, e.g. on the crew's own colored banner.
    var tint: Color? = nil
    var body: some View {
        QuickCountPill(symbol: "figure.dance", text: crew.countText,
                       title: crew.type == .academy ? crew.countLabel.rawValue : "Dancers",
                       subtitle: crew.name, tint: tint ?? crew.ink, value: crew.dancerCount,
                       maxValue: DanceGroup.maxDancers) { crew.setDancerCount($0) }
    }
}

/// Academy students (optional, separate from dancers).
struct StudentsPill: View {
    let crew: DanceGroup
    var body: some View {
        QuickCountPill(symbol: "graduationcap.fill",
                       text: crew.students.map { "\($0) \($0 == 1 ? "student" : "students")" } ?? "Students: add",
                       title: "Students", subtitle: crew.name, tint: crew.students == nil ? .secondary : .white,
                       value: crew.students, maxValue: DanceGroup.maxStudents,
                       onSave: { crew.setStudents($0) },
                       onClear: crew.students == nil ? nil : { crew.setStudents(nil) })
    }
}

extension View {
    /// Shared "Delete this dance group?" confirmation.
    func deleteDanceGroupDialog(_ crew: Binding<DanceGroup?>) -> some View {
        modifier(DeleteDanceGroupDialog(crew: crew))
    }
}

private struct DeleteDanceGroupDialog: ViewModifier {
    @Binding var crew: DanceGroup?
    @Environment(AppState.self) private var appState

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Delete \(crew?.name ?? "this dance group")?",
            isPresented: Binding(get: { crew != nil }, set: { if !$0 { crew = nil } }),
            presenting: crew
        ) { crew in
            Button("Delete Dance Group", role: .destructive) { appState.deleteDanceGroup(crew) }
        } message: { crew in
            Text("This removes \(crew.name) (\(crew.countText)), its logo, competitions and classes. Idol groups aren't affected. It can't be undone.")
        }
    }
}
