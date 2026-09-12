//
//  HallOfFame.swift
//  DnDTextRPG
//
//  Hall of Fame entries for completed dungeon runs
//

import Foundation

// MARK: - Hall of Fame Entry

enum RunOutcome: String, Codable {
    case victory
    case defeat
}

struct HallOfFameEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let partyNames: [String]
    let partyDescription: String
    let dungeonName: String
    let dungeonLevel: Int
    let outcome: RunOutcome
    let goldCollected: Int
    let monstersSlain: Int
    let combatsWon: Int
    let roomsExplored: Int
    let totalRooms: Int
    let gameTimeMinutes: Int
    var saveGameId: UUID?  // Linked save game (for "relive this adventure")

    /// Composite score: victory bonus + gold + kills + exploration + difficulty
    var score: Int {
        let victoryBonus = outcome == .victory ? 500 : 0
        let difficultyMultiplier = dungeonLevel
        let explorationBonus = totalRooms > 0 ? (roomsExplored * 100 / totalRooms) : 0
        return (victoryBonus + goldCollected + monstersSlain * 20 + combatsWon * 50 + explorationBonus) * difficultyMultiplier
    }

    init(id: UUID = UUID(), date: Date, partyNames: [String], partyDescription: String,
         dungeonName: String, dungeonLevel: Int, outcome: RunOutcome,
         goldCollected: Int, monstersSlain: Int, combatsWon: Int,
         roomsExplored: Int, totalRooms: Int, gameTimeMinutes: Int,
         saveGameId: UUID? = nil) {
        self.id = id
        self.date = date
        self.partyNames = partyNames
        self.partyDescription = partyDescription
        self.dungeonName = dungeonName
        self.dungeonLevel = dungeonLevel
        self.outcome = outcome
        self.goldCollected = goldCollected
        self.monstersSlain = monstersSlain
        self.combatsWon = combatsWon
        self.roomsExplored = roomsExplored
        self.totalRooms = totalRooms
        self.gameTimeMinutes = gameTimeMinutes
        self.saveGameId = saveGameId
    }

    // Decode older entries that don't have saveGameId
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        partyNames = try c.decode([String].self, forKey: .partyNames)
        partyDescription = try c.decode(String.self, forKey: .partyDescription)
        dungeonName = try c.decode(String.self, forKey: .dungeonName)
        dungeonLevel = try c.decode(Int.self, forKey: .dungeonLevel)
        outcome = try c.decode(RunOutcome.self, forKey: .outcome)
        goldCollected = try c.decode(Int.self, forKey: .goldCollected)
        monstersSlain = try c.decode(Int.self, forKey: .monstersSlain)
        combatsWon = try c.decode(Int.self, forKey: .combatsWon)
        roomsExplored = try c.decode(Int.self, forKey: .roomsExplored)
        totalRooms = try c.decode(Int.self, forKey: .totalRooms)
        gameTimeMinutes = try c.decode(Int.self, forKey: .gameTimeMinutes)
        saveGameId = try c.decodeIfPresent(UUID.self, forKey: .saveGameId)
    }
}

// MARK: - Hall of Fame Manager

class HallOfFameManager {
    static let shared = HallOfFameManager()

