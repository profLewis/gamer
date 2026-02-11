//
//  DungeonModels.swift
//  DnDTextRPG
//
//  Dungeon, room, and world models
//

import Foundation

// MARK: - Direction

enum Direction: String, CaseIterable {
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

enum RoomType: String, CaseIterable {
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
            return "The dungeon entrance. Dim light filters in from outside."
        case .corridor:
            return "A narrow stone corridor stretches before you."
        case .chamber:
            return "A large chamber with high ceilings."
        case .treasure:
            return "Gold glints in the torchlight. This room holds treasure!"
        case .trap:
            return "Something feels wrong about this room..."
        case .boss:
            return "A massive chamber. You sense a powerful presence."
        case .shrine:
            return "An ancient shrine stands in the center of the room."
        case .library:
            return "Dusty tomes line the walls of this forgotten library."
        case .armory:
            return "Weapon racks and armor stands fill this room."
        case .prison:
            return "Iron bars and chains suggest this was once a prison."
        case .empty:
            return "An unremarkable room, empty and silent."
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

class Room: Identifiable, ObservableObject {
    let id: Int
    let x: Int
    let y: Int
    @Published var roomType: RoomType
    @Published var name: String
    @Published var exits: [Direction: Int]  // Direction -> Room ID
    @Published var visited: Bool
    @Published var cleared: Bool
    @Published var encounter: Encounter?
    @Published var treasure: [TreasureItem]
    @Published var isLocked: [Direction: Bool]
    @Published var searchedFor: Set<String>  // Things already searched for

    init(id: Int, x: Int, y: Int, type: RoomType) {
        self.id = id
        self.x = x
        self.y = y
        self.roomType = type
        self.name = Room.generateName(for: type)
        self.exits = [:]
        self.visited = false
        self.cleared = false
        self.encounter = nil
        self.treasure = []
        self.isLocked = [:]
        self.searchedFor = []
    }

    static func generateName(for type: RoomType) -> String {
        let adjectives = ["Dark", "Dusty", "Ancient", "Forgotten", "Crumbling", "Moss-covered", "Damp", "Cold", "Shadowy", "Torchlit"]
        let adj = adjectives.randomElement()!

        switch type {
        case .entrance:
            return "Dungeon Entrance"
        case .corridor:
            return "\(adj) Corridor"
        case .chamber:
            return "\(adj) Chamber"
        case .treasure:
            return "\(adj) Treasury"
        case .trap:
            return "\(adj) Hall"
        case .boss:
            return "The Inner Sanctum"
        case .shrine:
            return "\(adj) Shrine"
        case .library:
            return "\(adj) Library"
        case .armory:
            return "\(adj) Armory"
        case .prison:
            return "\(adj) Prison"
        case .empty:
            return "\(adj) Room"
        }
    }

    func describe() -> String {
        var desc = "\(name)\n\n\(roomType.description)"

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

class Dungeon: ObservableObject {
    let name: String
    let level: Int
    @Published var rooms: [Int: Room]
    @Published var currentRoomId: Int

    var currentRoom: Room? {
        rooms[currentRoomId]
    }

    init(name: String, level: Int) {
        self.name = name
        self.level = level
        self.rooms = [:]
        self.currentRoomId = 0

        generateDungeon()
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
                        } else if Bool.random() && roomType != .empty {
                            newRoom.encounter = Encounter.generate(level: level, difficulty: .medium)
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

        let mapWidth = (maxX - minX + 1) * 6 + 3
        let border = String(repeating: "═", count: max(mapWidth, 20))
        lines.append("╔\(border)╗")
        lines.append("║ DUNGEON MAP".padding(toLength: border.count + 1, withPad: " ", startingAt: 0) + "║")
        lines.append("╠\(border)╣")

        for y in minY...maxY {
            // Room row
            var roomRow = "║ "
            // Vertical corridor row (below this room row)
            var corridorRow = "║ "

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

            roomRow = roomRow.padding(toLength: border.count + 1, withPad: " ", startingAt: 0) + "║"
            lines.append(roomRow)

            // Only add corridor row if not the last row
            if y < maxY {
                corridorRow = corridorRow.padding(toLength: border.count + 1, withPad: " ", startingAt: 0) + "║"
                lines.append(corridorRow)
            }
        }

        lines.append("╠\(border)╣")
        lines.append("║ @ You  E Entry  B Boss  ! Enemy".padding(toLength: border.count + 1, withPad: " ", startingAt: 0) + "║")
        lines.append("╚\(border)╝")

        return lines
    }
}

// MARK: - Treasure

struct TreasureItem {
    let name: String
    let value: Int  // Gold value
    let type: TreasureType

    enum TreasureType {
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
