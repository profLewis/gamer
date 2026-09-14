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
import CryptoKit

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

// MARK: - Puzzles (levels 3 and down)

/// A puzzle, defined as data — built in (PuzzleBank.builtIn) or from a
/// signed pack (PuzzlePackManager). Multiple choice when it has `options`
/// (correct first; shown shuffled), typed when it has `answers`.
struct Puzzle: Codable {
    let id: String
    let tier: Int            // 1 riddle · 2 logic · 3 word · 4 cryptic
    let kind: String
    let question: String
    let options: [String]?
    let answers: [String]?
    let hints: [String]?
    let source: String?

    var isTyped: Bool { options == nil }
    var correctAnswer: String { options?.first ?? answers?.first ?? "" }
    var hintList: [String] { hints ?? [] }

    /// Levels 1-2 riddles, 3-4 logic, 5-6 word puzzles, 7 cryptic clues.
    static func tier(forLevel level: Int) -> Int { level <= 2 ? 1 : (level <= 4 ? 2 : (level <= 6 ? 3 : 4)) }

    static func kindName(_ tier: Int) -> String { ["", "A Riddle", "A Logic Puzzle", "A Word Puzzle", "A Cryptic Clue"][min(4, max(1, tier))] }

    /// Capitals, spaces, punctuation and a leading "a/an/the" don't matter.
    static func normalize(_ s: String) -> String {
        var t = s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        for article in ["a ", "an ", "the "] where t.hasPrefix(article) { t = String(t.dropFirst(article.count)) }
        return String(String.UnicodeScalarView(t.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }))
    }

    func accepts(_ typed: String) -> Bool {
        let n = Puzzle.normalize(typed)
        return !n.isEmpty && (answers ?? []).contains { Puzzle.normalize($0) == n }
    }

    func shuffledOptions() -> (options: [String], correctIndex: Int) {
        let indexed = Array((options ?? []).enumerated()).shuffled()
        return (indexed.map { $0.element }, indexed.firstIndex { $0.offset == 0 } ?? 0)
    }

    /// The same checks the signing tool makes — a pack puzzle that fails
    /// any of them is dropped, never shown.
    var isValid: Bool {
        guard !id.isEmpty, id.count <= 80, (1...4).contains(tier), !question.isEmpty, question.count <= 600,
              hintList.count <= 5, hintList.allSatisfy({ $0.count <= 300 }), (source ?? "").count <= 200 else { return false }
        if let o = options { return (2...6).contains(o.count) && o.allSatisfy { !$0.isEmpty && $0.count <= 200 } }
        let a = answers ?? []
        return !a.isEmpty && a.count <= 10 && a.allSatisfy { !Puzzle.normalize($0).isEmpty && $0.count <= 60 }
    }
}

enum PuzzleBank {
    /// Built-in puzzles plus the installed pack's (a pack puzzle with the
    /// same id replaces the built-in one).
    static var all: [Puzzle] {
        var byId: [String: Puzzle] = [:]
        for p in builtIn { byId[p.id] = p }
        for p in PuzzlePackManager.shared.puzzles { byId[p.id] = p }
        return byId.values.sorted { $0.id < $1.id }
    }

    static func puzzle(id: String) -> Puzzle? {
        PuzzlePackManager.shared.puzzles.first { $0.id == id } ?? builtIn.first { $0.id == id }
    }

    /// No repeats within a tier until every puzzle of it has come up.
    private static var queues: [Int: [String]] = [:]
    static func nextId(tier: Int) -> String? {
        PuzzlePackManager.shared.checkIfDue()
        if queues[tier]?.isEmpty ?? true {
            queues[tier] = all.filter { $0.tier == tier }.map { $0.id }.shuffled()
        }
        guard var q = queues[tier], !q.isEmpty else { return nil }
        let id = q.removeFirst()
        queues[tier] = q
        return id
    }

    private static func mc(_ id: String, _ tier: Int, _ question: String, _ options: [String], hints: [String] = [], source: String = "Traditional puzzle") -> Puzzle {
        Puzzle(id: id, tier: tier, kind: tier == 2 ? "logic" : "riddle", question: question, options: options, answers: nil, hints: hints, source: source)
    }
    private static func typed(_ id: String, _ tier: Int, _ question: String, _ answers: [String], hints: [String], source: String = "Written for the game") -> Puzzle {
        Puzzle(id: id, tier: tier, kind: tier == 3 ? "word" : "cryptic", question: question, options: nil, answers: answers, hints: hints, source: source)
    }

