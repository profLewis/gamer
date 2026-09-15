//
//  QuestModels.swift
//  DnDTextRPG
//
//  Side quests offered by dungeon NPCs — separate from the main "beat the
//  boss" objective. Only one can be active at a time; a giver checks
//  GameEngine.activeQuest == nil before offering.
//

import Foundation

enum SideQuestType: String, Codable {
    case defeatMonsters   // Defeat N more monsters
    case collectGold      // Bring the party's total gold up by N
    case fullyEquipped    // Every conscious party member wielding weapon+armor+shield
    case reachLevel       // Any party member reaches level N
    case visitRoomType    // Find and enter a room of a given type (see SideQuest.targetRoomType)
    case slayBoss         // The Gatekeeper's own quest — defeat the dungeon boss. Never offered by
                           // anyone else, and never auto-completed by isSideQuestComplete(); the boss
                           // fight ending the game entirely is a distinct flow (see handleGameVictory()).

    func description(target: Int, roomType: RoomType?) -> String {
        switch self {
        case .defeatMonsters: return "Defeat \(target) more monsters"
        case .collectGold: return "Amass \(target) more gold"
        case .fullyEquipped: return "Get every adventurer armed with a weapon, armor, and shield"
        case .reachLevel: return "Get an adventurer to level \(target)"
        case .visitRoomType: return "Find and enter the \(roomType?.rawValue ?? "special room") somewhere in this dungeon"
        case .slayBoss: return "Slay the creature that lurks in the depths of this dungeon"
        }
    }
}

enum SideQuestReward: Codable {
    case bonusGold(Int)
    case titleSuffix(String)
    case maxHPBoost(Int)
    case newSkill                 // free proficiency in a skill someone lacks
    case specialSpell             // a rare class-specific spell, not learned via normal leveling
    case instantLevelUp           // an immediate level, XP requirement waived
    case familiar                 // a companion familiar
    case certificate(String)      // a framed, purely decorative memento

    var description: String {
        switch self {
        case .bonusGold(let amount): return "\(amount) gold"
        case .titleSuffix(let suffix): return "the title \"\(suffix)\""
        case .maxHPBoost(let amount): return "+\(amount) max HP for the whole party"
        case .newSkill: return "a new skill, free of charge"
        case .specialSpell: return "a rare spell"
        case .instantLevelUp: return "an instant level up"
        case .familiar: return "a familiar companion"
        case .certificate(let name): return "a \(name)"
        }
    }
}

struct SideQuest: Codable {
    let giverName: String
    let type: SideQuestType
    let target: Int
    let reward: SideQuestReward
    /// Which room type to find, for .visitRoomType only — nil for every
    /// other quest type.
    let targetRoomType: RoomType?
    /// Baseline captured when the quest was accepted, so progress measures
    /// the CHANGE since accepting rather than lifetime totals (relevant for
    /// defeatMonsters/collectGold — fullyEquipped/reachLevel/visitRoomType
    /// are absolute checks and ignore these).
    let startMonstersSlain: Int
    let startPartyGold: Int
    /// When it was accepted (game minutes) — the giver chases slow progress.
    var acceptedAt: Int? = nil
    /// How many times the giver has chased so far.
    var chaseCount: Int? = nil
    /// Extra gold the giver was talked into adding (paid on completion).
    var extraGold: Int? = nil

    var description: String { type.description(target: target, roomType: targetRoomType) }

    static let certificateNames = ["Certificate of Valor", "Certificate of Merit", "Certificate of Bravery", "Certificate of Perseverance"]
    static let familiarTypes = ["Raven", "Black Cat", "Toad", "Owl", "Imp", "Sprite", "Fox"]
    static let familiarNames = ["Whisper", "Shadow", "Ember", "Pip", "Nyx", "Sage", "Boots", "Gale"]
    /// Room types worth sending someone looking for — excludes entrance
    /// (already visited by definition), boss (has its own separate quest),
    /// corridor/empty (too mundane to feel like a destination).
    static let notableRoomTypes: [RoomType] = [.treasure, .shrine, .library, .armory, .prison, .shop, .trap, .chamber]

