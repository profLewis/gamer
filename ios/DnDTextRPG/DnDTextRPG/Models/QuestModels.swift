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
