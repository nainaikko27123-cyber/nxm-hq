import Foundation

enum BuiltInRelationshipType: String, Codable, CaseIterable, Identifiable, Hashable {
    case couple, twin, sibling, siblingInLaw, bestFriend, friend, rival, friendlyRival
    case mentorMentee, roommate, duoPartner, colleague, family, other

    var id: String { rawValue }

    var name: String {
        switch self {
        case .couple: "Couple"
        case .twin: "Twin"
        case .sibling: "Sibling"
        case .siblingInLaw: "Sibling-in-law"
        case .bestFriend: "Best Friend"
        case .friend: "Friend"
        case .rival: "Rival"
        case .friendlyRival: "Friendly Rival"
        case .mentorMentee: "Mentor / Mentee"
        case .roommate: "Roommate"
        case .duoPartner: "Duo Partner"
        case .colleague: "Colleague"
        case .family: "Family"
        case .other: "Other"
        }
    }

    /// Labels for side A and side B when the type has a direction. Nil = same label both ways.
    var sideLabels: (a: String, b: String)? {
        self == .mentorMentee ? ("Mentor", "Mentee") : nil
    }
}

/// A type the user made up. If `otherSideName` is set, the type has a direction:
/// side A is called `name`, side B `otherSideName` (e.g. "Senpai" / "Kouhai").
struct CustomRelationshipType: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var otherSideName: String = ""

    var isDirectional: Bool { !otherSideName.isEmpty }
}

enum RelationshipType: Hashable, Codable {
    case builtIn(BuiltInRelationshipType)
    case custom(UUID)
}

enum RelationshipStatus: String, Codable, CaseIterable, Identifiable {
    case current = "Current"
    case past = "Past"
    case complicated = "It's complicated"
    case secret = "Secret"
    var id: String { rawValue }
}

/// Whether the world knows about it.
enum RelationshipVisibility: String, Codable, CaseIterable, Identifiable {
    case `public` = "Public"
    case `private` = "Private"
    var id: String { rawValue }
}

/// One two-way relationship between two members (any groups). Stored ONCE in the company's
/// relationships list and read by both people; members are referenced by id, never by name.
struct Relationship: Identifiable, Codable, Hashable {
    var id = UUID()
    /// For types with a direction, `memberA` is the first side (e.g. the Mentor). Saved as "personA".
    var memberA: UUID
    /// Saved as "personB".
    var memberB: UUID
    var type: RelationshipType
    var status: RelationshipStatus = .current
    var visibility: RelationshipVisibility = .public
    var note: String = ""
    var startDate: Date? = nil

    init(id: UUID = UUID(), memberA: UUID, memberB: UUID, type: RelationshipType,
         status: RelationshipStatus = .current, visibility: RelationshipVisibility = .public,
         note: String = "", startDate: Date? = nil) {
        self.id = id
        self.memberA = memberA
        self.memberB = memberB
        self.type = type
        self.status = status
        self.visibility = visibility
        self.note = note
        self.startDate = startDate
    }

    private enum CodingKeys: String, CodingKey {
        case id, personA, personB, type, status, visibility, note, startDate
        case memberA, memberB   // earlier key names, read only
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        memberA = try c.decodeIfPresent(UUID.self, forKey: .personA) ?? c.decode(UUID.self, forKey: .memberA)
        memberB = try c.decodeIfPresent(UUID.self, forKey: .personB) ?? c.decode(UUID.self, forKey: .memberB)
        type = try c.decode(RelationshipType.self, forKey: .type)
        status = try c.decodeIfPresent(RelationshipStatus.self, forKey: .status) ?? .current
        visibility = try c.decodeIfPresent(RelationshipVisibility.self, forKey: .visibility) ?? .public
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        startDate = try c.decodeIfPresent(Date.self, forKey: .startDate)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(memberA, forKey: .personA)
        try c.encode(memberB, forKey: .personB)
        try c.encode(type, forKey: .type)
        try c.encode(status, forKey: .status)
        try c.encode(visibility, forKey: .visibility)
        try c.encode(note, forKey: .note)
        try c.encodeIfPresent(startDate, forKey: .startDate)
    }

    func involves(_ memberID: UUID) -> Bool { memberA == memberID || memberB == memberID }

    func other(than memberID: UUID) -> UUID { memberA == memberID ? memberB : memberA }

    func connects(_ x: UUID, _ y: UUID) -> Bool {
        (memberA == x && memberB == y) || (memberA == y && memberB == x)
    }
}

