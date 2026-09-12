//
//  RiddleData.swift
//  DnDTextRPG
//
//  Classic riddles — ancient folklore, mythology, and traditional English
//  riddles, all public domain (no copyrighted-book riddles, e.g. no Hobbit
//  riddles-in-the-dark, matching the rest of this project's copyright care).
//  Presented as multiple choice so a correct answer is always unambiguous
//  regardless of phrasing.
//

import Foundation

struct Riddle {
    let question: String
    let options: [String]      // exactly 4, correct answer first
    let source: String         // where it's drawn from, for flavour after solving

    var correctAnswer: String { options[0] }

    /// Options in a random display order, with the index of the correct one.
    func shuffled() -> (options: [String], correctIndex: Int) {
        let indexed = Array(options.enumerated()).shuffled()
        let correctIndex = indexed.firstIndex(where: { $0.offset == 0 })!
        return (indexed.map { $0.element }, correctIndex)
    }
}

struct RiddleData {
    /// A shuffled no-repeat draw order — every riddle in `all` is used
    /// exactly once before any of them repeat, then the pool reshuffles for
    /// the next cycle. Static, so it holds for the lifetime of the app
    /// process (one play session), covering both dungeon generation
    /// assigning riddles to rooms and any other ad-hoc riddle pick.
    private static var drawQueue: [Int] = []

    static func nextIndex() -> Int {
        if drawQueue.isEmpty {
            drawQueue = Array(0..<all.count).shuffled()
        }
        return drawQueue.removeFirst()
    }

