//
//  FAQData.swift
//  DnDTextRPG
//
//  Frequently asked questions organised by topic.
//  Used by: Help screens, Hint buttons, DM chat responses.
//

import Foundation

struct FAQEntry {
    let question: String
    let answer: String
    /// Keywords the DM can match against player messages
    let keywords: [String]
}

struct FAQCategory {
    let title: String
    /// Game contexts where these tips are most relevant
    let contexts: Set<String>  // e.g. "combat", "exploration", "inventory", "settings", "rest", "shop"
    let entries: [FAQEntry]
}

struct FAQData {

    // MARK: - All Categories (used by hint system and DM chat)

    static let categories: [FAQCategory] = [
        exploration,
        torch,
        combat,
        inventory,
        character,
        shops,
        saving,
        multiplayer,
        dm,
        accessibility,
        shortcuts,
    ]

    /// Categories shown in the FAQ menu — excludes topics already covered
    /// by dedicated How to Play pages (Exploration, Combat, Character,
    /// Multiplayer, DM, Tips & Tricks).
    static let faqMenuCategories: [FAQCategory] = [
        torch,
        inventory,
        shops,
        saving,
        accessibility,
        shortcuts,
    ]

    /// Flat list of every FAQ entry across all categories
    static let allEntries: [FAQEntry] = categories.flatMap { $0.entries }

    // MARK: - Exploration

    static let exploration = FAQCategory(title: "Exploration", contexts: ["exploration", "rest"], entries: [
        FAQEntry(
            question: "How do I move around the dungeon?",
            answer: "Tap a direction button (N/S/E/W) to move between rooms. On Mac use arrow keys or WASD. Available exits light up green; greyed-out directions have no passage.",
            keywords: ["move", "walk", "direction", "navigate", "go north", "go south", "go east", "go west", "how to move"]
        ),
        FAQEntry(
            question: "How do I search a room?",
            answer: "Tap 'Search Room' from the exploration menu. You need a lit torch to search properly. Rooms can be searched multiple times — you might find hidden treasure on a second or third look!",
            keywords: ["search", "find items", "hidden", "treasure", "loot", "search room"]
        ),
        FAQEntry(
            question: "Where do I find shops?",
            answer: "Shops appear as special rooms in the dungeon marked 'Shop' or 'Merchant'. You'll find them as you explore. The Merchant sells weapons, armour, potions, and torches. Shops are more common on easier difficulty levels.",
            keywords: ["shop", "merchant", "store", "buy", "where is the shop", "find shop", "purchase"]
        ),
        FAQEntry(
            question: "How do I rest and heal?",
            answer: "Tap 'Rest' from the exploration menu. A short rest restores some HP. Long-press the Rest button for a long rest, which restores more HP and spell slots but advances time significantly. Rest in cleared rooms to avoid ambushes!",
            keywords: ["rest", "heal", "short rest", "long rest", "recover", "hp", "health"]
        ),
        FAQEntry(
            question: "What does the map show?",
            answer: "The map shows rooms you've visited. Your current position is marked with @. Rooms are colour-coded: green for explored, yellow for shops, red for boss rooms. You need a lit torch to see the map clearly.",
            keywords: ["map", "where am i", "minimap", "layout", "dungeon map"]
        ),
        FAQEntry(
            question: "How do I find the boss?",
            answer: "The boss lurks in the deepest room of the dungeon. Explore thoroughly — the boss room is usually far from the entrance. You'll get warnings as you approach. Save before entering!",
            keywords: ["boss", "final boss", "find boss", "where is boss", "end boss"]
        ),
        FAQEntry(
            question: "What happens when I die?",
            answer: "If all party members fall in combat, the adventure ends in defeat. Your run is recorded in the Hall of Fame. You can start a new adventure or load a saved game. Save often to avoid losing progress!",
            keywords: ["die", "death", "game over", "defeat", "tpk", "party wipe", "what happens when"]
        ),
        FAQEntry(
            question: "Where is Party Status?",
            answer: "Tap 'Party Status' from the exploration menu. It shows your full party with HP bars, stats, equipment, gold, XP, and the dungeon map. From here you can view the Adventure Log, invite remote players, or return to the main menu.",
            keywords: ["party status", "party screen", "view party", "check party", "character stats", "hp bar"]
        ),
        FAQEntry(
            question: "How do I see my character's stats?",
            answer: "Open Party Status from the exploration menu. Each character shows their full stat sheet: race, class, level, ability scores, HP bar, gold, and XP. You can also see equipped weapons and armour.",
            keywords: ["stats", "character sheet", "ability scores", "my character", "view stats"]
        ),
        FAQEntry(
            question: "Where is the Adventure Log?",
            answer: "Open Party Status from the exploration menu, then tap 'Adventure Log'. It shows a record of everything that's happened in your adventure — rooms explored, battles fought, items found.",
            keywords: ["adventure log", "history", "log", "what happened"]
        ),
        FAQEntry(
            question: "How do I talk to NPCs?",
            answer: "When you enter a room with an NPC, tap 'Talk' to interact. NPCs offer services like healing, item repair, trading, and dungeon lore. The Gatekeeper at the entrance offers a gold reward for clearing the dungeon.",
            keywords: ["npc", "talk", "interact", "gatekeeper", "trader", "hermit", "priestess", "smith"]
        ),
    ])

