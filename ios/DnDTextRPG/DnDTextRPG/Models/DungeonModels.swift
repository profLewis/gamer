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

// MARK: - Atlas (map explorer)

/// A lightweight record of one room — enough for the Atlas to draw and
/// describe it. Built from the live dungeon on demand, and kept (as part of
/// an AtlasLevel) for every level the party has already left behind.
struct AtlasRoom: Codable {
    let id: Int
    let x: Int
    let y: Int
    let symbol: String          // the glyph the Atlas draws for it
    let name: String
    let typeName: String
    let visited: Bool
    let cleared: Bool
    let danger: Bool            // an encounter still waiting here
    let defeated: [String]
    let exits: [String: Int]    // Direction.rawValue -> room id
    let lockedExits: [String]
    let securedExits: [String]
    let teleportTo: Int?
    let verticalTo: Int?
    let verticalDirection: String?
    let verticalMethod: String?
    let merchantName: String?
    let gymName: String?
    let npcName: String?
    let treasureLeft: Bool
    let droppedItems: [String]
}

/// One dungeon level as the Atlas knows it.
/// Where a level sits on the big map (see Dungeon.atlasFrames): the grid's
/// top-left in that level's own coordinates, and the shared size.
struct AtlasFrame {
    let minX: Int
    let minY: Int
    let cols: Int
    let rows: Int
}

struct AtlasLevel: Codable {
    let dungeonName: String
    let level: Int
    let rooms: [AtlasRoom]
    let currentRoomId: Int?     // where you are (nil for a level you've left)
    let exitRoomId: Int?        // where you left a finished level from
}

// MARK: - Room

class Room: Identifiable, ObservableObject, Codable {
    /// The armoury/forge flavour text that names a merchant — shared with
    /// GameEngine's self-heal (see the room-menu render pass) so an old
    /// save whose armoury room already has this text stored (from before
    /// merchants were guaranteed here) gets a real merchant retrofitted to
    /// match it, not just newly-generated dungeons.
    static let armouryMerchantVariant = "Swords, shields, and helms line the walls. A forge in the corner is cold but could be relit. A merchant has set up shop here."

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
    /// Look Around features already done here (a forge lit, a book taken...).
    @Published var interactionsDone: Set<String> = []
    /// Which floor of this level the room is on — 1, unless the level has a
    /// second floor reached by the stairs or rope (see generateDungeon).
    @Published var floor: Int = 1
    /// A puzzle from PuzzleBank (levels 3+: logic, word, cryptic) — shares
    /// riddleResolved, since a room poses one or the other.
    @Published var puzzleId: String? = nil
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
    /// Whether Dungeon.expandIfNeeded(from:) has already made its one-time
    /// decision for every direction this room didn't already have an exit
    /// in. Without this, expandIfNeeded re-rolled its 60% chance for any
    /// still-missing direction on EVERY visit, so a room could genuinely
    /// grow a new exit on a later revisit that simply wasn't there the
    /// first time — the map must be fixed once a room has been considered,
    /// not still being decided fresh each time the player walks back in.
    @Published var expansionConsidered: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, x, y, roomType, name, roomDescription, exits, visited, cleared
        case encounter, treasure, isLocked, searchedFor, trapTriggered
        case hiddenItems, hiddenGold, droppedItems, npc, secured, merchant, trainer
        case defeatedMonsterNames, respawnEligibleMonsterNames
        case riddleIndex, riddleResolved, puzzleId, doorLockIds, openedLocks
        case teleportDestinationRoomId
        case verticalDestinationRoomId, verticalMethod, verticalDirection, verticalRopeHintRoomName
        case isTorchlit, expansionConsidered, interactionsDone, floor
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
        self.puzzleId = nil
        self.trainer = nil
        self.doorLockIds = [:]
        self.openedLocks = []
        self.teleportDestinationRoomId = nil
        self.verticalDestinationRoomId = nil
        self.verticalMethod = nil
        self.verticalDirection = nil
        self.verticalRopeHintRoomName = nil
        self.isTorchlit = false
        self.expansionConsidered = false
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
        interactionsDone = try container.decodeIfPresent(Set<String>.self, forKey: .interactionsDone) ?? []
        floor = try container.decodeIfPresent(Int.self, forKey: .floor) ?? 1
        puzzleId = try container.decodeIfPresent(String.self, forKey: .puzzleId)
        trainer = try container.decodeIfPresent(Trainer.self, forKey: .trainer)
        doorLockIds = try container.decodeIfPresent([Direction: UUID].self, forKey: .doorLockIds) ?? [:]
        openedLocks = try container.decodeIfPresent(Set<Direction>.self, forKey: .openedLocks) ?? []
        teleportDestinationRoomId = try container.decodeIfPresent(Int.self, forKey: .teleportDestinationRoomId)
        verticalDestinationRoomId = try container.decodeIfPresent(Int.self, forKey: .verticalDestinationRoomId)
        verticalMethod = try container.decodeIfPresent(String.self, forKey: .verticalMethod)
        verticalDirection = try container.decodeIfPresent(String.self, forKey: .verticalDirection)
        verticalRopeHintRoomName = try container.decodeIfPresent(String.self, forKey: .verticalRopeHintRoomName)
        isTorchlit = try container.decodeIfPresent(Bool.self, forKey: .isTorchlit) ?? false
        expansionConsidered = try container.decodeIfPresent(Bool.self, forKey: .expansionConsidered) ?? false
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
        try container.encode(interactionsDone, forKey: .interactionsDone)
        try container.encode(floor, forKey: .floor)
        try container.encodeIfPresent(puzzleId, forKey: .puzzleId)
        try container.encodeIfPresent(trainer, forKey: .trainer)
        try container.encode(doorLockIds, forKey: .doorLockIds)
        try container.encode(openedLocks, forKey: .openedLocks)
        try container.encodeIfPresent(teleportDestinationRoomId, forKey: .teleportDestinationRoomId)
        try container.encodeIfPresent(verticalDestinationRoomId, forKey: .verticalDestinationRoomId)
        try container.encodeIfPresent(verticalMethod, forKey: .verticalMethod)
        try container.encodeIfPresent(verticalDirection, forKey: .verticalDirection)
        try container.encodeIfPresent(verticalRopeHintRoomName, forKey: .verticalRopeHintRoomName)
        try container.encode(isTorchlit, forKey: .isTorchlit)
        try container.encode(expansionConsidered, forKey: .expansionConsidered)
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

