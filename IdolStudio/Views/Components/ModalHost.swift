import SwiftUI

/// A small dialog shown with `AppState.present(...)` (count edits, competition form, status picker, …).
struct CustomModal: Identifiable {
    let id: UUID
    let maxWidth: CGFloat
    let content: AnyView
}

/// Closes the dialog a view is shown in. Editors call it like `dismiss()`.
struct CloseModalAction {
    var action: () -> Void = {}
    func callAsFunction() { action() }
}

private struct CloseModalKey: EnvironmentKey { static let defaultValue = CloseModalAction() }
/// Largest size a dialog may take: 90% of the window.
private struct ModalBoundsKey: EnvironmentKey { static let defaultValue = CGSize(width: 10_000, height: 10_000) }

extension EnvironmentValues {
    var closeModal: CloseModalAction {
        get { self[CloseModalKey.self] }
        set { self[CloseModalKey.self] = newValue }
    }
    var modalBounds: CGSize {
        get { self[ModalBoundsKey.self] }
        set { self[ModalBoundsKey.self] = newValue }
    }
}

extension View {
    /// Preferred dialog size, shrunk to fit inside the window (never more than 90% of it).
    func modalFrame(width: CGFloat, height: CGFloat) -> some View {
        modifier(ModalFrame(width: width, height: height))
    }
}

private struct ModalFrame: ViewModifier {
    let width: CGFloat
    let height: CGFloat
    @Environment(\.modalBounds) private var bounds
    func body(content: Content) -> some View {
        content.frame(width: min(width, bounds.width), height: min(height, bounds.height))
    }
}

/// Draws every open dialog centered over the window with a dark backdrop. Stacked dialogs work
/// (only the top one is active). Backdrop click closes, asking first only if you typed something.
struct ModalHost: View {
    @Environment(AppState.self) private var appState
    @State private var confirmDiscard: ModalLayer?

    var body: some View {
        GeometryReader { geo in
            let bounds = CGSize(width: geo.size.width * 0.9, height: geo.size.height * 0.9)
            let layers = appState.modalLayers
            ZStack {
                ForEach(Array(layers.enumerated()), id: \.element.id) { index, layer in
                    let isTop = index == layers.count - 1
                    ZStack {
                        Color.black.opacity(isTop ? 0.6 : 0.25)
                            .contentShape(Rectangle())
                            .onTapGesture { if isTop { requestClose(layer) } }
                        ModalCard(layer: layer, bounds: bounds)
                            .disabled(!isTop)   // also turns off the lower dialog's Esc shortcut
                    }
                    .transition(.opacity)
                    .zIndex(Double(index))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(.easeOut(duration: 0.18), value: layers.map(\.id))
        }
        .ignoresSafeArea()
        .onAppear { ChadderBrain.startWatchingKeys() }
        .confirmationDialog("Discard what you typed?",
                            isPresented: Binding(get: { confirmDiscard != nil }, set: { if !$0 { confirmDiscard = nil } }),
                            presenting: confirmDiscard) { layer in
            Button("Discard", role: .destructive) { appState.closeModal(layer) }
            Button("Keep Editing", role: .cancel) {}
        } message: { _ in
            Text("Closing this window throws away your unsaved changes.")
        }
    }

    private func requestClose(_ layer: ModalLayer) {
        if ChadderBrain.lastKeyDown > layer.openedAt { confirmDiscard = layer } else { appState.closeModal(layer) }
    }
}

private struct ModalCard: View {
    let layer: ModalLayer
    let bounds: CGSize
    @Environment(AppState.self) private var appState
    @State private var shown = false

    var body: some View {
        content
            .environment(\.modalBounds, bounds)
            .environment(\.closeModal, CloseModalAction { appState.closeModal(layer) })
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.12)))
            .shadow(color: .black.opacity(0.5), radius: 30, y: 12)
            .scaleEffect(shown ? 1 : 0.94)
            .opacity(shown ? 1 : 0)
            .onAppear { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { shown = true } }
    }

    @ViewBuilder private var content: some View {
        switch layer.kind {
        case .member(let mode):
            if case .edit(let member) = mode, let group = appState.company.group(containing: member.id) {
                MemberEditorView(mode: mode, group: group)
            } else if let group = appState.selectedGroup {
                MemberEditorView(mode: mode, group: group)
            }
        case .group(let mode):
            GroupEditorView(mode: mode)
        case .dance(let mode):
            DanceGroupEditorView(mode: mode)
        case .relationship(let mode):
            RelationshipEditorView(mode: mode, company: appState.company)
        case .custom(let modal):
            FittedScroll(maxHeight: bounds.height) {
                modal.content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: min(modal.maxWidth, bounds.width))
            .background(Color(hex: "#17171A").opacity(0.98))
        }
    }
}

/// Scrolls only when the content is taller than `maxHeight`; otherwise hugs the content.
private struct FittedScroll<Content: View>: View {
    let maxHeight: CGFloat
    @ViewBuilder var content: Content
    @State private var height: CGFloat = 0

    var body: some View {
        ScrollView {
            content.background(GeometryReader { g in
                Color.clear.preference(key: HeightKey.self, value: g.size.height)
            })
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: height == 0 ? nil : min(height, maxHeight))
        .onPreferenceChange(HeightKey.self) { height = $0 }
    }
}

private struct HeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// One open dialog.
struct ModalLayer: Identifiable {
    enum Kind {
        case member(MemberEditorMode)
        case group(GroupEditorMode)
        case dance(DanceGroupEditorMode)
        case relationship(RelationshipEditorMode)
        case custom(CustomModal)
    }
    let id: String
    let kind: Kind
    let openedAt: Date
}