    // MARK: - Torch & Light

    static let torch = FAQCategory(title: "Torch & Light", contexts: ["exploration", "inventory", "combat"], entries: [
        FAQEntry(
            question: "How do I light my torch?",
            answer: "Tap 'Light Torch' from the exploration menu, or go to Rest and tap 'Light Torch' there. You need a torch item in your inventory. Each torch burns for about 12 hours of game time.",
            keywords: ["light torch", "torch on", "turn on torch", "ignite", "how to light"]
        ),
        FAQEntry(
            question: "How do I douse (put out) my torch?",
            answer: "Tap 'Douse Torch' from the Rest menu. Dousing your torch lets you sneak past monsters — there's a 30% chance enemies won't notice you in the dark.",
            keywords: ["douse", "put out", "extinguish", "torch off", "turn off torch"]
        ),
        FAQEntry(
            question: "Why does my torch keep going out?",
            answer: "Torches can be blown out by gusts of wind or dropped when stumbling in the dark — these are random dungeon events. When your torch goes out, check your packs for a spare. You can also buy torches from the Merchant.",
            keywords: ["torch going out", "torch blew out", "wind", "torch keeps", "why torch"]
        ),
        FAQEntry(
            question: "What happens without a torch?",
            answer: "In darkness you can't see room details, search for treasure, or read the map. However, you can sneak past monsters more easily. Combat still works in the dark, but you miss some contextual information.",
            keywords: ["no torch", "dark", "darkness", "without light", "can't see"]
        ),
        FAQEntry(
            question: "Where can I get more torches?",
            answer: "Buy torches from the Merchant in shop rooms (only 1gp each). You start with some in your inventory. Check all party members' packs — someone might have a spare!",
            keywords: ["get torch", "buy torch", "more torches", "out of torches", "need torch"]
        ),
    ])

    // MARK: - Combat

