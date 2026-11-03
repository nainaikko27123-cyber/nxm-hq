import Foundation

// MARK: - Codable records
// The @Observable model classes stay plain; these structs are the on-disk format.

struct CompanyRecord: Codable {
    var version = 2
    var name: String
    var ceoName: String
    var groups: [GroupRecord]
    var relationships: [Relationship]
    var customRelationshipTypes: [CustomRelationshipType]
    var chadder: ChadderData
    var statusLog: [StatusLogEntry] = []
    /// Nil only in files saved before the dance studio existed; those get the two starter crews.
    var danceGroups: [DanceGroupRecord]?
    var studioDescription: String = ""

    init(name: String, ceoName: String, groups: [GroupRecord],
         relationships: [Relationship] = [], customRelationshipTypes: [CustomRelationshipType] = [],
         chadder: ChadderData = ChadderData()) {
        self.name = name
        self.ceoName = ceoName
        self.groups = groups
        self.relationships = relationships
        self.customRelationshipTypes = customRelationshipTypes
        self.chadder = chadder
    }

    /// `relationships`, `customRelationshipTypes` and `chadder` were added later; older files still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        name = try c.decode(String.self, forKey: .name)
        ceoName = try c.decode(String.self, forKey: .ceoName)
        groups = try c.decode([GroupRecord].self, forKey: .groups)
        relationships = try c.decodeIfPresent([Relationship].self, forKey: .relationships) ?? []
        customRelationshipTypes = try c.decodeIfPresent([CustomRelationshipType].self, forKey: .customRelationshipTypes) ?? []
        chadder = try c.decodeIfPresent(ChadderData.self, forKey: .chadder) ?? ChadderData()
        statusLog = try c.decodeIfPresent([StatusLogEntry].self, forKey: .statusLog) ?? []
        danceGroups = try c.decodeIfPresent([DanceGroupRecord].self, forKey: .danceGroups)
        studioDescription = try c.decodeIfPresent(String.self, forKey: .studioDescription) ?? ""
    }
}

struct DanceGroupRecord: Codable {
    var id: UUID
    var name: String
    var type: DanceGroupType
    var dancerCount: Int
    var logoFileName: String?
    var accentHex: String
    var summary: String
    var styles: [String]
    var headChoreographer: String
    var formedDate: Date?
    var worksWithGroups: [UUID]
    var worksWithUnits: [UUID]
    var notes: String
    var competitions: [Competition]
    var teaches: [String]
    var classes: [DanceClass]
    var students: Int?
    var countLabel: DancerCountLabel

    init(_ crew: DanceGroup) {
        type = crew.type; competitions = crew.competitions; teaches = crew.teaches; classes = crew.classes
        students = crew.students; countLabel = crew.countLabel
        id = crew.id; name = crew.name; dancerCount = crew.dancerCount; logoFileName = crew.logoFileName
        accentHex = crew.accentHex; summary = crew.summary; styles = crew.styles
        headChoreographer = crew.headChoreographer; formedDate = crew.formedDate
        worksWithGroups = crew.worksWithGroups; worksWithUnits = crew.worksWithUnits; notes = crew.notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        // Saved before types existed: Dance Media is the academy, everything else a performance team.
        type = try c.decodeIfPresent(DanceGroupType.self, forKey: .type)
            ?? (name.lowercased() == "dance media" ? .academy : .performanceTeam)
        dancerCount = max(0, try c.decodeIfPresent(Int.self, forKey: .dancerCount) ?? 0)
        logoFileName = try c.decodeIfPresent(String.self, forKey: .logoFileName)
        accentHex = try c.decodeIfPresent(String.self, forKey: .accentHex) ?? "#E50914"
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        styles = try c.decodeIfPresent([String].self, forKey: .styles) ?? []
        headChoreographer = try c.decodeIfPresent(String.self, forKey: .headChoreographer) ?? ""
        formedDate = try c.decodeIfPresent(Date.self, forKey: .formedDate)
        worksWithGroups = try c.decodeIfPresent([UUID].self, forKey: .worksWithGroups) ?? []
        worksWithUnits = try c.decodeIfPresent([UUID].self, forKey: .worksWithUnits) ?? []
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        competitions = try c.decodeIfPresent([Competition].self, forKey: .competitions) ?? []
        teaches = try c.decodeIfPresent([String].self, forKey: .teaches) ?? []
        classes = try c.decodeIfPresent([DanceClass].self, forKey: .classes) ?? []
        students = try c.decodeIfPresent(Int.self, forKey: .students).map { max(0, $0) }
        countLabel = try c.decodeIfPresent(DancerCountLabel.self, forKey: .countLabel) ?? .dancers
    }

