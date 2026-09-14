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
        case .engineer:
            return [
                ("Light Crossbow + Tinker's Tools + Leather Armour", [lightCrossbow(), thievesTools(), leatherArmor(), healingPotion(), torch()]),
                ("Dagger + Tinker's Tools + Extra Potions", [dagger(), thievesTools(), healingPotion(), healingPotion(), torch()]),
            ]
        case .scout:
            return [
                ("Longbow + Leather Armour + Shortsword", [longbow(), leatherArmor(), shortsword(), healingPotion(), torch()]),
                ("Shortsword + Studded Leather", [shortsword(), studdedLeather(), healingPotion(), healingPotion(), torch()]),
            ]
        case .thief:
            return [
                ("Dagger + Leather Armour + Thieves' Tools", [dagger(), leatherArmor(), thievesTools(), healingPotion(), torch()]),
                ("Rapier + Thieves' Tools + Extra Potions", [rapier(), thievesTools(), healingPotion(), healingPotion(), torch()]),
            ]
        }
    }

    // MARK: Shop Stock

    /// Every merchant used to carry the identical full list, so shops all
    /// felt the same. Now: a few essentials every shop has, a random slice
    /// of the level-appropriate gear pool, and a handful of everyday
    /// provisions. Rolled once per merchant and remembered (see
    /// ShopEngine.openShop), so each merchant keeps their own selection.
    static func shopStock(forLevel level: Int) -> [Item] {
        let essentials: [Item] = [healingPotion(), antidote(), torch()]

        var pool: [Item] = [healingPotion(), rope(), whetstone(), dagger(), leatherArmor(), shortsword(),
                            mace(), shield(), spear(), sling(), paddedArmor(), buckler(), elixirOfClarity()]
        if level >= 2 {
            pool += [greaterHealingPotion(), longsword(), scaleMail(), rapier(), studdedLeather(), longbow(),
                     warhammer(), battleaxe(), scimitar(), lightCrossbow(), ringMail(), potionOfFireResistance()]
        }
        if level >= 3 {
            pool += [greaterHealingPotion(), chainMail(), greataxe(), whip(), trident(), potionOfGiantStrength()]
        }
        if level >= 4 {
            pool += [superiorHealingPotion(), plateArmor()]
        }

        let gearCount = min(pool.count, 7 + level * 2)
        let gear = Array(pool.shuffled().prefix(gearCount))
        // Always a few cheeses (players asked for a proper cheese counter),
        // plus a handful of other everyday goods.
        let goods = Array(everydayProvisions().shuffled().prefix(Int.random(in: 2...3)))
            + Array(cheeses().shuffled().prefix(Int.random(in: 2...3)))
        return essentials + gear + goods
    }

    // MARK: Provisions — everyday goods, for variety between merchants

    private static func food(_ name: String, _ desc: String, value: Int, weight: Double, heal: String?, effect: String) -> Item {
        Item(id: UUID(), name: name, description: desc, type: .potion, weight: weight, value: value,
             weaponStats: nil, armorStats: nil,
             potionStats: PotionStats(healAmount: heal, effect: effect))
    }

    /// Every food and drink a merchant might sell (everyday goods + cheeses).
    static func provisions() -> [Item] { everydayProvisions() + cheeses() }

    static func everydayProvisions() -> [Item] {
        [
            food("Jar of Honey", "Golden and thick, from hives at the dungeon's edge.", value: 3, weight: 1.0, heal: "1d4", effect: "Restores 1d4 HP + a sugary lift (2 temp HP)"),
            food("Pot of Jam", "Blackberry, with the odd seed.", value: 2, weight: 1.0, heal: "1d2", effect: "Restores 1d2 HP + a sugary lift (2 temp HP)"),
            food("Jar of Marmite", "Dark, salty and divisive. You either love it or hate it.", value: 2, weight: 0.5, heal: "1d3", effect: "Restores 1d3 HP (if you can stomach it)"),
            food("Flask of Apple Juice", "Cloudy, pressed from orchard apples.", value: 2, weight: 1.0, heal: "1d3", effect: "Restores 1d3 HP. Too much juice slows you down!"),
            food("Bottle of Elderflower Cordial", "Fizzy, floral and faintly posh.", value: 3, weight: 1.0, heal: "1d3", effect: "Restores 1d3 HP. Too much juice slows you down!"),
            food("Waterskin", "Clean water — worth more than gold in the deep dark.", value: 1, weight: 2.0, heal: "1d2", effect: "Restores 1d2 HP; settles a sloshing belly"),
            food("Loaf of Bread", "Crusty, a day or two old.", value: 1, weight: 0.5, heal: "1d3", effect: "Restores 1d3 HP"),
            food("Bag of Apples", "Crisp, if slightly bruised.", value: 1, weight: 1.0, heal: "1d2", effect: "Restores 1d2 HP"),
            food("Salt Pork", "Tough, salty trail rations.", value: 2, weight: 1.0, heal: "1d4", effect: "Restores 1d4 HP; you feel strong (+1 attack/damage, 2 attacks)"),
            food("Pot of Tea", "Strong enough to stand a spoon in.", value: 1, weight: 0.5, heal: nil, effect: "Feel refreshed; settles a sloshing belly"),
        ]
    }

    /// A merchant always has a few of these — cheese is hearty food.
    static func cheeses() -> [Item] {
        [
            food("Wheel of Cheese", "Pungent. Very pungent.", value: 5, weight: 2.0, heal: "1d6", effect: "Restores 1d6 HP; you feel strong (+1 attack/damage, 3 attacks)"),
            food("Wedge of Cheddar", "Sharp and crumbly, aged in a cave.", value: 3, weight: 0.5, heal: "1d4", effect: "Restores 1d4 HP; you feel strong (+1 attack/damage, 2 attacks)"),
            food("Slice of Wensleydale", "Mild and crumbly — goes well with cake, apparently.", value: 3, weight: 0.5, heal: "1d4", effect: "Restores 1d4 HP; you feel strong (+1 attack/damage, 2 attacks)"),
            food("Round of Brie", "Soft, runny, and best eaten before it walks off.", value: 4, weight: 0.5, heal: "1d4", effect: "Restores 1d4 HP; you feel strong (+1 attack/damage, 2 attacks)"),
            food("Goat's Cheese Log", "Tangy. The goat seemed very proud of it.", value: 3, weight: 0.5, heal: "1d3", effect: "Restores 1d3 HP; you feel strong (+1 attack/damage, 2 attacks)"),
            food("Smoked Gouda", "Red wax rind, smoky inside.", value: 4, weight: 1.0, heal: "1d4", effect: "Restores 1d4 HP; you feel strong (+1 attack/damage, 2 attacks)"),
            food("Blue Stilton", "Veined with blue — the mould is supposed to be there.", value: 6, weight: 1.0, heal: "1d6", effect: "Restores 1d6 HP; you feel strong (+1 attack/damage, 3 attacks)"),
            food("Block of Halloumi", "Squeaks when you bite it.", value: 4, weight: 0.5, heal: "1d4", effect: "Restores 1d4 HP; you feel strong (+1 attack/damage, 2 attacks)"),
        ]
    }

    /// Obscure foods a merchant only brings out from under the counter.
    static func rareFoods() -> [Item] {
        [
            food("Stinking Bishop", "A cheese washed in pear juice. Smells like the inside of a boot.", value: 20, weight: 1.0, heal: "1d8", effect: "Restores 1d8 HP; you feel mighty (+1 attack/damage, 4 attacks)"),
            food("Pickled Eel", "It wriggles slightly on the way down.", value: 12, weight: 1.0, heal: "1d6", effect: "Restores 1d6 HP; oddly invigorating (+1 attack/damage, 3 attacks)"),
            food("Black Truffle", "Earthy, knobbly, and worth more than its weight in silver.", value: 25, weight: 0.5, heal: "1d8", effect: "Restores 1d8 HP; you feel strong (+1 attack/damage, 3 attacks)"),
            food("Owlbear Jerky", "Chewy enough to count as a workout.", value: 18, weight: 1.0, heal: "1d6", effect: "Restores 1d6 HP; you feel mighty (+1 attack/damage, 4 attacks)"),
            food("Cave Mushroom Pie", "Glows faintly. The baker swears that's normal.", value: 10, weight: 1.0, heal: "1d6", effect: "Restores 1d6 HP; you feel strong (+1 attack/damage, 3 attacks)"),
            food("Highland Haggis", "Best not to ask what's in it.", value: 16, weight: 2.0, heal: "1d8", effect: "Restores 1d8 HP; you feel strong (+1 attack/damage, 3 attacks)"),
            food("Dragonfruit", "Bright pink outside, speckled inside.", value: 15, weight: 1.0, heal: "1d8", effect: "Restores 1d8 HP; tastes faintly of sparks"),
            food("Durian", "Spiky, and it smells like a troll's sock.", value: 14, weight: 2.0, heal: "1d8", effect: "Restores 1d8 HP — if you can get past the smell"),
            food("Candied Violets", "Crystallised flowers in a tiny tin.", value: 12, weight: 0.2, heal: "1d4", effect: "Restores 1d4 HP + a sugary lift (2 temp HP)"),
            food("Frost Giant Ice Cream", "Somehow still frozen. Don't ask how.", value: 12, weight: 1.0, heal: "1d6", effect: "Restores 1d6 HP + a sugary lift (2 temp HP)"),
            food("Salted Liquorice", "Black, salty, and deeply suspicious.", value: 6, weight: 0.2, heal: "1d3", effect: "Restores 1d3 HP (love it or hate it)"),
            food("Jar of Pickled Onions", "Eye-wateringly sharp.", value: 6, weight: 1.0, heal: "1d3", effect: "Restores 1d3 HP; your breath could now strip paint"),
            food("Gnomish Fizzy Pop", "Violently fizzy. Counts double on the slosh-o-meter.", value: 8, weight: 1.0, heal: "1d4", effect: "Restores 1d4 HP. Very sloshy — too much slows you down!"),
        ]
    }

    // MARK: Food effects

    /// What eating/drinking a named food or drink does, beyond its dice of
    /// HP. Looked up by name so items already sitting in old saves (which
    /// carry their own copy of the item) keep working.
    private static let foodKinds: [String: FoodKind] = [
        "Jar of Honey": .sweet, "Pot of Jam": .sweet,
        "Candied Violets": .sweet, "Frost Giant Ice Cream": .sweet,
        "Jar of Marmite": .divisive, "Salted Liquorice": .divisive,
        "Flask of Apple Juice": .juice(glasses: 1), "Bottle of Elderflower Cordial": .juice(glasses: 1),
        "Flask of Mead": .juice(glasses: 1),   // legacy name — renamed on load
        "Gnomish Fizzy Pop": .juice(glasses: 2),
        "Waterskin": .refreshing, "Pot of Tea": .refreshing,
        "Loaf of Bread": .plain, "Bag of Apples": .plain,
        "Salt Pork": .hearty(attacks: 2),
        "Wheel of Cheese": .hearty(attacks: 3), "Blue Stilton": .hearty(attacks: 3),
        "Wedge of Cheddar": .hearty(attacks: 2), "Slice of Wensleydale": .hearty(attacks: 2),
        "Round of Brie": .hearty(attacks: 2), "Goat's Cheese Log": .hearty(attacks: 2),
        "Smoked Gouda": .hearty(attacks: 2), "Block of Halloumi": .hearty(attacks: 2),
        "Stinking Bishop": .hearty(attacks: 4), "Owlbear Jerky": .hearty(attacks: 4),
        "Black Truffle": .hearty(attacks: 3), "Cave Mushroom Pie": .hearty(attacks: 3),
        "Highland Haggis": .hearty(attacks: 3),
        "Pickled Eel": .strange(line: "It wriggles slightly on the way down. Oddly invigorating!", attacks: 3),
        "Dragonfruit": .strange(line: "Tastes faintly of sparks. Your hair stands on end for a moment.", attacks: 0),
        "Durian": .strange(line: "Smells like a troll's sock, tastes like custard. The party edges away.", attacks: 0),
        "Jar of Pickled Onions": .strange(line: "Eye-watering! Your breath could now strip paint.", attacks: 0),
    ]

    static func foodKind(for item: Item) -> FoodKind? {
        guard item.type == .potion else { return nil }
        return foodKinds[item.name]
    }

    /// "drinks" for juices/water/tea (and ordinary potions), "eats" for food.
    static func consumeVerb(for item: Item) -> String {
        switch foodKind(for: item) {
        case .none, .juice, .refreshing: return "drinks"
        default: return "eats"
        }
    }

    /// Old saves may still carry a "Flask of Mead" — swap it for the
    /// age-appropriate juice it has become.
    static func migrateLegacyFood(_ item: Item) -> Item {
        guard item.name == "Flask of Mead", item.type == .potion else { return item }
        return everydayProvisions().first { $0.name == "Flask of Apple Juice" } ?? item
    }
}

/// What a food or drink does when used, on top of the HP it restores.
enum FoodKind {
    case plain                                  // just the HP
    case hearty(attacks: Int)                   // feel strong: +1 attack & damage for N attacks
    case sweet                                  // sugary lift: 2 temporary HP
    case juice(glasses: Int)                    // 3+ glasses → sloshing and sluggish
    case refreshing                             // water/tea: settles a sloshing belly
    case divisive                               // love it or hate it
    case strange(line: String, attacks: Int)    // odd under-the-counter foods
}
