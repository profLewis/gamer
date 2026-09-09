//
//  CharacterLibraryModels.swift
//  DnDTextRPG
//
//  Character Roster — save/load individual characters independent of game
//  saves, so a character can carry its level, gear, and gold from one
//  adventure into the next. Mirrors SaveGameManager's file-per-record
//  approach in its own directory, so it's a clearly separate "slot" system
//  from adventure saves.
//

import Foundation

struct SavedCharacterRecord: Codable, Identifiable {
    var id: UUID { character.id }
    let savedAt: Date
    let character: Character
}

class CharacterLibraryManager {
    static let shared = CharacterLibraryManager()

    static let maxCharacters = 20

    private var libraryDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("SavedCharacters")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// All saved characters, most recently saved first.
    func listCharacters() -> [SavedCharacterRecord] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: libraryDirectory,
            includingPropertiesForKeys: nil
        ) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> SavedCharacterRecord? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(SavedCharacterRecord.self, from: data)
            }
            .sorted { $0.savedAt > $1.savedAt }
    }

    /// Saves (or updates, if a character with this id was already saved) a
    /// character to the roster. Keyed on the character's own id, so saving
    /// progress on a character already in the roster overwrites its record
    /// rather than creating a duplicate.
    @discardableResult
    func save(_ character: Character) -> Bool {
        let record = SavedCharacterRecord(savedAt: Date(), character: character)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(record) else { return false }

        let fileURL = libraryDirectory.appendingPathComponent("\(character.id.uuidString).json")
        do {
            try data.write(to: fileURL)
            trimExcess()
            return true
        } catch {
            return false
        }
    }

    func delete(id: UUID) {
        let fileURL = libraryDirectory.appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Keep only the most recently saved N characters.
    private func trimExcess() {
        let all = listCharacters()
        guard all.count > Self.maxCharacters else { return }
        for record in all.suffix(from: Self.maxCharacters) {
            delete(id: record.character.id)
        }
    }
}

// MARK: - Character Hall of Fame
//
// Parallels HallOfFame.swift (game runs), but for individual characters:
// every survivor of a victorious run is inducted here, with a link to a
// Character Roster save so "relive this hero" works the same way a Hall of
// Fame game entry links to a game save.

struct CharacterHallOfFameEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let characterName: String
    let race: String
    let characterClass: String
    let level: Int
    let gold: Int
    let dungeonName: String
    let dungeonLevel: Int
    var linkedCharacterId: UUID?  // matches a CharacterLibraryManager saved character

    var score: Int { level * 200 + gold }

    init(id: UUID = UUID(), date: Date, characterName: String, race: String, characterClass: String,
         level: Int, gold: Int, dungeonName: String, dungeonLevel: Int, linkedCharacterId: UUID? = nil) {
        self.id = id
        self.date = date
        self.characterName = characterName
        self.race = race
        self.characterClass = characterClass
        self.level = level
        self.gold = gold
        self.dungeonName = dungeonName
        self.dungeonLevel = dungeonLevel
        self.linkedCharacterId = linkedCharacterId
    }
}

class CharacterHallOfFameManager {
    static let shared = CharacterHallOfFameManager()

    private var hallDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("CharacterHallOfFame")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func listEntries() -> [CharacterHallOfFameEntry] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: hallDirectory,
            includingPropertiesForKeys: nil
        ) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> CharacterHallOfFameEntry? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(CharacterHallOfFameEntry.self, from: data)
            }
            .sorted { $0.score > $1.score }
    }

    /// Most recently inducted entry (by date, not score) whose linked
    /// character is still present in the roster — used to default "New
    /// Adventure" to offering your last hero back.
    func mostRecentAvailableEntry() -> CharacterHallOfFameEntry? {
        let rosterIds = Set(CharacterLibraryManager.shared.listCharacters().map { $0.character.id })
        return listEntries()
            .filter { $0.linkedCharacterId.map { rosterIds.contains($0) } ?? false }
            .max { $0.date < $1.date }
    }

    func addEntry(_ entry: CharacterHallOfFameEntry) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(entry) else { return }
        let fileURL = hallDirectory.appendingPathComponent("\(entry.id.uuidString).json")
        try? data.write(to: fileURL)
        trimToTop10()
    }

    private func trimToTop10() {
        let entries = listEntries()
        guard entries.count > 10 else { return }
        for entry in entries.suffix(from: 10) {
            let fileURL = hallDirectory.appendingPathComponent("\(entry.id.uuidString).json")
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}
