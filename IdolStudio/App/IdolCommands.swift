import SwiftUI

/// Menu bar commands: ⌘N new member, ⇧⌘N new group, ⌘E edit group, ⌘1–9 to jump between pages.
struct IdolCommands: Commands {
    let appState: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Member") {
                guard appState.selectedGroup != nil, !appState.isPresentingSheet else { return }
                appState.memberSheet = .add
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(appState.selectedGroup == nil || appState.isPresentingSheet)

            Button("New Group…") {
                guard !appState.isPresentingSheet else { return }
                appState.groupSheet = .add
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(appState.isPresentingSheet)
        }

        CommandMenu("Group") {
            Button("Edit Group…") {
                guard let group = appState.selectedGroup, !appState.isPresentingSheet else { return }
                appState.groupSheet = .edit(group)
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(appState.selectedGroup == nil || appState.isPresentingSheet)

            Divider()

            Button("Company Overview") { go(.overview) }
                .keyboardShortcut("1", modifiers: .command)
            // ⌘2–⌘9 cover the first eight groups; the rest are still listed without a shortcut.
            ForEach(Array(appState.company.groups.enumerated()), id: \.element.id) { index, group in
                let title = group.name.isEmpty ? "Untitled Group" : group.name
                if index < 8 {
                    Button(title) { go(.group(group.id)) }
                        .keyboardShortcut(KeyEquivalent(Character(String(index + 2))), modifiers: .command)
                } else {
                    Button(title) { go(.group(group.id)) }
                }
            }
        }
    }

    private func go(_ item: SidebarItem) {
        guard !appState.isPresentingSheet else { return }
        appState.navigate(to: item)
    }
}