    /// Random quest sized to the current dungeon level, with a reward drawn
    /// from only the options this party could actually receive right now
    /// (e.g. no "special spell" offered if nobody in the party casts), and
    /// (for visitRoomType) a destination that actually exists in this dungeon.
    static func random(level: Int, giverName: String, monstersSlain: Int, partyGold: Int, party: [Character], dungeon: Dungeon, includeSlayBoss: Bool = false) -> SideQuest {
        let presentRoomTypes = Set(dungeon.rooms.values.map { $0.roomType })
        let availableDestinations = notableRoomTypes.filter { presentRoomTypes.contains($0) }
        // Monsters that can actually still be fought in this dungeon — a
        // "defeat N more" quest must never ask for more than physically
        // exist left to kill.
        let remainingMonsters = dungeon.rooms.values.filter { !$0.cleared }.reduce(0) { $0 + ($1.encounter?.monsters.count ?? 0) }

        var possibleTypes = SideQuestType.allCases.filter { $0 != .visitRoomType && $0 != .defeatMonsters && $0 != .slayBoss }
        if !availableDestinations.isEmpty { possibleTypes.append(.visitRoomType) }
        if remainingMonsters >= 3 { possibleTypes.append(.defeatMonsters) }
        // Only the Gatekeeper offers this, and only while the boss hasn't
        // been defeated yet — weighted in a few times so it comes up often
        // (it's their whole reason for existing) without being guaranteed
        // every single time, which is the actual variety being asked for.
        if includeSlayBoss, dungeon.rooms.values.contains(where: { $0.roomType == .boss && !$0.cleared }) {
            possibleTypes.append(contentsOf: [.slayBoss, .slayBoss, .slayBoss])
        }
        let type = possibleTypes.randomElement() ?? .collectGold

        var targetRoomType: RoomType? = nil
        let target: Int
        switch type {
        case .defeatMonsters:
            // Leave margin — don't demand literally every remaining monster.
            target = min(3 + level, max(1, Int(Double(remainingMonsters) * 0.8)))
        case .collectGold: target = (20 + level * 15)
        case .fullyEquipped: target = 1
        case .reachLevel: target = min(5, 2 + level / 2)
        case .visitRoomType:
            targetRoomType = availableDestinations.randomElement()
            target = 1
        case .slayBoss:
            target = 1
        }

        var options: [SideQuestReward] = [
            .bonusGold(30 + level * 20),
            .titleSuffix(["the Magnificent", "the Bold", "the Unyielding", "the Renowned"].randomElement()!),
            .maxHPBoost(2 + level),
            .certificate(certificateNames.randomElement()!),
        ]
        // slayBoss ends the adventure the moment it's completed, so rewards
        // that only matter for the REST of an adventure (a new skill, a
        // spell to actually cast, an instant level, a familiar to travel
        // with) don't make sense here — keep it to the ones that still mean
        // something at the finish line (gold, a title, a keepsake).
        if type != .slayBoss {
            if party.contains(where: { $0.skillProficiencies.count < Skill.allCases.count }) {
                options.append(.newSkill)
            }
            if party.contains(where: { char in
                guard let spell = SpellCatalog.specialSpellFor(characterClass: char.characterClass) else { return false }
                return !char.knownSpells.contains(where: { $0.name == spell.name })
            }) {
                options.append(.specialSpell)
            }
            if party.contains(where: { $0.level < 5 }) {
                options.append(.instantLevelUp)
            }
            if party.contains(where: { $0.familiarName == nil }) {
                options.append(.familiar)
            }
        }

        let reward = options.randomElement() ?? .bonusGold(30 + level * 20)
        return SideQuest(giverName: giverName, type: type, target: target, reward: reward,
                          targetRoomType: targetRoomType,
                          startMonstersSlain: monstersSlain, startPartyGold: partyGold)
    }
}

extension SideQuestType: CaseIterable {}


// MARK: - Main Quest

/// The adventure's own quest — why the party is here at all. Side quests
/// are the errands picked up along the way; this one ends with its villain,
/// the guardian waiting at the very bottom of the dungeon.
struct MainQuest: Codable {
    let villain: String
    let goal: String
    let stakes: String
    let reward: String
    let village: String
    /// What the villain is doing to the village, and why — so the tale
    /// can tell one story that makes sense. (Older saves don't have them.)
    var harm: String? = nil
    var motive: String? = nil
    /// What sort of quest (rescue, mystery, rival, twist...), and what the
    /// party finds out on the way down — one beat each on Levels 2, 4, 6.
    var kind: String? = nil
    var beats: [String]? = nil
    /// Where the prize (or the villain) is found, what must be done once
    /// it is, and who down there knows things — plus what the party has
    /// been told so far by asking around.
    var place: String? = nil
    var finale: String? = nil
    var informant: String? = nil
    var cluesLearned: [String]? = nil
    /// A time-bound quest's deadline ("the new moon", on day N): whether
    /// anyone has told the party when it is, and whether it has passed.
    var deadlineName: String? = nil
    var deadlineDay: Int? = nil
    var deadlineKnown: Bool? = nil
    var deadlinePassed: Bool? = nil
    /// A petitioner's village on another world: its name, and how they came
    /// (and will take the party back) — cleared once the party has travelled.
    var otherWorld: Bool? = nil
    var worldName: String? = nil
    var travelBy: String? = nil

    /// A quest whose stakes are time-bound gets a real day for it — generous
    /// enough to reach the bottom, but it does run out.
    func withDeadline(today: Int, level: Int) -> MainQuest {
        guard deadlineDay == nil else { return self }
        let s = stakes.lowercased()
        let table: [(String, String, Int)] = [
            ("new moon", "the new moon", 8), ("full moon", "the full moon", 10), ("eclipse", "the eclipse", 7),
            ("end of the week", "the end of the week", 7), ("eggs hatch", "the eggs hatching", 9), ("still air", "the air running out", 8),
            ("barrel", "the last of the water", 10), ("midwinter", "midwinter", 18), ("midsummer", "midsummer", 18),
            ("first snow", "the first snow", 16), ("winter", "winter", 16), ("coronation", "the coronation", 12),
            ("end of the month", "the end of the month", 20), ("harvest", "the harvest", 14), ("spring", "spring", 24),
            ("tunnels are finished", "the tunnels being finished", 12), ("warband", "the warband marching", 12),
            ("sleepers", "the sleepers being lost", 12), ("spores", "the spores reaching the fields", 12),
        ]
        guard let hit = table.first(where: { s.contains($0.0) }) else { return self }
        var q = self
        q.deadlineName = hit.1
        q.deadlineDay = today + max(hit.2, (Dungeon.finalLevel - level + 1) * 2)
        return q
    }

    /// The next thing someone could tell you, or nil once you know it all.
    var nextClue: String? {
        let learned = cluesLearned ?? []
        var all: [String] = []
        if let place = place { all.append("It's kept in \(place).") }
        if let finale = finale { all.append("When you find it, you must \(finale).") }
        return all.first { !learned.contains($0) }
    }

