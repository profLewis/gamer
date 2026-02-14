//
//  DungeonModels.swift
//  DnDTextRPG
//
//  Dungeon, room, and world models
//

import Foundation

// MARK: - Direction

enum Direction: String, CaseIterable, Codable {
    case north = "North"
    case south = "South"
    case east = "East"
    case west = "West"

    var opposite: Direction {
        switch self {
        case .north: return .south
        case .south: return .north
        case .east: return .west
        case .west: return .east
        }
    }

    var offset: (x: Int, y: Int) {
        switch self {
        case .north: return (0, -1)
        case .south: return (0, 1)
        case .east: return (1, 0)
        case .west: return (-1, 0)
        }
    }
}

// MARK: - Room Types

enum RoomType: String, CaseIterable, Codable {
    case entrance = "Entrance"
    case corridor = "Corridor"
    case chamber = "Chamber"
    case treasure = "Treasure Room"
    case trap = "Trap Room"
    case boss = "Boss Chamber"
    case shrine = "Shrine"
    case library = "Library"
    case armory = "Armory"
    case prison = "Prison"
    case empty = "Empty Room"

    var description: String {
        switch self {
        case .entrance:
            return [
                "The dungeon entrance. Dim light filters in from outside, casting long shadows on the damp stone walls.",
                "Carved into the hillside, the entrance yawns like a mouth. Cold air rises from below, carrying the scent of earth and iron.",
                "Crumbling steps descend into darkness. The last rays of daylight cling to the moss-covered threshold.",
            ].randomElement()!
        case .corridor:
            return [
                "A narrow stone corridor stretches before you. Water drips from the ceiling, echoing in the stillness.",
                "The walls press close here. Scratch marks score the stone — something clawed its way through.",
                "Flickering torchlight reveals carvings on the walls: warnings in a language long forgotten.",
                "The corridor bends ahead. A cold draft carries the faint sound of something breathing in the dark.",
            ].randomElement()!
        case .chamber:
            return [
                "A vast chamber opens before you. Pillars carved with serpentine figures hold up the vaulted ceiling.",
                "The ceiling soars overhead, lost in shadow. Broken furniture and scattered bones hint at former inhabitants.",
                "A large room with cracked flagstones. Faded tapestries hang in tatters from rusted hooks on the walls.",
                "This wide chamber still echoes with the memory of voices. Soot marks on the walls suggest old campfires.",
            ].randomElement()!
        case .treasure:
            return [
                "Gold glints in the torchlight! Coins and trinkets are scattered across a stone altar.",
                "A glittering hoard catches your eye — someone, or something, has been collecting valuables here.",
                "Jewels wink from crevices in the wall. A half-open chest sits in the corner, its lock long since broken.",
            ].randomElement()!
        case .trap:
            return [
                "Something feels wrong about this room. The floor tiles are unevenly spaced — deliberate, perhaps?",
                "A faint clicking echoes from the walls. Tiny holes line the stonework at ankle height. Tread carefully.",
                "The air here smells of old oil and copper. Grooves in the floor suggest something swings across this space.",
            ].randomElement()!
        case .boss:
            return [
                "A massive chamber wreathed in shadow. The air thrums with malevolent energy. Something ancient waits here.",
                "The room opens into a cathedral of darkness. Bones are arranged in patterns on the floor — an offering, or a warning.",
                "A throne of blackened stone sits at the far end. The walls are scarred by claws and scorched by fire. You sense a powerful presence.",
            ].randomElement()!
        case .shrine:
            return [
                "An ancient shrine stands in the center, its stone basin filled with clear water that seems to glow faintly.",
                "Candles that should have burned out long ago still flicker on the altar. The air feels calm and warm here.",
                "A weathered statue of a forgotten deity watches over this room. Wildflowers grow impossibly from cracks in the stone floor.",
            ].randomElement()!
        case .library:
            return [
                "Dusty tomes line the walls from floor to ceiling. A reading desk holds a book still open to a page on alchemy.",
                "Scrolls and leather-bound volumes fill every shelf. The smell of old parchment and ink hangs heavy in the air.",
                "Most books here have crumbled to dust, but a few remain intact — their spines glinting with gold leaf titles.",
            ].randomElement()!
        case .armory:
            return [
                "Weapon racks and armor stands fill this room. Most have been picked clean, but some items remain.",
                "Swords, shields, and helms line the walls. A forge in the corner is cold but could be relit. A merchant has set up shop here.",
                "Rows of rusted weapons stand at attention like silent soldiers. A workbench holds tools for repair and sharpening.",
            ].randomElement()!
        case .prison:
            return [
                "Iron bars and chains line the walls. Names and tallies are scratched into the stone — someone counted the days here.",
                "Rows of cells stretch into the darkness. A skeletal hand reaches through the bars of one, frozen in its last plea.",
                "The stench of old straw and despair clings to this place. Manacles hang open on the walls, their prisoners long gone.",
            ].randomElement()!
        case .empty:
            return [
                "An empty room, silent but for the drip of water. Cobwebs drape the corners like grey curtains.",
                "This room seems to serve no purpose. Dust motes drift in the still air, undisturbed for ages.",
                "Nothing of note here — just bare stone and silence. But the acoustics carry sounds from deeper in the dungeon.",
            ].randomElement()!
        }
    }

