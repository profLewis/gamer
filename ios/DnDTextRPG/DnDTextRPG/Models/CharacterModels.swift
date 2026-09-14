//
//  CharacterModels.swift
//  DnDTextRPG
//
//  D&D 5e character models
//

import Foundation

// MARK: - Ability Scores

enum Ability: String, CaseIterable, Codable {
    case strength = "Strength"
    case dexterity = "Dexterity"
    case constitution = "Constitution"
    case intelligence = "Intelligence"
    case wisdom = "Wisdom"
    case charisma = "Charisma"

    var abbreviation: String {
        switch self {
        case .strength: return "STR"
        case .dexterity: return "DEX"
        case .constitution: return "CON"
        case .intelligence: return "INT"
        case .wisdom: return "WIS"
        case .charisma: return "CHA"
        }
    }
}

struct AbilityScores: Codable {
    var strength: Int
    var dexterity: Int
    var constitution: Int
    var intelligence: Int
    var wisdom: Int
    var charisma: Int

    static let standardArray = [15, 14, 13, 12, 10, 8]

    func score(for ability: Ability) -> Int {
        switch ability {
        case .strength: return strength
        case .dexterity: return dexterity
        case .constitution: return constitution
        case .intelligence: return intelligence
        case .wisdom: return wisdom
        case .charisma: return charisma
        }
    }

    func modifier(for ability: Ability) -> Int {
        return (score(for: ability) - 10) / 2
    }

    mutating func set(_ ability: Ability, to value: Int) {
        switch ability {
        case .strength: strength = value
        case .dexterity: dexterity = value
        case .constitution: constitution = value
        case .intelligence: intelligence = value
        case .wisdom: wisdom = value
        case .charisma: charisma = value
        }
    }
}

// MARK: - Race

enum Race: String, CaseIterable, Codable {
    case human = "Human"
    case highElf = "High Elf"
    case woodElf = "Wood Elf"
    case hillDwarf = "Hill Dwarf"
    case mountainDwarf = "Mountain Dwarf"
    case lightfootHalfling = "Lightfoot Halfling"
    case stoutHalfling = "Stout Halfling"
    case halfElf = "Half-Elf"
    case halfOrc = "Half-Orc"
    case gnome = "Rock Gnome"
    case tiefling = "Tiefling"
    case dragonborn = "Dragonborn"

    var abilityBonuses: [(Ability, Int)] {
        switch self {
        case .human:
            return Ability.allCases.map { ($0, 1) }
        case .highElf, .woodElf:
            return [(.dexterity, 2), (.intelligence, 1)]
        case .hillDwarf:
            return [(.constitution, 2), (.wisdom, 1)]
        case .mountainDwarf:
            return [(.constitution, 2), (.strength, 2)]
        case .lightfootHalfling:
            return [(.dexterity, 2), (.charisma, 1)]
        case .stoutHalfling:
            return [(.dexterity, 2), (.constitution, 1)]
        case .halfElf:
            return [(.charisma, 2)]  // Plus 2 others of choice
        case .halfOrc:
            return [(.strength, 2), (.constitution, 1)]
        case .gnome:
            return [(.intelligence, 2), (.constitution, 1)]
        case .tiefling:
            return [(.charisma, 2), (.intelligence, 1)]
        case .dragonborn:
            return [(.strength, 2), (.charisma, 1)]
        }
    }

}

// MARK: - Class

enum CharacterClass: String, CaseIterable, Codable {
    case fighter = "Fighter"
    case wizard = "Wizard"
    case rogue = "Rogue"
    case cleric = "Cleric"
    case ranger = "Ranger"
    case barbarian = "Barbarian"
    case engineer = "Engineer"
    case scout = "Scout"
    case thief = "Thief"

    var hitDie: Int {
        switch self {
        case .barbarian: return 12
        case .fighter, .ranger: return 10
        case .cleric, .rogue, .engineer, .scout, .thief: return 8
        case .wizard: return 6
        }
    }

    var primaryAbility: Ability {
        switch self {
        case .fighter, .barbarian: return .strength
        case .wizard, .engineer: return .intelligence
        case .rogue, .ranger, .scout, .thief: return .dexterity
        case .cleric: return .wisdom
        }
    }

    /// A class+level rank title — the visible "you've grown" marker for a
    /// text-based game (no portrait to put a hat on, so the title does that
    /// job). Levels 1-5 only, matching the current level cap.
    func rankTitle(atLevel level: Int) -> String {
        let titles: [String]
        switch self {
        case .fighter:   titles = ["Recruit", "Soldier", "Warrior", "Veteran", "Champion"]
        case .wizard:    titles = ["Apprentice", "Adept", "Conjurer", "Magus", "Archmage"]
        case .rogue:     titles = ["Footpad", "Cutpurse", "Infiltrator", "Shadowblade", "Master Thief"]
        case .cleric:    titles = ["Acolyte", "Curate", "Priest", "High Priest", "Hierophant"]
        case .ranger:    titles = ["Tracker", "Pathfinder", "Warden", "Ranger-Captain", "Wildkeeper"]
        case .barbarian: titles = ["Brawler", "Berserker", "Reaver", "Warchief", "Juggernaut"]
        case .engineer:  titles = ["Tinkerer", "Mechanist", "Artificer", "Machinist", "Grand Engineer"]
        case .scout:     titles = ["Wayfinder", "Trailblazer", "Outrider", "Vanguard", "Pathlord"]
        case .thief:     titles = ["Sneak", "Prowler", "Fence", "Cat Burglar", "Shadow Lord"]
        }
        let idx = max(0, min(titles.count - 1, level - 1))
        return titles[idx]
    }

