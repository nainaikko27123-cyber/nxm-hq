import Foundation

private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
}

extension Company {
    /// Fictional company the app launches with.
    static var sample: Company {
        let lumina = IdolGroup.lumina, hexa = IdolGroup.hexa
        let l = lumina.members, h = hexa.members
        let company = Company(
            name: "NXM Entertainment",
            ceoName: "Max",
            groups: [lumina, hexa],
            relationships: [
                Relationship(memberA: l[0].id, memberB: l[3].id, type: .builtIn(.roommate), note: "Shared a dorm room since trainee days"),
                Relationship(memberA: l[0].id, memberB: l[4].id, type: .builtIn(.mentorMentee), note: "Coaches her vocals before every comeback"),
                Relationship(memberA: l[1].id, memberB: l[2].id, type: .builtIn(.friendlyRival), note: "Always competing in dance challenges"),
                Relationship(memberA: h[1].id, memberB: h[3].id, type: .builtIn(.duoPartner), note: "Vocal line duo on every B-side"),
            ]
        )
        company.danceGroups = DanceGroup.starters
        return company
    }
}

extension IdolGroup {
    static var lumina: IdolGroup {
        let yuna = IdolMember(
            stageName: "Yuna", realName: "Kang Yu-na",
            roles: [.leader, .mainVocal],
            personality: Personality(mbti: "INFJ", traits: ["Calm", "Protective", "Perfectionist"]),
            colorAccent: "#C792EA", avatarSymbol: "moon.stars.fill")
        let seori = IdolMember(
            stageName: "Seori", realName: "Park Seo-rin",
            roles: [.mainDancer, .center],
            personality: Personality(mbti: "ESFP", traits: ["Energetic", "Playful", "Fearless"]),
            colorAccent: "#FF8FB1", avatarSymbol: "sparkles")
        let hana = IdolMember(
            stageName: "Hana", realName: "Lee Ha-na",
            roles: [.mainRapper, .leadDancer],
            personality: Personality(mbti: "ENTP", traits: ["Witty", "Bold", "Quick-thinking"]),
            colorAccent: "#7FDBFF", avatarSymbol: "bolt.heart.fill")
        let mirae = IdolMember(
            stageName: "Mirae", realName: "Choi Mi-rae",
            roles: [.leadVocal, .visual],
            personality: Personality(mbti: "ISFJ", traits: ["Gentle", "Thoughtful", "Reliable"]),
            colorAccent: "#FFD27F", avatarSymbol: "sun.max.fill")
        let ari = IdolMember(
            stageName: "Ari", realName: "Jung A-ri",
            roles: [.maknae, .subVocal],
            personality: Personality(mbti: "ENFP", traits: ["Curious", "Bubbly", "Creative"]),
            colorAccent: "#9CF0C4", avatarSymbol: "leaf.fill")


        return IdolGroup(
            name: "LUMINA",
            concept: "Celestial dream-pop with soft synths and starlit visuals",
            fandomName: "Lumies",
            debutDate: date(2023, 4, 12),
            members: [yuna, seori, hana, mirae, ari],
            subUnits: [
                SubUnit(name: "LUMINA Moon", memberIDs: [yuna.id, mirae.id]),
                SubUnit(name: "LUMINA Flare", memberIDs: [seori.id, hana.id, ari.id]),
            ],
            themeColors: ["#FF4D4D", "#E50914"]
        )
    }

    static var hexa: IdolGroup {
        let jin = IdolMember(
            stageName: "Jin", realName: "Seo Jin-ho",
            roles: [.leader, .mainRapper],
            personality: Personality(mbti: "ENTJ", traits: ["Driven", "Decisive", "Loyal"]),
            colorAccent: "#00E0FF", avatarSymbol: "flame.fill")
        let taeo = IdolMember(
            stageName: "Taeo", realName: "Kim Tae-o",
            roles: [.mainVocal],
            personality: Personality(mbti: "INFP", traits: ["Sensitive", "Creative", "Dreamy"]),
            colorAccent: "#5B8CFF", avatarSymbol: "music.note")
        let rio = IdolMember(
            stageName: "Rio", realName: "Han Ri-on",
            roles: [.mainDancer, .center],
            personality: Personality(mbti: "ESTP", traits: ["Fearless", "Competitive", "Charismatic"]),
            colorAccent: "#FF5E5E", avatarSymbol: "figure.dance")
        let kai = IdolMember(
            stageName: "Kai", realName: "Yoon Kai",
            roles: [.visual, .leadVocal],
            personality: Personality(mbti: "ISTP", traits: ["Cool", "Quiet", "Observant"]),
            colorAccent: "#B0B7C3", avatarSymbol: "moon.fill")
        let dami = IdolMember(
            stageName: "Dami", realName: "Lim Da-min",
            roles: [.maknae, .leadRapper],
            personality: Personality(mbti: "ESFJ", traits: ["Cheerful", "Caring", "Chatty"]),
            colorAccent: "#FFB86B", avatarSymbol: "star.fill")


        return IdolGroup(
            name: "HEXA",
            concept: "Neon cyberpunk hip-hop with hard-hitting beats and futuristic styling",
            fandomName: "Hexagons",
            debutDate: date(2024, 9, 3),
            members: [jin, taeo, rio, kai, dami],
            subUnits: [
                SubUnit(name: "HEXA Code", memberIDs: [jin.id, rio.id, dami.id]),
                SubUnit(name: "HEXA Echo", memberIDs: [taeo.id, kai.id]),
            ],
            themeColors: ["#B00020", "#2A2A2A"]
        )
    }
}
