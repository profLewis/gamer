//
//  StateSnapshot.swift
//  DnDTextRPG
//
//  Lightweight snapshot of mutable game state for DM mode reconciliation
//

import Foundation

// MARK: - Character Snapshot

struct CharacterSnapshot: Codable, Equatable {
    let id: UUID
    let name: String
    let currentHP: Int
    let maxHP: Int
    let gold: Int
    let inventoryItems: [String]
    let equippedWeapon: String?
    let equippedArmor: String?
    let equippedShield: String?
    let isConscious: Bool
    let isPoisoned: Bool
}

// MARK: - State Snapshot

struct StateSnapshot: Codable {
    let timestamp: Date
    let label: String
    let currentRoomId: Int
    let currentRoomName: String
    let dungeonLevel: Int
    let characters: [CharacterSnapshot]
    let gameTimeMinutes: Int

    static func capture(
        label: String,
        party: [Character],
        dungeon: Dungeon?,
        gameTimeMinutes: Int
    ) -> StateSnapshot {
        let charSnapshots = party.map { char in
            CharacterSnapshot(
                id: char.id,
                name: char.name,
                currentHP: char.currentHP,
                maxHP: char.maxHP,
                gold: char.gold,
                inventoryItems: char.inventory.map { $0.name }.sorted(),
                equippedWeapon: char.equippedWeapon?.name,
                equippedArmor: char.equippedArmor?.name,
                equippedShield: char.equippedShield?.name,
                isConscious: char.isConscious,
                isPoisoned: char.isPoisoned
            )
        }
        return StateSnapshot(
            timestamp: Date(),
            label: label,
            currentRoomId: dungeon?.currentRoomId ?? -1,
            currentRoomName: dungeon?.currentRoom?.name ?? "Unknown",
            dungeonLevel: dungeon?.level ?? 0,
            characters: charSnapshots,
            gameTimeMinutes: gameTimeMinutes
        )
    }
}