    /// The discovery waiting on arriving at this level, if any.
    func beat(forLevel level: Int) -> String? {
        guard level >= 2, level % 2 == 0, level <= 6 else { return nil }
        let all = beats ?? MainQuest.genericBeats(villain: villain)
        let i = level / 2 - 1
        return i < all.count ? all[i] : nil
    }

    /// Everything found out by this level, in order.
    func beatsSoFar(level: Int) -> [String] {
        guard level >= 2 else { return [] }
        return stride(from: 2, through: min(level, 6), by: 2).compactMap { beat(forLevel: $0) }
    }

    static func genericBeats(villain: String) -> [String] {
        let g = Dungeon.guardianName(villain)
        return ["Scratched on the wall by the stairs, in an old hand: '\(g) is below. Turn back.' You don't.",
                "You find the camp of the last party who tried. They left in a hurry, and they left their supplies behind.",
                "\(g)'s creatures grow thicker the deeper you go. You must be close."]
    }

    var summary: String { goal.prefix(1).uppercased() + goal.dropFirst() + " — " + stakes + "." }

    /// A quest where everything fits together: who the villain is, what
    /// they're doing to the village and why — and so what must be done, by
    /// when, for what reward — plus what's found out on the way down.
    static func random() -> MainQuest {
        let village = Int.random(in: 1...3) == 1 ? "Lithlind"
            : ["Brackenford", "Thistledown", "Emberholt", "Wyrmsby", "Millbrook", "Greywater", "Owlcombe"].randomElement()!
        let s = scenarios.randomElement()!
        return MainQuest(villain: s.villain, goal: s.goal(village), stakes: s.stakes, reward: s.reward, village: village,
                         harm: s.harm, motive: s.motive, kind: s.kind, beats: s.beats(village, Dungeon.guardianName(s.villain)),
                         place: s.place, finale: s.finale, informant: s.informant)
    }

    private struct Scenario {
        let kind: String
        let villain: String
        let harm: String        // "In <village>, <harm>."
        let motive: String      // "<villain>, who <motive>."
        let goal: (String) -> String
        let stakes: String
        let reward: String
        let beats: (String, String) -> [String]   // (village, villain's short name) -> Levels 2, 4, 6
        var place = ""          // "It's kept in <place>."
        var finale = ""         // "When you find it, you must <finale>."
        var informant = ""      // "<informant> know more than they let on."
    }

