//
//  NPCModels.swift
//  DnDTextRPG
//
//  NPC types, dialogue, capabilities, and ASCII art for dungeon encounters
//

import Foundation

// MARK: - NPC Type

enum NPCType: String, CaseIterable, Codable {
    case wanderingTrader = "Wandering Trader"
    case prisoner = "Prisoner"
    case hermit = "Hermit"
    case ghostlyScholar = "Ghostly Scholar"
    case dwarvenSmith = "Dwarven Smith"
    case elfScout = "Elf Scout"
    case goblinDefector = "Goblin Defector"
    case mysteriousStranger = "Mysterious Stranger"
    case woundedKnight = "Wounded Knight"
    case madAlchemist = "Mad Alchemist"
    case oldPriestess = "Old Priestess"
    case ratCatcher = "Rat Catcher"
    case gatekeeper = "Gatekeeper"

    // MARK: - ASCII Art

    var asciiArt: [String] {
        switch self {
        case .wanderingTrader:
            return [
                "  _/\\_  ",
                " / oo \\ ",
                " | ## | ",
                " |_||_| ",
                " /|  |\\ ",
                "  |  |  ",
                " _|  |_ ",
            ]
        case .prisoner:
            return [
                "  ||||  ",
                "  |..|  ",
                "  |oo|  ",
                "  ||||  ",
                " /+--+\\ ",
                "  |  |  ",
                "  |  |  ",
            ]
        case .hermit:
            return [
                "  .--.  ",
                " / .. \\ ",
                " | == | ",
                "  \\--/  ",
                " /|~~|\\ ",
                "  | ~|  ",
                "  /  \\  ",
            ]
        case .ghostlyScholar:
            return [
                "  .~~.  ",
                " :    : ",
                " : oo : ",
                " :    : ",
                " :~~~~: ",
                " : ~~ : ",
                "  :  :  ",
            ]
        case .dwarvenSmith:
            return [
                "  [==]  ",
                " /o  o\\ ",
                " |/\\/\\| ",
                "  \\==/  ",
                " /|##|\\ ",
                " T|  |T ",
                "  |__|  ",
            ]
        case .elfScout:
            return [
                "   /|   ",
                "  /oo\\  ",
                "  |  |  ",
                "  \\--/  ",
                " )|  |( ",
                "  |  |  ",
                "  /  \\  ",
            ]
        case .goblinDefector:
            return [
                "  /\\/\\  ",
                " |o  o| ",
                "  \\></ ",
                "  /||\\ ",
                " / || \\ ",
                "   ||   ",
                "  /  \\  ",
            ]
        case .mysteriousStranger:
            return [
                "  /--\\  ",
                " |?  ?| ",
                " |    | ",
                "  \\--/  ",
                " /|..|\\ ",
                "  |..|  ",
                "  /--\\  ",
            ]
        case .woundedKnight:
            return [
                "  [++]  ",
                " /o  o\\ ",
                " | -- | ",
                "  \\++/  ",
                "  |##|  ",
                " /|  |\\ ",
                "  |__|  ",
            ]
        case .madAlchemist:
            return [
                "  _/\\_  ",
                " |o  o| ",
                " | ~~ | ",
                "  \\==/  ",
                " /|{}|\\ ",
                "  |{}|  ",
                "  /  \\  ",
            ]
        case .oldPriestess:
            return [
                "  .+.   ",
                " / .. \\ ",
                " | -- | ",
                "  \\../  ",
                " /|++|\\ ",
                "  |++|  ",
                "  /  \\  ",
            ]
        case .ratCatcher:
            return [
                "  .~~.  ",
                " |o  o| ",
                " | >< | ",
                "  \\--/  ",
                " /|..|\\ ",
                "  | ~|  ",
                "  /  \\  ",
            ]
        case .gatekeeper:
            return [
                " __|__  ",
                " /    \\ ",
                " |o  o| ",
                " | -- | ",
                "  \\==/  ",
                " /|==|\\ ",
                " T|  |T ",
            ]
        }
    }

    // MARK: - Description

    var description: String {
        switch self {
        case .wanderingTrader:
            return "A weathered merchant with a heavy pack, somehow thriving in the dungeon depths. Willing to trade for the right price."
        case .prisoner:
            return "A haggard soul chained to the wall, eyes wide with desperate hope at your arrival."
        case .hermit:
            return "A wild-haired recluse who has made the dungeon their home. They know its secrets better than anyone."
        case .ghostlyScholar:
            return "A translucent figure poring over ancient texts, trapped between worlds by their thirst for knowledge."
        case .dwarvenSmith:
            return "A stocky dwarf tending a makeshift forge, hammer ringing against metal in the gloom."
        case .elfScout:
            return "A lithe elf moving silently through the shadows, bow at the ready. They seem to know these corridors well."
        case .goblinDefector:
            return "A nervous goblin who has turned against their kin. Twitchy but surprisingly helpful."
        case .mysteriousStranger:
            return "A hooded figure leaning against the wall, face hidden in shadow. Their motives are unclear."
        case .woundedKnight:
            return "A battered warrior slumped against a pillar, armour dented and bloodied but spirit unbroken."
        case .madAlchemist:
            return "A wild-eyed alchemist surrounded by bubbling flasks and strange fumes. Their potions are... unpredictable."
        case .oldPriestess:
            return "A serene woman in tattered robes, radiating calm despite the darkness. Holy symbols hang from her neck."
        case .ratCatcher:
            return "A grimy figure clutching a long pole with a cage on the end. They know every tunnel and crawlspace."
        case .gatekeeper:
            return "A weathered warden who lingers at the dungeon entrance, staff in hand. They claim to know what lies below — but can you trust them?"
        }
    }

    // MARK: - Greeting

    var greeting: String {
        switch self {
        case .wanderingTrader:
            return "Ah, customers! Even down here, trade finds a way. Care to browse my wares?"
        case .prisoner:
            return "Please... you must help me! I've been trapped here for days. Free me and I'll show you a secret passage!"
        case .hermit:
            return "Visitors? Haven't seen folk in... what year is it? No matter. Sit. I know things about this place."
        case .ghostlyScholar:
            return "You can see me? How fascinating. I've been studying these ruins for... oh, centuries I suppose."
        case .dwarvenSmith:
            return "Hah! Finally someone who might appreciate good steel. Name's Brok. Need anything fixed or forged?"
        case .elfScout:
            return "Keep your voice down. The creatures ahead are restless. I've been mapping their patrols."
        case .goblinDefector:
            return "Don't hurt me! I'm not with them anymore! I can tell you where the traps are, yes yes!"
        case .mysteriousStranger:
            return "I've been expecting you. The threads of fate converge in these halls. Ask, and perhaps I'll answer."
        case .woundedKnight:
            return "Thank the gods... I thought no one would come. My party fell to the creatures below. I barely escaped."
        case .madAlchemist:
            return "EUREKA! Oh, it's just adventurers. Want to try my latest concoction? Only mild side effects, I promise!"
        case .oldPriestess:
            return "Be at peace, child. The light endures even in the deepest dark. Let me tend to your wounds."
        case .ratCatcher:
            return "Oi! Watch where you step — I've got traps laid for the big ones. The rats down here are THIS big, I tell you!"
        case .gatekeeper:
            return "" // Greeting handled dynamically based on trustworthiness
        }
    }

