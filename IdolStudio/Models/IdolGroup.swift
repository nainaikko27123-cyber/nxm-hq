import Foundation
import Observation

struct SubUnit: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var memberIDs: [UUID]
}

/// Named `IdolGroup` rather than `Group` so it doesn't clash with SwiftUI's `Group` view.
@Observable
final class IdolGroup: Identifiable {
    let id: UUID
    var name: String
    var concept: String
    var fandomName: String
    /// Small tag shown in the group's banner, e.g. "Formerly Bubble Girls". Empty = no tag.
    var bannerTag: String = ""
    /// Nil = not added yet.
    var debutDate: Date?
    var members: [IdolMember]
    var subUnits: [SubUnit]
    /// Award count. Only changed through `setAwards(_:)` so it can never go below 0.
    private(set) var awards: Int
    /// Two hex colors used for the group's gradient.
    var themeColors: [String]
    /// What the group is doing right now (shown in the Overview's live status bar). Nil = no status set.
    var liveStatus: GroupStatus?

    init(
        id: UUID = UUID(),
        name: String,
        concept: String,
        fandomName: String = "",
        debutDate: Date? = nil,
        members: [IdolMember] = [],
        subUnits: [SubUnit] = [],
        awards: Int = 0,
        themeColors: [String] = ["#E50914", "#8B0000"]
    ) {
        self.id = id
        self.name = name
        self.concept = concept
        self.fandomName = fandomName
        self.debutDate = debutDate
        self.members = members
        self.subUnits = subUnits
        self.awards = max(0, awards)
        self.themeColors = themeColors
    }

    static let maxAwards = 9999

    func setAwards(_ count: Int) {
        awards = min(max(0, count), Self.maxAwards)
    }

    func member(with id: UUID) -> IdolMember? {
        members.first { $0.id == id }
    }

    func add(_ member: IdolMember) {
        members.append(member)
    }

    /// Removes a member and every sub-unit slot or relationship pointing at them.
    func removeMember(_ member: IdolMember) {
        PhotoStore.delete(member.photoFileName)
        members.removeAll { $0.id == member.id }
        for index in subUnits.indices {
            subUnits[index].memberIDs.removeAll { $0 == member.id }
        }
    }
}
