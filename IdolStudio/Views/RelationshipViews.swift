import SwiftUI

enum RelationshipEditorMode: Identifiable {
    /// Adding a relationship starting from this member.
    case add(from: UUID)
    /// Editing, seen from `viewer`'s side.
    case edit(Relationship, viewer: UUID)

    var id: String {
        switch self {
        case .add(let from): "add-\(from)"
        case .edit(let r, _): r.id.uuidString
        }
    }
}

// MARK: - Chip

/// "Ningning · Couple" with the other person's photo, type icon and status. Click to open that person.
struct RelationshipChip: View {
    let relationship: Relationship
    let viewer: UUID
    let company: Company
    let onOpen: (IdolMember) -> Void
    @State private var hovering = false

    var body: some View {
        if let other = company.member(withID: relationship.other(than: viewer)) {
            let tint = Color(hex: other.colorAccent).readableOnDark
            let isCouple = relationship.type == .builtIn(.couple)
            let isTwin = relationship.type == .builtIn(.twin)
            Button { onOpen(other) } label: {
                HStack(spacing: 5) {
                    MemberAvatar(member: other, size: 22)
                    Text(other.stageName).font(.caption.weight(.semibold)).lineLimit(1)
                    Text("·").foregroundStyle(.tertiary)
                    if isCouple {
                        Image(systemName: "heart.fill").foregroundStyle(Theme.red)
                    } else if isTwin {
                        Image(systemName: "figure.2").foregroundStyle(tint)
                    }
                    Text(company.label(for: relationship, viewer: viewer))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    StatusMarker(status: relationship.status)
                    if relationship.visibility == .private {
                        Image(systemName: "eye.slash.fill").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .padding(.leading, 3)
                .padding(.trailing, 9)
                .padding(.vertical, 3)
                .background((isCouple ? Theme.red : tint).opacity(isCouple ? 0.16 : 0.12), in: Capsule())
                .overlay(Capsule().strokeBorder((isCouple ? Theme.red : tint).opacity(isCouple ? 0.55 : 0.3), lineWidth: 1))
                .scaleEffect(hovering ? 1.05 : 1)
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .animation(Theme.bouncy, value: hovering)
            .help(helpText(other))
        }
    }

    private func helpText(_ other: IdolMember) -> String {
        var parts = ["\(other.stageName): \(company.label(for: relationship, viewer: viewer))",
                     relationship.status.rawValue, relationship.visibility.rawValue]
        if !relationship.note.isEmpty { parts.append(relationship.note) }
        return parts.joined(separator: " · ")
    }
}

/// Chips for one member plus edit/delete in each chip's right-click menu (delete asks first).
struct RelationshipChipList: View {
    let member: IdolMember
    @Environment(AppState.self) private var appState
    var onEdit: (RelationshipEditorMode) -> Void
    /// When true, clicking a chip edits that relationship instead of opening the other person's profile
    /// (used inside the member form, where the profile popup would be hidden behind the sheet).
    var clickToEdit = false
    @State private var pendingDelete: Relationship?

    var body: some View {
        let company = appState.company
        let relationships = company.relationships(for: member.id)
        let current = relationships.filter { $0.status != .past }
        let past = relationships.filter { $0.status == .past }
        SwiftUI.Group {
            if relationships.isEmpty {
                NotAddedYet()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if !current.isEmpty {
                        if !past.isEmpty { sectionLabel("Current") }
                        chips(current, company: company)
                    }
                    if !past.isEmpty {
                        sectionLabel("Past")
                        chips(past, company: company)
                            .opacity(0.75)
                    }
                }
            }
        }
        .animation(Theme.bouncy, value: relationships.map(\.id))
        .animation(Theme.bouncy, value: relationships.map(\.status))
        .confirmationDialog(
            "Delete this relationship?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { relationship in
            Button("Delete", role: .destructive) {
                withAnimation(Theme.bouncy) { company.deleteRelationship(id: relationship.id) }
            }
        } message: { relationship in
            let other = company.member(withID: relationship.other(than: member.id))?.stageName ?? "them"
            Text("\(member.stageName) and \(other) will no longer be linked as \(company.typeName(relationship.type)). It's removed from both profiles.")
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.1)
            .foregroundStyle(.tertiary)
    }

    private func chips(_ relationships: [Relationship], company: Company) -> some View {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(relationships) { relationship in
                        RelationshipChip(relationship: relationship, viewer: member.id, company: company) { other in
                            if clickToEdit {
                                onEdit(.edit(relationship, viewer: member.id))
                            } else {
                                appState.openProfile(other)
                            }
                        }
                        .contextMenu {
                            Button("Edit Relationship…") { onEdit(.edit(relationship, viewer: member.id)) }
                            Button("Delete Relationship…", role: .destructive) { pendingDelete = relationship }
                        }
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
    }
}

/// Tiny icon showing a relationship's status (full text is in the chip's tooltip).
struct StatusMarker: View {
    let status: RelationshipStatus

    var body: some View {
        let symbol: String = switch status {
        case .current: "circle.fill"
        case .past: "clock.arrow.circlepath"
        case .complicated: "questionmark.circle.fill"
        case .secret: "lock.fill"
        }
        Image(systemName: symbol)
            .font(.system(size: status == .current ? 5 : 9, weight: .bold))
            .foregroundStyle(status == .current ? Color.white.opacity(0.85) : .secondary)
            .help(status.rawValue)
    }
}

// MARK: - Add / edit sheet

struct RelationshipEditorView: View {
    let mode: RelationshipEditorMode
    let company: Company

    @Environment(\.closeModal) private var dismiss
    @State private var otherID: UUID?
    @State private var type: RelationshipType
    @State private var status: RelationshipStatus
    @State private var visibility: RelationshipVisibility
    @State private var note: String
    @State private var viewerIsSideA: Bool
    @State private var search = ""
    @State private var addingType = false
    @State private var newTypeName = ""
    @State private var newTypeOtherSide = ""
    @State private var showErrors = false
    @State private var shakeCount = 0
    @State private var confirmDelete = false
    @State private var hasStartDate: Bool
    @State private var startDate: Date
    /// Current couples that clash with this one (asked about before saving).
    @State private var coupleConflicts: [Relationship] = []

    static let noteLimit = 120

    init(mode: RelationshipEditorMode, company: Company) {
        self.mode = mode
        self.company = company
        switch mode {
        case .add:
            _otherID = State(initialValue: nil)
            _type = State(initialValue: .builtIn(.friend))
            _status = State(initialValue: .current)
            _visibility = State(initialValue: .public)
            _note = State(initialValue: "")
            _viewerIsSideA = State(initialValue: true)
            _hasStartDate = State(initialValue: false)
            _startDate = State(initialValue: .now)
        case .edit(let r, let viewer):
            _otherID = State(initialValue: r.other(than: viewer))
            _type = State(initialValue: r.type)
            _status = State(initialValue: r.status)
            _visibility = State(initialValue: r.visibility)
            _note = State(initialValue: r.note)
            _viewerIsSideA = State(initialValue: r.memberA == viewer)
            _hasStartDate = State(initialValue: r.startDate != nil)
            _startDate = State(initialValue: r.startDate ?? .now)
        }
    }

    private var viewerID: UUID {
        switch mode {
        case .add(let from): from
        case .edit(_, let viewer): viewer
        }
    }
    private var existing: Relationship? {
        if case .edit(let r, _) = mode { return r }
        return nil
    }
    private var viewer: IdolMember? { company.member(withID: viewerID) }
    private var other: IdolMember? { otherID.flatMap(company.member(withID:)) }

    // MARK: Validation

    private var personError: String? {
        if otherID == viewerID { return "Someone can't be linked to themselves." }
        return otherID == nil && showErrors ? "Pick who they're connected to." : nil
    }

    private var duplicateError: String? {
        guard let otherID else { return nil }
        let clash = company.relationships.contains {
            $0.id != existing?.id && $0.connects(viewerID, otherID) && $0.type == type
        }
        return clash ? "They already have a \(company.typeName(type)) relationship." : nil
    }

    private var noteError: String? {
        note.count > Self.noteLimit ? "Notes can be up to \(Self.noteLimit) characters." : nil
    }

    private var isValid: Bool { otherID != nil && otherID != viewerID && duplicateError == nil && noteError == nil }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    personSection
                    typeSection
                    statusSection
                    EditorSection(title: "Start Date", symbol: "calendar") {
                        HStack(spacing: 10) {
                            Toggle("Add start date", isOn: $hasStartDate.animation(Theme.bouncy))
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                            if hasStartDate {
                                DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    .transition(.opacity)
                            } else {
                                Text("Optional").font(.callout.italic()).foregroundStyle(.tertiary)
                            }
                            Spacer()
                        }
                    }
                    EditorSection(title: "Note", symbol: "text.quote", error: noteError) {
                        FieldBox(label: nil, trailing: "\(note.count)/\(Self.noteLimit)", focused: false, invalid: noteError != nil) {
                            TextField("Optional, e.g. \"Met as trainees in 2019\"", text: $note, axis: .vertical)
                                .lineLimit(1...3)
                        }
                    }
                }
                .padding(20)
            }
            footer
        }
        .modalFrame(width: 600, height: 760)
        .background {
            ZStack {
                VisualEffectBackground(material: .sheet, blending: .withinWindow)
                Color.black.opacity(0.6)
            }
        }
        .confirmationDialog(
            "Already in a current couple",
            isPresented: Binding(get: { !coupleConflicts.isEmpty }, set: { if !$0 { coupleConflicts = [] } })
        ) {
            Button("Mark Old Couple as Past and Save") {
                withAnimation(Theme.bouncy) {
                    for var old in coupleConflicts {
                        old.status = .past
                        company.save(old)
                    }
                }
                coupleConflicts = []
                commit()
            }
            Button("Cancel", role: .cancel) { coupleConflicts = [] }
        } message: {
            Text(conflictMessage)
        }
        .confirmationDialog("Delete this relationship?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                if let existing { withAnimation(Theme.bouncy) { company.deleteRelationship(id: existing.id) } }
                dismiss()
            }
        } message: {
            Text("It's removed from both people's cards. This can't be undone.")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            if let viewer { MemberAvatar(member: viewer, size: 52) }
            Image(systemName: type == .builtIn(.couple) ? "heart.fill" : "arrow.left.arrow.right")
                .font(.title3.weight(.bold))
                .foregroundStyle(type == .builtIn(.couple) ? Theme.red : .secondary)
                .contentTransition(.opacity)
            if let other {
                MemberAvatar(member: other, size: 52).transition(.scale.combined(with: .opacity))
            } else {
                Circle().strokeBorder(.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .frame(width: 52, height: 52)
                    .overlay(Image(systemName: "questionmark").foregroundStyle(.tertiary))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(existing == nil ? "ADD RELATIONSHIP" : "EDIT RELATIONSHIP")
                    .font(.caption.weight(.semibold)).tracking(1.2).foregroundStyle(.secondary)
                Text("\(viewer?.stageName ?? "?") & \(other?.stageName ?? "…")")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(company.typeName(type)).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(LinearGradient(colors: [Theme.red.opacity(0.22), .clear], startPoint: .top, endPoint: .bottom))
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
        .animation(Theme.bouncy, value: otherID)
    }

    private var personSection: some View {
        EditorSection(title: "Person", symbol: "person.crop.circle", error: personError ?? duplicateError) {
            FieldBox(label: nil, focused: false) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search all groups", text: $search)
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(company.groups) { group in
                        let people = group.members.filter { $0.id != viewerID && matches($0, group) }
                        if !people.isEmpty {
                            Text(group.name.uppercased())
                                .font(.caption2.weight(.semibold)).tracking(1.1)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 6)
                            ForEach(people) { person in personRow(person, group: group) }
                        }
                    }
                    if company.allMembers.filter({ $0.id != viewerID }).isEmpty {
                        Text("Add more members first.").foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 190)
            .modifier(Shake(animatableData: otherID == nil ? CGFloat(shakeCount) : 0))
        }
    }

    private func matches(_ person: IdolMember, _ group: IdolGroup) -> Bool {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return true }
        return [person.stageName, person.realName, group.name].contains { $0.lowercased().contains(query) }
    }

    private func personRow(_ person: IdolMember, group: IdolGroup) -> some View {
        let selected = otherID == person.id
        let tint = Color(hex: person.colorAccent)
        return Button {
            withAnimation(Theme.bouncy) { otherID = person.id }
        } label: {
            HStack(spacing: 10) {
                MemberAvatar(member: person, size: 30)
                VStack(alignment: .leading, spacing: 0) {
                    Text(person.stageName).font(.callout.weight(.semibold))
                    Text(person.realName.isEmpty ? group.name : "\(person.realName) · \(group.name)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(tint.readableOnDark)
                    .opacity(selected ? 1 : 0)
                    .scaleEffect(selected ? 1 : 0.5)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(tint.opacity(0.15)).opacity(selected ? 1 : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var allTypes: [RelationshipType] {
        BuiltInRelationshipType.allCases.map { .builtIn($0) } + company.customRelationshipTypes.map { .custom($0.id) }
    }

    private var typeSection: some View {
        EditorSection(title: "Type", symbol: "link") {
            FlowLayout(spacing: 7, lineSpacing: 7) {
                ForEach(allTypes, id: \.self) { candidate in
                    typeChip(candidate)
                }
                Button {
                    withAnimation(Theme.bouncy) { addingType.toggle() }
                } label: {
                    Label("Custom type", systemImage: addingType ? "xmark" : "plus")
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .overlay(Capsule().strokeBorder(Theme.red.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
                .buttonStyle(.plain)
            }
            if addingType {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        FieldBox(label: "Name", focused: false) {
                            TextField("e.g. Senpai", text: $newTypeName)
                        }
                        FieldBox(label: "Other side (optional)", focused: false) {
                            TextField("e.g. Kouhai", text: $newTypeOtherSide)
                        }
                    }
                    HStack {
                        Text("Fill in the other side only if the two people have different roles.")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Add Type", action: addCustomType)
                            .buttonStyle(SpringyButtonStyle(kind: .secondary))
                            .disabled(newTypeName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .transition(.opacity)
            }
            if let sides = company.sideLabels(type), let viewer, let other {
                Picker("Direction", selection: $viewerIsSideA) {
                    Text("\(viewer.stageName) is the \(sides.a)").tag(true)
                    Text("\(other.stageName) is the \(sides.a)").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .transition(.opacity)
            }
        }
    }

    private func typeChip(_ candidate: RelationshipType) -> some View {
        let selected = candidate == type
        let tint = candidate == .builtIn(.couple) ? Theme.red : Color(hex: "#FF4D4D")
        return Button {
            withAnimation(Theme.bouncy) { type = candidate }
        } label: {
            HStack(spacing: 5) {
                if candidate == .builtIn(.couple) { Image(systemName: "heart.fill").font(.caption) }
                if candidate == .builtIn(.twin) { Image(systemName: "figure.2").font(.caption) }
                Text(company.typeName(candidate)).font(.callout.weight(.medium))
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .foregroundStyle(selected ? .white : .primary)
            .background(Capsule().fill(.white.opacity(0.07)))
            .background(Capsule().fill(tint).opacity(selected ? 1 : 0))
            .overlay(Capsule().strokeBorder(.white.opacity(0.1)))
            .scaleEffect(selected ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if case .custom(let id) = candidate {
                Button("Delete Custom Type", role: .destructive) {
                    withAnimation(Theme.bouncy) {
                        company.deleteCustomType(id)
                        if type == candidate { type = .builtIn(.other) }
                    }
                }
                .disabled(company.isCustomTypeInUse(id))
            }
        }
        .help({ if case .custom(let id) = candidate, company.isCustomTypeInUse(id) { return "In use, so it can't be deleted" }; return "" }())
    }

    private var statusSection: some View {
        EditorSection(title: "Status", symbol: "flag") {
            Picker("Status", selection: $status) {
                ForEach(RelationshipStatus.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            HStack {
                Text("Does the world know?").font(.callout).foregroundStyle(.secondary)
                Spacer()
                Picker("Visibility", selection: $visibility) {
                    Label("Public", systemImage: "eye").tag(RelationshipVisibility.public)
                    Label("Private", systemImage: "eye.slash").tag(RelationshipVisibility.private)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if existing != nil {
                Button("Delete", role: .destructive) { confirmDelete = true }
                    .buttonStyle(SpringyButtonStyle(kind: .destructive))
            }
            Spacer()
            Button("Cancel") { dismiss() }
                .buttonStyle(SpringyButtonStyle(kind: .secondary))
                .keyboardShortcut(.cancelAction)
            Button(action: save) { Label("Save", systemImage: "checkmark") }
                .buttonStyle(SpringyButtonStyle(kind: .primary, dimmed: !isValid))
                .keyboardShortcut(.return, modifiers: .command)
                .modifier(Shake(animatableData: CGFloat(shakeCount)))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.black.opacity(0.25))
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
    }

    // MARK: Actions

    private func addCustomType() {
        let name = newTypeName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let created = company.addCustomType(name: name, otherSideName: newTypeOtherSide.trimmingCharacters(in: .whitespaces))
        withAnimation(Theme.bouncy) {
            type = .custom(created.id)
            addingType = false
            newTypeName = ""
            newTypeOtherSide = ""
        }
    }

    private func save() {
        guard isValid, let otherID else {
            withAnimation(Theme.bouncy) { showErrors = true }
            withAnimation(.linear(duration: 0.45)) { shakeCount += 1 }
            NSSound.beep()
            return
        }
        let candidate = makeRelationship(otherID: otherID)
        let conflicts = company.coupleConflicts(for: candidate)
        if !conflicts.isEmpty {
            coupleConflicts = conflicts   // ask first; Save continues from the dialog
            return
        }
        commit()
    }

    private var conflictMessage: String {
        let lines = coupleConflicts.map { r -> String in
            let a = company.member(withID: r.memberA)?.stageName ?? "?"
            let b = company.member(withID: r.memberB)?.stageName ?? "?"
            return "\(a) & \(b)"
        }
        return "A person can only have one current Couple. Currently: \(lines.joined(separator: ", ")). Mark that couple as Past, or cancel."
    }

    private func commit() {
        guard let otherID else { return }
        withAnimation(Theme.bouncy) { company.save(makeRelationship(otherID: otherID)) }
        dismiss()
    }

    private func makeRelationship(otherID: UUID) -> Relationship {
        // For directional types, side A holds the first label (e.g. the Mentor).
        let directional = company.sideLabels(type) != nil
        let aIsViewer = directional ? viewerIsSideA : true
        let relationship = Relationship(
            id: existing?.id ?? UUID(),
            memberA: aIsViewer ? viewerID : otherID,
            memberB: aIsViewer ? otherID : viewerID,
            type: type,
            status: status,
            visibility: visibility,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: hasStartDate ? startDate : nil
        )
        return relationship
    }
}

// MARK: - Member profile popup

/// A member's profile over the window: large photo, roles, relationship status and relationships.
/// Clicking a relationship switches to that person. Opacity and scale animations only.
struct MemberProfileView: View {
    let member: IdolMember
    @Environment(AppState.self) private var appState
    @State private var shown = false

    var body: some View {
        let company = appState.company
        let color = Color(hex: member.colorAccent)
        let group = company.group(containing: member.id)
        ZStack {
            Color.black.opacity(0.8)
                .contentShape(Rectangle())
                .onTapGesture(perform: close)

            HStack(alignment: .top, spacing: 28) {
                MemberAvatar(member: member, size: 300, cornerRadius: 30)
                    .shadow(color: color.opacity(0.45), radius: 40)
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let group {
                            Text(group.name.uppercased()).font(.caption.weight(.semibold)).tracking(1.3)
                                .foregroundStyle(color.readableOnDark)
                        }
                        Text(member.stageName).font(.system(size: 34, weight: .heavy, design: .rounded))
                        if member.realName.isEmpty {
                            NotAddedYet(text: "No real name yet")
                        } else {
                            Text(member.realName).foregroundStyle(.secondary)
                        }
                    }
                    FlowLayout(spacing: 6, lineSpacing: 6) {
                        ForEach(Array(member.roles.enumerated()), id: \.element) { index, role in
                            Chip(text: role.rawValue, tint: index == 0 ? color : color.readableOnDark, filled: index == 0)
                        }
                    }
                    PartnerLine(member: member)
                    Divider().opacity(0.4)
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.wave.2.fill").foregroundStyle(color.readableOnDark)
                        Text("Relationships & Dynamics").font(.headline)
                    }
                    RelationshipChipList(member: member) { mode in
                        close()
                        appState.relationshipSheet = mode
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 10) {
                        Button {
                            close()
                            appState.relationshipSheet = .add(from: member.id)
                        } label: { Label("Add Relationship", systemImage: "plus") }
                            .buttonStyle(SpringyButtonStyle(kind: .secondary))
                        Button {
                            close()
                            appState.edit(member)
                        } label: { Label("Edit Member", systemImage: "pencil") }
                            .buttonStyle(SpringyButtonStyle(kind: .primary))
                    }
                }
                .frame(width: 360, alignment: .leading)
                .frame(minHeight: 300)
            }
            .padding(30)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color(hex: "#141416").opacity(0.96)))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(color.opacity(0.35)))
            .scaleEffect(shown ? 1 : 0.92)
            .opacity(shown ? 1 : 0)
            .id(member.id)

            VStack {
                HStack {
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 34, height: 34)
                            .background(.white.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    .help("Close (Esc)")
                }
                Spacer()
            }
            .padding(.top, 44)
            .padding(.trailing, 24)
        }
        .onAppear { withAnimation(Theme.bouncy) { shown = true } }
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.18)) { appState.profileMember = nil }
    }
}

/// "Partner: ♥ [photo] Ningning" when the member has a current Couple; otherwise their manual
/// relationship status (e.g. "Single") if one is set; otherwise nothing.
struct PartnerLine: View {
    let member: IdolMember
    @Environment(AppState.self) private var appState

    var body: some View {
        let company = appState.company
        if let partner = company.currentPartner(of: member.id) {
            Button { appState.openProfile(partner) } label: {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill").foregroundStyle(Theme.red)
                    Text("Partner:").foregroundStyle(.secondary)
                    MemberAvatar(member: partner, size: 20)
                    Text(partner.stageName).fontWeight(.semibold)
                }
                .font(.callout)
                .lineLimit(1)
            }
            .buttonStyle(.plain)
            .help("Open \(partner.stageName)'s profile")
            .transition(.opacity)
        } else if let status = member.relationshipStatus {
            HStack(spacing: 6) {
                Image(systemName: "heart").foregroundStyle(Theme.red)
                Text(status.rawValue).fontWeight(.medium)
            }
            .font(.callout)
            .transition(.opacity)
        }
    }
}