    /// Optimal ability score assignment order for auto-assign
    var abilityPriority: [Ability] {
        switch self {
        case .fighter:   return [.strength, .constitution, .dexterity, .wisdom, .charisma, .intelligence]
        case .barbarian: return [.strength, .constitution, .dexterity, .wisdom, .charisma, .intelligence]
        case .wizard:    return [.intelligence, .dexterity, .constitution, .wisdom, .charisma, .strength]
        case .rogue:     return [.dexterity, .constitution, .wisdom, .charisma, .intelligence, .strength]
        case .cleric:    return [.wisdom, .constitution, .strength, .charisma, .dexterity, .intelligence]
        case .ranger:    return [.dexterity, .wisdom, .constitution, .strength, .charisma, .intelligence]
        case .engineer:  return [.intelligence, .dexterity, .constitution, .wisdom, .charisma, .strength]
        case .scout:     return [.dexterity, .wisdom, .constitution, .strength, .intelligence, .charisma]
        case .thief:     return [.dexterity, .charisma, .constitution, .wisdom, .intelligence, .strength]
        }
    }

    var skillChoices: [Skill] {
        switch self {
        case .fighter:
            return [.acrobatics, .animalHandling, .athletics, .history, .insight, .intimidation, .perception, .survival]
        case .wizard:
            return [.arcana, .history, .insight, .investigation, .medicine, .religion]
        case .rogue:
            return [.acrobatics, .athletics, .deception, .insight, .intimidation, .investigation, .perception, .performance, .persuasion, .sleightOfHand, .stealth]
        case .cleric:
            return [.history, .insight, .medicine, .persuasion, .religion]
        case .ranger:
            return [.animalHandling, .athletics, .insight, .investigation, .nature, .perception, .stealth, .survival]
        case .barbarian:
            return [.animalHandling, .athletics, .intimidation, .nature, .perception, .survival]
        case .engineer:
            return [.arcana, .history, .investigation, .perception, .sleightOfHand]
        case .scout:
            return [.athletics, .insight, .investigation, .nature, .perception, .stealth, .survival]
        case .thief:
            return [.deception, .insight, .intimidation, .performance, .persuasion, .sleightOfHand, .stealth]
        }
    }

    var numSkillChoices: Int {
        switch self {
        case .rogue, .thief: return 4
        case .ranger, .scout, .engineer: return 3
        default: return 2
        }
    }

    var startingHP: Int {
        return hitDie
    }

    // MARK: - Reliability (class-flavoured edge at Search / Map / Negotiate)

    /// Willpower Surge: a timed on-screen prompt to resist an enemy's
    /// mind-control attack the instant it's cast, instead of an automatic
    /// saving throw — a Cleric's faith or a Wizard's trained mental
    /// discipline pushing back against it (this roster has no Paladin or
    /// Sorcerer; these two are the closest existing divine/arcane-willpower
    /// analogues). Limited like Second Wind/Rage, restored on long rest
    /// (see Character.willpowerSurgeUsesRemaining).
    var willpowerSurgeMaxUses: Int {
        switch self {
        case .cleric, .wizard: return 1
        default: return 0
        }
    }

    /// Bonus to Search Room's Perception check — mechanically-minded classes
    /// are better at spotting traps and hidden compartments.
    var searchReliability: Int {
        switch self {
        case .rogue, .engineer: return 2
        default: return 0
        }
    }

    /// Whether this class extends the party's effective map visibility
    /// radius (see GameEngine.effectiveMapRadius) — reconnaissance,
    /// pathfinding, or arcane sense of the dungeon's layout.
    var mapReliability: Int {
        switch self {
        case .wizard, .ranger, .scout: return 2
        default: return 0
        }
    }

    /// Bonus applied to haggling (reduces the effective DC) — classes with
    /// a trusted, persuasive, or street-smart edge negotiate better deals.
    var negotiateReliability: Int {
        switch self {
        case .cleric, .thief: return 2
        default: return 0
        }
    }

    var asciiArt: [String] {
        switch self {
        case .fighter:
            return [
                "  o  ",
                " /|\\=+>",
                " / \\",
                "[===]",
            ]
        case .wizard:
            return [
                " /\\",
                " /~~\\",
                "  o",
                " /|\\*",
                " / \\",
            ]
        case .rogue:
            return [
                "  o",
                " /|\\",
                " /|  >>",
                " / \\",
            ]
        case .cleric:
            return [
                "  +",
                "  o",
                " /|\\",
                " [+]",
                " / \\",
            ]
        case .ranger:
            return [
                "  o",
                " /|\\",
                " )| \\>",
                " / \\",
            ]
        case .barbarian:
            return [
                "  o",
                " /|\\",
                "=||=",
                " /  \\",
            ]
        case .engineer:
            return [
                " [o]",
                " /|\\+",
                " /|\\",
                " / \\",
            ]
        case .scout:
            return [
                "  o",
                " /|\\",
                " )|\\\\",
                " / \\",
            ]
        case .thief:
            return [
                "  o",
                " /|\\",
                " /|>",
                " / \\",
            ]
        }
    }