    static let builtIn: [Puzzle] = [
        // Tier 2 — logic (levels 3-4), multiple choice
        mc("logic-chests", 2, "Three chests: Gold, Silver and Lead. Exactly one label tells the truth. Gold: 'The treasure is in here.' Silver: 'The treasure is not in here.' Lead: 'The treasure is not in the Gold chest.' Where is the treasure?",
           ["The Silver chest", "The Gold chest", "The Lead chest", "In none of them"], hints: ["Suppose it's in each chest in turn, and count the true labels."], source: "Written for the game"),
        mc("logic-river", 2, "A farmer must ferry a wolf, a goat and a cabbage across a river, one at a time. Left alone together, the wolf eats the goat and the goat eats the cabbage. What must cross first?",
           ["The goat", "The wolf", "The cabbage", "The farmer, alone"], hints: ["Which pair can safely be left together?"], source: "Traditional (Alcuin of York, 8th century)"),
        mc("logic-guards", 2, "Two guards stand at two doors. One door leads out. One guard always lies, the other always tells the truth, and you don't know which is which. You may ask one guard one question. What do you ask?",
           ["\"Which door would the other guard say leads out?\" — then take the other door", "\"Are you the liar?\"", "\"Which door leads out?\" — and take it", "\"Is the sky blue?\" — then ask again"],
           hints: ["You need a question that gives the same answer whoever you ask."], source: "Traditional logic puzzle"),
        mc("logic-torches", 2, "A torch burns for exactly one hour, but unevenly, so half its length isn't half an hour. With two such torches and a flint, how can you time exactly 45 minutes?",
           ["Light the first at both ends and the second at one end; when the first burns out, light the second's other end", "Burn one torch halfway, then the other", "Cut one torch into quarters", "It can't be done"],
           hints: ["A torch lit at both ends burns out in half the time."], source: "Traditional puzzle, retold"),
        mc("logic-goblin-line", 2, "Five goblins stand in a line. Pip is first. Mog is last. Grak is somewhere ahead of Snot, and Snot is somewhere ahead of Fizz. Who is second?",
           ["Grak", "Snot", "Fizz", "Mog"], hints: ["Three goblins fill places 2, 3 and 4 — in what order?"], source: "Written for the game"),
        mc("logic-gems", 2, "A bag holds 3 red gems and 3 blue gems. In the pitch dark, how many must you draw to be certain of two the same colour?",
           ["Three", "Two", "Four", "Six"], hints: ["Think about the unluckiest first draws."], source: "Traditional puzzle"),
        mc("logic-hoard", 2, "A dragon's hoard doubles every night. On the thirtieth night it fills the cave. On which night was the cave half full?",
           ["The twenty-ninth", "The fifteenth", "The twenty-eighth", "The first"], hints: ["Work backwards one night."], source: "Traditional puzzle"),
        mc("logic-snail", 2, "A snail climbs a 10-foot wall: up 3 feet each day, sliding back 2 feet each night. On which day does it reach the top?",
           ["The eighth day", "The tenth day", "The seventh day", "The ninth day"], hints: ["On the last day it doesn't slide back."], source: "Traditional puzzle"),
        mc("logic-knaves", 2, "Knights always tell the truth; knaves always lie. Ada says: 'We are both knaves.' Bo says nothing. What are they?",
           ["Ada is a knave, Bo is a knight", "Both are knaves", "Both are knights", "Ada is a knight, Bo is a knave"], hints: ["Could a knight ever say that?"], source: "Traditional logic puzzle"),
        mc("logic-siblings", 2, "A boy says, 'I have as many brothers as sisters.' His sister says, 'I have twice as many brothers as sisters.' How many children are in the family?",
           ["Seven", "Five", "Six", "Eight"], hints: ["Try four boys."], source: "Traditional puzzle"),
        mc("logic-switches", 2, "Three switches in the cellar each light one lamp upstairs. You may go upstairs to look only once. How can you tell which switch lights which lamp?",
           ["Turn one on for a while, then off; turn a second on; go up — the warm dark lamp is the first", "Turn them all on at once", "Turn them on one at a time, running up each time", "It can't be done"],
           hints: ["A lamp tells you more than whether it's lit."], source: "Traditional puzzle, retold"),
        mc("logic-scales", 2, "Nine gold coins look the same, but one is a lighter fake. Using a balance scale, what is the fewest weighings that will always find it?",
           ["Two", "Three", "Four", "One"], hints: ["Split them into three piles of three."], source: "Traditional puzzle"),

        // Tier 3 — word puzzles (levels 5-6), typed
        typed("word-silent", 3, "Rearrange the letters of LISTEN into a word that means 'making no sound'.", ["silent"], hints: ["Same six letters.", "It starts with S."]),
        typed("word-stone", 3, "Take away the first two letters of this five-letter word and ONE is left. You'll find it in every wall.", ["stone", "stones"], hints: ["_ _ O N E", "Walls are built of them."]),
        typed("word-dormitory", 3, "DIRTY ROOM is an anagram of one word: a place where many sleep.", ["dormitory"], hints: ["Think of a school or an abbey.", "It starts with DORM."]),
        typed("word-light", 3, "What word can follow SUN, MOON, CANDLE and STAR?", ["light"], hints: ["Each of them gives it off."]),
        typed("word-crown", 3, "Add one letter to CROW to get something a queen wears.", ["crown"], hints: ["Add it at the end."]),
        typed("word-pig", 3, "An animal is hiding in this sentence: \"Lift the cap I gave you.\" What is it?", ["pig"], hints: ["It runs across two words.", "Look at 'cap I gave'."]),
        typed("word-ladder", 3, "Turn COLD into WARM, one letter at a time: COLD, CORD, ?, WARD, WARM. What's missing?", ["card"], hints: ["Change the O of CORD.", "You'd play a game with it."]),
        typed("word-desserts", 3, "Spell this word backwards and you get STRESSED. What is it?", ["desserts"], hints: ["Read STRESSED from the end.", "Pudding!"]),
        typed("word-words", 3, "Rearrange SWORD to find what a scroll is full of.", ["words"], hints: ["Same five letters.", "You're reading them now."]),
        typed("word-rain", 3, "What word can come before BOW, COAT and DROP?", ["rain"], hints: ["You'd want the coat when it falls."]),
        typed("word-snow", 3, "What word can come before BALL, FLAKE and MAN?", ["snow"], hints: ["It falls in winter."]),
        typed("word-heart", 3, "Rearrange the letters of EARTH to find something that beats.", ["heart"], hints: ["It's inside you.", "It starts with H."]),

        // Tier 4 — cryptic clues (level 7), typed; the number is the answer's length
        typed("cryptic-ideal", 4, "I deal out something perfect (5)", ["ideal"], hints: ["Put I in front of DEAL.", "It means 'perfect'."]),
        typed("cryptic-tones", 4, "Stone broken into musical sounds (5)", ["tones"], hints: ["'Broken' means jumble the letters.", "Rearrange STONE.", "A singer holds them."]),
        typed("cryptic-art", 4, "Rat mixed up for a painter's work (3)", ["art"], hints: ["Jumble RAT.", "It hangs in a gallery."]),
        typed("cryptic-one", 4, "Some dragon eggs hide a single (3)", ["one"], hints: ["The answer is hidden in the words.", "Look across 'dragon eggs'."]),
        typed("cryptic-bat", 4, "In the tomb a timid flier hides (3)", ["bat"], hints: ["The answer is hidden in the words.", "Look across 'tomb a timid'."]),
        typed("cryptic-season", 4, "Sea boy makes a time of year (6)", ["season"], hints: ["Put two words together.", "SEA + a boy (a SON)."]),
        typed("cryptic-carpet", 4, "Motor and a favourite animal make a rug (6)", ["carpet"], hints: ["A motor is a CAR.", "A favourite animal is a PET."]),
        typed("cryptic-pot", 4, "Top turned back is a cooking vessel (3)", ["pot"], hints: ["Reverse TOP."]),
        typed("cryptic-evil", 4, "Every village in lands, at first, is wicked (4)", ["evil"], hints: ["Take the first letter of each word.", "E, V, I, L."]),
        typed("cryptic-dragon", 4, "Grand O, all mixed up, breathes fire (6)", ["dragon"], hints: ["'Mixed up' means jumble the letters.", "Rearrange GRANDO."]),
        typed("cryptic-date", 4, "An appointment with a fruit (4)", ["date"], hints: ["The clue gives two meanings of one word.", "It grows on palm trees."]),
        typed("cryptic-king", 4, "A ruler, and a playing card (4)", ["king"], hints: ["Two meanings of one word.", "He wears a crown."]),
    ]
}

