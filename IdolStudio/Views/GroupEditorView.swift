import SwiftUI
import AppKit

enum GroupEditorMode: Identifiable {
    case add
    case edit(IdolGroup)

    var id: String {
        switch self {
        case .add: "add-group"
        case .edit(let group): group.id.uuidString
        }
    }
}

/// Sheet for creating a group (+ New Group, ⇧⌘N) or editing one (⌘E).
/// Works on a draft; nothing changes until Save.
struct GroupEditorView: View {
    let mode: GroupEditorMode

    @Environment(AppState.self) private var appState
    @Environment(\.closeModal) private var dismiss
    @State private var name: String
    @State private var concept: String
    @State private var fandomName: String
    @State private var bannerTag: String
    @State private var debutDate: Date
    @State private var hasDebut: Bool
    @State private var accentHex: String
    @State private var awardsText: String
    @State private var showErrors = false
    @State private var shakeCount = 0
    @State private var confirmDelete = false
    @FocusState private var focus: Field?

    private enum Field { case name, concept, fandom, hex }

    static let nameLimit = 24
    static let fandomLimit = 24
    static let conceptLimit = 140
    static let accentSwatches = ["#E50914", "#FF4D4D", "#B00020", "#8B0000", "#FFFFFF", "#2A2A2A"]

    init(mode: GroupEditorMode) {
        self.mode = mode
        switch mode {
        case .add:
            _name = State(initialValue: "")
            _concept = State(initialValue: "")
            _fandomName = State(initialValue: "")
            _bannerTag = State(initialValue: "")
            _debutDate = State(initialValue: .now)
            _hasDebut = State(initialValue: false)
            _accentHex = State(initialValue: "#E50914")
            _awardsText = State(initialValue: "0")   // new groups start at 0 awards
        case .edit(let group):
            _name = State(initialValue: group.name)
            _concept = State(initialValue: group.concept)
            _fandomName = State(initialValue: group.fandomName)
            _bannerTag = State(initialValue: group.bannerTag)
            _debutDate = State(initialValue: group.debutDate ?? .now)
            _hasDebut = State(initialValue: group.debutDate != nil)
            _accentHex = State(initialValue: group.themeColors.first ?? "#E50914")
            _awardsText = State(initialValue: String(group.awards))
        }
    }

    private var editingGroup: IdolGroup? {
        if case .edit(let group) = mode { return group }
        return nil
    }
    private var isAdding: Bool { editingGroup == nil }

    // MARK: Validation

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var trimmedFandom: String { fandomName.trimmingCharacters(in: .whitespaces) }

    private var isValidHex: Bool {
        accentHex.range(of: "^#?[0-9A-Fa-f]{6}$", options: .regularExpression) != nil
    }

    private var normalizedHex: String {
        let hex = accentHex.uppercased()
        return hex.hasPrefix("#") ? hex : "#" + hex
    }

    /// Theme gradient: the accent, keeping the group's existing second color if the accent wasn't changed.
    private var themeColors: [String] {
        let accent = isValidHex ? normalizedHex : "#E50914"
        if let group = editingGroup, group.themeColors.count >= 2,
           group.themeColors[0].uppercased() == accent {
            return Array(group.themeColors.prefix(2))
        }
        return [accent, Theme.darkerHex(accent)]
    }

    private var colors: [Color] { themeColors.map(Color.init(hex:)) }

    private var nameError: String? {
        if trimmedName.isEmpty { return showErrors ? "The group needs a name." : nil }
        if trimmedName.count > Self.nameLimit { return "Keep it to \(Self.nameLimit) characters or fewer." }
        let taken = appState.company.groups.contains {
            $0.id != editingGroup?.id && $0.name.trimmingCharacters(in: .whitespaces).lowercased() == trimmedName.lowercased()
        }
        return taken ? "Another group is already called \(trimmedName)." : nil
    }

    private var fandomError: String? {
        trimmedFandom.count > Self.fandomLimit ? "Keep it to \(Self.fandomLimit) characters or fewer." : nil
    }

    private var conceptError: String? {
        concept.count > Self.conceptLimit ? "Keep the concept to \(Self.conceptLimit) characters." : nil
    }

    private var awards: Int? { Int(awardsText) }

    private var awardsError: String? {
        guard let awards, (0...IdolGroup.maxAwards).contains(awards) else {
            return "Enter a whole number from 0 to \(IdolGroup.maxAwards)."
        }
        return nil
    }

