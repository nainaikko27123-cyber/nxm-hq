import SwiftUI

struct CompanyOverviewView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var company = appState.company

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(eyebrow: "Company Overview", title: company.name)

                LiveStatusBar()

                // Identity card
                HStack(spacing: 20) {
                    NXLogo(size: 88)
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Company name", text: $company.name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        HStack(spacing: 6) {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundStyle(.secondary)
                            Text("CEO").foregroundStyle(.secondary)
                            TextField("CEO name", text: $company.ceoName)
                                .textFieldStyle(.plain)
                        }
                        .font(.body)
                    }
                    Spacer()
                }
                .card(padding: 22)

                // Quick stats
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
                    StatTile(value: "\(company.totalArtists)", label: "Total artists",
                             symbol: "person.2.fill", colors: [Color(hex: "#FF4D4D"), Theme.red])
                    StatTile(value: "\(company.groups.count)", label: company.groups.count == 1 ? "Group" : "Groups",
                             symbol: "music.mic", colors: [Theme.red, Theme.darkRed])
                    StatTile(value: "\(company.totalSubUnits)", label: "Sub-units",
                             symbol: "square.grid.2x2.fill", colors: [Color(hex: "#3A3A3A"), Color(hex: "#111111")])
                    StatTile(value: timeSinceFirstDebut, label: "Since first debut",
                             symbol: "calendar", colors: [Theme.darkRed, Color(hex: "#1A1A1A")])
                    StatTile(value: "\(company.totalAwards)", label: "Total awards",
                             symbol: "trophy.fill", colors: [Color(hex: "#FF4D4D"), Theme.darkRed])
                    // Dancers are counted separately from "Total artists".
                    StatTile(value: "\(company.totalDancers)", label: "Dancers",
                             symbol: "figure.dance", colors: [Color(hex: "#3A3A3A"), Theme.red])
                }

                SectionTitle(title: "Groups")
                if company.groups.isEmpty {
                    Label("No groups yet. Click + New Group in the sidebar to create one.", systemImage: "music.mic")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 14)], spacing: 14) {
                    ForEach(company.groups) { group in
                        // Tap gesture rather than a Button so the award pill inside can be its own button.
                        GroupSummaryCard(group: group)
                            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .onTapGesture { appState.navigate(to: .group(group.id)) }
                            .hoverLift()
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
    }

    private var timeSinceFirstDebut: String {
        guard let first = appState.company.firstDebut else { return "—" }
        let parts = Calendar.current.dateComponents([.year, .month], from: first, to: .now)
        let years = parts.year ?? 0, months = parts.month ?? 0
        return years > 0 ? "\(years)y \(months)m" : "\(months)m"
    }
}

struct GroupSummaryCard: View {
    let group: IdolGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                group.gradient
                Image(systemName: "waveform")
                    .font(.system(size: 90, weight: .black))
                    .foregroundStyle(group.bannerText)
                    .opacity(0.12)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .offset(x: 10, y: 14)
                VStack(alignment: .leading, spacing: 2) {
                    if !group.bannerTag.isEmpty {
                        BannerTag(text: group.bannerTag, color: group.bannerText).padding(.bottom, 3)
                    }
                    Text(group.name.isEmpty ? "Untitled Group" : group.name)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                    HStack(spacing: 6) {
                        if let debut = group.debutDate {
                            Text("Debuted \(debut.formatted(date: .abbreviated, time: .omitted))").opacity(0.85)
                        } else {
                            BannerPlaceholder(text: "Debut not added yet", color: group.bannerText)
                        }
                        Text("·").opacity(0.85)
                        if group.fandomName.isEmpty {
                            BannerPlaceholder(text: "Fandom not added yet", color: group.bannerText)
                        } else {
                            Label(group.fandomName, systemImage: "heart.fill").opacity(0.85)
                        }
                    }
                    .font(.caption.weight(.medium))
                }
                .foregroundStyle(group.bannerText)
                .padding(16)
            }
            .frame(height: 112)
            .clipped()

            VStack(alignment: .leading, spacing: 12) {
                SwiftUI.Group {
                    if group.concept.isEmpty {
                        Text("Concept not added yet").italic().foregroundStyle(.tertiary)
                    } else {
                        Text(group.concept).foregroundStyle(.secondary)
                    }
                }
                .font(.callout)
                .lineLimit(2, reservesSpace: true)
                // One row when it fits, otherwise the pills drop under the avatars.
                ViewThatFits(in: .horizontal) {
                    HStack {
                        AvatarStack(members: group.members)
                        Spacer(minLength: 8)
                        pills
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        AvatarStack(members: group.members)
                        pills
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.glass)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.10)))
    }

    private var pills: some View {
        HStack(spacing: 6) {
            Chip(text: group.members.count == 1 ? "1 member" : "\(group.members.count) members", tint: Color(hex: "#FF4D4D"))
            Chip(text: group.subUnits.count == 1 ? "1 unit" : "\(group.subUnits.count) units", tint: .white)
            AwardPill(group: group)
        }
        .fixedSize()
    }
}
