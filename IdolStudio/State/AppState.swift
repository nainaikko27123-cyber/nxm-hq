import SwiftUI
import Observation
import AppKit

enum SidebarItem: Hashable {
    case overview
    case survey
    case danceStudio
    case danceGroup(UUID)
    case group(UUID)
}

/// Single source of truth for the app, injected into the view tree with `.environment(_:)`.
@Observable
final class AppState {
    var company: Company
    private(set) var selection: SidebarItem = .overview
    /// Edge the next page slides in from, based on where it sits in the sidebar.
    private(set) var transitionEdge: Edge = .trailing

    // Dialogs live here so menu commands (⌘N, ⌘E) can open them. Shown centered by ModalHost.
    var memberSheet: MemberEditorMode? { didSet { stamp("member", memberSheet != nil) } }
    var groupSheet: GroupEditorMode? { didSet { stamp("group", groupSheet != nil) } }
    /// Member whose profile popup is open.
    var profileMember: IdolMember?
    var relationshipSheet: RelationshipEditorMode? { didSet { stamp("relationship", relationshipSheet != nil) } }
    var danceSheet: DanceGroupEditorMode? { didSet { stamp("dance", danceSheet != nil) } }
    /// Small centered dialogs (count edits, competition form, status picker…), top last.
    var customModals: [CustomModal] = []
    @ObservationIgnored private var openedAt: [String: Date] = [:]
    /// True when the app hasn't been opened for a while; Chadder's first line greets you back.
    var chadderWelcomeBack = false

    @ObservationIgnored private let store: CompanyStore
    @ObservationIgnored private var pendingSave: DispatchWorkItem?
    @ObservationIgnored private var terminateObserver: NSObjectProtocol?