    private var isValid: Bool {
        !trimmedName.isEmpty && nameError == nil && fandomError == nil && conceptError == nil && isValidHex
            && bannerTag.count <= 40
            && awardsError == nil
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            banner
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    EditorSection(title: "Identity", symbol: "music.mic") {
                        FieldBox(label: "Group Name", required: true, trailing: "\(trimmedName.count)/\(Self.nameLimit)",
                                 error: nameError, focused: focus == .name) {
                            TextField("e.g. LUMINA", text: $name)
                                .focused($focus, equals: .name)
                        }
                        .modifier(Shake(animatableData: nameError != nil || trimmedName.isEmpty ? CGFloat(shakeCount) : 0))
                        FieldBox(label: "Fandom Name", trailing: "\(trimmedFandom.count)/\(Self.fandomLimit)",
                                 error: fandomError, focused: focus == .fandom) {
                            TextField("e.g. Lumies", text: $fandomName)
                                .focused($focus, equals: .fandom)
                        }
                        FieldBox(label: "Concept", trailing: "\(concept.count)/\(Self.conceptLimit)",
                                 error: conceptError, focused: focus == .concept) {
                            TextField("e.g. Celestial dream-pop with starlit visuals", text: $concept, axis: .vertical)
                                .lineLimit(2...4)
                                .focused($focus, equals: .concept)
                        }
                    }

                    EditorSection(title: "Banner Tag", symbol: "tag") {
                        HStack(spacing: 10) {
                            FieldBox(label: nil, trailing: "\(bannerTag.count)/40",
                                     error: bannerTag.count > 40 ? "Keep it to 40 characters." : nil, focused: false) {
                                TextField("Optional, e.g. Formerly Bubble Girls", text: $bannerTag)
                            }
                            if !bannerTag.isEmpty {
                                Button(role: .destructive) { withAnimation(Theme.bouncy) { bannerTag = "" } } label: {
                                    Label("Remove Tag", systemImage: "xmark")
                                }
                                .buttonStyle(SpringyButtonStyle(kind: .destructive))
                                .transition(.opacity)
                            }
                        }
                        Text("A small pill shown above the group name in its banners.")
                            .font(.caption).foregroundStyle(.tertiary)
                    }

                    EditorSection(title: "Debut", symbol: "calendar") {
                        HStack(spacing: 10) {
                            Toggle("Add debut date", isOn: $hasDebut.animation(Theme.bouncy))
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                            if hasDebut {
                                DatePicker("Debut date", selection: $debutDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    .transition(.opacity)
                                Spacer()
                                Text(debutSummary).font(.callout).foregroundStyle(.secondary)
                            } else {
                                Text("Not added yet").font(.callout.italic()).foregroundStyle(.tertiary)
                                Spacer()
                            }
                        }
                    }

                    EditorSection(title: "Awards", symbol: "trophy", error: awardsError) {
                        HStack {
                            AwardStepper(text: $awardsText, tint: colors[0].readableOnDark)
                                .modifier(Shake(animatableData: awardsError != nil ? CGFloat(shakeCount) : 0))
                            Spacer()
                            Text("Shown on the group's overview card")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    EditorSection(title: "Accent Color", symbol: "paintpalette") {
                        HStack(spacing: 10) {
                            ForEach(Self.accentSwatches, id: \.self) { hex in
                                swatch(hex)
                            }
                            Spacer()
                            ColorPicker("Custom", selection: accentBinding, supportsOpacity: false)
                                .labelsHidden()
                            FieldBox(label: nil, focused: focus == .hex, invalid: !isValidHex) {
                                TextField("#E50914", text: $accentHex)
                                    .focused($focus, equals: .hex)
                                    .font(.system(.callout, design: .monospaced))
                            }
                            .frame(width: 100)
                        }
                        if !isValidHex {
                            ErrorText("Use a 6-digit hex color like #E50914.")
                        }
                    }
                }
                .padding(20)
            }
            footer
        }
        .modalFrame(width: 580, height: 780)
        .background {
            ZStack {
                VisualEffectBackground(material: .sheet, blending: .withinWindow)
                Color.black.opacity(0.6)
            }
        }
        .onAppear { focus = .name }
        .confirmationDialog(
            "Delete \(editingGroup?.name ?? "this group")?",
            isPresented: $confirmDelete
        ) {
            Button("Delete Group", role: .destructive, action: delete)
        } message: {
            Text(deleteMessage)
        }
    }

    private var deleteMessage: String {
        guard let group = editingGroup else { return "" }
        let rels = appState.company.relationshipCount(involving: Set(group.members.map(\.id)))
        return "This permanently removes \(group.members.count) members, \(group.subUnits.count) sub-units and \(rels == 1 ? "1 relationship" : "\(rels) relationships"). It can't be undone."
    }

