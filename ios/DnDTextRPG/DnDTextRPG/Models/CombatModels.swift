//
//  CombatModels.swift
//  DnDTextRPG
//
//  Combat, monsters, and encounter models
//

import Foundation

// MARK: - Monster

struct Monster: Identifiable, Codable {
    let id: UUID
    let name: String
    let type: MonsterType
    var currentHP: Int
    let maxHP: Int
    let armorClass: Int
    let attackBonus: Int
    let damage: String
    let challengeRating: Double
    let experiencePoints: Int

    var isAlive: Bool { currentHP > 0 }

    mutating func takeDamage(_ amount: Int) {
        currentHP = max(0, currentHP - amount)
    }

    static func create(_ type: MonsterType) -> Monster {
        let stats = type.stats
        return Monster(
            id: UUID(),
            name: type.rawValue,
            type: type,
            currentHP: stats.hp,
            maxHP: stats.hp,
            armorClass: stats.ac,
            attackBonus: stats.attackBonus,
            damage: stats.damage,
            challengeRating: stats.cr,
            experiencePoints: stats.xp
        )
    }
}

enum MonsterType: String, CaseIterable, Codable {
    case goblin = "Goblin"
    case skeleton = "Skeleton"
    case zombie = "Zombie"
    case orc = "Orc"
    case hobgoblin = "Hobgoblin"
    case gnoll = "Gnoll"
    case bugbear = "Bugbear"
    case ogre = "Ogre"
    case troll = "Troll"
    case owlbear = "Owlbear"
    case giantSpider = "Giant Spider"
    case wolf = "Wolf"

    struct Stats {
        let hp: Int
        let ac: Int
        let attackBonus: Int
        let damage: String
        let cr: Double
        let xp: Int
    }

    var stats: Stats {
        switch self {
        case .goblin:
            return Stats(hp: 7, ac: 15, attackBonus: 4, damage: "1d6+2", cr: 0.25, xp: 50)
        case .skeleton:
            return Stats(hp: 13, ac: 13, attackBonus: 4, damage: "1d6+2", cr: 0.25, xp: 50)
        case .zombie:
            return Stats(hp: 22, ac: 8, attackBonus: 3, damage: "1d6+1", cr: 0.25, xp: 50)
        case .wolf:
            return Stats(hp: 11, ac: 13, attackBonus: 4, damage: "2d4+2", cr: 0.25, xp: 50)
        case .orc:
            return Stats(hp: 15, ac: 13, attackBonus: 5, damage: "1d12+3", cr: 0.5, xp: 100)
        case .hobgoblin:
            return Stats(hp: 11, ac: 18, attackBonus: 3, damage: "1d8+1", cr: 0.5, xp: 100)
        case .giantSpider:
            return Stats(hp: 26, ac: 14, attackBonus: 5, damage: "1d8+3", cr: 1, xp: 200)
        case .gnoll:
            return Stats(hp: 22, ac: 15, attackBonus: 4, damage: "1d8+2", cr: 0.5, xp: 100)
        case .bugbear:
            return Stats(hp: 27, ac: 16, attackBonus: 4, damage: "2d8+2", cr: 1, xp: 200)
        case .ogre:
            return Stats(hp: 59, ac: 11, attackBonus: 6, damage: "2d8+4", cr: 2, xp: 450)
        case .owlbear:
            return Stats(hp: 59, ac: 13, attackBonus: 7, damage: "2d8+5", cr: 3, xp: 700)
        case .troll:
            return Stats(hp: 84, ac: 15, attackBonus: 7, damage: "2d6+4", cr: 5, xp: 1800)
        }
    }

    var description: String {
        switch self {
        case .goblin: return "A small, vicious humanoid with sharp teeth."
        case .skeleton: return "Animated bones wielding rusty weapons."
        case .zombie: return "A shambling corpse with rotting flesh."
        case .wolf: return "A fierce predator with gleaming eyes."
        case .orc: return "A brutish warrior with green skin and tusks."
        case .hobgoblin: return "A disciplined goblinoid soldier in armor."
        case .giantSpider: return "A massive arachnid with dripping fangs."
        case .gnoll: return "A hyena-headed humanoid savage."
        case .bugbear: return "A large, hairy goblinoid ambusher."
        case .ogre: return "A towering brute of immense strength."
        case .owlbear: return "A fearsome hybrid of owl and bear."
        case .troll: return "A lanky giant with regenerating flesh."
        }
    }

