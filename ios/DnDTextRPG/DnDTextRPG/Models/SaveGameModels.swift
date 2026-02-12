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
    let slotId: UUID           // Groups saves into a "slot" (same adventure)
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

// MARK: - Save Slot (grouped view)

struct SaveSlot {
    let slotId: UUID
    let slotName: String
    let latest: SaveGame          // Most recent breakpoint
    let breakpointCount: Int      // Total breakpoints in this slot
}

// MARK: - Save Game Manager

class SaveGameManager {
    static let shared = SaveGameManager()

    static let maxSlots = 10
    static let maxBreakpointsPerSlot = 5

    private var savesDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("SavedGames")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func listAllSaves() -> [SaveGame] {
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

    /// Returns saves grouped by slot, most recent first
    func listSlots() -> [SaveSlot] {
        let allSaves = listAllSaves()
        var slotGroups: [UUID: [SaveGame]] = [:]

        for save in allSaves {
            slotGroups[save.slotId, default: []].append(save)
        }

        return slotGroups.values.compactMap { saves -> SaveSlot? in
            guard let latest = saves.first else { return nil }  // already sorted by date desc
            return SaveSlot(
                slotId: latest.slotId,
                slotName: latest.slotName,
                latest: latest,
                breakpointCount: saves.count
            )
        }
        .sorted { $0.latest.savedAt > $1.latest.savedAt }
    }

    /// Returns all breakpoints for a given slot, most recent first
    func listBreakpoints(slotId: UUID) -> [SaveGame] {
        return listAllSaves().filter { $0.slotId == slotId }
    }

    // Legacy compatibility — return all saves as a flat list
    func listSaves() -> [SaveGame] {
        return listAllSaves()
    }

    func save(_ saveGame: SaveGame) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(saveGame)
        let fileName = "\(saveGame.id.uuidString).json"
        let fileURL = savesDirectory.appendingPathComponent(fileName)
        try data.write(to: fileURL)

        // Trim old breakpoints for this slot
        trimBreakpoints(slotId: saveGame.slotId)
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

    /// Delete all breakpoints in a slot
    func deleteSlot(slotId: UUID) {
        let breakpoints = listBreakpoints(slotId: slotId)
        for save in breakpoints {
            delete(id: save.id)
        }
    }

    /// Keep only the N most recent breakpoints per slot
    private func trimBreakpoints(slotId: UUID) {
        let breakpoints = listBreakpoints(slotId: slotId)
        if breakpoints.count > SaveGameManager.maxBreakpointsPerSlot {
            let toDelete = breakpoints.suffix(from: SaveGameManager.maxBreakpointsPerSlot)
            for save in toDelete {
                delete(id: save.id)
            }
        }
    }
}
