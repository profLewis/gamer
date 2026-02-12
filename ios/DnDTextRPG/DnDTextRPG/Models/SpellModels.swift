//
//  SpellModels.swift
//  DnDTextRPG
//
//  D&D 5e spell system — cantrips, spell slots, and spell catalog
//

import Foundation

// MARK: - Spell Level

enum SpellLevel: Int, Codable, Comparable {
    case cantrip = 0
    case level1 = 1
    case level2 = 2

    static func < (lhs: SpellLevel, rhs: SpellLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .cantrip: return "Cantrip"
        case .level1: return "1st Level"
        case .level2: return "2nd Level"
        }
    }
}

// MARK: - Spell Type

enum SpellType: String, Codable {
    case attack         // Roll d20 + spell attack bonus vs AC
    case savingThrow    // Target rolls save vs spell DC
    case autoHit        // Magic Missile — no roll needed
    case healing        // Cure Wounds — heal an ally
    case buff           // Bless — buff the party
    case utility        // Spare the Dying — stabilize ally
}

// MARK: - Spell Target

enum SpellTarget: String, Codable {
    case singleEnemy
    case allEnemies
    case singleAlly
    case self_
}

// MARK: - Spell

struct Spell: Codable, Identifiable {
    let id: UUID
    let name: String
    let level: SpellLevel
    let spellType: SpellType
    let target: SpellTarget
    let damage: String?             // dice notation: "1d10", "3d4+3"
    let damageType: String?         // "fire", "cold", "radiant", etc.
    let healAmount: String?         // dice notation: "1d8"
    let usesCasterMod: Bool         // add spellcasting mod to heal/damage
    let savingThrowAbility: String? // "dexterity", "wisdom" for save spells
    let halfDamageOnSave: Bool      // save spells do half on success
    let description: String

    init(name: String, level: SpellLevel, spellType: SpellType, target: SpellTarget,
         damage: String? = nil, damageType: String? = nil,
         healAmount: String? = nil, usesCasterMod: Bool = false,
         savingThrowAbility: String? = nil, halfDamageOnSave: Bool = true,
         description: String) {
        self.id = UUID()
        self.name = name
        self.level = level
        self.spellType = spellType
        self.target = target
        self.damage = damage
        self.damageType = damageType
        self.healAmount = healAmount
        self.usesCasterMod = usesCasterMod
        self.savingThrowAbility = savingThrowAbility
        self.halfDamageOnSave = halfDamageOnSave
        self.description = description
    }
}

// MARK: - Spell Slots

struct SpellSlots: Codable {
    var level1Current: Int = 0
    var level1Max: Int = 0
    var level2Current: Int = 0
    var level2Max: Int = 0

    mutating func useSlot(level: SpellLevel) {
        switch level {
        case .level1: level1Current = max(0, level1Current - 1)
        case .level2: level2Current = max(0, level2Current - 1)
        case .cantrip: break
        }
    }

    func hasSlot(level: SpellLevel) -> Bool {
        switch level {
        case .cantrip: return true
        case .level1: return level1Current > 0
        case .level2: return level2Current > 0
        }
    }

    mutating func restoreAll() {
        level1Current = level1Max
        level2Current = level2Max
    }

    var isEmpty: Bool {
        level1Max == 0 && level2Max == 0
    }
}

// MARK: - Spell Report

struct SpellReport {
    let casterName: String
    let spellName: String
    let spellType: SpellType

    // For attack spells
    let d20Roll: Int?
    let attackBonus: Int?
    let totalAttack: Int?
    let targetAC: Int?
    let hits: Bool?
    let isCritical: Bool

    // For save spells
    let saveDC: Int?
    let saveResults: [(targetName: String, roll: Int, total: Int, saved: Bool)]

    // Damage / Healing
    let damageRolls: [Int]
    let totalDamage: Int
    let healAmount: Int
    let damageType: String?

    // Targets
    let targetName: String?
    let targetsHit: [String]
    let targetsDefeated: [String]
    let targetStatuses: [(name: String, currentHP: Int, maxHP: Int)]
}

// MARK: - Spell Catalog

struct SpellCatalog {

    // MARK: Wizard Cantrips

    static func fireBolt() -> Spell {
        Spell(name: "Fire Bolt", level: .cantrip, spellType: .attack, target: .singleEnemy,
              damage: "1d10", damageType: "fire",
              description: "1d10 fire damage (ranged spell attack)")
    }

    static func rayOfFrost() -> Spell {
        Spell(name: "Ray of Frost", level: .cantrip, spellType: .attack, target: .singleEnemy,
              damage: "1d8", damageType: "cold",
              description: "1d8 cold damage (ranged spell attack)")
    }

    static func shockingGrasp() -> Spell {
        Spell(name: "Shocking Grasp", level: .cantrip, spellType: .attack, target: .singleEnemy,
              damage: "1d8", damageType: "lightning",
              description: "1d8 lightning damage (melee spell attack)")
    }

