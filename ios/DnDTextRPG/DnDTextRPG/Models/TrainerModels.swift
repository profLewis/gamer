//
//  TrainerModels.swift
//  DnDTextRPG
//
//  Training gyms — a named trainer who'll teach a party member a new skill
//  proficiency, for a membership fee or by winning a sparring check. Modelled
//  on the Merchant system (named persona, found in a room, one action button)
//  rather than inventing a whole new mechanic.
//

import Foundation

struct Trainer: Codable, Equatable {
    var name: String
    var gymName: String
    var specialty: Skill          // the skill this trainer is known for
    var greeting: String
    var membershipFee: Int
    var sparDC: Int                // DC to win free entry by sparring instead of paying
    var lessonFee: Int = 15          // per-skill training cost, charged on top of entry

    static func == (lhs: Trainer, rhs: Trainer) -> Bool { lhs.name == rhs.name && lhs.gymName == rhs.gymName }

    private struct Persona {
        let name: String
        let gymNames: [String]
        let greeting: String
    }

    private static func personas(for specialty: Skill) -> [Persona] {
        switch specialty {
        case .athletics, .acrobatics:
            return [Persona(name: "Coach Brannigan", gymNames: ["The Iron Ring", "Brannigan's Bootcamp"],
                             greeting: "\"You want to get stronger, or you want to talk about it? Pay up or prove it.\"")]
        case .stealth, .sleightOfHand:
            return [Persona(name: "Whisper Nyx", gymNames: ["The Quiet Hand", "Nyx's Backstreet School"],
                             greeting: "\"Shh. You found me — that's a start. Coin or a contest, your choice.\"")]
        case .arcana, .investigation:
            return [Persona(name: "Magister Fennick", gymNames: ["The Lantern Academy", "Fennick's Study"],
                             greeting: "\"Knowledge isn't free, but it is fairly priced. Pay, or best me in a test of wit.\"")]
        case .persuasion, .deception, .performance, .intimidation:
            return [Persona(name: "Silvertongue Rell", gymNames: ["The Velvet Word", "Rell's Parlour"],
                             greeting: "\"Everyone can be taught to talk their way through a locked door — for a price, or a wager.\"")]
        case .perception, .survival, .animalHandling, .nature:
            return [Persona(name: "Old Thistlewood", gymNames: ["The Wildwood Post", "Thistlewood's Camp"],
                             greeting: "\"City folk. Fine — coin's coin, or show me you've got the grit already.\"")]
        default:
            return [Persona(name: "Vann the Steady", gymNames: ["The Common Ground"],
                             greeting: "\"Everyone's welcome to learn. Pay the fee, or earn your way in.\"")]
        }
    }

    static func random(specialty: Skill, dungeonLevel: Int) -> Trainer {
        let persona = personas(for: specialty).randomElement()!
        return Trainer(
            name: persona.name,
            gymName: persona.gymNames.randomElement()!,
            specialty: specialty,
            greeting: persona.greeting,
            membershipFee: 15 + dungeonLevel * 10,
            sparDC: 12 + dungeonLevel,
            lessonFee: 10 + dungeonLevel * 5
        )
    }
}
