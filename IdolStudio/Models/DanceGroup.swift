import Foundation
import Observation

enum DanceGroupType: String, Codable, CaseIterable, Identifiable {
    case performanceTeam = "Performance Team"
    case academy = "Academy"
    var id: String { rawValue }
    var symbol: String { self == .performanceTeam ? "figure.dance" : "graduationcap.fill" }
    /// Short form for tight spots like the sidebar.
    var shortName: String { self == .performanceTeam ? "Team" : "Academy" }
    /// What the lead person is called on this type of crew.
    var leadTitle: String { self == .performanceTeam ? "Head choreographer" : "Head instructor" }
}

enum CompetitionResult: String, Codable, CaseIterable, Identifiable {
    case winner = "Winner", first = "1st", second = "2nd", third = "3rd", finalist = "Finalist", participated = "Participated"
    var id: String { rawValue }
    /// Winner and 1st place count as wins.
    var isWin: Bool { self == .winner || self == .first }
}

struct Competition: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    /// Exact day it happened. When set, it wins over `year`.
    var date: Date?
    /// Used when only the year is known (or for entries saved before dates existed).
    var year: Int?
    var result: CompetitionResult = .participated
    var category: String = ""
    var location: String = ""
    var note: String = ""

    init(id: UUID = UUID(), name: String, date: Date? = nil, year: Int? = nil, result: CompetitionResult = .participated,
         category: String = "", location: String = "", note: String = "") {
        self.id = id; self.name = name; self.date = date; self.year = year; self.result = result
        self.category = category; self.location = location; self.note = note
    }

    /// Older entries have no date or location; they load unchanged.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        date = try c.decodeIfPresent(Date.self, forKey: .date)
        year = try c.decodeIfPresent(Int.self, forKey: .year)
        result = try c.decodeIfPresent(CompetitionResult.self, forKey: .result) ?? .participated
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        location = try c.decodeIfPresent(String.self, forKey: .location) ?? ""
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    /// "15 Nov 2026", "2026", or nil when the date is unknown.
    var dateText: String? {
        if let date { return Self.dayFormatter.string(from: date) }
        if let year { return String(year) }
        return nil
    }

    /// For newest-first sorting. Year-only entries count as the start of that year; unknown dates sort last.
    var sortDate: Date? {
        if let date { return date }
        if let year { return Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1)) }
        return nil
    }
}

extension Array where Element == Competition {
    /// Newest first, entries without a date at the bottom.
    var newestFirst: [Competition] {
        sorted { a, b in
            switch (a.sortDate, b.sortDate) {
            case let (x?, y?): return x > y
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        }
    }
}

struct DanceClass: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var details: String = ""
}

/// Academies can call their count "Dancers" or "Instructors".
enum DancerCountLabel: String, Codable, CaseIterable, Identifiable {
    case dancers = "Dancers", instructors = "Instructors"
    var id: String { rawValue }
}

/// A dance crew from NXM's dance studio. One card per crew with a dancer count; no individual dancer profiles.
@Observable
final class DanceGroup: Identifiable {
    static let maxDancers = 9999
    static let suggestedStyles = ["Hip-hop", "Contemporary", "Popping", "Locking", "Waacking", "Choreography",
                                  "Krump", "House", "Breaking", "Jazz", "Voguing", "K-pop"]
    static let suggestedAudiences = ["Kids", "Teens", "Adults", "Beginners", "Advanced"]
    static let maxStudents = 99_999

    let id: UUID
    var name: String
    var type: DanceGroupType
    /// Only changed through `setDancerCount(_:)` so it can never go below 0.
    private(set) var dancerCount: Int
    /// Logo/photo in the app's photos folder. Nil = letter circle in the accent color.
    var logoFileName: String?
    var accentHex: String
    var summary: String
    var styles: [String]
    /// Just a name, not a profile.
    var headChoreographer: String
    var formedDate: Date?
    /// Performance teams: idol groups they back up ("Backs up"). Kept (hidden) if the type changes.
    var worksWithGroups: [UUID]
    /// Performance teams: sub-units they back up.
    var worksWithUnits: [UUID]
    var notes: String
    // Performance team
    var competitions: [Competition]
    // Academy
    var teaches: [String]
    var classes: [DanceClass]
    /// Optional, separate from the dancer count. Only changed through `setStudents(_:)`.
    private(set) var students: Int?
    var countLabel: DancerCountLabel

    init(id: UUID = UUID(), name: String, type: DanceGroupType = .performanceTeam, dancerCount: Int = 0, logoFileName: String? = nil,
         accentHex: String = "#E50914", summary: String = "", styles: [String] = [],
         headChoreographer: String = "", formedDate: Date? = nil,
         worksWithGroups: [UUID] = [], worksWithUnits: [UUID] = [], notes: String = "",
         competitions: [Competition] = [], teaches: [String] = [], classes: [DanceClass] = [],
         students: Int? = nil, countLabel: DancerCountLabel = .dancers) {
        self.id = id
        self.name = name
        self.type = type
        self.competitions = competitions
        self.teaches = teaches
        self.classes = classes
        self.students = students.map { min(max(0, $0), Self.maxStudents) }
        self.countLabel = countLabel
        self.dancerCount = min(max(0, dancerCount), Self.maxDancers)
        self.logoFileName = logoFileName
        self.accentHex = accentHex
        self.summary = summary
        self.styles = styles
        self.headChoreographer = headChoreographer
        self.formedDate = formedDate
        self.worksWithGroups = worksWithGroups
        self.worksWithUnits = worksWithUnits
        self.notes = notes
    }

