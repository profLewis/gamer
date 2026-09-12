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
    /// Names of monsters defeated here, captured right before the fight's
    /// Encounter is cleared — lets a revisit describe the aftermath (e.g.
    /// "2 dead zombies") instead of the room looking like nothing happened.
    /// Cleared again if a fresh encounter is ever placed here (e.g. a future
    /// "monsters wander in" respawn), so a description never lingers past
    /// the point it's no longer accurate.
    @Published var defeatedMonsterNames: [String] = []
    /// Zombies specifically: names of defeated zombies whose killing blow
    /// didn't happen to finish them for good (see handleCombatVictory's
    /// zombie-destruction roll) — they can claw back up on a later visit
    /// unless the party goes out of its way to destroy them properly.
    /// Cleared once a fresh encounter is placed here (respawned, or the
    /// room is otherwise repopulated) so it never lingers past relevance.
    @Published var respawnEligibleMonsterNames: [String] = []
    @Published var npc: DungeonNPC?         // NPC present in this room
    @Published var secured: Set<Direction>  // Barred/secured exits
    @Published var merchant: Merchant?      // Shopkeeper present in this room (shop/armoury rooms)
    @Published var riddleIndex: Int?        // Index into RiddleData.all, nil = no riddle challenge here
    @Published var riddleResolved: Bool = false  // Solved OR given up on (button hidden either way)
    @Published var trainer: Trainer?        // Training gym present in this room
    /// Doors with a lock mechanism — direction → a lock id shared by both
    /// rooms on either side of that door. This entry is permanent (the lock
    /// mechanism doesn't disappear once picked); whether it's currently open
    /// is tracked separately in openedLocks, so a door unlocked with a key
    /// can be locked again later. A key's Item.keyForDoorId matching this id
    /// opens it. Persists as part of the room, so state survives leaving and
    /// returning.
    @Published var doorLockIds: [Direction: UUID] = [:]
    /// Which locked doors (see doorLockIds) are currently open.
    @Published var openedLocks: Set<Direction> = []
    /// If set, this room has a teleport pad leading to the room with this
    /// id. Set on both rooms of a pair for a bidirectional pad, or on just
    /// one for a one-way pad. See Dungeon.generateDungeon()'s teleport-pad
    /// placement.
    @Published var teleportDestinationRoomId: Int? = nil
    /// If set, this room connects to another floor via the room with this
    /// id, using verticalMethod. Mirrors teleportDestinationRoomId's
    /// same-room-pair pattern. See Dungeon.generateDungeon()'s vertical-
    /// connection placement.
    @Published var verticalDestinationRoomId: Int? = nil
    /// "stairs" (free, always works), "rope" (needs a Rope item carried),
    /// or "levitation" (needs an available spell slot). nil if no vertical
    /// connection here.
    @Published var verticalMethod: String? = nil
    /// "up" or "down" — which way this room's vertical connection goes, from
    /// this room's own perspective. nil if no vertical connection here. The
    /// paired room at verticalDestinationRoomId always gets the opposite
    /// direction, so travelling it and coming back flips consistently.
    @Published var verticalDirection: String? = nil
    /// For a "rope" verticalMethod only — the name of the room a Rope item
    /// was guaranteed-placed in when this connection was generated, so a
    /// party without one can be told exactly where to look instead of just
    /// "you need a rope". nil for stairs (needs nothing) and for any older
    /// save predating this hint.
    @Published var verticalRopeHintRoomName: String? = nil
    /// Wall-mounted torches keep this passage lit on their own — its
    /// description, exits, and contents are visible even with no torch of
    /// your own (see GameEngine's roomIsLit), and searching it always
    /// turns up spare torches to take. Only ever set on .corridor rooms
    /// (see Dungeon.generateDungeon()'s room creation).
    @Published var isTorchlit: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, x, y, roomType, name, roomDescription, exits, visited, cleared
        case encounter, treasure, isLocked, searchedFor, trapTriggered
        case hiddenItems, hiddenGold, droppedItems, npc, secured, merchant, trainer
        case defeatedMonsterNames, respawnEligibleMonsterNames
        case riddleIndex, riddleResolved, doorLockIds, openedLocks
        case teleportDestinationRoomId
        case verticalDestinationRoomId, verticalMethod, verticalDirection, verticalRopeHintRoomName
        case isTorchlit
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
        self.defeatedMonsterNames = []
        self.respawnEligibleMonsterNames = []
        self.npc = nil
        self.secured = []
        self.merchant = nil
        self.riddleIndex = nil
        self.riddleResolved = false
        self.trainer = nil
        self.doorLockIds = [:]
        self.openedLocks = []
        self.teleportDestinationRoomId = nil
        self.verticalDestinationRoomId = nil
        self.verticalMethod = nil
        self.verticalDirection = nil
        self.verticalRopeHintRoomName = nil
        self.isTorchlit = false
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
        defeatedMonsterNames = try container.decodeIfPresent([String].self, forKey: .defeatedMonsterNames) ?? []
        respawnEligibleMonsterNames = try container.decodeIfPresent([String].self, forKey: .respawnEligibleMonsterNames) ?? []
        npc = try container.decodeIfPresent(DungeonNPC.self, forKey: .npc)
        secured = try container.decodeIfPresent(Set<Direction>.self, forKey: .secured) ?? []
        merchant = try container.decodeIfPresent(Merchant.self, forKey: .merchant)
        riddleIndex = try container.decodeIfPresent(Int.self, forKey: .riddleIndex)
        riddleResolved = try container.decodeIfPresent(Bool.self, forKey: .riddleResolved) ?? false
        trainer = try container.decodeIfPresent(Trainer.self, forKey: .trainer)
        doorLockIds = try container.decodeIfPresent([Direction: UUID].self, forKey: .doorLockIds) ?? [:]
        openedLocks = try container.decodeIfPresent(Set<Direction>.self, forKey: .openedLocks) ?? []
        teleportDestinationRoomId = try container.decodeIfPresent(Int.self, forKey: .teleportDestinationRoomId)
        verticalDestinationRoomId = try container.decodeIfPresent(Int.self, forKey: .verticalDestinationRoomId)
        verticalMethod = try container.decodeIfPresent(String.self, forKey: .verticalMethod)
        verticalDirection = try container.decodeIfPresent(String.self, forKey: .verticalDirection)
        verticalRopeHintRoomName = try container.decodeIfPresent(String.self, forKey: .verticalRopeHintRoomName)
        isTorchlit = try container.decodeIfPresent(Bool.self, forKey: .isTorchlit) ?? false
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
        try container.encode(defeatedMonsterNames, forKey: .defeatedMonsterNames)
        try container.encode(respawnEligibleMonsterNames, forKey: .respawnEligibleMonsterNames)
        try container.encodeIfPresent(npc, forKey: .npc)
        try container.encode(secured, forKey: .secured)
        try container.encodeIfPresent(merchant, forKey: .merchant)
        try container.encodeIfPresent(riddleIndex, forKey: .riddleIndex)
        try container.encode(riddleResolved, forKey: .riddleResolved)
        try container.encodeIfPresent(trainer, forKey: .trainer)
        try container.encode(doorLockIds, forKey: .doorLockIds)
        try container.encode(openedLocks, forKey: .openedLocks)
        try container.encodeIfPresent(teleportDestinationRoomId, forKey: .teleportDestinationRoomId)
        try container.encodeIfPresent(verticalDestinationRoomId, forKey: .verticalDestinationRoomId)
        try container.encodeIfPresent(verticalMethod, forKey: .verticalMethod)
        try container.encodeIfPresent(verticalDirection, forKey: .verticalDirection)
        try container.encodeIfPresent(verticalRopeHintRoomName, forKey: .verticalRopeHintRoomName)
        try container.encode(isTorchlit, forKey: .isTorchlit)
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

    /// True if this exit has a lock mechanism and it's currently shut.
    func isLockedShut(_ direction: Direction) -> Bool {
        doorLockIds[direction] != nil && !openedLocks.contains(direction)
    }

    func describe() -> String {
        var desc = "\(name)\n\n\(roomDescription)"

        if !cleared && encounter != nil {
            desc += "\n\nYou sense danger here..."
        }

        if !treasure.isEmpty && cleared {
            desc += "\n\nYou see treasure on the ground."
        }

        let exitList = exits.keys.map { isLockedShut($0) ? "\($0.rawValue) (locked)" : $0.rawValue }.joined(separator: ", ")
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
            // Corridor — very rare minor finds, occasionally a dropped purse
            if Dice.d8() >= 7 {
                items.append([ItemCatalog.torch, ItemCatalog.rope].randomElement()!())
            }
            if Dice.d8() >= 7 { gold = Dice.rollSum(1, d: 4) * 3 }

        case .empty:
            // Empty rooms are otherwise featureless, but someone may have
            // dropped a purse in a hurry.
            if Dice.d10() >= 8 { gold = Dice.rollSum(1, d: 6) * 2 }

        case .entrance, .boss, .shop:
            // No hidden loot
            break
        }

        return (items, gold)
    }

    /// About 30% of corridors have wall-mounted torches that keep them lit
    /// on their own — see the isTorchlit property. Corridors already have a
    /// small independent chance of a torch as ordinary loot
    /// (generateHiddenLoot); a torchlit one gets a couple more guaranteed
    /// ones on top, since "there are lit torches here" should mean you can
    /// actually take one, not just that the room looks nice.
    static func rollIsTorchlit(roomType: RoomType) -> Bool {
        roomType == .corridor && Int.random(in: 1...100) <= 30
    }

    static func torchlitBonusItems() -> [Item] {
        (0..<Int.random(in: 1...2)).map { _ in ItemCatalog.torch() }
    }
}

