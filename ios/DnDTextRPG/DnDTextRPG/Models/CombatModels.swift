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
    var maxHP: Int
    var armorClass: Int
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
    case rustMonster = "Rust Monster"
    // Mid (CR 1-2)
    case bugbear = "Bugbear"
    case giantSpider = "Giant Spider"
    case ogre = "Ogre"
    case gargoyle = "Gargoyle"
    case mimic = "Mimic"
    case gelatinousCube = "Gelatinous Cube"
    // High (CR 3+)
    case owlbear = "Owlbear"
    case troll = "Troll"
    case minotaur = "Minotaur"
    case basilisk = "Basilisk"
    case displacerBeast = "Displacer Beast"
    case wraith = "Wraith"
    case demogorgon = "Demogorgon"
    case mindFlayer = "Mind Flayer"
    // Boss (CR 10+)
    case beholder = "Beholder"
    case youngDragon = "Young Dragon"
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
        case .rustMonster:
            return Stats(hp: 27, ac: 14, attackBonus: 3, damage: "1d8+1", cr: 0.5, xp: 100)
        // Mid
        case .bugbear:
            return Stats(hp: 27, ac: 16, attackBonus: 4, damage: "2d8+2", cr: 1, xp: 200)
        case .giantSpider:
            return Stats(hp: 26, ac: 14, attackBonus: 5, damage: "1d8+3", cr: 1, xp: 200)
        case .ogre:
            return Stats(hp: 59, ac: 11, attackBonus: 6, damage: "2d8+4", cr: 2, xp: 450)
        case .gargoyle:
            return Stats(hp: 52, ac: 15, attackBonus: 4, damage: "2d6+2", cr: 2, xp: 450)
        case .mimic:
            return Stats(hp: 58, ac: 12, attackBonus: 5, damage: "1d8+3", cr: 2, xp: 450)
        case .gelatinousCube:
            return Stats(hp: 84, ac: 6, attackBonus: 4, damage: "2d6+1", cr: 2, xp: 450)
        // High
        case .owlbear:
            return Stats(hp: 59, ac: 13, attackBonus: 7, damage: "2d8+5", cr: 3, xp: 700)
        case .troll:
            return Stats(hp: 84, ac: 15, attackBonus: 7, damage: "2d6+4", cr: 5, xp: 1800)
        case .minotaur:
            return Stats(hp: 76, ac: 14, attackBonus: 6, damage: "2d8+4", cr: 3, xp: 700)
        case .basilisk:
            return Stats(hp: 52, ac: 15, attackBonus: 5, damage: "2d6+3", cr: 3, xp: 700)
        case .displacerBeast:
            return Stats(hp: 85, ac: 13, attackBonus: 6, damage: "1d10+4", cr: 3, xp: 700)
        case .wraith:
            return Stats(hp: 67, ac: 13, attackBonus: 6, damage: "3d6+3", cr: 5, xp: 1800)
        case .demogorgon:
            return Stats(hp: 68, ac: 14, attackBonus: 7, damage: "2d8+4", cr: 4, xp: 1100)
        case .mindFlayer:
            return Stats(hp: 71, ac: 15, attackBonus: 7, damage: "2d10+3", cr: 7, xp: 2900)
        case .beholder:
            return Stats(hp: 180, ac: 18, attackBonus: 9, damage: "3d8+4", cr: 13, xp: 10000)
        case .youngDragon:
            return Stats(hp: 142, ac: 18, attackBonus: 10, damage: "2d10+5", cr: 10, xp: 5900)
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
        case .hobgoblin: return "A disciplined goblinoid soldier in armour."
        case .giantSpider: return "A massive arachnid with dripping fangs."
        case .gnoll: return "A hyena-headed humanoid savage."
        case .rustMonster: return "An insectoid creature whose antennae corrode metal on contact."
        case .bugbear: return "A large, hairy goblinoid ambusher."
        case .ogre: return "A towering brute of immense strength."
        case .gargoyle: return "A winged stone creature that lurks motionless until it strikes."
        case .mimic: return "A shapeshifter disguised as a treasure chest, waiting to devour the greedy."
        case .gelatinousCube: return "A nearly transparent cube of acidic jelly that fills the corridor."
        case .owlbear: return "A fearsome hybrid of owl and bear."
        case .troll: return "A lanky giant with regenerating flesh."
        case .minotaur: return "A hulking bull-headed humanoid that charges through the labyrinth."
        case .basilisk: return "An eight-legged reptile whose gaze turns flesh to stone."
        case .displacerBeast: return "A six-legged panther with barbed tentacles, its image always shifting."
        case .wraith: return "A spectral undead wreathed in shadow, draining the life from all it touches."
        case .demogorgon: return "A terrifying creature from the Upside Down with a gaping flower-like maw."
        case .mindFlayer: return "An aberration with tentacles protruding from its face, wielding psionic power."
        case .beholder: return "A floating sphere of flesh with a central eye and many stalks, each firing a deadly ray."
        case .youngDragon: return "A fearsome dragon not yet fully grown, but deadly with fang, claw, and fiery breath."
        case .vecna: return "The Undying King, a lich of immense power reaching between worlds."
        }
    }

    /// Flavorful attack descriptions — randomly selected each attack
    var attackDescriptions: [String] {
        switch self {
        case .giantRat:
            return ["its filthy teeth", "a savage bite", "its diseased claws", "a lunging gnaw"]
        case .kobold:
            return ["a rusty spear", "a tiny dagger", "a crude sling stone", "a sharpened stick"]
        case .stirge:
            return ["its blood-draining proboscis", "a piercing sting", "its barbed tongue"]
        case .giantBat:
            return ["razor-sharp talons", "a swooping bite", "its leathery wings"]
        case .crawlingClaw:
            return ["its bony fingers", "a crushing grip", "a scratching swipe", "a throttling squeeze"]
        case .goblin:
            return ["a jagged scimitar", "a crude shortbow", "a rusty dagger", "its foul breath and a wild swing"]
        case .skeleton:
            return ["a rusty shortsword", "a crumbling mace", "a notched battleaxe", "its bony fist"]
        case .zombie:
            return ["its rotting fists", "a shambling lunge", "grasping dead hands", "a putrid bite"]
        case .wolf:
            return ["snapping jaws", "a lunging bite", "its powerful fangs", "a pouncing tackle"]
        case .orc:
            return ["a brutal greataxe", "a heavy javelin", "a savage headbutt", "its iron-shod fist"]
        case .hobgoblin:
            return ["a disciplined longsword strike", "a heavy crossbow bolt", "a shield bash", "a precise spear thrust"]
        case .giantSpider:
            return ["venomous fangs", "a web-tangling spray", "its dripping mandibles", "a poisoned bite"]
        case .gnoll:
            return ["a barbed spear", "its hyena-like jaws", "a crude flail", "a savage claw swipe"]
        case .rustMonster:
            return ["its corroding antennae", "a rusting touch", "its gnashing mandibles", "an armour-dissolving swipe"]
        case .bugbear:
            return ["a heavy morningstar", "a crushing bear hug", "a spiked club", "a sneaky backstab"]
        case .ogre:
            return ["a massive greatclub", "a boulder-like fist", "a sweeping tree-trunk swing", "a ground-shaking stomp"]
        case .gargoyle:
            return ["its stone claws", "a diving swoop", "a crushing stone fist", "its fanged bite"]
        case .mimic:
            return ["its adhesive pseudopod", "a snapping lid-jaw", "a grasping tongue", "its crushing bite"]
        case .gelatinousCube:
            return ["its engulfing mass", "a wave of acid", "a dissolving pseudopod", "its corrosive surface"]
        case .owlbear:
            return ["its razor beak", "massive claws", "a devastating bear swipe", "a screeching lunge"]
        case .troll:
            return ["its regenerating claws", "a raking slash", "its foul bite", "a long-armed backhand"]
        case .minotaur:
            return ["its massive horns", "a charging gore", "a greataxe cleave", "a trampling hoof"]
        case .basilisk:
            return ["its petrifying gaze", "venomous fangs", "a lunging bite", "its crushing jaws"]
        case .displacerBeast:
            return ["a barbed tentacle", "its shifting claws", "a lashing tendril", "a pouncing bite"]
        case .wraith:
            return ["its life-draining touch", "a spectral claw", "a chilling grasp", "a soul-sapping swipe"]
        case .demogorgon:
            return ["its gaping flower-maw", "a tentacle lash", "a psychic screech", "its crushing tendrils"]
        case .mindFlayer:
            return ["a mind-shattering blast", "its writhing tentacles", "a psionic assault", "its brain-extracting grasp"]
        case .beholder:
            return ["a disintegration ray", "its antimagic eye", "a paralyzing beam", "a death ray"]
        case .youngDragon:
            return ["a searing fire breath", "its rending claws", "a crushing tail swipe", "its snapping jaws"]
        case .vecna:
            return ["a necrotic ray", "the Hand of Vecna", "a soul-rending spell", "a withering touch of undeath"]
        }
    }

    /// Whether this monster type can inflict poison
    var canPoison: Bool {
        switch self {
        case .giantSpider, .stirge, .giantRat, .gelatinousCube, .basilisk, .youngDragon: return true
        default: return false
        }
    }

    /// Chance of inflicting poison (0.0-1.0) on a successful hit
    var poisonChance: Double {
        switch self {
        case .giantSpider: return 0.35
        case .stirge: return 0.25
        case .giantRat: return 0.15
        case .gelatinousCube: return 0.40
        case .basilisk: return 0.30
        case .youngDragon: return 0.25
        default: return 0.0
        }
    }

    /// Poison damage per turn
    var poisonDamagePerTurn: Int {
        switch self {
        case .giantSpider: return 3
        case .stirge: return 2
        case .giantRat: return 1
        case .gelatinousCube: return 4
        case .basilisk: return 3
        case .youngDragon: return 5
        default: return 0
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
        case .rustMonster:
            return [
                "    /\\  /\\",
                "   (  ==  )",
                "  /|~~~~~~|\\",
                "   |  ()  |",
                "   d d  d d",
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
        case .gargoyle:
            return [
                "   _/|\\_",
                "  / o  o \\",
                "  | \\VV/ |",
                " _/| || |\\_",
                " V  |/\\|  V",
            ]
        case .mimic:
            return [
                "  .-------.",
                " / ~ ~~ ~ \\",
                " | |@  @| |",
                " | |VVVV| |",
                "  \\_______/",
            ]
        case .gelatinousCube:
            return [
                "  .-------.",
                "  | .   . |",
                "  |  ; ;  |",
                "  | .   . |",
                "  '-------'",
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
        case .minotaur:
            return [
                "   (\\   /)",
                "    \\o_o/",
                "   --|+|--",
                "   /|| ||\\",
                "   d|   |b",
            ]
        case .basilisk:
            return [
                "   ___/\\",
                "  (o  o >",
                "  /\\~~~~\\",
                " / /||||  \\",
                " d d    d d",
            ]
        case .displacerBeast:
            return [
                "    /\\_/\\",
                "   ( o.o )",
                "  ~/|   |\\~",
                " / /|   |\\ \\",
                "  d d   d d",
            ]
        case .wraith:
            return [
                "   .oOOo.",
                "  ( O  O )",
                "   \\~~~~/ ",
                "   /|  |\\",
                "  ~ ~  ~ ~",
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
        case .beholder:
            return [
                "  \\~ ~|~ ~/",
                "   .-----.",
                "  ( ( O ) )",
                "   '-----'",
                "  /~ ~|~ ~\\",
            ]
        case .youngDragon:
            return [
                "   /\\_/\\  __",
                "  / o o \\/  \\",
                "  \\ >><  \\--/",
                " /|/    \\|\\",
                " d d    d d~~",
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

    /// Animation frames for bestiary idle animations (eyes, tails, limbs)
    var asciiArtFrames: [[String]] {
        switch self {
        case .giantRat:
            return [
                ["      /\\  /\\", "     (  ..  )", "      )    (", "     /||||||\\", "    ~ ~~~~~  ~"],
                ["      /\\  /\\", "     (  oo  )", "      )    (", "     /||||||\\", "    ~  ~~~~~ ~"],
                ["      /\\  /\\", "     ( ..   )", "      )    (", "     /||||||\\", "    ~ ~~~~~  ~"],
            ]
        case .kobold:
            return [
                ["     /\\", "    (><)", "    /|\\", "   / | \\", "     A"],
                ["     /\\", "    (>< )", "    /|\\", "   / | \\", "    A"],
                ["     /\\", "    ( ><)", "    /|\\", "   / | \\", "     A"],
            ]
        case .stirge:
            return [
                ["    _/\\_", "   / () \\", "   \\    /", "    |--|", "     \\/"],
                ["   _/ \\_", "  /  () \\", "   \\    /", "    |--|", "     \\/"],
                ["    _/\\_", "   / () \\", "   \\    /", "    |--|", "     \\/"],
            ]
        case .giantBat:
            return [
                ["  _/    \\_", " / \\(oo)/ \\", "/   \\  /   \\", "     \\/"],
                [" _/      \\_", "/  \\(oo)/  \\", "    \\  /", "     \\/"],
                ["  _/    \\_", " / \\(oo)/ \\", "/   \\  /   \\", "     \\/"],
            ]
        case .crawlingClaw:
            return [
                ["    ___", "   /   \\", "  | === |", "   \\|||/", "    \\|/"],
                ["    ___", "   /   \\", "  | === |", "   \\|||/", "     |/"],
                ["    ___", "   /   \\", "  | === |", "   \\|||/", "    \\|"],
            ]
        case .goblin:
            return [
                ["    /\\", "   (oo)", "  _/||\\_", " / /||  \\", "   /  \\"],
                ["    /\\", "   (oO)", "  _/||\\_", " / /||  \\", "   /  \\"],
                ["    /\\", "   (Oo)", "  _/||\\_", " / /||  \\", "  /  \\"],
            ]
        case .skeleton:
            return [
                ["    .-..", "   (o o)", "   | O |", "   /| |\\", "   d| |b"],
                ["    .-..", "   ( oo)", "   | O |", "   /| |\\", "   d| |b"],
                ["    .-..", "   (oo )", "   | O |", "   /| |\\", "   d| |b"],
            ]
        case .zombie:
            return [
                ["   _____", "  /x   x\\", "  | ~~~ |", "  /|   |\\", "   |___|"],
                ["   _____", "  /x   x\\", "  | ~~~ |", " /|    |\\", "   |___|"],
                ["   _____", "  / x  x\\", "  | ~~~ |", "  /|   |\\", "   |___|"],
            ]
        case .wolf:
            return [
                ["   /\\_/\\", "  ( o.o )", "   > ^ <", "  /|   |\\", "  _/   \\_"],
                ["   /\\_/\\", "  ( o.o )", "   > ^ <", "  /|   |\\", " _/    \\_"],
                ["   /\\_/\\", "  ( O.O )", "   > ^ <", "  /|   |\\", "  _/   \\_"],
            ]
        case .orc:
            return [
                ["   ___", "  /o_o\\", "  \\VVV/", "  /| |\\", "  d| |b"],
                ["   ___", "  /O_o\\", "  \\VVV/", "  /| |\\", "  d| |b"],
                ["   ___", "  /o_O\\", "  \\VVV/", "  /| |\\", "  d| |b"],
            ]
        case .hobgoblin:
            return [
                ["  [===]", "  |o_o|", "  /|#|\\", " /=| |=\\", "   d b"],
                ["  [===]", "  |o_O|", "  /|#|\\", " /=| |=\\", "   d b"],
                ["  [===]", "  |O_o|", "  /|#|\\", " /=| |=\\", "   d b"],
            ]
        case .giantSpider:
            return [
                [" \\ |o o| /", "  \\(   )/", "  /(   )\\", " / |___| \\"],
                ["  \\|o o|/", "  \\(   )/", "  /(   )\\", "  /|___| \\"],
                [" \\ |o o| /", "  \\(   )/", "  /(   )\\", " / |___| \\"],
            ]
        case .gnoll:
            return [
                ["    /V\\", "   (o o)", "  --|~|--", "   /| |\\", "   d| |b"],
                ["    /V\\", "   (o.o)", "  --|~|--", "   /| |\\", "   d| |b"],
                ["    /V\\", "   (O o)", "  --|~|--", "   /| |\\", "   d| |b"],
            ]
        case .rustMonster:
            return [
                ["    /\\  /\\", "   (  ==  )", "  /|~~~~~~|\\", "   |  ()  |", "   d d  d d"],
                ["    /\\  /\\", "   (  ==  )", "  /|~~~~~~|\\", "   |  ()  |", "  d d    d d"],
                ["    /\\  /\\", "   ( ==   )", "  /|~~~~~~|\\", "   |  ()  |", "   d d  d d"],
            ]
        case .bugbear:
            return [
                ["   (\\=/)", "   (o.o)", "  //| |\\\\", " // | | \\\\", "    d b"],
                ["   (\\=/)", "   (O.o)", "  //| |\\\\", " // | | \\\\", "    d b"],
                ["   (\\=/)", "   (o.O)", "  //| |\\\\", " // | | \\\\", "   d   b"],
            ]
        case .ogre:
            return [
                ["   .-\"\"-.", "  / O  O \\", "  |  __  |", "  /|/  \\|\\", " / |    | \\"],
                ["   .-\"\"-.", "  /  O O  \\", "  |  __  |", "  /|/  \\|\\", " / |    | \\"],
                ["   .-\"\"-.", "  / O  O \\", "  |  __  |", " /|/  \\|\\", "  / |    | \\"],
            ]
        case .gargoyle:
            return [
                ["   _/|\\_", "  / o  o \\", "  | \\VV/ |", " _/| || |\\_", " V  |/\\|  V"],
                ["   _/|\\_", "  / O  o \\", "  | \\VV/ |", " _/| || |\\_", " V  |/\\|  V"],
                ["   _/|\\_", "  / o  O \\", "  | \\VV/ |", " _/| || |\\_", " V  |/\\|  V"],
            ]
        case .mimic:
            return [
                ["  .-------.", " / ~ ~~ ~ \\", " | |@  @| |", " | |VVVV| |", "  \\_______/"],
                ["  .-------.", " / ~ ~~ ~ \\", " | |@  @| |", " | | VV | |", "  \\_______/"],
                ["  .------.", " /~ ~~ ~ ~\\", " | |@  @| |", " | |VVVV| |", "  \\_______/"],
            ]
        case .gelatinousCube:
            return [
                ["  .-------.", "  | .   . |", "  |  ; ;  |", "  | .   . |", "  '-------'"],
                ["  .-------.", "  |  .  . |", "  | ;   ; |", "  |  . .  |", "  '-------'"],
                ["  .-------.", "  | .  .  |", "  |  ;  ; |", "  | .   . |", "  '-------'"],
            ]
        case .owlbear:
            return [
                ["   /\\'v'/\\", "  ( o   o )", "  /|  ^  |\\", " / | /|\\ | \\", "   |/   \\|"],
                ["   /\\'v'/\\", "  (  o  o )", "  /|  ^  |\\", " / | /|\\ | \\", "   |/   \\|"],
                ["   /\\'v'/\\", "  ( o  o  )", "  /|  ^  |\\", " / | /|\\ | \\", "   |/   \\|"],
            ]
        case .troll:
            return [
                ["     /|", "   (x x)", "   /| |\\", "  / | | \\", " /  | |  \\"],
                ["     /|", "   (X x)", "   /| |\\", "  / | | \\", " /  | |  \\"],
                ["     /|", "   (x X)", "   /| |\\", "  / | |  \\", " /  | | \\"],
            ]
        case .minotaur:
            return [
                ["   (\\   /)", "    \\o_o/", "   --|+|--", "   /|| ||\\", "   d|   |b"],
                ["   (\\   /)", "    \\O_o/", "   --|+|--", "   /|| ||\\", "   d|   |b"],
                ["   (\\   /)", "    \\o_O/", "  ---|+|--", "   /|| ||\\", "   d|   |b"],
            ]
        case .basilisk:
            return [
                ["   ___/\\", "  (o  o >", "  /\\~~~~\\", " / /||||  \\", " d d    d d"],
                ["   ___/\\", "  (O  o >", "  /\\~~~~\\", " / /||||  \\", "  d d  d d"],
                ["   ___/\\", "  (o  O >", "  /\\~~~~\\", " / /||||  \\", " d d    d d"],
            ]
        case .displacerBeast:
            return [
                ["    /\\_/\\", "   ( o.o )", "  ~/|   |\\~", " / /|   |\\ \\", "  d d   d d"],
                ["    /\\_/\\", "   ( O.o )", " ~/|    |\\~", " / /|   |\\ \\", "  d d   d d"],
                ["    /\\_/\\", "   ( o.O )", "  ~/|   |\\~", " / /|   |\\ \\", " d d     d d"],
            ]
        case .wraith:
            return [
                ["   .oOOo.", "  ( O  O )", "   \\~~~~/ ", "   /|  |\\", "  ~ ~  ~ ~"],
                ["   .oOOo.", "  (  O O  )", "   \\~~~~/ ", "   /|  |\\", "  ~  ~ ~  ~"],
                ["   .oOOo.", "  ( O  O )", "   \\~~~~/ ", "  /|    |\\", "  ~ ~  ~ ~"],
            ]
        case .demogorgon:
            return [
                ["   \\|/|\\|/", "    \\|||/", "   (     )", "   /|   |\\", "  / |   | \\"],
                ["   \\|/|\\|/", "    \\|||/", "   (     )", "   /|   |\\", "  / |   | \\"],
                ["    |/|\\|/", "    \\|||/", "   (     )", "  /|    |\\", "  / |   | \\"],
            ]
        case .mindFlayer:
            return [
                ["    .-\"\"\"-.  ", "   ( o   o )", "    \\|||||/", "   /||   ||\\", "    /|   |\\"],
                ["    .-\"\"\"-.  ", "   (  o  o )", "    \\|||||/", "   /||   ||\\", "    /|   |\\"],
                ["    .-\"\"\"-.  ", "   ( o  o  )", "    \\|||||/", "   /||   ||\\", "    /|   |\\"],
            ]
        case .beholder:
            return [
                ["  \\~ ~|~ ~/", "   .-----.", "  ( ( O ) )", "   '-----'", "  /~ ~|~ ~\\"],
                ["  \\~ ~|~ ~/", "   .-----.", "  (( O )  )", "   '-----'", "  /~ ~|~ ~\\"],
                ["  \\~~| ~~/ ", "   .-----.", "  (  ( O ))", "   '-----'", "  /~ ~|~ ~\\"],
            ]
        case .youngDragon:
            return [
                ["   /\\_/\\  __", "  / o o \\/  \\", "  \\ >><  \\--/", " /|/    \\|\\", " d d    d d~~"],
                ["   /\\_/\\  __", "  / O o \\/  \\", "  \\ >><  \\--/", " /|/    \\|\\", " d d    d d ~"],
                ["   /\\_/\\  __", "  / o O \\/  \\", "  \\ >><  \\--/", " /|/    \\|\\", " d d    d d~~"],
            ]
        case .vecna:
            return [
                ["   .--VVV--.", "  / (X) (o) \\", "  | /===\\ |", "  /| /#\\ |\\", " / |/   \\| \\"],
                ["   .--VVV--.", "  / (X) (O) \\", "  | /===\\ |", "  /| /#\\ |\\", " / |/   \\| \\"],
                ["   .--VVV--.", "  / (X) (o) \\", "  | /===\\ |", " /| /#\\ |\\", "  / |/   \\| \\"],
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
            return [.goblin, .skeleton, .orc, .hobgoblin, .gnoll, .rustMonster]
        case 4:
            return [.orc, .hobgoblin, .bugbear, .giantSpider, .gnoll, .gargoyle, .mimic]
        case 5:
            return [.bugbear, .giantSpider, .ogre, .gelatinousCube, .minotaur, .basilisk]
        case 6:
            return [.ogre, .owlbear, .troll, .displacerBeast, .wraith, .demogorgon, .mindFlayer]
        default:
            return [.troll, .demogorgon, .mindFlayer, .beholder, .youngDragon, .wraith]
        }
    }

    static func boss(forLevel level: Int) -> MonsterType {
        switch level {
        case 1: return .goblin
        case 2: return .bugbear
        case 3: return .ogre
        case 4: return .owlbear
        case 5: return .demogorgon
        case 6: return .mindFlayer
        case 7: return .beholder
        default: return .vecna
        }
    }

    /// Roll for possible loot drop from this monster type
    func rollLoot() -> TreasureItem? {
        let roll = Dice.d20()
        switch self {
        // Starter monsters — rare small drops
        case .giantRat, .stirge, .giantBat, .crawlingClaw:
            if roll >= 18 { return TreasureItem(name: "Dagger", value: 2, type: .item) }
            if roll >= 15 { return TreasureItem(name: "\(Dice.d6() * 2) Gold Pieces", value: Dice.d6() * 2, type: .gold) }
            // Poisonous creatures sometimes drop antidotes (from their own resistance)
            if canPoison && roll >= 12 { return TreasureItem(name: "Antidote", value: 30, type: .potion) }
            return nil
        case .kobold:
            if roll >= 18 { return TreasureItem(name: "Antidote", value: 30, type: .potion) }
            if roll >= 16 { return TreasureItem(name: "Shortsword", value: 10, type: .item) }
            if roll >= 12 { return TreasureItem(name: "\(Dice.d6() * 3) Gold Pieces", value: Dice.d6() * 3, type: .gold) }
            return nil
        // Low — occasional drops
        case .goblin, .skeleton, .zombie, .wolf:
            if roll >= 17 { return TreasureItem(name: "Potion of Healing", value: 50, type: .potion) }
            if roll >= 14 { return TreasureItem(name: "Dagger", value: 2, type: .item) }
            if roll >= 10 { return TreasureItem(name: "\(Dice.rollSum(2, d: 6) * 5) Gold Pieces", value: Dice.rollSum(2, d: 6) * 5, type: .gold) }
            return nil
        // Mid — better drops
        case .orc, .hobgoblin, .gnoll, .rustMonster:
            if roll >= 16 { return TreasureItem(name: "Potion of Healing", value: 50, type: .potion) }
            if roll >= 13 { return TreasureItem(name: "Longsword", value: 15, type: .item) }
            if roll >= 8 { return TreasureItem(name: "\(Dice.rollSum(3, d: 6) * 5) Gold Pieces", value: Dice.rollSum(3, d: 6) * 5, type: .gold) }
            return nil
        // High — good drops
        case .bugbear, .giantSpider, .ogre, .gargoyle, .mimic, .gelatinousCube:
            if roll >= 15 { return TreasureItem(name: "Potion of Greater Healing", value: 150, type: .potion) }
            if canPoison && roll >= 13 { return TreasureItem(name: "Antidote", value: 30, type: .potion) }
            if roll >= 12 { return TreasureItem(name: "Scale Mail", value: 50, type: .item) }
            if roll >= 7 { return TreasureItem(name: "\(Dice.rollSum(4, d: 6) * 10) Gold Pieces", value: Dice.rollSum(4, d: 6) * 10, type: .gold) }
            return nil
        // Boss — guaranteed drops
        case .owlbear, .troll, .minotaur, .basilisk, .displacerBeast, .wraith, .demogorgon, .mindFlayer, .beholder, .youngDragon, .vecna:
            if roll >= 10 { return TreasureItem(name: "Potion of Greater Healing", value: 150, type: .potion) }
            return TreasureItem(name: "\(Dice.rollSum(5, d: 6) * 10) Gold Pieces", value: Dice.rollSum(5, d: 6) * 10, type: .gold)
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

    /// Adjust monster ACs so the party hits roughly 65% of the time (medium).
    /// Easy = 75%, Medium = 65%, Hard = 55%, Deadly = 50%.
    mutating func balanceAC(partyAvgAttackBonus: Int) {
        let targetRoll: Int
        switch difficulty {
        case .easy:   targetRoll = 6   // 75% hit
        case .medium: targetRoll = 8   // 65% hit
        case .hard:   targetRoll = 10  // 55% hit
        case .deadly: targetRoll = 11  // 50% hit
        }
        let idealAC = targetRoll + partyAvgAttackBonus
        for i in monsters.indices {
            let baseAC = monsters[i].type.stats.ac
            // Don't deviate more than ±3 from base stats
            monsters[i].armorClass = max(baseAC - 3, min(baseAC + 3, idealAC))
        }
    }
    var bossDifficulty: BossDifficulty? = nil

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

    enum BossDifficulty: String, Codable {
        case easy, medium, hard
    }

    static func generateBoss(level: Int) -> Encounter {
        let bossType = MonsterType.boss(forLevel: level)
        var boss = Monster.create(bossType)

        // Roll boss difficulty: 20% easy, 50% medium, 30% hard
        let roll = Int.random(in: 1...10)
        let bossDiff: BossDifficulty
        let hpMult: Double
        let acBonus: Int
        let atkBonus: Int
        if roll <= 2 {
            bossDiff = .easy
            hpMult = level == 1 ? 1.3 : 1.5
            acBonus = level == 1 ? 0 : 1
            atkBonus = level == 1 ? 1 : 1
        } else if roll <= 7 {
            bossDiff = .medium
            hpMult = level == 1 ? 1.8 : 2.0
            acBonus = level == 1 ? 1 : 2
            atkBonus = level == 1 ? 1 : 2
        } else {
            bossDiff = .hard
            hpMult = level == 1 ? 2.2 : 2.5
            acBonus = level == 1 ? 2 : 3
            atkBonus = level == 1 ? 2 : 2
        }

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

        return Encounter(monsters: monsters, difficulty: .deadly, bossDifficulty: bossDiff)
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

    // Battle scene visuals
    let attackerArt: [String]
    let defenderArt: [String]
    let weaponName: String

    // Status effects
    let poisonApplied: Bool
}

// MARK: - Combat State

enum CombatState: String, Codable {
    case ongoing
    case victory
    case defeat
}

struct TurnOrderEntry: Codable, Equatable {
    let id: UUID
    let name: String
    let isPlayer: Bool
    let initiative: Int
}

final class Combat: ObservableObject {
    @Published var party: [Character]
    @Published var encounter: Encounter
    @Published var turnOrder: [TurnOrderEntry]
    @Published var currentTurnIndex: Int
    @Published var state: CombatState
    @Published var combatLog: [String]

    var currentCombatant: TurnOrderEntry? {
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
        var initiatives: [TurnOrderEntry] = []

        // Roll for party
        for char in party {
            let initiative = Dice.rollInitiative(dexModifier: char.abilityScores.modifier(for: .dexterity))
            initiatives.append(TurnOrderEntry(id: char.id, name: char.name, isPlayer: true, initiative: initiative))
        }

        // Roll for monsters
        for monster in encounter.monsters {
            let initiative = Dice.d20() + 1  // Simplified monster initiative
            initiatives.append(TurnOrderEntry(id: monster.id, name: monster.name, isPlayer: false, initiative: initiative))
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

    private func isCombatantAlive(_ combatant: TurnOrderEntry) -> Bool {
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

    func playerAttack(characterId: UUID, targetId: UUID, disadvantage: Bool = false) -> AttackReport? {
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
        let attack = Dice.attackRoll(modifier: attackMod, targetAC: monster.armorClass, disadvantage: disadvantage)

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
            targetMaxHP: monster.maxHP,
            attackerArt: character.characterClass.asciiArt,
            defenderArt: monster.type.asciiArt,
            weaponName: character.equippedWeapon?.name ?? "Unarmed",
            poisonApplied: false
        )

        combatLog.append("\(character.name) attacks \(monster.name)")
        return report
    }

    func monsterAttack(monsterId: UUID, targetId: UUID) -> AttackReport? {
        guard let monster = encounter.monsters.first(where: { $0.id == monsterId }),
              let character = party.first(where: { $0.id == targetId }) else {
            return nil
        }

        let attackDesc = monster.type.attackDescriptions.randomElement() ?? monster.type.rawValue
        let hasDisadvantage = character.isDodging
        let attack = Dice.attackRoll(modifier: monster.attackBonus, targetAC: character.armorClass, disadvantage: hasDisadvantage)
        let breakdown = hasDisadvantage
            ? "Attack +\(monster.attackBonus) (DISADVANTAGE — target dodging!)"
            : "Attack +\(monster.attackBonus)"

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

        // Check for poison
        var didPoison = false
        if attack.hits && monster.type.canPoison && !character.isPoisoned {
            let roll = Double.random(in: 0...1)
            if roll < monster.type.poisonChance {
                let turns = Int.random(in: 2...4)
                character.applyPoison(damagePerTurn: monster.type.poisonDamagePerTurn, turns: turns)
                didPoison = true
            }
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
            targetMaxHP: character.maxHP,
            attackerArt: monster.type.asciiArt,
            defenderArt: character.characterClass.asciiArt,
            weaponName: attackDesc,
            poisonApplied: didPoison
        )

        combatLog.append("\(monster.name) attacks \(character.name) with \(attackDesc)")
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

        let maxPartyName = party.map { $0.name.prefix(16).count }.max() ?? 8
        for char in party {
            let s: String
            if char.hasFledCombat || char.isPlayingDead {
                s = "○"  // Out of the fight but not dead
            } else if !char.isConscious {
                s = "✗"
            } else {
                s = char.isComputerControlled ? "◆" : "●"  // ◆ = AI, ● = human
            }
            let n = String(char.name.prefix(16)).padding(toLength: maxPartyName, withPad: " ", startingAt: 0)
            let statusTag = char.hasFledCombat ? " [fled]" : (char.isPlayingDead ? " [playing dead]" : "")
            let hp = String("\(char.currentHP)/\(char.maxHP)").padding(toLength: 7, withPad: " ", startingAt: 0)
            lines.append(" \(s) \(n)  \(hp)\(statusTag)")
        }

        lines.append("")
        let monsterNames = Combat.numberedMonsterNames(encounter.monsters)
        let maxMonName = monsterNames.map { $0.prefix(16).count }.max() ?? 8
        for (i, monster) in encounter.monsters.enumerated() {
            let s = monster.isAlive ? "●" : "✗"
            let n = String(monsterNames[i].prefix(16)).padding(toLength: maxMonName, withPad: " ", startingAt: 0)
            let hp = String("\(monster.currentHP)/\(monster.maxHP)").padding(toLength: 7, withPad: " ", startingAt: 0)
            lines.append(" \(s) \(n)  \(hp)")
        }

        lines.append("──────────────────")

        return lines
    }
}

// MARK: - Combat Codable

extension Combat: Codable {
    enum CodingKeys: String, CodingKey {
        case encounter, turnOrder, currentTurnIndex, state, combatLog, partyCharacterIds
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let encounter = try container.decode(Encounter.self, forKey: .encounter)
        self.init(party: [], encounter: encounter)
        self.turnOrder = try container.decode([TurnOrderEntry].self, forKey: .turnOrder)
        self.currentTurnIndex = try container.decode(Int.self, forKey: .currentTurnIndex)
        self.state = try container.decode(CombatState.self, forKey: .state)
        self.combatLog = try container.decode([String].self, forKey: .combatLog)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(encounter, forKey: .encounter)
        try container.encode(turnOrder, forKey: .turnOrder)
        try container.encode(currentTurnIndex, forKey: .currentTurnIndex)
        try container.encode(state, forKey: .state)
        try container.encode(combatLog, forKey: .combatLog)
        let ids = party.map { $0.id }
        try container.encode(ids, forKey: .partyCharacterIds)
    }

    /// Re-link party references after decoding from match data
    func relinkParty(_ fullParty: [Character]) {
        self.party = fullParty
    }
}