/// Optional "Relationship status" line on a member card.
enum RelationshipStatusLine: String, Codable, CaseIterable, Identifiable {
    case single = "Single"
    case inRelationship = "In a relationship"
    case married = "Married"
    case complicated = "It's complicated"
    case `private` = "Private"
    var id: String { rawValue }
}

// MARK: - Company helpers

extension Company {
    var allMembers: [IdolMember] { groups.flatMap(\.members) }

    func member(withID id: UUID) -> IdolMember? {
        for group in groups { if let m = group.member(with: id) { return m } }
        return nil
    }

    func group(containing memberID: UUID) -> IdolGroup? {
        groups.first { $0.member(with: memberID) != nil }
    }

    /// Relationships for a member, skipping any whose other person no longer exists.
    func relationships(for memberID: UUID) -> [Relationship] {
        relationships.filter { $0.involves(memberID) && member(withID: $0.other(than: memberID)) != nil }
    }

    func customType(_ id: UUID) -> CustomRelationshipType? {
        customRelationshipTypes.first { $0.id == id }
    }

    /// Name used in pickers, e.g. "Mentor / Mentee" or "Senpai / Kouhai".
    func typeName(_ type: RelationshipType) -> String {
        switch type {
        case .builtIn(let builtIn): return builtIn.name
        case .custom(let id):
            guard let custom = customType(id) else { return "Other" }
            return custom.isDirectional ? "\(custom.name) / \(custom.otherSideName)" : custom.name
        }
    }

    func sideLabels(_ type: RelationshipType) -> (a: String, b: String)? {
        switch type {
        case .builtIn(let builtIn): return builtIn.sideLabels
        case .custom(let id):
            guard let custom = customType(id), custom.isDirectional else { return nil }
            return (custom.name, custom.otherSideName)
        }
    }

    /// What the *other* person is to `viewer`, e.g. on the mentor's card the mentee shows as "Mentee".
    func label(for relationship: Relationship, viewer: UUID) -> String {
        if let sides = sideLabels(relationship.type) {
            return relationship.memberA == viewer ? sides.b : sides.a
        }
        return typeName(relationship.type)
    }

    func currentPartner(of memberID: UUID) -> IdolMember? {
        relationships(for: memberID)
            .first { $0.type == .builtIn(.couple) && $0.status == .current }
            .flatMap { member(withID: $0.other(than: memberID)) }
    }

    /// The card's relationship status line. A current Couple relationship fills in the partner's name.
    func relationshipStatusText(for member: IdolMember) -> String? {
        if let partner = currentPartner(of: member.id) {
            switch member.relationshipStatus {
            case .married: return "Married to \(partner.stageName)"
            case .complicated: return "It's complicated with \(partner.stageName)"
            case .private: return "Private"
            default: return "In a relationship with \(partner.stageName)"
            }
        }
        return member.relationshipStatus?.rawValue
    }

    func save(_ relationship: Relationship) {
        if let index = relationships.firstIndex(where: { $0.id == relationship.id }) {
            relationships[index] = relationship
        } else {
            relationships.append(relationship)
        }
    }

    func deleteRelationship(id: UUID) {
        relationships.removeAll { $0.id == id }
    }

    func relationshipCount(involving memberIDs: Set<UUID>) -> Int {
        relationships.filter { memberIDs.contains($0.memberA) || memberIDs.contains($0.memberB) }.count
    }

    /// Removes every relationship involving these members. Returns how many were removed.
    @discardableResult
    func deleteRelationships(involving memberIDs: Set<UUID>) -> Int {
        let before = relationships.count
        relationships.removeAll { memberIDs.contains($0.memberA) || memberIDs.contains($0.memberB) }
        return before - relationships.count
    }

    /// Current Couple relationships that would clash with saving `candidate` (one current Couple per person).
    func coupleConflicts(for candidate: Relationship) -> [Relationship] {
        guard candidate.type == .builtIn(.couple), candidate.status == .current else { return [] }
        return relationships.filter {
            $0.id != candidate.id && $0.type == .builtIn(.couple) && $0.status == .current
                && ($0.involves(candidate.memberA) || $0.involves(candidate.memberB))
        }
    }

    @discardableResult
    func addCustomType(name: String, otherSideName: String) -> CustomRelationshipType {
        let type = CustomRelationshipType(name: name, otherSideName: otherSideName)
        customRelationshipTypes.append(type)
        return type
    }

    func isCustomTypeInUse(_ id: UUID) -> Bool {
        relationships.contains { $0.type == .custom(id) }
    }

    func deleteCustomType(_ id: UUID) {
        guard !isCustomTypeInUse(id) else { return }
        customRelationshipTypes.removeAll { $0.id == id }
    }
}
