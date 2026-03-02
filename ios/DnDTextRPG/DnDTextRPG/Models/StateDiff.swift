//
//  StateDiff.swift
//  DnDTextRPG
//
//  Computes and formats differences between two state snapshots
//

import Foundation

struct StateChange {
    let description: String
    let color: TerminalColor
}

struct StateDiff {
    let changes: [StateChange]
    var hasChanges: Bool { !changes.isEmpty }

    static func compute(before: StateSnapshot, after: StateSnapshot) -> StateDiff {
        var changes: [StateChange] = []

        // Room movement
        if before.currentRoomId != after.currentRoomId {
            changes.append(StateChange(
                description: "Moved: \(before.currentRoomName) -> \(after.currentRoomName)",
                color: .yellow
            ))
        }

        // Per-character diffs
        for afterChar in after.characters {
            guard let beforeChar = before.characters.first(where: { $0.id == afterChar.id }) else { continue }
            let name = afterChar.name

            // HP
            let hpDelta = afterChar.currentHP - beforeChar.currentHP
            if hpDelta > 0 {
                changes.append(StateChange(
                    description: "\(name): +\(hpDelta) HP (\(beforeChar.currentHP) -> \(afterChar.currentHP))",
                    color: .brightGreen
                ))
            } else if hpDelta < 0 {
                changes.append(StateChange(
                    description: "\(name): \(hpDelta) HP (\(beforeChar.currentHP) -> \(afterChar.currentHP))",
                    color: .red
                ))
            }

            // Gold
            let goldDelta = afterChar.gold - beforeChar.gold
            if goldDelta > 0 {
                changes.append(StateChange(description: "\(name): +\(goldDelta) gold", color: .brightGreen))
            } else if goldDelta < 0 {
                changes.append(StateChange(description: "\(name): \(goldDelta) gold", color: .red))
            }

            // Inventory
            let beforeItems = beforeChar.inventoryItems
            let afterItems = afterChar.inventoryItems
            let beforeSet = NSCountedSet(array: beforeItems)
            let afterSet = NSCountedSet(array: afterItems)

            for item in Set(afterItems) {
                let gained = afterSet.count(for: item) - beforeSet.count(for: item)
                if gained > 0 {
                    let label = gained > 1 ? "\(item) x\(gained)" : item
                    changes.append(StateChange(description: "\(name): Gained \(label)", color: .brightGreen))
                }
            }
            for item in Set(beforeItems) {
                let lost = beforeSet.count(for: item) - afterSet.count(for: item)
                if lost > 0 {
                    let label = lost > 1 ? "\(item) x\(lost)" : item
                    changes.append(StateChange(description: "\(name): Lost \(label)", color: .red))
                }
            }

            // Equipment
            if beforeChar.equippedWeapon != afterChar.equippedWeapon {
                let from = beforeChar.equippedWeapon ?? "None"
                let to = afterChar.equippedWeapon ?? "None"
                changes.append(StateChange(description: "\(name): Weapon \(from) -> \(to)", color: .yellow))
            }
            if beforeChar.equippedArmor != afterChar.equippedArmor {
                let from = beforeChar.equippedArmor ?? "None"
                let to = afterChar.equippedArmor ?? "None"
                changes.append(StateChange(description: "\(name): Armour \(from) -> \(to)", color: .yellow))
            }
            if beforeChar.equippedShield != afterChar.equippedShield {
                let from = beforeChar.equippedShield ?? "None"
                let to = afterChar.equippedShield ?? "None"
                changes.append(StateChange(description: "\(name): Shield \(from) -> \(to)", color: .yellow))
            }

            // Status
            if !beforeChar.isConscious && afterChar.isConscious {
                changes.append(StateChange(description: "\(name): Revived!", color: .brightGreen))
            } else if beforeChar.isConscious && !afterChar.isConscious {
                changes.append(StateChange(description: "\(name): Knocked out!", color: .red))
            }
            if !beforeChar.isPoisoned && afterChar.isPoisoned {
                changes.append(StateChange(description: "\(name): Poisoned!", color: .red))
            } else if beforeChar.isPoisoned && !afterChar.isPoisoned {
                changes.append(StateChange(description: "\(name): Poison cured", color: .brightGreen))
            }
        }

        return StateDiff(changes: changes)
    }
}
