import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum DanceGroupEditorMode: Identifiable {
    case add
    case edit(DanceGroup)
    var id: String {
        switch self {
        case .add: "add-dance"
        case .edit(let crew): crew.id.uuidString
        }
    }
}

/// Add / edit a dance crew. Works on a draft; nothing changes until Save.
struct DanceGroupEditorView: View {
    let mode: DanceGroupEditorMode
    @Environment(AppState.self) private var appState
    @Environment(\.closeModal) private var dismiss

    @State private var name: String
    @State private var type: DanceGroupType
    @State private var teaches: [String]
    @State private var countLabel: DancerCountLabel
    @State private var hasStudents: Bool
    @State private var studentsText: String
    @State private var summary: String
    @State private var countText: String
    @State private var accentHex: String
    @State private var styles: [String]
    @State private var newStyle = ""
    @State private var choreographer: String
    @State private var hasFormed: Bool
    @State private var formedDate: Date
    @State private var worksWithGroups: [UUID]
    @State private var worksWithUnits: [UUID]
    @State private var notes: String
    @State private var logoFileName: String?

    @State private var showErrors = false
    @State private var shakeCount = 0
    @State private var confirmDelete = false
    // Logo upload
    @State private var cropSource: CropSource?
    @State private var showFilePicker = false
    @State private var dropTargeted = false
    @State private var logoError: String?
    @State private var createdLogos: [String] = []
    @State private var didSave = false
    private let originalLogo: String?

    static let nameLimit = 24
    static let summaryLimit = 200
    static let accentSwatches = ["#E50914", "#FF4D4D", "#B00020", "#8B0000", "#F2F2F2", "#2A2A2A"]

    init(mode: DanceGroupEditorMode) {
        self.mode = mode
        let crew: DanceGroup? = { if case .edit(let c) = mode { return c }; return nil }()
        _name = State(initialValue: crew?.name ?? "")
        _type = State(initialValue: crew?.type ?? .performanceTeam)
        _teaches = State(initialValue: crew?.teaches ?? [])
        _countLabel = State(initialValue: crew?.countLabel ?? .dancers)
        _hasStudents = State(initialValue: crew?.students != nil)
        _studentsText = State(initialValue: String(crew?.students ?? 0))
        _summary = State(initialValue: crew?.summary ?? "")
        _countText = State(initialValue: String(crew?.dancerCount ?? 0))
        _accentHex = State(initialValue: crew?.accentHex ?? "#E50914")
        _styles = State(initialValue: crew?.styles ?? [])
        _choreographer = State(initialValue: crew?.headChoreographer ?? "")
        _hasFormed = State(initialValue: crew?.formedDate != nil)
        _formedDate = State(initialValue: crew?.formedDate ?? .now)
        _worksWithGroups = State(initialValue: crew?.worksWithGroups ?? [])
        _worksWithUnits = State(initialValue: crew?.worksWithUnits ?? [])
        _notes = State(initialValue: crew?.notes ?? "")
        _logoFileName = State(initialValue: crew?.logoFileName)
        originalLogo = crew?.logoFileName
    }

    private var editing: DanceGroup? { if case .edit(let c) = mode { return c }; return nil }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var isValidHex: Bool { accentHex.range(of: "^#?[0-9A-Fa-f]{6}$", options: .regularExpression) != nil }
    private var hex: String { isValidHex ? (accentHex.hasPrefix("#") ? accentHex : "#" + accentHex).uppercased() : "#E50914" }
    private var accent: Color { Color(hex: hex) }

