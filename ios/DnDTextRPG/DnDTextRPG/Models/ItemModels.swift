//
//  ItemModels.swift
//  DnDTextRPG
//
//  Item, equipment, and inventory models
//

import Foundation

// MARK: - Item Type

enum ItemType: String, Codable, CaseIterable {
    case weapon
    case armor
    case shield
    case potion
    case scroll
    case gem
    case misc
}

// MARK: - Weapon Stats

struct WeaponStats: Codable {
    let damage: String          // e.g. "1d8"
    let damageType: String      // "slashing", "piercing", "bludgeoning"
    let isFinesse: Bool         // Can use DEX instead of STR
    let isRanged: Bool
    let isTwoHanded: Bool
}

// MARK: - Armor Stats

struct ArmorStats: Codable {
    let baseAC: Int             // e.g. 11 for leather, 16 for chain
    let maxDexBonus: Int?       // nil = unlimited, 0 = none, 2 = medium armor
    let stealthDisadvantage: Bool
    let isShield: Bool          // +2 AC bonus, stacks with armor
}

// MARK: - Potion Stats

struct PotionStats: Codable {
    let healAmount: String?     // e.g. "2d4+2"
    let effect: String          // Human-readable: "Restores 2d4+2 HP"
}

// MARK: - Item

struct Item: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let description: String
    let type: ItemType
    let weight: Double          // in pounds
    let value: Int              // gold piece value

    let weaponStats: WeaponStats?
    let armorStats: ArmorStats?
    let potionStats: PotionStats?

    static func == (lhs: Item, rhs: Item) -> Bool {
        lhs.id == rhs.id
    }

    /// Create a fresh copy with a new UUID
    func newInstance() -> Item {
        Item(id: UUID(), name: name, description: description, type: type,
             weight: weight, value: value, weaponStats: weaponStats,
             armorStats: armorStats, potionStats: potionStats)
    }
}

// MARK: - Item Catalog

struct ItemCatalog {

    // MARK: Weapons

    static func longsword() -> Item {
        Item(id: UUID(), name: "Longsword", description: "A versatile steel blade.",
             type: .weapon, weight: 3.0, value: 15,
             weaponStats: WeaponStats(damage: "1d8", damageType: "slashing",
                                       isFinesse: false, isRanged: false, isTwoHanded: false),
             armorStats: nil, potionStats: nil)
    }

    static func shortsword() -> Item {
        Item(id: UUID(), name: "Shortsword", description: "A light, quick blade.",
             type: .weapon, weight: 2.0, value: 10,
             weaponStats: WeaponStats(damage: "1d6", damageType: "piercing",
                                       isFinesse: true, isRanged: false, isTwoHanded: false),
             armorStats: nil, potionStats: nil)
    }

    static func greataxe() -> Item {
        Item(id: UUID(), name: "Greataxe", description: "A massive two-handed axe.",
             type: .weapon, weight: 7.0, value: 30,
             weaponStats: WeaponStats(damage: "1d12", damageType: "slashing",
                                       isFinesse: false, isRanged: false, isTwoHanded: true),
             armorStats: nil, potionStats: nil)
    }

    static func longbow() -> Item {
        Item(id: UUID(), name: "Longbow", description: "A tall bow for ranged attacks.",
             type: .weapon, weight: 2.0, value: 50,
             weaponStats: WeaponStats(damage: "1d8", damageType: "piercing",
                                       isFinesse: false, isRanged: true, isTwoHanded: true),
             armorStats: nil, potionStats: nil)
    }

    static func dagger() -> Item {
        Item(id: UUID(), name: "Dagger", description: "A small, concealable blade.",
             type: .weapon, weight: 1.0, value: 2,
             weaponStats: WeaponStats(damage: "1d4", damageType: "piercing",
                                       isFinesse: true, isRanged: false, isTwoHanded: false),
             armorStats: nil, potionStats: nil)
    }

    static func quarterstaff() -> Item {
        Item(id: UUID(), name: "Quarterstaff", description: "A simple wooden staff.",
             type: .weapon, weight: 4.0, value: 2,
             weaponStats: WeaponStats(damage: "1d6", damageType: "bludgeoning",
                                       isFinesse: false, isRanged: false, isTwoHanded: false),
             armorStats: nil, potionStats: nil)
    }

