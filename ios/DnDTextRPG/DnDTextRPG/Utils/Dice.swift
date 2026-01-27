//
//  Dice.swift
//  DnDTextRPG
//
//  Dice rolling utilities for D&D 5e
//

import Foundation

struct Dice {
    // MARK: - Basic Rolls

    /// Roll a single die
    static func roll(_ sides: Int) -> Int {
        return Int.random(in: 1...sides)
    }

    /// Roll multiple dice
    static func roll(_ count: Int, d sides: Int) -> [Int] {
        return (0..<count).map { _ in roll(sides) }
    }

    /// Roll multiple dice and return sum
    static func rollSum(_ count: Int, d sides: Int) -> Int {
        return roll(count, d: sides).reduce(0, +)
    }

    // MARK: - Common Dice

    static func d4() -> Int { roll(4) }
    static func d6() -> Int { roll(6) }
    static func d8() -> Int { roll(8) }
    static func d10() -> Int { roll(10) }
    static func d12() -> Int { roll(12) }
    static func d20() -> Int { roll(20) }
    static func d100() -> Int { roll(100) }

    // MARK: - D&D Specific Rolls

    /// Roll with advantage (roll 2d20, take higher)
    static func rollWithAdvantage() -> (result: Int, rolls: [Int]) {
        let rolls = [d20(), d20()]
        return (rolls.max()!, rolls)
    }

    /// Roll with disadvantage (roll 2d20, take lower)
    static func rollWithDisadvantage() -> (result: Int, rolls: [Int]) {
        let rolls = [d20(), d20()]
        return (rolls.min()!, rolls)
    }

    /// Roll ability scores using 4d6 drop lowest method
    static func rollAbilityScore() -> Int {
        let rolls = roll(4, d: 6).sorted(by: >)
        return rolls.prefix(3).reduce(0, +)
    }

    /// Generate a full set of ability scores
    static func rollAbilityScores() -> [Int] {
        return (0..<6).map { _ in rollAbilityScore() }.sorted(by: >)
    }

    // MARK: - Attack Rolls

    struct AttackResult {
        let roll: Int
        let total: Int
        let isCritical: Bool
        let isCriticalMiss: Bool
        let hits: Bool

        var description: String {
            if isCritical {
                return "CRITICAL HIT! (\(roll) + modifiers = \(total))"
            } else if isCriticalMiss {
                return "Critical Miss! (Natural 1)"
            } else if hits {
                return "Hit! (\(roll) + modifiers = \(total))"
            } else {
                return "Miss (\(roll) + modifiers = \(total))"
            }
        }
    }

    static func attackRoll(modifier: Int, targetAC: Int, advantage: Bool = false, disadvantage: Bool = false) -> AttackResult {
        let roll: Int
        if advantage && !disadvantage {
            roll = rollWithAdvantage().result
        } else if disadvantage && !advantage {
            roll = rollWithDisadvantage().result
        } else {
            roll = d20()
        }

        let total = roll + modifier
        let isCritical = roll == 20
        let isCriticalMiss = roll == 1

        // Natural 20 always hits, natural 1 always misses
        let hits = isCritical || (!isCriticalMiss && total >= targetAC)

        return AttackResult(
            roll: roll,
            total: total,
            isCritical: isCritical,
            isCriticalMiss: isCriticalMiss,
            hits: hits
        )
    }

    // MARK: - Saving Throws

    struct SavingThrowResult {
        let roll: Int
        let total: Int
        let success: Bool
        let isCriticalSuccess: Bool
        let isCriticalFailure: Bool
    }

    static func savingThrow(modifier: Int, dc: Int) -> SavingThrowResult {
        let roll = d20()
        let total = roll + modifier

        return SavingThrowResult(
            roll: roll,
            total: total,
            success: roll == 20 || (roll != 1 && total >= dc),
            isCriticalSuccess: roll == 20,
            isCriticalFailure: roll == 1
        )
    }

    // MARK: - Damage Rolls

    static func rollDamage(_ diceNotation: String) -> (total: Int, rolls: [Int]) {
        // Parse notation like "2d6+3" or "1d8"
        let cleaned = diceNotation.lowercased().replacingOccurrences(of: " ", with: "")

        var modifier = 0
        var diceString = cleaned

        // Extract modifier
        if let plusIndex = cleaned.firstIndex(of: "+") {
            let modStr = String(cleaned[cleaned.index(after: plusIndex)...])
            modifier = Int(modStr) ?? 0
            diceString = String(cleaned[..<plusIndex])
        } else if let minusIndex = cleaned.lastIndex(of: "-") {
            let modStr = String(cleaned[cleaned.index(after: minusIndex)...])
            modifier = -(Int(modStr) ?? 0)
            diceString = String(cleaned[..<minusIndex])
        }

        // Parse dice (e.g., "2d6")
        let parts = diceString.split(separator: "d")
        guard parts.count == 2,
              let count = Int(parts[0]),
              let sides = Int(parts[1]) else {
            return (modifier, [])
        }

        let rolls = roll(count, d: sides)
        let total = rolls.reduce(0, +) + modifier

        return (total, rolls)
    }

    /// Roll damage with critical hit (double dice)
    static func rollCriticalDamage(_ diceNotation: String) -> (total: Int, rolls: [Int]) {
        // Double the dice for critical hits
        let cleaned = diceNotation.lowercased().replacingOccurrences(of: " ", with: "")

        var modifier = 0
        var diceString = cleaned

        if let plusIndex = cleaned.firstIndex(of: "+") {
            let modStr = String(cleaned[cleaned.index(after: plusIndex)...])
            modifier = Int(modStr) ?? 0
            diceString = String(cleaned[..<plusIndex])
        } else if let minusIndex = cleaned.lastIndex(of: "-") {
            let modStr = String(cleaned[cleaned.index(after: minusIndex)...])
            modifier = -(Int(modStr) ?? 0)
            diceString = String(cleaned[..<minusIndex])
        }

        let parts = diceString.split(separator: "d")
        guard parts.count == 2,
              let count = Int(parts[0]),
              let sides = Int(parts[1]) else {
            return (modifier, [])
        }

        // Double the dice count for crits
        let rolls = roll(count * 2, d: sides)
        let total = rolls.reduce(0, +) + modifier

        return (total, rolls)
    }

    // MARK: - Death Saves

    struct DeathSaveResult {
        let roll: Int
        let isSuccess: Bool
        let isCriticalSuccess: Bool  // Natural 20 = regain 1 HP
        let isCriticalFailure: Bool  // Natural 1 = 2 failures
    }

    static func deathSave() -> DeathSaveResult {
        let roll = d20()
        return DeathSaveResult(
            roll: roll,
            isSuccess: roll >= 10,
            isCriticalSuccess: roll == 20,
            isCriticalFailure: roll == 1
        )
    }

    // MARK: - Initiative

    static func rollInitiative(dexModifier: Int) -> Int {
        return d20() + dexModifier
    }
}
