import SwiftUI

/// Glass member card: gradient border and colored glow, hover elevation, profile info,
/// collapsible personality, relationship tags, and an Edit button.
/// Empty fields show a soft "Not added yet" instead of made-up data.
struct MemberCard: View {
    let member: IdolMember
    let group: IdolGroup
    let onSelect: () -> Void

    @Environment(AppState.self) private var appState
    @State private var hovering = false
    @State private var showPersonality = false
    @State private var tapCount = 0

    private let radius: CGFloat = 20
    private var color: Color { Color(hex: member.colorAccent) }
    /// Accent for text and icons; very dark accents (like deep red) are lifted so they stay readable.
    private var ink: Color { color.readableOnDark }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            PartnerLine(member: member)
            rolePills
            profileRow
            Divider().opacity(0.5)
            personalitySection
            relationshipsSection
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Theme.glass)
                .overlay(
                    // Faint tint of the member's color behind the glass.
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(LinearGradient(colors: [color.opacity(0.16), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [color.opacity(hovering ? 0.9 : 0.6), .white.opacity(0.08), color.opacity(hovering ? 0.5 : 0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: hovering ? 1.5 : 1
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        // Each member's own colored glow, stronger on hover.
        .shadow(color: color.opacity(hovering ? 0.4 : 0.18), radius: hovering ? 22 : 14, y: hovering ? 10 : 4)
        .scaleEffect(hovering ? 1.03 : 1)
        .animation(Theme.bouncy, value: hovering)
        // Bouncy click feedback: squash, overshoot, settle.
        .keyframeAnimator(initialValue: 1.0, trigger: tapCount) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            SpringKeyframe(0.93, duration: 0.10, spring: .snappy)
            SpringKeyframe(1.04, duration: 0.16, spring: .bouncy)
            SpringKeyframe(1.0, duration: 0.22, spring: .smooth)
        }
        .onHover { hovering = $0 }
        .onTapGesture(perform: open)
        // Animate in-place updates (renames, new roles, recolors) with a spring.
        .animation(Theme.bouncy, value: member.roles)
        .animation(Theme.bouncy, value: member.colorAccent)
        .animation(Theme.bouncy, value: member.avatarSymbol)
    }

    private func open() {
        tapCount += 1
        // Let the bounce play before the editor sheet slides in.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: onSelect)
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            MemberAvatar(member: member, size: 76, cornerRadius: 22, zoomOnHover: member.photoFileName != nil)
                .shadow(color: color.opacity(0.5), radius: 10, y: 3)
                .onTapGesture { appState.openProfile(member) }
                .help("Open profile")
            VStack(alignment: .leading, spacing: 1) {
                Text(member.stageName.isEmpty ? "Unnamed" : member.stageName)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if member.realName.isEmpty {
                    NotAddedYet(text: "No real name yet")
                } else {
                    Text(member.realName)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                EditPill(tint: color, action: open)
                    .fixedSize()
                    .padding(.top, 6)
            }
            Spacer(minLength: 0)
        }
    }

    private var rolePills: some View {
        FlowLayout(spacing: 5, lineSpacing: 5) {
            if member.roles.isEmpty {
                NotAddedYet(text: "Roles not added yet")
            }
            ForEach(Array(member.roles.enumerated()), id: \.element) { index, role in
                Chip(text: role.rawValue, tint: index == 0 ? color : ink, filled: index == 0)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
    }

    private var profileRow: some View {
        HStack(spacing: 8) {
            InfoTile(symbol: "number", label: "Age", tint: ink) {
                if let age = member.displayAge {
                    Text("\(age)")
                } else {
                    NotAddedYet()
                }
            }
            InfoTile(symbol: "gift", label: "Birthday", tint: ink) {
                if let birthday = member.birthday {
                    Text(birthday.formatted(.dateTime.day().month(.abbreviated).year()))
                } else {
                    NotAddedYet()
                }
            }
        }
    }

    private var personalitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(Theme.bouncy) { showPersonality.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(ink)
                    Text("Personality")
                        .font(.subheadline.weight(.semibold))
                    if !member.personality.mbti.isEmpty {
                        Text(member.personality.mbti)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showPersonality ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showPersonality {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("MBTI").font(.caption).foregroundStyle(.secondary)
                        if member.personality.mbti.isEmpty {
                            NotAddedYet()
                        } else {
                            Chip(text: member.personality.mbti, tint: color, filled: true)
                        }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("About").font(.caption).foregroundStyle(.secondary)
                        if member.personality.summary.isEmpty {
                            NotAddedYet()
                        } else {
                            Text(member.personality.summary)
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if !member.personality.traits.isEmpty {
                        FlowLayout(spacing: 5, lineSpacing: 5) {
                            ForEach(member.personality.traits, id: \.self) { trait in
                                Chip(text: trait)
                            }
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.92, anchor: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
    }

    private var relationshipsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "person.2.wave.2.fill").foregroundStyle(ink)
                Text("Relationships & Dynamics").font(.subheadline.weight(.semibold))
                Spacer(minLength: 4)
                Button {
                    appState.relationshipSheet = .add(from: member.id)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Add relationship")
            }
            RelationshipChipList(member: member) { appState.relationshipSheet = $0 }
        }
    }
}

/// Soft placeholder for a field that hasn't been filled in.
struct NotAddedYet: View {
    var text = "Not added yet"

    var body: some View {
        Text(text)
            .font(.caption.italic())
            .foregroundStyle(.tertiary)
    }
}

private struct InfoTile<Value: View>: View {
    let symbol: String
    let label: String
    let tint: Color
    @ViewBuilder var value: Value

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(label, systemImage: symbol)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint.opacity(0.9))
            value
                .font(.callout.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct EditPill: View {
    let tint: Color
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Label("Edit", systemImage: "pencil")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundStyle(hovering ? (tint.isLight ? .black : .white) : .primary)
                .background(Capsule().fill(hovering ? AnyShapeStyle(tint) : AnyShapeStyle(.white.opacity(0.08))))
                .overlay(Capsule().strokeBorder(tint.opacity(0.4)))
                .scaleEffect(hovering ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.bouncy, value: hovering)
        .help("Edit member")
    }
}