    func makeDanceGroup() -> DanceGroup {
        DanceGroup(id: id, name: name, type: type, dancerCount: dancerCount, logoFileName: logoFileName, accentHex: accentHex,
                   summary: summary, styles: styles, headChoreographer: headChoreographer, formedDate: formedDate,
                   worksWithGroups: worksWithGroups, worksWithUnits: worksWithUnits, notes: notes,
                   competitions: competitions, teaches: teaches, classes: classes, students: students,
                   countLabel: countLabel)
    }
}

struct GroupRecord: Codable {
    var id: UUID
    var name: String
    var concept: String
    var fandomName: String
    var debutDate: Date?
    var members: [MemberRecord]
    var subUnits: [SubUnit]
    var awards: Int
    var themeColors: [String]
    var liveStatus: GroupStatus?
    var bannerTag: String = ""

    init(id: UUID, name: String, concept: String, fandomName: String, debutDate: Date?,
         members: [MemberRecord], subUnits: [SubUnit], awards: Int, themeColors: [String],
         liveStatus: GroupStatus? = nil) {
        self.id = id
        self.name = name
        self.concept = concept
        self.fandomName = fandomName
        self.debutDate = debutDate
        self.members = members
        self.subUnits = subUnits
        self.awards = awards
        self.themeColors = themeColors
        self.liveStatus = liveStatus
    }

    /// `fandomName` and `awards` were added later, so files saved before them still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        concept = try c.decode(String.self, forKey: .concept)
        fandomName = try c.decodeIfPresent(String.self, forKey: .fandomName) ?? ""
        debutDate = try c.decodeIfPresent(Date.self, forKey: .debutDate)
        members = try c.decode([MemberRecord].self, forKey: .members)
        subUnits = try c.decode([SubUnit].self, forKey: .subUnits)
        awards = max(0, try c.decodeIfPresent(Int.self, forKey: .awards) ?? 0)
        themeColors = try c.decode([String].self, forKey: .themeColors)
        liveStatus = try c.decodeIfPresent(GroupStatus.self, forKey: .liveStatus)
        bannerTag = try c.decodeIfPresent(String.self, forKey: .bannerTag) ?? ""
    }
}

struct MemberRecord: Codable {
    var id: UUID
    var stageName: String
    var realName: String
    var age: Int?
    var birthday: Date?
    var roles: [MemberRole]
    var personality: Personality
    /// Old one-way format; only read from older files, converted on load, never written.
    var relationships: [MemberRelationship]?
    var relationshipStatus: RelationshipStatusLine?
    var colorAccent: String
    var avatarSymbol: String
    var photoFileName: String?
}

extension CompanyRecord {
    init(_ company: Company) {
        let memberIDs = Set(company.allMembers.map(\.id))
        self.init(
            name: company.name, ceoName: company.ceoName, groups: company.groups.map(GroupRecord.init),
            // Relationships pointing at deleted members are dropped here.
            relationships: company.relationships.filter { memberIDs.contains($0.memberA) && memberIDs.contains($0.memberB) },
            customRelationshipTypes: company.customRelationshipTypes,
            chadder: company.chadder
        )
        statusLog = company.statusLog
        danceGroups = company.danceGroups.map(DanceGroupRecord.init)
        studioDescription = company.studioDescription
    }

    func makeCompany() -> Company {
        let company = Company(name: name, ceoName: ceoName, groups: groups.map { $0.makeGroup() },
                              relationships: relationships + legacyRelationships(),
                              customRelationshipTypes: customRelationshipTypes, chadder: chadder)
        company.statusLog = Array(statusLog.prefix(Company.statusLogLimit))
        company.danceGroups = danceGroups.map { $0.map { $0.makeDanceGroup() } } ?? DanceGroup.starters
        company.studioDescription = studioDescription
        return company
    }