    private static let scenarios: [Scenario] = [
        Scenario(kind: "rescue", villain: "Gorrak the Bugbear King",
                 harm: "children have been vanishing from their beds at night",
                 motive: "is digging himself an underground kingdom and wants the children as his servants",
                 goal: { "rescue the children taken from \($0)" }, stakes: "before Gorrak's tunnels are finished and he carries them deeper still",
                 reward: "the village's savings, and a feast in the heroes' honour",
                 beats: { v, g in ["Scratched low on the wall by the stairs: a row of tally marks, and the name '\(v)'. The children came this way.",
                   "A goblin cook, sick of \(g)'s temper, trades you a secret for your rations: the children are kept at the bottom, digging.",
                   "You hear small voices singing a village song to keep their spirits up. They're close now."] },
                 place: "a half-dug hall at the very bottom, where the new tunnels begin", finale: "unlock the children's chains with Gorrak's own key and lead them out the way you came, carrying the smallest", informant: "the goblin cooks, who are sick of Gorrak's temper"),
        Scenario(kind: "theft", villain: "Mother Sable, the Hag of the Deep",
                 harm: "the Heartstone that warms every hearth has been stolen from the shrine",
                 motive: "wants its warmth for her own cold, drowned halls",
                 goal: { "recover the Heartstone stolen from \($0)'s shrine" }, stakes: "before winter comes and the village freezes",
                 reward: "the smith's finest blade and three hundred gold",
                 beats: { v, g in ["One patch of wall here is warm to the touch. The Heartstone was carried past, not long ago.",
                   "A drowned lantern-bearer, one of \(g)'s servants, drifts by and whispers that the stone is fading in her cold halls.",
                   "Frost creeps across the floor from below. She is using the stone's warmth up fast — hurry."] },
                 place: "a drowned hall where the water is so cold it smokes", finale: "wrap the Heartstone in wool, carry it home and set it back in the shrine's hollow — every hearth in the village lights at once", informant: "Sable's lantern-bearers, the drowned servants who drift about her halls"),
        Scenario(kind: "raids", villain: "Vorkath the Ember Drake",
                 harm: "the outlying farms are being burned and the cattle carried off",
                 motive: "is fattening itself up before its hundred-year sleep",
                 goal: { "end the drake's raids on \($0) for good" }, stakes: "before every farm in the valley is ash",
                 reward: "a share of the drake's hoard",
                 beats: { v, g in ["Scorch marks and a trail of cattle bones lead down the stairs. The drake has been this way.",
                   "A shepherd hiding in a side tunnel saw \(g) fly down past him, heavy and slow with food.",
                   "The air is hot enough to sting your eyes. The drake is settling down to sleep, and it will wake up hungry."] },
                 place: "the drake's nest, a cavern as hot as an oven, heaped with bones and stolen coins", finale: "carry the hoard back up to repay the farmers — with nothing left to guard, no drake stays", informant: "the shepherds and farmhands hiding in the side tunnels"),
        Scenario(kind: "curse", villain: "the Hollow King",
                 harm: "the dead walk out of the churchyard every night, because the old bell that kept them asleep has been stolen",
                 motive: "stole the bell to wake the dead and raise an army",
                 goal: { "bring back the Bell of \($0), whose ringing keeps the dead asleep" }, stakes: "before the new moon, when every grave will open at once",
                 reward: "the pick of the old king's armoury",
                 beats: { v, g in ["A bell-shaped ring is pressed into the dust. The bell was set down here to rest.",
                   "The ghost of an old bell-ringer drifts up to you. 'Ring it at the bottom,' she says, 'and his army sleeps again.'",
                   "Rows of empty coffins line the walls. The King's army is gathering, and it is nearly complete."] },
                 place: "the King's throne room, among rows of empty coffins", finale: "ring the Bell three times at the bottom of the dungeon, then carry it home and hang it back in the tower", informant: "the ghosts of the old bell-ringers"),
        Scenario(kind: "raids", villain: "Skarn the Goblin Warlord",
                 harm: "goblins raid the farms every night, taking food and tools",
                 motive: "is gathering supplies for a war on the whole valley",
                 goal: { "stop Skarn's raids on \($0) for good" }, stakes: "before his warband is big enough to march",
                 reward: "five hundred gold from the Lord of the Marches",
                 beats: { v, g in ["A goblin cart lies tipped over, full of stolen spades and turnips from \(v).",
                   "Painted on a wall: \(g)'s plan of attack, with \(v) circled three times. Badly.",
                   "War drums start up below. The warband is nearly ready to march."] },
                 place: "the war camp at the bottom, under a banner painted with Skarn's face", finale: "tear down Skarn's banner — goblins won't follow a warlord whose banner has fallen", informant: "goblin deserters who don't fancy a war"),
        Scenario(kind: "plague", villain: "Nightshade, the Lich's Apprentice",
                 harm: "half the village has fallen into a sleep that nobody can wake them from",
                 motive: "is stealing the sleepers' dreams to make herself into a lich",
                 goal: { "find the cure for the sleeping sickness in \($0)" }, stakes: "before the sleepers are lost for good",
                 reward: "the herbalists' gold, and free healing for life",
                 beats: { v, g in ["Black petals lie on the steps, the same as on every sleeper's pillow in \(v).",
                   "You find a jar of bottled dreams, labelled in neat handwriting: '\(v) — the baker'. So that's where they go.",
                   "\(g)'s garden of black flowers glows below. The cure must grow from the same roots."] },
                 place: "a garden of black flowers glowing in the dark, deep down", finale: "pick the one white flower at the heart of her garden and brew it into tea — a sip each wakes the sleepers", informant: "the moth-folk who flutter round her flowers"),
        Scenario(kind: "trapped", villain: "Old Grimtooth the Cave Troll",
                 harm: "the deep tunnels of the mine have collapsed, trapping twelve miners",
                 motive: "brought the tunnels down to keep the silver seam for itself",
                 goal: { "free the miners trapped beneath \($0)" }, stakes: "while there is still air in the tunnels",
                 reward: "a share in the silver seam",
                 beats: { v, g in ["You find a miner's helmet with a note inside: 'Still twelve of us. Water running low.'",
                   "Troll footprints the size of cartwheels lead towards the silver seam.",
                   "Tapping on the rock: three knocks, then three more. The miners are alive, and very near."] },
                 place: "the silver seam, behind a wall of fallen rock", finale: "dig through the last of the rubble and bring the miners up the rope, one at a time", informant: "the knockers, the little mine spirits who tap on the rock"),
        Scenario(kind: "missing", villain: "the Weaver in the Dark, a spider as big as a cart",
                 harm: "travellers on the road keep disappearing, and only strands of silk are left behind",
                 motive: "is gathering food for a nest of hatching young",
                 goal: { "free the travellers taken on the road to \($0)" }, stakes: "before the eggs hatch",
                 reward: "the merchants' guild reward of four hundred gold",
                 beats: { v, g in ["Silk strands hang across the corridor, still sticky. A traveller's hat is caught in one.",
                   "A merchant, wrapped up tight but alive, tells you the others are kept in a larder further down.",
                   "Hundreds of pale eggs cover the ceiling, and some of them are twitching."] },
                 place: "a larder of silk cocoons hung from the roof of the deepest cave", finale: "cut the travellers down, carefully, and burn the silk so the nest can never be rebuilt", informant: "travellers who were caught and got away"),
        Scenario(kind: "poison", villain: "Baron Rot, the Mushroom Tyrant",
                 harm: "the wells have turned grey, and anyone who drinks from them falls sick",
                 motive: "is spreading his spores to turn the whole valley into one great fungus garden",
                 goal: { "cleanse the wells of \($0)" }, stakes: "before the spores reach the fields and spoil the harvest",
                 reward: "a year of free supplies from every shop in the village",
                 beats: { v, g in ["The walls are furred with grey mould, the same colour as \(v)'s wells.",
                   "A cheerful mushroom-man, who has had enough of the Baron, says the spores all come from one great toadstool below.",
                   "The great toadstool is swelling. When it bursts, the spores will reach the fields."] },
                 place: "a cavern full of spores, around a toadstool as tall as a house", finale: "sprinkle salt on the great toadstool's roots — it shrivels, and the wells run clear within a day", informant: "the mushroom-folk who have had enough of the Baron"),
        Scenario(kind: "nature", villain: "Caldra the Frost Wyrm",
                 harm: "the river has frozen solid in midsummer, and the mill has stopped",
                 motive: "has made her nest at the river's source and freezes it to keep her eggs cold",
                 goal: { "drive Caldra from the river's source and thaw \($0)'s river" }, stakes: "before the harvest rots for want of flour",
                 reward: "the miller's savings, and the thanks of the whole valley",
                 beats: { v, g in ["Icicles hang from the ceiling in midsummer. The wyrm has been through here.",
                   "You find the miller's lost apprentice, half frozen, who followed the ice down. The river starts in a cavern at the very bottom, she says.",
                   "The cold here hurts your teeth. The eggs must be close to hatching."] },
                 place: "the river's source, a frozen cavern where the eggs lie in the ice", finale: "carry the eggs to a cold spring far from the river, so they can hatch there and the river can flow again", informant: "the frost sprites who dance on the ice"),
        Scenario(kind: "mystery", villain: "Grandmother Wick, the Candle Witch",
                 harm: "people keep forgetting things — names, faces, the way home — and nobody knows why",
                 motive: "has been stealing memories to make candles that let her live for ever",
                 goal: { "find out who is stealing the memories of \($0), and stop them" }, stakes: "before the whole village forgets itself",
                 reward: "four hundred gold and a portrait in the town hall, so nobody forgets you",
                 beats: { v, g in ["You find a candle stub that smells of fresh bread. When you light it, you remember a bakery you've never seen.",
                   "Wax footprints lead downwards. Somebody down here is making a great many candles.",
                   "A room full of candles, each labelled with a name from \(v). A tall one, burning brightest, says: '\(g)'."] },
                 place: "a candle-maker's workshop somewhere deep, which smells of honey and forgotten things", finale: "snuff out the tallest candle — every memory it holds flies home", informant: "the lost-looking folk wandering the halls, who can't remember why they came"),
        Scenario(kind: "rival", villain: "Sir Roderick Vane and his Gilded Company",
                 harm: "a rival band of adventurers stole the village's old map and has gone after the treasure the village needs to pay its debts",
                 motive: "want the treasure for themselves, and don't care who goes hungry",
                 goal: { "reach the Founders' Hoard of \($0) before Sir Roderick does" }, stakes: "before the tax collector comes at the end of the month",
                 reward: "a tenth of the hoard, which is a great deal",
                 beats: { v, g in ["Fresh boot prints and a gilded button on the stairs. The Gilded Company is a day ahead of you.",
                   "You find one of Sir Roderick's men tied up by his own friends — they left him when he twisted his ankle. He tells you their plan.",
                   "Voices ahead, arguing about how to split the gold. They're nearly there."] },
                 place: "a vault behind a door carved with the village's crest", finale: "press the village's old seal onto the chest to claim the hoard in its name, then carry it home", informant: "members of the Gilded Company who have fallen out with Sir Roderick"),
        Scenario(kind: "heir", villain: "Morthrax the Warden",
                 harm: "the young lord of the manor went into the dungeon to prove himself a month ago, and never came back",
                 motive: "keeps prisoners to guard his treasure, and the young lord is his newest",
                 goal: { "find the young lord of \($0) and bring him home" }, stakes: "before the manor passes to his greedy uncle at midwinter",
                 reward: "the young lord's thanks, and a fine horse each from the manor stables",
                 beats: { v, g in ["Carved into a pillar: a stag, the young lord's family crest, with an arrow pointing down.",
                   "You find the young lord's sword, dropped in a hurry. The blade is notched — he put up a fight.",
                   "A voice echoes up, reciting the names of his ancestors to stay brave. It's him."] },
                 place: "the Warden's treasure vault, where prisoners are chained up to guard the gold", finale: "free the young lord, give him back his sword and let him walk out first — he wants to come home a hero", informant: "other prisoners who have escaped the Warden"),
        Scenario(kind: "ritual", villain: "Voss the Eclipse Priest",
                 harm: "the stars have been going out, one by one, over the village",
                 motive: "is trying to summon an endless night so that his master can rule in the dark",
                 goal: { "stop Voss's ritual and bring back the stars over \($0)" }, stakes: "before the eclipse at the end of the week",
                 reward: "a telescope from the Royal Observatory, and five hundred gold",
                 beats: { v, g in ["Chalk circles on the floor, carefully drawn and carefully rubbed out. Someone has been practising.",
                   "A frightened acolyte asks you to let him go home. He tells you \(g)'s ritual needs three candles, lit at the very bottom.",
                   "Two of the three candles are lit. There isn't long."] },
                 place: "an altar ringed with three tall candles, under the lowest vault of the dungeon", finale: "blow out the candles in the reverse order they were lit — and the stars come back, one by one", informant: "Voss's acolytes, many of whom would rather go home"),
        Scenario(kind: "hunt", villain: "the Grey Widow, a wolf as tall as a horse",
                 harm: "a huge wolf has been taking sheep, then dogs, and last night it came right up to the school door",
                 motive: "is feeding a litter of cubs in the caves and grows bolder every night",
                 goal: { "hunt down the Grey Widow before she takes a child from \($0)" }, stakes: "before the full moon, when she hunts at her boldest",
                 reward: "the hunters' guild prize of three hundred gold, and a wolf-fur cloak each",
                 beats: { v, g in ["Tufts of grey fur and sheep's wool on the steps. She comes and goes this way.",
                   "An abandoned trapper's camp. His diary says her den is at the bottom, where it's warm.",
                   "Cubs whine somewhere below — and something much bigger growls at them to be quiet."] },
                 place: "a warm den at the bottom, lined with stolen blankets", finale: "bring back her collar of stolen dog tags, so the whole village knows it's over", informant: "the trappers and hunters who have tried before"),
        Scenario(kind: "twist", villain: "Lord Mallory",
                 harm: "the village's Luckstone has been stolen, and bad luck has fallen on every family",
                 motive: "stole it himself, then hired heroes to take the blame when they failed",
                 goal: { "recover the Luckstone of \($0)" }, stakes: "before the harvest fails",
                 reward: "the purse Lord Mallory promised — though there's something odd about his smile",
                 beats: { v, g in ["A servant's note, dropped on the stairs: 'He never kept the stone in the vault at all.'",
                   "In a thieves' camp you find a letter paying them for the job — in \(g)'s own handwriting.",
                   "Fresh footprints come down a hidden stair from the surface. \(g) is here, ahead of you, to make sure the stone is never found."] },
                 place: "a hidden vault that only Lord Mallory knew about", finale: "set the Luckstone back on its old stone on the village green, for everyone to see — and tell them who took it", informant: "Lord Mallory's servants, who have their suspicions"),
        Scenario(kind: "prison", villain: "Warden Krell",
                 harm: "the village blacksmith was dragged off by goblin jailers, accused of a crime he didn't commit",
                 motive: "runs a prison-mine in the deep and needs a smith to make his chains",
                 goal: { "free \($0)'s blacksmith from Warden Krell's prison" }, stakes: "before he's sent down to the mines, where nobody comes back from",
                 reward: "a suit of armour each, made to measure by the blacksmith himself",
                 beats: { v, g in ["A broken shackle lies on the floor, with the smith's initials scratched into it. He's alive.",
                   "An escaped prisoner stops long enough to warn you: \(g) keeps the keys on his own belt, and never takes it off.",
                   "The ring of a hammer on an anvil. The smith is being made to forge chains, somewhere close."] },
                 place: "the cells beside Krell's forge, at the very bottom", finale: "take the keys from Krell's belt and unlock every cell, not just the smith's", informant: "escaped prisoners, and the rats who carry messages between the cells"),
        Scenario(kind: "debt", villain: "Nick Crook, the Goblin Moneylender",
                 harm: "the whole village owes money to a goblin moneylender, and he adds a little more every day",
                 motive: "wants to own the village, house by house",
                 goal: { "find the moneylender's ledger and burn every page of \($0)'s debts" }, stakes: "before he takes the mill, the inn and the school",
                 reward: "every family's debts gone, and a free dinner at every table in town",
                 beats: { v, g in ["A goblin clerk's lost page: \(v)'s mill, marked 'nearly mine'.",
                   "You find the counting room: abacuses, ink, and a great many locks. The ledger isn't here.",
                   "A weary goblin clerk tells you \(g) sleeps with the ledger under his pillow, right at the bottom."] },
                 place: "the moneylender's bedroom, at the bottom of a counting house full of locks", finale: "burn the ledger page by page in the village square, so everyone can watch their debts go up in smoke", informant: "Crook's overworked goblin clerks"),
        Scenario(kind: "knowledge", villain: "the Librarian Who Eats Books",
                 harm: "every book in the village school has been stolen, and the children can't learn to read",
                 motive: "eats knowledge to grow cleverer, and is nearly clever enough to escape the dungeon",
                 goal: { "bring back the stolen books of \($0)'s school" }, stakes: "before the Librarian finishes the last of them",
                 reward: "a scholar's library ticket for life, and three hundred gold",
                 beats: { v, g in ["A trail of torn pages leads downwards. There are teeth marks on them.",
                   "A talking bookmark, rescued from a half-eaten atlas, says the school's books are being saved for pudding.",
                   "Someone below is reading aloud in a growling voice, faster and faster. It's nearly finished."] },
                 place: "a library carved into the rock, its shelves half empty", finale: "read the Librarian's last page aloud — it's a binding spell — then carry the books home to the school", informant: "the books themselves: old pages and bookmarks still whisper"),
        Scenario(kind: "haunting", villain: "the Pale Piper",
                 harm: "every night sweet piping drifts up from the old well, and the village's cats and dogs follow it and don't come back",
                 motive: "is gathering an army of enchanted animals",
                 goal: { "silence the Pale Piper and bring home \($0)'s animals" }, stakes: "before the Piper learns the tune that calls people",
                 reward: "a basket of kittens (optional) and four hundred gold",
                 beats: { v, g in ["A single cat sits on the stairs, staring down and purring, as if it hears something.",
                   "Paw prints — hundreds of them — all heading the same way.",
                   "The piping is loud now, and your feet want to dance towards it. Stuff your ears and keep going."] },
                 place: "a cavern of echoes where the animals sit in rows, listening", finale: "snap the Piper's pipe in two — the animals wake up and follow you home", informant: "the animals who haven't quite fallen under the spell — especially cats"),
    ]
}