    /// "Emergency Drop" — the rare, automatic anti-total-party-wipe save
    /// (see GameEngine.handleCombatDefeat) — is one-time-per-adventure, so
    /// it's a genuine safety net rather than a repeatable free pass. Tracked
    /// here (not on GameEngine) so it correctly persists across saves/loads
    /// of THIS specific adventure.
    @Published var emergencyDropUsed: Bool = false

    /// A one-time premium purchase (see GameEngine.visitGym) that covers
    /// every gym in this dungeon at once, instead of paying each Trainer's
    /// membershipPaid individually.
    @Published var hasMultiGymPass: Bool = false

    /// Atlas snapshots of every earlier level of this adventure, oldest
    /// first — carried forward each time the party goes deeper, so the
    /// Atlas can page back through the whole descent.
    @Published var archivedLevels: [AtlasLevel] = []
    /// Map Training (bought at a gym) — unlocks the Atlas from Party
    /// Status. Carried forward to deeper levels along with archivedLevels.
    @Published var hasCartography: Bool = false

    /// The dungeon runs downward: Level 1 is the ground floor (0) and each
    /// level below is one floor further down, to floor -6 (Level 7). "Floor"
    /// always means depth — a level's own second storey is a gallery.
    /// What the player is told. The entrance is on the ground floor, which is
    /// floor 0; each level below is one further down. `level` itself is left
    /// alone — it is saved, and it decides which monsters appear, the XP
    /// thresholds and isFinalLevel, so renumbering it would quietly change the
    /// difficulty of every adventure already under way.
    static func floorName(_ level: Int) -> String {
        level <= 1 ? "Floor 0" : "Floor -\(level - 1)"
    }

    static func depthLabel(_ level: Int) -> String {
        level <= 1 ? "0 (ground)" : "-\(level - 1)"
    }

    /// The same, in words: "the ground floor", "two floors down".
    static func depthWords(_ level: Int) -> String {
        switch level {
        case ...1: return "the ground floor (floor 0)"
        case 2: return "one floor down (floor -1)"
        default: return "\(level - 1) floors down (floor \(depthLabel(level)))"
        }
    }