    init(store: CompanyStore = CompanyStore()) {
        self.store = store
        if let saved = store.load() {
            company = saved
        } else {
            company = .sample
            store.save(CompanyRecord(company))
        }
        if let last = company.chadder.lastActive,
           Date().timeIntervalSince(last) > ChadderBrain.welcomeBackAfterDays * 86_400 {
            chadderWelcomeBack = true
        }
        company.chadder.lastActive = .now
        observeForAutosave()
        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.company.chadder.lastActive = .now
            self?.saveNow()
        }
    }

    deinit {
        if let terminateObserver { NotificationCenter.default.removeObserver(terminateObserver) }
    }

    var selectedGroup: IdolGroup? {
        guard case .group(let id) = selection else { return nil }
        return company.groups.first { $0.id == id }
    }

    var isPresentingSheet: Bool {
        memberSheet != nil || groupSheet != nil || relationshipSheet != nil || danceSheet != nil || !customModals.isEmpty
    }

    // MARK: Dialogs

    private func stamp(_ key: String, _ open: Bool) {
        if open { if openedAt[key] == nil { openedAt[key] = .now } } else { openedAt[key] = nil }
    }

    /// Open dialogs bottom to top. A relationship dialog opened from the member form sits above it.
    var modalLayers: [ModalLayer] {
        var layers: [ModalLayer] = []
        func time(_ key: String) -> Date { openedAt[key] ?? .now }
        if let m = memberSheet { layers.append(ModalLayer(id: "member-\(m.id)", kind: .member(m), openedAt: time("member"))) }
        if let g = groupSheet { layers.append(ModalLayer(id: "group-\(g.id)", kind: .group(g), openedAt: time("group"))) }
        if let d = danceSheet { layers.append(ModalLayer(id: "dance-\(d.id)", kind: .dance(d), openedAt: time("dance"))) }
        if let r = relationshipSheet { layers.append(ModalLayer(id: "rel-\(r.id)", kind: .relationship(r), openedAt: time("relationship"))) }
        for modal in customModals {
            layers.append(ModalLayer(id: modal.id.uuidString, kind: .custom(modal), openedAt: time(modal.id.uuidString)))
        }
        return layers
    }

    /// Shows a small centered dialog. `content` gets a closure that closes it.
    func present<V: View>(maxWidth: CGFloat = 520, @ViewBuilder _ content: (_ close: @escaping () -> Void) -> V) {
        let id = UUID()
        let close: () -> Void = { [weak self] in
            withAnimation(.easeOut(duration: 0.18)) { self?.customModals.removeAll { $0.id == id } }
        }
        let modal = CustomModal(id: id, maxWidth: maxWidth, content: AnyView(content(close)))
        openedAt[id.uuidString] = .now
        customModals.append(modal)
    }

    func closeModal(_ layer: ModalLayer) {
        withAnimation(.easeOut(duration: 0.18)) {
            switch layer.kind {
            case .member: memberSheet = nil
            case .group: groupSheet = nil
            case .dance: danceSheet = nil
            case .relationship: relationshipSheet = nil
            case .custom(let modal):
                customModals.removeAll { $0.id == modal.id }
                openedAt[modal.id.uuidString] = nil
            }
        }
    }

    var selectedDanceGroup: DanceGroup? {
        guard case .danceGroup(let id) = selection else { return nil }
        return company.danceGroup(withID: id)
    }

    func deleteDanceGroup(_ crew: DanceGroup) {
        if selection == .danceGroup(crew.id) {
            transitionEdge = .leading
            withAnimation(Theme.spring) { selection = .danceStudio }
        }
        withAnimation(Theme.bouncy) { company.removeDanceGroup(id: crew.id) }
    }

    /// Removes a member plus all of their relationships. Returns how many relationships were removed.
    @discardableResult
    func removeMember(_ member: IdolMember, from group: IdolGroup) -> Int {
        if profileMember?.id == member.id { profileMember = nil }
        var removed = 0
        withAnimation(Theme.bouncy) {
            removed = company.deleteRelationships(involving: [member.id])
            group.removeMember(member)
        }
        return removed
    }

    func openProfile(_ member: IdolMember) {
        withAnimation(.easeOut(duration: 0.2)) { profileMember = member }
    }

    /// Opens a member's edit form, switching to their group's page first.
    func edit(_ member: IdolMember) {
        if let group = company.group(containing: member.id) { navigate(to: .group(group.id)) }
        memberSheet = .edit(member)
    }

    // MARK: Groups

    /// Adds the group and jumps straight to its page.
    func createGroup(_ group: IdolGroup) {
        withAnimation(Theme.bouncy) { company.addGroup(group) }
        navigate(to: .group(group.id))
    }

    func deleteGroup(_ group: IdolGroup) {
        if selection == .group(group.id) {
            transitionEdge = .leading
            withAnimation(Theme.spring) { selection = .overview }
        }
        withAnimation(Theme.bouncy) { company.removeGroup(id: group.id) }
    }

    // MARK: Navigation

    func navigate(to item: SidebarItem) {
        guard item != selection else { return }
        transitionEdge = order(of: item) >= order(of: selection) ? .trailing : .leading
        // Apply the direction first so the outgoing page picks up the matching exit transition.
        DispatchQueue.main.async {
            withAnimation(Theme.spring) { self.selection = item }
        }
    }

    private func order(of item: SidebarItem) -> Int {
        switch item {
        case .overview: 0
        case .survey: 1
        case .group(let id): (company.groups.firstIndex { $0.id == id } ?? 0) + 2
        case .danceStudio: company.groups.count + 2
        case .danceGroup(let id): (company.danceGroups.firstIndex { $0.id == id } ?? 0) + company.groups.count + 3
        }
    }

    // MARK: Persistence

    /// Re-arms after every change: any edit to the company, its groups or members schedules a save.
    private func observeForAutosave() {
        withObservationTracking {
            _ = CompanyRecord(company)
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.scheduleSave()
                self?.observeForAutosave()
            }
        }
    }

    /// Debounced so typing doesn't write the file on every keystroke.
    private func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        store.save(CompanyRecord(company))
    }
}
