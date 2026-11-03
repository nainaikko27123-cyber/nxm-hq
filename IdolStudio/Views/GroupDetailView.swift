import SwiftUI

struct GroupDetailView: View {
    @Bindable var group: IdolGroup
    @Environment(AppState.self) private var appState
    @State private var memberToRemove: IdolMember?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(eyebrow: "Group", title: group.name) {
                    HStack(spacing: 10) {
                        Button {
                            appState.groupSheet = .edit(group)
                        } label: {
                            Label("Edit Group", systemImage: "slider.horizontal.3")
                        }
                        .buttonStyle(SpringyButtonStyle(kind: .secondary))
                        .help("Edit Group (⌘E)")
                        Button {
                            appState.memberSheet = .add
                        } label: {
                            Label("Add Member", systemImage: "person.badge.plus")
                        }
                        .buttonStyle(GradientButtonStyle(colors: group.colors))
                        .help("New Member (⌘N)")
                    }
                }

                hero

                HStack {
                    SectionTitle(title: "Sub-units")
                    Spacer()
                    Button {
                        withAnimation(Theme.spring) {
                            group.subUnits.append(SubUnit(name: "New Unit", memberIDs: []))
                        }
                    } label: {
                        Label("New Sub-unit", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
                    ForEach($group.subUnits) { $unit in
                        SubUnitCard(unit: $unit, group: group) {
                            withAnimation(Theme.spring) { group.subUnits.removeAll { $0.id == unit.id } }
                        }
                    }
                }
                if group.subUnits.isEmpty {
                    Text("No sub-units yet.").foregroundStyle(.secondary)
                }

                SectionTitle(title: "Members")
                AutoFitGrid(minColumnWidth: 260, spacing: 16) {
                    ForEach(group.members) { member in
                        MemberCard(member: member, group: group) {
                            appState.memberSheet = .edit(member)
                        }
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.6).combined(with: .opacity),
                                removal: .scale(scale: 0.85).combined(with: .opacity)
                            )
                        )
                        .contextMenu {
                            Button("Edit…") { appState.memberSheet = .edit(member) }
                            Button("Remove from \(group.name)…", role: .destructive) {
                                memberToRemove = member
                            }
                        }
                    }
                }
                .animation(Theme.bouncy, value: group.members.map(\.id))
            }
            .confirmationDialog(
                "Remove \(memberToRemove?.stageName ?? "this member") from \(group.name)?",
                isPresented: Binding(get: { memberToRemove != nil }, set: { if !$0 { memberToRemove = nil } }),
                presenting: memberToRemove
            ) { member in
                Button("Remove", role: .destructive) { appState.removeMember(member, from: group) }
            } message: { member in
                let count = appState.company.relationshipCount(involving: [member.id])
                Text("This also removes their photo, sub-unit spots and \(count == 1 ? "1 relationship" : "\(count) relationships"). It can't be undone.")
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
    }

    private var hero: some View {
        ZStack(alignment: .topTrailing) {
            group.gradient
            Image(systemName: "music.quarternote.3")
                .font(.system(size: 130, weight: .black))
                .foregroundStyle(group.bannerText)
                .opacity(0.10)
                .offset(x: 20, y: 10)

            VStack(alignment: .leading, spacing: 14) {
                if !group.bannerTag.isEmpty {
                    BannerTag(text: group.bannerTag, color: group.bannerText)
                }
                Text(group.name.isEmpty ? "Untitled Group" : group.name)
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                if group.concept.isEmpty {
                    BannerPlaceholder(text: "Concept not added yet", color: group.bannerText).font(.title3)
                } else {
                    Text(group.concept)
                        .font(.title3)
                        .lineLimit(3)
                        .opacity(0.9)
                }

                HStack(spacing: 18) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                        if let debut = group.debutDate {
                            Text("Debuted \(debut.formatted(date: .long, time: .omitted))")
                        } else {
                            BannerPlaceholder(text: "Debut not added yet", color: group.bannerText)
                        }
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                        if group.fandomName.isEmpty {
                            BannerPlaceholder(text: "Fandom not added yet", color: group.bannerText)
                        } else {
                            Text(group.fandomName)
                        }
                    }
                    heroStat("\(group.members.count)", "members")
                    heroStat("\(group.subUnits.count)", "sub-units")
                    Spacer()
                }
                .font(.callout.weight(.medium))

                let crews = appState.company.danceGroups(workingWith: group)
                if !crews.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(crews) { crew in
                            Button { appState.navigate(to: .danceGroup(crew.id)) } label: {
                                HStack(spacing: 6) {
                                    DanceLogo(crew: crew, size: 20)
                                    Text("Backed by \(crew.name)")
                                }
                                .font(.caption.weight(.semibold))
                                .padding(.leading, 4).padding(.trailing, 10).padding(.vertical, 4)
                                .background(.black.opacity(0.25), in: Capsule())
                                .overlay(Capsule().strokeBorder(.white.opacity(0.25)))
                            }
                            .buttonStyle(.plain)
                            .help("Open \(crew.name)")
                        }
                    }
                }
            }
            .foregroundStyle(group.bannerText)
            .padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: group.colors[0].opacity(0.35), radius: 18, y: 8)
    }

    private func heroStat(_ value: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(value).font(.callout.weight(.bold)).contentTransition(.numericText())
            Text(label).opacity(0.85)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(group.bannerText.opacity(0.14), in: Capsule())
    }
}

struct GradientButtonStyle: ButtonStyle {
    var colors: [Color]
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing),
                in: Capsule()
            )
            .shadow(color: colors[0].opacity(0.35), radius: 8, y: 3)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Theme.spring, value: configuration.isPressed)
    }
}

struct SubUnitCard: View {
    @Binding var unit: SubUnit
    let group: IdolGroup
    let onDelete: () -> Void

    var body: some View {
        let members = unit.memberIDs.compactMap(group.member(with:))

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Unit name", text: $unit.name)
                    .textFieldStyle(.plain)
                    .font(.headline)
                Menu {
                    ForEach(group.members) { member in
                        Toggle(member.stageName, isOn: membershipBinding(member))
                    }
                    Divider()
                    Button("Delete Sub-unit", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            if members.isEmpty {
                Text("Use ⋯ to add members")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 10) {
                    AvatarStack(members: members, size: 26)
                    Text(members.map(\.stageName).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16)
    }

    private func membershipBinding(_ member: IdolMember) -> Binding<Bool> {
        Binding(
            get: { unit.memberIDs.contains(member.id) },
            set: { isOn in
                if isOn {
                    if !unit.memberIDs.contains(member.id) { unit.memberIDs.append(member.id) }
                } else {
                    unit.memberIDs.removeAll { $0 == member.id }
                }
            }
        )
    }
}