    var asciiArt: [String] {
        switch self {
        case .goblin:
            return [
                "    /\\",
                "   (oo)",
                "  _/||\\_",
                " / /||  \\",
                "   /  \\",
            ]
        case .skeleton:
            return [
                "    .-..",
                "   (o o)",
                "   | O |",
                "   /| |\\",
                "   d| |b",
            ]
        case .zombie:
            return [
                "   _____",
                "  /x   x\\",
                "  | ~~~ |",
                "  /|   |\\",
                "   |___|",
            ]
        case .wolf:
            return [
                "   /\\_/\\",
                "  ( o.o )",
                "   > ^ <",
                "  /|   |\\",
                "  _/   \\_",
            ]
        case .orc:
            return [
                "   ___",
                "  /o_o\\",
                "  \\VVV/",
                "  /| |\\",
                "  d| |b",
            ]
        case .hobgoblin:
            return [
                "  [===]",
                "  |o_o|",
                "  /|#|\\",
                " /=| |=\\",
                "   d b",
            ]
        case .giantSpider:
            return [
                " \\ |o o| /",
                "  \\(   )/",
                "  /(   )\\",
                " / |___| \\",
            ]
        case .gnoll:
            return [
                "    /V\\",
                "   (o o)",
                "  --|~|--",
                "   /| |\\",
                "   d| |b",
            ]
        case .bugbear:
            return [
                "   (\\=/)",
                "   (o.o)",
                "  //| |\\\\",
                " // | | \\\\",
                "    d b",
            ]
        case .ogre:
            return [
                "   .-\"\"-.",
                "  / O  O \\",
                "  |  __  |",
                "  /|/  \\|\\",
                " / |    | \\",
            ]
        case .owlbear:
            return [
                "   /\\'v'/\\",
                "  ( o   o )",
                "  /|  ^  |\\",
                " / | /|\\ | \\",
                "   |/   \\|",
            ]
        case .troll:
            return [
                "     /|",
                "   (x x)",
                "   /| |\\",
                "  / | | \\",
                " /  | |  \\",
            ]
        }
    }

    static func forLevel(_ level: Int) -> [MonsterType] {
        switch level {
        case 1:
            return [.goblin, .skeleton, .zombie, .wolf]
        case 2:
            return [.goblin, .skeleton, .orc, .hobgoblin, .gnoll]
        case 3:
            return [.orc, .hobgoblin, .bugbear, .giantSpider, .gnoll]
        case 4:
            return [.bugbear, .giantSpider, .ogre]
        default:
            return [.ogre, .owlbear, .troll]
        }
    }

    static func boss(forLevel level: Int) -> MonsterType {
        switch level {
        case 1: return .bugbear
        case 2: return .ogre
        case 3: return .owlbear
        default: return .troll
        }
    }
}

// MARK: - Encounter

enum EncounterDifficulty: String, Codable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    case deadly = "Deadly"

    var multiplier: Double {
        switch self {
        case .easy: return 0.5
        case .medium: return 1.0
        case .hard: return 1.5
        case .deadly: return 2.0
        }
    }
}

struct Encounter: Codable {
    var monsters: [Monster]
    let difficulty: EncounterDifficulty

    var isDefeated: Bool {
        monsters.allSatisfy { !$0.isAlive }
    }

    var totalXP: Int {
        monsters.reduce(0) { $0 + $1.experiencePoints }
    }

    var aliveMonsters: [Monster] {
        monsters.filter { $0.isAlive }
    }