// MARK: - Dungeon

class Dungeon: ObservableObject, Codable {
    let name: String
    let level: Int
    @Published var rooms: [Int: Room]
    @Published var currentRoomId: Int
    @Published var previousRoomId: Int?
    /// Which floor the party is currently on via vertical connections
    /// (stairs/rope/levitation) — distinct from `level` (the difficulty
    /// tier). All rooms live in the same flat `rooms` dictionary regardless
    /// of floor; this is purely a display counter so "Descend the Stairs"
    /// actually shows a floor number changing, rather than implying a
    /// second level that never appears anywhere on screen.
    @Published var currentFloor: Int = 1

    /// True if this dungeon has at least one stairs/rope/levitation link.
    var hasVerticalConnections: Bool {
        rooms.values.contains { $0.verticalDestinationRoomId != nil }
    }

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
        case name, level, rooms, currentRoomId, previousRoomId, nextRoomId, currentFloor
    }

    init(name: String, level: Int) {
        self.name = name
        self.level = level
        self.rooms = [:]
        self.currentRoomId = 0
        self.previousRoomId = nil
        self.currentFloor = 1

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
        currentFloor = try container.decodeIfPresent(Int.self, forKey: .currentFloor) ?? 1
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
        try container.encode(currentFloor, forKey: .currentFloor)
    }

    /// Next room ID for dynamic expansion
    private var nextRoomId: Int = 0

    /// Chance a given non-special room gets a monster encounter, scaled by
    /// dungeon level. Used to be a single step (0.35 at level 1, 0.5 at every
    /// level after) — Medium difficulty starts at level 2, so it immediately
    /// hit the same monster density as much deeper levels while merchants
    /// stayed rare (one guaranteed shop room, occasional armoury). Ramping
    /// gradually keeps Medium noticeably lighter than Hard/Brutal.
    private var encounterChance: Double {
        level <= 1 ? 0.28 : min(0.42, 0.28 + Double(level - 2) * 0.05)
    }

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
                    newRoom.isTorchlit = Room.rollIsTorchlit(roomType: roomType)
                    if newRoom.isTorchlit {
                        newRoom.hiddenItems.append(contentsOf: Room.torchlitBonusItems())
                    }

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

        // Place shop rooms — one per ~15 rooms in the dungeon (was a hard-coded
        // single shop regardless of dungeon size, which felt sparse next to how
        // many rooms carry a monster encounter). The first shop keeps the
        // original placement (roughly mid-dungeon); any extra shops are spread
        // across the rest of the dungeon.
        var candidates = rooms.values
            .filter { $0.roomType != .entrance && $0.roomType != .boss }
            .sorted { (abs($0.x) + abs($0.y)) < (abs($1.x) + abs($1.y)) }
        // Settings toggle (GameEngine.multipleShopsEnabled) — read the same
        // UserDefaults key directly since Dungeon doesn't hold a reference
        // to GameEngine. Off forces exactly one shop regardless of size.
        let multipleShopsEnabled = UserDefaults.standard.object(forKey: "multiple_shops_enabled") == nil
            || UserDefaults.standard.bool(forKey: "multiple_shops_enabled")
        let numShops = multipleShopsEnabled ? max(1, numRooms / 10) : 1
        for shopIndex in 0..<numShops {
            guard !candidates.isEmpty else { break }
            let shopRoom: Room
            if shopIndex == 0 {
                let midIndex = candidates.count / 2
                let shopRange = max(0, midIndex - 2)...min(candidates.count - 1, midIndex + 2)
                shopRoom = candidates[shopRange].randomElement()!
            } else {
                shopRoom = candidates.randomElement()!
            }
            shopRoom.roomType = .shop
            shopRoom.name = Room.generateName(for: .shop)
            shopRoom.roomDescription = RoomType.shop.description
            shopRoom.encounter = nil
            shopRoom.hiddenItems = []
            shopRoom.hiddenGold = 0
            shopRoom.merchant = Merchant.random(tier: MerchantTier.forDungeonLevel(level))
            candidates.removeAll { $0.id == shopRoom.id }
        }

        // Armoury rooms (forges included — same room type) always double as
        // a merchant shop now, same as a dedicated .shop room, rather than
        // just sometimes — matches the "a merchant has set up shop here"
        // flavour text, which used to only sometimes be true.
        let armouryMerchantVariant = "Swords, shields, and helms line the walls. A forge in the corner is cold but could be relit. A merchant has set up shop here."
        for armouryRoom in rooms.values where armouryRoom.roomType == .armory {
            armouryRoom.merchant = Merchant.random(tier: MerchantTier.forDungeonLevel(level))
            armouryRoom.roomDescription = armouryMerchantVariant
            // A merchant here must actually be reachable — the "Visit
            // Merchant" button stays hidden behind an uncleared encounter
            // (see showExplorationView()'s gating), so an armoury that says
            // a merchant has set up shop can't also be guarded by a monster
            // the room-type roll may have already assigned before this pass ran.
            armouryRoom.encounter = nil
            // The flavour text names a merchant — give it an actual face:
            // the Dwarven Smith is the only NPC type that prefers armouries,
            // so this guarantees "Ask to Trade" has someone to ask.
            armouryRoom.npc = DungeonNPC(type: .dwarvenSmith)
        }

        // Riddle challenges — libraries and shrines occasionally pose one,
        // offering a bonus reward for a correct answer.
        for room in rooms.values where room.roomType == .library || room.roomType == .shrine {
            if Int.random(in: 1...100) <= 35 {
                room.riddleIndex = RiddleData.nextIndex()
            }
        }

        // Training gyms — a chance in chamber rooms, offering to teach a new
        // skill proficiency for a fee or by winning a sparring check.
        let chamberRooms = rooms.values.filter { $0.roomType == .chamber && $0.encounter == nil }
        for room in chamberRooms {
            if Int.random(in: 1...100) <= 35 {
                let specialty = Skill.allCases.randomElement()!
                room.trainer = Trainer.random(specialty: specialty, dungeonLevel: level)
            }
        }

        // Teleport pads — a rare shortcut linking two distant rooms. A
        // bidirectional pad works both ways; a one-way pad only leads out,
        // with no pad back. Skipped in small dungeons where a shortcut
        // wouldn't mean much.
        if numRooms >= 12 {
            let padCandidates = rooms.values.filter { $0.roomType != .entrance && $0.roomType != .boss }
            var usedForPad: Set<Int> = []
            let numPads = max(1, numRooms / 15)
            for _ in 0..<numPads {
                let available = padCandidates.filter { !usedForPad.contains($0.id) }
                guard let roomA = available.randomElement() else { break }
                let farEnough = available.filter {
                    $0.id != roomA.id
                        && (abs($0.x - roomA.x) + abs($0.y - roomA.y)) >= 4
                        && !roomA.exits.values.contains($0.id)
                }
                guard let roomB = farEnough.randomElement() else { continue }
                roomA.teleportDestinationRoomId = roomB.id
                if Int.random(in: 1...100) <= 70 {
                    roomB.teleportDestinationRoomId = roomA.id
                }
                usedForPad.insert(roomA.id)
                usedForPad.insert(roomB.id)
            }
        }

        // Vertical connections — a second "floor" reachable via stairs (free,
        // always works), a rope through a hole (needs a Rope item carried),
        // or a levitation shaft (needs an available spell slot). Each pair is
        // bidirectional (same two rooms link both ways once the method's
        // requirement is met) and direction-aware — one side is "down" from
        // there, the other "up" — so labels/flavor text and the map icon can
        // say which way it goes instead of just "a connection exists".
        // Scaled by dungeon size rather than a single fixed pair, since one
        // shortcut in a large dungeon barely registered. Skipped in small
        // dungeons.
        if numRooms >= 15 {
            let numVertical = max(1, numRooms / 12)
            var usedForVertical: Set<Int> = []
            for i in 0..<numVertical {
                let vCandidates = rooms.values.filter {
                    $0.roomType != .entrance && $0.roomType != .boss
                        && $0.teleportDestinationRoomId == nil
                        && $0.verticalDestinationRoomId == nil
                        && !usedForVertical.contains($0.id)
                }
                // First connection preferentially starts from a training
                // room (gym), if one exists — "stairs down/up from the gym"
                // gives an otherwise-easy-to-miss room a reason to visit.
                let roomA: Room?
                if i == 0, let gymRoom = vCandidates.first(where: { $0.trainer != nil }) {
                    roomA = gymRoom
                } else {
                    roomA = vCandidates.randomElement()
                }
                guard let roomA = roomA else { break }

                let farEnough = vCandidates.filter {
                    $0.id != roomA.id
                        && (abs($0.x - roomA.x) + abs($0.y - roomA.y)) >= 4
                        && !roomA.exits.values.contains($0.id)
                }
                guard let roomB = farEnough.randomElement() else { continue }

                // Just two methods, never mixed on the same connection —
                // stairs are free and always usable both ways; rope needs
                // an actual Rope item to climb UP (going down, you can
                // always just jump and risk a landing injury instead).
                let method = ["stairs", "rope"].randomElement()!
                let aGoesDown = Bool.random()
                roomA.verticalDestinationRoomId = roomB.id
                roomA.verticalMethod = method
                roomA.verticalDirection = aGoesDown ? "down" : "up"
                roomB.verticalDestinationRoomId = roomA.id
                roomB.verticalMethod = method
                roomB.verticalDirection = aGoesDown ? "up" : "down"

                // A rope connection needs an actual findable rope somewhere
                // in the dungeon, or climbing up would be a dead end with
                // no way to know where to look — guarantee one and remember
                // the room's name so both ends can point the player at it.
                if method == "rope" {
                    let ropeCandidates = rooms.values.filter {
                        $0.id != roomA.id && $0.id != roomB.id
                            && $0.roomType != .entrance && $0.roomType != .boss
                    }
                    if let ropeRoom = ropeCandidates.randomElement() ?? rooms.values.first(where: { $0.roomType != .entrance }) {
                        ropeRoom.hiddenItems.append(ItemCatalog.rope())
                        roomA.verticalRopeHintRoomName = ropeRoom.name
                        roomB.verticalRopeHintRoomName = ropeRoom.name
                    }
                }

                usedForVertical.insert(roomA.id)
                usedForVertical.insert(roomB.id)
            }
        }

        // Locked doors — a rare obstacle needing a key, lockpicking, or force.
        // Generation is a flood fill with no cycles, so a room's exit toward
        // a higher room id always leads to a "child" subtree with exactly one
        // way in; locking that door gates everything beyond it. The matching
        // key is always placed in a lower-id room, which is guaranteed to be
        // outside that subtree (every room in it was created afterward, so
        // has a higher id) — so the key is always reachable without needing
        // the lock at all. Lockpicking/forcing (see GameEngine) work
        // regardless of whether the key was ever found.
        let maxLocks = min(3, 1 + level / 2)
        var lockedCount = 0
        for room in rooms.values.shuffled() {
            guard lockedCount < maxLocks else { break }
            guard room.roomType != .entrance else { continue }
            guard let (direction, childId) = room.exits.first(where: { dir, id in
                id > room.id && rooms[id]?.roomType != .boss && room.doorLockIds[dir] == nil
            }), let childRoom = rooms[childId] else { continue }
            guard Int.random(in: 1...100) <= 20 else { continue }

            let lockId = UUID()
            room.doorLockIds[direction] = lockId
            childRoom.doorLockIds[direction.opposite] = lockId

            let keyCandidates = rooms.values.filter {
                $0.id < childId && $0.roomType != .entrance && $0.roomType != .boss && $0.id != room.id
            }
            let keyRoom = keyCandidates.randomElement() ?? room
            keyRoom.hiddenItems.append(ItemCatalog.key(forDoorId: lockId))

            lockedCount += 1
        }

        // Spawn NPCs in ~30-40% of non-boss, non-entrance rooms (max 6)
        let npcCandidates = rooms.values.filter {
            $0.roomType != .entrance && $0.roomType != .boss && $0.encounter == nil && $0.npc == nil
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
            newRoom.isTorchlit = Room.rollIsTorchlit(roomType: roomType)
            if newRoom.isTorchlit {
                newRoom.hiddenItems.append(contentsOf: Room.torchlitBonusItems())
            }

            rooms[nextRoomId] = newRoom
            nextRoomId += 1
        }
    }

    private func randomRoomType() -> RoomType {
        let roll = Dice.d100()
        switch roll {
        case 1...20: return .corridor
        case 21...45: return .chamber
        case 46...54: return .empty
        case 55...63: return .treasure
        case 64...72: return .trap
        case 73...85: return .armory
        case 86...89: return .library
        case 90...92: return .shrine
        case 93...95: return .prison
        default: return .chamber
        }
    }

    /// Regenerate encounters for all uncleared rooms (keeps map layout intact)
    func rerollEncounters() {
        for room in rooms.values {
            guard !room.cleared else { continue }
            guard room.roomType != .entrance && room.roomType != .shrine && room.roomType != .shop else { continue }
            // An armoury with a merchant must stay reachable, same as a
            // dedicated shop room — don't hand it a fresh encounter that
            // would block the "Visit Merchant" button behind a fight the
            // room's own description never mentioned.
            guard !(room.roomType == .armory && room.merchant != nil) else { continue }

            if room.roomType == .boss {
                room.encounter = Encounter.generateBoss(level: level)
            } else if room.roomType != .empty {
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

    /// All possible legend symbols, in a fixed order. Which of these are
    /// shown is filtered down to what's actually present on screen (see
    /// mapLegendLines), but the BLOCK HEIGHT never depends on that filtered
    /// count — it's always sized for `legendMaxSymbols` slots regardless of
    /// how many end up active, so the map's line count — and therefore its
    /// on-screen size — never depends on room content, the torch being lit
    /// or unlit, or how many distinct symbol types happen to be nearby.
    // "S"/Shop was dropped — a dedicated shop room always has a merchant
    // (and an armoury sometimes does too), so "M"/Merchant alone already
    // covers it; showing both was redundant for the same room.
    static let mapLegendEntries: [(symbol: String, label: String)] = [
        ("@", "You"), ("!", "Danger"), (".", "Empty"),
        ("E", "Entry"), ("=", "Hall"), ("#", "Room"),
        ("$", "Loot"), ("+", "Shrine"), ("L", "Library"),
        ("B", "Boss"), ("A", "Armoury"), ("P", "Prison"),
        ("M", "Merchant"), ("G", "Gym"), ("N", "NPC"), ("X", "Secured"), ("K", "Locked")
    ]

    static func mapLegendRowCount(maxSymbols: Int) -> Int {
        (max(1, maxSymbols) + 2) / 3
    }

    /// Builds the fixed-size legend block (separator + packed rows), used
    /// identically by both the lit and unlit branches of getMapDisplay.
    /// Only symbols in `activeSymbols` are shown (so the legend stays
    /// relevant to what's actually on screen), but the row count — and so
    /// the block's height — is always determined by `maxSymbols` alone,
    /// padding with blank rows when fewer than that are active.
    private func mapLegendLines(border: String, activeSymbols: Set<String>, maxSymbols: Int) -> [String] {
        let capped = max(1, maxSymbols)
        let entries = Array(Self.mapLegendEntries.filter { activeSymbols.contains($0.symbol) }.prefix(capped))
        let rowCount = Self.mapLegendRowCount(maxSymbols: capped)
        var lines: [String] = ["+\(border)+"]
        var entryIdx = 0
        for _ in 0..<rowCount {
            var row = ""
            for _ in 0..<3 {
                guard entryIdx < entries.count else { break }
                let entry = entries[entryIdx]
                let item = "\(entry.symbol)=\(entry.label)"
                row = row.isEmpty ? item : row + "  \(item)"
                entryIdx += 1
            }
            lines.append("| \(row)".padding(toLength: border.count + 1, withPad: " ", startingAt: 0) + "|")
        }
        return lines
    }

    /// Calculate how many terminal lines a map with the given radius will produce
    func mapLineCount(visibilityRadius: Int, torchLit: Bool, compact: Bool = false, verticalRadius: Int? = nil, legendMaxSymbols: Int = mapLegendEntries.count) -> Int {
        let vRadius = verticalRadius ?? visibilityRadius
        let headerLines = compact ? 1 : 3  // just top border (compact) vs top + MAP + separator
        let gridLines = (2 * vRadius + 1) + (2 * vRadius)  // room rows + corridor rows
        let hereLine = 1  // always reserved so the box size never depends on room content — see getMapDisplay
        // compact: just bottom border; full: separator + fixed legend rows + bottom border
        let legendLines = compact ? 1 : (1 + Self.mapLegendRowCount(maxSymbols: legendMaxSymbols) + 1)
        return headerLines + gridLines + hereLine + legendLines
    }

    /// How far (in room-grid units) the current room is from the furthest
    /// visited room on any side — the radius needed to fit every explored
    /// room on this floor in one getMapDisplay call, for the "hold to see
    /// the whole map" overlay.
    var exploredRadius: Int {
        guard let current = rooms[currentRoomId] else { return 0 }
        let visited = rooms.values.filter { $0.visited }
        guard !visited.isEmpty else { return 0 }
        let dx = visited.map { abs($0.x - current.x) }.max() ?? 0
        let dy = visited.map { abs($0.y - current.y) }.max() ?? 0
        return max(dx, dy)
    }

    func getMapDisplay(visibilityRadius: Int = 3, torchLit: Bool = true, compact: Bool = false, verticalRadius: Int? = nil, legendMaxSymbols: Int = mapLegendEntries.count, hasTrapSense: Bool = false, capWidth: Bool = true) -> [String] {
        guard let current = rooms[currentRoomId] else { return ["No map available."] }

        // Torch off: no direction info — you can't see the passages. Sized
        // to match the same viewport (border width, room/corridor row count)
        // the lit map would use at this same radius, instead of a small
        // fixed box — the box used to visibly shrink and grow every time
        // the torch toggled, rather than just going dark in place.
        if !torchLit {
            let vRadius = verticalRadius ?? visibilityRadius
            let viewMinX = current.x - visibilityRadius
            let viewMaxX = current.x + visibilityRadius
            let viewMinY = current.y - vRadius
            let viewMaxY = current.y + vRadius

            let cols = viewMaxX - viewMinX + 1
            let mapWidth = capWidth ? min(cols * 5 + 3, 40) : cols * 5 + 3
            let border = String(repeating: "-", count: max(mapWidth, 26))

            var lines: [String] = []
            lines.append("+\(border)+")
            if !compact {
                lines.append("| MAP".padding(toLength: border.count + 1, withPad: " ", startingAt: 0) + "|")
                lines.append("+\(border)+")
            }
            // See the torch-lit branch below for why this centers @ instead
            // of leaving it left-of-centre at small radii.
            let naturalContentWidth = 1 + cols * 5
            let gridSlack = max(0, border.count - naturalContentWidth)
            let gridLeadPad = String(repeating: " ", count: gridSlack / 2)
            for y in viewMinY...viewMaxY {
                var roomRow = "| " + gridLeadPad
                for x in viewMinX...viewMaxX {
                    roomRow += (x == current.x && y == current.y) ? "[@]  " : "     "
                }
                roomRow = roomRow.padding(toLength: border.count + 1, withPad: " ", startingAt: 0) + "|"
                lines.append(roomRow)
                if y < viewMaxY {
                    let corridorRow = "|".padding(toLength: border.count + 1, withPad: " ", startingAt: 0) + "|"
                    lines.append(corridorRow)
                }
            }
            let hereLine = "| @ here: torch unlit".padding(toLength: border.count + 1, withPad: " ", startingAt: 0) + "|"
            lines.append(hereLine)
            // No room info without a torch — the only symbol that's actually
            // relevant is "@" itself.
            if !compact { lines.append(contentsOf: mapLegendLines(border: border, activeSymbols: ["@"], maxSymbols: legendMaxSymbols)) }
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

        let cols = viewMaxX - viewMinX + 1
        let mapWidth = capWidth ? min(cols * 5 + 3, 40) : cols * 5 + 3
        let border = String(repeating: "-", count: max(mapWidth, 26))
        lines.append("+\(border)+")
        if !compact {
            lines.append("| MAP".padding(toLength: border.count + 1, withPad: " ", startingAt: 0) + "|")
            lines.append("+\(border)+")
        }

        // At small radii the box has a fixed minimum width (26) wider than
        // the grid actually needs — without this, @ (centered within the
        // grid's own narrower span) ends up left-of-centre in the box,
        // since padding(toLength:) below only ever adds space on the
        // right. Split the slack evenly so the grid — and @ — sits in the
        // middle of the box instead.
        let naturalContentWidth = 1 + cols * 5  // leading space + cells, before the closing border
        let gridSlack = max(0, border.count - naturalContentWidth)
        let gridLeadPad = String(repeating: " ", count: gridSlack / 2)

        // A trap room's own symbol ("!") would otherwise show up on the map
        // the instant it's merely seen — before the trap has actually gone
        // off, and whether or not anyone in the party could plausibly have
        // noticed it. Disguised as an ordinary empty room until either the
        // trap has actually been triggered, or the party has a character
        // skilled enough to sense it (Perception proficiency).
        func effectiveSymbol(for room: Room, hasTrapSense: Bool) -> String {
            guard room.roomType == .trap, !room.trapTriggered, !hasTrapSense else {
                return room.roomType.symbol
            }
            return RoomType.empty.symbol
        }

        // Corridors are only ever drawn once, from whichever side happens to
        // iterate first — the room being drawn's own east/south exits. A
        // north/west exit is only ever drawn as part of THAT neighbor's own
        // row, which never renders if that neighbor hasn't been visited yet
        // (visibleRooms is filtered to .visited). The result: the D-pad
        // (which checks the current room's own room.exits in every
        // direction, visited or not) could say a direction is walkable
        // while the map showed no corridor there at all — patched below,
        // right after the loop, using these captured coordinates.
        var currentRoomLineIndex: Int? = nil
        var currentRoomColumnStart: Int? = nil
        var priorCorridorLineIndex: Int? = nil

        for y in viewMinY...viewMaxY {
            if y == current.y {
                priorCorridorLineIndex = y > viewMinY ? lines.count - 1 : nil
                currentRoomLineIndex = lines.count
                currentRoomColumnStart = 2 + gridLeadPad.count + (current.x - viewMinX) * 5
            }
            // Room row
            var roomRow = "| " + gridLeadPad
            // Vertical corridor row (below this room row)
            var corridorRow = "| " + gridLeadPad

            for x in viewMinX...viewMaxX {
                if let room = visibleRooms.first(where: { $0.x == x && $0.y == y }) {
                    if room.id == currentRoomId {
                        roomRow += "[@]"
                    } else if !room.cleared && room.encounter != nil {
                        roomRow += "[!]"
                    } else if room.merchant != nil {
                        roomRow += "[M]"
                    } else if room.trainer != nil {
                        roomRow += "[G]"
                    } else if room.npc != nil && !(room.npc?.hasBeenTalkedTo ?? true) {
                        // "N" not "?" — "?" is the map's own Help symbol,
                        // and doubling it up for "NPC here" read as confusing.
                        roomRow += "[N]"
                    } else {
                        roomRow += "[\(effectiveSymbol(for: room, hasTrapSense: hasTrapSense))]"
                    }

                    // East corridor (XX = secured/barred, KK = locked door)
                    if let eastId = room.exits[.east] {
                        let eastRoom = rooms[eastId]
                        let barred = room.secured.contains(.east) || (eastRoom?.secured.contains(.west) ?? false)
                        let locked = room.isLockedShut(.east)
                        roomRow += locked ? "KK" : (barred ? "XX" : "--")
                    } else {
                        roomRow += "  "
                    }

                    // South corridor (X = secured/barred, K = locked door)
                    if let southId = room.exits[.south] {
                        let southRoom = rooms[southId]
                        let barred = room.secured.contains(.south) || (southRoom?.secured.contains(.north) ?? false)
                        let locked = room.isLockedShut(.south)
                        corridorRow += locked ? " K   " : (barred ? " X   " : " |   ")
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

        // Patch in the current room's own west/north exits wherever the
        // loop above left that slot blank — see the comment above the loop.
        // Only ever fills in an already-blank slot, so a corridor already
        // drawn from a visited neighbor's own side is never touched.
        if let roomLine = currentRoomLineIndex, let colStart = currentRoomColumnStart {
            if let westId = current.exits[.west], colStart >= 2 {
                let slot = colStart - 2
                var chars = Array(lines[roomLine])
                if slot + 1 < chars.count, chars[slot] == " ", chars[slot + 1] == " " {
                    let westRoom = rooms[westId]
                    let barred = current.secured.contains(.west) || (westRoom?.secured.contains(.east) ?? false)
                    let locked = current.isLockedShut(.west)
                    let symbol = Array(locked ? "KK" : (barred ? "XX" : "--"))
                    chars[slot] = symbol[0]
                    chars[slot + 1] = symbol[1]
                    lines[roomLine] = String(chars)
                }
            }
            if let northId = current.exits[.north], let corridorLine = priorCorridorLineIndex {
                let slot = colStart + 1
                var chars = Array(lines[corridorLine])
                if slot < chars.count, chars[slot] == " " {
                    let northRoom = rooms[northId]
                    let barred = current.secured.contains(.north) || (northRoom?.secured.contains(.south) ?? false)
                    let locked = current.isLockedShut(.north)
                    chars[slot] = locked ? "K" : (barred ? "X" : "|")
                    lines[corridorLine] = String(chars)
                }
            }
        }

        // @ always covers up whatever else is in the player's own room (room
        // type, a merchant, an uncleared encounter...) — spell that out on
        // its own line instead of silently dropping it. Always print this
        // line (even when there's nothing but the room type) so the box's
        // line count — and therefore @'s position — never depends on what's
        // in the room.
        var hereSymbols: [(symbol: String, label: String)] = []
        // "Room"/"Hall"/"Empty" are the default, unremarkable room types —
        // most of the dungeon is one of these, so flagging "you're in a
        // Room" here is just noise, not information (unlike the legend
        // below, which is a key to the whole grid and rightly lists every
        // symbol that can appear on it, generic ones included). Only the
        // genuinely notable types are worth calling out for the room
        // you're actually standing in.
        let hereLabels: [String: String] = [
            "E": "Entry", "$": "Loot", "!": "Trap", "+": "Shrine",
            "L": "Library", "B": "Boss", "A": "Armoury", "P": "Prison",
        ]
        // A merchant IS the shop — "M" on its own tells you everything "S"
        // would have (a dedicated shop room always has a merchant; an
        // armoury sometimes does too), so don't also list the room's base
        // type when there's a merchant here — matches the grid glyph below,
        // which already shows [M] instead of [S]/[A] for the same reason.
        if current.merchant != nil {
            hereSymbols.append(("M", "Merchant"))
        } else {
            let currentSymbol = effectiveSymbol(for: current, hasTrapSense: hasTrapSense)
            if let label = hereLabels[currentSymbol] {
                hereSymbols.append((currentSymbol, label))
            }
        }
        // Only worth flagging when it's actually doing something — if the
        // party's own torch is already lit, wall-mounted torches are redundant info.
        if current.isTorchlit && !torchLit { hereSymbols.append(("T", "Torchlit")) }
        if !current.cleared && current.encounter != nil { hereSymbols.append(("!", "Danger")) }
        if current.trainer != nil { hereSymbols.append(("G", "Gym")) }
        if current.npc != nil && !(current.npc?.hasBeenTalkedTo ?? true) { hereSymbols.append(("N", "NPC")) }
        if current.verticalDestinationRoomId != nil {
            hereSymbols.append((current.verticalDirection == "down" ? "\u{2193}" : "\u{2191}",
                                 current.verticalDirection == "down" ? "Stairs Down" : "Stairs Up"))
        }
        let hereText = "@ here: " + hereSymbols.map { "\($0.symbol)=\($0.label)" }.joined(separator: " ")
        let hereLine = "| \(hereText)".padding(toLength: border.count + 1, withPad: " ", startingAt: 0) + "|"
        lines.append(hereLine)

        // Filtered to symbols actually present in the viewport — but the
        // BLOCK'S HEIGHT is fixed by legendMaxSymbols regardless (see
        // mapLegendLines), so it never changes size room-to-room or when
        // the torch toggles, even though its contents do.
        var visibleSymbols = Set<String>()
        visibleSymbols.insert("@") // current room is always shown
        for room in visibleRooms {
            if room.id == currentRoomId {
                // already added @
            } else if !room.cleared && room.encounter != nil {
                visibleSymbols.insert("!")
            } else if room.merchant != nil {
                // "M" alone, not also the room's base type — see the @ here:
                // line above for why.
                visibleSymbols.insert("M")
            } else {
                visibleSymbols.insert(effectiveSymbol(for: room, hasTrapSense: hasTrapSense))
            }
            if room.trainer != nil { visibleSymbols.insert("G") }
        }
        if visibleRooms.contains(where: { !$0.secured.isEmpty }) {
            visibleSymbols.insert("X")
        }
        if visibleRooms.contains(where: { room in room.doorLockIds.keys.contains(where: { room.isLockedShut($0) }) }) {
            visibleSymbols.insert("K")
        }
        if !compact { lines.append(contentsOf: mapLegendLines(border: border, activeSymbols: visibleSymbols, maxSymbols: legendMaxSymbols)) }
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
