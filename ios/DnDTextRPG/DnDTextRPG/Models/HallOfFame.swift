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

    /// Composite score: victory bonus + gold + kills + exploration + difficulty
    var score: Int {
        let victoryBonus = outcome == .victory ? 500 : 0
        let difficultyMultiplier = dungeonLevel
        let explorationBonus = totalRooms > 0 ? (roomsExplored * 100 / totalRooms) : 0
        return (victoryBonus + goldCollected + monstersSlain * 20 + combatsWon * 50 + explorationBonus) * difficultyMultiplier
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

    func seedIfEmpty() {
        guard listEntries().isEmpty else { return }

        let calendar = Calendar.current
        let now = Date()

        // Aragorn's Fellowship — Tolkien heroes, the high score to beat
        addEntry(HallOfFameEntry(
            id: UUID(), date: calendar.date(byAdding: .day, value: -2, to: now)!,
            partyNames: ["Aragorn", "Ged", "Granny Weatherwax"],
            partyDescription: "Aragorn (Ranger), Ged (Wizard), Granny Weatherwax (Cleric)",
            dungeonName: "Moria", dungeonLevel: 3,
            outcome: .victory, goldCollected: 420, monstersSlain: 18,
            combatsWon: 7, roomsExplored: 12, totalRooms: 14,
            gameTimeMinutes: 1400
        ))

        // 80s Fantasy Legends — classic film heroes
        addEntry(HallOfFameEntry(
            id: UUID(), date: calendar.date(byAdding: .day, value: -5, to: now)!,
            partyNames: ["Madmartigan", "Willow", "Hawk", "Red Sonja"],
            partyDescription: "Madmartigan (Fighter), Willow (Wizard), Hawk (Ranger), Red Sonja (Fighter)",
            dungeonName: "Ravenloft", dungeonLevel: 3,
            outcome: .victory, goldCollected: 380, monstersSlain: 16,
            combatsWon: 6, roomsExplored: 11, totalRooms: 14,
            gameTimeMinutes: 1200
        ))

        // Edgin's Heist — Honour Among Thieves
        addEntry(HallOfFameEntry(
            id: UUID(), date: calendar.date(byAdding: .day, value: -8, to: now)!,
            partyNames: ["Edgin", "Holga", "Xenk"],
            partyDescription: "Edgin (Rogue), Holga (Barbarian), Xenk (Fighter)",
            dungeonName: "Tomb of Horrors", dungeonLevel: 3,
            outcome: .defeat, goldCollected: 280, monstersSlain: 14,
            combatsWon: 5, roomsExplored: 8, totalRooms: 14,
            gameTimeMinutes: 1100
        ))

        // Disc World Expedition — Pratchett
        addEntry(HallOfFameEntry(
            id: UUID(), date: calendar.date(byAdding: .day, value: -10, to: now)!,
            partyNames: ["Rincewind", "DEATH"],
            partyDescription: "Rincewind (Wizard), DEATH (Fighter)",
            dungeonName: "Ankh-Morpork", dungeonLevel: 1,
            outcome: .victory, goldCollected: 140, monstersSlain: 7,
            combatsWon: 4, roomsExplored: 9, totalRooms: 10,
            gameTimeMinutes: 660
        ))

        // Classic Sci-Fi Survivors
        addEntry(HallOfFameEntry(
            id: UUID(), date: calendar.date(byAdding: .day, value: -14, to: now)!,
            partyNames: ["Ripley", "Atreides", "Snake Plissken"],
            partyDescription: "Ripley (Ranger), Atreides (Wizard), Snake Plissken (Rogue)",
            dungeonName: "Trantor", dungeonLevel: 2,
            outcome: .victory, goldCollected: 220, monstersSlain: 11,
            combatsWon: 5, roomsExplored: 10, totalRooms: 12,
            gameTimeMinutes: 900
        ))

        // Cartoon Caper — classic cartoons
        addEntry(HallOfFameEntry(
            id: UUID(), date: calendar.date(byAdding: .day, value: -18, to: now)!,
            partyNames: ["Top Cat", "Danger Mouse", "Penelope Pitstop"],
            partyDescription: "Top Cat (Rogue), Danger Mouse (Ranger), Penelope Pitstop (Fighter)",
            dungeonName: "The Labyrinth", dungeonLevel: 2,
            outcome: .victory, goldCollected: 190, monstersSlain: 9,
            combatsWon: 4, roomsExplored: 10, totalRooms: 12,
            gameTimeMinutes: 840
        ))

        // Robots Expedition — sci-fi robots
        addEntry(HallOfFameEntry(
            id: UUID(), date: calendar.date(byAdding: .day, value: -22, to: now)!,
            partyNames: ["Daneel", "K-9", "Marvin"],
            partyDescription: "Daneel (Rogue), K-9 (Wizard), Marvin (Wizard)",
            dungeonName: "Nostromo", dungeonLevel: 2,
            outcome: .defeat, goldCollected: 95, monstersSlain: 6,
            combatsWon: 3, roomsExplored: 6, totalRooms: 12,
            gameTimeMinutes: 540
        ))

        // Hellfire Club — Stranger Things tribute
        addEntry(HallOfFameEntry(
            id: UUID(), date: calendar.date(byAdding: .day, value: -28, to: now)!,
            partyNames: ["Eddie Munson", "Will the Wise", "Eleven"],
            partyDescription: "Eddie Munson (Rogue), Will the Wise (Cleric), Eleven (Wizard)",
            dungeonName: "Caves of Chaos", dungeonLevel: 1,
            outcome: .defeat, goldCollected: 65, monstersSlain: 4,
            combatsWon: 2, roomsExplored: 5, totalRooms: 10,
            gameTimeMinutes: 480
        ))
    }
}