    // MARK: Wizard Level 1

    static func magicMissile() -> Spell {
        Spell(name: "Magic Missile", level: .level1, spellType: .autoHit, target: .singleEnemy,
              damage: "3d4+3", damageType: "force",
              description: "3d4+3 force damage (auto-hit)")
    }

    static func burningHands() -> Spell {
        Spell(name: "Burning Hands", level: .level1, spellType: .savingThrow, target: .allEnemies,
              damage: "3d6", damageType: "fire",
              savingThrowAbility: "dexterity", halfDamageOnSave: true,
              description: "3d6 fire to all enemies (DEX save, half)")
    }

    static func sleep() -> Spell {
        Spell(name: "Sleep", level: .level1, spellType: .autoHit, target: .singleEnemy,
              damage: "5d8", damageType: "sleep",
              description: "5d8 HP of creatures fall unconscious")
    }

    // MARK: Cleric Cantrips

    static func sacredFlame() -> Spell {
        Spell(name: "Sacred Flame", level: .cantrip, spellType: .savingThrow, target: .singleEnemy,
              damage: "1d8", damageType: "radiant",
              savingThrowAbility: "dexterity", halfDamageOnSave: false,
              description: "1d8 radiant damage (DEX save, no half)")
    }

    static func tollTheDead() -> Spell {
        Spell(name: "Toll the Dead", level: .cantrip, spellType: .savingThrow, target: .singleEnemy,
              damage: "1d8", damageType: "necrotic",
              savingThrowAbility: "wisdom", halfDamageOnSave: false,
              description: "1d8 necrotic (1d12 if hurt) (WIS save)")
    }

    static func spareTheDying() -> Spell {
        Spell(name: "Spare the Dying", level: .cantrip, spellType: .utility, target: .singleAlly,
              description: "Stabilize an unconscious ally")
    }

    // MARK: Cleric Level 1

    static func cureWounds() -> Spell {
        Spell(name: "Cure Wounds", level: .level1, spellType: .healing, target: .singleAlly,
              healAmount: "1d8", usesCasterMod: true,
              description: "Heal 1d8 + WIS mod HP")
    }

    static func guidingBolt() -> Spell {
        Spell(name: "Guiding Bolt", level: .level1, spellType: .attack, target: .singleEnemy,
              damage: "4d6", damageType: "radiant",
              description: "4d6 radiant damage (ranged spell attack)")
    }

    static func healingWord() -> Spell {
        Spell(name: "Healing Word", level: .level1, spellType: .healing, target: .singleAlly,
              healAmount: "1d4", usesCasterMod: true,
              description: "Heal 1d4 + WIS mod HP (bonus action)")
    }

    // MARK: Ranger Level 1

    static func huntersMark() -> Spell {
        Spell(name: "Hunter's Mark", level: .level1, spellType: .buff, target: .self_,
              description: "Add 1d6 damage to attacks (concentration)")
    }

    static func cureWoundsRanger() -> Spell {
        Spell(name: "Cure Wounds", level: .level1, spellType: .healing, target: .singleAlly,
              healAmount: "1d8", usesCasterMod: true,
              description: "Heal 1d8 + WIS mod HP")
    }

    // MARK: - Spell Lists by Class

    static func startingSpells(for characterClass: CharacterClass) -> [Spell] {
        switch characterClass {
        case .wizard:
            return [fireBolt(), rayOfFrost(), shockingGrasp(),
                    magicMissile(), burningHands(), sleep()]
        case .cleric:
            return [sacredFlame(), tollTheDead(), spareTheDying(),
                    cureWounds(), guidingBolt(), healingWord()]
        default:
            return []
        }
    }

    static func startingSlots(for characterClass: CharacterClass, level: Int) -> SpellSlots {
        var slots = SpellSlots()
        switch characterClass {
        case .wizard, .cleric:
            switch level {
            case 1: slots.level1Max = 2
            case 2: slots.level1Max = 3
            case 3: slots.level1Max = 4; slots.level2Max = 2
            case 4: slots.level1Max = 4; slots.level2Max = 3
            default: slots.level1Max = 4; slots.level2Max = 3
            }
        case .ranger:
            switch level {
            case 2: slots.level1Max = 2
            case 3: slots.level1Max = 3
            case 4: slots.level1Max = 3
            default:
                if level >= 5 { slots.level1Max = 4; slots.level2Max = 2 }
            }
        default:
            break
        }
        slots.level1Current = slots.level1Max
        slots.level2Current = slots.level2Max
        return slots
    }

    static func spellsForLevelUp(characterClass: CharacterClass, newLevel: Int) -> [Spell] {
        switch characterClass {
        case .ranger:
            if newLevel == 2 {
                return [huntersMark(), cureWoundsRanger()]
            }
            return []
        default:
            return []
        }
    }
}