/// New puzzles without an app update: a small signed JSON file in the
/// public repo (puzzles/pack.json). Installed only if its Ed25519 signature
/// matches the key below (the private key never leaves the maintainer's
/// machine — see tools/sign-puzzle-pack.swift), its version is newer than
/// any seen before (no rollbacks), and it's small; every puzzle is checked.
final class PuzzlePackManager {
    static let shared = PuzzlePackManager()
    static let publicKeyBase64 = "HUAgANvDDILCJmAM5DSveTe1desdWLfkZcpWgCvRJow="
    static let packURL = URL(string: "https://raw.githubusercontent.com/profLewis/gamer/main/puzzles/pack.json")!
    static let maxPayloadBytes = 256 * 1024

    private(set) var puzzles: [Puzzle] = []
    private(set) var version = 0
    private var checking = false

    private struct Envelope: Codable { let format: Int; let payload: String; let signature: String }
    private struct Body: Codable { let version: Int; let puzzles: [Puzzle] }

    private var fileURL: URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("PuzzlePack", isDirectory: true) else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("pack.json")
    }
    private var highestSeen: Int {
        get { UserDefaults.standard.integer(forKey: "puzzlePackHighestVersion") }
        set { UserDefaults.standard.set(newValue, forKey: "puzzlePackHighestVersion") }
    }

    private init() {
        // What's on disk is re-checked every launch, never trusted as is.
        if let url = fileURL, let data = try? Data(contentsOf: url), let body = Self.verify(data) {
            version = body.version
            puzzles = body.puzzles
        }
    }

    /// The pack's puzzles if (and only if) it's genuine and well-formed.
    static func verify(_ data: Data) -> (version: Int, puzzles: [Puzzle])? {
        guard data.count <= maxPayloadBytes * 2,
              let env = try? JSONDecoder().decode(Envelope.self, from: data), env.format == 1,
              let payload = Data(base64Encoded: env.payload), payload.count <= maxPayloadBytes,
              let signature = Data(base64Encoded: env.signature),
              let keyData = Data(base64Encoded: publicKeyBase64),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData),
              key.isValidSignature(signature, for: payload),
              let body = try? JSONDecoder().decode(Body.self, from: payload),
              body.version > 0, body.puzzles.count <= 1000 else { return nil }
        var seen = Set<String>()
        let good = body.puzzles.filter { $0.isValid && seen.insert($0.id).inserted }
        return (body.version, good)
    }

    /// At most once a day, quietly.
    func checkIfDue() {
        let last = UserDefaults.standard.double(forKey: "puzzlePackLastCheck")
        guard Date().timeIntervalSince1970 - last > 24 * 3600 else { return }
        check(completion: nil)
    }

    /// Fetches the pack; `completion` (on the main thread) says what happened.
    func check(completion: ((String) -> Void)?) {
        guard !checking else { completion?("Already checking…"); return }
        checking = true
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "puzzlePackLastCheck")
        var request = URLRequest(url: Self.packURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.httpMethod = "GET"
        URLSession(configuration: .ephemeral).dataTask(with: request) { [weak self] data, response, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.checking = false
                guard let data = data, (response as? HTTPURLResponse)?.statusCode == 200 else {
                    completion?("Couldn't reach the puzzle library just now — try again later.")
                    return
                }
                guard let body = Self.verify(data) else {
                    completion?("The puzzle pack online didn't pass its signature check, so it was ignored.")
                    return
                }
                guard body.version > max(self.version, self.highestSeen) else {
                    completion?("You have the latest puzzles (pack v\(self.version)).")
                    return
                }
                if let url = self.fileURL { try? data.write(to: url, options: .atomic) }
                self.version = body.version
                self.puzzles = body.puzzles
                self.highestSeen = body.version
                completion?("New puzzles installed: pack v\(body.version), \(body.puzzles.count) puzzles.")
            }
        }.resume()
    }
}
