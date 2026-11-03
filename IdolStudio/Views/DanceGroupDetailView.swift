import SwiftUI

/// One dance crew's page. Sections depend on the crew's type.
struct DanceGroupDetailView: View {
    @Bindable var crew: DanceGroup
    @Environment(AppState.self) private var appState
    @State private var crewToDelete: DanceGroup?

    var body: some View {
        let company = appState.company
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(eyebrow: crew.type.rawValue, title: crew.name) {
                    HStack(spacing: 10) {
                        Button(role: .destructive) { crewToDelete = crew } label: { Label("Delete", systemImage: "trash") }
                            .buttonStyle(SpringyButtonStyle(kind: .destructive))
                        Button { appState.danceSheet = .edit(crew) } label: { Label("Edit", systemImage: "slider.horizontal.3") }
                            .buttonStyle(GradientButtonStyle(colors: crew.colors))
                    }
                }

                hero

                section("Styles", symbol: "sparkles") {
                    TagEditor(tags: $crew.styles, suggestions: DanceGroup.suggestedStyles, tint: crew.ink,
                              placeholder: "Add a style and press Return", empty: "No styles yet")
                }

                switch crew.type {
                case .performanceTeam:
                    section("Backs Up", symbol: "person.3.sequence.fill") {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("The dancers and backup dancers for these groups.")
                                    .font(.caption).foregroundStyle(.secondary)
                                if let sentence = company.worksWithSentence(for: crew) {
                                    Text(sentence).font(.callout)
                                }
                                BackupChips(crew: crew, company: company)
                            }
                            Spacer()
                            BackupMenu(crew: crew, company: company)
                        }
                    }
                    section("Competitions", symbol: "trophy") {
                        CompetitionList(crew: crew)
                    }
                case .academy:
                    section("Teaches", symbol: "person.2.fill") {
                        TagEditor(tags: $crew.teaches, suggestions: DanceGroup.suggestedAudiences, tint: .white,
                                  placeholder: "Who are the classes for? Press Return to add", empty: "Not added yet")
                    }
                    section("Classes", symbol: "list.bullet.rectangle") {
                        ClassList(crew: crew)
                    }
                    section("Counts", symbol: "number") {
                        HStack(spacing: 14) {
                            DancerCountPill(crew: crew)
                            StudentsPill(crew: crew)
                            Spacer()
                            Text("Call the count").font(.caption).foregroundStyle(.secondary)
                            Picker("Count label", selection: $crew.countLabel) {
                                ForEach(DancerCountLabel.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .fixedSize()
                        }
                    }
                }

                section("Notes", symbol: "note.text") {
                    ZStack(alignment: .topLeading) {
                        if crew.notes.isEmpty {
                            Text("Write your own lore here: history, rivalries, iconic stages…")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8).padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $crew.notes)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 160)
                    }
                    .padding(8)
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
        .deleteDanceGroupDialog($crewToDelete)
    }

    private var hero: some View {
        let textColor: Color = crew.colors[0].isLight ? .black : .white
        return ZStack(alignment: .topTrailing) {
            crew.gradient
            Image(systemName: crew.type.symbol)
                .font(.system(size: 130, weight: .black))
                .foregroundStyle(textColor.opacity(0.10))
                .offset(x: 10, y: 10)
            HStack(alignment: .center, spacing: 20) {
                DanceLogo(crew: crew, size: 104)
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text(crew.name.isEmpty ? "Untitled" : crew.name)
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                        DanceTypeBadge(type: crew.type, onColor: textColor)
                    }
                    if crew.summary.isEmpty {
                        BannerPlaceholder(text: "Description not added yet", color: textColor).font(.title3)
                    } else {
                        Text(crew.summary).font(.title3).opacity(0.9).lineLimit(3)
                    }
                    HStack(spacing: 14) {
                        DancerCountPill(crew: crew, tint: textColor)
                        HStack(spacing: 5) {
                            Image(systemName: "calendar")
                            if let formed = crew.formedDate {
                                Text("Formed \(formed.formatted(date: .long, time: .omitted))")
                            } else {
                                BannerPlaceholder(text: "Formed date not added yet", color: textColor)
                            }
                        }
                        HStack(spacing: 5) {
                            Image(systemName: "person.fill")
                            if crew.headChoreographer.isEmpty {
                                BannerPlaceholder(text: "\(crew.type.leadTitle) not added yet", color: textColor)
                            } else {
                                Text("\(crew.type.leadTitle): \(crew.headChoreographer)")
                            }
                        }
                    }
                    .font(.callout.weight(.medium))
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(textColor)
            .padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: crew.colors[0].opacity(0.3), radius: 18, y: 8)
    }

    private func section<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 18)
    }
}