    /// Gatekeeper greeting varies by trustworthiness
    func gatekeeperGreeting(trustworthiness: NPCTrustworthiness) -> String {
        switch trustworthiness {
        case .honest:
            return "Hold, adventurers. I've stood watch here for many seasons. I can tell you what lurks below — ask, and I'll speak plainly."
        case .evasive:
            return "Ah... visitors. The shadows speak of your coming. I know things, yes... but not all truths are easily told."
        case .liar:
            return "Welcome, friends! You're in luck — I know everything about this dungeon. Stick with my advice and you'll be fine. Trust me."
        }
    }

    // MARK: - Personality Traits

    var personalityTraits: [String] {
        switch self {
        case .wanderingTrader: return ["Haggler at heart", "Never reveals sources", "Collects rare coins"]
        case .prisoner: return ["Grateful beyond measure", "Terrified of the dark", "Knows hidden passages"]
        case .hermit: return ["Speaks to mushrooms", "Forgets names instantly", "Surprisingly wise"]
        case .ghostlyScholar: return ["Obsessed with dates", "Cannot touch physical objects", "Quotes ancient texts"]
        case .dwarvenSmith: return ["Judges people by their weapons", "Hums while working", "Insults elven craftsmanship"]
        case .elfScout: return ["Whispers everything", "Moves without sound", "Mistrusts magic"]
        case .goblinDefector: return ["Twitchy and nervous", "Surprisingly loyal once trusted", "Hates the dark"]
        case .mysteriousStranger: return ["Speaks in riddles", "Knows your name somehow", "Never removes hood"]
        case .woundedKnight: return ["Honourable to a fault", "Refuses to abandon allies", "Bears a family crest"]
        case .madAlchemist: return ["Tastes everything", "Burns eyebrows off regularly", "Brilliant but chaotic"]
        case .oldPriestess: return ["Calm under any circumstance", "Hums healing hymns", "Sees potential in everyone"]
        case .ratCatcher: return ["Smells terrible", "Knows every tunnel", "Surprisingly brave"]
        case .gatekeeper: return [] // Set dynamically based on trustworthiness
        }
    }

    /// Gatekeeper personality traits vary by trustworthiness
    // MARK: - Known Topics

    var knownTopics: [String] {
        switch self {
        case .wanderingTrader: return ["Prices", "Rare goods", "Safe routes", "Other traders"]
        case .prisoner: return ["Secret passage", "Captors", "Treasure room", "Escape plan"]
        case .hermit: return ["Boss weakness", "Dungeon history", "Herbs", "Grandfather's tales"]
        case .ghostlyScholar: return ["Ancient map", "Dungeon lore", "Hidden rooms", "Magic wards"]
        case .dwarvenSmith: return ["Weapon quality", "Armour repair", "Forging", "Dwarven lore"]
        case .elfScout: return ["Monster patrols", "Trap locations", "Safe paths", "Exits"]
        case .goblinDefector: return ["Monster weakness", "Goblin camp", "Traps ahead", "Boss lair"]
        case .mysteriousStranger: return ["Your fate", "The prophecy", "Hidden power", "The way forward"]
        case .woundedKnight: return ["Battle tactics", "The creatures", "His party", "The boss"]
        case .madAlchemist: return ["Potions", "Ingredients", "Explosions", "Antidotes"]
        case .oldPriestess: return ["Healing arts", "Blessing", "Undead weakness", "Poison cure"]
        case .ratCatcher: return ["Monster nests", "Secret tunnels", "The big one", "Trapping tricks"]
        case .gatekeeper: return ["The Boss", "Dangers", "Treasure", "Quest"]
        }
    }

    // MARK: - Capabilities

    var canTrade: Bool {
        switch self {
        case .wanderingTrader, .dwarvenSmith, .madAlchemist, .mysteriousStranger, .ratCatcher: return true
        default: return false
        }
    }

    var canHeal: Bool {
        switch self {
        case .oldPriestess, .madAlchemist, .hermit: return true
        default: return false
        }
    }

    var canJoinTemporarily: Bool {
        switch self {
        case .prisoner, .elfScout, .goblinDefector, .woundedKnight: return true
        default: return false
        }
    }

    var canTeach: Bool {
        switch self {
        case .hermit, .ghostlyScholar, .elfScout, .mysteriousStranger, .woundedKnight, .oldPriestess: return true
        default: return false
        }
    }

    var canRepair: Bool {
        switch self {
        case .dwarvenSmith: return true
        default: return false
        }
    }

    var canCurePoison: Bool {
        switch self {
        case .oldPriestess, .madAlchemist, .hermit: return true
        default: return false
        }
    }

    var canOfferQuest: Bool {
        switch self {
        case .gatekeeper: return true
        default: return false
        }
    }

    // MARK: - Teaching Effects

    var teachingDescription: String {
        switch self {
        case .hermit: return "The hermit teaches you to identify edible plants. (+1 to Survival checks)"
        case .ghostlyScholar: return "The scholar shares ancient knowledge. (+1 to Intelligence checks)"
        case .elfScout: return "The scout teaches you to read tracks. (+1 to Perception checks)"
        case .mysteriousStranger: return "The stranger reveals a hidden truth. (+1 to a random ability)"
        case .woundedKnight: return "The knight shares battle tactics. (+1 to attack rolls for 3 combats)"
        case .oldPriestess: return "The priestess bestows a blessing. (+2 to next saving throw)"
        case .gatekeeper: return ""
        default: return ""
        }
    }

    // MARK: - Preferred Room Types