    var symbol: String {
        switch self {
        case .entrance: return "E"
        case .corridor: return "="
        case .chamber: return "#"
        case .treasure: return "$"
        case .trap: return "!"
        case .boss: return "B"
        case .shrine: return "+"
        case .library: return "L"
        case .armory: return "A"
        case .prison: return "P"
        case .empty: return "."
        }
    }
}

// MARK: - Room

class Room: Identifiable, ObservableObject, Codable {
    let id: Int
    let x: Int
    let y: Int
    @Published var roomType: RoomType
    @Published var name: String
    @Published var roomDescription: String  // Stored on creation, consistent forever
    @Published var exits: [Direction: Int]  // Direction -> Room ID
    @Published var visited: Bool
    @Published var cleared: Bool
    @Published var encounter: Encounter?
    @Published var treasure: [TreasureItem]
    @Published var isLocked: [Direction: Bool]
    @Published var searchedFor: Set<String>  // Things already searched for

    enum CodingKeys: String, CodingKey {
        case id, x, y, roomType, name, roomDescription, exits, visited, cleared
        case encounter, treasure, isLocked, searchedFor
    }

    init(id: Int, x: Int, y: Int, type: RoomType) {
        self.id = id
        self.x = x
        self.y = y
        self.roomType = type
        self.name = Room.generateName(for: type)
        self.roomDescription = type.description  // Pick once, store forever
        self.exits = [:]
        self.visited = false
        self.cleared = false
        self.encounter = nil
        self.treasure = []
        self.isLocked = [:]
        self.searchedFor = []
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        x = try container.decode(Int.self, forKey: .x)
        y = try container.decode(Int.self, forKey: .y)
        let decodedType = try container.decode(RoomType.self, forKey: .roomType)
        roomType = decodedType
        name = try container.decode(String.self, forKey: .name)
        // Backwards-compatible: old saves won't have roomDescription
        roomDescription = try container.decodeIfPresent(String.self, forKey: .roomDescription) ?? decodedType.description
        exits = try container.decode([Direction: Int].self, forKey: .exits)
        visited = try container.decode(Bool.self, forKey: .visited)
        cleared = try container.decode(Bool.self, forKey: .cleared)
        encounter = try container.decodeIfPresent(Encounter.self, forKey: .encounter)
        treasure = try container.decode([TreasureItem].self, forKey: .treasure)
        isLocked = try container.decode([Direction: Bool].self, forKey: .isLocked)
        searchedFor = try container.decode(Set<String>.self, forKey: .searchedFor)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(roomType, forKey: .roomType)
        try container.encode(name, forKey: .name)
        try container.encode(roomDescription, forKey: .roomDescription)
        try container.encode(exits, forKey: .exits)
        try container.encode(visited, forKey: .visited)
        try container.encode(cleared, forKey: .cleared)
        try container.encodeIfPresent(encounter, forKey: .encounter)
        try container.encode(treasure, forKey: .treasure)
        try container.encode(isLocked, forKey: .isLocked)
        try container.encode(searchedFor, forKey: .searchedFor)
    }