    static func mace() -> Item {
        Item(id: UUID(), name: "Mace", description: "A heavy flanged weapon.",
             type: .weapon, weight: 4.0, value: 5,
             weaponStats: WeaponStats(damage: "1d6", damageType: "bludgeoning",
                                       isFinesse: false, isRanged: false, isTwoHanded: false),
             armorStats: nil, potionStats: nil)
    }

    static func rapier() -> Item {
        Item(id: UUID(), name: "Rapier", description: "A thin, precise thrusting blade.",
             type: .weapon, weight: 2.0, value: 25,
             weaponStats: WeaponStats(damage: "1d8", damageType: "piercing",
                                       isFinesse: true, isRanged: false, isTwoHanded: false),
             armorStats: nil, potionStats: nil)
    }

    static func handaxe() -> Item {
        Item(id: UUID(), name: "Handaxe", description: "A small throwing axe.",
             type: .weapon, weight: 2.0, value: 5,
             weaponStats: WeaponStats(damage: "1d6", damageType: "slashing",
                                       isFinesse: false, isRanged: false, isTwoHanded: false),
             armorStats: nil, potionStats: nil)
    }

    // MARK: Armor

    static func leatherArmor() -> Item {
        Item(id: UUID(), name: "Leather Armor", description: "Light, flexible protection.",
             type: .armor, weight: 10.0, value: 10,
             weaponStats: nil,
             armorStats: ArmorStats(baseAC: 11, maxDexBonus: nil, stealthDisadvantage: false, isShield: false),
             potionStats: nil)
    }

    static func chainMail() -> Item {
        Item(id: UUID(), name: "Chain Mail", description: "Interlocking metal rings.",
             type: .armor, weight: 55.0, value: 75,
             weaponStats: nil,
             armorStats: ArmorStats(baseAC: 16, maxDexBonus: 0, stealthDisadvantage: true, isShield: false),
             potionStats: nil)
    }

    static func scaleMail() -> Item {
        Item(id: UUID(), name: "Scale Mail", description: "Coat of metal scales.",
             type: .armor, weight: 45.0, value: 50,
             weaponStats: nil,
             armorStats: ArmorStats(baseAC: 14, maxDexBonus: 2, stealthDisadvantage: true, isShield: false),
             potionStats: nil)
    }

    static func studdedLeather() -> Item {
        Item(id: UUID(), name: "Studded Leather", description: "Reinforced leather armor.",
             type: .armor, weight: 13.0, value: 45,
             weaponStats: nil,
             armorStats: ArmorStats(baseAC: 12, maxDexBonus: nil, stealthDisadvantage: false, isShield: false),
             potionStats: nil)
    }

    static func shield() -> Item {
        Item(id: UUID(), name: "Shield", description: "A wooden shield. +2 AC.",
             type: .shield, weight: 6.0, value: 10,
             weaponStats: nil,
             armorStats: ArmorStats(baseAC: 2, maxDexBonus: nil, stealthDisadvantage: false, isShield: true),
             potionStats: nil)
    }

    // MARK: Potions

    static func healingPotion() -> Item {
        Item(id: UUID(), name: "Potion of Healing", description: "Restores 2d4+2 hit points.",
             type: .potion, weight: 0.5, value: 50,
             weaponStats: nil, armorStats: nil,
             potionStats: PotionStats(healAmount: "2d4+2", effect: "Restores 2d4+2 HP"))
    }

    static func greaterHealingPotion() -> Item {
        Item(id: UUID(), name: "Potion of Greater Healing", description: "Restores 4d4+4 hit points.",
             type: .potion, weight: 0.5, value: 150,
             weaponStats: nil, armorStats: nil,
             potionStats: PotionStats(healAmount: "4d4+4", effect: "Restores 4d4+4 HP"))
    }

    // MARK: Misc

    static func torch() -> Item {
        Item(id: UUID(), name: "Torch", description: "Provides light for 1 hour.",
             type: .misc, weight: 1.0, value: 1,
             weaponStats: nil, armorStats: nil, potionStats: nil)
    }

