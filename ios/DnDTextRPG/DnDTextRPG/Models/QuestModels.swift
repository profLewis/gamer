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

    var summary: String { goal.prefix(1).uppercased() + goal.dropFirst() + " — " + stakes + "." }

    /// A quest where everything fits together: who the villain is, what
    /// they're doing to the village and why — and so what must be done, by
    /// when, and for what reward.
    static func random() -> MainQuest {
        let village = Int.random(in: 1...3) == 1 ? "Lithlind"
            : ["Brackenford", "Thistledown", "Emberholt", "Wyrmsby", "Millbrook", "Greywater", "Owlcombe"].randomElement()!
        let s = scenarios.randomElement()!
        return MainQuest(villain: s.villain, goal: s.goal(village), stakes: s.stakes, reward: s.reward,
                         village: village, harm: s.harm, motive: s.motive)
    }

    private struct Scenario {
        let villain: String
        let harm: String        // "In <village>, <harm>."
        let motive: String      // "<villain>, who <motive>."
        let goal: (String) -> String
        let stakes: String
        let reward: String
    }

    private static let scenarios: [Scenario] = [
        Scenario(villain: "Gorrak the Bugbear King", harm: "children have been vanishing from their beds at night",
                 motive: "is digging himself an underground kingdom and wants the children as his servants",
                 goal: { "rescue the children taken from \($0)" }, stakes: "before Gorrak's tunnels are finished and he carries them deeper still",
                 reward: "the village's savings, and a feast in the heroes' honour"),
        Scenario(villain: "Mother Sable, the Hag of the Deep", harm: "the Heartstone that warms every hearth has been stolen from the shrine",
                 motive: "wants its warmth for her own cold, drowned halls",
                 goal: { "recover the Heartstone stolen from \($0)'s shrine" }, stakes: "before winter comes and the village freezes",
                 reward: "the smith's finest blade and three hundred gold"),
        Scenario(villain: "Vorkath the Ember Drake", harm: "the outlying farms are being burned and the cattle carried off",
                 motive: "is fattening itself up before its hundred-year sleep",
                 goal: { "end the drake's raids on \($0) for good" }, stakes: "before every farm in the valley is ash",
                 reward: "a share of the drake's hoard"),
        Scenario(villain: "the Hollow King", harm: "the dead walk out of the churchyard every night, because the old bell that kept them asleep has been stolen",
                 motive: "stole the bell to wake the dead and raise an army",
                 goal: { "bring back the Bell of \($0), whose ringing keeps the dead asleep" }, stakes: "before the new moon, when every grave will open at once",
                 reward: "the pick of the old king's armoury"),
        Scenario(villain: "Skarn the Goblin Warlord", harm: "goblins raid the farms every night, taking food and tools",
                 motive: "is gathering supplies for a war on the whole valley",
                 goal: { "stop Skarn's raids on \($0) for good" }, stakes: "before his warband is big enough to march",
                 reward: "five hundred gold from the Lord of the Marches"),
        Scenario(villain: "Nightshade, the Lich's Apprentice", harm: "half the village has fallen into a sleep that nobody can wake them from",
                 motive: "is stealing the sleepers' dreams to make herself into a lich",
                 goal: { "find the cure for the sleeping sickness in \($0)" }, stakes: "before the sleepers are lost for good",
                 reward: "the herbalists' gold, and free healing for life"),
        Scenario(villain: "Old Grimtooth the Cave Troll", harm: "the deep tunnels of the mine have collapsed, trapping twelve miners",
                 motive: "brought the tunnels down to keep the silver seam for itself",
                 goal: { "free the miners trapped beneath \($0)" }, stakes: "while there is still air in the tunnels",
                 reward: "a share in the silver seam"),
        Scenario(villain: "the Weaver in the Dark, a spider as big as a cart", harm: "travellers on the road keep disappearing, and only strands of silk are left behind",
                 motive: "is gathering food for a nest of hatching young",
                 goal: { "free the travellers taken on the road to \($0)" }, stakes: "before the eggs hatch",
                 reward: "the merchants' guild reward of four hundred gold"),
        Scenario(villain: "Baron Rot, the Mushroom Tyrant", harm: "the wells have turned grey, and anyone who drinks from them falls sick",
                 motive: "is spreading his spores to turn the whole valley into one great fungus garden",
                 goal: { "cleanse the wells of \($0)" }, stakes: "before the spores reach the fields and spoil the harvest",
                 reward: "a year of free supplies from every shop in the village"),
        Scenario(villain: "Caldra the Frost Wyrm", harm: "the river has frozen solid in midsummer, and the mill has stopped",
                 motive: "has made her nest at the river's source and freezes it to keep her eggs cold",
                 goal: { "drive Caldra from the river's source and thaw \($0)'s river" }, stakes: "before the harvest rots for want of flour",
                 reward: "the miller's savings, and the thanks of the whole valley"),
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
