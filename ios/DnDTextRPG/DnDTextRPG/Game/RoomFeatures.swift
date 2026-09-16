//
//  RoomFeatures.swift — things to do in a room besides fight ("Look Around"):
//  light a cold forge, take a book off the shelf, drink the holy water, read
//  what someone scratched on a cell wall, forage for something to eat. Mostly
//  just for the doing; now and then a small reward — or one of the quest's
//  old runes, which, pieced together, tell what the quest was really about
//  (and pay off in the tale at the end).
//

import Foundation

/// One thing a room lets you do.
struct RoomFeature {
    let key: String       // remembered in Room.interactionsDone once done
    let button: String
    let hint: String      // what you notice on coming in
}

extension MainQuest {
    /// Four old runes cut into the walls on the way down. Read in order they
    /// tell who the villain is, what it wants, what it costs, and how it ends.
    var runeVerses: [String] {
        let g = Dungeon.guardianName(villain)
        return [
            "A name, worn almost smooth: \(g) — carved by someone who knew it long before you did.",
            motive.map { "\"\(g) \($0).\" A warning, cut deep and in a hurry." }
                ?? "\"It wants what was never its own.\" A warning, cut deep and in a hurry.",
            harm.map { "\"Up above, \($0).\" They knew what it would cost \(village)." }
                ?? "\"Up above, the village will pay.\" They knew what it would cost.",
            finale.map { "\"Whoever would end it must \($0).\"" } ?? "\"Whoever would end it must go all the way down.\"",
        ]
    }

    /// The level from which each rune can be found.
    static let runeLevels = [1, 2, 4, 5]

    var runesRead: Int { runesFound ?? 0 }
}

extension GameEngine {
    /// What this room offers that hasn't been done yet.
    func roomFeatures(_ room: Room) -> [RoomFeature] {
        guard let dungeon = dungeon else { return [] }
        var all: [RoomFeature] = []
        switch room.roomType {
        case .armory:
            all.append(RoomFeature(key: "forge", button: "Light the Forge", hint: "A cold forge squats in the corner, its bellows cracked but whole."))
        case .library:
            all.append(RoomFeature(key: "book", button: "Take a Book", hint: "Shelves of mouldering books sag along the walls."))
        case .shrine:
            all.append(RoomFeature(key: "water", button: "Drink Holy Water", hint: "A stone basin of still, clear water sits before the altar."))
            all.append(RoomFeature(key: "walls", button: "Read the Altar", hint: "Runes run round the altar's edge."))
        case .prison:
            all.append(RoomFeature(key: "scratch", button: "Read the Scratchings", hint: "Someone scratched marks into a cell wall — tallies, and words."))
        case .entrance:
            all.append(RoomFeature(key: "sign", button: "Read the Old Sign", hint: "A weathered sign is nailed up beside the way down."))
        case .chamber, .corridor, .empty, .treasure:
            if room.id % 3 == 1 {
                all.append(RoomFeature(key: "walls", button: "Examine the Walls", hint: "Faint carvings run along one wall, half hidden by grime."))
            }
        default:
            break
        }
        let plants: [RoomType] = [.chamber, .corridor, .empty, .entrance, .prison]
        if plants.contains(room.roomType) && (room.id * 7 + dungeon.level) % 4 == 0 {
            let hints = ["Pale mushrooms crowd the damp at the foot of one wall.",
                         "Moss grows thick here, and something with small white flowers.",
                         "Roots have pushed through a crack in the ceiling, trailing leaves.",
                         "A patch of glowing caps lights one corner a faint blue."]
            all.append(RoomFeature(key: "forage", button: "Forage", hint: hints[room.id % hints.count]))
        }
        return all.filter { !room.interactionsDone.contains($0.key) }
    }

