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