    static func generate(level: Int, difficulty: EncounterDifficulty) -> Encounter {
        let possibleMonsters = MonsterType.forLevel(level)
        let targetXP = xpThreshold(for: level, difficulty: difficulty)

        var monsters: [Monster] = []
        var currentXP = 0

        while currentXP < targetXP {
            let monsterType = possibleMonsters.randomElement()!
            let monster = Monster.create(monsterType)

            if currentXP + monster.experiencePoints <= targetXP * Int(1.5) {
                monsters.append(monster)
                currentXP += monster.experiencePoints
            } else {
                break
            }

            // Limit number of monsters
            if monsters.count >= 4 + level {
                break
            }
        }

        // Ensure at least one monster
        if monsters.isEmpty {
            monsters.append(Monster.create(possibleMonsters.first!))
        }

        return Encounter(monsters: monsters, difficulty: difficulty)
    }

    static func generateBoss(level: Int) -> Encounter {
        let bossType = MonsterType.boss(forLevel: level)
        var boss = Monster.create(bossType)

        // Buff the boss
        boss = Monster(
            id: UUID(),
            name: "The " + boss.name,
            type: boss.type,
            currentHP: boss.maxHP * 2,
            maxHP: boss.maxHP * 2,
            armorClass: boss.armorClass + 2,
            attackBonus: boss.attackBonus + 2,
            damage: boss.damage,
            challengeRating: boss.challengeRating * 2,
            experiencePoints: boss.experiencePoints * 3
        )

        var monsters = [boss]

        // Add some minions
        if level >= 2 {
            let minionType = MonsterType.forLevel(max(1, level - 1)).randomElement()!
            monsters.append(Monster.create(minionType))
            if level >= 3 {
                monsters.append(Monster.create(minionType))
            }
        }

        return Encounter(monsters: monsters, difficulty: .deadly)
    }

    private static func xpThreshold(for level: Int, difficulty: EncounterDifficulty) -> Int {
        let baseXP: Int
        switch level {
        case 1: baseXP = 50
        case 2: baseXP = 100
        case 3: baseXP = 150
        case 4: baseXP = 250
        case 5: baseXP = 500
        default: baseXP = 750
        }
        return Int(Double(baseXP) * difficulty.multiplier)
    }
}

// MARK: - Attack Report

struct AttackReport {
    let attackerName: String
    let targetName: String
    let isPlayerAttack: Bool

    // Attack roll
    let d20Roll: Int
    let attackModifier: Int
    let modifierBreakdown: String
    let totalAttack: Int
    let targetAC: Int

    // Result
    let hits: Bool
    let isCritical: Bool
    let isCriticalMiss: Bool

    // Damage (nil if miss)
    let damageDice: String?
    let damageRolls: [Int]?
    let damageModifier: Int?
    let totalDamage: Int?

    // Aftermath
    let targetDefeated: Bool
    let targetUnconscious: Bool
    let targetCurrentHP: Int
    let targetMaxHP: Int
}

// MARK: - Combat State

enum CombatState {
    case ongoing
    case victory
    case defeat
}

class Combat: ObservableObject {
    @Published var party: [Character]
    @Published var encounter: Encounter
    @Published var turnOrder: [(id: UUID, name: String, isPlayer: Bool, initiative: Int)]
    @Published var currentTurnIndex: Int
    @Published var state: CombatState
    @Published var combatLog: [String]

    var currentCombatant: (id: UUID, name: String, isPlayer: Bool, initiative: Int)? {
        guard currentTurnIndex >= 0 && currentTurnIndex < turnOrder.count else { return nil }
        return turnOrder[currentTurnIndex]
    }

    init(party: [Character], encounter: Encounter) {
        self.party = party
        self.encounter = encounter
        self.turnOrder = []
        self.currentTurnIndex = 0
        self.state = .ongoing
        self.combatLog = []

        rollInitiative()
    }