    /// Look Around: the room's features, a button each.
    func showRoomFeatures(_ room: Room, onBack: @escaping () -> Void) {
        let features = roomFeatures(room)
        guard !features.isEmpty else { onBack(); return }
        clearTerminal()
        printExplorationMap()
        print("")
        printTitle("Look Around")
        print("")
        for f in features {
            printWrapped(f.hint, indent: 2, color: .cyan)
            print("")
        }
        showMenu(features.map { $0.button } + ["< Back"])
        closeHandler = onBack
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            guard choice >= 1, choice <= features.count else { onBack(); return }
            self.doRoomFeature(features[choice - 1], room: room, onBack: onBack)
        }
    }

    private func doRoomFeature(_ feature: RoomFeature, room: Room, onBack: @escaping () -> Void) {
        room.interactionsDone.insert(feature.key)
        clearTerminal()
        printTitle(feature.button)
        print("")
        let actor = party.filter { $0.isConscious }.randomElement() ?? party.first
        let name = actor.map { shortName(for: $0) } ?? "You"
        let lines: [(String, TerminalColor)]
        switch feature.key {
        case "forge": lines = forgeOutcome(name)
        case "book": lines = bookOutcome(name)
        case "water": lines = holyWaterOutcome()
        case "scratch": lines = scratchingsOutcome()
        case "sign": lines = [(signText(), .cyan)]
        case "walls": lines = wallsOutcome(room)
        case "forage": lines = forageOutcome(room)
        default: lines = []
        }
        for (text, color) in lines {
            printWrapped(text, indent: 2, color: color)
            print("")
        }
        if let after = aftermath(of: feature, room: room, actor: name) {
            printWrapped(after, indent: 2, color: .dimGreen)
            print("")
        }
        logEvent("\(feature.button) in \(room.name)", category: "EXPLORE")
        // A book is worth opening, not just identifying.
        if feature.key == "book" {
            showMenu(["Read It", "Put It Back"])
            closeHandler = { [weak self] in self?.afterFeature(room, onBack: onBack) }
            menuHandler = { [weak self] choice in
                guard let self = self else { return }
                if choice == 1 { self.readTheBook(page: 0, room: room, onBack: onBack) }
                else { self.afterFeature(room, onBack: onBack) }
            }
            return
        }
        waitForContinueWithTimeout { [weak self] in
            guard let self = self else { return }
            self.afterFeature(room, onBack: onBack)
        }
    }

    /// Back to the other things in this room, or out if there are none left.
    private func afterFeature(_ room: Room, onBack: @escaping () -> Void) {
        if roomFeatures(room).isEmpty { onBack() } else { showRoomFeatures(room, onBack: onBack) }
    }

    /// One short tale from the shelf, a page at a time, with a picture and a
    /// moral — the sort of thing somebody down here wrote to pass the dark.
    private func readTheBook(page: Int, room: Room, onBack: @escaping () -> Void) {
        let tale = Self.shelfTales[abs(room.id &+ (dungeon?.level ?? 1) &* 7) % Self.shelfTales.count]
        guard page < tale.pages.count else {
            clearTerminal(); printTitle(tale.title); print("")
            printWrapped(tale.moral, indent: 2, color: .yellow); print("")
            waitForContinueWithTimeout { [weak self] in self?.afterFeature(room, onBack: onBack) }
            return
        }
        clearTerminal()
        printTitle(tale.title)
        print("")
        let p = tale.pages[page]
        for line in p.art { print("    " + line, color: .cyan) }
        print("")
        printWrapped(p.text, indent: 2, color: .green)
        print("")
        print("  Page \(page + 1) of \(tale.pages.count)", color: .dimGreen)
        showMenu([page + 1 < tale.pages.count ? "Turn the Page" : "The End", "Close the Book"])
        closeHandler = { [weak self] in self?.afterFeature(room, onBack: onBack) }
        menuHandler = { [weak self] choice in
            guard let self = self else { return }
            if choice == 1 { self.readTheBook(page: page + 1, room: room, onBack: onBack) }
            else { self.afterFeature(room, onBack: onBack) }
        }
    }

    private func forgeOutcome(_ name: String) -> [(String, TerminalColor)] {
        var out: [(String, TerminalColor)] = [("\(name) works the bellows. Coals that haven't glowed in years catch, and the forge roars orange. For a while the room is warm, and the shadows back off.", .cyan)]
        switch Int.random(in: 1...10) {
        case 1...3:
            for c in party where c.isConscious { c.heal(2) }
            out.append(("Everyone warms their hands, and their bones. (+2 HP each)", .brightGreen))
        case 4...5:
            let coins = Int.random(in: 6...20)
            party.first?.gold += coins
            out.append(("Raking out the ash pit, \(name) turns up a smith's forgotten stash: \(coins) gold.", .yellow))
        default:
            out.append(([
                "A maker's mark is stamped on the anvil — a hammer and a star. Whoever worked here was good.",
                "The heat wakes a smell of old iron and older secrets. Nothing else happens. Probably for the best.",
                "Sparks fly up the flue. Somewhere far above, someone is wondering why their chimney is smoking.",
            ].randomElement()!, .dimGreen))
        }
        return out
    }

    /// A consequence, so looking around carries the story on a little
    /// instead of stopping dead at the description.
    private func aftermath(of feature: RoomFeature, room: Room, actor: String) -> String? {
        guard Int.random(in: 1...100) <= 55 else { return nil }
        switch feature.key {
        case "forge":
            return ["The forge ticks as it cools, and goes on ticking after you have stopped listening.",
                    "\(actor) pockets a nail. No reason. It just seemed a shame to leave it."].randomElement()
        case "book":
            return ["\(actor) keeps a finger in the page for a while, then gives up and lets it close.",
                    "Dust from the shelf hangs in the torchlight long after the book is shut."].randomElement()
        case "water", "walls", "scratch", "sign":
            return ["Somebody, a long time ago, stood exactly where \(actor) is standing and did exactly this.",
                    "The party goes quiet for a moment, then pretends it didn't.",
                    "\(actor) looks back at it twice on the way out."].randomElement()
        case "forage":
            return ["\(actor) wipes their hands on their coat and looks pleased with themselves.",
                    "Whatever was growing here will grow back. Probably."].randomElement()
        default:
            return nil
        }
    }

    /// Tales somebody wrote down here, to pass the dark.
    private static let shelfTales: [(title: String, pages: [(art: [String], text: String)], moral: String)] = [
        ("The Lamp That Would Not Be Carried",
         [(["   _n_", "  |   |", "  | * |", "  |___|"],
           "A lamp was made for a miner who went very deep. It burned well, and he loved it, and he would not put it down even to eat."),
          (["   _n_", "  |   |", "  |   |", "  |___|"],
           "So he did not eat. And the lamp, which had no opinion on the matter, burned exactly as long as lamps do, and then stopped."),
          (["    .", "   . .", "  .   ."],
           "They found him by the cold lamp, a hand's reach from a shaft where daylight came in.")],
         "The moral: a light you will not set down is a light you cannot see past."),
        ("Three Knocks",
         [(["  +------+", "  |      |", "  |  []  |", "  +------+"],
           "There was a door in a wall in a room nobody used, and once a year something on the other side knocked three times."),
          (["  +------+", "  |  ??  |", "  |  []  |", "  +------+"],
           "For ninety years the household answered the knock politely and did not open the door, and nothing bad happened at all."),
          (["  +------+", "  |      |", "  |      |", "  +------+"],
           "In the ninety-first year a clever young man opened it, to settle the question. The question is still settled.")],
         "The moral: some questions are load-bearing."),
        ("The Cook and the Crown",
         [(["   ___", "  (   )", "   | |", "  _|_|_"],
           "A king asked his cook what the kingdom most needed. The cook said: onions, and a bigger pot."),
          (["   ___", "  ( ! )", "   | |", "  _|_|_"],
           "The king had the cook thrown out, and took advice instead from people who spoke of destiny and of war."),
          (["   ...", "  (   )", "   | |", "  _|_|_"],
           "The war came. The kingdom was hungry. Somebody, in the end, went and found the cook.")],
         "The moral: the kitchen keeps you alive rather longer than the throne does."),
    ]

    private func bookOutcome(_ name: String) -> [(String, TerminalColor)] {
        let books = [
            ("A Bestiary of the Lower Deeps", "Mostly teeth, by the pictures. Someone has pencilled 'NO' beside the chapter on mimics."),
            ("Mushrooms, and How Not to Die of Them", "Short, practical, and suspiciously unfinished."),
            ("The Collected Sayings of Aunty Fen", "Every one of them is about soup."),
            ("A Very Long Poem About a Door", "The door, it turns out, was open the whole time."),
            ("Knots for the Adventuring Classes", "Forty-one knots. Two of them are just called 'the other one'."),
            ("Maps I Have Lost", "A memoir. Poignant, in places."),
            ("On the Proper Care of Torches", "Chapter one: do not drop the torch."),
        ]
        let (title, gist) = books.randomElement()!
        var out: [(String, TerminalColor)] = [("\(name) pulls down \"\(title)\". \(gist)", .cyan)]
        if let rune = revealRune(chance: 35, how: "Tucked between the pages is a rubbing of old runes. Copied out carefully, they read:") {
            out += rune
        } else {
            out.append(("\(name) puts it back. Or keeps it — it's hard to tell, with books.", .dimGreen))
        }
        return out
    }

    private func holyWaterOutcome() -> [(String, TerminalColor)] {
        var out: [(String, TerminalColor)] = [("The water is cold and tastes of stone. Each of you drinks, and feels steadier. (A little HP back.)", .cyan)]
        for c in party where c.isConscious {
            c.heal(Dice.d4())
            if c.isPoisoned && Bool.random() {
                c.isPoisoned = false
                out.append(("The poison in \(shortName(for: c))'s blood fades away.", .brightGreen))
            }
        }
        // The optional bit — now and then.
        if Int.random(in: 1...100) <= 20 {
            let coins = Int.random(in: 15...45)
            party.first?.gold += coins
            out.append(("As the last of you drinks, the water drops below a carved lip — and a niche in the basin's side clicks open. Inside is an offering nobody came back for: \(coins) gold.", .yellow))
        }
        return out
    }

    private func scratchingsOutcome() -> [(String, TerminalColor)] {
        let note = ["\"The guard sleeps after the third bell.\"", "\"Tell Mara I tried.\"",
                    "\"Not the left tunnel. NOT the left tunnel.\"", "\"Day 40. The rat and I have reached an understanding.\""].randomElement()!
        var out: [(String, TerminalColor)] = [("\(Int.random(in: 9...60)) tally marks, in rows of five. Then, smaller: \(note)", .cyan)]
        if let rune = revealRune(chance: 40, how: "Beneath them, older and deeper, a line of runes — copied again and again, as if to learn it by heart:") {
            out += rune
        }
        return out
    }

    private func signText() -> String {
        ["The sign reads: ABANDON HOPE. Someone has crossed out HOPE and written SNACKS.",
         "The sign reads: NO DRAGONS BEYOND THIS POINT. Underneath, in a different hand: 'citation needed'.",
         "The sign reads: MIND THE STEP. There are four hundred and twelve of them.",
         "The sign reads: ADVENTURERS WELCOME. The WELCOME has several arrows in it."].randomElement()!
    }

    private func wallsOutcome(_ room: Room) -> [(String, TerminalColor)] {
        if let rune = revealRune(chance: room.roomType == .shrine ? 100 : 45, how: "Under the grime, a line of old runes. You copy them down:") {
            return rune
        }
        // A mural is worth reading, not merely noticing.
        if Int.random(in: 1...100) <= 40 {
            let m = Self.murals.randomElement()!
            return [("A mural, faded and flaking, but most of it still legible.", .dimGreen),
                    (m.scene, .green),
                    (m.writing, .yellow)]
        }
        return [([
            "Claw marks, deep and parallel. Something big came through here, in a hurry.",
            "Old graffiti: 'BRAM WUZ ERE'. Bram, it seems, was everywhere.",
            "Water stains in the shape of a face. Probably.",
        ].randomElement()!, .dimGreen)]
    }

    /// What the murals show, and what is written under them — sometimes in
    /// a hand nobody here can read any more.
    private static let murals: [(scene: String, writing: String)] = [
        ("A line of figures carry something long and wrapped between them, down a stair with no bottom drawn in.",
         "Underneath, in a careful hand: \"WE TOOK IT DOWN. WE DID NOT COME BACK UP.\""),
        ("A feast. Every diner faces away from the table, and the table is laid for one more than there are chairs.",
         "Underneath, runes nobody has read in an age: \u{16A0}\u{16B1}\u{16C1} \u{16D2}\u{16A6}\u{16B7} \u{16DE}\u{16A2}\u{16B1}"),
        ("A great door, painted shut with a red seal, and a small figure standing with its palm flat against it.",
         "Underneath: \"IT KNOCKS POLITELY. THAT IS THE WORST OF IT.\""),
        ("Seven rings, one inside the next, with something small and bright kept at the centre.",
         "Underneath, scratched over the paint much later: \"COUNT THEM AGAIN.\""),
        ("Two armies, one facing the other, and between them a single figure with both arms raised.",
         "Underneath, runes worn almost flat: \u{16BE}\u{16A2}\u{16D6} \u{16C1}\u{16A0}\u{16DA}\u{16B1}"),
        ("A cook, a crown and a hound sharing one long bench, all three of them laughing.",
         "Underneath, in a rounder hand than the rest: \"THE KITCHEN KEPT US ALIVE, NOT THE THRONE.\""),
    ]

    /// The quest's next rune, if one can be found at this depth (a chance in
    /// 100) — kept under the main quest in Party Status, and told at the end.
    private func revealRune(chance: Int, how: String) -> [(String, TerminalColor)]? {
        guard var mq = mainQuest, let dungeon = dungeon else { return nil }
        let verses = mq.runeVerses
        let next = mq.runesRead
        guard next < verses.count, dungeon.level >= MainQuest.runeLevels[next], Int.random(in: 1...100) <= chance else { return nil }
        mq.runesFound = next + 1
        mainQuest = mq
        logEvent("Read a rune (\(next + 1) of \(verses.count)): \(verses[next])", category: "QUEST")
        return [(how, .cyan), ("ᚱ " + verses[next], .yellow),
                (next + 1 < verses.count
                    ? "(Rune \(next + 1) of \(verses.count) — noted under your main quest. There are more, deeper down.)"
                    : "(The last of the runes. Read together, they tell the whole of it — and how it has to end.)", .dimGreen)]
    }

    /// Survival or Nature, whoever's best: something to eat — or a stomach ache.
    private func forageOutcome(_ room: Room) -> [(String, TerminalColor)] {
        let able = party.filter { $0.isConscious }
        func knack(_ c: Character) -> Int { max(c.skillModifier(for: .survival), c.skillModifier(for: .nature)) }
        guard let forager = able.max(by: { knack($0) < knack($1) }) else { return [] }
        let name = shortName(for: forager)
        let survival = forager.skillModifier(for: .survival), nature = forager.skillModifier(for: .nature)
        let skill = survival >= nature ? "Survival" : "Nature"
        let mod = max(survival, nature)
        let dc = 10 + (dungeon?.level ?? 1) / 2
        let roll = Dice.roll(20)
        let total = roll + mod
        let plant = ["Glowcap Mushrooms", "Cave Moss Cakes", "Bitterroot", "Pale Morels"][room.id % 4]
        var out: [(String, TerminalColor)] = [("\(name) looks the plants over. (\(skill): \(roll) \(mod >= 0 ? "+" : "−") \(abs(mod)) = \(total), needs \(dc))", .dimGreen)]
        if total >= dc {
            let great = total >= dc + 5
            let item = Item(id: UUID(), name: plant, description: "Foraged in the deep — \(name) is sure they're safe to eat.", type: .potion,
                            weight: 0.3, value: 2, weaponStats: nil, armorStats: nil,
                            potionStats: PotionStats(healAmount: great ? "2d4" : "1d4", effect: great ? "Restores 2d4 HP" : "Restores 1d4 HP"))
            if let taker = able.first(where: { $0.canCarry(item) }) {
                _ = taker.addItem(item)
                out.append(("\(great ? "A fine find! " : "")\(name) knows these — \(plant.lowercased()), good to eat. \(shortName(for: taker)) packs some away. (\(item.potionStats?.effect ?? ""))", .brightGreen))
            } else {
                for c in able { c.heal(1) }
                out.append(("\(name) knows these are good to eat — but nobody has room to carry any, so you eat a few there and then.", .brightGreen))
            }
        } else if total <= dc - 5 {
            let hurt = Dice.d4()
            forager.currentHP = max(1, forager.currentHP - hurt)
            out.append(("\(name) nibbles one to check. Wrong one. (\(hurt) damage, and a very long face.)", .red))
        } else {
            out.append(("\(name) isn't sure which ones are safe, and leaves them be. Probably wise.", .yellow))
        }
        return out
    }
}
