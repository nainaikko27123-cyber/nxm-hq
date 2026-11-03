import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum MemberEditorMode: Identifiable {
    case add
    case edit(IdolMember)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let member): member.id.uuidString
        }
    }
}

/// Editable copy of a member. Nothing touches the real model until Save.
struct MemberDraft {
    var stageName = ""
    var realName = ""
    var ageText = ""
    var hasBirthday = false
    var birthday = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? .now
    var roles: [MemberRole] = []
    var mbti = ""
    var traits: [String] = []
    var summary = ""
    var relationshipStatus: RelationshipStatusLine?
    var colorAccent = "#E50914"
    /// Empty = letter avatar.
    var avatarSymbol = ""
    var photoFileName: String?

    init() {}

    init(member: IdolMember) {
        stageName = member.stageName
        realName = member.realName
        ageText = member.age.map(String.init) ?? ""
        hasBirthday = member.birthday != nil
        if let date = member.birthday { birthday = date }
        roles = member.roles
        mbti = member.personality.mbti
        traits = member.personality.traits
        summary = member.personality.summary
        relationshipStatus = member.relationshipStatus
        colorAccent = member.colorAccent
        avatarSymbol = member.avatarSymbol
        photoFileName = member.photoFileName
    }

    var age: Int? { Int(ageText.trimmingCharacters(in: .whitespaces)) }