    /// Animation frames for idle weapon display (2 frames each)
    var asciiArtFrames: [[String]] {
        switch self {
        case .fighter:
            return [
                ["  o  ", " /|\\=+>", " / \\", "[===]"],       // sword forward
                ["  o  ", "<+=|/", "   / \\", "  [===]"],       // sword pulled back
                ["  o  ", " /|\\  +>", " / \\", "[===]"],       // mid-swing
            ]
        case .wizard:
            return [
                [" /\\", " /~~\\", "  o", " /|\\*", " / \\"],   // casting
                [" /\\", " /~~\\", "  o", " /|\\  *", " / \\"], // spark out
                [" /\\", " /~~\\", "  o", " /|\\✦", " / \\"],   // spell ready
            ]
        case .rogue:
            return [
                ["  o", " /|\\", " /|  >>", " / \\"],           // dagger ready
                ["  o", " /|\\     >>", " /|", " / \\"],        // dagger thrown!
                ["  o", " /|\\", " /|>>", " / \\"],             // caught it
            ]
        case .cleric:
            return [
                ["  +", "  o", " /|\\", " [+]", " / \\"],       // praying
                ["  ✦", "  o", " /|\\", " [+]", " / \\"],       // blessing
                ["  +", "  o", " \\|/", " [+]", " / \\"],       // arms wide
            ]
        case .ranger:
            return [
                ["  o", " /|\\", " )| \\>", " / \\"],           // aim
                ["  o", " /|\\", " )|   --->", " / \\"],        // fire!
                ["  o", " /|\\", " )|\\", " / \\"],              // reload
            ]
        case .barbarian:
            return [
                ["  o", " /|\\", "=||=", " /  \\"],             // ready
                ["  o", "  |\\", "  || =>>", " /  \\"],         // swing!
                ["  o", " /|", "<<= ||", "   /  \\"],           // backswing
            ]
        case .engineer:
            return [
                [" [o]", " /|\\+", " /|\\", " / \\"],           // tinkering
                [" [o]", " /|\\*", " /|\\", " / \\"],           // spark!
                [" [o]", " /|\\+", " /|\\ ✦", " / \\"],         // gadget ready
            ]
        case .scout:
            return [
                ["  o", " /|\\", " )|\\\\", " / \\"],           // scanning
                ["  o", " /|\\", " )|  \\\\", " / \\"],         // spotted something
                ["  o", " /|\\", " )|\\\\", " / \\"],           // steady
            ]
        case .thief:
            return [
                ["  o", " /|\\", " /|>", " / \\"],              // lurking
                ["  o", " /|\\  >", " /|", " / \\"],            // snatch!
                ["  o", " /|\\", " /|>", " / \\"],              // vanished
            ]
        }
    }
}

// MARK: - Skills

enum Skill: String, CaseIterable, Codable {
    case acrobatics = "Acrobatics"
    case animalHandling = "Animal Handling"
    case arcana = "Arcana"
    case athletics = "Athletics"
    case deception = "Deception"
    case history = "History"
    case insight = "Insight"
    case intimidation = "Intimidation"
    case investigation = "Investigation"
    case medicine = "Medicine"
    case nature = "Nature"
    case perception = "Perception"
    case performance = "Performance"
    case persuasion = "Persuasion"
    case religion = "Religion"
    case sleightOfHand = "Sleight of Hand"
    case stealth = "Stealth"
    case survival = "Survival"

    var ability: Ability {
        switch self {
        case .athletics:
            return .strength
        case .acrobatics, .sleightOfHand, .stealth:
            return .dexterity
        case .arcana, .history, .investigation, .nature, .religion:
            return .intelligence
        case .animalHandling, .insight, .medicine, .perception, .survival:
            return .wisdom
        case .deception, .intimidation, .performance, .persuasion:
            return .charisma
        }
    }
}

// MARK: - Glyphkeeper (Ethical Alignment)

/// A character's tracked moral standing, derived from their running
/// `ethicalScore` (-100...100). Named bands rather than a raw number so the
/// DM, character sheet, and NPC reactions can all talk about it consistently.
enum EthicalAlignment: String, CaseIterable {
    case villainous = "Villainous"
    case selfish = "Selfish"
    case neutral = "Neutral"
    case kind = "Kind"
    case heroic = "Heroic"

    static func forScore(_ score: Int) -> EthicalAlignment {
        switch score {
        case ..<(-60): return .villainous
        case -60 ..< -20: return .selfish
        case -20...20: return .neutral
        case 21..<60: return .kind
        default: return .heroic
        }
    }

    var summary: String {
        switch self {
        case .villainous: return "Known for cruelty and self-interest above all else."
        case .selfish: return "Looks out for themself first, others second."
        case .neutral: return "No strong reputation either way."
        case .kind: return "Known for fairness and looking out for others."
        case .heroic: return "Known for selfless courage and mercy."
        }
    }
}

// MARK: - Character

