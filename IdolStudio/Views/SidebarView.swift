import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Namespace private var highlight
    @State private var groupToDelete: IdolGroup?
    @State private var crewToDelete: DanceGroup?

    var body: some View {
        let company = appState.company

        VStack(alignment: .leading, spacing: 4) {
            brand
                .padding(.top, 48)
                .padding(.bottom, 22)

            label("Company")
            SidebarRow(
                title: "Overview",
                subtitle: company.ceoName.isEmpty ? nil : "CEO \(company.ceoName)",
                symbol: "building.2.fill",
                colors: Theme.brandColors,
                isSelected: appState.selection == .overview,
                namespace: highlight
            ) { appState.navigate(to: .overview) }

            SidebarRow(
                title: "Chadder's Fan Survey",
                subtitle: surveySubtitle,
                symbol: "pawprint.fill",
                colors: [Color(hex: "#FF9F43"), Theme.red],
                isSelected: appState.selection == .survey,
                namespace: highlight
            ) { appState.navigate(to: .survey) }

            label("Groups").padding(.top, 14)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(company.groups) { group in
                        SidebarRow(
                            title: group.name.isEmpty ? "Untitled Group" : group.name,
                            subtitle: groupSubtitle(group),
                            symbol: "music.mic",
                            colors: group.colors,
                            isSelected: appState.selection == .group(group.id),
                            namespace: highlight
                        ) { appState.navigate(to: .group(group.id)) }
                        .contextMenu {
                            Button("Edit Group…") { appState.groupSheet = .edit(group) }
                            Divider()
                            Button("Delete Group…", role: .destructive) { groupToDelete = group }
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }

                    NewGroupButton(title: "New Group", help: "New Group (⇧⌘N)") { appState.groupSheet = .add }
                        .padding(.top, 4)

                    // STUDIO: NXM's dance studio, separate from the idol groups.
                    label("Studio").padding(.top, 14)
                    SidebarRow(
                        title: "Dance Studio",
                        subtitle: "\(company.totalDancers) dancers",
                        symbol: "figure.dance",
                        colors: Theme.brandColors,
                        isSelected: appState.selection == .danceStudio,
                        namespace: highlight
                    ) { appState.navigate(to: .danceStudio) }
                    ForEach(company.danceGroups) { crew in
                        SidebarRow(
                            title: crew.name.isEmpty ? "Untitled" : crew.name,
                            subtitle: "\(crew.type.shortName) · \(crew.countText)",
                            symbol: crew.type.symbol,
                            colors: crew.colors,
                            isSelected: appState.selection == .danceGroup(crew.id),
                            namespace: highlight
                        ) { appState.navigate(to: .danceGroup(crew.id)) }
                        .contextMenu {
                            Button("Edit Dance Group…") { appState.danceSheet = .edit(crew) }
                            Divider()
                            Button("Delete Dance Group…", role: .destructive) { crewToDelete = crew }
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    NewGroupButton(title: "New Dance Group", help: "New Dance Group") { appState.danceSheet = .add }
                        .padding(.top, 4)
                }
                .animation(Theme.bouncy, value: company.groups.map(\.id))
                .animation(Theme.bouncy, value: company.danceGroups.map(\.id))
            }
            .scrollIndicators(.never)

            ChadderMascot()
                .deleteDanceGroupDialog($crewToDelete)
                .padding(.top, 8)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
        .confirmationDialog(
            "Delete \(groupToDelete?.name ?? "this group")?",
            isPresented: Binding(get: { groupToDelete != nil }, set: { if !$0 { groupToDelete = nil } }),
            presenting: groupToDelete
        ) { group in
            Button("Delete Group", role: .destructive) { appState.deleteGroup(group) }
        } message: { group in
            let rels = appState.company.relationshipCount(involving: Set(group.members.map(\.id)))
            Text("This permanently removes \(group.members.count) members, \(group.subUnits.count) sub-units and \(rels == 1 ? "1 relationship" : "\(rels) relationships"). It can't be undone.")
        }
    }

    private var surveySubtitle: String {
        let count = appState.company.chadder.answers.count
        return count == 1 ? "1 answer" : "\(count) answers"
    }

    private func groupSubtitle(_ group: IdolGroup) -> String {
        let members = group.members.count == 1 ? "1 member" : "\(group.members.count) members"
        return group.fandomName.isEmpty ? members : "\(members) · \(group.fandomName)"
    }

    private var brand: some View {
        HStack(spacing: 10) {
            NXLogo(size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text("NXM HQ")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text(appState.company.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 6)
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 8)
            .padding(.bottom, 2)
    }
}

/// Dashed "+ New …" row at the bottom of a sidebar section.
private struct NewGroupButton: View {
    var title = "New Group"
    var help = "New Group"
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(hovering ? .white : Theme.red)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(hovering ? AnyShapeStyle(Theme.brand) : AnyShapeStyle(Theme.red.opacity(0.14)))
                    )
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.red.opacity(hovering ? 0.6 : 0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .contentShape(Rectangle())
            .scaleEffect(hovering ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.bouncy, value: hovering)
        .help(help)
    }
}

private struct SidebarRow: View {
    let title: String
    let subtitle: String?
    let symbol: String
    let colors: [Color]
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(
                        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.primary.opacity(0.09))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(colors[0].opacity(0.35), lineWidth: 1)
                        )
                        .matchedGeometryEffect(id: "selection", in: namespace)
                } else if hovering {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.primary.opacity(0.04))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