// MARK: - Adventure files

/// One adventure as a file: the village in trouble, the villain waiting at
/// the bottom, the goal, and its opening tale. In the tale, {party},
/// {dungeon}, {village}, {villain}, {goal}, {stakes} and {reward} are filled
/// in for whoever plays it. The defaults ship with the game; the story
/// writer reads a couple as examples of the style, and every new tale it
/// writes is kept as another file, so the collection grows.
struct AdventureFile: Codable {
    var title: String
    var village: String
    var villain: String
    var goal: String
    var stakes: String
    var reward: String
    var tale: [String]
    var author: String?
    /// Written by the story writer for one party (real names, no
    /// placeholders) — a style example, never replayed as a template.
    var generated: Bool?

    var mainQuest: MainQuest { MainQuest(villain: villain, goal: goal, stakes: stakes, reward: reward, village: village) }

    func filledTale(party: String, dungeon: String) -> [String] {
        tale.map { line in
            let a = line.replacingOccurrences(of: "{party}", with: party).replacingOccurrences(of: "{dungeon}", with: dungeon)
            let b = a.replacingOccurrences(of: "{village}", with: village).replacingOccurrences(of: "{villain}", with: villain)
            return b.replacingOccurrences(of: "{goal}", with: goal).replacingOccurrences(of: "{stakes}", with: stakes)
                .replacingOccurrences(of: "{reward}", with: reward)
        }
    }
}