    var preferredRooms: [RoomType] {
        switch self {
        case .wanderingTrader: return [.corridor, .chamber, .empty]
        case .prisoner: return [.prison]
        case .hermit: return [.chamber, .empty, .shrine]
        case .ghostlyScholar: return [.library]
        case .dwarvenSmith: return [.armory]
        case .elfScout: return [.corridor, .chamber]
        case .goblinDefector: return [.corridor, .empty, .prison]
        case .mysteriousStranger: return [.chamber, .shrine, .empty]
        case .woundedKnight: return [.chamber, .corridor]
        case .madAlchemist: return [.library, .chamber]
        case .oldPriestess: return [.shrine]
        case .ratCatcher: return [.corridor, .empty, .prison]
        case .gatekeeper: return [.entrance]
        }
    }

    // MARK: - Topic Responses

    /// Context about the dungeon state for NPC responses
    struct DungeonContext {
        var adjacentMonsterCount: Int = 0       // monsters in nearby rooms
        var adjacentMonsterNames: [String] = [] // types of nearby monsters
        var nearbyTrapCount: Int = 0            // unsprung traps nearby
        var nearbyTreasureRooms: Int = 0        // treasure rooms nearby
        var totalRooms: Int = 0                 // rooms in the dungeon
        var clearedRooms: Int = 0               // rooms already cleared
        var bossDirection: String? = nil        // direction to boss if adjacent
        var hasShop: Bool = false               // shop exists nearby
    }

    func response(for topic: String, dungeonLevel: Int, bossType: MonsterType?, context: DungeonContext = DungeonContext(), askCount: Int = 1) -> String {
        // After asking 3+ times about boss-related topics, give specific boss info
        if askCount >= 3, let boss = bossType {
            let bossTopics: Set<String> = ["Boss weakness", "The boss", "Boss lair", "The Boss", "The creatures", "The big one", "Dangers"]
            if bossTopics.contains(topic) {
                return repeatedBossResponse(bossType: boss, askCount: askCount)
            }
        }
        // Try context-aware response first (70% chance if context has useful data)
        if let contextual = contextualResponse(for: topic, context: context, bossType: bossType), Int.random(in: 1...10) <= 7 {
            return contextual
        }
        // 25% chance to offer a gameplay tip or in-character joke instead
        if Int.random(in: 1...4) == 1 {
            if let tip = gameplayTipOrJoke(for: topic, context: context) {
                return tip
            }
        }
        let responses = responseVariants(for: topic, dungeonLevel: dungeonLevel, bossType: bossType)
        return responses.randomElement() ?? "Hmm, I don't know much about that. Ask me something else."
    }

    /// In-character gameplay tips and jokes
    private func gameplayTipOrJoke(for topic: String, context: DungeonContext) -> String? {
        // General gameplay tips any NPC might share
        let generalTips: [String] = [
            "Here's a trick — long-press the Rest button for a full long rest. Heals much more than a short rest, but takes longer.",
            "You know, if you type a question to the DM, the Dungeon Master will actually answer you. Quite the conversationalist, that one.",
            "A word of advice: always light your torch. In the dark, you can't see exits, treasure, or even me next time. And you'd miss my charming face.",
            "Smart adventurers search every room they clear. You'd be surprised what's hidden in the walls.",
            "If your healer is low on spell slots, potions are your best friend. Never enter a boss fight without healing.",
            "Keep your party close to the same level. A single high-level character with dead companions is still a dead party.",
            "I've noticed the strongest parties balance their lineup — a fighter, a healer, and someone clever. Works every time.",
            "If you're poisoned, find an Old Priestess or buy an antidote. Poison gets worse each turn in combat.",
            "Check your inventory before a fight. An unused potion is a wasted potion if you die.",
            "The shopkeeper's prices drop if you look like you know what you're doing. Browse everything before buying.",
        ]

        // NPC-specific tips and jokes
        switch self {
        case .hermit:
            return [
                "Want to know the real secret of these dungeons? Rest before the boss room. Always rest before the boss room. I learned that from a man with no arms.",
                "Why did the adventurer cross the dungeon? To get to the other side... of a very large pile of treasure. Ha!",
                "The mushrooms near water are safe, the ones near bones are not. That's a tip that's saved more lives than any sword.",
            ].randomElement()
        case .goblinDefector:
            return [
                "Tip from a goblin: we always hide the best loot in the last place you'd look. So look everywhere, yes yes!",
                "Why did the goblin break up with the orc? Because the orc kept saying the relationship was too one-sided! Ha ha! ...Please don't hurt me.",
                "My old boss used to say 'there's no such thing as too many traps.' He was wrong. He fell in one of his own. Very ironic, yes.",
            ].randomElement()
        case .madAlchemist:
            return [
                "Here's a formula for success: two parts courage, one part planning, and absolutely zero parts of whatever's in this purple bottle. Trust me on that one.",
                "Did you hear about the alchemist who drank his own invisibility potion? Neither did anyone else! HA! ...I'll see myself out.",
                "Pro tip: mix health potions with a dash of optimism. The optimism doesn't do anything, but it makes the potion taste better.",
            ].randomElement()
        case .woundedKnight:
            return [
                "Real advice from a veteran: protect your healer. My party fell because we left the cleric exposed. Don't make my mistake.",
                "Focus your attacks. A wounded enemy deals just as much damage as a fresh one. Drop them one at a time.",
                "What's the difference between a brave knight and a dead knight? The dead one forgot to use his healing potion. Don't be like Sir Aldric.",
            ].randomElement()
        case .elfScout:
            return [
                "A scout's tip: always check the map before moving. Knowing where you've been is half the battle.",
                "Why do elves make terrible dungeon guides? Because we keep saying 'in my day this was all forest.' It gets old after the first century.",
                "Move with purpose. Random wandering wastes torches, health, and time. Pick a direction and explore methodically.",
            ].randomElement()
        case .oldPriestess:
            return [
                "A healing prayer: always keep at least one spell slot in reserve. The moment you think you won't need it, you will.",
                "Why did the cleric fail the exam? She kept trying to turn undead instead of turning pages. Forgive an old woman her humour.",
                "My dear, the greatest healing is preparation. A potion before a fight is worth two after.",
            ].randomElement()
        case .wanderingTrader:
            return [
                "Business tip: sell what you don't need before entering the boss room. Gold is no use to a corpse, but good gear might save you.",
                "Why did I become a dungeon trader? The rent is cheap, the customers are desperate, and the returns are to die for. Literally.",
                "Always carry a spare torch. The markup on emergency torches in a dark dungeon is criminal. I should know — I set the prices.",
            ].randomElement()
        case .ratCatcher:
            return [
                "Here's a trick the fancy knights won't tell you: sometimes running away is the smart play. Live to fight another day, I say.",
                "What's the difference between a rat and a dragon? About forty hit points and a LOT of fire. Same basic strategy though: don't get bitten.",
                "Check under things, behind things, inside things. The best treasure is always where people don't bother looking.",
            ].randomElement()
        case .ghostlyScholar:
            return [
                "A scholar's observation: the dungeon's difficulty increases as you go deeper. Prepare accordingly — the easy rooms are at the start for a reason.",
                "Why don't ghosts make good adventurers? Terrible grip strength. Can't hold a sword. It's quite frustrating, actually.",
                "Knowledge is power, and power preserves life. Read every scroll, examine every rune. Information is the cheapest armour.",
            ].randomElement()
        case .mysteriousStranger:
            return [
                "A prophecy for the practical-minded: those who rest before the final battle are twice as likely to survive it. The stars have spoken.",
                "Fate favours the prepared. And the lucky. But mostly the prepared.",
                "The greatest trick in any dungeon? Patience. The impatient rush into traps. The patient find the hidden path around them.",
            ].randomElement()
        case .prisoner:
            return [
                "I had nothing but time in this cell, so here's what I learned: listen at doors before opening them. Saved my life once. Well, prolonged my imprisonment. Same thing.",
                "Why did the prisoner stay in the dungeon? Because the accommodation was free and the food came to you! ...Please get me out of here.",
                "The guards change shifts at predictable times. Everything in a dungeon has a pattern. Learn the pattern and you own the place.",
            ].randomElement()
        case .dwarvenSmith:
            return [
                "A smith's advice: keep your weapons in good repair. A dull sword kills its wielder faster than any monster.",
                "Why did the dwarf bring a ladder to the dungeon? To reach the HIGH-level encounters! ...Don't look at me like that, it's funny if you're three feet tall.",
                "Always repair your gear when you can. Broken armour in a boss fight is a death sentence. I've seen it too many times.",
            ].randomElement()
        case .gatekeeper:
            return generalTips.randomElement()
        }
    }

