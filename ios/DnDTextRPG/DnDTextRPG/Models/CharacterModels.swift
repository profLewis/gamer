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

    var speed: Int {
        switch self {
        case .hillDwarf, .mountainDwarf:
            return 25
        case .lightfootHalfling, .stoutHalfling, .gnome:
            return 25
        case .woodElf:
            return 35
        default:
            return 30
        }
    }

    var traits: [String] {
        switch self {
        case .human:
            return ["Extra Language"]
        case .highElf:
            return ["Darkvision", "Fey Ancestry", "Trance", "Cantrip"]
        case .woodElf:
            return ["Darkvision", "Fey Ancestry", "Trance", "Mask of the Wild"]
        case .hillDwarf:
            return ["Darkvision", "Dwarven Resilience", "Dwarven Toughness"]
        case .mountainDwarf:
            return ["Darkvision", "Dwarven Resilience", "Armor Proficiency"]
        case .lightfootHalfling:
            return ["Lucky", "Brave", "Nimble", "Naturally Stealthy"]
        case .stoutHalfling:
            return ["Lucky", "Brave", "Nimble", "Stout Resilience"]
        case .halfElf:
            return ["Darkvision", "Fey Ancestry", "Skill Versatility"]
        case .halfOrc:
            return ["Darkvision", "Menacing", "Relentless Endurance", "Savage Attacks"]
        case .gnome:
            return ["Darkvision", "Gnome Cunning", "Tinker"]
        case .tiefling:
            return ["Darkvision", "Hellish Resistance", "Infernal Legacy"]
        case .dragonborn:
            return ["Breath Weapon", "Damage Resistance"]
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

    var hitDie: Int {
        switch self {
        case .barbarian: return 12
        case .fighter, .ranger: return 10
        case .cleric, .rogue: return 8
        case .wizard: return 6
        }
    }

    var primaryAbility: Ability {
        switch self {
        case .fighter, .barbarian: return .strength
        case .wizard: return .intelligence
        case .rogue, .ranger: return .dexterity
        case .cleric: return .wisdom
        }
    }

    var savingThrows: [Ability] {
        switch self {
        case .fighter: return [.strength, .constitution]
        case .wizard: return [.intelligence, .wisdom]
        case .rogue: return [.dexterity, .intelligence]
        case .cleric: return [.wisdom, .charisma]
        case .ranger: return [.strength, .dexterity]
        case .barbarian: return [.strength, .constitution]
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
        }
    }

    var numSkillChoices: Int {
        switch self {
        case .rogue: return 4
        case .ranger: return 3
        default: return 2
        }
    }

    var isSpellcaster: Bool {
        switch self {
        case .wizard, .cleric, .ranger: return true
        default: return false
        }
    }

    var armorProficiencies: [String] {
        switch self {
        case .fighter: return ["All Armor", "Shields"]
        case .cleric: return ["Light Armor", "Medium Armor", "Shields"]
        case .ranger: return ["Light Armor", "Medium Armor", "Shields"]
        case .barbarian: return ["Light Armor", "Medium Armor", "Shields"]
        case .rogue: return ["Light Armor"]
        case .wizard: return []
        }
    }

    var weaponProficiencies: [String] {
        switch self {
        case .fighter: return ["Simple Weapons", "Martial Weapons"]
        case .barbarian: return ["Simple Weapons", "Martial Weapons"]
        case .ranger: return ["Simple Weapons", "Martial Weapons"]
        case .cleric: return ["Simple Weapons"]
        case .rogue: return ["Simple Weapons", "Rapier", "Shortsword", "Hand Crossbow"]
        case .wizard: return ["Dagger", "Quarterstaff", "Light Crossbow"]
        }
    }

    var startingHP: Int {
        return hitDie
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

    enum CodingKeys: String, CodingKey {
        case id, name, race, characterClass, level, abilityScores
        case currentHP, maxHP, tempHP, skillProficiencies, experiencePoints, gold
        case isConscious, deathSaveSuccesses, deathSaveFailures
    }

    init(name: String, race: Race, characterClass: CharacterClass, abilityScores: AbilityScores) {
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
    }

    var proficiencyBonus: Int {
        return 2 + ((level - 1) / 4)
    }

    var armorClass: Int {
        // Base AC (unarmored) = 10 + DEX modifier
        return 10 + abilityScores.modifier(for: .dexterity)
    }

    var initiative: Int {
        return abilityScores.modifier(for: .dexterity)
    }

    func skillModifier(for skill: Skill) -> Int {
        let abilityMod = abilityScores.modifier(for: skill.ability)
        if skillProficiencies.contains(skill) {
            return abilityMod + proficiencyBonus
        }
        return abilityMod
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

    func displaySheet() -> [String] {
        var lines: [String] = []

        lines.append("╔══════════════════════════════════════╗")
        lines.append("║ \(name.padding(toLength: 36, withPad: " ", startingAt: 0)) ║")
        lines.append("║ Level \(level) \(race.rawValue) \(characterClass.rawValue)".padding(toLength: 39, withPad: " ", startingAt: 0) + "║")
        lines.append("╠══════════════════════════════════════╣")
        lines.append("║ HP: \(currentHP)/\(maxHP)".padding(toLength: 20, withPad: " ", startingAt: 0) + "AC: \(armorClass)".padding(toLength: 18, withPad: " ", startingAt: 0) + "║")
        lines.append("╠══════════════════════════════════════╣")
        lines.append("║ STR: \(abilityScores.strength) (\(formatMod(abilityScores.modifier(for: .strength))))  INT: \(abilityScores.intelligence) (\(formatMod(abilityScores.modifier(for: .intelligence))))".padding(toLength: 39, withPad: " ", startingAt: 0) + "║")
        lines.append("║ DEX: \(abilityScores.dexterity) (\(formatMod(abilityScores.modifier(for: .dexterity))))  WIS: \(abilityScores.wisdom) (\(formatMod(abilityScores.modifier(for: .wisdom))))".padding(toLength: 39, withPad: " ", startingAt: 0) + "║")
        lines.append("║ CON: \(abilityScores.constitution) (\(formatMod(abilityScores.modifier(for: .constitution))))  CHA: \(abilityScores.charisma) (\(formatMod(abilityScores.modifier(for: .charisma))))".padding(toLength: 39, withPad: " ", startingAt: 0) + "║")
        lines.append("╚══════════════════════════════════════╝")

        return lines
    }

    private func formatMod(_ mod: Int) -> String {
        return mod >= 0 ? "+\(mod)" : "\(mod)"
    }
}