enum AdventureLibrary {
    static let defaultsVersion = 1
    static let maxGenerated = 40

    /// Documents/Adventures. The defaults are written here, and every .json
    /// file in it is read — so anyone can add an adventure of their own.
    static var folder: URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let dir = docs.appendingPathComponent("Adventures", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func ensureDefaults() {
        guard UserDefaults.standard.integer(forKey: "adventureDefaultsVersion") < defaultsVersion, let dir = folder else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        for (i, a) in defaults.enumerated() {
            if let data = try? encoder.encode(a) {
                try? data.write(to: dir.appendingPathComponent(String(format: "default-%02d.json", i + 1)), options: .atomic)
            }
        }
        UserDefaults.standard.set(defaultsVersion, forKey: "adventureDefaultsVersion")
    }

    /// Every adventure file there is (the built-in defaults if none can be read).
    static func all() -> [AdventureFile] {
        ensureDefaults()
        guard let dir = folder, let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return defaults }
        let decoder = JSONDecoder()
        let loaded = urls.filter { $0.pathExtension.lowercased() == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url -> AdventureFile? in
                guard let data = try? Data(contentsOf: url), data.count < 64_000,
                      let a = try? decoder.decode(AdventureFile.self, from: data),
                      (3...14).contains(a.tale.count), !a.villain.isEmpty, !a.goal.isEmpty else { return nil }
                return a
            }
        return loaded.isEmpty ? defaults : loaded
    }