class Character: ObservableObject, Identifiable, Codable {
    let id: UUID
    @Published var name: String
    @Published var race: Race
    @Published var characterClass: CharacterClass
    @Published var level: Int
    @Published var abilityScores: AbilityScores
    @Published var currentHP: Int
    @Published var maxHP: Int
    @Published var tempHP: Int
    @Published var skillProficiencies: Set<Skill>
    @Published var experiencePoints: Int
    @Published var gold: Int

    // Combat state
    @Published var isConscious: Bool
    @Published var deathSaveSuccesses: Int
    @Published var deathSaveFailures: Int

    // Inventory & equipment
    @Published var inventory: [Item]
    @Published var equippedWeapon: Item?
    @Published var equippedArmor: Item?
    @Published var equippedShield: Item?

    // Spellcasting
    @Published var knownSpells: [Spell]
    @Published var spellSlots: SpellSlots

    // Class features
    @Published var secondWindUsed: Bool      // Fighter: 1/short rest
    @Published var rageUsesRemaining: Int    // Barbarian: uses per long rest
    @Published var isRaging: Bool            // Barbarian: currently raging
    @Published var huntersMarkActive: Bool   // Ranger: bonus damage active
    @Published var weaponSharpenedUses: Int  // Whetstone: +1 to hit/damage for this many attacks
    @Published var wellFedAttacks: Int = 0   // Hearty food: +1 to hit/damage for this many attacks
    @Published var juiceCount: Int = 0       // Glasses of juice since the last rest/water/tea
    @Published var sluggishAttacks: Int = 0  // Too much juice: disadvantage on this many attacks
    /// Spells whose true incantation this character has learned (arcane
    /// gyms) — spoken right every time, so no incantation choice.
    @Published var knownIncantations: Set<String> = []

    // AI control
    @Published var isComputerControlled: Bool

    // Status effects
    @Published var isPoisoned: Bool
    @Published var poisonDamagePerTurn: Int
    @Published var poisonTurnsRemaining: Int
    @Published var isPlayingDead: Bool       // Pretending to be dead in combat
    @Published var hasFledCombat: Bool       // Has fled this combat
    @Published var isDodging: Bool           // Took Dodge action — attackers have disadvantage
    @Published var isMindControlled: Bool = false      // Lost their turn to an enemy's mind-control attack
    @Published var mindControlTurnsRemaining: Int = 0
    @Published var willpowerSurgeImmuneTurns: Int = 0  // Grace window right after a successful Willpower Surge resist
    // Willpower Surge: Paladin/Sorcerer reactive ability — a timed on-screen
    // prompt to resist an enemy's mind-control attack the instant it's cast,
    // rather than an automatic saving throw. Limited like Second Wind/Rage
    // (see willpowerSurgeMaxUses below), restored on long rest.
    @Published var willpowerSurgeUsesRemaining: Int = 0

    // Familiar — a small companion, currently cosmetic/flavour only (shown
    // on the character card and in status), earned as a quest reward
    @Published var familiarName: String?
    @Published var familiarType: String?

    // Glyphkeeper — running ethical/alignment tracking. A single -100...100
    // score (Villainous...Heroic) shifted by tracked in-game choices, with a
    // short rolling log of what shifted it — the "memory" the AI DM reads to
    // keep narration and NPC reactions consistent with who this character has
    // actually been over the campaign, not just this one scene.
    @Published var ethicalScore: Int = 0
    @Published var ethicalLog: [String] = []   // most recent first, capped

    enum CodingKeys: String, CodingKey {
        case id, name, race, characterClass, level, abilityScores
        case currentHP, maxHP, tempHP, skillProficiencies, experiencePoints, gold
        case isConscious, deathSaveSuccesses, deathSaveFailures
        case inventory, equippedWeapon, equippedArmor, equippedShield
        case knownSpells, spellSlots
        case secondWindUsed, rageUsesRemaining, isRaging, huntersMarkActive, weaponSharpenedUses
        case isComputerControlled
        case isPoisoned, poisonDamagePerTurn, poisonTurnsRemaining
        case familiarName, familiarType
        case ethicalScore, ethicalLog
        case willpowerSurgeUsesRemaining
        case wellFedAttacks, juiceCount, sluggishAttacks
        case knownIncantations
    }