    private func rollInitiative() {
        var initiatives: [(id: UUID, name: String, isPlayer: Bool, initiative: Int)] = []

        // Roll for party
        for char in party {
            let initiative = Dice.rollInitiative(dexModifier: char.abilityScores.modifier(for: .dexterity))
            initiatives.append((id: char.id, name: char.name, isPlayer: true, initiative: initiative))
        }

        // Roll for monsters
        for monster in encounter.monsters {
            let initiative = Dice.d20() + 1  // Simplified monster initiative
            initiatives.append((id: monster.id, name: monster.name, isPlayer: false, initiative: initiative))
        }

        // Sort by initiative (descending)
        turnOrder = initiatives.sorted { $0.initiative > $1.initiative }
    }

    func nextTurn() {
        currentTurnIndex += 1
        if currentTurnIndex >= turnOrder.count {
            currentTurnIndex = 0
        }

        // Skip dead combatants
        while !isCombatantAlive(turnOrder[currentTurnIndex]) {
            currentTurnIndex += 1
            if currentTurnIndex >= turnOrder.count {
                currentTurnIndex = 0
            }
        }

        checkCombatEnd()
    }

    private func isCombatantAlive(_ combatant: (id: UUID, name: String, isPlayer: Bool, initiative: Int)) -> Bool {
        if combatant.isPlayer {
            return party.first { $0.id == combatant.id }?.isConscious ?? false
        } else {
            return encounter.monsters.first { $0.id == combatant.id }?.isAlive ?? false
        }
    }

    func checkCombatEnd() {
        // Check for party defeat
        if party.allSatisfy({ !$0.isConscious }) {
            state = .defeat
            return
        }

        // Check for victory
        if encounter.isDefeated {
            state = .victory
            return
        }
    }

    func playerAttack(characterId: UUID, targetId: UUID) -> AttackReport? {
        guard let character = party.first(where: { $0.id == characterId }),
              let monsterIndex = encounter.monsters.firstIndex(where: { $0.id == targetId }) else {
            return nil
        }

        var monster = encounter.monsters[monsterIndex]
        let strMod = character.abilityScores.modifier(for: .strength)
        let dexMod = character.abilityScores.modifier(for: .dexterity)
        let profBonus = character.proficiencyBonus

        // Determine attack ability based on weapon
        let weaponStats = character.equippedWeapon?.weaponStats
        let attackAbilityMod: Int
        if weaponStats?.isFinesse == true {
            attackAbilityMod = max(strMod, dexMod)
        } else if weaponStats?.isRanged == true {
            attackAbilityMod = dexMod
        } else {
            attackAbilityMod = strMod
        }

        let attackMod = attackAbilityMod + profBonus
        let attack = Dice.attackRoll(modifier: attackMod, targetAC: monster.armorClass)

        let abilityLabel = (weaponStats?.isRanged == true) ? "DEX" : (weaponStats?.isFinesse == true && dexMod > strMod) ? "DEX" : "STR"
        let breakdown = "\(abilityLabel) \(attackAbilityMod >= 0 ? "+" : "")\(attackAbilityMod), Prof +\(profBonus)"

        var damageDice: String? = nil
        var damageRolls: [Int]? = nil
        var damageModifier: Int? = nil
        var totalDamage: Int? = nil
        var targetDefeated = false

        if attack.hits {
            let damageMod = attackAbilityMod
            let baseDice = weaponStats?.damage ?? "1d4"  // Unarmed fallback
            damageDice = baseDice
            damageModifier = damageMod

            let roll = attack.isCritical
                ? Dice.rollCriticalDamage("\(baseDice)+\(damageMod)")
                : Dice.rollDamage("\(baseDice)+\(damageMod)")

            let damage = max(1, roll.total)
            totalDamage = damage
            damageRolls = roll.rolls

            monster.takeDamage(damage)
            encounter.monsters[monsterIndex] = monster
            targetDefeated = !monster.isAlive
        }

        let report = AttackReport(
            attackerName: character.name,
            targetName: monster.name,
            isPlayerAttack: true,
            d20Roll: attack.roll,
            attackModifier: attackMod,
            modifierBreakdown: breakdown,
            totalAttack: attack.total,
            targetAC: monster.armorClass,
            hits: attack.hits,
            isCritical: attack.isCritical,
            isCriticalMiss: attack.isCriticalMiss,
            damageDice: damageDice,
            damageRolls: damageRolls,
            damageModifier: damageModifier,
            totalDamage: totalDamage,
            targetDefeated: targetDefeated,
            targetUnconscious: false,
            targetCurrentHP: monster.currentHP,
            targetMaxHP: monster.maxHP
        )

        combatLog.append("\(character.name) attacks \(monster.name)")
        return report
    }