    private var hallDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("HallOfFame")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func listEntries() -> [HallOfFameEntry] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: hallDirectory,
            includingPropertiesForKeys: nil
        ) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> HallOfFameEntry? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(HallOfFameEntry.self, from: data)
            }
            .sorted { $0.score > $1.score }
    }

    func addEntry(_ entry: HallOfFameEntry) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(entry) else { return }
        let fileName = "\(entry.id.uuidString).json"
        let fileURL = hallDirectory.appendingPathComponent(fileName)
        try? data.write(to: fileURL)

        // Enforce top 10 limit — delete lowest-scoring entries
        trimToTop10()
    }

    private func trimToTop10() {
        let entries = listEntries()
        guard entries.count > 10 else { return }

        let toDelete = entries.suffix(from: 10)
        for entry in toDelete {
            let fileName = "\(entry.id.uuidString).json"
            let fileURL = hallDirectory.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Update an existing entry (e.g. to attach a save game)
    func updateEntry(_ entry: HallOfFameEntry) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(entry) else { return }
        let fileName = "\(entry.id.uuidString).json"
        let fileURL = hallDirectory.appendingPathComponent(fileName)
        try? data.write(to: fileURL)
    }

    // MARK: - Stats

    func totalVictories() -> Int {
        listEntries().filter { $0.outcome == .victory }.count
    }

    func totalDefeats() -> Int {
        listEntries().filter { $0.outcome == .defeat }.count
    }

    func bestGold() -> Int {
        listEntries().map { $0.goldCollected }.max() ?? 0
    }

    func mostSlain() -> Int {
        listEntries().map { $0.monstersSlain }.max() ?? 0
    }

    func totalRuns() -> Int {
        listEntries().count
    }

    // MARK: - Seed Data (diverse sources — books, films, cartoons, games)

    /// Seed entry definition for building HoF entries with linked saves
    private struct SeedDef {
        let daysAgo: Int
        let names: [String]
        let members: [(String, CharacterClass, Race)]
        let dungeon: String
        let level: Int
        let outcome: RunOutcome
        let gold: Int
        let slain: Int
        let combats: Int
        let explored: Int
        let total: Int
        let minutes: Int
    }

    // MARK: - Repair Orphan Entries (no linked save, or the save no longer exists)

    /// Every entry should be loadable/continuable from Continue Adventure
    /// (see GameEngine.showLoadGameMenu) — without this, an entry that
    /// predates the saveGameId link (everything from before 2026-09-08,
    /// which for most players is most or all of their Hall of Fame) shows
    /// as an unloadable "(no save)" dead end forever. Runs once per entry
    /// — one with a valid saveGameId is skipped — so it's cheap to call on
    /// every launch and heals entries the moment they're next seen. This
    /// replaces the old reseedIfNeeded(), which only ever fixed the
    /// pre-seeded demo entries, and only if EVERY entry lacked a save — a
    /// single real entry from actual play (linked automatically since
    /// 2026-09-08) permanently blocked it from ever running again.
    ///
    /// The original dungeon layout from that run is gone — there was never
    /// enough data saved to reconstruct it — so this generates a fresh one
    /// at the same name/level instead. The party is reconstructed member-
    /// by-member from partyDescription ("Name (Class)", comma-separated):
    /// an exact Character Roster name match keeps that character's real
    /// level/gear/gold; anything unmatched (most entries, since the
    /// Roster is newer than the Hall of Fame) gets a freshly built
    /// character of the right name/class instead. Either way, the result
    /// is a real, loadable SaveGame — and since showAdventureTale's
    /// narrative is generated from an entry's own stats (not read back out
    /// of the save itself), every repaired entry gets a proper tale the
    /// same way any other Hall of Fame entry does, regardless of how many
    /// other saves or breakpoints exist elsewhere.
    func repairOrphanEntries() {
        for entry in listEntries() {
            guard entry.saveGameId == nil || SaveGameManager.shared.load(id: entry.saveGameId!) == nil else { continue }
            guard let save = buildRepairSave(for: entry) else { continue }
            try? SaveGameManager.shared.save(save)
            var updated = entry
            updated.saveGameId = save.id
            updateEntry(updated)
        }
    }

    private func buildRepairSave(for entry: HallOfFameEntry) -> SaveGame? {
        let party = buildRepairParty(for: entry)
        guard !party.isEmpty else { return nil }

        let dungeon = Dungeon(name: entry.dungeonName, level: entry.dungeonLevel)
        simulateExploration(dungeon: dungeon, roomsExplored: entry.roomsExplored, isDefeat: entry.outcome == .defeat)

        let partyDesc = party.map { "\($0.name) (\($0.characterClass.rawValue))" }.joined(separator: ", ")
        return SaveGame(
            id: UUID(), slotId: UUID(), savedAt: entry.date,
            slotName: "\(party.first?.name ?? "Hero") — \(entry.dungeonName)",
            partyDescription: partyDesc, dungeonName: entry.dungeonName, dungeonLevel: entry.dungeonLevel,
            party: party, dungeon: dungeon, gameState: .exploring,
            gameTimeMinutes: entry.gameTimeMinutes,
            adventureLog: buildRepairLog(entry),
            dmChatLog: nil, torchLit: true, torchTurnsRemaining: 30,
            partyChatLog: nil,
            monstersSlain: entry.monstersSlain, combatsWon: entry.combatsWon,
            activeQuest: nil
        )
    }

    private func buildRepairParty(for entry: HallOfFameEntry) -> [Character] {
        let members = entry.partyDescription
            .components(separatedBy: ", ")
            .filter { !$0.isEmpty }
        guard !members.isEmpty else { return [] }

        let roster = CharacterLibraryManager.shared.listCharacters()
        let goldEach = entry.goldCollected / max(members.count, 1)

        return members.enumerated().map { (i, member) in
            let name = member.components(separatedBy: " (").first ?? member
            var className = ""
            if let openParen = member.lastIndex(of: "("), let closeParen = member.lastIndex(of: ")"), openParen < closeParen {
                className = String(member[member.index(after: openParen)..<closeParen])
            }
            let charClass = CharacterClass.allCases.first(where: { $0.rawValue == className }) ?? .fighter

            if let record = roster.first(where: { $0.character.name == name }) {
                let character = record.character
                character.prepareForNewAdventure()
                return character
            }

            let race = Race.allCases.randomElement() ?? .human
            let scores = typicalScores(for: charClass)
            let character = Character(name: name, race: race, characterClass: charClass,
                                       abilityScores: scores, isComputerControlled: i > 0)
            character.gold = goldEach

            let equipOptions = ItemCatalog.startingEquipmentOptions(for: charClass)
            if let (_, items) = equipOptions.first {
                for item in items { character.inventory.append(item) }
                if let weapon = character.inventory.first(where: { $0.type == .weapon }) { character.equipWeapon(weapon) }
                if let armor = character.inventory.first(where: { $0.type == .armor }) { character.equipArmor(armor) }
                if let shield = character.inventory.first(where: { $0.type == .shield }) { character.equipShield(shield) }
            }

            if entry.dungeonLevel > 1 {
                character.level = entry.dungeonLevel
                let conMod = scores.modifier(for: .constitution)
                let hpPerLevel = (charClass.startingHP / 2 + 1) + conMod
                character.maxHP += hpPerLevel * (entry.dungeonLevel - 1)
                character.currentHP = character.maxHP
            }

            return character
        }
    }

    /// Same style as buildSeedLog, but reads only this one entry's own
    /// stats — safe to run for any number of entries/save slots without
    /// them influencing each other's description.
    private func buildRepairLog(_ entry: HallOfFameEntry) -> [String] {
        var log: [String] = []
        log.append("The party entered \(entry.dungeonName).")
        if entry.monstersSlain > 0 {
            log.append("Slew \(entry.monstersSlain) creature\(entry.monstersSlain == 1 ? "" : "s") in \(entry.combatsWon) battle\(entry.combatsWon == 1 ? "" : "s").")
        }
        log.append("Explored \(entry.roomsExplored) of \(entry.totalRooms) rooms.")
        if entry.goldCollected > 0 {
            log.append("Collected \(entry.goldCollected) gold pieces.")
        }
        if entry.outcome == .victory {
            log.append("The dungeon boss was defeated!")
        } else {
            log.append("The party fell to the dungeon's horrors...")
        }
        return log
    }

    func seedIfEmpty() {
        guard listEntries().isEmpty else { return }

        let seeds: [SeedDef] = [
            // Robin's Company — folk heroes, the high score to beat
            SeedDef(daysAgo: 2, names: ["Robin of Loxley", "Ged", "Granny Weatherwax"],
                    members: [("Robin of Loxley", .ranger, .human), ("Ged", .wizard, .halfElf), ("Granny Weatherwax", .cleric, .human)],
                    dungeon: "Erewhon", level: 3, outcome: .victory,
                    gold: 420, slain: 18, combats: 7, explored: 12, total: 14, minutes: 1400),
            // 80s Fantasy Legends — classic film heroes
            SeedDef(daysAgo: 5, names: ["Valerian", "Willow", "Hawk", "Beast Master"],
                    members: [("Valerian", .fighter, .human), ("Willow", .wizard, .lightfootHalfling), ("Hawk", .ranger, .halfElf), ("Beast Master", .fighter, .human)],
                    dungeon: "Skull Island", level: 3, outcome: .victory,
                    gold: 380, slain: 16, combats: 6, explored: 11, total: 14, minutes: 1200),
            // Edgin's Heist — Honour Among Thieves
            SeedDef(daysAgo: 8, names: ["Edgin", "Holga", "Xenk"],
                    members: [("Edgin", .rogue, .human), ("Holga", .barbarian, .halfOrc), ("Xenk", .fighter, .human)],
                    dungeon: "Barsoom", level: 3, outcome: .defeat,
                    gold: 280, slain: 14, combats: 5, explored: 8, total: 14, minutes: 1100),
            // Disc World Expedition — Pratchett
            SeedDef(daysAgo: 10, names: ["Rincewind", "DEATH"],
                    members: [("Rincewind", .wizard, .human), ("DEATH", .fighter, .tiefling)],
                    dungeon: "Ankh-Morpork", level: 1, outcome: .victory,
                    gold: 140, slain: 7, combats: 4, explored: 9, total: 10, minutes: 660),
            // Classic Sci-Fi Survivors
            SeedDef(daysAgo: 14, names: ["Ripley", "Atreides", "Snake Plissken"],
                    members: [("Ripley", .ranger, .human), ("Atreides", .wizard, .human), ("Snake Plissken", .rogue, .human)],
                    dungeon: "Trantor", level: 2, outcome: .victory,
                    gold: 220, slain: 11, combats: 5, explored: 10, total: 12, minutes: 900),
            // Cartoon Caper — classic cartoons
            SeedDef(daysAgo: 18, names: ["Top Cat", "Danger Mouse", "Penelope Pitstop"],
                    members: [("Top Cat", .rogue, .lightfootHalfling), ("Danger Mouse", .ranger, .gnome), ("Penelope Pitstop", .fighter, .human)],
                    dungeon: "The Labyrinth", level: 2, outcome: .victory,
                    gold: 190, slain: 9, combats: 4, explored: 10, total: 12, minutes: 840),
            // Robots Expedition — sci-fi robots
            SeedDef(daysAgo: 22, names: ["Daneel", "K-9", "Marvin"],
                    members: [("Daneel", .rogue, .human), ("K-9", .wizard, .gnome), ("Marvin", .wizard, .tiefling)],
                    dungeon: "Nostromo", level: 2, outcome: .defeat,
                    gold: 95, slain: 6, combats: 3, explored: 6, total: 12, minutes: 540),
            // Hellfire Club — Stranger Things tribute
            SeedDef(daysAgo: 28, names: ["Eddie Munson", "Will the Wise", "Eleven"],
                    members: [("Eddie Munson", .rogue, .human), ("Will the Wise", .cleric, .human), ("Eleven", .wizard, .human)],
                    dungeon: "Krell Laboratory", level: 1, outcome: .defeat,
                    gold: 65, slain: 4, combats: 2, explored: 5, total: 10, minutes: 480),
            // Burroughs' Barsoom — pulp legends
            SeedDef(daysAgo: 32, names: ["Doct Carter", "Dejah Thoris", "Tars Tarkas"],
                    members: [("Doct Carter", .fighter, .human), ("Dejah Thoris", .barbarian, .human), ("Tars Tarkas", .fighter, .human)],
                    dungeon: "The Scarlet Citadel", level: 3, outcome: .victory,
                    gold: 350, slain: 15, combats: 6, explored: 13, total: 14, minutes: 1300),
            // Three Musketeers — Dumas
            SeedDef(daysAgo: 36, names: ["Athos", "Porthos", "Aramis", "D'Artagnan"],
                    members: [("Athos", .fighter, .human), ("Porthos", .fighter, .human), ("Aramis", .cleric, .halfElf), ("D'Artagnan", .rogue, .human)],
                    dungeon: "The Iron Tower", level: 2, outcome: .victory,
                    gold: 260, slain: 12, combats: 5, explored: 11, total: 12, minutes: 950),
        ]

        let calendar = Calendar.current
        let now = Date()

        for seed in seeds {
            let date = calendar.date(byAdding: .day, value: -seed.daysAgo, to: now)!
            let desc = seed.members.map { "\($0.0) (\($0.1.rawValue))" }.joined(separator: ", ")

            // Build the party
            let party = buildSeedParty(seed.members, gold: seed.gold, level: seed.level)

            // Generate dungeon and simulate exploration
            let dungeon = Dungeon(name: seed.dungeon, level: seed.level)
            simulateExploration(dungeon: dungeon, roomsExplored: seed.explored, isDefeat: seed.outcome == .defeat)

            // Create the save game (for defeats: positioned one room before the end)
            let slotId = UUID()
            let saveId = UUID()
            let save = SaveGame(
                id: saveId, slotId: slotId, savedAt: date,
                slotName: "⭐ \(seed.dungeon)",
                partyDescription: desc,
                dungeonName: seed.dungeon, dungeonLevel: seed.level,
                party: party, dungeon: dungeon, gameState: .exploring,
                gameTimeMinutes: seed.minutes,
                adventureLog: buildSeedLog(seed),
                dmChatLog: nil, torchLit: true, torchTurnsRemaining: 30,
                partyChatLog: nil,
                monstersSlain: seed.slain, combatsWon: seed.combats,
                activeQuest: nil
            )
            try? SaveGameManager.shared.save(save)

            // Create Hall of Fame entry linked to the save
            var entry = HallOfFameEntry(
                date: date,
                partyNames: seed.names, partyDescription: desc,
                dungeonName: seed.dungeon, dungeonLevel: seed.level,
                outcome: seed.outcome, goldCollected: seed.gold,
                monstersSlain: seed.slain, combatsWon: seed.combats,
                roomsExplored: seed.explored, totalRooms: seed.total,
                gameTimeMinutes: seed.minutes,
                saveGameId: saveId
            )
            addEntry(entry)
        }
    }

    // MARK: - Save Game Generation Helpers

    /// Build characters for a seed entry with appropriate gear and stats
    private func buildSeedParty(_ members: [(String, CharacterClass, Race)], gold: Int, level: Int) -> [Character] {
        let goldEach = gold / max(members.count, 1)
        return members.enumerated().map { (i, m) in
            let scores = typicalScores(for: m.1)
            let char = Character(name: m.0, race: m.2, characterClass: m.1,
                                 abilityScores: scores, isComputerControlled: i > 0)
            char.gold = goldEach

            // Give starting gear and equip best weapon/armour
            let equipOptions = ItemCatalog.startingEquipmentOptions(for: m.1)
            if let (_, items) = equipOptions.first {
                for item in items { char.inventory.append(item) }
                // Auto-equip first weapon
                if let weapon = char.inventory.first(where: { $0.type == .weapon }) {
                    char.equipWeapon(weapon)
                }
                // Auto-equip first armour
                if let armor = char.inventory.first(where: { $0.type == .armor }) {
                    char.equipArmor(armor)
                }
                // Auto-equip shield
                if let shield = char.inventory.first(where: { $0.type == .shield }) {
                    char.equipShield(shield)
                }
            }

            // Set level for higher-level dungeons
            if level > 1 {
                char.level = level
                let conMod = scores.modifier(for: .constitution)
                let hpPerLevel = (m.1.startingHP / 2 + 1) + conMod  // avg HP per level
                char.maxHP += hpPerLevel * (level - 1)
                char.currentHP = char.maxHP
            }

            return char
        }
    }

    /// Sensible ability scores per class
    private func typicalScores(for cls: CharacterClass) -> AbilityScores {
        switch cls {
        case .fighter:    return AbilityScores(strength: 16, dexterity: 13, constitution: 14, intelligence: 10, wisdom: 12, charisma: 8)
        case .wizard:     return AbilityScores(strength: 8, dexterity: 14, constitution: 12, intelligence: 16, wisdom: 13, charisma: 10)
        case .rogue:      return AbilityScores(strength: 10, dexterity: 16, constitution: 13, intelligence: 14, wisdom: 12, charisma: 8)
        case .cleric:     return AbilityScores(strength: 14, dexterity: 10, constitution: 13, intelligence: 8, wisdom: 16, charisma: 12)
        case .ranger:     return AbilityScores(strength: 13, dexterity: 16, constitution: 14, intelligence: 10, wisdom: 12, charisma: 8)
        case .barbarian:  return AbilityScores(strength: 16, dexterity: 14, constitution: 15, intelligence: 8, wisdom: 10, charisma: 12)
        }
    }

    /// Mark rooms as visited to simulate exploration progress
    private func simulateExploration(dungeon: Dungeon, roomsExplored: Int, isDefeat: Bool) {
        // Walk rooms via BFS from entrance
        var visited: [Int] = [0]
        var queue: [Int] = [0]
        dungeon.rooms[0]?.visited = true
        dungeon.rooms[0]?.cleared = true

        while visited.count < roomsExplored && !queue.isEmpty {
            let current = queue.removeFirst()
            guard let room = dungeon.rooms[current] else { continue }
            for (_, nextId) in room.exits {
                guard !visited.contains(nextId), visited.count < roomsExplored else { break }
                dungeon.rooms[nextId]?.visited = true
                dungeon.rooms[nextId]?.cleared = true
                dungeon.rooms[nextId]?.encounter = nil  // cleared
                visited.append(nextId)
                queue.append(nextId)
            }
        }

        // Position the party in the last explored room
        // For defeats: one room before the end (as if about to face doom)
        if isDefeat && visited.count > 1 {
            dungeon.currentRoomId = visited[visited.count - 2]
        } else if let last = visited.last {
            dungeon.currentRoomId = last
        }
    }

    /// Build a flavourful adventure log
    private func buildSeedLog(_ seed: SeedDef) -> [String] {
        var log: [String] = []
        log.append("The party entered \(seed.dungeon).")
        if seed.slain > 0 {
            log.append("Slew \(seed.slain) creatures in \(seed.combats) battles.")
        }
        log.append("Explored \(seed.explored) of \(seed.total) rooms.")
        if seed.gold > 0 {
            log.append("Collected \(seed.gold) gold pieces.")
        }
        if seed.outcome == .victory {
            log.append("The dungeon boss was defeated!")
        } else {
            log.append("The party fell to the dungeon's horrors...")
        }
        return log
    }
}