    init(name: String, race: Race, characterClass: CharacterClass, abilityScores: AbilityScores, isComputerControlled: Bool = false) {
        self.id = UUID()
        self.name = name
        self.race = race
        self.characterClass = characterClass
        self.level = 1
        self.abilityScores = abilityScores
        self.skillProficiencies = []
        self.experiencePoints = 0
        self.gold = 0
        self.isConscious = true
        self.deathSaveSuccesses = 0
        self.deathSaveFailures = 0
        self.tempHP = 0
        self.inventory = []
        self.equippedWeapon = nil
        self.equippedArmor = nil
        self.equippedShield = nil
        self.isComputerControlled = isComputerControlled

        // Spellcasting
        self.knownSpells = SpellCatalog.startingSpells(for: characterClass)
        self.spellSlots = SpellCatalog.startingSlots(for: characterClass, level: 1)

        // Class features
        self.secondWindUsed = false
        self.rageUsesRemaining = characterClass == .barbarian ? 2 : 0
        self.isRaging = false
        self.huntersMarkActive = false
        self.weaponSharpenedUses = 0

        // Status effects
        self.isPoisoned = false
        self.poisonDamagePerTurn = 0
        self.poisonTurnsRemaining = 0
        self.isPlayingDead = false
        self.hasFledCombat = false
        self.isDodging = false
        self.familiarName = nil
        self.familiarType = nil
        self.willpowerSurgeUsesRemaining = characterClass.willpowerSurgeMaxUses

        // Calculate starting HP
        let conMod = abilityScores.modifier(for: .constitution)
        let startingHP = characterClass.startingHP + conMod
        self.maxHP = startingHP
        self.currentHP = startingHP
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        race = try container.decode(Race.self, forKey: .race)
        characterClass = try container.decode(CharacterClass.self, forKey: .characterClass)
        level = try container.decode(Int.self, forKey: .level)
        abilityScores = try container.decode(AbilityScores.self, forKey: .abilityScores)
        currentHP = try container.decode(Int.self, forKey: .currentHP)
        maxHP = try container.decode(Int.self, forKey: .maxHP)
        tempHP = try container.decode(Int.self, forKey: .tempHP)
        skillProficiencies = try container.decode(Set<Skill>.self, forKey: .skillProficiencies)
        experiencePoints = try container.decode(Int.self, forKey: .experiencePoints)
        gold = try container.decode(Int.self, forKey: .gold)
        isConscious = try container.decode(Bool.self, forKey: .isConscious)
        deathSaveSuccesses = try container.decode(Int.self, forKey: .deathSaveSuccesses)
        deathSaveFailures = try container.decode(Int.self, forKey: .deathSaveFailures)
        inventory = ((try? container.decode([Item].self, forKey: .inventory)) ?? []).map(ItemCatalog.migrateLegacyFood)
        equippedWeapon = try? container.decodeIfPresent(Item.self, forKey: .equippedWeapon)
        equippedArmor = try? container.decodeIfPresent(Item.self, forKey: .equippedArmor)
        equippedShield = try? container.decodeIfPresent(Item.self, forKey: .equippedShield)

        // Spellcasting (backward compatible)
        knownSpells = (try? container.decodeIfPresent([Spell].self, forKey: .knownSpells)) ?? []
        spellSlots = (try? container.decodeIfPresent(SpellSlots.self, forKey: .spellSlots)) ?? SpellSlots()

        // Class features (backward compatible)
        secondWindUsed = (try? container.decodeIfPresent(Bool.self, forKey: .secondWindUsed)) ?? false
        rageUsesRemaining = (try? container.decodeIfPresent(Int.self, forKey: .rageUsesRemaining)) ?? 0
        isRaging = (try? container.decodeIfPresent(Bool.self, forKey: .isRaging)) ?? false
        huntersMarkActive = (try? container.decodeIfPresent(Bool.self, forKey: .huntersMarkActive)) ?? false
        weaponSharpenedUses = (try? container.decodeIfPresent(Int.self, forKey: .weaponSharpenedUses)) ?? 0
        isComputerControlled = (try? container.decodeIfPresent(Bool.self, forKey: .isComputerControlled)) ?? false
        isPoisoned = (try? container.decodeIfPresent(Bool.self, forKey: .isPoisoned)) ?? false
        poisonDamagePerTurn = (try? container.decodeIfPresent(Int.self, forKey: .poisonDamagePerTurn)) ?? 0
        poisonTurnsRemaining = (try? container.decodeIfPresent(Int.self, forKey: .poisonTurnsRemaining)) ?? 0
        isPlayingDead = false
        hasFledCombat = false
        isDodging = false
        familiarName = (try? container.decodeIfPresent(String.self, forKey: .familiarName)) ?? nil
        familiarType = (try? container.decodeIfPresent(String.self, forKey: .familiarType)) ?? nil
        ethicalScore = (try? container.decodeIfPresent(Int.self, forKey: .ethicalScore)) ?? 0
        ethicalLog = (try? container.decodeIfPresent([String].self, forKey: .ethicalLog)) ?? []
        willpowerSurgeUsesRemaining = (try? container.decodeIfPresent(Int.self, forKey: .willpowerSurgeUsesRemaining)) ?? characterClass.willpowerSurgeMaxUses
        wellFedAttacks = (try? container.decodeIfPresent(Int.self, forKey: .wellFedAttacks)) ?? 0
        juiceCount = (try? container.decodeIfPresent(Int.self, forKey: .juiceCount)) ?? 0
        sluggishAttacks = (try? container.decodeIfPresent(Int.self, forKey: .sluggishAttacks)) ?? 0
        knownIncantations = (try? container.decodeIfPresent(Set<String>.self, forKey: .knownIncantations)) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(race, forKey: .race)
        try container.encode(characterClass, forKey: .characterClass)
        try container.encode(level, forKey: .level)
        try container.encode(abilityScores, forKey: .abilityScores)
        try container.encode(currentHP, forKey: .currentHP)
        try container.encode(maxHP, forKey: .maxHP)
        try container.encode(tempHP, forKey: .tempHP)
        try container.encode(skillProficiencies, forKey: .skillProficiencies)
        try container.encode(experiencePoints, forKey: .experiencePoints)
        try container.encode(gold, forKey: .gold)
        try container.encode(isConscious, forKey: .isConscious)
        try container.encode(deathSaveSuccesses, forKey: .deathSaveSuccesses)
        try container.encode(deathSaveFailures, forKey: .deathSaveFailures)
        try container.encode(inventory, forKey: .inventory)
        try container.encodeIfPresent(equippedWeapon, forKey: .equippedWeapon)
        try container.encodeIfPresent(equippedArmor, forKey: .equippedArmor)
        try container.encodeIfPresent(equippedShield, forKey: .equippedShield)
        try container.encode(knownSpells, forKey: .knownSpells)
        try container.encode(spellSlots, forKey: .spellSlots)
        try container.encode(secondWindUsed, forKey: .secondWindUsed)
        try container.encode(rageUsesRemaining, forKey: .rageUsesRemaining)
        try container.encode(isRaging, forKey: .isRaging)
        try container.encode(huntersMarkActive, forKey: .huntersMarkActive)
        try container.encode(weaponSharpenedUses, forKey: .weaponSharpenedUses)
        try container.encode(isComputerControlled, forKey: .isComputerControlled)
        try container.encode(isPoisoned, forKey: .isPoisoned)
        try container.encode(poisonDamagePerTurn, forKey: .poisonDamagePerTurn)
        try container.encode(poisonTurnsRemaining, forKey: .poisonTurnsRemaining)
        try container.encodeIfPresent(familiarName, forKey: .familiarName)
        try container.encodeIfPresent(familiarType, forKey: .familiarType)
        try container.encode(ethicalScore, forKey: .ethicalScore)
        try container.encode(ethicalLog, forKey: .ethicalLog)
        try container.encode(willpowerSurgeUsesRemaining, forKey: .willpowerSurgeUsesRemaining)
        try container.encode(wellFedAttacks, forKey: .wellFedAttacks)
        try container.encode(juiceCount, forKey: .juiceCount)
        try container.encode(sluggishAttacks, forKey: .sluggishAttacks)
        try container.encode(knownIncantations, forKey: .knownIncantations)
    }

