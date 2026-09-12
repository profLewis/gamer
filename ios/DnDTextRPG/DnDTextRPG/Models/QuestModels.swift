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

    func description(target: Int) -> String {
        switch self {
        case .defeatMonsters: return "Defeat \(target) more monsters"
        case .collectGold: return "Amass \(target) more gold"
        case .fullyEquipped: return "Get every adventurer armed with a weapon, armor, and shield"
        case .reachLevel: return "Get an adventurer to level \(target)"
        }
    }
}

enum SideQuestReward: Codable {
    case bonusGold(Int)
    case titleSuffix(String)
    case maxHPBoost(Int)

    var description: String {
        switch self {
        case .bonusGold(let amount): return "\(amount) gold"
        case .titleSuffix(let suffix): return "the title \"\(suffix)\""
        case .maxHPBoost(let amount): return "+\(amount) max HP for the whole party"
        }
    }
}

struct SideQuest: Codable {
    let giverName: String
    let type: SideQuestType
    let target: Int
    let reward: SideQuestReward
    /// Baseline captured when the quest was accepted, so progress measures
    /// the CHANGE since accepting rather than lifetime totals (relevant for
    /// defeatMonsters/collectGold — fullyEquipped/reachLevel are absolute
    /// checks and ignore these).
    let startMonstersSlain: Int
    let startPartyGold: Int

    var description: String { type.description(target: target) }

    /// Random quest sized to the current dungeon level — called by an NPC
    /// deciding what to offer.
    static func random(level: Int, giverName: String, monstersSlain: Int, partyGold: Int) -> SideQuest {
        let type = SideQuestType.allCases.randomElement() ?? .defeatMonsters
        let target: Int
        switch type {
        case .defeatMonsters: target = 3 + level
        case .collectGold: target = (20 + level * 15)
        case .fullyEquipped: target = 1
        case .reachLevel: target = min(5, 2 + level / 2)
        }
        let reward: SideQuestReward
        switch Int.random(in: 0..<3) {
        case 0: reward = .bonusGold(30 + level * 20)
        case 1: reward = .titleSuffix(["the Magnificent", "the Bold", "the Unyielding", "the Renowned"].randomElement()!)
        default: reward = .maxHPBoost(2 + level)
        }
        return SideQuest(giverName: giverName, type: type, target: target, reward: reward,
                          startMonstersSlain: monstersSlain, startPartyGold: partyGold)
    }
}

extension SideQuestType: CaseIterable {}
