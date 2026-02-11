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
            .sorted { $0.date > $1.date }
    }

    func addEntry(_ entry: HallOfFameEntry) {
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

    // MARK: - Seed Data (Stranger Things D&D crew)

    func seedIfEmpty() {
        guard listEntries().isEmpty else { return }

        let calendar = Calendar.current
        let now = Date()

        // Max's legendary run — the high score to beat
        addEntry(HallOfFameEntry(
            id: UUID(), date: calendar.date(byAdding: .day, value: -3, to: now)!,
            partyNames: ["Max", "Lucas", "Dustin"],
            partyDescription: "Max (Fighter), Lucas (Ranger), Dustin (Wizard)",
            dungeonName: "The Upside Down", dungeonLevel: 2,
            outcome: .victory, goldCollected: 320, monstersSlain: 14,
            combatsWon: 6, roomsExplored: 10, totalRooms: 12,
            gameTimeMinutes: 1200
        ))

        // Will's solo attempt
        addEntry(HallOfFameEntry(
            id: UUID(), date: calendar.date(byAdding: .day, value: -7, to: now)!,
            partyNames: ["Will"],
            partyDescription: "Will (Cleric)",
            dungeonName: "Castle Byers", dungeonLevel: 1,
            outcome: .victory, goldCollected: 85, monstersSlain: 5,
            combatsWon: 3, roomsExplored: 8, totalRooms: 10,
            gameTimeMinutes: 720
        ))

        // Mike's campaign — party wipe
        addEntry(HallOfFameEntry(
            id: UUID(), date: calendar.date(byAdding: .day, value: -10, to: now)!,
            partyNames: ["Mike", "Eleven", "Will", "Dustin"],
            partyDescription: "Mike (Paladin), Eleven (Sorcerer), Will (Cleric), Dustin (Wizard)",
            dungeonName: "Vecna's Lair", dungeonLevel: 3,
            outcome: .defeat, goldCollected: 210, monstersSlain: 11,
            combatsWon: 4, roomsExplored: 7, totalRooms: 14,
            gameTimeMinutes: 900
        ))

        // Eddie's brave run
        addEntry(HallOfFameEntry(
            id: UUID(), date: calendar.date(byAdding: .day, value: -14, to: now)!,
            partyNames: ["Eddie", "Dustin"],
            partyDescription: "Eddie (Bard), Dustin (Wizard)",
            dungeonName: "The Dark Depths", dungeonLevel: 1,
            outcome: .victory, goldCollected: 150, monstersSlain: 8,
            combatsWon: 4, roomsExplored: 9, totalRooms: 10,
            gameTimeMinutes: 840
        ))

        // Lucas's quick defeat
        addEntry(HallOfFameEntry(
            id: UUID(), date: calendar.date(byAdding: .day, value: -20, to: now)!,
            partyNames: ["Lucas"],
            partyDescription: "Lucas (Ranger)",
            dungeonName: "Hawkins Lab", dungeonLevel: 2,
            outcome: .defeat, goldCollected: 40, monstersSlain: 3,
            combatsWon: 1, roomsExplored: 4, totalRooms: 12,
            gameTimeMinutes: 480
        ))
    }
}