    var proficiencyBonus: Int {
        return 2 + ((level - 1) / 4)
    }

    var armorClass: Int {
        var ac: Int
        let dexMod = abilityScores.modifier(for: .dexterity)

        if let armor = equippedArmor, let stats = armor.armorStats {
            if let maxDex = stats.maxDexBonus {
                ac = stats.baseAC + min(dexMod, maxDex)
            } else {
                ac = stats.baseAC + dexMod
            }
        } else {
            // Unarmored — barbarian gets CON bonus
            if characterClass == .barbarian {
                ac = 10 + dexMod + abilityScores.modifier(for: .constitution)
            } else {
                ac = 10 + dexMod
            }
        }

        // Shield bonus
        if let shield = equippedShield, let stats = shield.armorStats, stats.isShield {
            ac += stats.baseAC
        }
        return ac
    }


    func skillModifier(for skill: Skill) -> Int {
        let abilityMod = abilityScores.modifier(for: skill.ability)
        if skillProficiencies.contains(skill) {
            return abilityMod + proficiencyBonus
        }
        return abilityMod
    }

    // MARK: - Glyphkeeper (Ethical Alignment)

    var ethicalAlignment: EthicalAlignment { EthicalAlignment.forScore(ethicalScore) }

    /// Shifts this character's tracked ethical score by `delta` (clamped to
    /// -100...100) and records why, most-recent-first, capped at 20 entries
    /// so the log stays a useful recent summary rather than growing forever
    /// across a long campaign.
    func adjustEthicalScore(_ delta: Int, reason: String) {
        guard delta != 0 else { return }
        ethicalScore = max(-100, min(100, ethicalScore + delta))
        let sign = delta > 0 ? "+" : ""
        ethicalLog.insert("\(sign)\(delta) — \(reason)", at: 0)
        if ethicalLog.count > 20 {
            ethicalLog.removeLast(ethicalLog.count - 20)
        }
    }

    func takeDamage(_ amount: Int) {
        var remaining = amount

        // Temp HP absorbs first
        if tempHP > 0 {
            if tempHP >= remaining {
                tempHP -= remaining
                return
            } else {
                remaining -= tempHP
                tempHP = 0
            }
        }

        currentHP -= remaining
        if currentHP <= 0 {
            currentHP = 0
            isConscious = false
        }
    }

    func heal(_ amount: Int) {
        currentHP = min(currentHP + amount, maxHP)
        if currentHP > 0 {
            isConscious = true
            deathSaveSuccesses = 0
            deathSaveFailures = 0
        }
    }

    /// A failed (or auto-resolved) mind-control attempt — loses their next
    /// `turns` turn(s) to it. See willpowerSurgeUsesRemaining/
    /// willpowerSurgeImmuneTurns for the resist side of this.
    func applyMindControl(turns: Int) {
        isMindControlled = true
        mindControlTurnsRemaining = turns
    }

    func applyPoison(damagePerTurn: Int, turns: Int) {
        isPoisoned = true
        poisonDamagePerTurn = damagePerTurn
        poisonTurnsRemaining = turns
    }

    func curePoison() {
        isPoisoned = false
        poisonDamagePerTurn = 0
        poisonTurnsRemaining = 0
    }