    static let all: [Riddle] = [
        Riddle(question: "What walks on four legs in the morning, two legs at noon, and three legs in the evening?",
               options: ["A human being", "A dog", "A clock", "A tree"],
               source: "The Riddle of the Sphinx — Greek mythology"),
        Riddle(question: "Out of the eater came forth meat, and out of the strong came forth sweetness. What is it?",
               options: ["A lion and a honeycomb", "A cow and milk", "A bee and honey", "A wolf and a lamb"],
               source: "Samson's riddle — Book of Judges"),
        Riddle(question: "What has keys but no locks, space but no room, and you can enter but not go inside?",
               options: ["A keyboard", "A piano", "A map", "A house"],
               source: "Traditional riddle"),
        Riddle(question: "The more you take, the more you leave behind. What am I?",
               options: ["Footsteps", "Time", "Breath", "Money"],
               source: "Traditional riddle"),
        Riddle(question: "What has a heart that doesn't beat?",
               options: ["An artichoke", "A statue", "A drum", "A clock"],
               source: "Traditional riddle"),
        Riddle(question: "I am not alive, but I grow; I don't have lungs, but I need air; I don't have a mouth, but water kills me. What am I?",
               options: ["Fire", "A plant", "A stone", "Ice"],
               source: "Traditional riddle"),
        Riddle(question: "What can travel around the world while staying in a corner?",
               options: ["A stamp", "A spider", "A map", "A shadow"],
               source: "Traditional riddle"),
        Riddle(question: "What comes once in a minute, twice in a moment, but never in a thousand years?",
               options: ["The letter M", "A heartbeat", "A second", "A wish"],
               source: "Traditional riddle"),
        Riddle(question: "What has many teeth but cannot bite?",
               options: ["A comb", "A saw", "A gear", "A key"],
               source: "Traditional riddle"),
        Riddle(question: "What has a neck but no head, two arms but no hands?",
               options: ["A shirt", "A bottle", "A guitar", "A jacket"],
               source: "Traditional riddle"),
        Riddle(question: "What gets wetter the more it dries?",
               options: ["A towel", "A sponge", "Rain", "The sea"],
               source: "Traditional riddle"),
        Riddle(question: "What can you catch but not throw?",
               options: ["A cold", "A ball", "A fish", "A thief"],
               source: "Traditional riddle"),
        Riddle(question: "I have cities, but no houses; forests, but no trees; rivers, but no water. What am I?",
               options: ["A map", "A globe", "A dream", "A painting"],
               source: "Traditional riddle"),
        Riddle(question: "What begins with an E, ends with an E, but only has one letter in it?",
               options: ["An envelope", "An eye", "An eagle", "An egg"],
               source: "Traditional riddle"),
        Riddle(question: "Riddle me this: two brothers we are, great burdens we bear, all day we are bitterly pressed. What are we?",
               options: ["Shoes", "Twins", "Oxen", "Millstones"],
               source: "Anglo-Saxon riddle — the Exeter Book"),
        Riddle(question: "What is so fragile that saying its name breaks it?",
               options: ["Silence", "Glass", "A promise", "An egg"],
               source: "Traditional riddle"),
        Riddle(question: "I have no life, but I can die. What am I?",
               options: ["A battery", "A candle", "A shadow", "A flower"],
               source: "Traditional riddle"),
        Riddle(question: "What building has the most stories?",
               options: ["The library", "The tower", "The castle", "The theatre"],
               source: "Traditional riddle"),
        Riddle(question: "What has one eye but cannot see?",
               options: ["A needle", "A storm", "A potato", "A cat"],
               source: "Traditional riddle"),
        Riddle(question: "What is always in front of you but can't be seen?",
               options: ["The future", "The wind", "Time", "The horizon"],
               source: "Traditional riddle"),
        Riddle(question: "I am taken from a mine, and shut up in a wooden case, from which I am never released, yet I am used by almost everyone. What am I?",
               options: ["Pencil lead", "A coin", "A diamond", "A nail"],
               source: "Traditional riddle"),
        Riddle(question: "What can fill a room but takes up no space?",
               options: ["Light", "Sound", "Smoke", "Air"],
               source: "Traditional riddle"),
        Riddle(question: "What five-letter word becomes shorter when you add two letters to it?",
               options: ["Short", "Small", "Brief", "Tiny"],
               source: "Traditional riddle"),
        Riddle(question: "The person who makes it, sells it. The person who buys it never uses it. The person who uses it never knows they're using it. What is it?",
               options: ["A coffin", "A candle", "A gravestone", "A bell"],
               source: "Traditional riddle"),
        Riddle(question: "What has a bottom at the top?",
               options: ["Legs", "A candle", "A hill", "A ladder"],
               source: "Traditional riddle"),
        Riddle(question: "What can you break, even if you never pick it up or touch it?",
               options: ["A promise", "A record", "Silence", "A vow"],
               source: "Traditional riddle"),
        Riddle(question: "Alive without breath, as cold as death, never thirsty, ever drinking. What am I?",
               options: ["A fish", "A ghost", "A stone", "A river"],
               source: "Traditional riddle (attested variant)"),
        Riddle(question: "This thing all things devours: birds, beasts, trees, flowers; gnaws iron, bites steel; grinds hard stones to meal. What is it?",
               options: ["Time", "Rust", "Fire", "A dragon"],
               source: "Traditional riddle (attested variant)"),
        Riddle(question: "What has hands but cannot clap?",
               options: ["A clock", "A statue", "A glove", "A puppet"],
               source: "Traditional riddle"),
        Riddle(question: "What runs all around a farmyard but never moves?",
               options: ["A fence", "A dog", "A well", "A path"],
               source: "Traditional riddle"),
        Riddle(question: "What kind of room has no doors or windows?",
               options: ["A mushroom", "A ballroom", "A wardrobe", "A cellar"],
               source: "Traditional riddle"),
        Riddle(question: "What goes up but never comes down?",
               options: ["Your age", "A balloon", "Smoke", "A kite"],
               source: "Traditional riddle"),
        Riddle(question: "What has to be broken before you can use it?",
               options: ["An egg", "A promise", "A seal", "A lock"],
               source: "Traditional riddle"),
        Riddle(question: "What invention lets you look right through a wall?",
               options: ["A window", "A telescope", "A mirror", "A door"],
               source: "Traditional riddle"),
    ]
}
