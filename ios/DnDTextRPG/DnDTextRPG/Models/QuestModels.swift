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

    func description(target: Int, roomType: RoomType?) -> String {
        switch self {
        case .defeatMonsters: return "Defeat \(target) more monsters"
        case .collectGold: return "Amass \(target) more gold"
        case .fullyEquipped: return "Get every adventurer armed with a weapon, armor, and shield"
        case .reachLevel: return "Get an adventurer to level \(target)"
        case .visitRoomType: return "Find and enter the \(roomType?.rawValue ?? "special room") somewhere in this dungeon"
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
    static func random(level: Int, giverName: String, monstersSlain: Int, partyGold: Int, party: [Character], dungeon: Dungeon) -> SideQuest {
        let presentRoomTypes = Set(dungeon.rooms.values.map { $0.roomType })
        let availableDestinations = notableRoomTypes.filter { presentRoomTypes.contains($0) }

        var possibleTypes = SideQuestType.allCases.filter { $0 != .visitRoomType }
        if !availableDestinations.isEmpty { possibleTypes.append(.visitRoomType) }
        let type = possibleTypes.randomElement() ?? .defeatMonsters

        var targetRoomType: RoomType? = nil
        let target: Int
        switch type {
        case .defeatMonsters: target = 3 + level
        case .collectGold: target = (20 + level * 15)
        case .fullyEquipped: target = 1
        case .reachLevel: target = min(5, 2 + level / 2)
        case .visitRoomType:
            targetRoomType = availableDestinations.randomElement()
            target = 1
        }

        var options: [SideQuestReward] = [
            .bonusGold(30 + level * 20),
            .titleSuffix(["the Magnificent", "the Bold", "the Unyielding", "the Renowned"].randomElement()!),
            .maxHPBoost(2 + level),
            .certificate(certificateNames.randomElement()!),
        ]
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

        let reward = options.randomElement() ?? .bonusGold(30 + level * 20)
        return SideQuest(giverName: giverName, type: type, target: target, reward: reward,
                          targetRoomType: targetRoomType,
                          startMonstersSlain: monstersSlain, startPartyGold: partyGold)
    }
}

extension SideQuestType: CaseIterable {}