    /// Reset per-adventure/per-combat state to a fresh start — used when a
    /// character loaded from the Character Roster joins a new party. Keeps
    /// everything that makes it "the same character" (level, XP, gear, gold,
    /// spells known) but clears anything that only made sense mid-adventure.
    func prepareForNewAdventure() {
        currentHP = maxHP
        tempHP = 0
        isConscious = true
        deathSaveSuccesses = 0
        deathSaveFailures = 0
        curePoison()
        if !spellSlots.isEmpty { spellSlots.restoreAll() }
        secondWindUsed = false
        rageUsesRemaining = rageMaxUses
        isRaging = false
        huntersMarkActive = false
        isPlayingDead = false
        hasFledCombat = false
        isDodging = false
        weaponSharpenedUses = 0
        wellFedAttacks = 0
        juiceCount = 0
        sluggishAttacks = 0
        isMindControlled = false
        mindControlTurnsRemaining = 0
        willpowerSurgeImmuneTurns = 0
        willpowerSurgeUsesRemaining = characterClass.willpowerSurgeMaxUses
    }

    /// Called each combat turn — returns damage taken from poison, or 0 if recovered
    func tickPoison() -> (damage: Int, cured: Bool) {
        guard isPoisoned, poisonTurnsRemaining > 0 else { return (0, false) }

        // 20% chance of naturally recovering each turn (CON save)
        let conMod = abilityScores.modifier(for: .constitution)
        let saveRoll = Int.random(in: 1...20) + conMod
        if saveRoll >= 14 {
            curePoison()
            return (0, true)
        }

        let dmg = poisonDamagePerTurn
        takeDamage(dmg)
        poisonTurnsRemaining -= 1
        if poisonTurnsRemaining <= 0 {
            curePoison()
        }
        return (dmg, poisonTurnsRemaining <= 0)
    }

    // MARK: - Carry Capacity

    static let maxInventorySlots = 10

    /// Pack weight limit. Strength is still the main driver (the classic
    /// STR x 15 lb), but Constitution now matters too — stamina to haul a
    /// load all day, +10 lb per point of CON modifier (or 5 lb less per
    /// point below zero) — and small folk (halflings, gnomes) manage a bit
    /// less for their size. Never below 30 lb, so nobody's left unable to
    /// carry the basics.
    var carryCapacity: Double {
        let base = Double(abilityScores.strength) * 15.0
        let conMod = abilityScores.modifier(for: .constitution)
        let stamina = conMod >= 0 ? Double(conMod) * 10.0 : Double(conMod) * 5.0
        let isSmall: Bool
        switch race {
        case .lightfootHalfling, .stoutHalfling, .gnome: isSmall = true
        default: isSmall = false
        }
        let sizeFactor = isSmall ? 0.85 : 1.0
        return max(30.0, (base + stamina) * sizeFactor)
    }

    var currentWeight: Double {
        var total = inventory.reduce(0.0) { $0 + $1.weight }
        if let w = equippedWeapon { total += w.weight }
        if let a = equippedArmor { total += a.weight }
        if let s = equippedShield { total += s.weight }
        return total
    }

    var isEncumbered: Bool {
        currentWeight > carryCapacity
    }

    var isInventoryFull: Bool {
        inventory.count >= Character.maxInventorySlots
    }

    func canCarry(_ item: Item) -> Bool {
        currentWeight + item.weight <= carryCapacity && inventory.count < Character.maxInventorySlots
    }

    /// Why canCarry(_:) would refuse this item, in words — the two checks
    /// it makes (weight, item-slot count) are independent, so a message
    /// that always blames weight is wrong (and confusing) whenever it's
    /// actually the slot cap that's hit, which carries no visible number
    /// anywhere else on screen. nil if the item CAN be carried.
    func carryBlockReason(for item: Item) -> String? {
        let overWeight = currentWeight + item.weight > carryCapacity
        let overSlots = inventory.count >= Character.maxInventorySlots
        if overWeight && overSlots {
            return "You're carrying too much, and too many separate items — drop or store something first."
        } else if overWeight {
            return "That's too heavy to carry right now — drop or store something first."
        } else if overSlots {
            return "Your pack is full (\(Character.maxInventorySlots) items max) — drop or store something first, even if you've got the weight to spare."
        }
        return nil
    }

    /// Recalculate maxHP based on current class and CON (for class/race changes)
    func recalculateMaxHP() {
        let conMod = abilityScores.modifier(for: .constitution)
        let newMax = characterClass.startingHP + conMod
        maxHP = max(1, newMax)
        currentHP = maxHP
    }

    // MARK: - AI Control

    /// Mark as computer-controlled and add "R." prefix (Asimov convention)
    func markAsAI() {
        isComputerControlled = true
        syncRobotPrefix()
    }

    /// Remove computer control and "R." prefix
    func unmarkAsAI() {
        isComputerControlled = false
        syncRobotPrefix()
    }