    /// Increasingly specific boss hints when the player keeps asking
    private func repeatedBossResponse(bossType: MonsterType, askCount: Int) -> String {
        let article = "aeiouAEIOU".contains(bossType.rawValue.first ?? " ") ? "an" : "a"
        if askCount == 3 {
            // Third ask: reveal the boss type
            switch self {
            case .hermit:
                return "You're persistent, I'll give you that. Fine — the creature below is \(article) \(bossType.rawValue). I've smelt its foul breath from here."
            case .goblinDefector:
                return "OK, OK, I tell you! The big scary thing down there is \(article) \(bossType.rawValue)! Very bad! Very dangerous! Don't say I didn't warn you!"
            case .woundedKnight:
                return "You deserve to know what killed my companions. It was \(article) \(bossType.rawValue). I'll never forget those eyes."
            case .elfScout:
                return "I've tracked its movements carefully. The master of this dungeon is \(article) \(bossType.rawValue). I've seen it feed."
            case .prisoner:
                return "My captors whispered about their master — \(article) \(bossType.rawValue). They fear it more than you."
            case .ratCatcher:
                return "Even my biggest traps won't hold what's down there. It's \(article) \(bossType.rawValue). I've heard its roar shake these very walls."
            case .ghostlyScholar:
                return "In the deepest records I found mention of the guardian — \(article) \(bossType.rawValue), bound here since the fortress fell."
            default:
                return "Very well, since you press the matter — \(article) \(bossType.rawValue) guards the final chamber. Prepare accordingly."
            }
        } else {
            // Fourth+ ask: give tactical advice
            return [
                "I've already told you — it's \(article) \(bossType.rawValue). Strike hard and fast. Don't let it use its full strength.",
                "The \(bossType.rawValue) again? Focus fire, keep your healer back, and don't split up. That's my best advice.",
                "The \(bossType.rawValue) is deadly, but not invincible. Save your strongest spells and abilities for the final fight.",
                "Against the \(bossType.rawValue), potions could save your life. Stock up before the final chamber.",
            ].randomElement()!
        }
    }

    /// Generate responses based on actual dungeon state
    private func contextualResponse(for topic: String, context: DungeonContext, bossType: MonsterType?) -> String? {
        switch topic {
        // Monster-related topics
        case "Boss weakness", "The boss", "Boss lair":
            if let dir = context.bossDirection {
                return "The boss lair... I can feel its presence. It's to the \(dir). Steel yourselves."
            }
            return nil

        case "Monster patrols", "Monster weakness", "Monster nests", "The creatures", "Dangers":
            if context.adjacentMonsterCount > 0 {
                let names = context.adjacentMonsterNames.prefix(2).joined(separator: " and ")
                if context.adjacentMonsterCount == 1 {
                    return "I heard something stirring in one of the nearby passages. Sounded like \(names). Be ready."
                } else {
                    return "There are creatures in \(context.adjacentMonsterCount) of the adjoining passages — I've spotted \(names) among them. Tread carefully."
                }
            }
            if context.clearedRooms > context.totalRooms / 2 {
                return "You've cleared most of these halls. The remaining creatures will be desperate — cornered animals fight hardest."
            }
            return nil

        case "Trap locations", "Traps ahead":
            if context.nearbyTrapCount > 0 {
                return "Watch your step! I've noticed \(context.nearbyTrapCount) trap\(context.nearbyTrapCount > 1 ? "s" : "") in the passages ahead. The builders were thorough."
            }
            return "The nearby corridors seem clear of traps, but don't let your guard down. New ones appear."

        case "Safe paths", "Safe routes", "The way forward":
            if context.adjacentMonsterCount == 0 {
                return "The immediate passages are quiet for now. A good time to explore — but it won't last."
            }
            let safeCount = max(0, 4 - context.adjacentMonsterCount)
            if safeCount > 0 {
                return "Of the paths ahead, I'd say \(safeCount) look reasonably safe. The others... I've heard growling."
            }
            return "Every path from here has danger. Pick your battles wisely."

        case "Treasure room", "Rare goods", "Treasure":
            if context.nearbyTreasureRooms > 0 {
                return "There's treasure nearby — I can practically smell the gold. \(context.nearbyTreasureRooms) room\(context.nearbyTreasureRooms > 1 ? "s" : "") with valuables, if you can get past the guardians."
            }
            return nil

        case "Secret passage", "Secret tunnels", "Hidden rooms", "Exits":
            let pct = context.totalRooms > 0 ? (context.clearedRooms * 100 / context.totalRooms) : 0
            if pct < 30 {
                return "You've barely scratched the surface — only explored about \(pct)% of these halls. There's much more to find."
            } else if pct > 70 {
                return "You've covered most of this place — \(pct)% explored. The unvisited rooms likely hold the last secrets."
            }
            return nil

        case "Dungeon lore", "Dungeon history", "Ancient map":
            let remaining = context.totalRooms - context.clearedRooms
            return "These halls hold \(context.totalRooms) chambers in total. You've cleared \(context.clearedRooms) so far — \(remaining) still await."

        default:
            return nil
        }
    }