    static let combat = FAQCategory(title: "Combat", contexts: ["combat"], entries: [
        FAQEntry(
            question: "How does combat work?",
            answer: "Combat is turn-based. Each round, characters act in initiative order (d20 + DEX modifier). On your turn, choose Attack, Dodge, use a Spell, drink a Potion, or try to flee. Attacks roll d20 + modifier vs the enemy's AC.",
            keywords: ["how combat", "how fight", "combat work", "battle", "fighting"]
        ),
        FAQEntry(
            question: "What is AC (Armour Class)?",
            answer: "AC is how hard you are to hit. Higher is better. Your AC comes from armour, shields, and DEX modifier. An attacker must roll equal to or above your AC to land a hit.",
            keywords: ["ac", "armour class", "armor class", "hard to hit", "defence"]
        ),
        FAQEntry(
            question: "What does Dodge do?",
            answer: "Dodge makes you harder to hit for one round. All attackers have disadvantage against you (they roll twice and take the lower result). Use Dodge when you're low on HP and waiting for healing.",
            keywords: ["dodge", "what does dodge", "dodge action", "dodging"]
        ),
        FAQEntry(
            question: "How does Play Dead work?",
            answer: "Play Dead lets you try to escape a fight by pretending to fall. If successful, you withdraw from combat. It's useful when a fight is going badly, but it doesn't always work — tougher enemies are harder to fool.",
            keywords: ["play dead", "feign death", "escape combat", "run away", "flee"]
        ),
        FAQEntry(
            question: "What are critical hits?",
            answer: "A natural 20 on the attack roll is a critical hit — you roll double damage dice! A natural 1 is a critical miss — the attack automatically fails regardless of modifiers.",
            keywords: ["critical", "crit", "natural 20", "double damage", "critical hit", "nat 20"]
        ),
        FAQEntry(
            question: "I'm poisoned! What should I do?",
            answer: "Poison gives disadvantage on attacks and deals damage each turn. Cure it with a Potion of Healing, a Cleric's healing spell, or by resting (short or long rest). Poisoned characters show ☠ in the exploration HUD. Avoid melee with Giant Spiders and Stirges — use ranged attacks instead.",
            keywords: ["poison", "poisoned", "cure poison", "antidote", "disadvantage"]
        ),
        FAQEntry(
            question: "How do spells work?",
            answer: "Wizards and Clerics have spell slots. Each spell costs one slot. Slots recharge on a long rest. Wizards deal damage with attack spells; Clerics can heal the party. Choose spells wisely — running out of slots means relying on cantrips or melee.",
            keywords: ["spell", "magic", "cast", "spell slot", "wizard spell", "cleric spell"]
        ),
        FAQEntry(
            question: "How do I sneak past monsters?",
            answer: "Douse your torch before entering a room with monsters. In the dark, there's a 30% chance enemies won't notice you, letting you pass without combat. Rogues have better sneak chances.",
            keywords: ["sneak", "stealth", "avoid combat", "skip fight", "sneak past"]
        ),
    ])

    // MARK: - Inventory & Equipment

    static let inventory = FAQCategory(title: "Inventory & Equipment", contexts: ["inventory", "shop", "exploration"], entries: [
        FAQEntry(
            question: "How do I use a potion?",
            answer: "Open Inventory, then Open Pack, then Use Item. Select the potion to drink it. You can also use potions during combat on your turn. Potions of Healing restore 2d4+2 HP; Greater Healing restores 4d4+4 HP.",
            keywords: ["use potion", "drink potion", "healing potion", "how to heal", "health potion"]
        ),
        FAQEntry(
            question: "How do I equip a weapon or armour?",
            answer: "Open Inventory, then Equipment. Choose the slot (Weapon, Armour, or Shield) and select the item to equip. Your old item goes back to your pack. Two-handed weapons prevent using a shield.",
            keywords: ["equip", "wear", "armour", "weapon", "shield", "put on", "wield"]
        ),
        FAQEntry(
            question: "What's the difference between Equipment and Pack?",
            answer: "Equipment is what you're wearing or wielding — your weapon, armour, and shield. Your Pack (backpack) holds everything else: potions, torches, rope, spare weapons. Open Pack to use, drop, or give items.",
            keywords: ["equipment vs pack", "backpack", "inventory", "bag", "pack"]
        ),
        FAQEntry(
            question: "How do I give items to another party member?",
            answer: "Open Inventory, then Open Pack, then Give Item. Choose the item and the party member to give it to. This is useful for passing potions to a wounded fighter or torches to the party leader.",
            keywords: ["give item", "trade", "pass item", "share", "transfer"]
        ),
        FAQEntry(
            question: "My inventory is full! What do I do?",
            answer: "Each character can carry up to 12 items. Drop items you don't need (Open Pack → Drop Item) or give items to party members with space. You can also sell unwanted gear at the Merchant.",
            keywords: ["inventory full", "too many items", "can't carry", "no space", "encumbered", "drop"]
        ),
    ])