    static func generateName(for type: RoomType) -> String {
        switch type {
        case .entrance:
            return "Dungeon Entrance"
        case .corridor:
            return [
                "Narrow Passage", "Winding Corridor", "Torchlit Passage",
                "Echoing Tunnel", "Damp Corridor", "Crumbling Passage",
                "Shadowy Hallway", "Stone Corridor", "Cobwebbed Passage",
            ].randomElement()!
        case .chamber:
            return [
                "Vaulted Chamber", "Pillared Hall", "Sunken Chamber",
                "Dusty Great Room", "Ancient Hall", "Crumbling Chamber",
                "Moss-Covered Hall", "Torchlit Chamber", "Echoing Hall",
            ].randomElement()!
        case .treasure:
            return [
                "Glittering Treasury", "Hidden Vault", "Treasure Alcove",
                "Dragon's Hoard", "Forgotten Vault",
            ].randomElement()!
        case .trap:
            return [
                "Suspicious Hall", "Clicking Chamber", "Trapped Passage",
                "Pressure-Plate Room", "Grooved Corridor",
            ].randomElement()!
        case .boss:
            return [
                "The Inner Sanctum", "The Throne Room",
                "The Heart of Darkness", "The Lair",
            ].randomElement()!
        case .shrine:
            return [
                "Moonlit Shrine", "Candlelit Altar", "Ancient Sanctuary",
                "Blessed Shrine", "Forgotten Chapel",
            ].randomElement()!
        case .library:
            return [
                "Dusty Archives", "Forgotten Library", "Scholar's Study",
                "Tome-Filled Chamber", "Ruined Scriptorium",
            ].randomElement()!
        case .armory:
            return [
                "Rusted Armory", "Weapon Hall", "Iron Forge",
                "Quartermaster's Store", "Blade-Lined Chamber",
            ].randomElement()!
        case .prison:
            return [
                "The Iron Cells", "Abandoned Dungeon", "Bone-Strewn Prison",
                "The Oubliette", "Shackled Chamber",
            ].randomElement()!
        case .empty:
            return [
                "Quiet Alcove", "Barren Chamber", "Silent Room",
                "Hollow Chamber", "Vacant Hall",
            ].randomElement()!
        }
    }

    func describe() -> String {
        var desc = "\(name)\n\n\(roomDescription)"

        if !cleared && encounter != nil {
            desc += "\n\nYou sense danger here..."
        }

        if !treasure.isEmpty && cleared {
            desc += "\n\nYou see treasure on the ground."
        }

        let exitList = exits.keys.map { $0.rawValue }.joined(separator: ", ")
        if !exitList.isEmpty {
            desc += "\n\nExits: \(exitList)"
        }

        return desc
    }
}

// MARK: - Dungeon

class Dungeon: ObservableObject, Codable {
    let name: String
    let level: Int
    @Published var rooms: [Int: Room]
    @Published var currentRoomId: Int

    var currentRoom: Room? {
        rooms[currentRoomId]
    }

    enum CodingKeys: String, CodingKey {
        case name, level, rooms, currentRoomId
    }