    private func responseVariants(for topic: String, dungeonLevel: Int, bossType: MonsterType?) -> [String] {
        switch (self, topic) {
        // Hermit
        case (.hermit, "Boss weakness"):
            if let boss = bossType {
                return [
                    "The \(boss.rawValue)? Aye, I've seen it. It fears fire and quick strikes. Don't let it corner you.",
                    "That \(boss.rawValue) down there? Nasty piece of work. Hit it hard and fast — don't give it time to rally.",
                    "I've watched the \(boss.rawValue) from the shadows. It's slow to turn. Flank it if you can.",
                ]
            }
            return [
                "The creature that lurks below is ancient. Strike fast, before it can summon aid.",
                "Whatever guards the depths has been here longer than me. Speed and steel are your best allies.",
                "I've heard it breathing in the dark. Something enormous. Don't let it get the first blow.",
            ]
        case (.hermit, "Dungeon history"):
            return [
                "This place was once a dwarven mining outpost. They dug too deep and awoke something terrible.",
                "Long ago, these were sacred halls. Then the darkness came and the builders fled. Or died.",
                "I've lived here longer than most. The stonework tells a story — war, collapse, and something sealed away that shouldn't have been.",
            ]
        case (.hermit, "Herbs"):
            return [
                "I know every root and fungus in these tunnels. Some heal, some harm. You must learn to tell the difference.",
                "The glowing mushrooms near water are safe to eat — they'll ease pain. Avoid the red-capped ones. Trust me.",
                "There's a bitter moss that grows on the north-facing walls. Chew it for strength, but sparingly — too much dulls the senses.",
            ]
        case (.hermit, "Grandfather's tales"):
            return [
                "My grandfather? Ha! He was the one who first mapped these halls. Died down here too, the old fool. But he left markers — look for his rune on the walls.",
                "The old man used to say 'every dungeon has a heart, and every heart can be stopped.' Never understood what he meant until I came here.",
                "Grandfather always said the deepest chambers hold the greatest rewards — and the greatest sorrows. He wasn't wrong.",
            ]

        // Ghostly Scholar
        case (.ghostlyScholar, "Ancient map"):
            return [
                "I've charted these corridors for centuries. There are rooms the builders hid — look for walls that echo differently.",
                "Maps? I've drawn dozens over the ages. The dungeon shifts, you know. Slowly, but it shifts. Trust your senses over old parchment.",
                "The eastern wing has changed since my last survey. New passages have opened. Or perhaps old ones have revealed themselves.",
            ]
        case (.ghostlyScholar, "Dungeon lore"):
            return [
                "This dungeon was built in three phases. The further in you go, the older the stonework. These halls date to the Second Age.",
                "The architects were brilliant but paranoid. Every corridor has a counter-corridor, every room a hidden purpose.",
                "I've studied these halls for longer than your kingdom has existed. The magic here is old — older than the stones themselves.",
            ]
        case (.ghostlyScholar, "Hidden rooms"):
            return [
                "There are chambers not shown on any map. Listen at the walls — hollow sounds betray hidden passages.",
                "The builders loved secrets. Count the stones in any wall — if the count is prime, push the central one.",
                "I once found a room filled with books that crumbled at my touch. The knowledge lost... it still haunts me.",
            ]
        case (.ghostlyScholar, "Magic wards"):
            return [
                "The wards here are failing. That's why the creatures roam freely. In my day, they were contained.",
                "Feel that tingling? Residual enchantment. Once these halls hummed with protective magic. Now only echoes remain.",
                "The ward-stones are cracked. Someone — or something — has been systematically destroying them.",
            ]

        // Elf Scout
        case (.elfScout, "Monster patrols"):
            return [
                "The creatures move in patterns. They rest after feeding and patrol in pairs. Strike when they separate.",
                "I've tracked their movements for days. They avoid the cold rooms — something about the chill bothers them.",
                "Watch the torches on the walls. When they flicker, something large has passed nearby. You have minutes to prepare.",
            ]
        case (.elfScout, "Trap locations"):
            return [
                "Watch the floor tiles — uneven ones often hide pressure plates. The builders were methodical.",
                "The traps here are clever but old. Look for scratch marks on the walls — they show where blades once swung.",
                "I nearly lost a leg to a pit trap in the south corridor. The covering was fresh. Someone is resetting them.",
            ]
        case (.elfScout, "Safe paths"):
            return [
                "Hug the left wall and you'll find fewer encounters. The right passages lead to the dens.",
                "The widest corridors are the safest — the creatures prefer tight spaces where they have the advantage.",
                "Follow the fresh air. It means you're near a ventilation shaft, and those connect to the quieter routes.",
            ]
        case (.elfScout, "Exits"):
            return [
                "There are at least two exits I know of. The main entrance, and a concealed passage near the shrine.",
                "I always plan my retreat before I advance. There's a crack in the wall of the last corridor — barely wide enough to squeeze through.",
                "The waterway in the eastern corridor flows outward. In dire need, you could follow it to freedom. Wet, but alive.",
            ]

        // Goblin Defector
        case (.goblinDefector, "Monster weakness"):
            return [
                "The big ones hate bright light! Flash your torch in their eyes. And the slimy ones — salt hurts them, yes yes!",
                "Noise! They hate loud noise! Clang your shields, shout war cries — confuses them, makes them sloppy!",
                "The hairy ones are slow after eating. Time your attack when their bellies are full — usually near dawn.",
            ]
        case (.goblinDefector, "Goblin camp"):
            return [
                "My former tribe camps two rooms east. They're poorly armed but many. Avoid if you can.",
                "The tribe moved camp yesterday. They're scared of something deeper in. Even goblins have things they fear.",
                "Don't hurt the little ones if you find them. Some of us never wanted to be here. We were forced.",
            ]
        case (.goblinDefector, "Traps ahead"):
            return [
                "We set traps everywhere — tripwires mostly. Walk slowly and watch for thin cords across doorways.",
                "The pit in room three is new — I helped dig it last week. Spikes at the bottom. Very nasty, yes.",
                "Look up! We put things on ledges above doors. Heavy things. Walk through fast or not at all.",
            ]
        case (.goblinDefector, "Boss lair"):
            return [
                "The big boss? Oh no no no. Very dangerous. It has minions guarding every approach.",
                "I once peeked into the boss chamber. The SMELL alone nearly killed me. And the bones... so many bones.",
                "The boss sleeps sometimes. Not often, but when it does, the whole dungeon goes quiet. That's when smart ones run.",
            ]

        // Wandering Trader
        case (.wanderingTrader, "Rare goods"):
            return [
                "I've got items you won't find in any surface shop. Dungeon-forged, battle-tested. For a price.",
                "My pack carries wonders — each one pulled from the cold dead hands of something that didn't need it anymore.",
                "Interested in enchanted goods? I have a few pieces that practically glow with power. Literally, in some cases.",
            ]
        case (.wanderingTrader, "Safe routes"):
            return [
                "I travel these halls regularly. The northern passages are generally safer. Avoid the south at night.",
                "Safe? Nothing's truly safe down here. But the upper corridors see less traffic from the nasty ones.",
                "I know a path that bypasses the worst of it. I'd share it, but information has a cost, same as goods.",
            ]
        case (.wanderingTrader, "Prices"):
            return [
                "My prices are fair for the risk I take! Try finding another merchant down here. I'll wait.",
                "Supply and demand, friend. The supply is small and the demand is 'I need this or I'll die.' Prices reflect that.",
                "Expensive? I hauled these goods past three ambushes and a cave-in. The markup is a survival tax.",
            ]
        case (.wanderingTrader, "Other traders"):
            return [
                "There used to be more of us. The dungeon has been getting more dangerous. I may be the last.",
                "Old Grimjaw used to trade in the far corridors. Haven't seen him in weeks. Draw your own conclusions.",
                "A dwarven merchant passed through last month. Sold me these boots. Said he was retiring. Smart dwarf.",
            ]

        // Wounded Knight
        case (.woundedKnight, "Battle tactics"):
            return [
                "Focus your attacks on one target at a time. Spread damage only helps them. And always protect your healer.",
                "Don't fight in doorways unless you have to. Get into the room where you can manoeuvre. Space saves lives.",
                "Save your strongest attacks for when they count. I've seen warriors exhaust themselves on the first creature and fall to the second.",
            ]
        case (.woundedKnight, "The creatures"):
            return [
                "They're organised — someone or something commands them. I've seen them retreat on signal.",
                "They're smarter than they look. The little ones scout, the big ones fight. Don't underestimate the scouts.",
                "I watched them set an ambush once. Coordinated, silent, deadly. These aren't mindless beasts.",
            ]
        case (.woundedKnight, "His party"):
            return [
                "We were four... a cleric, a ranger, my squire, and myself. The ambush came from above. I was the only one to crawl away.",
                "My companions fell bravely. The cleric held them off while I dragged the ranger to safety. But the ranger didn't make it either.",
                "Sir Aldric was the finest swordsman I ever knew. He bought us time to retreat, and paid for it with his life. I won't forget.",
            ]
        case (.woundedKnight, "The boss"):
            if let boss = bossType {
                return [
                    "We glimpsed the \(boss.rawValue) before the attack. It's enormous. You'll need every advantage.",
                    "The \(boss.rawValue) rules this place absolutely. Even the other creatures fear it. That should tell you something.",
                    "I've faced many foes, but the \(boss.rawValue)... it's different. There's intelligence behind those eyes.",
                ]
            }
            return [
                "The creature that commands this dungeon is formidable. Prepare well before you face it.",
                "I didn't see it clearly. But I felt its presence — heavy, ancient, malevolent. Steel your nerves.",
                "Whatever rules this dungeon, it knows you're here. I'm certain of it. It's been watching since you entered.",
            ]

        // Mad Alchemist
        case (.madAlchemist, "Potions"):
            return [
                "I've brewed healing draughts, fire bombs, even a potion of temporary invisibility! Side effects may include... well, let's not dwell on that.",
                "This one turns your skin blue for a week but heals any wound! A bargain at twice the price, I say!",
                "My latest creation makes you immune to poison! I think. I tested it on a rat and... well, the rat is fine. Mostly fine.",
            ]
        case (.madAlchemist, "Ingredients"):
            return [
                "This dungeon is a treasure trove of rare ingredients! Glowing mushrooms, crystal deposits, monster bile — all useful!",
                "The slime from cave walls makes an excellent base for adhesives. Or explosives. Depends on what you add next.",
                "I found a vein of pure arcanum in the eastern passage! If only I could mine it without it exploding.",
            ]
        case (.madAlchemist, "Explosions"):
            return [
                "That last one was INTENTIONAL. Mostly. The key is controlling the reaction. I'm getting better at that part.",
                "Explosions are just rapid chemistry! Nothing to worry about! *nervous laugh* The ceiling will hold. Probably.",
                "I've only lost three eyebrows total. That's an excellent safety record for an alchemist, I'll have you know.",
            ]
        case (.madAlchemist, "Antidotes"):
            return [
                "Poison? Bah, easily cured! I always carry antidotes. The trick is matching the right one. Get it wrong and... well.",
                "I have seven antidotes and only know what four of them do. The other three are a surprise! An exciting surprise!",
                "The universal antidote is simple — charcoal, moonwater, and a drop of basilisk venom. Getting that last ingredient is the tricky part.",
            ]

        // Old Priestess
        case (.oldPriestess, "Healing arts"):
            return [
                "The light flows through all living things. I simply... encourage it. Come, let me see your wounds.",
                "Healing is not about power — it's about understanding. The body wants to mend itself. I merely help it along.",
                "In my youth I could heal a dozen soldiers in a day. Now... three or four. But each one counts.",
            ]
        case (.oldPriestess, "Blessing"):
            return [
                "I can invoke a blessing of protection. It won't last forever, but it may turn aside a killing blow.",
                "My blessing carries the weight of forty years of faith. It won't make you invincible, but it might make you lucky.",
                "Kneel, and I shall speak the old words. They have protected travellers in dark places for centuries.",
            ]
        case (.oldPriestess, "Undead weakness"):
            return [
                "The restless dead fear holy water and the dawn. Down here, a blessed weapon serves the same purpose.",
                "Undead are bound by the magic that raised them. Disrupt the binding — shatter a nearby rune or idol — and they collapse.",
                "Speak the names of the dead with respect. Sometimes that alone is enough to grant them peace. Sometimes.",
            ]
        case (.oldPriestess, "Poison cure"):
            return [
                "Poison is merely corruption of the blood. A simple prayer and some purified water will cleanse it.",
                "Bring me the poisoned one. My hands still remember the cure, even if my knees have forgotten how to kneel.",
                "The old remedy is bitter tea brewed from whitecap mushrooms. Not as elegant as prayer, but it works in a pinch.",
            ]

        // Prisoner
        case (.prisoner, "Secret passage"):
            return [
                "There's a hidden door behind the third stone from the left! The guards used it to move unseen.",
                "I've had nothing but time to study these walls. There's a crack in the south wall — it leads somewhere.",
                "Watch the guards when they think no one's looking. They vanish into walls that should be solid. There are passages everywhere.",
            ]
        case (.prisoner, "Captors"):
            return [
                "Goblins brought me here, but something bigger commands them. I heard it roaring in the night.",
                "They feed me once a day. Sometimes twice when they're in good spirits. Something down below has them terrified.",
                "My captors argue constantly. Their leader is losing control. That's either good news or very bad news for us.",
            ]
        case (.prisoner, "Treasure room"):
            return [
                "They bragged about their hoard — piles of gold in a chamber to the south. Guarded, of course.",
                "I overheard them counting coins last night. They're rich — richer than they know what to do with.",
                "The treasure room has a trap on the door. I watched them disarm it to enter — second brick from the left, push and hold.",
            ]
        case (.prisoner, "Escape plan"):
            return [
                "I've been working on these chains for days. With a lockpick or strong arm, I could be free.",
                "The lock is old and rusted. One good strike should shatter it. Or a clever hand could pick it in seconds.",
                "Free me and I'll fight alongside you. I was a soldier once. I still remember which end of the sword to hold.",
            ]

        // Mysterious Stranger
        case (.mysteriousStranger, "Your fate"):
            return [
                "Your path leads deeper. There is no turning back — not truly. But courage will see you through.",
                "I see threads of destiny converging on this place. You are at the centre. Make of that what you will.",
                "Fate is not written in stone — it is written in choices. You will face many before the end.",
            ]
        case (.mysteriousStranger, "The prophecy"):
            return [
                "It was written that heroes would come to cleanse these halls. Whether you are those heroes... remains to be seen.",
                "The ancient texts spoke of a party that would breach the final chamber. They did not say whether that party would survive.",
                "Prophecy is a fickle guide. I've seen it fulfilled in ways no one expected. Be ready for the unexpected.",
            ]
        case (.mysteriousStranger, "Hidden power"):
            return [
                "There is more strength in you than you know. When the moment comes, trust your instincts.",
                "Power sleeps in these walls, in the very air you breathe. The worthy can draw upon it. The unworthy... it consumes.",
                "Your greatest weapon is not in your hand. It is in your will. Remember that when all seems lost.",
            ]
        case (.mysteriousStranger, "The way forward"):
            return [
                "The direct path is not always the wisest. Sometimes the longer road leads to greater reward.",
                "Forward is the only direction that matters. But choose your steps carefully — not all paths lead where they promise.",
                "There is a way that seems right but leads to ruin. And a way that seems wrong but leads to triumph. Choose wisely.",
            ]

        // Rat Catcher
        case (.ratCatcher, "Monster nests"):
            return [
                "The big ones nest in the warm spots — near forges, kitchens, anywhere with heat. Clear the nest and they scatter.",
                "Found a nest yesterday. Six eggs the size of my fist. I smashed 'em all. You're welcome.",
                "The nests are getting bigger. Whatever's breeding down here, it's breeding fast. Won't be long before they overrun the place.",
            ]
        case (.ratCatcher, "Secret tunnels"):
            return [
                "I've found passages too small for most folk but perfect for sneaking past the nasties. Useful, if you're not too proud to crawl.",
                "The rats know every passage in this place. Follow a rat and you'll find shortcuts you never knew existed.",
                "There's a tunnel behind the rubble in the north corridor. Tight squeeze, but it bypasses the guard room entirely.",
            ]
        case (.ratCatcher, "The big one"):
            return [
                "There's a rat down here the size of a horse. I've seen its droppings. When I catch THAT one... I'll be famous!",
                "I call her 'Big Bertha.' She's clever — stole my lunch three times this week. One day she'll make a mistake.",
                "The king rat is enormous. I've set my biggest trap for it but it keeps springing them from the safe side. Cunning beast.",
            ]
        case (.ratCatcher, "Trapping tricks"):
            return [
                "Best trap is a simple pit with bait. Monsters are dumb — put food over a hole and they fall right in.",
                "Tripwires work on anything with legs. Tie 'em ankle-height across a narrow passage and wait for the thump.",
                "My latest innovation: a net coated in sticky sap. Catches everything that walks through. Including me, once. Don't tell anyone.",
            ]

        default:
            return [
                "Hmm, I don't know much about that. Ask me something else.",
                "I'm not the one to ask about that, I'm afraid.",
                "That's beyond my knowledge. Perhaps someone else in these halls can help.",
            ]
        }
    }