    func monsterAttack(monsterId: UUID, targetId: UUID) -> AttackReport? {
        guard let monster = encounter.monsters.first(where: { $0.id == monsterId }),
              let character = party.first(where: { $0.id == targetId }) else {
            return nil
        }

        let attack = Dice.attackRoll(modifier: monster.attackBonus, targetAC: character.armorClass)
        let breakdown = "Attack +\(monster.attackBonus)"

        var damageDice: String? = nil
        var damageRolls: [Int]? = nil
        var damageModifier: Int? = nil
        var totalDamage: Int? = nil
        var targetUnconscious = false

        if attack.hits {
            // Parse monster damage notation to extract dice and modifier
            let notation = monster.damage.lowercased().replacingOccurrences(of: " ", with: "")
            var dMod = 0
            var diceOnly = notation
            if let plusIdx = notation.firstIndex(of: "+") {
                dMod = Int(String(notation[notation.index(after: plusIdx)...])) ?? 0
                diceOnly = String(notation[..<plusIdx])
            }

            damageDice = attack.isCritical ? diceOnly.replacingOccurrences(of: "1d", with: "2d").replacingOccurrences(of: "2d", with: "4d") : diceOnly
            damageModifier = dMod

            let roll = attack.isCritical
                ? Dice.rollCriticalDamage(monster.damage)
                : Dice.rollDamage(monster.damage)

            let damage = max(1, roll.total)
            totalDamage = damage
            damageRolls = roll.rolls

            character.takeDamage(damage)
            targetUnconscious = !character.isConscious
        }

        let report = AttackReport(
            attackerName: monster.name,
            targetName: character.name,
            isPlayerAttack: false,
            d20Roll: attack.roll,
            attackModifier: monster.attackBonus,
            modifierBreakdown: breakdown,
            totalAttack: attack.total,
            targetAC: character.armorClass,
            hits: attack.hits,
            isCritical: attack.isCritical,
            isCriticalMiss: attack.isCriticalMiss,
            damageDice: damageDice,
            damageRolls: damageRolls,
            damageModifier: damageModifier,
            totalDamage: totalDamage,
            targetDefeated: false,
            targetUnconscious: targetUnconscious,
            targetCurrentHP: character.currentHP,
            targetMaxHP: character.maxHP
        )

        combatLog.append("\(monster.name) attacks \(character.name)")
        return report
    }

    func runMonsterTurn() -> AttackReport? {
        guard let current = currentCombatant, !current.isPlayer else {
            return nil
        }

        guard encounter.monsters.first(where: { $0.id == current.id && $0.isAlive }) != nil else {
            return nil  // Monster dead, caller handles nextTurn
        }

        // Find a target (random conscious party member)
        let targets = party.filter { $0.isConscious }
        guard let target = targets.randomElement() else {
            state = .defeat
            return nil
        }

        return monsterAttack(monsterId: current.id, targetId: target.id)
    }

    func displayStatus() -> [String] {
        var lines: [String] = []

        lines.append("══════════ COMBAT ══════════")
        lines.append("")

        // Party status
        lines.append("PARTY:")
        for char in party {
            let status = char.isConscious ? "●" : "✗"
            lines.append("  \(status) \(char.name): \(char.currentHP)/\(char.maxHP) HP")
        }

        lines.append("")
        lines.append("ENEMIES:")
        for monster in encounter.monsters {
            let status = monster.isAlive ? "●" : "✗"
            lines.append("  \(status) \(monster.name): \(monster.currentHP)/\(monster.maxHP) HP")
        }

        lines.append("")
        if let current = currentCombatant {
            lines.append("Current Turn: \(current.name)")
        }

        lines.append("════════════════════════════")

        return lines
    }
}