    // MARK: - Characters & Party

    static let character = FAQCategory(title: "Characters & Party", contexts: ["exploration", "combat", "rest"], entries: [
        FAQEntry(
            question: "Which class should I pick?",
            answer: "Fighter: tanky melee. Wizard: powerful spells but fragile. Rogue: sneaky with high damage. Cleric: healer with decent combat. Ranger: ranged attacks. Barbarian: high damage, low defence. A balanced party of 3-4 is recommended.",
            keywords: ["class", "which class", "best class", "fighter", "wizard", "rogue", "cleric", "ranger", "barbarian"]
        ),
        FAQEntry(
            question: "What do the ability scores mean?",
            answer: "STR: melee damage. DEX: ranged attacks, AC, initiative. CON: hit points. INT: wizard spells. WIS: cleric spells, perception. CHA: social skills. Each class has a primary ability that should be your highest score.",
            keywords: ["ability", "stats", "strength", "dexterity", "constitution", "intelligence", "wisdom", "charisma", "str", "dex", "con", "int", "wis", "cha"]
        ),
        FAQEntry(
            question: "How do I level up?",
            answer: "Characters gain XP from defeating monsters and completing objectives. When you earn enough XP, you level up automatically, gaining more HP, better attack bonuses, and new abilities. Check party status to see your current XP and level.",
            keywords: ["level up", "xp", "experience", "gain level", "levelling"]
        ),
        FAQEntry(
            question: "How many party members should I have?",
            answer: "You can have 1-4 adventurers. More members means more actions in combat but XP is shared. Solo runs are harder but faster to level up. 3-4 members is recommended for beginners; include a Cleric for healing.",
            keywords: ["party size", "how many", "solo", "members", "adventurers"]
        ),
    ])

    // MARK: - Shops & Gold

    static let shops = FAQCategory(title: "Shops & Gold", contexts: ["shop", "exploration"], entries: [
        FAQEntry(
            question: "How do I buy things?",
            answer: "When you enter a shop room, tap 'Visit Merchant' from the exploration menu. Browse the stock and buy items with gold. Prices are fixed. Higher-level shops stock better gear.",
            keywords: ["buy", "purchase", "merchant", "shopping", "how to buy"]
        ),
        FAQEntry(
            question: "How do I sell items?",
            answer: "Visit the Merchant in a shop room and choose 'Sell'. You can sell any item from your pack for half its value. This is a good way to clear inventory space and earn gold for better gear.",
            keywords: ["sell", "sell items", "get gold", "sell gear"]
        ),
        FAQEntry(
            question: "Where do I get gold?",
            answer: "Gold comes from searching rooms (treasure chests and hidden stashes), defeating monsters (loot drops), selling items at the Merchant, and occasionally from the DM as quest rewards.",
            keywords: ["gold", "money", "coins", "earn gold", "get gold", "treasure"]
        ),
    ])

    // MARK: - Saving

    static let saving = FAQCategory(title: "Saving & Loading", contexts: ["settings"], entries: [
        FAQEntry(
            question: "How do I save my game?",
            answer: "Tap 'Save/Quit' from the exploration menu. Choose 'Save' to save and continue playing, or 'Quit+Save' to save and exit. The game also auto-saves every few rooms. You can have multiple save slots.",
            keywords: ["save", "save game", "how to save", "autosave"]
        ),
        FAQEntry(
            question: "How do I load a saved game?",
            answer: "From the main menu, tap 'Play' then 'Load Game'. Choose the save slot you want to load. Your full party, inventory, and dungeon progress will be restored.",
            keywords: ["load", "load game", "continue", "resume", "restore"]
        ),
        FAQEntry(
            question: "How many save slots do I have?",
            answer: "You can have up to 5 save slots. If all slots are full, you'll need to overwrite an existing save or delete one from Settings → Save → Manage Saves.",
            keywords: ["save slots", "how many saves", "save limit", "delete save"]
        ),
    ])

