import AppKit

// MARK: - Saved data

enum ChadderFrequency: String, Codable, CaseIterable, Identifiable {
    case chill = "Chill", normal = "Normal", chatty = "Chatty"
    var id: String { rawValue }

    /// Seconds between bubbles.
    var interval: ClosedRange<Double> {
        switch self {
        case .chill: 120...240
        case .normal: 45...90
        case .chatty: 20...40
        }
    }

    var summary: String {
        switch self {
        case .chill: "every 2–4 minutes"
        case .normal: "every 45–90 seconds"
        case .chatty: "every 20–40 seconds"
        }
    }
}

struct ChadderLine: Identifiable, Codable, Hashable {
    var id = UUID()
    var text: String
    var isQuestion: Bool
}

struct ChadderSettings: Codable, Hashable {
    var enabled = true
    var frequency: ChadderFrequency = .normal
    var customLines: [ChadderLine] = []

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        frequency = try c.decodeIfPresent(ChadderFrequency.self, forKey: .frequency) ?? .normal
        customLines = try c.decodeIfPresent([ChadderLine].self, forKey: .customLines) ?? []
    }
}

struct SurveyAnswer: Identifiable, Codable, Hashable {
    var id = UUID()
    var question: String
    var answer: String
    var date: Date
}

/// Everything Chadder remembers, saved in company.json under "chadder".
struct ChadderData: Codable, Hashable {
    var settings = ChadderSettings()
    var answers: [SurveyAnswer] = []
    /// Skipped questions aren't asked again until this date.
    var skippedUntil: [String: Date] = [:]
    /// Last time the app was used, for the "you're back" greeting.
    var lastActive: Date?

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        settings = try c.decodeIfPresent(ChadderSettings.self, forKey: .settings) ?? ChadderSettings()
        answers = try c.decodeIfPresent([SurveyAnswer].self, forKey: .answers) ?? []
        skippedUntil = try c.decodeIfPresent([String: Date].self, forKey: .skippedUntil) ?? [:]
        lastActive = try c.decodeIfPresent(Date.self, forKey: .lastActive)
    }
}

// MARK: - What Chadder says

struct ChadderSay: Equatable {
    var text: String
    var isQuestion: Bool
}

enum ChadderBrain {
    static let skipDays = 3.0
    static let welcomeBackAfterDays = 3.0
    static let welcomeBack = ChadderSay(text: "Oh, you're back! Souls missed you.", isQuestion: false)
    static let easterEgg = ChadderSay(text: "Stupid Cheese Cat? I prefer Chief Morale Officer.", isQuestion: false)

    static let questions = [
        "Who is your bias?",
        "What's your fav song?",
        "What's your fav album?",
        "When did you become a stan?",
        "Who is your bias wrecker?",
        "Which era is your favorite?",
        "What was the first NXM song you ever heard?",
        "Who do you want to see a duo stage with?",
        "Which member made you laugh the most this week?",
        "Which group is better at choreography? Be honest.",
    ]

    static func reminders(_ company: Company) -> [String] {
        var lines = [
            "Don't forget to stream.",
            "Have you voted today?",
            "Did you drink water? Idols stay hydrated.",
            "Souls never skip the music video.",
            "Meow. (This is a company-approved statement.)",
        ]
        let ceo = company.ceoName.trimmingCharacters(in: .whitespaces)
        lines.append("\(ceo.isEmpty ? "Max" : ceo) says good work.")
        return lines
    }

    /// Lines built from the real data. Anything with an empty field is left out.
    static func smartLines(_ company: Company, now: Date = .now) -> [String] {
        var lines: [String] = []
        let named = company.allMembers.filter { !$0.stageName.trimmingCharacters(in: .whitespaces).isEmpty }
        if let member = named.randomElement() {
            lines.append("Have you watched \(member.stageName)'s latest stage?")
        }
        if let group = company.groups.filter({ $0.awards > 0 && !$0.name.isEmpty }).randomElement() {
            lines.append("\(group.name) has \(group.awards) \(group.awards == 1 ? "award" : "awards"). Let's get more!")
        }
        if let group = company.groups.filter({ !$0.fandomName.isEmpty && !$0.name.isEmpty }).randomElement() {
            lines.append("\(group.fandomName), have you supported \(group.name) today?")
        }
        for member in named {
            guard let days = daysUntilBirthday(member, now: now), days <= 14 else { continue }
            lines.append(days == 0 ? "It's \(member.stageName)'s birthday today!" : "It's \(member.stageName)'s birthday soon!")
        }
        let couples = company.relationships.filter { $0.type == .builtIn(.couple) && $0.status == .current }
        if let couple = couples.randomElement(),
           let a = company.member(withID: couple.memberA), let b = company.member(withID: couple.memberB) {
            lines.append("\(a.stageName) and \(b.stageName) are such a good couple.")
        }
        return lines
    }

    static func daysUntilBirthday(_ member: IdolMember, now: Date) -> Int? {
        guard let birthday = member.birthday else { return nil }
        let calendar = Calendar.current
        let parts = calendar.dateComponents([.month, .day], from: birthday)
        let today = calendar.startOfDay(for: now)
        guard let next = calendar.nextDate(after: today.addingTimeInterval(-1), matching: parts, matchingPolicy: .nextTime) else { return nil }
        return calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: next)).day
    }

    static func pool(_ company: Company, now: Date = .now) -> [ChadderSay] {
        let data = company.chadder
        func available(_ question: String) -> Bool { (data.skippedUntil[question] ?? .distantPast) <= now }
        var pool = questions.filter(available).map { ChadderSay(text: $0, isQuestion: true) }
        pool += reminders(company).map { ChadderSay(text: $0, isQuestion: false) }
        pool += smartLines(company, now: now).map { ChadderSay(text: $0, isQuestion: false) }
        pool += data.settings.customLines
            .map { ChadderLine(id: $0.id, text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines), isQuestion: $0.isQuestion) }
            .filter { !$0.text.isEmpty && (!$0.isQuestion || available($0.text)) }
            .map { ChadderSay(text: $0.text, isQuestion: $0.isQuestion) }
        return pool
    }

    /// A random line that isn't the same as the last one.
    static func next(_ company: Company, after last: String?) -> ChadderSay? {
        let all = pool(company)
        return all.filter { $0.text != last }.randomElement() ?? all.randomElement()
    }

    // MARK: Typing detection

    /// Time of the last key press anywhere in the app (also used to ask before discarding typed text).
    private(set) static var lastKeyDown = Date.distantPast
    private static var monitor: Any?

    static func startWatchingKeys() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            lastKeyDown = Date()
            return event
        }
    }

    /// True while a text field or editor has focus and a key was pressed in the last few seconds.
    static var userIsTyping: Bool {
        guard let responder = NSApp.keyWindow?.firstResponder, responder is NSText else { return false }
        return Date().timeIntervalSince(lastKeyDown) < 6
    }
}
