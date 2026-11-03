import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        HStack(spacing: 0) {
            SidebarView()
                .frame(width: 236)
                .background {
                    ZStack {
                        VisualEffectBackground(material: .sidebar)
                        Color.black.opacity(0.55)
                    }
                }

            Rectangle()
                .fill(LinearGradient(colors: [Theme.red.opacity(0.6), Theme.red.opacity(0.08)], startPoint: .top, endPoint: .bottom))
                .frame(width: 1)

            ZStack {
                accentWash
                detail
                    .id(appState.selection)
                    .transition(
                        .asymmetric(
                            insertion: .pageSlide(from: appState.transitionEdge),
                            removal: .pageSlide(from: appState.transitionEdge.opposite)
                        )
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    VisualEffectBackground(material: .underWindowBackground)
                    Color.black.opacity(0.72)
                }
            }
            .clipped()
        }
        .overlay {
            if let member = appState.profileMember {
                MemberProfileView(member: member)
                    .transition(.opacity)
            }
        }
        .overlay { ModalHost() }
        .overlay { CursorGlow().allowsHitTesting(false) }
        .ignoresSafeArea()
        .sheet(item: $appState.relationshipSheet) { mode in
            RelationshipEditorView(mode: mode, company: appState.company)
        }
        .sheet(item: $appState.groupSheet) { mode in
            GroupEditorView(mode: mode)
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let group = appState.selectedGroup {
            GroupDetailView(group: group)
        } else if appState.selection == .survey {
            FanSurveyView()
        } else if let crew = appState.selectedDanceGroup {
            DanceGroupDetailView(crew: crew)
        } else if case .danceStudio = appState.selection {
            DanceStudioView()
        } else if case .danceGroup = appState.selection {
            DanceStudioView()   // crew was deleted
        } else {
            CompanyOverviewView()
        }
    }

    /// Soft color glow at the top of the page that follows the selected group's theme.
    private var accentWash: some View {
        let colors = appState.selectedGroup?.colors ?? Theme.brandColors
        return LinearGradient(
            colors: [colors[0].opacity(0.22), (colors.last ?? colors[0]).opacity(0.08), .clear],
            startPoint: .topLeading,
            endPoint: .center
        )
        .animation(Theme.spring, value: appState.selection)
        .allowsHitTesting(false)
    }
}

// MARK: - Page transition

/// Slides a page in from one side with a slight scale, like flipping between tabs.
private struct PageSlide: ViewModifier {
    let offset: CGFloat
    let progress: Double  // 0 = off-screen state, 1 = settled

    func body(content: Content) -> some View {
        content
            .offset(x: offset * (1 - progress))
            .scaleEffect(0.97 + 0.03 * progress)
            .opacity(progress)
    }
}

extension AnyTransition {
    static func pageSlide(from edge: Edge) -> AnyTransition {
        let distance: CGFloat = edge == .leading ? -80 : 80
        return .modifier(
            active: PageSlide(offset: distance, progress: 0),
            identity: PageSlide(offset: distance, progress: 1)
        )
    }
}

extension Edge {
    var opposite: Edge {
        switch self {
        case .leading: .trailing
        case .trailing: .leading
        case .top: .bottom
        case .bottom: .top
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState(store: CompanyStore(fileURL: nil)))
        .frame(width: 1180, height: 780)
}