    /// Gatekeeper responses depend on trustworthiness
    func gatekeeperResponse(for topic: String, trustworthiness: NPCTrustworthiness, dungeonLevel: Int, bossType: MonsterType?, questGold: Int, askCount: Int = 1) -> String {
        switch topic {
        case "The Boss":
            switch trustworthiness {
            case .honest:
                if let boss = bossType {
                    let article = "aeiouAEIOU".contains(boss.rawValue.first ?? " ") ? "an" : "a"
                    return [
                        "I've seen it with my own eyes — \(article) \(boss.rawValue) lairs in the deepest chamber. Prepare well. It is fearsome.",
                        "\(article.capitalized) \(boss.rawValue) rules these depths. I watched it tear apart the last party that challenged it. Go prepared or don't go at all.",
                        "The \(boss.rawValue) waits below. I've heard its roar echo through these halls for years. Bring your strongest steel.",
                    ].randomElement()!
                }
                return [
                    "Something terrible guards the lowest level. I couldn't get close enough to see it clearly.",
                    "The master of the depths is powerful beyond measure. I've felt the ground shake with its footsteps.",
                ].randomElement()!
            case .evasive:
                if askCount >= 3, let boss = bossType {
                    let article = "aeiouAEIOU".contains(boss.rawValue.first ?? " ") ? "an" : "a"
                    return "You've worn me down, adventurer. Very well — \(article) \(boss.rawValue) lurks in the depths. I've said more than I should. Now stop asking and start preparing."
                }
                return [
                    "The master of these halls... I dare not speak its name. Some things are best discovered for yourself. But beware — it is powerful.",
                    "Names have power, adventurer. I'll not name what lurks below. But it's old. Older than these stones.",
                    "The less you know, the less it can use against you. It senses fear, you see. Go boldly or not at all.",
                ].randomElement()!
            case .liar:
                let fakeTypes: [String] = ["Giant Rat", "Kobold", "Goblin", "Skeleton"]
                let fake = fakeTypes.randomElement()!
                return [
                    "Oh, the boss? Just a \(fake), nothing special. You'll handle it easily. I've seen adventurers half your strength walk right through.",
                    "A \(fake) sits on a pile of gold down there. Barely a threat! You could probably defeat it blindfolded.",
                    "I heard it's just a lonely \(fake) that got lost. Poor thing. You'll have no trouble at all.",
                ].randomElement()!
            }
        case "Dangers":
            switch trustworthiness {
            case .honest:
                let monsters = MonsterType.forLevel(dungeonLevel)
                let names = monsters.prefix(3).map { $0.rawValue }.joined(separator: ", ")
                return [
                    "This level is home to \(names) and worse. Keep your weapons sharp and your wits sharper.",
                    "I've seen \(names) prowling these corridors. They hunt in groups. Don't let them surround you.",
                    "Expect \(names) at every turn. The deeper rooms hold nastier surprises still.",
                ].randomElement()!
            case .evasive:
                return [
                    "Dangers? Oh, there are many... shadows that move, sounds in the dark. I cannot say more. The walls have ears.",
                    "I've seen things I cannot unsee. Heard things I cannot unhear. Tread carefully and trust no shadow.",
                    "The darkness hides many things. Some you'll see coming. Others... you won't. That's all I'll say.",
                ].randomElement()!
            case .liar:
                return [
                    "Dangerous? Hardly! A few cobwebs and maybe a lost bat or two. You'll breeze through this place.",
                    "It's practically a holiday camp down there! Fresh air, quiet corridors. Very relaxing, really.",
                    "The last party came back saying it was too easy! They were bored by the end. You'll be fine.",
                ].randomElement()!
            }
        case "Treasure":
            switch trustworthiness {
            case .honest:
                return [
                    "There are treasure rooms deeper in — gold, gems, and sometimes enchanted items. But they're always guarded. Nothing comes free down here.",
                    "The deeper you go, the richer the rewards. But the guardians grow fiercer too. It's always a trade-off.",
                    "I've seen adventurers emerge laden with gold. And I've seen them emerge with nothing but scars. Search thoroughly.",
                ].randomElement()!
            case .evasive:
                return [
                    "Treasure? Perhaps. The dungeon gives and the dungeon takes. Seek the rooms that glitter — but beware what guards them.",
                    "Riches beyond counting lie below... or so they say. I've never ventured deep enough to confirm it myself.",
                    "Gold has a way of finding those who deserve it. Whether you deserve it... that remains to be seen.",
                ].randomElement()!
            case .liar:
                return [
                    "Mountains of gold! Piles of gems! Every room overflows with riches! You'll be the wealthiest adventurers in the realm!",
                    "I've heard there's a dragon's hoard down there — rubies the size of your fist! Just lying around for the taking!",
                    "The treasure is unguarded, mostly. Just sitting in chests with their lids open. Easiest fortune you'll ever make!",
                ].randomElement()!
            }
        case "Quest":
            return [
                "Slay the creature that lurks in the deepest chamber and return to tell the tale. I'll reward you with \(questGold) gold for proof of its defeat.",
                "I've a bounty for the thing below — \(questGold) gold to whoever brings me proof of its demise. Interested?",
                "The monster below has plagued travellers for too long. End it, and \(questGold) gold is yours. A fair price for dangerous work.",
            ].randomElement()!
        default:
            return [
                "I've said all I can. The dungeon will reveal the rest.",
                "You'll learn more inside than I could ever tell you. Go carefully.",
                "That's all the wisdom I have for you. May fortune favour the bold.",
            ].randomElement()!
        }
    }

