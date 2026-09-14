//
//  SaveGameModels.swift
//  DnDTextRPG
//
//  Save game data model and file manager
//

import Foundation

// MARK: - DM Chat Entry (Codable wrapper for chat log tuples)

struct DMChatEntry: Codable {
    let isUser: Bool
    let text: String
}

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

    // DM conversation history (persists across saves/loads)
    let dmChatLog: [DMChatEntry]?

    // Torch state
    let torchLit: Bool?
    let torchTurnsRemaining: Int?

    // Party chat log
    let partyChatLog: [PartyChatMessage]?

    // Run stats
    let monstersSlain: Int
    let combatsWon: Int

    // Active side quest, if any
    let activeQuest: SideQuest?

    // Further quests a strong party is carrying at the same time (nil in older saves)
    var otherQuests: [SideQuest]? = nil

    // The adventure's opening tale, a line a page (nil in older saves)
    var introLines: [String]? = nil
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

    /// How many separate adventures (slots) are kept — the "Max Saves"
    /// option on the Game Saves settings screen. Was a hard-coded 10.
    /// -1 = Unlimited in both pickers (0 means "never set" in UserDefaults).
    static let unlimited = -1
    static let maxSlotsChoices = [10, 25, 50, 100, unlimited]
    static var maxSlotsSetting: Int {
        let v = UserDefaults.standard.integer(forKey: "maxSaveSlots")
        return v == unlimited ? unlimited : (v > 0 ? v : 25)
    }
    static var maxSlots: Int { maxSlotsSetting == unlimited ? Int.max : maxSlotsSetting }

    /// Save points kept per adventure ("Save Points" on Game Saves) —
    /// was a fixed 5.
    static let savePointChoices = [3, 5, 10, 20, unlimited]
    static var savePointsSetting: Int {
        let v = UserDefaults.standard.integer(forKey: "maxSavePointsPerAdventure")
        return v == unlimited ? unlimited : (v > 0 ? v : 5)
    }
    static var maxBreakpointsPerSlot: Int { savePointsSetting == unlimited ? Int.max : savePointsSetting }

    /// "10" / "Unlimited" for a limit setting.
    static func limitLabel(_ value: Int) -> String { value == unlimited ? "Unlimited" : "\(value)" }

    /// Which save points survive once an adventure has more than its limit:
    /// the newest N, or a spread — recent ones kept densely, older ones at
    /// ever-wider gaps, so you can still go back a long way.
    enum KeepStrategy: String {
        case newest, spread
        var label: String { self == .newest ? "Newest" : "Spread Out" }
    }
    static var keepStrategy: KeepStrategy {
        get { KeepStrategy(rawValue: UserDefaults.standard.string(forKey: "saveKeepStrategy") ?? "") ?? .newest }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "saveKeepStrategy") }
    }
    /// Won adventures (Hall of Fame victories) are never trimmed to make room.
    static var protectWins: Bool {
        get { UserDefaults.standard.object(forKey: "protectWonAdventures") == nil ? true : UserDefaults.standard.bool(forKey: "protectWonAdventures") }
        set { UserDefaults.standard.set(newValue, forKey: "protectWonAdventures") }
    }

    /// Indices (into a newest-first list of `count` saves) to keep for a
    /// limit of `limit`.
    static func indicesToKeep(count: Int, limit: Int, strategy: KeepStrategy) -> Set<Int> {
        guard count > limit else { return Set(0..<count) }
        switch strategy {
        case .newest:
            return Set(0..<limit)
        case .spread:
            // Newest half kept as-is, then 2, 4, 8... saves further back.
            let dense = max(1, (limit + 1) / 2)
            var keep = Set(0..<dense)
            var index = dense - 1
            var gap = 2
            while keep.count < limit && index + gap < count {
                index += gap
                keep.insert(index)
                gap *= 2
            }
            // Always keep the very first save point if there's room left.
            if keep.count < limit { keep.insert(count - 1) }
            return keep
        }
    }

    private var savesDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("SavedGames")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Deletion record
    //
    // A persisted list of every save id the player has deleted — kept in
    // its own file, outside SavedGames/, and only ever appended to. Any
    // save file whose id is on it is treated as deleted (and removed
    // again) by listAllSaves/load, no matter which code path may have
    // written it back. Belt-and-braces behind the real fix (launch-time
    // seeding/repair no longer recreating deleted adventures — see
    // HallOfFameManager.seedIfEmpty/repairOrphanEntries): a deletion
    // should never be silently undone.

    private var deletedSavesURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("DeletedSaves.json")
    }

    private func loadDeletedSaveIds() -> Set<UUID> {
        guard let data = try? Data(contentsOf: deletedSavesURL),
              let strings = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(strings.compactMap(UUID.init(uuidString:)))
    }

    private func recordDeletedSaveId(_ id: UUID) {
        var ids = loadDeletedSaveIds()
        guard ids.insert(id).inserted else { return }
        guard let data = try? JSONEncoder().encode(ids.map { $0.uuidString }) else { return }
        try? data.write(to: deletedSavesURL, options: .atomic)
    }

    func listAllSaves() -> [SaveGame] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: savesDirectory,
            includingPropertiesForKeys: nil
        ) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let deletedIds = loadDeletedSaveIds()

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> SaveGame? in
                guard let data = try? Data(contentsOf: url),
                      let save = try? decoder.decode(SaveGame.self, from: data) else { return nil }
                if deletedIds.contains(save.id) {
                    try? FileManager.default.removeItem(at: url)
                    return nil
                }
                return save
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

        // Enforce max slot limit — delete oldest slots if over 10
        trimExcessSlots()
    }

    func load(id: UUID) -> SaveGame? {
        guard !loadDeletedSaveIds().contains(id) else { return nil }
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
        recordDeletedSaveId(id)
        // A completed tale's Hall of Fame entry is just this same save
        // shown differently in Continue Adventure's one unified list, not
        // a second, independent record — deleting the save should delete
        // it too, rather than leaving a "no save" ghost of the adventure
        // the player just removed.
        HallOfFameManager.shared.deleteEntries(forSaveGameId: id)
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
        let keep = SaveGameManager.indicesToKeep(count: breakpoints.count,
                                                  limit: SaveGameManager.maxBreakpointsPerSlot,
                                                  strategy: SaveGameManager.keepStrategy)
        for (index, save) in breakpoints.enumerated() where !keep.contains(index) {
            delete(id: save.id)
        }
    }

    /// Delete the oldest slots if total exceeds maxSlots
    private func trimExcessSlots() {
        let slots = listSlots()
        guard slots.count > SaveGameManager.maxSlots else { return }
        // Won adventures are exempt (Protect Wins) — they don't count
        // towards the limit and are never trimmed.
        let wonSaveIds: Set<UUID> = SaveGameManager.protectWins
            ? Set(HallOfFameManager.shared.listEntries().filter { $0.outcome == .victory }.compactMap { $0.saveGameId })
            : []
        let trimmable = slots.filter { slot in
            !listBreakpoints(slotId: slot.slotId).contains { wonSaveIds.contains($0.id) }
        }
        guard trimmable.count > SaveGameManager.maxSlots else { return }
        // Slots are sorted newest first — delete from the end
        for slot in trimmable.suffix(from: SaveGameManager.maxSlots) {
            deleteSlot(slotId: slot.slotId)
        }
    }
}