    // MARK: - Multiplayer

    static let multiplayer = FAQCategory(title: "Multiplayer", contexts: ["settings", "exploration"], entries: [
        FAQEntry(
            question: "How do I invite a remote player?",
            answer: "During a local game, open Party Status and tap 'Invite Remote Player'. This sends a Game Center invitation. The other player needs the game installed and Game Center signed in. They'll see the invite in their Requests.",
            keywords: ["invite", "remote player", "multiplayer", "game center", "friend", "online"]
        ),
        FAQEntry(
            question: "How does multiplayer work?",
            answer: "Multiplayer is turn-based via Game Center. The host controls exploration (movement, searching, resting). In combat, each player controls their own character. It's asynchronous — you don't need to be online at the same time.",
            keywords: ["multiplayer", "how multiplayer", "turn based", "online play", "game center multiplayer"]
        ),
        FAQEntry(
            question: "How do I enable multiplayer?",
            answer: "Go to Settings → Gameplay and turn on Multiplayer. You need to be signed into Game Center. Then during a game, mark characters as 'Remote' in Party Status and send invites.",
            keywords: ["enable multiplayer", "turn on multiplayer", "setup multiplayer", "game center"]
        ),
        FAQEntry(
            question: "Can I chat with other players?",
            answer: "Tap 'Chat' from the exploration or inventory menus to message your party. Use @Name to address specific party members. In multiplayer, your messages are sent to other players on their next turn.",
            keywords: ["chat", "message", "talk", "party chat", "communicate"]
        ),
    ])

    // MARK: - Dungeon Master (AI)

    static let dm = FAQCategory(title: "Dungeon Master (AI)", contexts: ["exploration", "combat", "settings"], entries: [
        FAQEntry(
            question: "How do I talk to the DM?",
            answer: "Tap 'Ask the DM' from the exploration menu, or enter chat mode and type your question. The DM can describe the world, give hints, and (at higher ad-lib levels) affect gameplay. Type shortcuts: 'i' for inventory, 'm' for map.",
            keywords: ["ask dm", "talk to dm", "dungeon master", "dm chat"]
        ),
        FAQEntry(
            question: "What are DM ad-lib levels?",
            answer: "Off: silent DM. Flavour Only: atmospheric descriptions, no game changes. Moderate: DM can heal, grant items, deal damage. Full: DM can create side-quests and dramatic events. Set this in Settings → Gameplay.",
            keywords: ["ad-lib", "adlib", "dm level", "dm mode", "flavour", "moderate", "full"]
        ),
        FAQEntry(
            question: "How do I get a smarter DM?",
            answer: "The default DM uses your device's built-in AI. For better responses, set up a free API key in Settings → Gameplay → DM Provider. Google Gemini offers a free tier. Cloud AI gives richer, more creative narration.",
            keywords: ["smarter dm", "better dm", "api key", "gemini", "claude", "openai", "ai provider"]
        ),
        FAQEntry(
            question: "What is DM Voice?",
            answer: "DM Voice reads the Dungeon Master's narration aloud using text-to-speech. Enable it in Settings → Accessibility → DM Voice. You can customise the voice, speed, and pitch. You can also tap the speaker icon for continuous narration.",
            keywords: ["dm voice", "text to speech", "tts", "narration", "read aloud"]
        ),
    ])

    // MARK: - Accessibility

