import SwiftUI

/// What a group is doing right now.
enum GroupStatusKind: String, Codable, CaseIterable, Identifiable {
    case performing, hiatus, event, vacation, busy
    var id: String { rawValue }

    var title: String {
        switch self {
        case .performing: "Performing"
        case .hiatus: "Hiatus"
        case .event: "At an event"
        case .vacation: "On vacation"
        case .busy: "Busy / Sleeping"
        }
    }

    var symbol: String {
        switch self {
        case .performing: "music.mic"
        case .hiatus: "pause.circle.fill"
        case .event: "star.fill"
        case .vacation: "airplane"
        case .busy: "moon.zzz.fill"
        }
    }

    /// Each type has its own color. Performing uses the company red.
    var color: Color {
        switch self {
        case .performing: Theme.red
        case .hiatus: Color(hex: "#9A9AA1")
        case .event: Color(hex: "#FFB300")
        case .vacation: Color(hex: "#4FB3FF")
        case .busy: Color(hex: "#A98BFF")
        }
    }

    /// What the extra detail field is for, and whether it's required.
    var detailPrompt: (label: String, placeholder: String, required: Bool)? {
        switch self {
        case .performing: ("Show or stage", "e.g. Mnet, Music Bank", true)
        case .event: ("Event name", "e.g. KCON LA", true)
        case .vacation: ("Place (optional)", "e.g. Jeju", false)
        case .hiatus, .busy: nil
        }
    }
}

/// One line in the recent-changes log. The sentence is stored as written at the time.
struct StatusLogEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var groupID: UUID
    var text: String
    var kind: GroupStatusKind?   // nil = status cleared
    var date: Date = .now
}

/// A group's live status. `detail` is the show, event or place, depending on the kind.
struct GroupStatus: Codable, Hashable {
    var kind: GroupStatusKind
    var detail: String = ""
    var since: Date = .now
}

extension GroupStatus {
    /// "NG is performing at Mnet now", "Bubble Girls are on a hiatus".
    func sentence(for groupName: String) -> String {
        let name = groupName.isEmpty ? "This group" : groupName
        let verb = Self.isPlural(name) ? "are" : "is"
        let detail = self.detail.trimmingCharacters(in: .whitespaces)
        switch kind {
        case .performing: return "\(name) \(verb) performing at \(detail) now"
        case .hiatus: return "\(name) \(verb) on a hiatus"
        case .event: return "\(name) \(verb) at \(detail)"
        case .vacation: return detail.isEmpty ? "\(name) \(verb) on vacation" : "\(name) \(verb) on vacation in \(detail)"
        case .busy: return "\(name) \(verb) busy or sleeping"
        }
    }

    /// Simple English rule: names ending in a single "s" (Bubble Girls) read as plural.
    static func isPlural(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.hasSuffix("s") && !lower.hasSuffix("ss")
    }
}
