//
//  SaveGameModels.swift
//  DnDTextRPG
//
//  Save game data model and file manager
//

import Foundation

// MARK: - Save Game

struct SaveGame: Codable, Identifiable {
    let id: UUID
    let savedAt: Date
    let slotName: String
    let partyDescription: String
    let dungeonName: String
    let dungeonLevel: Int

    // Game state
    let party: [Character]
    let dungeon: Dungeon
    let gameState: GameState

    // Time & history
    let gameTimeMinutes: Int
    let adventureLog: [String]

    // Run stats
    let monstersSlain: Int
    let combatsWon: Int
}

// MARK: - Save Game Manager

class SaveGameManager {
    static let shared = SaveGameManager()

    private var savesDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("SavedGames")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func listSaves() -> [SaveGame] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: savesDirectory,
            includingPropertiesForKeys: nil
        ) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> SaveGame? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(SaveGame.self, from: data)
            }
            .sorted { $0.savedAt > $1.savedAt }
    }

    func save(_ saveGame: SaveGame) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(saveGame)
        let fileName = "\(saveGame.id.uuidString).json"
        let fileURL = savesDirectory.appendingPathComponent(fileName)
        try data.write(to: fileURL)
    }

    func load(id: UUID) -> SaveGame? {
        let fileName = "\(id.uuidString).json"
        let fileURL = savesDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SaveGame.self, from: data)
    }

    func delete(id: UUID) {
        let fileName = "\(id.uuidString).json"
        let fileURL = savesDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }
}