    init(name: String, level: Int) {
        self.name = name
        self.level = level
        self.rooms = [:]
        self.currentRoomId = 0

        generateDungeon()
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        level = try container.decode(Int.self, forKey: .level)
        let roomsArray = try container.decode([Room].self, forKey: .rooms)
        var roomsDict: [Int: Room] = [:]
        for room in roomsArray {
            roomsDict[room.id] = room
        }
        rooms = roomsDict
        currentRoomId = try container.decode(Int.self, forKey: .currentRoomId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(level, forKey: .level)
        let roomsArray = Array(rooms.values).sorted { $0.id < $1.id }
        try container.encode(roomsArray, forKey: .rooms)
        try container.encode(currentRoomId, forKey: .currentRoomId)
    }

    private func generateDungeon() {
        let numRooms = 8 + level * 2

        // Create entrance
        let entrance = Room(id: 0, x: 0, y: 0, type: .entrance)
        entrance.visited = true
        rooms[0] = entrance

        var roomId = 1
        var frontier: [(Int, Int)] = [(0, 0)]
        var occupied: Set<String> = ["0,0"]

        // Generate rooms using flood fill
        while roomId < numRooms && !frontier.isEmpty {
            let (x, y) = frontier.randomElement()!

            // Try to add rooms in random directions
            for direction in Direction.allCases.shuffled() {
                if roomId >= numRooms { break }

                let newX = x + direction.offset.x
                let newY = y + direction.offset.y
                let key = "\(newX),\(newY)"

                if !occupied.contains(key) {
                    occupied.insert(key)

                    // Determine room type
                    let roomType: RoomType
                    if roomId == numRooms - 1 {
                        roomType = .boss
                    } else {
                        roomType = randomRoomType()
                    }

                    let newRoom = Room(id: roomId, x: newX, y: newY, type: roomType)

                    // Connect rooms
                    let fromRoom = rooms.values.first { $0.x == x && $0.y == y }!
                    fromRoom.exits[direction] = roomId
                    newRoom.exits[direction.opposite] = fromRoom.id

                    // Add encounter based on room type
                    if roomType != .entrance && roomType != .shrine {
                        if roomType == .boss {
                            newRoom.encounter = Encounter.generateBoss(level: level)
                        } else if roomType != .empty {
                            // Lower encounter rate and easier monsters at level 1
                            let encounterChance = level == 1 ? 0.35 : 0.5
                            let diff: EncounterDifficulty = level == 1 ? .easy : .medium
                            if Double.random(in: 0...1) < encounterChance {
                                newRoom.encounter = Encounter.generate(level: level, difficulty: diff)
                            }
                        }
                    }

                    // Add treasure to treasure rooms
                    if roomType == .treasure {
                        newRoom.treasure = TreasureItem.generateTreasure(level: level)
                    }

                    rooms[roomId] = newRoom
                    frontier.append((newX, newY))
                    roomId += 1
                }
            }

            // Remove from frontier if no more directions
            frontier.removeAll { $0.0 == x && $0.1 == y }
        }
    }

    private func randomRoomType() -> RoomType {
        let roll = Dice.d100()
        switch roll {
        case 1...20: return .corridor
        case 21...40: return .chamber
        case 41...50: return .empty
        case 51...60: return .treasure
        case 61...70: return .trap
        case 71...80: return .armory
        case 81...85: return .library
        case 86...90: return .shrine
        case 91...95: return .prison
        default: return .chamber
        }
    }

    /// Regenerate encounters for all uncleared rooms (keeps map layout intact)
    func rerollEncounters() {
        for room in rooms.values {
            guard !room.cleared else { continue }
            guard room.roomType != .entrance && room.roomType != .shrine else { continue }

            if room.roomType == .boss {
                room.encounter = Encounter.generateBoss(level: level)
            } else if room.roomType != .empty {
                let encounterChance = level == 1 ? 0.35 : 0.5
                let diff: EncounterDifficulty = level == 1 ? .easy : .medium
                guard Double.random(in: 0...1) < encounterChance else {
                    room.encounter = nil
                    continue
                }
                room.encounter = Encounter.generate(level: level, difficulty: diff)
            } else {
                room.encounter = nil
            }

            // Also regenerate treasure for treasure rooms
            if room.roomType == .treasure && room.treasure.isEmpty {
                room.treasure = TreasureItem.generateTreasure(level: level)
            }
        }
    }

    func move(direction: Direction) -> (success: Bool, message: String) {
        guard let current = currentRoom else {
            return (false, "Error: No current room")
        }

        guard let nextRoomId = current.exits[direction] else {
            return (false, "There is no exit to the \(direction.rawValue).")
        }

        guard let nextRoom = rooms[nextRoomId] else {
            return (false, "Error: Room not found")
        }

        currentRoomId = nextRoomId
        nextRoom.visited = true

        return (true, "You move \(direction.rawValue).\n\n\(nextRoom.describe())")
    }

    func getMapDisplay() -> [String] {
        let visitedRooms = rooms.values.filter { $0.visited }
        guard !visitedRooms.isEmpty else { return ["No map available."] }

        let minX = visitedRooms.map { $0.x }.min()!
        let maxX = visitedRooms.map { $0.x }.max()!
        let minY = visitedRooms.map { $0.y }.min()!
        let maxY = visitedRooms.map { $0.y }.max()!

        // Build a grid with rooms and corridors between them
        // Each room cell is 5 chars wide, corridor rows are 1 char tall
        var lines: [String] = []

        let mapWidth = min((maxX - minX + 1) * 6 + 3, 32)
        let border = String(repeating: "─", count: max(mapWidth, 18))
        lines.append("┌\(border)┐")
        lines.append("│ MAP".padding(toLength: border.count + 1, withPad: " ", startingAt: 0) + "│")
        lines.append("├\(border)┤")

        for y in minY...maxY {
            // Room row
            var roomRow = "│ "
            // Vertical corridor row (below this room row)
            var corridorRow = "│ "

            for x in minX...maxX {
                if let room = visitedRooms.first(where: { $0.x == x && $0.y == y }) {
                    if room.id == currentRoomId {
                        roomRow += "[@]"
                    } else if room.cleared {
                        roomRow += "[\(room.roomType.symbol)]"
                    } else if room.encounter != nil {
                        roomRow += "[!]"
                    } else {
                        roomRow += "[\(room.roomType.symbol)]"
                    }

                    // East corridor
                    if room.exits[.east] != nil {
                        roomRow += "──"
                    } else {
                        roomRow += "  "
                    }

                    // South corridor
                    if room.exits[.south] != nil {
                        corridorRow += " |   "
                    } else {
                        corridorRow += "     "
                    }
                } else {
                    roomRow += "     "
                    corridorRow += "     "

                    // Extra space for east corridor slot
                    roomRow += " "
                    corridorRow += " "
                }
            }

            roomRow = roomRow.padding(toLength: border.count + 1, withPad: " ", startingAt: 0) + "│"
            lines.append(roomRow)

            // Only add corridor row if not the last row
            if y < maxY {
                corridorRow = corridorRow.padding(toLength: border.count + 1, withPad: " ", startingAt: 0) + "│"
                lines.append(corridorRow)
            }
        }

        lines.append("├\(border)┤")
        lines.append("│ @=You !=Danger B=Boss".padding(toLength: border.count + 1, withPad: " ", startingAt: 0) + "│")
        lines.append("└\(border)┘")

        return lines
    }
}

// MARK: - Treasure

struct TreasureItem: Codable {
    let name: String
    let value: Int  // Gold value
    let type: TreasureType

    enum TreasureType: String, Codable {
        case gold
        case gem
        case item
        case potion
    }

    static func generateTreasure(level: Int) -> [TreasureItem] {
        var items: [TreasureItem] = []

        // Gold
        let goldAmount = Dice.rollSum(level + 1, d: 6) * 10
        items.append(TreasureItem(name: "\(goldAmount) Gold Pieces", value: goldAmount, type: .gold))

        // Maybe a gem
        if Dice.d20() >= 15 {
            let gems = ["Ruby", "Sapphire", "Emerald", "Diamond", "Pearl", "Amethyst"]
            let gem = gems.randomElement()!
            let value = Dice.rollSum(2, d: 6) * 25
            items.append(TreasureItem(name: gem, value: value, type: .gem))
        }

        // Maybe a potion
        if Dice.d20() >= 12 {
            items.append(TreasureItem(name: "Potion of Healing", value: 50, type: .potion))
        }

        return items
    }
}