    private var personality: Personality {
        Personality(mbti: mbti, traits: traits, summary: summary.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func apply(to member: IdolMember) {
        member.stageName = stageName.trimmingCharacters(in: .whitespaces)
        member.realName = realName.trimmingCharacters(in: .whitespaces)
        member.age = age
        member.birthday = hasBirthday ? birthday : nil
        member.roles = roles
        member.personality = personality
        member.relationshipStatus = relationshipStatus
        member.colorAccent = colorAccent.uppercased()
        member.avatarSymbol = avatarSymbol
        member.photoFileName = photoFileName
    }

    func makeMember() -> IdolMember {
        IdolMember(
            stageName: stageName.trimmingCharacters(in: .whitespaces),
            realName: realName.trimmingCharacters(in: .whitespaces),
            age: age,
            birthday: hasBirthday ? birthday : nil,
            roles: roles,
            personality: personality,
            relationshipStatus: relationshipStatus,
            colorAccent: colorAccent.uppercased(),
            avatarSymbol: avatarSymbol,
            photoFileName: photoFileName
        )
    }
}

struct MemberEditorView: View {
    let mode: MemberEditorMode
    let group: IdolGroup

    @Environment(AppState.self) private var appState

    @Environment(\.closeModal) private var dismiss
    @State private var draft: MemberDraft
    @State private var newTrait = ""
    @State private var showErrors = false
    @State private var shakeCount = 0
    @State private var confirmRemove = false
    @FocusState private var focus: Field?

    // Photo
    @State private var cropSource: CropSource?
    @State private var showFilePicker = false
    @State private var dropTargeted = false
    @State private var headerDropTargeted = false
    @State private var photoError: String?
    /// Photo files written while this sheet was open; unused ones are deleted when it closes.
    @State private var createdPhotos: [String] = []
    @State private var didSave = false
    private let originalPhoto: String?

    private enum Field { case stageName, realName, age, trait, summary, hex, symbol }

    static let stageNameLimit = 20
    static let summaryLimit = 300
    static let auraSwatches = ["#E50914", "#8B0000", "#FF4D4D", "#FFFFFF", "#1A1A1A",
                               "#FF8FB1", "#C792EA", "#7FDBFF", "#9CF0C4", "#FFD27F"]

    init(mode: MemberEditorMode, group: IdolGroup) {
        self.mode = mode
        self.group = group
        switch mode {
        case .add:
            var draft = MemberDraft()
            draft.colorAccent = group.themeColors.first ?? "#E50914"
            _draft = State(initialValue: draft)
            originalPhoto = nil
        case .edit(let member):
            _draft = State(initialValue: MemberDraft(member: member))
            originalPhoto = member.photoFileName
        }
    }

    private var editingID: UUID? {
        if case .edit(let member) = mode { return member.id }
        return nil
    }

    private var isAdding: Bool { editingID == nil }
    private var aura: Color { Color(hex: isValidHex ? draft.colorAccent : "#E50914") }

    // MARK: Validation

    private var trimmedName: String { draft.stageName.trimmingCharacters(in: .whitespaces) }

    private var stageNameError: String? {
        if trimmedName.isEmpty { return showErrors ? "Every idol needs a stage name." : nil }
        if trimmedName.count > Self.stageNameLimit { return "Keep it to \(Self.stageNameLimit) characters or fewer." }
        let taken = group.members.contains {
            $0.id != editingID && $0.stageName.trimmingCharacters(in: .whitespaces).lowercased() == trimmedName.lowercased()
        }
        return taken ? "\(group.name) already has a member called \(trimmedName)." : nil
    }

    /// Roles are optional (members can start with none and get them later).
    private var rolesError: String? { nil }

    private var isValidHex: Bool {
        draft.colorAccent.range(of: "^#?[0-9A-Fa-f]{6}$", options: .regularExpression) != nil
    }

    private var symbolIsValid: Bool {
        draft.avatarSymbol.isEmpty || NSImage(systemSymbolName: draft.avatarSymbol, accessibilityDescription: nil) != nil
    }

    private var ageError: String? {
        let text = draft.ageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !draft.hasBirthday else { return nil }
        guard let age = Int(text), (1...99).contains(age) else { return "Enter an age from 1 to 99." }
        return nil
    }

    private var summaryTooLong: Bool { draft.summary.count > Self.summaryLimit }

    private var initial: String {
        trimmedName.first.map { String($0).uppercased() } ?? "?"
    }

    /// Age shown when a birthday is set (worked out from it).
    private var birthdayAge: Int? {
        Calendar.current.dateComponents([.year], from: draft.birthday, to: .now).year
    }


    private var isValid: Bool {
        !trimmedName.isEmpty
            && trimmedName.count <= Self.stageNameLimit
            && stageNameError == nil
            && isValidHex
            && symbolIsValid
            && ageError == nil
            && !summaryTooLong
    }

    private var problemCount: Int {
        [trimmedName.isEmpty || stageNameError != nil, !isValidHex, !symbolIsValid,
         ageError != nil, summaryTooLong]
            .filter { $0 }.count
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            previewHeader
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    identitySection
                    photoSection
                    rolesSection
                    personalitySection
                    auraSection
                    avatarSection
                    relationshipsSection
                }
                .padding(20)
            }
            footer
        }
        .modalFrame(width: 640, height: 780)
        .background {
            ZStack {
                VisualEffectBackground(material: .sheet, blending: .withinWindow)
                Color.black.opacity(0.6)
            }
        }
        .onAppear { if isAdding { focus = .stageName } }
        .onDisappear(perform: cleanUpPhotos)
        .sheet(item: $cropSource) { source in
            PhotoCropView(source: source.image, tint: aura) { cropped in
                do {
                    let fileName = try PhotoStore.save(croppedSquare: cropped)
                    createdPhotos.append(fileName)
                    withAnimation(.easeOut(duration: 0.2)) {
                        draft.photoFileName = fileName
                        photoError = nil
                    }
                } catch {
                    photoError = error.localizedDescription
                }
            }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: PhotoStore.allowedTypes) { result in
            if case .success(let url) = result { openForCropping(url) }
        }
        .confirmationDialog("Remove \(draft.stageName) from \(group.name)?", isPresented: $confirmRemove) {
            Button("Remove", role: .destructive) { remove() }
        } message: {
            Text(removalMessage)
        }
    }

    // MARK: Header

    private var previewHeader: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [aura.opacity(0.75), .clear], center: .center, startRadius: 20, endRadius: 58))
                    .frame(width: 116, height: 116)
                    .blur(radius: 6)
                draftAvatar(size: 72, cornerRadius: nil)
            }
            .frame(width: 90, height: 90)
            .photoDropTarget(isTargeted: $headerDropTargeted, tint: aura, perform: handleDrop)

            VStack(alignment: .leading, spacing: 4) {
                Text(isAdding ? "NEW MEMBER · \(group.name)" : "EDIT MEMBER · \(group.name)")
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Text(trimmedName.isEmpty ? "Stage Name" : trimmedName)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(trimmedName.isEmpty ? .tertiary : .primary)
                    .lineLimit(1)
                Text(draft.roles.isEmpty ? "Roles not added yet" : draft.roles.map(\.rawValue).joined(separator: " · "))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(LinearGradient(colors: [aura.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom))
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
        .animation(Theme.bouncy, value: draft.colorAccent)
        .animation(Theme.bouncy, value: draft.avatarSymbol)
    }

    // MARK: Sections

    private var identitySection: some View {
        EditorSection(title: "Identity", symbol: "person.text.rectangle") {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    FieldBox(label: "Stage Name", required: true,
                             trailing: "\(trimmedName.count)/\(Self.stageNameLimit)",
                             error: stageNameError, focused: focus == .stageName) {
                        TextField("e.g. Yuna", text: $draft.stageName)
                            .focused($focus, equals: .stageName)
                    }
                    .modifier(Shake(animatableData: stageNameError != nil || trimmedName.isEmpty ? CGFloat(shakeCount) : 0))
                }
                FieldBox(label: "Real Name", focused: focus == .realName) {
                    TextField("e.g. Kang Yu-na", text: $draft.realName)
                        .focused($focus, equals: .realName)
                }
            }
            HStack(alignment: .top, spacing: 12) {
                if draft.hasBirthday {
                    FieldBox(label: "Age", trailing: "from birthday", focused: false) {
                        Text(birthdayAge.map(String.init) ?? "—")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(width: 140)
                } else {
                    FieldBox(label: "Age", error: ageError, focused: focus == .age) {
                        TextField("Not added yet", text: $draft.ageText)
                            .focused($focus, equals: .age)
                    }
                    .frame(width: 140)
                    .modifier(Shake(animatableData: ageError != nil ? CGFloat(shakeCount) : 0))
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("Birthday").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Toggle("Add birthday", isOn: $draft.hasBirthday.animation(Theme.bouncy))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                        if draft.hasBirthday {
                            DatePicker("Birthday", selection: $draft.birthday, in: ...Date.now, displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .transition(.scale(scale: 0.8, anchor: .leading).combined(with: .opacity))
                        } else {
                            Text("Not added yet").font(.callout.italic()).foregroundStyle(.tertiary)
                        }
                    }
                    .frame(minHeight: 34)
                }
                Spacer()
            }
        }
    }

    private var rolesSection: some View {
        EditorSection(title: "Positions", symbol: "star.circle", error: rolesError) {
            FlowLayout(spacing: 7, lineSpacing: 7) {
                ForEach(MemberRole.allCases) { role in
                    RoleChip(role: role, isOn: draft.roles.contains(role), tint: aura) {
                        withAnimation(Theme.bouncy) {
                            if let index = draft.roles.firstIndex(of: role) {
                                draft.roles.remove(at: index)
                            } else {
                                draft.roles.append(role)
                            }
                        }
                    }
                }
            }
        }
    }

    private var personalitySection: some View {
        EditorSection(title: "Personality", symbol: "brain.head.profile") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("MBTI").font(.callout).foregroundStyle(.secondary)
                    Picker("MBTI", selection: $draft.mbti) {
                        Text("Not added yet").tag("")
                        Divider()
                        ForEach(Personality.mbtiTypes, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    Spacer()
                }
                FieldBox(label: "Personality Description", trailing: "\(draft.summary.count)/\(Self.summaryLimit)",
                         error: summaryTooLong ? "Keep it to \(Self.summaryLimit) characters." : nil,
                         focused: focus == .summary) {
                    TextField("Not added yet", text: $draft.summary, axis: .vertical)
                        .lineLimit(2...5)
                        .focused($focus, equals: .summary)
                }
                FieldBox(label: "Traits", focused: focus == .trait) {
                    HStack {
                        TextField("Type a trait and press Return", text: $newTrait)
                            .focused($focus, equals: .trait)
                            .onSubmit(addTrait)
                        Button(action: addTrait) {
                            Image(systemName: "plus.circle.fill").foregroundStyle(aura)
                        }
                        .buttonStyle(.plain)
                        .disabled(newTrait.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                if !draft.traits.isEmpty {
                    FlowLayout(spacing: 6, lineSpacing: 6) {
                        ForEach(draft.traits, id: \.self) { trait in
                            HStack(spacing: 4) {
                                Text(trait).font(.caption.weight(.medium))
                                Button {
                                    withAnimation(Theme.bouncy) { draft.traits.removeAll { $0 == trait } }
                                } label: {
                                    Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(aura.opacity(0.16), in: Capsule())
                            .overlay(Capsule().strokeBorder(aura.opacity(0.35)))
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                        }
                    }
                }
            }
        }
    }

    private var auraSection: some View {
        EditorSection(title: "Aura Color", symbol: "paintpalette") {
            HStack(spacing: 10) {
                ForEach(Self.auraSwatches, id: \.self) { hex in
                    let selected = draft.colorAccent.uppercased() == hex
                    Button {
                        withAnimation(Theme.bouncy) { draft.colorAccent = hex }
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 24, height: 24)
                            .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                            .padding(3)
                            .overlay(Circle().strokeBorder(.white, lineWidth: selected ? 2 : 0))
                            .scaleEffect(selected ? 1.12 : 1)
                    }
                    .buttonStyle(.plain)
                    .help(hex)
                }
                Spacer()
                ColorPicker("Custom", selection: auraBinding, supportsOpacity: false)
                    .labelsHidden()
                FieldBox(label: nil, error: nil, focused: focus == .hex, invalid: !isValidHex) {
                    TextField("#E50914", text: $draft.colorAccent)
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

    private var avatarSection: some View {
        EditorSection(title: "Avatar Icon", symbol: "face.smiling") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 10), spacing: 8) {
                ForEach([""] + IdolMember.avatarSymbols, id: \.self) { symbol in
                    let selected = draft.avatarSymbol == symbol
                    Button {
                        withAnimation(Theme.bouncy) { draft.avatarSymbol = symbol }
                    } label: {
                        SwiftUI.Group {
                            if symbol.isEmpty {
                                Text(initial).font(.system(size: 16, weight: .heavy, design: .rounded))
                            } else {
                                Image(systemName: symbol).font(.system(size: 15, weight: .semibold))
                            }
                        }
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .foregroundStyle(selected ? (aura.isLight ? .black : .white) : .primary)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(selected ? AnyShapeStyle(aura) : AnyShapeStyle(.white.opacity(0.06)))
                            )
                            .scaleEffect(selected ? 1.08 : 1)
                    }
                    .buttonStyle(.plain)
                    .help(symbol.isEmpty ? "First letter of the stage name" : symbol)
                }
            }
            FieldBox(label: "Or any SF Symbol name", error: symbolIsValid ? nil : "No SF Symbol called \"\(draft.avatarSymbol)\".",
                     focused: focus == .symbol, invalid: !symbolIsValid) {
                TextField("Leave empty to use the first letter", text: $draft.avatarSymbol)
                    .focused($focus, equals: .symbol)
                    .font(.system(.callout, design: .monospaced))
            }
        }
    }

    private var relationshipsSection: some View {
        EditorSection(title: "Relationships & Dynamics", symbol: "person.2.wave.2") {
            HStack {
                Text("Relationship status").font(.callout).foregroundStyle(.secondary)
                Picker("Relationship status", selection: $draft.relationshipStatus) {
                    Text("Not set").tag(RelationshipStatusLine?.none)
                    Divider()
                    ForEach(RelationshipStatusLine.allCases) { Text($0.rawValue).tag(Optional($0)) }
                }
                .labelsHidden()
                .fixedSize()
                Spacer()
            }
            if let editingID, let partner = appState.company.currentPartner(of: editingID) {
                Label("Has a current Couple relationship with \(partner.stageName), so the card shows their name automatically.",
                      systemImage: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider().opacity(0.4)

            if let editingID, let member = appState.company.member(withID: editingID) {
                RelationshipChipList(member: member, onEdit: { appState.relationshipSheet = $0 }, clickToEdit: true)
                HStack {
                    Button {
                        appState.relationshipSheet = .add(from: editingID)
                    } label: {
                        Label("Add Relationship", systemImage: "plus")
                    }
                    .buttonStyle(SpringyButtonStyle(kind: .secondary))
                    Spacer()
                    Text("Click a relationship to edit it, or right-click to delete. Changes save right away and show on both people.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.trailing)
                }
            } else {
                Text("Add this member first, then you can link relationships.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if !isAdding {
                Button("Remove Member", role: .destructive) { confirmRemove = true }
                    .buttonStyle(SpringyButtonStyle(kind: .destructive))
            }
            Spacer()
            if showErrors && !isValid {
                Label(problemCount == 1 ? "1 thing to fix" : "\(problemCount) things to fix",
                      systemImage: "exclamationmark.circle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Theme.red)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            Button("Cancel") { dismiss() }
                .buttonStyle(SpringyButtonStyle(kind: .secondary))
                .keyboardShortcut(.cancelAction)
            Button(action: save) {
                Label(isAdding ? "Add Member" : "Save", systemImage: isAdding ? "person.badge.plus" : "checkmark")
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

    // MARK: Photo

    private func draftAvatar(size: CGFloat, cornerRadius: CGFloat?) -> some View {
        AvatarView(
            photoFileName: draft.photoFileName,
            initial: initial,
            symbol: symbolIsValid ? draft.avatarSymbol : "",
            colorHex: isValidHex ? draft.colorAccent : "#E50914",
            size: size,
            cornerRadius: cornerRadius
        )
    }

    private var photoSection: some View {
        EditorSection(title: "Photo", symbol: "photo", error: photoError) {
            HStack(alignment: .center, spacing: 18) {
                draftAvatar(size: 96, cornerRadius: 26)
                    .shadow(color: aura.opacity(0.45), radius: 12, y: 4)
                    .photoDropTarget(isTargeted: $dropTargeted, tint: aura, cornerRadius: 26, perform: handleDrop)
                VStack(alignment: .leading, spacing: 10) {
                    Text(draft.photoFileName == nil
                         ? "No photo yet, so the letter avatar is shown. Upload one or drag an image onto the avatar."
                         : "Drag a new image onto the avatar or upload another to replace it.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Button { showFilePicker = true } label: {
                            Label("Upload Photo…", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(SpringyButtonStyle(kind: .primary))
                        if draft.photoFileName != nil {
                            Button(role: .destructive) {
                                withAnimation(.easeOut(duration: 0.2)) { draft.photoFileName = nil }
                            } label: {
                                Label("Remove Photo", systemImage: "trash")
                            }
                            .buttonStyle(SpringyButtonStyle(kind: .destructive))
                            .transition(.opacity)
                        }
                    }
                    Text("PNG, JPG or WebP. Saved as a 512×512 square.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func openForCropping(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard PhotoStore.allowedExtensions.contains(url.pathExtension.lowercased()) else {
            photoError = "Use a PNG, JPG or WebP image."
            return
        }
        guard let image = PhotoStore.loadForCropping(from: url) else {
            photoError = "Couldn't open that image."
            return
        }
        photoError = nil
        cropSource = CropSource(image: image)
    }

    /// Accepts image files dragged from Finder, or raw image data dragged from a browser.
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async { openForCropping(url) }
            }
            return true
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                let image = data.flatMap(PhotoStore.loadForCropping(from:))
                DispatchQueue.main.async {
                    if let image {
                        photoError = nil
                        cropSource = CropSource(image: image)
                    } else {
                        photoError = "Couldn't open that image."
                    }
                }
            }
            return true
        }
        return false
    }

    /// Deletes photo files that ended up unused: new uploads on Cancel, or the old photo after it was replaced or removed.
    private func cleanUpPhotos() {
        let kept = didSave ? draft.photoFileName : originalPhoto
        for fileName in createdPhotos where fileName != kept {
            PhotoStore.delete(fileName)
        }
        if didSave, let originalPhoto, originalPhoto != draft.photoFileName {
            PhotoStore.delete(originalPhoto)
        }
    }

    // MARK: Actions

    private var auraBinding: Binding<Color> {
        Binding(get: { aura }, set: { draft.colorAccent = $0.hexString })
    }

    private func addTrait() {
        let trait = newTrait.trimmingCharacters(in: .whitespaces)
        guard !trait.isEmpty else { return }
        if !draft.traits.contains(where: { $0.lowercased() == trait.lowercased() }) {
            withAnimation(Theme.bouncy) { draft.traits.append(trait) }
        }
        newTrait = ""
    }

    private func save() {
        guard isValid else {
            withAnimation(Theme.bouncy) { showErrors = true }
            withAnimation(.linear(duration: 0.45)) { shakeCount += 1 }
            NSSound.beep()
            return
        }
        didSave = true
        switch mode {
        case .add:
            let member = draft.makeMember()
            dismiss()
            withAnimation(Theme.bouncy) { group.add(member) }
        case .edit(let member):
            withAnimation(Theme.bouncy) { draft.apply(to: member) }
            dismiss()
        }
    }

    private var removalMessage: String {
        let count = editingID.map { appState.company.relationshipCount(involving: [$0]) } ?? 0
        let rel = count == 1 ? "1 relationship" : "\(count) relationships"
        return "This also removes their photo, sub-unit spots and \(rel). It can't be undone."
    }

    private func remove() {
        guard case .edit(let member) = mode else { return }
        dismiss()
        appState.removeMember(member, from: group)
    }
}

private struct RoleChip: View {
    let role: MemberRole
    let isOn: Bool
    let tint: Color
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isOn {
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy))
                        .transition(.scale.combined(with: .opacity))
                }
                Text(role.rawValue).font(.callout.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(isOn ? (tint.isLight ? .black : .white) : .primary)
            .background(Capsule().fill(isOn ? AnyShapeStyle(tint) : AnyShapeStyle(.white.opacity(hovering ? 0.12 : 0.07))))
            .overlay(Capsule().strokeBorder(isOn ? .white.opacity(0.3) : .white.opacity(0.1)))
            .scaleEffect(hovering ? 1.05 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.bouncy, value: hovering)
        .animation(Theme.bouncy, value: isOn)
    }
}