    private var debutSummary: String {
        if debutDate > .now { return "Upcoming debut" }
        let parts = Calendar.current.dateComponents([.year, .month], from: debutDate, to: .now)
        let years = parts.year ?? 0, months = parts.month ?? 0
        return years > 0 ? "\(years)y \(months)m since debut" : "\(months)m since debut"
    }

    private var banner: some View {
        let textColor: Color = colors[0].isLight && colors[1].isLight ? .black : .white
        return ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "music.quarternote.3")
                .font(.system(size: 110, weight: .black))
                .foregroundStyle(textColor.opacity(0.12))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(x: 10, y: 20)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(isAdding ? "NEW GROUP" : "EDIT GROUP").font(.caption.weight(.semibold)).tracking(1.2).opacity(0.8)
                    let tag = bannerTag.trimmingCharacters(in: .whitespaces)
                    if !tag.isEmpty { BannerTag(text: tag, color: textColor) }
                }
                Text(trimmedName.isEmpty ? "Group Name" : trimmedName)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if trimmedFandom.isEmpty {
                        BannerPlaceholder(text: "Fandom not added yet", color: textColor)
                    } else {
                        Label(trimmedFandom, systemImage: "heart.fill").opacity(0.85)
                    }
                    Text("·").opacity(0.85)
                    if concept.isEmpty {
                        BannerPlaceholder(text: "Concept not added yet", color: textColor)
                    } else {
                        Text(concept).lineLimit(1).opacity(0.85)
                    }
                }
                .font(.callout)
            }
            .foregroundStyle(textColor)
            .padding(20)
        }
        .frame(height: 130)
        .clipped()
        .animation(Theme.bouncy, value: themeColors)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if !isAdding {
                Button("Delete Group", role: .destructive) { confirmDelete = true }
                    .buttonStyle(SpringyButtonStyle(kind: .destructive))
            }
            Spacer()
            if showErrors && !isValid {
                Label("Fix the highlighted fields", systemImage: "exclamationmark.circle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Theme.red)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            Button("Cancel") { dismiss() }
                .buttonStyle(SpringyButtonStyle(kind: .secondary))
                .keyboardShortcut(.cancelAction)
            Button(action: save) {
                Label(isAdding ? "Create Group" : "Save", systemImage: isAdding ? "plus" : "checkmark")
            }
            .buttonStyle(SpringyButtonStyle(kind: .primary, dimmed: !isValid))
            .keyboardShortcut(.return, modifiers: .command)
            .modifier(Shake(animatableData: CGFloat(shakeCount)))
            .help("⌘Return")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.black.opacity(0.25))
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
        .animation(Theme.bouncy, value: isValid)
    }

    private func swatch(_ hex: String) -> some View {
        let selected = isValidHex && normalizedHex == hex
        return Button {
            withAnimation(Theme.bouncy) { accentHex = hex }
        } label: {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 26, height: 26)
                .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                .padding(3)
                .overlay(Circle().strokeBorder(.white, lineWidth: selected ? 2 : 0))
                .scaleEffect(selected ? 1.12 : 1)
        }
        .buttonStyle(.plain)
        .help(hex)
    }

    private var accentBinding: Binding<Color> {
        Binding(get: { Color(hex: isValidHex ? normalizedHex : "#E50914") },
                set: { accentHex = $0.hexString })
    }

    // MARK: Actions

    private func save() {
        guard isValid else {
            withAnimation(Theme.bouncy) { showErrors = true }
            withAnimation(.linear(duration: 0.45)) { shakeCount += 1 }
            NSSound.beep()
            return
        }
        let cleanConcept = concept.trimmingCharacters(in: .whitespacesAndNewlines)
        if let group = editingGroup {
            withAnimation(Theme.bouncy) {
                group.name = trimmedName
                group.concept = cleanConcept
                group.fandomName = trimmedFandom
                group.bannerTag = bannerTag.trimmingCharacters(in: .whitespaces)
                group.debutDate = hasDebut ? debutDate : nil
                group.themeColors = themeColors
                group.setAwards(awards ?? 0)
            }
            dismiss()
        } else {
            let group = IdolGroup(name: trimmedName, concept: cleanConcept, fandomName: trimmedFandom,
                                  debutDate: hasDebut ? debutDate : nil, awards: awards ?? 0, themeColors: themeColors)
            group.bannerTag = bannerTag.trimmingCharacters(in: .whitespaces)
            dismiss()
            appState.createGroup(group)
        }
    }

    private func delete() {
        guard let group = editingGroup else { return }
        dismiss()
        appState.deleteGroup(group)
    }
}
