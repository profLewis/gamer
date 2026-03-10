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
    case armory = "Armoury"
    case prison = "Prison"
    case shop = "Shop"
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
                "An ancient shrine stands in the centre, its stone basin filled with clear water that seems to glow faintly.",
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
                "Weapon racks and armour stands fill this room. Most have been picked clean, but some items remain.",
                "Swords, shields, and helms line the walls. A forge in the corner is cold but could be relit. A merchant has set up shop here.",
                "Rows of rusted weapons stand at attention like silent soldiers. A workbench holds tools for repair and sharpening.",
            ].randomElement()!
        case .prison:
            return [
                "Iron bars and chains line the walls. Names and tallies are scratched into the stone — someone counted the days here.",
                "Rows of cells stretch into the darkness. A skeletal hand reaches through the bars of one, frozen in its last plea.",
                "The stench of old straw and despair clings to this place. Manacles hang open on the walls, their prisoners long gone.",
            ].randomElement()!
        case .shop:
            return [
                "A cluttered merchant's stall fills the alcove, lanterns casting warm light on stacked crates and hanging wares.",
                "Shelves of potions, weapons, and curious trinkets line the walls. A merchant beckons you closer with a grin.",
                "A travelling trader has set up shop here, their cart overflowing with supplies. The clink of coin fills the air.",
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
        case .shop: return "S"
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
    @Published var trapTriggered: Bool
    @Published var hiddenItems: [Item]      // Items discoverable by searching (thematic per room type)
    @Published var hiddenGold: Int           // Gold discoverable by searching
    @Published var droppedItems: [Item]     // Items left behind by the party
    @Published var npc: DungeonNPC?         // NPC present in this room
    @Published var secured: Set<Direction>  // Barred/secured exits

    enum CodingKeys: String, CodingKey {
        case id, x, y, roomType, name, roomDescription, exits, visited, cleared
        case encounter, treasure, isLocked, searchedFor, trapTriggered
        case hiddenItems, hiddenGold, droppedItems, npc, secured
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
        self.trapTriggered = false
        self.hiddenItems = []
        self.hiddenGold = 0
        self.droppedItems = []
        self.npc = nil
        self.secured = []
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
        trapTriggered = try container.decodeIfPresent(Bool.self, forKey: .trapTriggered) ?? false
        hiddenItems = try container.decodeIfPresent([Item].self, forKey: .hiddenItems) ?? []
        hiddenGold = try container.decodeIfPresent(Int.self, forKey: .hiddenGold) ?? 0
        droppedItems = try container.decodeIfPresent([Item].self, forKey: .droppedItems) ?? []
        npc = try container.decodeIfPresent(DungeonNPC.self, forKey: .npc)
        secured = try container.decodeIfPresent(Set<Direction>.self, forKey: .secured) ?? []
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
        try container.encode(trapTriggered, forKey: .trapTriggered)
        try container.encode(hiddenItems, forKey: .hiddenItems)
        try container.encode(hiddenGold, forKey: .hiddenGold)
        try container.encode(droppedItems, forKey: .droppedItems)
        try container.encodeIfPresent(npc, forKey: .npc)
        try container.encode(secured, forKey: .secured)
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
                "Rusted Armoury", "Weapon Hall", "Iron Forge",
                "Quartermaster's Store", "Blade-Lined Chamber",
            ].randomElement()!
        case .prison:
            return [
                "The Iron Cells", "Abandoned Dungeon", "Bone-Strewn Prison",
                "The Oubliette", "Shackled Chamber",
            ].randomElement()!
        case .shop:
            return [
                "Merchant's Corner", "Trading Post", "Dusty Bazaar",
                "Wanderer's Wares", "The Trinket Cart",
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

    /// Generate thematic hidden items and gold for a room based on its type and dungeon level
    static func generateHiddenLoot(roomType: RoomType, level: Int) -> (items: [Item], gold: Int) {
        var items: [Item] = []
        var gold = 0

        switch roomType {
        case .armory:
            // Armory — weapons and armor, scaled by level
            let pool: [() -> Item]
            if level >= 3 {
                pool = [ItemCatalog.longsword, ItemCatalog.rapier, ItemCatalog.scaleMail,
                        ItemCatalog.studdedLeather, ItemCatalog.shield, ItemCatalog.handaxe]
            } else if level >= 2 {
                pool = [ItemCatalog.shortsword, ItemCatalog.longsword, ItemCatalog.leatherArmor,
                        ItemCatalog.shield, ItemCatalog.mace, ItemCatalog.handaxe]
            } else {
                pool = [ItemCatalog.dagger, ItemCatalog.shortsword, ItemCatalog.leatherArmor,
                        ItemCatalog.shield, ItemCatalog.handaxe, ItemCatalog.mace]
            }
            // 1-2 items
            let count = Dice.d4() >= 3 ? 2 : 1
            for _ in 0..<count {
                items.append(pool.randomElement()!())
            }
            gold = Dice.rollSum(1, d: 6) * 5

        case .library:
            // Library — scholarly items, spell components, occasional potion
            let pool: [() -> Item] = level >= 2
                ? [ItemCatalog.spellComponentPouch, ItemCatalog.holySymbol,
                   ItemCatalog.healingPotion, ItemCatalog.torch]
                : [ItemCatalog.spellComponentPouch, ItemCatalog.holySymbol, ItemCatalog.torch]
            items.append(pool.randomElement()!())
            if Dice.d6() >= 5 { items.append(pool.randomElement()!()) }

        case .shrine:
            // Shrine — healing items, holy relics
            if level >= 3 {
                items.append(ItemCatalog.greaterHealingPotion())
            } else {
                items.append(ItemCatalog.healingPotion())
            }
            if Dice.d6() >= 4 { items.append(ItemCatalog.holySymbol()) }

        case .prison:
            // Prison — makeshift weapons, escape tools
            let pool: [() -> Item] = [ItemCatalog.dagger, ItemCatalog.rope,
                                       ItemCatalog.torch, ItemCatalog.thievesTools]
            items.append(pool.randomElement()!())
            if Dice.d6() >= 5 { items.append(pool.randomElement()!()) }
            gold = Dice.d6() >= 4 ? Dice.rollSum(1, d: 6) * 3 : 0

        case .treasure:
            // Treasure rooms already have treasure array — add a bonus hidden item
            if level >= 3 && Dice.d6() >= 3 {
                items.append([ItemCatalog.greaterHealingPotion, ItemCatalog.rapier,
                              ItemCatalog.studdedLeather].randomElement()!())
            } else if Dice.d6() >= 3 {
                items.append([ItemCatalog.healingPotion, ItemCatalog.dagger,
                              ItemCatalog.shield].randomElement()!())
            }

        case .chamber:
            // Chamber — small chance of minor items
            if Dice.d6() >= 5 {
                items.append([ItemCatalog.torch, ItemCatalog.rope, ItemCatalog.dagger].randomElement()!())
            }
            if Dice.d6() >= 5 { gold = Dice.rollSum(1, d: 6) * 3 }

        case .trap:
            // Trap rooms — rare finds, tools
            if Dice.d6() >= 5 {
                items.append([ItemCatalog.thievesTools, ItemCatalog.dagger].randomElement()!())
            }

        case .corridor:
            // Corridor — very rare minor finds
            if Dice.d8() >= 7 {
                items.append([ItemCatalog.torch, ItemCatalog.rope].randomElement()!())
            }

        case .entrance, .boss, .shop, .empty:
            // No hidden loot
            break
        }

        return (items, gold)
    }
}

// MARK: - Dungeon

class Dungeon: ObservableObject, Codable {
    let name: String
    let level: Int
    @Published var rooms: [Int: Room]
    @Published var currentRoomId: Int
    @Published var previousRoomId: Int?

    var currentRoom: Room? {
        get { rooms[currentRoomId] }
        set {
            if let room = newValue {
                previousRoomId = currentRoomId
                currentRoomId = room.id
            }
        }
    }

    var previousRoom: Room? {
        guard let prevId = previousRoomId else { return nil }
        return rooms[prevId]
    }

    enum CodingKeys: String, CodingKey {
        case name, level, rooms, currentRoomId, previousRoomId, nextRoomId
    }

    init(name: String, level: Int) {
        self.name = name
        self.level = level
        self.rooms = [:]
        self.currentRoomId = 0
        self.previousRoomId = nil

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
        previousRoomId = try? container.decodeIfPresent(Int.self, forKey: .previousRoomId)
        nextRoomId = try container.decodeIfPresent(Int.self, forKey: .nextRoomId)
            ?? (roomsDict.keys.max().map { $0 + 1 } ?? 0)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(level, forKey: .level)
        let roomsArray = Array(rooms.values).sorted { $0.id < $1.id }
        try container.encode(roomsArray, forKey: .rooms)
        try container.encode(currentRoomId, forKey: .currentRoomId)
        try container.encodeIfPresent(previousRoomId, forKey: .previousRoomId)
        try container.encode(nextRoomId, forKey: .nextRoomId)
    }

    /// Next room ID for dynamic expansion
    private var nextRoomId: Int = 0

    private func generateDungeon() {
        let numRooms = 20 + level * 5

        // Create entrance
        let entrance = Room(id: 0, x: 0, y: 0, type: .entrance)
        entrance.visited = true
        rooms[0] = entrance

        var roomId = 1
        var frontier: [(Int, Int)] = [(0, 0)]
        var occupied: Set<String> = ["0,0"]

        // Track the farthest room from entrance for boss placement
        var farthestId = 0
        var farthestDist = 0

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

                    let roomType: RoomType = randomRoomType()
                    let newRoom = Room(id: roomId, x: newX, y: newY, type: roomType)

                    // Connect rooms
                    let fromRoom = rooms.values.first { $0.x == x && $0.y == y }!
                    fromRoom.exits[direction] = roomId
                    newRoom.exits[direction.opposite] = fromRoom.id

                    // Add encounter based on room type
                    if roomType != .entrance && roomType != .shrine {
                        if roomType != .empty {
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

                    // Add thematic hidden items based on room type
                    let hiddenLoot = Room.generateHiddenLoot(roomType: roomType, level: level)
                    newRoom.hiddenItems = hiddenLoot.items
                    newRoom.hiddenGold = hiddenLoot.gold

                    rooms[roomId] = newRoom
                    frontier.append((newX, newY))

                    // Track farthest room for boss
                    let dist = abs(newX) + abs(newY)
                    if dist > farthestDist {
                        farthestDist = dist
                        farthestId = roomId
                    }

                    roomId += 1
                }
            }

            // Remove from frontier if no more directions
            frontier.removeAll { $0.0 == x && $0.1 == y }
        }

        // Place boss in the farthest room from entrance
        if let bossRoom = rooms[farthestId], bossRoom.roomType != .entrance {
            bossRoom.roomType = .boss
            bossRoom.name = Room.generateName(for: .boss)
            bossRoom.roomDescription = RoomType.boss.description
            bossRoom.encounter = Encounter.generateBoss(level: level)
            bossRoom.treasure = []
            bossRoom.hiddenItems = []
            bossRoom.hiddenGold = 0
        }

        // Place exactly one shop room — pick a non-entrance, non-boss room roughly mid-dungeon
        let candidates = rooms.values
            .filter { $0.roomType != .entrance && $0.roomType != .boss }
            .sorted { (abs($0.x) + abs($0.y)) < (abs($1.x) + abs($1.y)) }
        let midIndex = candidates.count / 2
        let shopRange = max(0, midIndex - 2)...min(candidates.count - 1, midIndex + 2)
        if let shopRoom = candidates[shopRange].randomElement() {
            shopRoom.roomType = .shop
            shopRoom.name = Room.generateName(for: .shop)
            shopRoom.roomDescription = RoomType.shop.description
            shopRoom.encounter = nil
            shopRoom.hiddenItems = []
            shopRoom.hiddenGold = 0
        }

        // Spawn NPCs in ~30-40% of non-boss, non-entrance rooms (max 6)
        let npcCandidates = rooms.values.filter {
            $0.roomType != .entrance && $0.roomType != .boss && $0.encounter == nil
        }.shuffled()
        let maxNPCs = min(6, max(2, npcCandidates.count / 3))
        var npcCount = 0
        for room in npcCandidates where npcCount < maxNPCs {
            if let npcType = NPCType.randomFor(roomType: room.roomType) {
                room.npc = DungeonNPC(type: npcType)
                npcCount += 1
            }
        }

        // Place Gatekeeper at entrance
        if let entrance = rooms[0] {
            var gatekeeper = DungeonNPC(type: .gatekeeper)
            gatekeeper.trustworthiness = .random()
            gatekeeper.questGold = 50 * level
            entrance.npc = gatekeeper
        }

        nextRoomId = roomId
    }

    // MARK: - Dynamic Dungeon Expansion

    /// Expand the dungeon by adding new rooms around the given room.
    /// Called when the player enters a room near the edge of the map.
    func expandIfNeeded(from room: Room) {
        // Only expand from rooms that have open adjacent cells
        let occupied = Set(rooms.values.map { "\($0.x),\($0.y)" })

        for direction in Direction.allCases.shuffled() {
            // Skip directions that already have exits
            if room.exits[direction] != nil { continue }

            let newX = room.x + direction.offset.x
            let newY = room.y + direction.offset.y
            let key = "\(newX),\(newY)"

            // Skip if something already occupies that cell
            if occupied.contains(key) { continue }

            // 60% chance to generate a new room in each open direction
            guard Dice.d100() <= 60 else { continue }

            let roomType = randomRoomType()
            let newRoom = Room(id: nextRoomId, x: newX, y: newY, type: roomType)

            // Connect
            room.exits[direction] = nextRoomId
            newRoom.exits[direction.opposite] = room.id

            // Encounter
            if roomType != .entrance && roomType != .shrine && roomType != .shop && roomType != .empty {
                let encounterChance = level == 1 ? 0.35 : 0.5
                let diff: EncounterDifficulty = level == 1 ? .easy : .medium
                if Double.random(in: 0...1) < encounterChance {
                    newRoom.encounter = Encounter.generate(level: level, difficulty: diff)
                }
            }

            // Treasure
            if roomType == .treasure {
                newRoom.treasure = TreasureItem.generateTreasure(level: level)
            }

            // Hidden loot
            let hiddenLoot = Room.generateHiddenLoot(roomType: roomType, level: level)
            newRoom.hiddenItems = hiddenLoot.items
            newRoom.hiddenGold = hiddenLoot.gold

            rooms[nextRoomId] = newRoom
            nextRoomId += 1
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
            guard room.roomType != .entrance && room.roomType != .shrine && room.roomType != .shop else { continue }

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

        previousRoomId = currentRoomId
        currentRoomId = nextRoomId
        nextRoom.visited = true

        // Expand the dungeon around the new room
        expandIfNeeded(from: nextRoom)

        return (true, "You move \(direction.rawValue).\n\n\(nextRoom.describe())")
    }

    /// Calculate how many terminal lines a map with the given radius will produce
    func mapLineCount(visibilityRadius: Int, torchLit: Bool, compact: Bool = false, verticalRadius: Int? = nil) -> Int {
        let vRadius = verticalRadius ?? visibilityRadius
        if !torchLit {
            // Top border + header + separator + 3 rows + bottom border = 7, or 5 compact
            return compact ? 5 : 7
        }
        let headerLines = compact ? 1 : 3  // just top border (compact) vs top + MAP + separator
        let gridLines = (2 * vRadius + 1) + (2 * vRadius)  // room rows + corridor rows
        let legendLines = compact ? 1 : 4  // compact: just bottom border; full: separator + ~2 legend rows + bottom border
        return headerLines + gridLines + legendLines
    }

    func getMapDisplay(visibilityRadius: Int = 3, torchLit: Bool = true, compact: Bool = false, verticalRadius: Int? = nil) -> [String] {
        guard let current = rooms[currentRoomId] else { return ["No map available."] }

        // Torch off: show only [@] with no direction info — you can't see the passages
        if !torchLit {
            let border = String(repeating: "-", count: 26)
            let emptyRow = "|".padding(toLength: 28, withPad: " ", startingAt: 0) + "|"
            let centerRow = "|      [@]".padding(toLength: 28, withPad: " ", startingAt: 0) + "|"

            var lines: [String] = []
            lines.append("+\(border)+")
            if !compact {
                lines.append("| MAP".padding(toLength: 27, withPad: " ", startingAt: 0) + "|")
                lines.append("+\(border)+")
            }
            lines.append(emptyRow)
            lines.append(centerRow)
            lines.append(emptyRow)
            lines.append("+\(border)+")
            return lines
        }

        // Viewport centered on current room (may be non-square)
        let vRadius = verticalRadius ?? visibilityRadius
        let viewMinX = current.x - visibilityRadius
        let viewMaxX = current.x + visibilityRadius
        let viewMinY = current.y - vRadius
        let viewMaxY = current.y + vRadius

        // Only show visited rooms within the viewport
        let visibleRooms = rooms.values.filter {
            $0.visited && $0.x >= viewMinX && $0.x <= viewMaxX && $0.y >= viewMinY && $0.y <= viewMaxY
        }
        guard !visibleRooms.isEmpty else { return ["No map available."] }

        // Build a grid with rooms and corridors between them
        // Each room cell is 5 chars wide, corridor rows are 1 char tall
        var lines: [String] = []

        let mapWidth = min((viewMaxX - viewMinX + 1) * 5 + 3, 40)
        let border = String(repeating: "-", count: max(mapWidth, 26))
        lines.append("+\(border)+")
        if !compact {
            lines.append("| MAP".padding(toLength: border.count + 1, withPad: " ", startingAt: 0) + "|")
            lines.append("+\(border)+")
        }

        for y in viewMinY...viewMaxY {
            // Room row
            var roomRow = "| "
            // Vertical corridor row (below this room row)
            var corridorRow = "| "

            for x in viewMinX...viewMaxX {
                if let room = visibleRooms.first(where: { $0.x == x && $0.y == y }) {
                    if room.id == currentRoomId {
                        roomRow += "[@]"
                    } else if !room.cleared && room.encounter != nil {
                        roomRow += "[!]"
                    } else if room.npc != nil && !(room.npc?.hasBeenTalkedTo ?? true) {
                        roomRow += "[?]"
                    } else {
                        roomRow += "[\(room.roomType.symbol)]"
                    }

                    // East corridor (XX = secured/barred from either side)
                    if let eastId = room.exits[.east] {
                        let eastRoom = rooms[eastId]
                        let barred = room.secured.contains(.east) || (eastRoom?.secured.contains(.west) ?? false)
                        roomRow += barred ? "XX" : "--"
                    } else {
                        roomRow += "  "
                    }

                    // South corridor (X = secured/barred from either side)
                    if let southId = room.exits[.south] {
                        let southRoom = rooms[southId]
                        let barred = room.secured.contains(.south) || (southRoom?.secured.contains(.north) ?? false)
                        corridorRow += barred ? " X   " : " |   "
                    } else {
                        corridorRow += "     "
                    }
                } else {
                    roomRow += "     "
                    corridorRow += "     "
                }
            }

            roomRow = roomRow.padding(toLength: border.count + 1, withPad: " ", startingAt: 0) + "|"
            lines.append(roomRow)

            // Only add corridor row if not the last row
            if y < viewMaxY {
                corridorRow = corridorRow.padding(toLength: border.count + 1, withPad: " ", startingAt: 0) + "|"
                lines.append(corridorRow)
            }
        }

        // Build key from symbols actually visible on the map
        var visibleSymbols = Set<String>()
        visibleSymbols.insert("@") // current room is always shown
        for room in visibleRooms {
            if room.id == currentRoomId {
                // already added @
            } else if !room.cleared && room.encounter != nil {
                visibleSymbols.insert("!")
            } else {
                visibleSymbols.insert(room.roomType.symbol)
            }
            visibleSymbols.insert(room.roomType.symbol)
        }

        // Check if any secured doors are visible
        if visibleRooms.contains(where: { !$0.secured.isEmpty }) {
            visibleSymbols.insert("X")
        }

        let allKeyEntries: [(symbol: String, label: String)] = [
            ("@", "You"), ("!", "Danger"), (".", "Empty"),
            ("E", "Entry"), ("=", "Hall"), ("#", "Room"),
            ("$", "Loot"), ("+", "Shrine"), ("L", "Library"),
            ("B", "Boss"), ("A", "Armoury"), ("P", "Prison"),
            ("S", "Shop"), ("X", "Secured")
        ]
        let activeEntries = allKeyEntries.filter { visibleSymbols.contains($0.symbol) }

        if !compact && !activeEntries.isEmpty {
            lines.append("+\(border)+")
            // Pack entries into rows, ~3 per line
            var row = ""
            for (i, entry) in activeEntries.enumerated() {
                let item = "\(entry.symbol)=\(entry.label)"
                if row.isEmpty {
                    row = item
                } else {
                    row += "  \(item)"
                }
                if (i + 1) % 3 == 0 || i == activeEntries.count - 1 {
                    let keyLine = "| \(row)".padding(toLength: border.count + 1, withPad: " ", startingAt: 0) + "|"
                    lines.append(keyLine)
                    row = ""
                }
            }
        }
        lines.append("+\(border)+")

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

        // Maybe an equipment item (higher chance at higher levels)
        if Dice.d20() >= (level >= 2 ? 14 : 17) {
            let itemPool: [(String, Int)]
            if level >= 3 {
                itemPool = [("Longsword", 15), ("Rapier", 25), ("Scale Mail", 50),
                            ("Studded Leather", 45), ("Shield", 10), ("Longbow", 50),
                            ("Potion of Greater Healing", 150)]
            } else if level >= 2 {
                itemPool = [("Shortsword", 10), ("Longsword", 15), ("Leather Armour", 10),
                            ("Shield", 10), ("Dagger", 2), ("Mace", 5)]
            } else {
                itemPool = [("Dagger", 2), ("Shortsword", 10), ("Leather Armour", 10),
                            ("Shield", 10), ("Torch", 1), ("Rope", 1)]
            }
            let pick = itemPool.randomElement()!
            items.append(TreasureItem(name: pick.0, value: pick.1, type: .item))
        }

        return items
    }
}