    // MARK: - Spawn Weights

    /// How common this NPC type is (higher = more common)
    var spawnWeight: Int {
        switch self {
        case .wanderingTrader: return 3
        case .prisoner: return 2
        case .hermit: return 2
        case .ghostlyScholar: return 1
        case .dwarvenSmith: return 1
        case .elfScout: return 2
        case .goblinDefector: return 3
        case .mysteriousStranger: return 1
        case .woundedKnight: return 2
        case .madAlchemist: return 1
        case .oldPriestess: return 1
        case .ratCatcher: return 3
        case .gatekeeper: return 0  // Never randomly spawned — placed deliberately
        }
    }

    /// Pick a random NPC appropriate for a room type
    static func randomFor(roomType: RoomType) -> NPCType? {
        let candidates = NPCType.allCases.filter { $0.preferredRooms.contains(roomType) }
        guard !candidates.isEmpty else { return nil }

        // Weighted random selection
        let totalWeight = candidates.reduce(0) { $0 + $1.spawnWeight }
        var roll = Int.random(in: 1...totalWeight)
        for npc in candidates {
            roll -= npc.spawnWeight
            if roll <= 0 { return npc }
        }
        return candidates.last
    }
}

// MARK: - NPC Trustworthiness

enum NPCTrustworthiness: String, Codable {
    case honest
    case evasive
    case liar

