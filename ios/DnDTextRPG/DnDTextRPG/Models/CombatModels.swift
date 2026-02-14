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
    // Starter (CR 0 / CR 1/8)
    case giantRat = "Giant Rat"
    case kobold = "Kobold"
    case stirge = "Stirge"
    case giantBat = "Giant Bat"
    case crawlingClaw = "Crawling Claw"
    // Low (CR 1/4)
    case goblin = "Goblin"
    case skeleton = "Skeleton"
    case zombie = "Zombie"
    case wolf = "Wolf"
    // Mid-low (CR 1/2)
    case orc = "Orc"
    case hobgoblin = "Hobgoblin"
    case gnoll = "Gnoll"
    // Mid (CR 1-2)
    case bugbear = "Bugbear"
    case giantSpider = "Giant Spider"
    case ogre = "Ogre"
    // High (CR 3+)
    case owlbear = "Owlbear"
    case troll = "Troll"
    case demogorgon = "Demogorgon"
    case mindFlayer = "Mind Flayer"
    case vecna = "Vecna"

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
        // Starter monsters — very weak, manageable for a solo level 1
        case .giantRat:
            return Stats(hp: 4, ac: 10, attackBonus: 2, damage: "1d4", cr: 0.125, xp: 25)
        case .kobold:
            return Stats(hp: 5, ac: 12, attackBonus: 3, damage: "1d4+1", cr: 0.125, xp: 25)
        case .stirge:
            return Stats(hp: 2, ac: 13, attackBonus: 3, damage: "1d4+1", cr: 0.125, xp: 25)
        case .giantBat:
            return Stats(hp: 4, ac: 11, attackBonus: 2, damage: "1d4+1", cr: 0.125, xp: 25)
        case .crawlingClaw:
            return Stats(hp: 3, ac: 12, attackBonus: 3, damage: "1d4+1", cr: 0, xp: 10)
        // Standard low-level monsters
        case .goblin:
            return Stats(hp: 7, ac: 13, attackBonus: 3, damage: "1d6+1", cr: 0.25, xp: 50)
        case .skeleton:
            return Stats(hp: 10, ac: 12, attackBonus: 3, damage: "1d6+1", cr: 0.25, xp: 50)
        case .zombie:
            return Stats(hp: 15, ac: 8, attackBonus: 2, damage: "1d6", cr: 0.25, xp: 50)
        case .wolf:
            return Stats(hp: 8, ac: 12, attackBonus: 3, damage: "1d6+1", cr: 0.25, xp: 50)
        // Mid-low
        case .orc:
            return Stats(hp: 15, ac: 13, attackBonus: 5, damage: "1d12+3", cr: 0.5, xp: 100)
        case .hobgoblin:
            return Stats(hp: 11, ac: 16, attackBonus: 3, damage: "1d8+1", cr: 0.5, xp: 100)
        case .gnoll:
            return Stats(hp: 18, ac: 14, attackBonus: 4, damage: "1d8+2", cr: 0.5, xp: 100)
        // Mid
        case .bugbear:
            return Stats(hp: 27, ac: 16, attackBonus: 4, damage: "2d8+2", cr: 1, xp: 200)
        case .giantSpider:
            return Stats(hp: 26, ac: 14, attackBonus: 5, damage: "1d8+3", cr: 1, xp: 200)
        case .ogre:
            return Stats(hp: 59, ac: 11, attackBonus: 6, damage: "2d8+4", cr: 2, xp: 450)
        // High
        case .owlbear:
            return Stats(hp: 59, ac: 13, attackBonus: 7, damage: "2d8+5", cr: 3, xp: 700)
        case .troll:
            return Stats(hp: 84, ac: 15, attackBonus: 7, damage: "2d6+4", cr: 5, xp: 1800)
        case .demogorgon:
            return Stats(hp: 68, ac: 14, attackBonus: 7, damage: "2d8+4", cr: 4, xp: 1100)
        case .mindFlayer:
            return Stats(hp: 71, ac: 15, attackBonus: 7, damage: "2d10+3", cr: 7, xp: 2900)
        case .vecna:
            return Stats(hp: 120, ac: 18, attackBonus: 9, damage: "3d8+5", cr: 10, xp: 5900)
        }
    }

    var description: String {
        switch self {
        case .giantRat: return "An oversized rat with beady red eyes and yellow teeth."
        case .kobold: return "A small, scaly reptilian creature clutching a tiny spear."
        case .stirge: return "A mosquito-like creature the size of a cat, buzzing hungrily."
        case .giantBat: return "A bat with a wingspan wider than your arms, swooping silently."
        case .crawlingClaw: return "A severed hand skittering across the floor on its fingertips."
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
        case .demogorgon: return "A terrifying creature from the Upside Down with a gaping flower-like maw."
        case .mindFlayer: return "An aberration with tentacles protruding from its face, wielding psionic power."
        case .vecna: return "The Undying King, a lich of immense power reaching between worlds."
        }
    }

    var asciiArt: [String] {
        switch self {
        case .giantRat:
            return [
                "      /\\  /\\",
                "     (  ..  )",
                "      )    (",
                "     /||||||\\",
                "    ~ ~~~~~  ~",
            ]
        case .kobold:
            return [
                "     /\\",
                "    (><)",
                "    /|\\",
                "   / | \\",
                "     A",
            ]
        case .stirge:
            return [
                "    _/\\_",
                "   / () \\",
                "   \\    /",
                "    |--|",
                "     \\/",
            ]
        case .giantBat:
            return [
                "  _/    \\_",
                " / \\(oo)/ \\",
                "/   \\  /   \\",
                "     \\/",
            ]
        case .crawlingClaw:
            return [
                "    ___",
                "   /   \\",
                "  | === |",
                "   \\|||/",
                "    \\|/",
            ]
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
        case .demogorgon:
            return [
                "   \\|/|\\|/",
                "    \\|||/",
                "   (     )",
                "   /|   |\\",
                "  / |   | \\",
            ]
        case .mindFlayer:
            return [
                "    .-\"\"\"-.  ",
                "   ( o   o )",
                "    \\|||||/",
                "   /||   ||\\",
                "    /|   |\\",
            ]
        case .vecna:
            return [
                "   .--VVV--.",
                "  / (X) (o) \\",
                "  | /===\\ |",
                "  /| /#\\ |\\",
                " / |/   \\| \\",
            ]
        }
    }

    static func forLevel(_ level: Int) -> [MonsterType] {
        switch level {
        case 1:
            return [.giantRat, .kobold, .stirge, .giantBat, .crawlingClaw]
        case 2:
            return [.goblin, .skeleton, .zombie, .wolf, .kobold]
        case 3:
            return [.goblin, .skeleton, .orc, .hobgoblin, .gnoll]
        case 4:
            return [.orc, .hobgoblin, .bugbear, .giantSpider, .gnoll]
        case 5:
            return [.bugbear, .giantSpider, .ogre, .demogorgon]
        case 6:
            return [.ogre, .owlbear, .troll, .demogorgon, .mindFlayer]
        default:
            return [.troll, .demogorgon, .mindFlayer]
        }
    }

    static func boss(forLevel level: Int) -> MonsterType {
        switch level {
        case 1: return .goblin  // A goblin chieftain — tough but beatable
        case 2: return .bugbear
        case 3: return .ogre
        case 4: return .owlbear
        case 5: return .demogorgon
        case 6: return .mindFlayer
        default: return .vecna
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

        // Buff the boss (less at level 1 so it's survivable)
        let hpMult = level == 1 ? 1.5 : 2.0
        let acBonus = level == 1 ? 1 : 2
        let atkBonus = level == 1 ? 1 : 2
        boss = Monster(
            id: UUID(),
            name: "The " + boss.name,
            type: boss.type,
            currentHP: Int(Double(boss.maxHP) * hpMult),
            maxHP: Int(Double(boss.maxHP) * hpMult),
            armorClass: boss.armorClass + acBonus,
            attackBonus: boss.attackBonus + atkBonus,
            damage: boss.damage,
            challengeRating: boss.challengeRating * 2,
            experiencePoints: boss.experiencePoints * 3
        )

        var monsters = [boss]

        // Add some minions (not at level 1)
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
            guard let char = party.first(where: { $0.id == combatant.id }) else { return false }
            // Alive if conscious, or unconscious but still making death saves
            return char.isConscious || (char.deathSaveFailures < 3 && char.deathSaveSuccesses < 3)
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

            var damage = max(1, roll.total)
            var allRolls = roll.rolls

            // Rogue Sneak Attack: extra damage on every hit
            if character.characterClass == .rogue && character.sneakAttackDice > 0 {
                let sneakRolls = Dice.roll(character.sneakAttackDice, d: 6)
                damage += sneakRolls.reduce(0, +)
                allRolls.append(contentsOf: sneakRolls)
            }

            // Barbarian Rage: bonus melee damage
            if character.isRaging && weaponStats?.isRanged != true {
                damage += character.rageDamageBonus
            }

            // Ranger Hunter's Mark: bonus 1d6 damage
            if character.huntersMarkActive {
                let markRoll = Dice.d6()
                damage += markRoll
                allRolls.append(markRoll)
            }

            totalDamage = damage
            damageRolls = allRolls

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

            var damage = max(1, roll.total)

            // Barbarian Rage: resistance to physical damage (half)
            if character.isRaging {
                damage = damage / 2
            }

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

    // MARK: - Spell Casting

    func castSpell(casterId: UUID, spell: Spell, targetIds: [UUID]) -> SpellReport? {
        guard let caster = party.first(where: { $0.id == casterId }) else { return nil }

        // Use spell slot
        if spell.level != .cantrip {
            caster.spellSlots.useSlot(level: spell.level)
        }

        let spellMod = caster.spellAttackBonus
        let saveDC = caster.spellSaveDC
        let casterAbilityMod: Int = {
            guard let ability = caster.spellcastingAbility else { return 0 }
            return caster.abilityScores.modifier(for: ability)
        }()

        var d20Roll: Int? = nil
        var attackBonus: Int? = nil
        var totalAttack: Int? = nil
        var targetAC: Int? = nil
        var hits: Bool? = nil
        var isCritical = false
        var saveResults: [(targetName: String, roll: Int, total: Int, saved: Bool)] = []
        var damageRolls: [Int] = []
        var totalDamage = 0
        var healAmount = 0
        var targetsHit: [String] = []
        var targetsDefeated: [String] = []
        var targetStatuses: [(name: String, currentHP: Int, maxHP: Int)] = []
        var targetName: String? = nil

        switch spell.spellType {
        case .attack:
            // Single target attack spell
            guard let targetId = targetIds.first,
                  let monsterIndex = encounter.monsters.firstIndex(where: { $0.id == targetId }) else { return nil }
            var monster = encounter.monsters[monsterIndex]
            targetName = monster.name

            let attack = Dice.attackRoll(modifier: spellMod, targetAC: monster.armorClass)
            d20Roll = attack.roll
            attackBonus = spellMod
            totalAttack = attack.total
            targetAC = monster.armorClass
            hits = attack.hits
            isCritical = attack.isCritical

            if attack.hits, let dmgDice = spell.damage {
                let roll = attack.isCritical
                    ? Dice.rollCriticalDamage(dmgDice)
                    : Dice.rollDamage(dmgDice)
                let damage = max(1, roll.total)
                totalDamage = damage
                damageRolls = roll.rolls
                targetsHit.append(monster.name)

                monster.takeDamage(damage)
                encounter.monsters[monsterIndex] = monster
                if !monster.isAlive { targetsDefeated.append(monster.name) }
                targetStatuses.append((monster.name, monster.currentHP, monster.maxHP))
            }

        case .savingThrow:
            // Can be single or all enemies
            let targets: [(index: Int, monster: Monster)] = targetIds.compactMap { id in
                guard let idx = encounter.monsters.firstIndex(where: { $0.id == id && $0.isAlive }) else { return nil }
                return (idx, encounter.monsters[idx])
            }

            guard let dmgDice = spell.damage else { return nil }
            let baseRoll = Dice.rollDamage(dmgDice)
            let baseDamage = max(1, baseRoll.total)
            damageRolls = baseRoll.rolls
            totalDamage = 0

            let saveAbility: Ability = {
                switch spell.savingThrowAbility {
                case "dexterity": return .dexterity
                case "wisdom": return .wisdom
                case "constitution": return .constitution
                default: return .dexterity
                }
            }()

            for (idx, var monster) in targets {
                let saveMod = monster.armorClass > 14 ? 3 : 1  // Simple save estimate
                let save = Dice.savingThrow(modifier: saveMod, dc: saveDC)
                saveResults.append((monster.name, save.roll, save.total, save.success))

                let damage: Int
                if save.success && spell.halfDamageOnSave {
                    damage = baseDamage / 2
                } else if save.success {
                    damage = 0
                } else {
                    damage = baseDamage
                    targetsHit.append(monster.name)
                }

                if damage > 0 {
                    totalDamage += damage
                    monster.takeDamage(damage)
                    encounter.monsters[idx] = monster
                    if !monster.isAlive { targetsDefeated.append(monster.name) }
                }
                targetStatuses.append((monster.name, monster.currentHP, monster.maxHP))
            }

        case .autoHit:
            // Magic Missile / Sleep
            guard let targetId = targetIds.first,
                  let monsterIndex = encounter.monsters.firstIndex(where: { $0.id == targetId }) else { return nil }
            var monster = encounter.monsters[monsterIndex]
            targetName = monster.name

            if spell.damageType == "sleep" {
                // Sleep: roll 5d8, if total >= monster HP, they "die" (knocked out)
                let roll = Dice.rollDamage(spell.damage ?? "5d8")
                damageRolls = roll.rolls
                totalDamage = roll.total
                if roll.total >= monster.currentHP {
                    monster.takeDamage(monster.currentHP)
                    encounter.monsters[monsterIndex] = monster
                    targetsHit.append(monster.name)
                    targetsDefeated.append(monster.name)
                }
                targetStatuses.append((monster.name, monster.currentHP, monster.maxHP))
            } else {
                // Magic Missile: auto-hit damage
                let roll = Dice.rollDamage(spell.damage ?? "3d4+3")
                let damage = max(1, roll.total)
                totalDamage = damage
                damageRolls = roll.rolls
                targetsHit.append(monster.name)

                monster.takeDamage(damage)
                encounter.monsters[monsterIndex] = monster
                if !monster.isAlive { targetsDefeated.append(monster.name) }
                targetStatuses.append((monster.name, monster.currentHP, monster.maxHP))
            }
            hits = true

        case .healing:
            // Heal a party member
            guard let targetId = targetIds.first,
                  let target = party.first(where: { $0.id == targetId }) else { return nil }
            targetName = target.name

            let roll = Dice.rollDamage(spell.healAmount ?? "1d8")
            var heal = max(1, roll.total)
            if spell.usesCasterMod {
                heal += casterAbilityMod
            }
            healAmount = heal
            damageRolls = roll.rolls
            target.heal(heal)
            targetStatuses.append((target.name, target.currentHP, target.maxHP))

        case .buff:
            // Hunter's Mark
            caster.huntersMarkActive = true
            targetName = caster.name

        case .utility:
            // Spare the Dying
            guard let targetId = targetIds.first,
                  let target = party.first(where: { $0.id == targetId }) else { return nil }
            targetName = target.name
            target.deathSaveSuccesses = 3  // Stabilized
        }

        combatLog.append("\(caster.name) casts \(spell.name)")

        return SpellReport(
            casterName: caster.name,
            spellName: spell.name,
            spellType: spell.spellType,
            d20Roll: d20Roll,
            attackBonus: attackBonus,
            totalAttack: totalAttack,
            targetAC: targetAC,
            hits: hits,
            isCritical: isCritical,
            saveDC: saveResults.isEmpty ? nil : saveDC,
            saveResults: saveResults,
            damageRolls: damageRolls,
            totalDamage: totalDamage,
            healAmount: healAmount,
            damageType: spell.damageType,
            targetName: targetName,
            targetsHit: targetsHit,
            targetsDefeated: targetsDefeated,
            targetStatuses: targetStatuses
        )
    }

    /// Returns display names for a list of monsters, numbering duplicates (e.g. "Goblin 1", "Goblin 2")
    static func numberedMonsterNames(_ monsters: [Monster]) -> [String] {
        var nameCounts: [String: Int] = [:]
        for m in monsters { nameCounts[m.name, default: 0] += 1 }

        var nameIndex: [String: Int] = [:]
        var result: [String] = []
        for m in monsters {
            if nameCounts[m.name, default: 1] > 1 {
                nameIndex[m.name, default: 0] += 1
                result.append("\(m.name) \(nameIndex[m.name]!)")
            } else {
                result.append(m.name)
            }
        }
        return result
    }

    func displayStatus() -> [String] {
        var lines: [String] = []

        lines.append("───── COMBAT ─────")
        lines.append("")

        for char in party {
            let s = char.isConscious ? "●" : "✗"
            let n = String(char.name.prefix(16))
            lines.append(" \(s) \(n) \(char.currentHP)/\(char.maxHP)")
        }

        lines.append("")
        let monsterNames = Combat.numberedMonsterNames(encounter.monsters)
        for (i, monster) in encounter.monsters.enumerated() {
            let s = monster.isAlive ? "●" : "✗"
            let n = String(monsterNames[i].prefix(16))
            lines.append(" \(s) \(n) \(monster.currentHP)/\(monster.maxHP)")
        }

        lines.append("──────────────────")

        return lines
    }
}