    /// Converts old per-member, one-way relationships into shared two-way ones (once per pair and type).
    private func legacyRelationships() -> [Relationship] {
        var converted: [Relationship] = []
        func exists(_ a: UUID, _ b: UUID, _ type: RelationshipType) -> Bool {
            (relationships + converted).contains { $0.connects(a, b) && $0.type == type }
        }
        for group in groups {
            for member in group.members {
                for old in member.relationships ?? [] {
                    var a = member.id, b = old.memberID
                    var note = old.note
                    let type: BuiltInRelationshipType
                    switch old.kind {
                    case .bestFriend: type = .bestFriend
                    case .roommate: type = .roommate
                    case .rival: type = .friendlyRival
                    case .duo: type = .duoPartner
                    case .traineeFriend:
                        type = .friend
                        if note.isEmpty { note = "Trainee-era friend" }
                    case .mentor: type = .mentorMentee                 // this member is the mentor
                    case .mentee: type = .mentorMentee; swap(&a, &b)   // the other person is the mentor
                    }
                    guard !exists(a, b, .builtIn(type)) else { continue }
                    converted.append(Relationship(memberA: a, memberB: b, type: .builtIn(type), note: note))
                }
            }
        }
        return converted
    }
}

extension GroupRecord {
    init(_ group: IdolGroup) {
        self.init(id: group.id, name: group.name, concept: group.concept, fandomName: group.fandomName,
                  debutDate: group.debutDate,
                  members: group.members.map(MemberRecord.init), subUnits: group.subUnits, awards: group.awards,
                  themeColors: group.themeColors, liveStatus: group.liveStatus)
        bannerTag = group.bannerTag
    }

    func makeGroup() -> IdolGroup {
        let group = IdolGroup(id: id, name: name, concept: concept, fandomName: fandomName, debutDate: debutDate,
                              members: members.map { $0.makeMember() }, subUnits: subUnits, awards: awards,
                              themeColors: themeColors)
        group.liveStatus = liveStatus
        group.bannerTag = bannerTag
        return group
    }
}

extension MemberRecord {
    init(_ member: IdolMember) {
        self.init(id: member.id, stageName: member.stageName, realName: member.realName,
                  age: member.age, birthday: member.birthday, roles: member.roles,
                  personality: member.personality, relationships: nil, relationshipStatus: member.relationshipStatus,
                  colorAccent: member.colorAccent, avatarSymbol: member.avatarSymbol,
                  photoFileName: member.photoFileName)
    }

    func makeMember() -> IdolMember {
        IdolMember(id: id, stageName: stageName, realName: realName, age: age, birthday: birthday,
                   roles: roles, personality: personality,
                   relationshipStatus: relationshipStatus, colorAccent: colorAccent, avatarSymbol: avatarSymbol,
                   photoFileName: photoFileName)
    }
}

// MARK: - Store

/// Reads and writes the company as JSON in
/// ~/Library/Application Support/Idol Studio/company.json
struct CompanyStore {
    let fileURL: URL?

    /// Pass `nil` for an in-memory store (previews).
    init(fileURL: URL? = CompanyStore.defaultURL) {
        self.fileURL = fileURL
    }

    static var defaultURL: URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        return support.appendingPathComponent("Idol Studio", isDirectory: true)
            .appendingPathComponent("company.json")
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Returns nil when there is no saved file yet. An unreadable file is moved
    /// aside (never overwritten) so the data can still be recovered by hand.
    func load() -> Company? {
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(CompanyRecord.self, from: data).makeCompany()
        } catch {
            let stamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
            let backup = fileURL.deletingLastPathComponent().appendingPathComponent("company-unreadable-\(stamp).json")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            NSLog("Idol Studio: couldn't read saved data (\(error)). Moved it to \(backup.path).")
            return nil
        }
    }

    func save(_ record: CompanyRecord) {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoder.encode(record).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Idol Studio: save failed: \(error)")
        }
    }
}
