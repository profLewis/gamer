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

    /// Torch remaining life in minutes (nil = not a torch). Fresh torch = 720 (12 hours).
    var torchLife: Int?

    /// If set, this item is a key that unlocks the door(s) sharing this id
    /// (Room.doorLockIds). nil = not a key.
    var keyForDoorId: UUID? = nil

    /// Weapons can break when used to block a blow in combat. Optional (not
    /// a plain Bool) so old saves without this field decode fine — treat
    /// missing as "not broken" via `broken` below.
    var isBroken: Bool? = nil

    static let torchFullLife = 720  // 12 hours in minutes

    var isTorch: Bool { name.lowercased().contains("torch") }

    /// A broken weapon can't be equipped or used to attack until repaired.
    var broken: Bool { isBroken ?? false }

    /// Human-readable torch life remaining
    var torchLifeDescription: String? {
        guard let life = torchLife else { return nil }
        let hours = life / 60
        let mins = life % 60
        if hours > 0 && mins > 0 { return "\(hours)h \(mins)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(mins)m"
    }

    static func == (lhs: Item, rhs: Item) -> Bool {
        lhs.id == rhs.id
    }

    /// Create a fresh copy with a new UUID
    func newInstance() -> Item {
        var copy = Item(id: UUID(), name: name, description: description, type: type,
             weight: weight, value: value, weaponStats: weaponStats,
             armorStats: armorStats, potionStats: potionStats)
        copy.torchLife = torchLife
        return copy
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

    static func warhammer() -> Item {
        Item(id: UUID(), name: "Warhammer", description: "A heavy hammer built to crack armour.",
             type: .weapon, weight: 5.0, value: 15,
             weaponStats: WeaponStats(damage: "1d8", damageType: "bludgeoning",
                                       isFinesse: false, isRanged: false, isTwoHanded: false),
             armorStats: nil, potionStats: nil)
    }

    static func battleaxe() -> Item {
        Item(id: UUID(), name: "Battleaxe", description: "A broad, single-bladed axe.",
             type: .weapon, weight: 4.0, value: 10,
             weaponStats: WeaponStats(damage: "1d8", damageType: "slashing",
                                       isFinesse: false, isRanged: false, isTwoHanded: false),
             armorStats: nil, potionStats: nil)
    }

    static func scimitar() -> Item {
        Item(id: UUID(), name: "Scimitar", description: "A light, curved blade.",
             type: .weapon, weight: 3.0, value: 25,
             weaponStats: WeaponStats(damage: "1d6", damageType: "slashing",
                                       isFinesse: true, isRanged: false, isTwoHanded: false),
             armorStats: nil, potionStats: nil)
    }

    static func spear() -> Item {
        Item(id: UUID(), name: "Spear", description: "A simple thrusting weapon.",
             type: .weapon, weight: 3.0, value: 1,
             weaponStats: WeaponStats(damage: "1d6", damageType: "piercing",
                                       isFinesse: false, isRanged: false, isTwoHanded: false),
             armorStats: nil, potionStats: nil)
    }

    static func sling() -> Item {
        Item(id: UUID(), name: "Sling", description: "A leather strap for hurling stones.",
             type: .weapon, weight: 0.5, value: 1,
             weaponStats: WeaponStats(damage: "1d4", damageType: "bludgeoning",
                                       isFinesse: false, isRanged: true, isTwoHanded: false),
             armorStats: nil, potionStats: nil)
    }

    static func lightCrossbow() -> Item {
        Item(id: UUID(), name: "Light Crossbow", description: "A mechanical ranged weapon, slow to reload but hard-hitting.",
             type: .weapon, weight: 5.0, value: 25,
             weaponStats: WeaponStats(damage: "1d8", damageType: "piercing",
                                       isFinesse: false, isRanged: true, isTwoHanded: true),
             armorStats: nil, potionStats: nil)
    }

    static func whip() -> Item {
        Item(id: UUID(), name: "Whip", description: "A long, snapping lash — more intimidating than deadly.",
             type: .weapon, weight: 3.0, value: 2,
             weaponStats: WeaponStats(damage: "1d4", damageType: "slashing",
                                       isFinesse: true, isRanged: false, isTwoHanded: false),
             armorStats: nil, potionStats: nil)
    }

    static func trident() -> Item {
        Item(id: UUID(), name: "Trident", description: "A three-pronged spear, favoured by sea-folk.",
             type: .weapon, weight: 4.0, value: 5,
             weaponStats: WeaponStats(damage: "1d6", damageType: "piercing",
                                       isFinesse: false, isRanged: false, isTwoHanded: false),
             armorStats: nil, potionStats: nil)
    }

    // MARK: Armor

    static func leatherArmor() -> Item {
        Item(id: UUID(), name: "Leather Armour", description: "Light, flexible protection.",
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
        Item(id: UUID(), name: "Studded Leather", description: "Reinforced leather armour.",
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

    static func paddedArmor() -> Item {
        Item(id: UUID(), name: "Padded Armour", description: "Quilted layers of cloth and batting.",
             type: .armor, weight: 8.0, value: 5,
             weaponStats: nil,
             armorStats: ArmorStats(baseAC: 11, maxDexBonus: nil, stealthDisadvantage: true, isShield: false),
             potionStats: nil)
    }

    static func ringMail() -> Item {
        Item(id: UUID(), name: "Ring Mail", description: "Leather armour reinforced with metal rings.",
             type: .armor, weight: 40.0, value: 30,
             weaponStats: nil,
             armorStats: ArmorStats(baseAC: 14, maxDexBonus: 0, stealthDisadvantage: true, isShield: false),
             potionStats: nil)
    }

    static func plateArmor() -> Item {
        Item(id: UUID(), name: "Plate Armour", description: "A full suit of shaped, fitted metal plate — the pinnacle of protection.",
             type: .armor, weight: 65.0, value: 200,
             weaponStats: nil,
             armorStats: ArmorStats(baseAC: 18, maxDexBonus: 0, stealthDisadvantage: true, isShield: false),
             potionStats: nil)
    }

    static func buckler() -> Item {
        Item(id: UUID(), name: "Buckler", description: "A small strap-on shield. +1 AC, doesn't get in the way.",
             type: .shield, weight: 2.0, value: 5,
             weaponStats: nil,
             armorStats: ArmorStats(baseAC: 1, maxDexBonus: nil, stealthDisadvantage: false, isShield: true),
             potionStats: nil)
    }

    // MARK: Potions

    static func healingPotion() -> Item {
        Item(id: UUID(), name: "Potion of Healing", description: "Restores 2d4+2 hit points.",
             type: .potion, weight: 1.0, value: 50,
             weaponStats: nil, armorStats: nil,
             potionStats: PotionStats(healAmount: "2d4+2", effect: "Restores 2d4+2 HP"))
    }

    static func greaterHealingPotion() -> Item {
        Item(id: UUID(), name: "Potion of Greater Healing", description: "Restores 4d4+4 hit points.",
             type: .potion, weight: 1.0, value: 150,
             weaponStats: nil, armorStats: nil,
             potionStats: PotionStats(healAmount: "4d4+4", effect: "Restores 4d4+4 HP"))
    }

    static func antidote() -> Item {
        Item(id: UUID(), name: "Antidote", description: "Cures poison instantly. Herbalists and clerics make the best use of these.",
             type: .potion, weight: 1.0, value: 30,
             weaponStats: nil, armorStats: nil,
             potionStats: PotionStats(healAmount: "0", effect: "Cures poison"))
    }

    static func superiorHealingPotion() -> Item {
        Item(id: UUID(), name: "Potion of Superior Healing", description: "Restores 8d4+8 hit points. Rare and expensive.",
             type: .potion, weight: 1.0, value: 400,
             weaponStats: nil, armorStats: nil,
             potionStats: PotionStats(healAmount: "8d4+8", effect: "Restores 8d4+8 HP"))
    }

    /// Flavour potions — no mechanical heal (healAmount nil keeps them out of
    /// the combat/pack "Use" heal flow), just colour for the shop shelf and
    /// the "find" table. Not every item needs to be useful.
    static func potionOfFireResistance() -> Item {
        Item(id: UUID(), name: "Potion of Fire Resistance", description: "Smells of ash. Said to numb the skin against flame — untested by this party.",
             type: .potion, weight: 1.0, value: 60,
             weaponStats: nil, armorStats: nil,
             potionStats: PotionStats(healAmount: nil, effect: "Reputed fire resistance (untested)"))
    }

    static func elixirOfClarity() -> Item {
        Item(id: UUID(), name: "Elixir of Clarity", description: "A shimmering, faintly fizzing tonic. Mostly makes you feel very awake.",
             type: .potion, weight: 1.0, value: 20,
             weaponStats: nil, armorStats: nil,
             potionStats: PotionStats(healAmount: nil, effect: "Feel very awake"))
    }

    static func potionOfGiantStrength() -> Item {
        Item(id: UUID(), name: "Potion of Giant's Strength", description: "Thick as syrup and smells of the earth. Supposedly grants monstrous strength.",
             type: .potion, weight: 1.0, value: 250,
             weaponStats: nil, armorStats: nil,
             potionStats: PotionStats(healAmount: nil, effect: "Reputed monstrous strength (untested)"))
    }

    // MARK: Misc

    static func torch() -> Item {
        var t = Item(id: UUID(), name: "Torch", description: "Burns for about 12 hours.",
             type: .misc, weight: 1.0, value: 1,
             weaponStats: nil, armorStats: nil, potionStats: nil)
        t.torchLife = Item.torchFullLife
        return t
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

    static func whetstone() -> Item {
        Item(id: UUID(), name: "Whetstone", description: "Use it on your equipped weapon to sharpen the edge — a temporary +1 to attack and damage rolls.",
             type: .misc, weight: 1.0, value: 5,
             weaponStats: nil, armorStats: nil, potionStats: nil)
    }

    private static let keyFlavorNames = ["Rusty Key", "Bronze Key", "Iron Key", "Ornate Key", "Tarnished Key", "Small Brass Key"]

    /// Creates a key matching a specific locked door (Room.doorLockIds).
    static func key(forDoorId lockId: UUID) -> Item {
        let name = keyFlavorNames.randomElement()!
        var item = Item(id: UUID(), name: name, description: "An old key. It might fit a lock somewhere in this dungeon.",
                         type: .misc, weight: 1.0, value: 0,
                         weaponStats: nil, armorStats: nil, potionStats: nil)
        item.keyForDoorId = lockId
        return item
    }

    // MARK: Starting Equipment

    static func startingEquipmentOptions(for characterClass: CharacterClass) -> [(String, [Item])] {
        switch characterClass {
        case .fighter:
            return [
                ("Longsword + Chain Mail + Shield", [longsword(), chainMail(), shield(), healingPotion(), torch()]),
                ("Greataxe + Chain Mail", [greataxe(), chainMail(), healingPotion(), healingPotion(), torch()]),
                ("Two Handaxes + Scale Mail + Shield", [handaxe(), handaxe(), scaleMail(), shield(), healingPotion(), torch()]),
            ]
        case .wizard:
            return [
                ("Quarterstaff + Spell Components", [quarterstaff(), spellComponentPouch(), dagger(), healingPotion(), torch()]),
                ("Dagger + Spell Components + Extra Potions", [dagger(), spellComponentPouch(), healingPotion(), healingPotion(), torch()]),
            ]
        case .rogue:
            return [
                ("Rapier + Leather Armour + Thieves' Tools", [rapier(), leatherArmor(), thievesTools(), dagger(), healingPotion(), torch()]),
                ("Two Shortswords + Studded Leather", [shortsword(), shortsword(), studdedLeather(), thievesTools(), healingPotion(), torch()]),
            ]
        case .cleric:
            return [
                ("Mace + Scale Mail + Shield + Holy Symbol", [mace(), scaleMail(), shield(), holySymbol(), healingPotion(), torch()]),
                ("Mace + Chain Mail + Holy Symbol", [mace(), chainMail(), holySymbol(), healingPotion(), healingPotion(), torch()]),
            ]
        case .ranger:
            return [
                ("Longbow + Studded Leather + Shortsword", [longbow(), studdedLeather(), shortsword(), healingPotion(), torch()]),
                ("Two Shortswords + Scale Mail", [shortsword(), shortsword(), scaleMail(), healingPotion(), torch()]),
            ]
        case .barbarian:
            return [
                ("Greataxe + Two Handaxes", [greataxe(), handaxe(), handaxe(), healingPotion(), healingPotion(), torch()]),
                ("Two Handaxes + Leather Armor", [handaxe(), handaxe(), leatherArmor(), healingPotion(), healingPotion(), torch()]),
            ]
        }
    }

    // MARK: Shop Stock

    static func shopStock(forLevel level: Int) -> [Item] {
        var stock: [Item] = []

        // Always available
        stock.append(healingPotion())
        stock.append(healingPotion())
        stock.append(antidote())
        stock.append(torch())
        stock.append(rope())
        stock.append(whetstone())
        stock.append(dagger())
        stock.append(leatherArmor())
        stock.append(shortsword())
        stock.append(mace())
        stock.append(shield())
        stock.append(spear())
        stock.append(sling())
        stock.append(paddedArmor())
        stock.append(buckler())
        stock.append(elixirOfClarity())

        if level >= 2 {
            stock.append(greaterHealingPotion())
            stock.append(longsword())
            stock.append(scaleMail())
            stock.append(rapier())
            stock.append(studdedLeather())
            stock.append(longbow())
            stock.append(warhammer())
            stock.append(battleaxe())
            stock.append(scimitar())
            stock.append(lightCrossbow())
            stock.append(ringMail())
            stock.append(potionOfFireResistance())
        }

        if level >= 3 {
            stock.append(greaterHealingPotion())
            stock.append(chainMail())
            stock.append(greataxe())
            stock.append(whip())
            stock.append(trident())
            stock.append(potionOfGiantStrength())
        }

        if level >= 4 {
            stock.append(superiorHealingPotion())
            stock.append(plateArmor())
        }

        return stock
    }
}
