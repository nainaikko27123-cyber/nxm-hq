import Foundation
import Observation

@Observable
final class Company {
    var name: String
    var ceoName: String
    private(set) var groups: [IdolGroup]
    /// Two-way relationships between members of any group.
    var relationships: [Relationship]
    var customRelationshipTypes: [CustomRelationshipType]
    /// Chadder's settings, custom lines and fan survey answers.
    var chadder: ChadderData
    /// NXM's dance studio: crews with dancer counts (kept out of "Total artists").
    var danceGroups: [DanceGroup] = []
    var studioDescription: String = ""
    /// Last 10 live-status changes, newest first.
    var statusLog: [StatusLogEntry] = []
    static let statusLogLimit = 10

    init(name: String, ceoName: String, groups: [IdolGroup] = [],
         relationships: [Relationship] = [], customRelationshipTypes: [CustomRelationshipType] = [],
         chadder: ChadderData = ChadderData()) {
        self.name = name
        self.ceoName = ceoName
        self.groups = groups
        self.relationships = relationships
        self.customRelationshipTypes = customRelationshipTypes
        self.chadder = chadder
    }

    func addGroup(_ group: IdolGroup) {
        groups.append(group)
    }

    func removeGroup(id: UUID) {
        if let group = groups.first(where: { $0.id == id }) {
            group.members.forEach { PhotoStore.delete($0.photoFileName) }
            deleteRelationships(involving: Set(group.members.map(\.id)))
            // Unlink the group and its units from any dance crews.
            let unitIDs = Set(group.subUnits.map(\.id))
            for crew in danceGroups {
                crew.worksWithGroups.removeAll { $0 == id }
                crew.worksWithUnits.removeAll { unitIDs.contains($0) }
            }
        }
        groups.removeAll { $0.id == id }
    }

    var totalArtists: Int { groups.reduce(0) { $0 + $1.members.count } }
    /// Sets (or clears, with nil) a group's live status.
    func setLiveStatus(_ status: GroupStatus?, for group: IdolGroup) {
        group.liveStatus = status
        let text = status?.sentence(for: group.name) ?? "\(group.name)'s status was cleared"
        statusLog.insert(StatusLogEntry(groupID: group.id, text: text, kind: status?.kind), at: 0)
        if statusLog.count > Self.statusLogLimit { statusLog.removeLast(statusLog.count - Self.statusLogLimit) }
    }

    var totalAwards: Int { groups.reduce(0) { $0 + $1.awards } }
    var totalSubUnits: Int { groups.reduce(0) { $0 + $1.subUnits.count } }
    var firstDebut: Date? { groups.compactMap(\.debutDate).min() }
}