    func setDancerCount(_ count: Int) {
        dancerCount = min(max(0, count), Self.maxDancers)
    }

    func setStudents(_ count: Int?) {
        students = count.map { min(max(0, $0), Self.maxStudents) }
    }

    /// "30 dancers", "25 instructors", "1 dancer". Performance teams always say dancers.
    var countText: String {
        let noun = type == .academy && countLabel == .instructors ? "instructor" : "dancer"
        return "\(dancerCount) \(noun)\(dancerCount == 1 ? "" : "s")"
    }

    var competitionWins: Int { competitions.filter { $0.result.isWin }.count }

    /// "Competitions: 8 entered, 3 wins".
    var competitionSummary: String {
        let wins = competitionWins
        return "Competitions: \(competitions.count) entered, \(wins) \(wins == 1 ? "win" : "wins")"
    }

    @discardableResult
    func addAudience(_ tag: String) -> Bool {
        let clean = tag.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty, !teaches.contains(where: { $0.lowercased() == clean.lowercased() }) else { return false }
        teaches.append(clean)
        return true
    }

    var initial: String {
        name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "?"
    }

    /// Adds a style unless it's empty or already there (ignoring case). Returns whether it was added.
    @discardableResult
    func addStyle(_ style: String) -> Bool {
        let clean = style.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty, !styles.contains(where: { $0.lowercased() == clean.lowercased() }) else { return false }
        styles.append(clean)
        return true
    }

    func removeStyle(_ style: String) {
        styles.removeAll { $0 == style }
    }

    /// The two starting crews.
    static var starters: [DanceGroup] {
        [DanceGroup(name: "1M", type: .performanceTeam, dancerCount: 30, accentHex: "#E50914"),
         DanceGroup(name: "Dance Media", type: .academy, dancerCount: 25, accentHex: "#F2F2F2")]
    }
}

extension Company {
    var totalDancers: Int { danceGroups.reduce(0) { $0 + $1.dancerCount } }

    /// Unique styles across all crews (case doesn't matter).
    var uniqueStyleCount: Int {
        Set(danceGroups.flatMap { $0.styles.map { $0.trimmingCharacters(in: .whitespaces).lowercased() } }).count
    }

    func danceGroup(withID id: UUID) -> DanceGroup? {
        danceGroups.first { $0.id == id }
    }

    func addDanceGroup(_ crew: DanceGroup) {
        danceGroups.append(crew)
    }

    func removeDanceGroup(id: UUID) {
        if let crew = danceGroup(withID: id) { PhotoStore.delete(crew.logoFileName) }
        danceGroups.removeAll { $0.id == id }
    }

    /// Performance teams that back up this idol group or any of its sub-units ("Backed by 1M").
    func danceGroups(workingWith group: IdolGroup) -> [DanceGroup] {
        let unitIDs = Set(group.subUnits.map(\.id))
        return danceGroups.filter {
            $0.type == .performanceTeam
                && ($0.worksWithGroups.contains(group.id) || !unitIDs.isDisjoint(with: $0.worksWithUnits))
        }
    }

    var totalCompetitionWins: Int {
        danceGroups.filter { $0.type == .performanceTeam }.reduce(0) { $0 + $1.competitionWins }
    }

    /// Students across academies; nil when no academy has a number filled in.
    var totalStudents: Int? {
        let filled = danceGroups.filter { $0.type == .academy }.compactMap(\.students)
        return filled.isEmpty ? nil : filled.reduce(0, +)
    }

    /// Names for a crew's "Works with" chips: groups first, then units as "Unit (Group)".
    func worksWithItems(for crew: DanceGroup) -> [(id: UUID, name: String, groupID: UUID)] {
        var items: [(UUID, String, UUID)] = []
        for group in groups where crew.worksWithGroups.contains(group.id) {
            items.append((group.id, group.name, group.id))
        }
        for group in groups {
            for unit in group.subUnits where crew.worksWithUnits.contains(unit.id) {
                items.append((unit.id, "\(unit.name) (\(group.name))", group.id))
            }
        }
        return items
    }

    /// "Backs up NG and MONSTER X".
    func worksWithSentence(for crew: DanceGroup) -> String? {
        let names = worksWithItems(for: crew).map(\.name)
        guard !names.isEmpty else { return nil }
        let list = names.count == 1 ? names[0]
            : names.dropLast().joined(separator: ", ") + " and " + names.last!
        return "Backs up \(list)"
    }
}