/// Removable tags plus a field and quick suggestions (used for styles and "Teaches").
struct TagEditor: View {
    @Binding var tags: [String]
    let suggestions: [String]
    let tint: Color
    let placeholder: String
    let empty: String
    @State private var newTag = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if tags.isEmpty {
                NotAddedYet(text: empty)
            } else {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag).font(.caption.weight(.medium))
                            Button {
                                withAnimation(Theme.bouncy) { tags.removeAll { $0 == tag } }
                            } label: { Image(systemName: "xmark").font(.system(size: 8, weight: .bold)) }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                                .help("Remove \(tag)")
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(tint.opacity(0.15), in: Capsule())
                        .overlay(Capsule().strokeBorder(tint.opacity(0.35)))
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                    }
                }
            }
            HStack {
                TextField(placeholder, text: $newTag)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .onSubmit { add(newTag) }
                Button { add(newTag) } label: { Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(tint) }
                    .buttonStyle(.plain)
                    .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            let remaining = suggestions.filter { s in !tags.contains { $0.lowercased() == s.lowercased() } }
            if !remaining.isEmpty {
                FlowLayout(spacing: 5, lineSpacing: 5) {
                    ForEach(remaining, id: \.self) { suggestion in
                        Button { add(suggestion) } label: {
                            Label(suggestion, systemImage: "plus")
                                .font(.caption)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .overlay(Capsule().strokeBorder(.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .animation(Theme.bouncy, value: tags)
    }

    private func add(_ tag: String) {
        let clean = tag.trimmingCharacters(in: .whitespaces)
        if !clean.isEmpty, !tags.contains(where: { $0.lowercased() == clean.lowercased() }) {
            withAnimation(Theme.bouncy) { tags.append(clean) }
        }
        newTag = ""
    }
}

/// Checklist menu for which idol groups and units a performance team backs up.
struct BackupMenu: View {
    @Bindable var crew: DanceGroup
    let company: Company

    var body: some View {
        Menu {
            ForEach(company.groups) { group in
                Toggle(group.name, isOn: Binding(
                    get: { crew.worksWithGroups.contains(group.id) },
                    set: { on in
                        if on { crew.worksWithGroups.append(group.id) } else { crew.worksWithGroups.removeAll { $0 == group.id } }
                    }))
                ForEach(group.subUnits) { unit in
                    Toggle("   \(unit.name) (\(group.name) unit)", isOn: Binding(
                        get: { crew.worksWithUnits.contains(unit.id) },
                        set: { on in
                            if on { crew.worksWithUnits.append(unit.id) } else { crew.worksWithUnits.removeAll { $0 == unit.id } }
                        }))
                }
            }
            if company.groups.isEmpty { Text("No idol groups yet") }
        } label: {
            Label("Choose", systemImage: "checklist")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

// MARK: - Competitions

struct CompetitionList: View {
    @Bindable var crew: DanceGroup
    @Environment(AppState.self) private var appState
    @State private var pendingDelete: Competition?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(crew.competitionSummary).font(.callout.weight(.medium))
                Spacer()
                Button { openForm(nil) } label: { Label("Add Competition", systemImage: "plus") }
                    .buttonStyle(SpringyButtonStyle(kind: .secondary))
            }
            if crew.competitions.isEmpty {
                NotAddedYet(text: "No competitions yet")
            }
            ForEach(crew.competitions.newestFirst) { competition in
                competitionRow(competition)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .animation(Theme.bouncy, value: crew.competitions)
        .confirmationDialog("Delete this competition?",
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            presenting: pendingDelete) { competition in
            Button("Delete", role: .destructive) {
                withAnimation(Theme.bouncy) { crew.competitions.removeAll { $0.id == competition.id } }
            }
        } message: { competition in
            Text(competition.name)
        }
    }

    /// Add (nil) or edit an entry in the centered dialog.
    private func openForm(_ competition: Competition?) {
        let crew = self.crew
        appState.present(maxWidth: 520) { close in
            CompetitionForm(competition: competition, tint: crew.ink, onSave: { saved in
                withAnimation(Theme.bouncy) {
                    if let i = crew.competitions.firstIndex(where: { $0.id == saved.id }) {
                        crew.competitions[i] = saved
                    } else {
                        crew.competitions.append(saved)
                    }
                }
            }, close: close)
        }
    }

    private func competitionRow(_ c: Competition) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: c.result.isWin ? "trophy.fill" : "medal")
                .font(.title3)
                .foregroundStyle(c.result.isWin ? crew.ink : Color.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(c.name).font(.callout.weight(.semibold))
                    if let dateText = c.dateText {
                        Text(dateText).font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Date unknown").font(.caption.italic()).foregroundStyle(.tertiary)
                    }
                    Chip(text: c.result.rawValue, tint: c.result.isWin ? crew.ink : .white, filled: c.result.isWin)
                }
                if !c.location.isEmpty {
                    Label(c.location, systemImage: "mappin.and.ellipse").font(.caption).foregroundStyle(.secondary)
                }
                if !c.category.isEmpty {
                    Text(c.category).font(.caption).foregroundStyle(.secondary)
                }
                if !c.note.isEmpty {
                    Text(c.note).font(.caption).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Button { openForm(c) } label: { Image(systemName: "pencil") }
                .buttonStyle(.plain).foregroundStyle(.secondary).help("Edit")
            Button { pendingDelete = c } label: { Image(systemName: "trash") }
                .buttonStyle(.plain).foregroundStyle(Theme.red).help("Delete")
        }
        .padding(10)
        .background(.white.opacity(c.result.isWin ? 0.06 : 0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Add / edit a competition: name, date (exact, year only, or unknown), location, result, category, note.
private struct CompetitionForm: View {
    let competition: Competition?
    let tint: Color
    let onSave: (Competition) -> Void
    let close: () -> Void

    private enum DateMode { case exact, yearOnly, unknown }

    @State private var name: String
    @State private var dateMode: DateMode
    @State private var date: Date
    @State private var yearText: String
    @State private var location: String
    @State private var result: CompetitionResult
    @State private var category: String
    @State private var note: String
    @State private var shakeCount = 0
    @State private var showErrors = false

    init(competition: Competition?, tint: Color, onSave: @escaping (Competition) -> Void, close: @escaping () -> Void) {
        self.competition = competition; self.tint = tint; self.onSave = onSave; self.close = close
        let thisYear = Calendar.current.component(.year, from: .now)
        _name = State(initialValue: competition?.name ?? "")
        // Existing entries keep what they had: a date, just a year, or nothing.
        if let c = competition {
            _dateMode = State(initialValue: c.date != nil ? .exact : (c.year != nil ? .yearOnly : .unknown))
        } else {
            _dateMode = State(initialValue: .exact)
        }
        _date = State(initialValue: competition?.date ?? .now)
        _yearText = State(initialValue: String(competition?.year ?? thisYear))
        _location = State(initialValue: competition?.location ?? "")
        _result = State(initialValue: competition?.result ?? .participated)
        _category = State(initialValue: competition?.category ?? "")
        _note = State(initialValue: competition?.note ?? "")
    }

    private var year: Int? { Int(yearText.trimmingCharacters(in: .whitespaces)) }
    private var yearError: String? {
        guard dateMode == .yearOnly else { return nil }
        guard let year, (1900...2100).contains(year) else { return "Use a 4-digit year." }
        return nil
    }
    private var nameError: String? {
        showErrors && name.trimmingCharacters(in: .whitespaces).isEmpty ? "Give the competition a name." : nil
    }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && yearError == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill").foregroundStyle(tint)
                Text(competition == nil ? "Add Competition" : "Edit Competition").font(.headline)
            }

            FieldBox(label: "Competition name", required: true, error: nameError, focused: false) {
                TextField("e.g. Street Woman Fighter", text: $name)
            }
            .modifier(Shake(animatableData: name.trimmingCharacters(in: .whitespaces).isEmpty ? CGFloat(shakeCount) : 0))

            VStack(alignment: .leading, spacing: 8) {
                Text("Date").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    Toggle("Date unknown", isOn: Binding(
                        get: { dateMode == .unknown },
                        set: { dateMode = $0 ? .unknown : .exact }))
                    if dateMode != .unknown {
                        Toggle("I only know the year", isOn: Binding(
                            get: { dateMode == .yearOnly },
                            set: { dateMode = $0 ? .yearOnly : .exact }))
                            .transition(.opacity)
                    }
                }
                .toggleStyle(.checkbox)
                .font(.callout)
                switch dateMode {
                case .exact:
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.field)
                        .transition(.opacity)
                case .yearOnly:
                    FieldBox(label: nil, error: yearError, focused: false, invalid: yearError != nil) {
                        TextField("2026", text: $yearText)
                    }
                    .frame(maxWidth: 140)
                    .transition(.opacity)
                case .unknown:
                    Text("Shown as \"Date unknown\" and listed at the bottom.")
                        .font(.caption).foregroundStyle(.tertiary)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.15), value: dateMode)

            FieldBox(label: "Location", focused: false) {
                TextField("Optional city or venue, e.g. Seoul Olympic Hall", text: $location)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Result").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                // Pills wrap onto a second row instead of running off the edge.
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(CompetitionResult.allCases) { option in
                        resultPill(option)
                    }
                }
            }

            FieldBox(label: "Category", focused: false) {
                TextField("e.g. Crew battle", text: $category)
            }
            FieldBox(label: "Note", focused: false) {
                TextField("Optional", text: $note, axis: .vertical).lineLimit(1...3)
            }

            HStack {
                Spacer()
                Button("Cancel", action: close).buttonStyle(SpringyButtonStyle(kind: .secondary)).keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .buttonStyle(SpringyButtonStyle(kind: .primary, dimmed: !isValid))
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(20)
    }

    private func resultPill(_ option: CompetitionResult) -> some View {
        let selected = option == result
        return Button { result = option } label: {
            HStack(spacing: 5) {
                if option.isWin { Image(systemName: "trophy.fill").font(.caption) }
                Text(option.rawValue).font(.callout.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minWidth: 70)
            .foregroundStyle(selected ? (tint.isLight ? Color.black : Color.white) : Color.primary)
            .background(Capsule().fill(.white.opacity(0.07)))
            .background(Capsule().fill(tint).opacity(selected ? 1 : 0))
            .overlay(Capsule().strokeBorder(.white.opacity(selected ? 0.3 : 0.12)))
            .scaleEffect(selected ? 1.04 : 1)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(Theme.bouncy, value: selected)
    }

    private func save() {
        guard isValid else {
            showErrors = true
            withAnimation(.linear(duration: 0.4)) { shakeCount += 1 }
            NSSound.beep()
            return
        }
        onSave(Competition(
            id: competition?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            date: dateMode == .exact ? date : nil,
            year: dateMode == .yearOnly ? year : (dateMode == .exact ? Calendar.current.component(.year, from: date) : nil),
            result: result,
            category: category.trimmingCharacters(in: .whitespaces),
            location: location.trimmingCharacters(in: .whitespaces),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)))
        close()
    }
}

// MARK: - Classes

struct ClassList: View {
    @Bindable var crew: DanceGroup
    @Environment(AppState.self) private var appState
    @State private var pendingDelete: DanceClass?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(crew.classes.isEmpty ? "No classes yet" : "\(crew.classes.count) \(crew.classes.count == 1 ? "class" : "classes")")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(crew.classes.isEmpty ? .tertiary : .primary)
                Spacer()
                Button { openForm(nil) } label: { Label("Add Class", systemImage: "plus") }
                    .buttonStyle(SpringyButtonStyle(kind: .secondary))
            }
            ForEach(crew.classes) { item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "figure.dance").foregroundStyle(crew.ink).frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).font(.callout.weight(.semibold))
                        if !item.details.isEmpty { Text(item.details).font(.caption).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    Button { openForm(item) } label: { Image(systemName: "pencil") }
                        .buttonStyle(.plain).foregroundStyle(.secondary).help("Edit")
                    Button { pendingDelete = item } label: { Image(systemName: "trash") }
                        .buttonStyle(.plain).foregroundStyle(Theme.red).help("Delete")
                }
                .padding(10)
                .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .animation(Theme.bouncy, value: crew.classes)
        .confirmationDialog("Delete this class?",
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            presenting: pendingDelete) { item in
            Button("Delete", role: .destructive) {
                withAnimation(Theme.bouncy) { crew.classes.removeAll { $0.id == item.id } }
            }
        } message: { item in
            Text(item.name)
        }
    }

    private func openForm(_ item: DanceClass?) {
        let crew = self.crew
        appState.present(maxWidth: 440) { close in
            ClassForm(danceClass: item, onSave: { saved in
                withAnimation(Theme.bouncy) {
                    if let i = crew.classes.firstIndex(where: { $0.id == saved.id }) { crew.classes[i] = saved }
                    else { crew.classes.append(saved) }
                }
            }, close: close)
        }
    }
}

private struct ClassForm: View {
    let danceClass: DanceClass?
    let onSave: (DanceClass) -> Void
    let close: () -> Void
    @State private var name: String
    @State private var details: String

    init(danceClass: DanceClass?, onSave: @escaping (DanceClass) -> Void, close: @escaping () -> Void) {
        self.danceClass = danceClass; self.onSave = onSave; self.close = close
        _name = State(initialValue: danceClass?.name ?? "")
        _details = State(initialValue: danceClass?.details ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(danceClass == nil ? "Add Class" : "Edit Class").font(.headline)
            FieldBox(label: "Class", required: true, focused: false) {
                TextField("e.g. Kids Hip-Hop", text: $name)
            }
            FieldBox(label: "Short description", focused: false) {
                TextField("e.g. Saturdays, ages 7–12", text: $details, axis: .vertical).lineLimit(1...3)
            }
            HStack {
                Spacer()
                Button("Cancel", action: close).buttonStyle(SpringyButtonStyle(kind: .secondary)).keyboardShortcut(.cancelAction)
                Button("Save") {
                    let clean = name.trimmingCharacters(in: .whitespaces)
                    guard !clean.isEmpty else { NSSound.beep(); return }
                    onSave(DanceClass(id: danceClass?.id ?? UUID(), name: clean,
                                      details: details.trimmingCharacters(in: .whitespacesAndNewlines)))
                    close()
                }
                .buttonStyle(SpringyButtonStyle(kind: .primary, dimmed: name.trimmingCharacters(in: .whitespaces).isEmpty))
            }
        }
        .padding(20)
    }
}