    static let accessibility = FAQCategory(title: "Accessibility", contexts: ["settings"], entries: [
        FAQEntry(
            question: "How do I change the text size?",
            answer: "Go to Settings → Accessibility → Font Size. Choose from Small, Medium, Large, or Extra Large. The entire game interface scales to match.",
            keywords: ["text size", "font size", "bigger text", "small text", "accessibility"]
        ),
        FAQEntry(
            question: "How do I use voice input?",
            answer: "In chat mode, tap the microphone icon next to the text field. Speak your message — it'll be transcribed and sent automatically after a pause. Enable Voice Menus in Accessibility settings to use voice control on menu screens too.",
            keywords: ["voice", "microphone", "speech", "voice input", "dictation"]
        ),
        FAQEntry(
            question: "Can I turn off combat animations?",
            answer: "Go to Settings → Accessibility and toggle 'Hits Off'. This disables the visual flash effects when attacks land in combat.",
            keywords: ["animations", "hit effects", "flash", "visual effects"]
        ),
    ])

    // MARK: - Shortcuts & Tips

    static let shortcuts = FAQCategory(title: "Shortcuts & Tips", contexts: ["exploration", "combat", "inventory"], entries: [
        FAQEntry(
            question: "What shortcuts are available?",
            answer: "Long-press Rest for a fast long rest. Long-press any character creation button to auto-fill. Long-press a direction to barricade a door. On Mac, use arrow keys for movement and letter keys for menu options.",
            keywords: ["shortcut", "long press", "quick", "fast", "hotkey"]
        ),
        FAQEntry(
            question: "How do I auto-create a party?",
            answer: "During character creation, long-press any button to auto-fill all remaining choices. Or type 'a' when asked for a character name to auto-create with a random name, race, class, and equipment.",
            keywords: ["auto create", "random party", "auto fill", "quick start"]
        ),
        FAQEntry(
            question: "What do the button colours mean?",
            answer: "Bright green: action buttons. Dim green: navigation (Done, Back). Cyan: chat and multiplayer. Amber: other characters' packs. The ✕ icon exits the current screen.",
            keywords: ["button colour", "button color", "green button", "cyan button", "amber"]
        ),
    ])

    // MARK: - DM Knowledge Lookup

    /// Find FAQ entries relevant to a player's message (for DM to reference)
    static func findRelevant(for message: String, limit: Int = 3) -> [FAQEntry] {
        let lower = message.lowercased()
        let words = Set(lower.components(separatedBy: .alphanumerics.inverted).filter { $0.count > 2 })

        var scored: [(entry: FAQEntry, score: Int)] = []

        for entry in allEntries {
            var score = 0
            // Keyword matches (strongest signal)
            for keyword in entry.keywords {
                if lower.contains(keyword) {
                    score += 10
                }
            }
            // Word overlap with question
            let qWords = Set(entry.question.lowercased().components(separatedBy: .alphanumerics.inverted).filter { $0.count > 2 })
            score += words.intersection(qWords).count * 3

            if score > 0 {
                scored.append((entry, score))
            }
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0.entry }
    }

    /// Return tips weighted by game context — entries matching the context are 3x more likely
    static func contextWeightedTip(context: String, excluding: Set<Int>) -> (tip: String, index: Int)? {
        let tips = GameEngine.gameplayTips
        guard !tips.isEmpty else { return nil }

        // Build a set of indices that match this context
        var contextIndices = Set<Int>()
        var idx = 7  // Skip the 7 core tips (always general)
        for category in categories {
            for entry in category.entries where entry.answer.count <= 180 {
                if category.contexts.contains(context) {
                    contextIndices.insert(idx)
                }
                idx += 1
            }
        }

        let available = tips.indices.filter { !excluding.contains($0) }
        if available.isEmpty { return nil }

        // Strongly prefer context-matching tips — only fall back to general if none left
        let contextAvailable = available.filter { contextIndices.contains($0) }
        if !contextAvailable.isEmpty {
            guard let picked = contextAvailable.randomElement() else { return nil }
            return (tips[picked], picked)
        }

        // Fallback: core tips (0-4) then any remaining
        let coreTips = available.filter { $0 < 7 }
        let pool = coreTips.isEmpty ? available : coreTips
        guard let picked = pool.randomElement() else { return nil }
        return (tips[picked], picked)
    }
}