    /// Adventures that can be played as they are (not one party's own tale).
    static func templates() -> [AdventureFile] {
        let t = all().filter { $0.generated != true }
        return t.isEmpty ? defaults : t
    }

    /// Two tales to show the story writer the style: one of the originals,
    /// and (when there is one) one it wrote before.
    static func styleExamples() -> [AdventureFile] {
        let everything = all()
        var picks: [AdventureFile] = []
        if let a = everything.filter({ $0.generated != true }).randomElement() { picks.append(a) }
        if let b = everything.filter({ $0.generated == true }).randomElement() { picks.append(b) }
        else if let b = everything.filter({ $0.generated != true && $0.title != picks.first?.title }).randomElement() { picks.append(b) }
        return picks
    }

    /// Keeps a tale the story writer wrote as one more example (dropping the
    /// oldest once there are plenty).
    static func saveGenerated(_ adventure: AdventureFile) {
        guard let dir = folder else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(adventure) else { return }
        try? data.write(to: dir.appendingPathComponent("written-\(Int(Date().timeIntervalSince1970)).json"), options: .atomic)
        let written = ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("written-") }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        for url in written.dropLast(maxGenerated) { try? FileManager.default.removeItem(at: url) }
    }

    static let defaults: [AdventureFile] = [
        AdventureFile(title: "The Salt Wells", village: "Brackenford", villain: "Morwen the Brine Witch",
                      goal: "break the curse that has turned Brackenford's wells to salt",
                      stakes: "before the last barrel of fresh water runs dry",
                      reward: "a year's free ale at the Drowned Duck, and three hundred gold",
                      tale: [
                        "In Brackenford the wells have turned to salt, and the children cry for water in their sleep.",
                        "Old Tamsin the well-keeper tasted the brine and knew it at once: the work of {villain}, driven into the hills fifty years ago.",
                        "The witch has come back — not to the hills, but to the dark beneath them, to {dungeon}.",
                        "The village met in the tithe barn and nobody volunteered, until {party} walked in out of the rain, looking for supper.",
                        "The task is plain: {goal}, {stakes}.",
                        "Do it, and Brackenford will pay {reward}. Fail, and there'll be no Brackenford left to pay anyone.",
                        "Tamsin fills their flasks with the last sweet water in the village and points up the hillside.",
                        "The stone door of {dungeon} is cold and wet, and it smells of the sea.",
                      ], author: "Written for the game", generated: false),
        AdventureFile(title: "The Stolen Bell", village: "Owlcombe", villain: "the Hollow King",
                      goal: "bring back the Bell of Owlcombe, whose ringing keeps the restless dead asleep",
                      stakes: "before the next new moon, when the graves will open",
                      reward: "the pick of the old king's armoury",
                      tale: [
                        "Every dusk for three hundred years, the Bell of Owlcombe has rung, and every night the dead of Owlcombe have stayed in their graves.",
                        "Four nights ago it did not ring. The bell tower stood empty, and frost lay in the shape of a crown on the floor.",
                        "The sexton swears he saw a thin grey figure carry it off: {villain}, who ruled here before the bell was cast.",
                        "The earth in the churchyard has begun to stir, and the new moon is only days away.",
                        "The mayor found {party} at the crossroads inn and did not waste words: {goal}, {stakes}.",
                        "The reward is {reward} — which, the mayor admits, has not been opened since the old king was buried.",
                        "The tracks in the frost lead to the barrow on the hill, and to the stair that goes down into {dungeon}.",
                      ], author: "Written for the game", generated: false),
        AdventureFile(title: "The Sleeping Sickness", village: "Millbrook", villain: "Nightshade, the Lich's Apprentice",
                      goal: "find the cure for the sleeping sickness spreading through Millbrook",
                      stakes: "before it reaches the castle and the young prince",
                      reward: "five hundred gold pieces and a seat at the prince's table",
                      tale: [
                        "It began with the miller, who sat down after lunch and did not wake up.",
                        "Then the baker, then the blacksmith's twins, then half the choir, all asleep and smiling, and none of them waking.",
                        "The herbwife Agnes found black petals on every pillow, and she knows only one grower of black flowers: {villain}.",
                        "The apprentice was chased out of the Wizards' College years ago, and was last seen heading for {dungeon}.",
                        "Agnes needs brave hands, and {party} have them: {goal}, {stakes}.",
                        "The castle has promised {reward}, and Agnes has promised them her best bread, which the village says is worth more.",
                        "They set out at first light, with cloths over their mouths, and they do not stop to smell the flowers along the way.",
                      ], author: "Written for the game", generated: false),
        AdventureFile(title: "The Miners Below", village: "Greywater", villain: "Old Grimtooth the Cave Troll",
                      goal: "free the miners trapped beneath Greywater",
                      stakes: "while there is still air in the deep tunnels",
                      reward: "a share in the Greywater silver seam",
                      tale: [
                        "The Greywater mine bell rang at noon, which only means one thing: a cave-in.",
                        "Twelve miners are trapped below, and the men who went to dig them out came back running, white as flour.",
                        "Something huge is down there, they say, grinding rocks between its teeth: {villain}, who everyone hoped was only a story.",
                        "The old tunnels beneath the mine run all the way into {dungeon}, and that's where the troll has made its home.",
                        "The foreman grabs {party} by the sleeve as they pass the pit-head: {goal}, {stakes}.",
                        "The mine will give {reward} — and the miners' children will give them all the cheering they can manage.",
                        "They take a lamp each and a rope between them, and step into the cage that lowers them into the dark.",
                      ], author: "Written for the game", generated: false),
        AdventureFile(title: "The Heartstone", village: "Emberholt", villain: "Vorkath the Ember Drake",
                      goal: "recover the Heartstone stolen from Emberholt's shrine",
                      stakes: "before winter comes and every hearth in Emberholt goes cold for good",
                      reward: "the smith's finest blade, and the thanks of every hearth in Emberholt",
                      tale: [
                        "In Emberholt, no fire ever needs lighting: the Heartstone in the shrine keeps every hearth in the valley warm.",
                        "Last week the shrine doors were found melted, and the Heartstone was gone.",
                        "Scorch marks lead to the mountain, where the shepherds have seen something red and enormous circling: {villain}.",
                        "Already the frost creeps in under the doors, and the first snow is on the peaks.",
                        "The shrine keeper begs {party} for help: {goal}, {stakes}.",
                        "The village smith has promised {reward}, and she has been working on the blade for twenty years.",
                        "Wrapped in borrowed cloaks, they follow the scorch marks up the mountain to the black mouth of {dungeon}.",
                      ], author: "Written for the game", generated: false),
        AdventureFile(title: "The Night Raids", village: "Thistledown", villain: "Skarn the Goblin Warlord",
                      goal: "end the night raids on Thistledown for good",
                      stakes: "or the farms will be abandoned by spring",
                      reward: "a chest of the realm's gold and a title from the Lord of the Marches",
                      tale: [
                        "Every night for a month, goblins have raided Thistledown: chickens gone, fences flattened, and one very angry goose.",
                        "The goose, to be fair, gave as good as it got, but the farmers cannot keep this up.",
                        "The goblins answer to {villain}, who has painted his face on every barn door in the valley — badly.",
                        "His warband hides in {dungeon}, and grows bigger every week.",
                        "The Lord of the Marches has put up notices, and {party} were the only ones to read one to the end: {goal}, {stakes}.",
                        "The notice promises {reward}. The goose, following them out of the village, seems to think it is coming too.",
                        "It isn't. They shut the gate on it, shoulder their packs, and walk towards the smoke rising from {dungeon}.",
                      ], author: "Written for the game", generated: false),
        AdventureFile(title: "The Young Queen's Crown", village: "Wyrmsby", villain: "Mother Sable, the Hag of the Deep",
                      goal: "return the crown stolen from Wyrmsby's young queen",
                      stakes: "before her coronation at midsummer",
                      reward: "a knighthood each, and the pick of the queen's own horses",
                      tale: [
                        "Queen Elin of Wyrmsby is eleven years old, and in twelve days she is to be crowned.",
                        "There is only one problem: there is no crown. It vanished from a locked room, and a wet black feather was left in its place.",
                        "The royal librarian turned pale when he saw the feather: it belongs to {villain}, who trades in stolen things and stolen years.",
                        "The hag's lair lies deep beneath the marsh, in the drowned halls of {dungeon}.",
                        "The young queen summoned {party} herself, and asked them very politely to {goal}, {stakes}.",
                        "She has promised {reward}, and she wrote it down and signed it, in case anyone forgets.",
                        "They bow, since it seems the right thing to do, and set off across the marsh towards {dungeon}.",
                      ], author: "Written for the game", generated: false),
    ]
}
