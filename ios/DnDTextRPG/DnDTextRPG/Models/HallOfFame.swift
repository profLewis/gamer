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

    // MARK: - Seed Data (Stranger Things D&D crew — Hellfire Club & friends)

    func seedIfEmpty() {
        guard listEntries().isEmpty else { return }

        let calendar = Calendar.current
        let now = Date()

        // Eddie's Hellfire Club campaign — the high score to beat
        addEntry(HallOfFameEntry(
            id: UUID(), date: calendar.date(byAdding: .day, value: -2, to: now)!,
            partyNames: ["Eddie Munson", "Dustin \"Nog\"", "Erica \"Lady Applejack\""],
            partyDescription: "Eddie Munson (Rogue), Dustin \"Nog\" (Wizard), Erica \"Lady Applejack\" (Rogue)",
            dungeonName: "The Demogorgon's Lair", dungeonLevel: 3,
            outcome: .victory, goldCollected: 420, monstersSlain: 18,
            combatsWon: 7, roomsExplored: 12, totalRooms: 14,
            gameTimeMinutes: 1400
        ))

        // Mike's epic party wipe against Vecna
        addEntry(HallOfFameEntry(
            id: UUID(), date: calendar.date(byAdding: .day, value: -5, to: now)!,
            partyNames: ["Mike Wheeler", "Eleven", "Will the Wise", "Dustin \"Nog\""],
            partyDescription: "Mike Wheeler (Fighter), Eleven (Wizard), Will the Wise (Wizard), Dustin \"Nog\" (Wizard)",
            dungeonName: "Vecna's Throne", dungeonLevel: 3,
            outcome: .defeat, goldCollected: 280, monstersSlain: 15,
            combatsWon: 5, roomsExplored: 9, totalRooms: 14,
            gameTimeMinutes: 1100
        ))

        // Max's legendary speed run
        addEntry(HallOfFameEntry(
            id: UUID(), date: calendar.date(byAdding: .day, value: -8, to: now)!,
            partyNames: ["Zoomer", "Sundar the Bold", "Dustin \"Nog\""],
            partyDescription: "Zoomer (Rogue), Sundar the Bold (Ranger), Dustin \"Nog\" (Wizard)",
            dungeonName: "The Upside Down", dungeonLevel: 2,
            outcome: .victory, goldCollected: 320, monstersSlain: 14,
            combatsWon: 6, roomsExplored: 10, totalRooms: 12,
            gameTimeMinutes: 900
        ))

        // Hopper & Joyce rescue mission
        addEntry(HallOfFameEntry(
            id: UUID(), date: calendar.date(byAdding: .day, value: -10, to: now)!,
            partyNames: ["Jim Hopper", "Joyce Byers"],
            partyDescription: "Jim Hopper (Barbarian), Joyce Byers (Cleric)",
            dungeonName: "Hawkins Lab", dungeonLevel: 2,
            outcome: .victory, goldCollected: 180, monstersSlain: 10,
            combatsWon: 5, roomsExplored: 11, totalRooms: 12,
            gameTimeMinutes: 840
        ))

        // Will the Wise solo
        addEntry(HallOfFameEntry(
            id: UUID(), date: calendar.date(byAdding: .day, value: -14, to: now)!,
            partyNames: ["Will the Wise"],
            partyDescription: "Will the Wise (Cleric)",
            dungeonName: "Castle Byers", dungeonLevel: 1,
            outcome: .victory, goldCollected: 85, monstersSlain: 5,
            combatsWon: 3, roomsExplored: 8, totalRooms: 10,
            gameTimeMinutes: 720
        ))

        // Steve & Robin
        addEntry(HallOfFameEntry(
            id: UUID(), date: calendar.date(byAdding: .day, value: -18, to: now)!,
            partyNames: ["Steve Harrington", "Robin Buckley"],
            partyDescription: "Steve Harrington (Fighter), Robin Buckley (Wizard)",
            dungeonName: "Starcourt Mall", dungeonLevel: 1,
            outcome: .victory, goldCollected: 140, monstersSlain: 7,
            combatsWon: 4, roomsExplored: 9, totalRooms: 10,
            gameTimeMinutes: 660
        ))

        // Nancy & Jonathan vs the Mind Flayer
        addEntry(HallOfFameEntry(
            id: UUID(), date: calendar.date(byAdding: .day, value: -22, to: now)!,
            partyNames: ["Nancy Wheeler", "Jonathan Byers"],
            partyDescription: "Nancy Wheeler (Ranger), Jonathan Byers (Ranger)",
            dungeonName: "Mind Flayer's Domain", dungeonLevel: 2,
            outcome: .defeat, goldCollected: 95, monstersSlain: 6,
            combatsWon: 3, roomsExplored: 6, totalRooms: 12,
            gameTimeMinutes: 540
        ))

        // Murray's solo quest
        addEntry(HallOfFameEntry(
            id: UUID(), date: calendar.date(byAdding: .day, value: -28, to: now)!,
            partyNames: ["Murray Bauman"],
            partyDescription: "Murray Bauman (Wizard)",
            dungeonName: "The Russian Base", dungeonLevel: 1,
            outcome: .defeat, goldCollected: 30, monstersSlain: 2,
            combatsWon: 1, roomsExplored: 3, totalRooms: 10,
            gameTimeMinutes: 360
        ))
    }
}
