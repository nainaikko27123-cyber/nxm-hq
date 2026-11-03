import Foundation
import Observation

/// Positions a member can hold. A member usually has more than one.
enum MemberRole: String, CaseIterable, Identifiable, Codable, Hashable {
    case leader = "Leader"
    case mainVocal = "Main Vocalist"
    case leadVocal = "Lead Vocalist"
    case subVocal = "Sub Vocalist"
    case vocalist = "Vocalist"
    case mainDancer = "Main Dancer"
    case leadDancer = "Lead Dancer"
    case mainRapper = "Main Rapper"
    case leadRapper = "Lead Rapper"
    case producer = "Producer"
    case visual = "Visual"
    case center = "Center"
    case maknae = "Maknae"

    var id: String { rawValue }

    /// Accepts the older "Main Vocal"-style names so earlier save files still load.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        let legacy = ["Main Vocal": "Main Vocalist", "Lead Vocal": "Lead Vocalist", "Sub Vocal": "Sub Vocalist"]
        guard let role = MemberRole(rawValue: legacy[raw] ?? raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown role \(raw)")
        }
        self = role
    }
}

struct Personality: Hashable, Codable {
    /// Empty string means "not added yet".
    var mbti: String
    var traits: [String]
    /// Free-text personality description. Empty means "not added yet".
    var summary: String = ""

    init(mbti: String = "", traits: [String] = [], summary: String = "") {
        self.mbti = mbti
        self.traits = traits
        self.summary = summary
    }

    /// `summary` was added later, so older save files without it still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mbti = try c.decodeIfPresent(String.self, forKey: .mbti) ?? ""
        traits = try c.decodeIfPresent([String].self, forKey: .traits) ?? []
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
    }

    static let mbtiTypes = [
        "INTJ", "INTP", "ENTJ", "ENTP",
        "INFJ", "INFP", "ENFJ", "ENFP",
        "ISTJ", "ISFJ", "ESTJ", "ESFJ",
        "ISTP", "ISFP", "ESTP", "ESFP",
    ]
}

/// Old one-way relationship format, kept only so older save files can be converted.
enum RelationshipKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case bestFriend = "Best Friend"
    case roommate = "Roommate"
    case rival = "Friendly Rival"
    case mentor = "Mentor"
    case mentee = "Mentee"
    case duo = "Duo Partner"
    case traineeFriend = "Trainee-Era Friend"

    var id: String { rawValue }
}

/// A link from one member to another member of the same group.
/// Old one-way relationship format, kept only so older save files can be converted.
struct MemberRelationship: Identifiable, Hashable, Codable {
    var id = UUID()
    var memberID: UUID
    var kind: RelationshipKind
    var note: String
}

@Observable
final class IdolMember: Identifiable {
    let id: UUID
    var stageName: String
    var realName: String
    var age: Int?
    var birthday: Date?
    var roles: [MemberRole]
    var personality: Personality
    /// Optional status line; a current Couple relationship fills in the partner automatically.
    var relationshipStatus: RelationshipStatusLine?
    /// Hex string such as "#FF8FB1".
    var colorAccent: String
    /// SF Symbol name used as the member's avatar. Empty means "show the first letter of the stage name".
    var avatarSymbol: String
    /// File name of the member's photo in the app's photos folder. Nil = no photo (letter/icon avatar is shown).
    var photoFileName: String?

    init(
        id: UUID = UUID(),
        stageName: String,
        realName: String,
        age: Int? = nil,
        birthday: Date? = nil,
        roles: [MemberRole],
        personality: Personality,
        relationshipStatus: RelationshipStatusLine? = nil,
        colorAccent: String,
        avatarSymbol: String,
        photoFileName: String? = nil
    ) {
        self.id = id
        self.stageName = stageName
        self.realName = realName
        self.age = age
        self.birthday = birthday
        self.roles = roles
        self.personality = personality
        self.relationshipStatus = relationshipStatus
        self.colorAccent = colorAccent
        self.avatarSymbol = avatarSymbol
        self.photoFileName = photoFileName
    }

    var primaryRole: String { roles.first?.rawValue ?? "Member" }

    var initial: String {
        stageName.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "?"
    }

    /// Age worked out from the birthday when there is one, otherwise the age typed in by hand.
    var displayAge: Int? {
        guard let birthday else { return age }
        return Calendar.current.dateComponents([.year], from: birthday, to: .now).year
    }


    static let avatarSymbols = [
        "star.fill", "sparkles", "moon.stars.fill", "sun.max.fill", "bolt.heart.fill",
        "heart.fill", "flame.fill", "leaf.fill", "music.note", "music.mic",
        "crown.fill", "moon.fill", "cloud.fill", "snowflake", "drop.fill",
        "wand.and.stars", "headphones", "figure.dance", "camera.fill", "bolt.fill",
    ]
}