    static func rope() -> Item {
        Item(id: UUID(), name: "Rope (50 ft)", description: "Hempen rope, 50 feet.",
             type: .misc, weight: 10.0, value: 1,
             weaponStats: nil, armorStats: nil, potionStats: nil)
    }

    static func spellComponentPouch() -> Item {
        Item(id: UUID(), name: "Spell Component Pouch", description: "A pouch of arcane components.",
             type: .misc, weight: 2.0, value: 25,
             weaponStats: nil, armorStats: nil, potionStats: nil)
    }

    static func holySymbol() -> Item {
        Item(id: UUID(), name: "Holy Symbol", description: "A divine focus for spellcasting.",
             type: .misc, weight: 1.0, value: 5,
             weaponStats: nil, armorStats: nil, potionStats: nil)
    }

    static func thievesTools() -> Item {
        Item(id: UUID(), name: "Thieves' Tools", description: "Tools for picking locks and disarming traps.",
             type: .misc, weight: 1.0, value: 25,
             weaponStats: nil, armorStats: nil, potionStats: nil)
    }

    // MARK: Starting Equipment

    static func startingEquipmentOptions(for characterClass: CharacterClass) -> [(String, [Item])] {
        switch characterClass {
        case .fighter:
            return [
                ("Longsword + Chain Mail + Shield", [longsword(), chainMail(), shield(), healingPotion()]),
                ("Greataxe + Chain Mail", [greataxe(), chainMail(), healingPotion(), healingPotion()]),
                ("Two Handaxes + Scale Mail + Shield", [handaxe(), handaxe(), scaleMail(), shield(), healingPotion()]),
            ]
        case .wizard:
            return [
                ("Quarterstaff + Spell Components", [quarterstaff(), spellComponentPouch(), dagger(), healingPotion()]),
                ("Dagger + Spell Components + Extra Potions", [dagger(), spellComponentPouch(), healingPotion(), healingPotion()]),
            ]
        case .rogue:
            return [
                ("Rapier + Leather Armor + Thieves' Tools", [rapier(), leatherArmor(), thievesTools(), dagger(), healingPotion()]),
                ("Two Shortswords + Studded Leather", [shortsword(), shortsword(), studdedLeather(), thievesTools(), healingPotion()]),
            ]
        case .cleric:
            return [
                ("Mace + Scale Mail + Shield + Holy Symbol", [mace(), scaleMail(), shield(), holySymbol(), healingPotion()]),
                ("Mace + Chain Mail + Holy Symbol", [mace(), chainMail(), holySymbol(), healingPotion(), healingPotion()]),
            ]
        case .ranger:
            return [
                ("Longbow + Studded Leather + Shortsword", [longbow(), studdedLeather(), shortsword(), healingPotion()]),
                ("Two Shortswords + Scale Mail", [shortsword(), shortsword(), scaleMail(), healingPotion()]),
            ]
        case .barbarian:
            return [
                ("Greataxe + Two Handaxes", [greataxe(), handaxe(), handaxe(), healingPotion(), healingPotion()]),
                ("Two Handaxes + Leather Armor", [handaxe(), handaxe(), leatherArmor(), healingPotion(), healingPotion()]),
            ]
        }
    }

    // MARK: Shop Stock

    static func shopStock(forLevel level: Int) -> [Item] {
        var stock: [Item] = []

        // Always available
        stock.append(healingPotion())
        stock.append(healingPotion())
        stock.append(torch())
        stock.append(rope())
        stock.append(dagger())
        stock.append(leatherArmor())
        stock.append(shortsword())
        stock.append(mace())
        stock.append(shield())

        if level >= 2 {
            stock.append(greaterHealingPotion())
            stock.append(longsword())
            stock.append(scaleMail())
            stock.append(rapier())
            stock.append(studdedLeather())
            stock.append(longbow())
        }

        if level >= 3 {
            stock.append(greaterHealingPotion())
            stock.append(chainMail())
            stock.append(greataxe())
        }

        return stock
    }
}