    private var nameError: String? {
        if trimmedName.isEmpty { return showErrors ? "The dance group needs a name." : nil }
        if trimmedName.count > Self.nameLimit { return "Keep it to \(Self.nameLimit) characters or fewer." }
        let taken = appState.company.danceGroups.contains { $0.id != editing?.id && $0.name.lowercased() == trimmedName.lowercased() }
        return taken ? "Another dance group is already called \(trimmedName)." : nil
    }
    private var countError: String? {
        guard let n = Int(countText), (0...DanceGroup.maxDancers).contains(n) else {
            return "Enter a whole number from 0 to \(DanceGroup.maxDancers)."
        }
        return nil
    }
    private var summaryError: String? { summary.count > Self.summaryLimit ? "Keep it to \(Self.summaryLimit) characters." : nil }
    private var studentsError: String? {
        guard type == .academy, hasStudents else { return nil }
        guard let n = Int(studentsText), (0...DanceGroup.maxStudents).contains(n) else {
            return "Enter a whole number from 0 to \(DanceGroup.maxStudents)."
        }
        return nil
    }
    private var isValid: Bool {
        !trimmedName.isEmpty && nameError == nil && countError == nil && summaryError == nil && isValidHex && studentsError == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            banner
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    EditorSection(title: "Type", symbol: type.symbol) {
                        Picker("Type", selection: $type.animation(Theme.bouncy)) {
                            ForEach(DanceGroupType.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        Text(type == .performanceTeam
                             ? "Performance teams back up idol groups and enter competitions."
                             : "Academies teach classes and can track students.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    EditorSection(title: "Identity", symbol: "figure.dance") {
                        FieldBox(label: "Name", required: true, trailing: "\(trimmedName.count)/\(Self.nameLimit)",
                                 error: nameError, focused: false) {
                            TextField("e.g. 1M", text: $name)
                        }
                        .modifier(Shake(animatableData: nameError != nil || trimmedName.isEmpty ? CGFloat(shakeCount) : 0))
                        FieldBox(label: "Short description", trailing: "\(summary.count)/\(Self.summaryLimit)",
                                 error: summaryError, focused: false) {
                            TextField("Not added yet", text: $summary, axis: .vertical).lineLimit(1...3)
                        }
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(type == .academy ? countLabel.rawValue : "Dancers").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                AwardStepper(text: $countText, tint: accent.readableOnDark, maxValue: DanceGroup.maxDancers)
                                    .modifier(Shake(animatableData: countError != nil ? CGFloat(shakeCount) : 0))
                                if let countError { ErrorText(countError) }
                            }
                            FieldBox(label: type.leadTitle, focused: false) {
                                TextField("Not added yet", text: $choreographer)
                            }
                        }
                        HStack(spacing: 10) {
                            Text("Formed").font(.callout).foregroundStyle(.secondary)
                            Toggle("Add formed date", isOn: $hasFormed.animation(Theme.bouncy))
                                .toggleStyle(.switch).controlSize(.small).labelsHidden()
                            if hasFormed {
                                DatePicker("Formed", selection: $formedDate, in: ...Date.now, displayedComponents: .date)
                                    .labelsHidden().datePickerStyle(.compact).transition(.opacity)
                            } else {
                                Text("Not added yet").font(.callout.italic()).foregroundStyle(.tertiary)
                            }
                            Spacer()
                        }
                    }

                    EditorSection(title: "Logo or Photo", symbol: "photo", error: logoError) {
                        HStack(spacing: 18) {
                            AvatarView(photoFileName: logoFileName, initial: trimmedName.first.map { String($0).uppercased() } ?? "?",
                                       symbol: "", colorHex: hex, size: 88, cornerRadius: 24)
                                .photoDropTarget(isTargeted: $dropTargeted, tint: accent, cornerRadius: 24, perform: handleDrop)
                            VStack(alignment: .leading, spacing: 10) {
                                Text(logoFileName == nil ? "No logo yet, so the first letter is shown. Upload one or drag an image onto it."
                                                         : "Drag a new image onto it or upload another to replace it.")
                                    .font(.callout).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                HStack(spacing: 10) {
                                    Button { showFilePicker = true } label: { Label("Upload…", systemImage: "square.and.arrow.up") }
                                        .buttonStyle(SpringyButtonStyle(kind: .primary))
                                    if logoFileName != nil {
                                        Button(role: .destructive) { withAnimation(.easeOut(duration: 0.2)) { logoFileName = nil } } label: {
                                            Label("Remove", systemImage: "trash")
                                        }
                                        .buttonStyle(SpringyButtonStyle(kind: .destructive))
                                    }
                                }
                            }
                        }
                    }

                    EditorSection(title: "Accent Color", symbol: "paintpalette") {
                        HStack(spacing: 10) {
                            ForEach(Self.accentSwatches, id: \.self) { swatch in
                                let selected = hex == swatch
                                Button { withAnimation(Theme.bouncy) { accentHex = swatch } } label: {
                                    Circle().fill(Color(hex: swatch)).frame(width: 26, height: 26)
                                        .overlay(Circle().strokeBorder(.white.opacity(0.3)))
                                        .padding(3)
                                        .overlay(Circle().strokeBorder(.white, lineWidth: selected ? 2 : 0))
                                        .scaleEffect(selected ? 1.12 : 1)
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                            ColorPicker("Custom", selection: Binding(get: { accent }, set: { accentHex = $0.hexString }), supportsOpacity: false)
                                .labelsHidden()
                            FieldBox(label: nil, focused: false, invalid: !isValidHex) {
                                TextField("#E50914", text: $accentHex).font(.system(.callout, design: .monospaced))
                            }
                            .frame(width: 100)
                        }
                    }

                    EditorSection(title: "Styles", symbol: "sparkles") {
                        if !styles.isEmpty {
                            FlowLayout(spacing: 6, lineSpacing: 6) {
                                ForEach(styles, id: \.self) { style in
                                    HStack(spacing: 4) {
                                        Text(style).font(.caption.weight(.medium))
                                        Button { styles.removeAll { $0 == style } } label: {
                                            Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                                        }.buttonStyle(.plain).foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(accent.opacity(0.16), in: Capsule())
                                }
                            }
                        }
                        FieldBox(label: nil, focused: false) {
                            TextField("Add a style and press Return", text: $newStyle).onSubmit { addStyle(newStyle) }
                        }
                        FlowLayout(spacing: 5, lineSpacing: 5) {
                            ForEach(DanceGroup.suggestedStyles.filter { s in !styles.contains { $0.lowercased() == s.lowercased() } }, id: \.self) { s in
                                Button { addStyle(s) } label: {
                                    Label(s, systemImage: "plus").font(.caption)
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .overlay(Capsule().strokeBorder(.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                                }
                                .buttonStyle(.plain).foregroundStyle(.secondary)
                            }
                        }
                    }

                    if type == .academy {
                        EditorSection(title: "Academy", symbol: "graduationcap.fill", error: studentsError) {
                            HStack {
                                Text("Call the count").font(.callout).foregroundStyle(.secondary)
                                Picker("Count label", selection: $countLabel) {
                                    ForEach(DancerCountLabel.allCases) { Text($0.rawValue).tag($0) }
                                }
                                .pickerStyle(.segmented).labelsHidden().fixedSize()
                                Spacer()
                            }
                            HStack(spacing: 10) {
                                Text("Students").font(.callout).foregroundStyle(.secondary)
                                Toggle("Track students", isOn: $hasStudents.animation(Theme.bouncy))
                                    .toggleStyle(.switch).controlSize(.small).labelsHidden()
                                if hasStudents {
                                    AwardStepper(text: $studentsText, tint: .white, maxValue: DanceGroup.maxStudents)
                                        .transition(.opacity)
                                } else {
                                    Text("Optional").font(.callout.italic()).foregroundStyle(.tertiary)
                                }
                                Spacer()
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Teaches").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                TagEditor(tags: $teaches, suggestions: DanceGroup.suggestedAudiences, tint: .white,
                                          placeholder: "Who are the classes for? Press Return", empty: "Not added yet")
                            }
                            Text("Add classes on the dance group's page after saving.")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                    }

                    if type == .performanceTeam {
                    EditorSection(title: "Backs Up", symbol: "person.3.sequence.fill") {
                        Text("The idol groups and units these dancers perform with. Add competitions on the dance group's page.")
                            .font(.caption).foregroundStyle(.secondary)
                        if appState.company.groups.isEmpty {
                            Text("No idol groups yet.").foregroundStyle(.secondary)
                        }
                        ForEach(appState.company.groups) { group in
                            Toggle(group.name, isOn: membership($worksWithGroups, group.id))
                            ForEach(group.subUnits) { unit in
                                Toggle("\(unit.name) (\(group.name) unit)", isOn: membership($worksWithUnits, unit.id))
                                    .padding(.leading, 20)
                            }
                        }
                    }
                    }

                    EditorSection(title: "Notes", symbol: "note.text") {
                        TextEditor(text: $notes)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 90)
                            .padding(6)
                            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                }
                .padding(20)
            }
            footer
        }
        .modalFrame(width: 620, height: 800)
        .background {
            ZStack {
                VisualEffectBackground(material: .sheet, blending: .withinWindow)
                Color.black.opacity(0.6)
            }
        }
        .onDisappear(perform: cleanUpLogos)
        .sheet(item: $cropSource) { source in
            PhotoCropView(source: source.image, tint: accent) { cropped in
                do {
                    let file = try PhotoStore.save(croppedSquare: cropped)
                    createdLogos.append(file)
                    withAnimation(.easeOut(duration: 0.2)) { logoFileName = file; logoError = nil }
                } catch { logoError = error.localizedDescription }
            }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: PhotoStore.allowedTypes) { result in
            if case .success(let url) = result { openForCropping(url) }
        }
        .confirmationDialog("Delete \(editing?.name ?? "this dance group")?", isPresented: $confirmDelete) {
            Button("Delete Dance Group", role: .destructive) {
                guard let crew = editing else { return }
                dismiss()
                appState.deleteDanceGroup(crew)
            }
        } message: {
            Text("This removes \(editing?.name ?? "it") (\(editing?.dancerCount ?? 0) dancers) and its logo. Idol groups aren't affected. It can't be undone.")
        }
    }

    private var banner: some View {
        let colors = [accent, Color(hex: Theme.darkerHex(hex))]
        let textColor: Color = colors[0].isLight ? .black : .white
        return ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "figure.dance").font(.system(size: 100, weight: .black))
                .foregroundStyle(textColor.opacity(0.12))
                .frame(maxWidth: .infinity, alignment: .trailing).offset(x: 10, y: 16)
            VStack(alignment: .leading, spacing: 3) {
                Text(editing == nil ? "NEW DANCE GROUP" : "EDIT DANCE GROUP").font(.caption.weight(.semibold)).tracking(1.2).opacity(0.8)
                Text(trimmedName.isEmpty ? "Name" : trimmedName).font(.system(size: 30, weight: .heavy, design: .rounded)).lineLimit(1)
                HStack(spacing: 8) {
                    Label(type.rawValue, systemImage: type.symbol)
                    Text("·")
                    Text("\(Int(countText) ?? 0) \(type == .academy && countLabel == .instructors ? "instructors" : "dancers")")
                }
                .font(.callout).opacity(0.85)
            }
            .foregroundStyle(textColor)
            .padding(20)
        }
        .frame(height: 120)
        .clipped()
        .animation(Theme.bouncy, value: hex)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if editing != nil {
                Button("Delete", role: .destructive) { confirmDelete = true }
                    .buttonStyle(SpringyButtonStyle(kind: .destructive))
            }
            Spacer()
            if showErrors && !isValid {
                Label("Fix the highlighted fields", systemImage: "exclamationmark.circle.fill")
                    .font(.callout.weight(.medium)).foregroundStyle(Theme.red)
                    .transition(.opacity)
            }
            Button("Cancel") { dismiss() }
                .buttonStyle(SpringyButtonStyle(kind: .secondary))
                .keyboardShortcut(.cancelAction)
            Button(action: save) { Label(editing == nil ? "Create" : "Save", systemImage: editing == nil ? "plus" : "checkmark") }
                .buttonStyle(SpringyButtonStyle(kind: .primary, dimmed: !isValid))
                .keyboardShortcut(.return, modifiers: .command)
                .modifier(Shake(animatableData: CGFloat(shakeCount)))
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
        .background(.black.opacity(0.25))
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
    }

    private func membership(_ list: Binding<[UUID]>, _ id: UUID) -> Binding<Bool> {
        Binding(get: { list.wrappedValue.contains(id) },
                set: { on in if on { list.wrappedValue.append(id) } else { list.wrappedValue.removeAll { $0 == id } } })
    }

    private func addStyle(_ style: String) {
        let clean = style.trimmingCharacters(in: .whitespaces)
        if !clean.isEmpty, !styles.contains(where: { $0.lowercased() == clean.lowercased() }) { styles.append(clean) }
        newStyle = ""
    }

    private func openForCropping(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard PhotoStore.allowedExtensions.contains(url.pathExtension.lowercased()) else {
            logoError = "Use a PNG, JPG or WebP image."; return
        }
        guard let image = PhotoStore.loadForCropping(from: url) else { logoError = "Couldn't open that image."; return }
        logoError = nil
        cropSource = CropSource(image: image)
    }

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
                    if let image { cropSource = CropSource(image: image) } else { logoError = "Couldn't open that image." }
                }
            }
            return true
        }
        return false
    }

    /// Deletes logo files that ended up unused (new uploads on Cancel, or the old logo after a replace/remove).
    private func cleanUpLogos() {
        let kept = didSave ? logoFileName : originalLogo
        for file in createdLogos where file != kept { PhotoStore.delete(file) }
        if didSave, let originalLogo, originalLogo != logoFileName { PhotoStore.delete(originalLogo) }
    }

    private func save() {
        guard isValid, let count = Int(countText) else {
            withAnimation(Theme.bouncy) { showErrors = true }
            withAnimation(.linear(duration: 0.45)) { shakeCount += 1 }
            NSSound.beep()
            return
        }
        didSave = true
        let crew = editing ?? DanceGroup(name: trimmedName)
        withAnimation(Theme.bouncy) {
            crew.name = trimmedName
            crew.type = type
            crew.teaches = teaches
            crew.countLabel = countLabel
            crew.setStudents(type == .academy && hasStudents ? Int(studentsText) : (type == .academy ? nil : crew.students))
            crew.summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
            crew.setDancerCount(count)
            crew.accentHex = hex
            crew.styles = styles
            crew.headChoreographer = choreographer.trimmingCharacters(in: .whitespaces)
            crew.formedDate = hasFormed ? formedDate : nil
            crew.worksWithGroups = worksWithGroups
            crew.worksWithUnits = worksWithUnits
            crew.notes = notes
            crew.logoFileName = logoFileName
            if editing == nil { appState.company.addDanceGroup(crew) }
        }
        dismiss()
        if editing == nil { appState.navigate(to: .danceGroup(crew.id)) }
    }
}