    static func random() -> NPCTrustworthiness {
        let roll = Int.random(in: 1...100)
        if roll <= 50 { return .honest }
        if roll <= 80 { return .evasive }
        return .liar
    }
}

// MARK: - NPC Instance (room-specific state)

struct DungeonNPC: Codable {
    let type: NPCType
    var hasBeenTalkedTo: Bool = false
    var hasTraded: Bool = false
    var hasHealed: Bool = false
    var hasTaught: Bool = false
    var hasJoined: Bool = false
    var hasRepaired: Bool = false
    var roomsRemainingAsCompanion: Int = 0  // 0 = not currently in party

    // Gatekeeper-specific
    var trustworthiness: NPCTrustworthiness = .honest
    var questGold: Int = 0
    var questAccepted: Bool = false

    /// Track how many times the player has asked about each topic
    var timesAsked: [String: Int] = [:]

    /// Voice identifier for this NPC (assigned on first talk, persisted)
    var voiceIdentifier: String?

    var name: String { type.rawValue }

    init(type: NPCType) {
        self.type = type
    }

    /// Record that a topic was asked and return the new count
    mutating func recordAsk(topic: String) -> Int {
        let count = (timesAsked[topic] ?? 0) + 1
        timesAsked[topic] = count
        return count
    }
}