    /// Where the stairs and ropes lead: the same floor's other gallery.
    var galleryName: String { currentFloor <= 1 ? "upper gallery" : "lower gallery" }

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
        case name, level, rooms, currentRoomId, previousRoomId, nextRoomId, currentFloor, emergencyDropUsed, hasMultiGymPass
        case archivedLevels, hasCartography, levelCount, startDifficulty
    }

    init(name: String, level: Int, levelCount: Int? = nil, startDifficulty: Int? = nil) {
        self.name = name
        self.level = level
        self.levelCount = levelCount ?? Dungeon.finalLevel
        // The difficulty chosen at the start — `level` is the floor number too,
        // so it cannot be asked about this later.
        self.startDifficulty = startDifficulty ?? level
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
        // The floor is whichever floor the party's room is on. A save where
        // these disagreed drew an empty map ("No map available.") and hid
        // the Atlas; the room is the truth.
        if let here = roomsDict[currentRoomId], here.floor != currentFloor { currentFloor = here.floor }
        emergencyDropUsed = (try? container.decodeIfPresent(Bool.self, forKey: .emergencyDropUsed)) ?? false
        hasMultiGymPass = (try? container.decodeIfPresent(Bool.self, forKey: .hasMultiGymPass)) ?? false
        archivedLevels = (try? container.decodeIfPresent([AtlasLevel].self, forKey: .archivedLevels)) ?? []
        hasCartography = (try? container.decodeIfPresent(Bool.self, forKey: .hasCartography)) ?? false
        // Saves made before the depth was configurable were all seven deep.
        levelCount = (try? container.decodeIfPresent(Int.self, forKey: .levelCount)) ?? Dungeon.defaultFinalLevel
        // This was in CodingKeys but in neither coder, and Dungeon writes its
        // own — so it silently went back to medium every time a game was saved
        // and continued, taking the easy-difficulty fight density with it.
        startDifficulty = (try? container.decodeIfPresent(Int.self, forKey: .startDifficulty)) ?? 2
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
        try container.encode(emergencyDropUsed, forKey: .emergencyDropUsed)
        try container.encode(hasMultiGymPass, forKey: .hasMultiGymPass)
        try container.encode(archivedLevels, forKey: .archivedLevels)
        try container.encode(hasCartography, forKey: .hasCartography)
        try container.encode(levelCount, forKey: .levelCount)
        try container.encode(startDifficulty, forKey: .startDifficulty)
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
        // Fewer fights than at first (play-testers found it repetitive) — more
        // room for exploring, and for the things rooms have to do.
        // Cut again (from 0.22-0.34): "still too many combat encounters".
        let base = level <= 1 ? 0.16 : min(0.26, 0.16 + Double(level - 2) * 0.03)
        return base * encounterDensity
    }

    private func generateDungeon() {
        NameRegistry.reset()   // a fresh dungeon: every name is free again
        // Easy floors are small, so the guardian's lair is never far to look.
        let numRooms = startDifficulty <= 1 ? 14 + level * 2 : 20 + level * 5

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
        for armouryRoom in rooms.values where armouryRoom.roomType == .armory {
            armouryRoom.merchant = Merchant.random(tier: MerchantTier.forDungeonLevel(level))
            armouryRoom.roomDescription = Room.armouryMerchantVariant
            // A merchant here must actually be reachable — the "Visit
            // Merchant" button stays hidden behind an uncleared encounter
            // (see showExplorationView()'s gating), so an armoury that says
            // a merchant has set up shop can't also be guarded by a monster
            // the room-type roll may have already assigned before this pass ran.
            armouryRoom.encounter = nil
            // The flavour text names a merchant — give it an actual face:
            // the Dwarven Smith is the only NPC type that prefers armouries,
            // so this guarantees "Ask to Trade" has someone to ask.
            // About one armoury in three is kept by the Dwarven Smith — one
            // person: the shop's keeper IS the smith, so "Visit Merchant" and
            // talking to them name the same dwarf. The rest are run by
            // merchants of every sort.
            if Int.random(in: 1...3) == 1 {
                let smith = DungeonNPC(type: .dwarvenSmith)
                armouryRoom.npc = smith
                armouryRoom.merchant?.name = smith.displayName
            }
        }

        // Riddles and puzzles. They were only in libraries and shrines, and
        // only one in three of those, so a whole floor could pass without one
        // ("what about the puzzles and riddles?"). Now: most libraries and
        // shrines; a third of rooms with monsters (offered BEFORE the fight,
        // as a way past it -- see c03b4aa); and the odd plain chamber.
        for room in rooms.values where room.roomType != .entrance && room.roomType != .boss && room.roomType != .shop {
            let chance: Int
            switch room.roomType {
            case .library, .shrine: chance = 80
            default: chance = room.encounter != nil ? 33 : 12
            }
            if Int.random(in: 1...100) <= chance, room.merchant == nil, room.trainer == nil {
                // Riddles near the top; deeper down, harder puzzles (see PuzzleBank).
                if level >= 3, let pid = PuzzleBank.nextId(tier: Puzzle.tier(forLevel: level)) {
                    room.puzzleId = pid
                } else {
                    room.riddleIndex = RiddleData.nextIndex()
                }
            }
        }

        // Training gyms — a chance in chamber rooms, offering to teach a new
        // skill proficiency for a fee or by winning a sparring check. Unlike
        // shops (guaranteed >= 1 via numShops = max(1, ...)) and general NPCs
        // (floor of 2 via maxNPCs), this was a pure independent 35%-per-room
        // roll with no fallback — a dungeon with only 2-3 chamber rooms had
        // a very real (well over a coin-flip's worth) chance of ending up
        // with zero gyms at all, which is exactly what got reported as
        // "missing gyms." Guarantee at least one, same pattern as shops.
        let chamberRooms = rooms.values.filter { $0.roomType == .chamber && $0.encounter == nil }
        for room in chamberRooms {
            if Int.random(in: 1...100) <= 35 {
                let specialty = Skill.allCases.randomElement()!
                room.trainer = Trainer.random(specialty: specialty, dungeonLevel: level)
            }
        }
        if !chamberRooms.isEmpty, !chamberRooms.contains(where: { $0.trainer != nil }), let luckyRoom = chamberRooms.randomElement() {
            let specialty = Skill.allCases.randomElement()!
            luckyRoom.trainer = Trainer.random(specialty: specialty, dungeonLevel: level)
        }

        // Teleport pads — shortcuts linking two distant rooms, about one pair
        // for every five rooms (see Dungeon.linkTeleportPads).
        if numRooms >= 6 {
            Dungeon.linkTeleportPads(in: rooms, pairs: Dungeon.teleportPairsWanted(roomCount: numRooms))
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
        // A real second floor: its own rooms, its own map. The way down is
        // a stairwell (free) or a rope through a hole (needs a Rope to climb
        // back up), and it lands at the SAME x,y one floor below — so going
        // down puts you where the stairs are, not on a copy of the floor you
        // just left (which is exactly what a shared grid used to look like).
        if numRooms >= 15 {
            let upperRooms = max(5, numRooms / 3)
            let lastFloorTwoId = roomId + upperRooms
            let stairCandidates = rooms.values.filter {
                $0.roomType != .entrance && $0.roomType != .boss && $0.verticalDestinationRoomId == nil
            }
            // Stairs from the gym, if there is one — it gives an easily
            // missed room a reason to visit.
            if let gate = stairCandidates.first(where: { $0.trainer != nil }) ?? stairCandidates.randomElement() {
                let landing = Room(id: roomId, x: gate.x, y: gate.y, type: .chamber)
                landing.floor = 2
                rooms[roomId] = landing
                roomId += 1
                var occupiedUp: Set<String> = ["\(gate.x),\(gate.y)"]
                var frontierUp: [Room] = [landing]
                while roomId <= lastFloorTwoId, !frontierUp.isEmpty {
                    guard let from = frontierUp.randomElement() else { break }
                    var grew = false
                    for direction in Direction.allCases.shuffled() {
                        guard roomId <= lastFloorTwoId else { break }
                        guard from.exits[direction] == nil else { continue }
                        let newX = from.x + direction.offset.x
                        let newY = from.y + direction.offset.y
                        let key = "\(newX),\(newY)"
                        guard !occupiedUp.contains(key) else { continue }
                        occupiedUp.insert(key)
                        let picked = randomRoomType()
                        let room = Room(id: roomId, x: newX, y: newY, type: picked == .entrance ? .chamber : picked)
                        room.floor = 2
                        from.exits[direction] = roomId
                        room.exits[direction.opposite] = from.id
                        if room.roomType != .shrine && room.roomType != .shop && room.roomType != .empty,
                           Double.random(in: 0...1) < encounterChance {
                            room.encounter = Encounter.generate(level: level, difficulty: level == 1 ? .easy : .medium)
                        }
                        if room.roomType == .treasure { room.treasure = TreasureItem.generateTreasure(level: level) }
                        let hiddenLoot = Room.generateHiddenLoot(roomType: room.roomType, level: level)
                        room.hiddenItems = hiddenLoot.items
                        room.hiddenGold = hiddenLoot.gold
                        room.isTorchlit = Room.rollIsTorchlit(roomType: room.roomType)
                        if room.isTorchlit { room.hiddenItems.append(contentsOf: Room.torchlitBonusItems()) }
                        rooms[roomId] = room
                        frontierUp.append(room)
                        roomId += 1
                        grew = true
                    }
                    if !grew { frontierUp.removeAll { $0.id == from.id } }
                }
                let method = ["stairs", "rope"].randomElement()!
                gate.verticalDestinationRoomId = landing.id
                gate.verticalMethod = method
                gate.verticalDirection = "down"
                landing.verticalDestinationRoomId = gate.id
                landing.verticalMethod = method
                landing.verticalDirection = "up"
                // A rope needs a findable rope, or climbing back up is a dead end.
                if method == "rope" {
                    let ropeCandidates = rooms.values.filter {
                        $0.floor == 1 && $0.id != gate.id && $0.roomType != .entrance && $0.roomType != .boss
                    }
                    if let ropeRoom = ropeCandidates.randomElement() {
                        ropeRoom.hiddenItems.append(ItemCatalog.rope())
                        gate.verticalRopeHintRoomName = ropeRoom.name
                        landing.verticalRopeHintRoomName = ropeRoom.name
                    }
                }
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
    ///
    /// Only ever does this ONCE per room (see Room.expansionConsidered) —
    /// it used to re-roll its 60% chance for any still-missing direction on
    /// EVERY visit, so a room whose open direction happened to roll "no
    /// room here" on the first visit could still spawn a brand new exit on
    /// a later revisit, purely because the dice got rolled again. The map
    /// must be fixed the moment a room has been fully considered once, not
    /// still being decided fresh each time the player walks back in.
    func expandIfNeeded(from room: Room) {
        guard !room.expansionConsidered else { return }
        defer { room.expansionConsidered = true }

        // Only expand from rooms that have open adjacent cells
        let occupied = Set(rooms.values.filter { $0.floor == room.floor }.map { "\($0.x),\($0.y)" })

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
            newRoom.floor = room.floor

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
        ("M", "Merchant"), ("G", "Gym"), ("N", "NPC"), ("X", "Secured"), ("K", "Locked"),
        ("*", "Teleport"), ("\u{2191}", "Way up"), ("\u{2193}", "Way down"), ("{ }", "More here")
    ]

    /// Mac/TV have room for the whole key, not just nearby symbols.
    static var showsFullLegend: Bool {
        #if os(macOS) || os(tvOS)
        return true
        #else
        return false
        #endif
    }

    /// Links `pairs` more teleport pads between rooms far apart (most work
    /// both ways; some only lead out). Never the entrance or the boss room,
    /// never a room that already has a pad, never two rooms already joined.
    static func linkTeleportPads(in rooms: [Int: Room], pairs: Int) {
        let padCandidates = rooms.values.filter { $0.roomType != .entrance && $0.roomType != .boss }
        var used = Set(rooms.values.filter { $0.teleportDestinationRoomId != nil }.map { $0.id })
        used.formUnion(rooms.values.compactMap { $0.teleportDestinationRoomId })
        for _ in 0..<max(0, pairs) {
            let available = padCandidates.filter { !used.contains($0.id) }
            guard let roomA = available.randomElement() else { break }
            let farEnough = available.filter {
                $0.id != roomA.id
                    && $0.floor == roomA.floor          // a pad never crosses floors
                    && (abs($0.x - roomA.x) + abs($0.y - roomA.y)) >= 3
                    && !roomA.exits.values.contains($0.id)
            }
            guard let roomB = farEnough.randomElement() else { continue }
            roomA.teleportDestinationRoomId = roomB.id
            if Int.random(in: 1...100) <= 70 {
                roomB.teleportDestinationRoomId = roomA.id
            }
            used.insert(roomA.id)
            used.insert(roomB.id)
        }
    }

    /// Teleport pads at a roughly constant density: about one pair for every
    /// 7-8 rooms — fewer on a small map, more on a big one.
    static func teleportPairsWanted(roomCount: Int) -> Int {
        // One pair per fourteen rooms: enough to be worth finding, few
        // enough that the big map isn't peppered with them.
        max(1, Int((Double(roomCount) / 14.0).rounded()))
    }

    /// Keeps a map near that density: tops up older maps that had one pad or
    /// none, and thins out maps that got too many (only pads nobody's used).
    func ensureTeleportPads() {
        guard rooms.count >= 6 else { return }
        let wantedPairs = Dungeon.teleportPairsWanted(roomCount: rooms.count)
        let padRooms = rooms.values.filter { $0.teleportDestinationRoomId != nil }.count
        let havePairs = (padRooms + 1) / 2
        if havePairs < wantedPairs {
            Dungeon.linkTeleportPads(in: rooms, pairs: wantedPairs - havePairs)
        } else if havePairs > wantedPairs + 1 {
            var excess = havePairs - wantedPairs
            for room in rooms.values.sorted(by: { $0.id < $1.id }) where excess > 0 {
                guard let dest = room.teleportDestinationRoomId, let other = rooms[dest],
                      !room.visited, !other.visited else { continue }
                room.teleportDestinationRoomId = nil
                if other.teleportDestinationRoomId == room.id { other.teleportDestinationRoomId = nil }
                excess -= 1
            }
        }
    }

    /// The box's title line: just "MAP" — the place's name sits on the line
    /// under the map instead (on a phone the title runs under the camera).
    func mapTitleLine(border: String) -> String {
        "| MAP".padding(toLength: border.count + 1, withPad: " ", startingAt: 0) + "|"
    }

    /// The bottom of the world: this level's guardian is the villain from
    /// the opening tale, and beating it ends the adventure.
    static let defaultFinalLevel = 7
    static let minFinalLevel = 1
    static let maxFinalLevel = 12
    /// How deep a NEW dungeon goes — the player's setting, clamped. Stays
    /// deterministic: it is read all over as a display fallback for when there
    /// is no dungeon yet, so it must never be the random one. When the setting
    /// is Auto this is only the stand-in; the real depth comes from
    /// autoLevelCount by way of newAdventure.
    static var finalLevel: Int {
        let v = UserDefaults.standard.integer(forKey: "dungeonLevelCount")
        return (minFinalLevel...maxFinalLevel).contains(v) ? v : defaultFinalLevel
    }

    /// Whether depth is left to the difficulty. Anything outside the valid
    /// range means Auto — including 0, which is what UserDefaults hands back
    /// when nothing was ever stored, so Auto is the default for everybody who
    /// has not chosen a depth, and no migration is needed for those who have.
    static var isAutoDepth: Bool {
        !(minFinalLevel...maxFinalLevel).contains(UserDefaults.standard.integer(forKey: "dungeonLevelCount"))
    }

    /// How deep an adventure at this difficulty should go, with a bit of
    /// randomness so two easy games are not the same shape.
    ///
    /// Brutal deliberately gets the SAME range as hard. Past hard the request
    /// was for harder bosses and harder fighting, not a longer climb — that
    /// part is already carried by difficultyScale, which parseDifficulty raises
    /// above 3, and by encounterDensity below.
    static func autoLevelCount(for difficulty: Int) -> Int {
        let range: ClosedRange<Int>
        switch difficulty {
        case ...1: range = 1...1      // easy: one floor — the guardian, then out
        case 2:    range = 4...6      // medium: about five
        default:   range = 6...8      // hard and beyond: about seven
        }
        return min(maxFinalLevel, max(minFinalLevel, Int.random(in: range)))
    }

    /// A dungeon for a brand-new adventure: depth from the difficulty when the
    /// setting is Auto, from the setting when it is not, and the difficulty
    /// itself recorded so that descending cannot mistake the floor number for it.
    static func newAdventure(name: String, difficulty: Int) -> Dungeon {
        let depth = isAutoDepth ? autoLevelCount(for: difficulty) : finalLevel
        return Dungeon(name: name, level: difficulty, levelCount: depth, startDifficulty: difficulty)
    }
    /// How deep THIS dungeon goes. Fixed when it was made and stored with
    /// it, so changing the setting never reshapes a game already under way.
    var levelCount: Int = Dungeon.defaultFinalLevel
    var isFinalLevel: Bool { level >= levelCount }

    /// The difficulty this dungeon was made at (1 easy, 2 medium, 3+ harder).
    /// `level` cannot stand in for it: level is also the floor number, so it
    /// rises as you descend and an easy game grew as many fights as a hard one
    /// by floor three. Defaulted to 2 so dungeons saved before this decode as
    /// medium and play exactly as they did.
    var startDifficulty: Int = 2

    /// Cheats ("magick: show the boss" and friends) — mark these rooms on the
    /// map even unexplored, as (B), (m) or (!), with no corridors to them:
    /// where they are, not how to get there. For this visit only, not saved.
    var revealBoss = false
    var revealMonsters = false
    var revealTraps = false

    /// The marker for an unexplored room a cheat has revealed, or nil.
    func revealedGlyph(_ room: Room) -> String? {
        guard !room.visited else { return nil }
        if revealBoss && room.roomType == .boss && !room.cleared { return "B" }
        if revealMonsters && !(room.encounter?.aliveMonsters.isEmpty ?? true) { return "m" }
        if revealTraps && room.roomType == .trap && !room.trapTriggered { return "!" }
        return nil
    }

    /// How much of the usual fighting this difficulty wants. Easy means fewer
    /// fights, not just weaker ones — there is more to a dungeon than combat.
    var encounterDensity: Double {
        switch startDifficulty {
        case ...1: return 0.55
        case 2: return 1.0
        case 3: return 1.15
        default: return 1.3
        }
    }

    /// What the villain is called in a fight: "Mother Sable, the Hag of the
    /// Deep" -> "Mother Sable"; "the Hollow King" -> "The Hollow King".
    static func guardianName(_ villain: String) -> String {
        let n = villain.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? villain
        return n.prefix(1).uppercased() + n.dropFirst()
    }

    /// On the final level the boss becomes the villain itself — named, and
    /// tougher than any guardian before it. Safe to call again and again.
    func crownFinalGuardian(villain: String) {
        guard isFinalLevel else { return }
        let name = Dungeon.guardianName(villain)
        for room in rooms.values where room.roomType == .boss && !room.cleared {
            guard var enc = room.encounter, let boss = enc.monsters.first, boss.name != name else { continue }
            // Still the plain boss: crown it (tougher). Already a villain (the
            // quest changed): just the new name, never tougher twice.
            let generic = boss.name.hasSuffix(boss.type.rawValue)
            let hp = generic ? Int(Double(boss.maxHP) * 1.3) : boss.maxHP
            enc.monsters[0] = Monster(id: boss.id, name: name, type: boss.type, currentHP: generic ? hp : boss.currentHP, maxHP: hp,
                                      armorClass: boss.armorClass + (generic ? 1 : 0), attackBonus: boss.attackBonus + (generic ? 1 : 0),
                                      damage: boss.damage, challengeRating: boss.challengeRating,
                                      experiencePoints: boss.experiencePoints * (generic ? 2 : 1))
            room.encounter = enc
        }
    }

    /// A "deep pad": on some levels (about four in ten, fixed by the
    /// dungeon's name and level, so it never changes on reload) one pad
    /// can also carry the party down to the next level. Never on a map
    /// too small to have pads to spare.
    var deepPadRoomId: Int? {
        guard rooms.count >= 8, level < levelCount else { return nil }
        let seed = name.unicodeScalars.reduce(0) { $0 + Int($1.value) } + level * 7
        guard seed % 10 < 4 else { return nil }
        return rooms.values.filter { $0.teleportDestinationRoomId != nil && $0.roomType != .entrance && $0.roomType != .boss }
            .map { $0.id }.max()
    }

    /// Where each mapped level sits on the big map, so flicking between them
    /// lines up: each level is shifted so its entrance lands exactly where
    /// the party left the level above, and all share one frame.
    static func atlasFrames(_ levels: [AtlasLevel], showAll: Bool) -> [AtlasFrame] {
        var offsets: [(Int, Int)] = []
        for (i, level) in levels.enumerated() {
            guard i > 0 else { offsets.append((0, 0)); continue }
            let prev = levels[i - 1]
            let (pdx, pdy) = offsets[i - 1]
            if let exitId = prev.exitRoomId, let exit = prev.rooms.first(where: { $0.id == exitId }),
               let entrance = level.rooms.first(where: { $0.typeName.lowercased().contains("entrance") }) {
                offsets.append((exit.x + pdx - entrance.x, exit.y + pdy - entrance.y))
            } else {
                offsets.append((pdx, pdy))
            }
        }
        var gMinX = Int.max, gMinY = Int.max, gMaxX = Int.min, gMaxY = Int.min
        for (i, level) in levels.enumerated() {
            for room in level.rooms where room.visited || showAll {
                gMinX = min(gMinX, room.x + offsets[i].0); gMaxX = max(gMaxX, room.x + offsets[i].0)
                gMinY = min(gMinY, room.y + offsets[i].1); gMaxY = max(gMaxY, room.y + offsets[i].1)
            }
        }
        guard gMinX <= gMaxX, gMinY <= gMaxY else { return levels.map { _ in AtlasFrame(minX: 0, minY: 0, cols: 1, rows: 1) } }
        return levels.indices.map { i in
            AtlasFrame(minX: gMinX - offsets[i].0, minY: gMinY - offsets[i].1, cols: gMaxX - gMinX + 1, rows: gMaxY - gMinY + 1)
        }
    }

    /// The text map's cells for rooms you've been to (for colouring them in
    /// The Whole Deep): line and first column of each "[X]".
    static func atlasVisitedCells(_ level: AtlasLevel, frame: AtlasFrame) -> [(line: Int, column: Int)] {
        level.rooms.filter { $0.visited }.map { room in
            (3 + (room.y - frame.minY) * 2, 2 + (room.x - frame.minX) * 5)
        }
    }

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
        // Most informative first, so a short key never drops a shrine or a
        // boss in favour of plain rooms; generic room types and "You" last.
        let priority = ["!", "B", "\u{2191}", "\u{2193}", "*", "M", "G", "N", "+", "$", "L", "A", "P", "E", "K", "X", "{ }", "#", "=", ".", "@"]
        let rank: (String) -> Int = { priority.firstIndex(of: $0) ?? priority.count }
        let entries = Array(Self.mapLegendEntries
            .filter { Self.showsFullLegend || activeSymbols.contains($0.symbol) }
            .sorted { rank($0.symbol) < rank($1.symbol) }
            .prefix(capped))
        let rowCount = Self.mapLegendRowCount(maxSymbols: capped)
        var lines: [String] = ["+\(border)+"]
        // Neat columns: each as wide as its widest entry, symbols
        // right-aligned so every "=" in a column lines up. If that won't
        // fit the box, entries are packed as tightly as before instead.
        let columns = 3
        let entryAt: (Int, Int) -> (symbol: String, label: String)? = { r, c in
            let i = r * columns + c
            return i < entries.count ? entries[i] : nil
        }
        var symbolWidth = [Int](repeating: 0, count: columns)
        var itemWidth = [Int](repeating: 0, count: columns)
        for r in 0..<rowCount { for c in 0..<columns { if let e = entryAt(r, c) { symbolWidth[c] = max(symbolWidth[c], e.symbol.count) } } }
        for r in 0..<rowCount { for c in 0..<columns { if let e = entryAt(r, c) { itemWidth[c] = max(itemWidth[c], symbolWidth[c] + 1 + e.label.count) } } }
        let aligned = itemWidth.reduce(0, +) + 2 * (columns - 1) <= border.count - 1
        for r in 0..<rowCount {
            var row = ""
            for c in 0..<columns {
                guard let e = entryAt(r, c) else { break }
                var item = "\(e.symbol)=\(e.label)"
                if aligned {
                    item = String(repeating: " ", count: symbolWidth[c] - e.symbol.count) + item
                    if entryAt(r, c + 1) != nil && c + 1 < columns {
                        item = item.padding(toLength: itemWidth[c], withPad: " ", startingAt: 0)
                    }
                }
                row = c == 0 ? item : row + "  \(item)"
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
        let visited = rooms.values.filter { $0.visited && $0.floor == currentFloor }
        guard !visited.isEmpty else { return 0 }
        let dx = visited.map { abs($0.x - current.x) }.max() ?? 0
        let dy = visited.map { abs($0.y - current.y) }.max() ?? 0
        return max(dx, dy)
    }

    // MARK: Atlas

    /// This level as the Atlas sees it. `archived` marks a level being left
    /// behind: no "you are here", but remembers where you left from.
    func atlasLevel(hasTrapSense: Bool, archived: Bool = false) -> AtlasLevel {
        let atlasRooms = rooms.values.filter { $0.floor == currentFloor }.sorted { $0.id < $1.id }.map { room -> AtlasRoom in
            let danger = !room.cleared && room.encounter != nil
            let symbol: String
            // Most important first: danger, the boss, a way up/down, a
            // teleport pad — then merchant, gym, and an NPC you haven't met.
            if danger { symbol = "!" }
            else if room.roomType == .boss { symbol = RoomType.boss.symbol }
            else if room.verticalDestinationRoomId != nil { symbol = room.verticalDirection == "down" ? "\u{2193}" : "\u{2191}" }
            else if room.teleportDestinationRoomId != nil { symbol = "*" }
            else if room.merchant != nil { symbol = "M" }
            else if room.trainer != nil { symbol = "G" }
            else if room.npc != nil && !(room.npc?.hasBeenTalkedTo ?? true) { symbol = "N" }
            else if room.roomType == .trap && !room.trapTriggered && !hasTrapSense { symbol = RoomType.empty.symbol }
            else { symbol = room.roomType.symbol }
            return AtlasRoom(
                id: room.id, x: room.x, y: room.y, symbol: symbol, name: room.name,
                typeName: room.roomType.rawValue.capitalized, visited: room.visited, cleared: room.cleared,
                danger: danger, defeated: room.defeatedMonsterNames,
                exits: Dictionary(uniqueKeysWithValues: room.exits.map { ($0.key.rawValue, $0.value) }),
                lockedExits: room.exits.keys.filter { room.isLockedShut($0) }.map { $0.rawValue },
                securedExits: room.secured.map { $0.rawValue },
                teleportTo: room.teleportDestinationRoomId, verticalTo: room.verticalDestinationRoomId,
                verticalDirection: room.verticalDirection, verticalMethod: room.verticalMethod,
                merchantName: room.merchant?.name, gymName: room.trainer?.gymName, npcName: room.npc?.name,
                treasureLeft: !room.treasure.isEmpty, droppedItems: room.droppedItems.map { $0.name })
        }
        return AtlasLevel(dungeonName: name, level: level, rooms: atlasRooms,
                          currentRoomId: archived ? nil : currentRoomId,
                          exitRoomId: archived ? currentRoomId : nil)
    }

    /// The whole level drawn in the same [X]--[Y] style as the main map,
    /// sized to fit every shown room. `highlight` is the line/column of
    /// the "[@]" cell, for colouring where you are.
    static func atlasMapLines(_ level: AtlasLevel, showAll: Bool, frame: AtlasFrame? = nil) -> (lines: [String], highlight: (line: Int, column: Int)?) {
        let shown = level.rooms.filter { $0.visited || showAll }
        guard var minX = shown.map({ $0.x }).min(), var maxX = shown.map({ $0.x }).max(),
              var minY = shown.map({ $0.y }).min(), var maxY = shown.map({ $0.y }).max() else {
            return (["(nothing mapped yet)"], nil)
        }
        // A shared frame lines this level up with the others (see atlasFrames).
        if let f = frame { minX = f.minX; minY = f.minY; maxX = f.minX + f.cols - 1; maxY = f.minY + f.rows - 1 }
        let shownIds = Set(shown.map { $0.id })
        // Teleport pads: each linked pair gets its own number (1, 2, 3...)
        // on the map, so you can see which pad goes where — listed under
        // the map too. A pad's far end stays hidden until you've been
        // there (or World Map shows every room).
        let byId = Dictionary(uniqueKeysWithValues: level.rooms.map { ($0.id, $0) })
        var padNumber: [Int: String] = [:]
        var padPairs: [(from: Int, to: Int?)] = []
        for room in level.rooms.sorted(by: { $0.id < $1.id })
            where room.teleportTo != nil && padNumber[room.id] == nil && (room.visited || showAll) {
            let n = padPairs.count
            let label = n < 9 ? "\(n + 1)" : String(UnicodeScalar(UInt8(65 + min(n - 9, 25))))
            padNumber[room.id] = label
            if let dest = room.teleportTo, let far = byId[dest], far.visited || showAll { padNumber[dest] = label }
            padPairs.append((room.id, room.teleportTo))
        }
        let width = (maxX - minX + 1) * 5
        let height = (maxY - minY + 1) * 2 - 1
        var grid = Array(repeating: Array(repeating: Swift.Character(" "), count: width), count: height)
        func put(_ s: String, _ row: Int, _ col: Int) {
            guard row >= 0, row < height else { return }
            for (i, ch) in s.enumerated() where col + i >= 0 && col + i < width { grid[row][col + i] = ch }
        }
        for room in shown {
            let cx = (room.x - minX) * 5, cy = (room.y - minY) * 2
            let glyph: String
            if room.id == level.currentRoomId { glyph = "@" }
            else if !room.visited { glyph = padNumber[room.id] ?? " " }
            else if ["!", RoomType.boss.symbol, "\u{2191}", "\u{2193}"].contains(room.symbol) { glyph = room.symbol }
            else { glyph = padNumber[room.id] ?? room.symbol }
            // {X} instead of [X]: more than one thing of note in this room.
            let thingsHere = [room.danger, room.typeName == "Boss", room.verticalTo != nil, room.teleportTo != nil,
                              room.merchantName != nil, room.gymName != nil, room.npcName != nil].filter { $0 }.count
            let several = room.visited && thingsHere > 1
            put(several ? "{\(glyph)}" : "[\(glyph)]", cy, cx)
            for dir in Direction.allCases {
                guard let targetId = room.exits[dir.rawValue] else { continue }
                // Each passage is drawn once — from its east/south end, or
                // from this end when the room beyond isn't on the map.
                if (dir == .west || dir == .north) && shownIds.contains(targetId) { continue }
                let locked = room.lockedExits.contains(dir.rawValue)
                let barred = room.securedExits.contains(dir.rawValue)
                let across = locked ? "KK" : (barred ? "XX" : "--")
                let upDown = locked ? "K" : (barred ? "X" : "|")
                switch dir {
                case .east: put(across, cy, cx + 3)
                case .west: put(across, cy, cx - 2)
                case .south: put(upDown, cy + 1, cx + 1)
                case .north: put(upDown, cy - 1, cx + 1)
                }
            }
        }
        let title = " ATLAS — Level \(level.level): \(level.dungeonName)"
        let inner = max(width + 2, title.count + 1, 28)
        let border = "+" + String(repeating: "-", count: inner) + "+"
        var lines = [border, "|" + title.padding(toLength: inner, withPad: " ", startingAt: 0) + "|", border]
        var highlight: (line: Int, column: Int)? = nil
        let current = shown.first { $0.id == level.currentRoomId }
        for (row, chars) in grid.enumerated() {
            lines.append("| " + String(chars).padding(toLength: inner - 1, withPad: " ", startingAt: 0) + "|")
            if let current = current, row == (current.y - minY) * 2 {
                highlight = (lines.count - 1, 2 + (current.x - minX) * 5)
            }
        }
        lines.append(border)
        if !padPairs.isEmpty {
            lines.append("")
            lines.append("TELEPORT PADS")
            for pair in padPairs {
                let label = padNumber[pair.from] ?? "?"
                let from = byId[pair.from]?.name ?? "?"
                let to = pair.to.flatMap { byId[$0] }.map { ($0.visited || showAll) ? $0.name : "somewhere unexplored" } ?? "?"
                lines.append("  \(label): \(from) ↔ \(to)")
            }
        }
        return (lines, highlight)
    }

    /// The Atlas's full key — every symbol it can draw, not just nearby ones.
    static let atlasKeyEntries: [(symbol: String, label: String)] = [
        ("@", "You are here"), ("!", "Danger / trap"), (".", "Empty"),
        ("E", "Entry"), ("=", "Hall"), ("#", "Room"), ("$", "Loot"), ("+", "Shrine"),
        ("L", "Library"), ("B", "Boss"), ("A", "Armoury"), ("P", "Prison"),
        ("M", "Merchant"), ("G", "Gym"), ("N", "NPC"), ("1-9", "Teleport pads"),
        ("\u{2191}", "Way up"), ("\u{2193}", "Way down"), ("[ ]", "Unexplored"), ("--", "Passage"),
        ("KK", "Locked door"), ("XX", "Barred door"), ("{ }", "Multiple"),
    ]

    static func atlasKeyLines() -> [String] {
        let cells = atlasKeyEntries.map { $0.symbol.padding(toLength: 3, withPad: " ", startingAt: 0) + " " + $0.label }
        var out = ["KEY"]
        for i in stride(from: 0, to: cells.count, by: 2) {
            let left = cells[i].padding(toLength: 20, withPad: " ", startingAt: 0)
            out.append(left + (i + 1 < cells.count ? cells[i + 1] : ""))
        }
        return out
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
                lines.append(mapTitleLine(border: border))
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

        // Only show visited rooms within the viewport -- on the floor of the
        // room you are actually standing in. This used to trust currentFloor,
        // and whenever that disagreed with the room (an older save, or a route
        // between floors that didn't update it) nothing matched and the map
        // said "No map available." The room you're in always counts as seen.
        let floorHere = current.floor
        let visibleRooms = rooms.values.filter {
            $0.floor == floorHere && ($0.visited || $0.id == current.id || revealedGlyph($0) != nil) && $0.x >= viewMinX && $0.x <= viewMaxX && $0.y >= viewMinY && $0.y <= viewMaxY
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
            lines.append(mapTitleLine(border: border))
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

        // Priority: danger, boss, a way up/down, teleport pad, merchant,
        // gym, an NPC you haven't met — then the room's own type. "N"
        // not "?" for an NPC: "?" is the map's own Help symbol.
        func cellGlyph(for room: Room) -> (glyph: String, several: Bool) {
            let danger = !room.cleared && room.encounter != nil
            let unmetNPC = room.npc != nil && !(room.npc?.hasBeenTalkedTo ?? true)
            let things = [danger, room.roomType == .boss, room.verticalDestinationRoomId != nil,
                          room.teleportDestinationRoomId != nil, room.merchant != nil, room.trainer != nil, unmetNPC]
            let several = things.filter { $0 }.count > 1
            if danger { return ("!", several) }
            if room.roomType == .boss { return (RoomType.boss.symbol, several) }
            if room.verticalDestinationRoomId != nil { return (room.verticalDirection == "down" ? "\u{2193}" : "\u{2191}", several) }
            if room.teleportDestinationRoomId != nil { return ("*", several) }
            if room.merchant != nil { return ("M", several) }
            if room.trainer != nil { return ("G", several) }
            if unmetNPC { return ("N", several) }
            return (effectiveSymbol(for: room, hasTrapSense: hasTrapSense), several)
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
                if let room = visibleRooms.first(where: { $0.x == x && $0.y == y }),
                   room.id != currentRoomId, let mark = revealedGlyph(room) {
                    // Revealed by a cheat: the room alone, no corridors to it.
                    roomRow += "(\(mark))  "
                    corridorRow += "     "
                } else if let room = visibleRooms.first(where: { $0.x == x && $0.y == y }) {
                    if room.id == currentRoomId {
                        roomRow += "[@]"
                    } else {
                        // Most important thing in the room; {X} when there's more than one.
                        let cell = cellGlyph(for: room)
                        roomRow += cell.several ? "{\(cell.glyph)}" : "[\(cell.glyph)]"
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
        for room in visibleRooms where room.id != currentRoomId {
            let cell = cellGlyph(for: room)
            visibleSymbols.insert(cell.glyph)
            if cell.several { visibleSymbols.insert("{ }") }
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