    /// Adds or removes the "R. " robot prefix (Asimov convention) so it
    /// always matches isComputerControlled and the "Robot Prefix" setting
    /// (Settings > Gameplay, on by default). Call this after loading a
    /// character from anywhere — a save, the Character Roster — since
    /// older data can predate the setting, or the setting can have been
    /// toggled since that character was last saved; without re-syncing,
    /// a loaded character's name and its actual control state can drift
    /// out of sync (an AI character with no "R. ", or a human one with a
    /// stale "R. " left over from before you took control).
    func syncRobotPrefix() {
        let enabled = UserDefaults.standard.object(forKey: "robot_prefix_enabled") == nil
            ? true : UserDefaults.standard.bool(forKey: "robot_prefix_enabled")
        let shouldHavePrefix = isComputerControlled && enabled
        let hasPrefix = name.hasPrefix("R. ")
        if shouldHavePrefix && !hasPrefix {
            name = "R. " + name
        } else if !shouldHavePrefix && hasPrefix {
            name = String(name.dropFirst(3))
        }
    }

    // MARK: - Inventory Management

    @discardableResult
    func addItem(_ item: Item) -> Bool {
        guard canCarry(item) else { return false }
        inventory.append(item)
        return true
    }

    func removeItem(_ item: Item) {
        if let index = inventory.firstIndex(where: { $0.id == item.id }) {
            inventory.remove(at: index)
        }
    }

    func equipWeapon(_ item: Item) {
        if let current = equippedWeapon {
            inventory.append(current)
        }
        removeItem(item)
        equippedWeapon = item
    }

    func equipArmor(_ item: Item) {
        if let current = equippedArmor {
            inventory.append(current)
        }
        removeItem(item)
        equippedArmor = item
    }

    func equipShield(_ item: Item) {
        if let current = equippedShield {
            inventory.append(current)
        }
        removeItem(item)
        equippedShield = item
    }

    func unequipWeapon() {
        if let weapon = equippedWeapon {
            inventory.append(weapon)
            equippedWeapon = nil
        }
    }

    func unequipArmor() {
        if let armor = equippedArmor {
            inventory.append(armor)
            equippedArmor = nil
        }
    }

    func unequipShield() {
        if let shield = equippedShield {
            inventory.append(shield)
            equippedShield = nil
        }
    }

    // MARK: - Spellcasting

    var spellcastingAbility: Ability? {
        switch characterClass {
        case .wizard: return .intelligence
        case .cleric, .ranger: return .wisdom
        default: return nil
        }
    }

    var spellAttackBonus: Int {
        guard let ability = spellcastingAbility else { return 0 }
        return abilityScores.modifier(for: ability) + proficiencyBonus
    }

    var spellSaveDC: Int {
        guard let ability = spellcastingAbility else { return 10 }
        return 8 + abilityScores.modifier(for: ability) + proficiencyBonus
    }

    func canCastSpell(_ spell: Spell) -> Bool {
        if spell.level == .cantrip { return true }
        return spellSlots.hasSlot(level: spell.level)
    }

    // MARK: - Level Up

    static func xpForLevel(_ level: Int) -> Int {
        switch level {
        case 1: return 0
        case 2: return 300
        case 3: return 900
        case 4: return 2700
        case 5: return 6500
        default: return 999999
        }
    }

    var canLevelUp: Bool {
        level < 5 && experiencePoints >= Character.xpForLevel(level + 1)
    }

    var sneakAttackDice: Int {
        guard characterClass == .rogue else { return 0 }
        return (level + 1) / 2  // 1 at L1, 1 at L2, 2 at L3, 2 at L4, 3 at L5
    }

    var rageMaxUses: Int {
        level < 3 ? 2 : (level < 6 ? 3 : 4)
    }

    var rageDamageBonus: Int {
        level < 9 ? 2 : 3
    }

    // MARK: - Display

    private static let boxW = 34 // inner width between ║ borders

    func displaySheet() -> [String] {
        let w = Character.boxW
        var lines: [String] = []

        func row(_ s: String) -> String {
            let t = String(s.prefix(w))
            return "║" + t.padding(toLength: w, withPad: " ", startingAt: 0) + "║"
        }
        let bar = String(repeating: "═", count: w)

        lines.append("╔\(bar)╗")
        lines.append(row(" \(String(name.prefix(w - 2)))"))
        lines.append(row(" Lv\(level) \(race.rawValue) \(characterClass.rawValue)"))
        lines.append("╠\(bar)╣")
        lines.append(row(" HP: \(currentHP)/\(maxHP)  AC: \(armorClass)"))
        lines.append(row(" Gold: \(gold)  XP: \(experiencePoints)"))
        if let weapon = equippedWeapon {
            lines.append(row(" Wpn: \(String(weapon.name.prefix(w - 7)))"))
        }
        if let armor = equippedArmor {
            lines.append(row(" Arm: \(String(armor.name.prefix(w - 7)))"))
        }
        lines.append("╠\(bar)╣")
        let s = abilityScores
        let fm = formatMod
        lines.append(row(" STR \(s.strength)(\(fm(s.modifier(for: .strength)))) INT \(s.intelligence)(\(fm(s.modifier(for: .intelligence))))"))
        lines.append(row(" DEX \(s.dexterity)(\(fm(s.modifier(for: .dexterity)))) WIS \(s.wisdom)(\(fm(s.modifier(for: .wisdom))))"))
        lines.append(row(" CON \(s.constitution)(\(fm(s.modifier(for: .constitution)))) CHA \(s.charisma)(\(fm(s.modifier(for: .charisma))))"))
        lines.append("╚\(bar)╝")

        return lines
    }

    private func formatMod(_ mod: Int) -> String {
        return mod >= 0 ? "+\(mod)" : "\(mod)"
    }
}

