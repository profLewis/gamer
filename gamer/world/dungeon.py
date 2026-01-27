"""Procedural dungeon generation."""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple, Set
from enum import Enum, auto
import random

from .encounters import Encounter


class RoomType(Enum):
    """Types of dungeon rooms."""
    ENTRANCE = auto()
    CORRIDOR = auto()
    CHAMBER = auto()
    TREASURE = auto()
    TRAP = auto()
    BOSS = auto()
    REST = auto()
    SHRINE = auto()
    LIBRARY = auto()
    ARMORY = auto()
    PRISON = auto()
    EMPTY = auto()


class Direction(Enum):
    """Cardinal directions."""
    NORTH = (0, -1)
    SOUTH = (0, 1)
    EAST = (1, 0)
    WEST = (-1, 0)

    @property
    def opposite(self) -> 'Direction':
        opposites = {
            Direction.NORTH: Direction.SOUTH,
            Direction.SOUTH: Direction.NORTH,
            Direction.EAST: Direction.WEST,
            Direction.WEST: Direction.EAST,
        }
        return opposites[self]


@dataclass
class RoomFeature:
    """A feature or object in a room."""
    name: str
    description: str
    interactable: bool = True
    searched: bool = False
    hidden_dc: int = 0  # DC to find if hidden, 0 if visible


@dataclass
class Trap:
    """A trap in a dungeon."""
    name: str
    description: str
    detection_dc: int = 12
    disarm_dc: int = 12
    damage: str = "1d6"
    damage_type: str = "piercing"
    save_dc: int = 12
    save_ability: str = "dex"
    triggered: bool = False
    disarmed: bool = False


@dataclass
class Room:
    """A room in the dungeon."""
    id: int
    room_type: RoomType
    name: str
    description: str
    x: int = 0
    y: int = 0

    # Connections
    exits: Dict[Direction, int] = field(default_factory=dict)  # direction -> room_id
    locked_doors: Set[Direction] = field(default_factory=set)
    secret_doors: Set[Direction] = field(default_factory=set)

    # Contents
    features: List[RoomFeature] = field(default_factory=list)
    trap: Optional[Trap] = None
    encounter: Optional[Encounter] = None
    treasure: List[str] = field(default_factory=list)

    # State
    visited: bool = False
    cleared: bool = False
    lit: bool = True

    def get_exits_description(self) -> str:
        """Get a description of available exits."""
        if not self.exits:
            return "There are no exits."

        exit_strs = []
        for direction in self.exits:
            door_type = "door"
            if direction in self.locked_doors:
                door_type = "locked door"
            elif direction in self.secret_doors:
                door_type = "passage"
            exit_strs.append(f"{direction.name.lower()} ({door_type})")

        return f"Exits: {', '.join(exit_strs)}."

    def get_full_description(self) -> str:
        """Get full room description including features."""
        parts = [self.description]

        if self.features:
            feature_names = [f.name for f in self.features if not f.hidden_dc or f.searched]
            if feature_names:
                parts.append(f"You notice: {', '.join(feature_names)}.")

        parts.append(self.get_exits_description())

        return " ".join(parts)

    def to_dict(self) -> Dict:
        """Convert to dictionary."""
        return {
            'id': self.id,
            'room_type': self.room_type.name,
            'name': self.name,
            'description': self.description,
            'x': self.x,
            'y': self.y,
            'exits': {d.name: rid for d, rid in self.exits.items()},
            'visited': self.visited,
            'cleared': self.cleared,
        }


# Room descriptions by type
ROOM_DESCRIPTIONS: Dict[RoomType, List[str]] = {
    RoomType.ENTRANCE: [
        "A weathered stone archway marks the dungeon entrance. Cobwebs drape the walls.",
        "Crumbling steps lead down into darkness. The air is musty and cold.",
        "An iron portcullis hangs overhead, its mechanism long rusted.",
    ],
    RoomType.CORRIDOR: [
        "A narrow passage stretches before you, its walls damp with moisture.",
        "The corridor is lined with faded murals depicting ancient battles.",
        "Torchlight flickers against rough-hewn stone walls.",
    ],
    RoomType.CHAMBER: [
        "A large chamber opens before you, pillars supporting the vaulted ceiling.",
        "This room was once grand, but now lies in dusty disrepair.",
        "Broken furniture and debris litter this abandoned chamber.",
    ],
    RoomType.TREASURE: [
        "A small room with reinforced walls. Something valuable was kept here.",
        "Glittering dust motes dance in the air of this vault.",
        "Iron-bound chests line the walls of this secure room.",
    ],
    RoomType.TRAP: [
        "The floor here seems newer than the surrounding stonework.",
        "Strange symbols are carved into the walls. You sense danger.",
        "The air feels tense. Your instincts warn of hidden threats.",
    ],
    RoomType.BOSS: [
        "A massive chamber dominates this section of the dungeon.",
        "The ceiling soars overhead in this grand hall.",
        "This room radiates an oppressive aura of power.",
    ],
    RoomType.REST: [
        "A small antechamber provides respite from the dungeon's dangers.",
        "This room appears defensible and relatively safe.",
        "A quiet alcove offers a moment of peace.",
    ],
    RoomType.SHRINE: [
        "An ancient altar dominates this sacred space.",
        "Religious iconography covers the walls of this small shrine.",
        "The air here feels charged with divine energy.",
    ],
    RoomType.LIBRARY: [
        "Dusty bookshelves line the walls, their contents moldering with age.",
        "A scholar's study, with scattered papers and dried inkwells.",
        "Ancient tomes fill this chamber with the scent of old parchment.",
    ],
    RoomType.ARMORY: [
        "Weapon racks and armor stands fill this military storage room.",
        "The clang of metal echoes as you enter this armory.",
        "Rusted weapons and dented shields suggest former glory.",
    ],
    RoomType.PRISON: [
        "Iron bars divide this room into cramped cells.",
        "Chains and manacles hang from the walls of this grim prison.",
        "The despair of past prisoners seems to seep from the stones.",
    ],
    RoomType.EMPTY: [
        "An unremarkable room with nothing of obvious interest.",
        "This chamber appears to have been thoroughly looted.",
        "Dust and silence fill this empty space.",
    ],
}

ROOM_NAMES: Dict[RoomType, List[str]] = {
    RoomType.ENTRANCE: ["Dungeon Entrance", "Entry Hall", "Gateway"],
    RoomType.CORRIDOR: ["Corridor", "Passage", "Hallway"],
    RoomType.CHAMBER: ["Chamber", "Hall", "Room"],
    RoomType.TREASURE: ["Treasury", "Vault", "Strongroom"],
    RoomType.TRAP: ["Suspicious Chamber", "Trapped Room", "Danger Zone"],
    RoomType.BOSS: ["Throne Room", "Grand Chamber", "Lair"],
    RoomType.REST: ["Safe Haven", "Antechamber", "Rest Area"],
    RoomType.SHRINE: ["Shrine", "Chapel", "Sanctum"],
    RoomType.LIBRARY: ["Library", "Archives", "Study"],
    RoomType.ARMORY: ["Armory", "Arsenal", "Weapon Store"],
    RoomType.PRISON: ["Prison", "Dungeon Cells", "Holding Area"],
    RoomType.EMPTY: ["Empty Room", "Abandoned Chamber", "Vacant Space"],
}

# Room features
FEATURES: Dict[RoomType, List[Tuple[str, str]]] = {
    RoomType.CHAMBER: [
        ("Broken Statue", "A shattered stone statue lies in pieces."),
        ("Old Fireplace", "An ornate fireplace, cold and dark."),
        ("Faded Tapestry", "A moth-eaten tapestry depicts a forgotten scene."),
        ("Stone Table", "A heavy stone table sits in the center."),
    ],
    RoomType.LIBRARY: [
        ("Ancient Tome", "A book that might contain useful information."),
        ("Dusty Scroll", "A rolled parchment with faded writing."),
        ("Reading Desk", "A desk with an open book."),
    ],
    RoomType.SHRINE: [
        ("Altar", "A stone altar with carved symbols."),
        ("Holy Symbol", "A religious icon mounted on the wall."),
        ("Offering Bowl", "A bowl that once held offerings."),
    ],
    RoomType.ARMORY: [
        ("Weapon Rack", "A rack that might still hold usable weapons."),
        ("Armor Stand", "A stand with remnants of armor."),
        ("Equipment Chest", "A chest for military supplies."),
    ],
}

# Trap templates
TRAP_TEMPLATES = [
    Trap("Pit Trap", "A concealed pit with spikes below.", 12, 15, "2d10", "piercing", 12, "dex"),
    Trap("Poison Dart", "Darts shoot from hidden holes in the wall.", 14, 13, "1d4", "piercing", 11, "dex"),
    Trap("Swinging Blade", "A blade swings from the ceiling.", 13, 14, "2d6", "slashing", 13, "dex"),
    Trap("Fire Glyph", "A magical glyph that erupts in flame.", 15, 15, "3d6", "fire", 14, "dex"),
    Trap("Crushing Walls", "The walls slowly close in.", 10, 16, "4d6", "bludgeoning", 15, "str"),
]


@dataclass
class Dungeon:
    """A procedurally generated dungeon."""
    name: str
    level: int  # Difficulty level (1-5)
    rooms: Dict[int, Room] = field(default_factory=dict)
    current_room_id: int = 0

    @property
    def current_room(self) -> Optional[Room]:
        """Get the current room."""
        return self.rooms.get(self.current_room_id)

    def get_room(self, room_id: int) -> Optional[Room]:
        """Get a room by ID."""
        return self.rooms.get(room_id)

    def move(self, direction: Direction) -> Tuple[bool, str]:
        """
        Attempt to move in a direction.
        Returns (success, message).
        """
        current = self.current_room
        if not current:
            return False, "You are nowhere."

        if direction not in current.exits:
            return False, f"There is no exit to the {direction.name.lower()}."

        if direction in current.locked_doors:
            return False, f"The door to the {direction.name.lower()} is locked."

        if direction in current.secret_doors:
            # Secret doors need to be discovered first
            return False, f"There is no obvious exit to the {direction.name.lower()}."

        # Move to new room
        new_room_id = current.exits[direction]
        self.current_room_id = new_room_id

        new_room = self.rooms[new_room_id]
        new_room.visited = True

        return True, f"You travel {direction.name.lower()} to the {new_room.name}."

    def unlock_door(self, direction: Direction) -> bool:
        """Unlock a door in the current room."""
        current = self.current_room
        if current and direction in current.locked_doors:
            current.locked_doors.remove(direction)
            return True
        return False

    def reveal_secret(self, direction: Direction) -> bool:
        """Reveal a secret door in the current room."""
        current = self.current_room
        if current and direction in current.secret_doors:
            current.secret_doors.remove(direction)
            return True
        return False

    def to_dict(self) -> Dict:
        """Convert to dictionary."""
        return {
            'name': self.name,
            'level': self.level,
            'rooms': {rid: room.to_dict() for rid, room in self.rooms.items()},
            'current_room_id': self.current_room_id,
        }

    def get_map_display(self, radius: int = 2) -> str:
        """Generate a simple text map centered on current room."""
        current = self.current_room
        if not current:
            return "No map available."

        # Find bounds of visited rooms
        min_x = max_x = current.x
        min_y = max_y = current.y

        for room in self.rooms.values():
            if room.visited:
                min_x = min(min_x, room.x)
                max_x = max(max_x, room.x)
                min_y = min(min_y, room.y)
                max_y = max(max_y, room.y)

        # Limit to radius around current position
        min_x = max(min_x, current.x - radius)
        max_x = min(max_x, current.x + radius)
        min_y = max(min_y, current.y - radius)
        max_y = min(max_y, current.y + radius)

        # Build map grid
        lines = []
        for y in range(min_y, max_y + 1):
            row = ""
            for x in range(min_x, max_x + 1):
                # Find room at this position
                room_here = None
                for room in self.rooms.values():
                    if room.x == x and room.y == y and room.visited:
                        room_here = room
                        break

                if room_here:
                    if room_here.id == self.current_room_id:
                        row += "[*]"
                    elif room_here.room_type == RoomType.ENTRANCE:
                        row += "[E]"
                    elif room_here.room_type == RoomType.BOSS:
                        row += "[B]"
                    else:
                        row += "[ ]"
                else:
                    row += "   "

            lines.append(row)

        return "\n".join(lines)


def generate_dungeon(name: str, level: int = 1, num_rooms: int = 10) -> Dungeon:
    """Generate a procedural dungeon."""
    dungeon = Dungeon(name=name, level=level)

    # Room type distribution based on dungeon level
    room_weights = {
        RoomType.CORRIDOR: 20,
        RoomType.CHAMBER: 25,
        RoomType.EMPTY: 15,
        RoomType.TRAP: 5 + level * 2,
        RoomType.TREASURE: 5,
        RoomType.REST: 5,
        RoomType.SHRINE: 3,
        RoomType.LIBRARY: 3,
        RoomType.ARMORY: 3,
        RoomType.PRISON: 3,
    }

    # Create entrance
    entrance = _create_room(0, RoomType.ENTRANCE, 0, 0)
    dungeon.rooms[0] = entrance
    entrance.visited = True

    # Track positions
    positions: Dict[Tuple[int, int], int] = {(0, 0): 0}

    # Generate remaining rooms
    room_id = 1
    frontier = [(0, 0)]  # Positions that can expand

    while room_id < num_rooms - 1 and frontier:  # -1 to save room for boss
        # Pick a position to expand from
        pos = random.choice(frontier)
        current_room = dungeon.rooms[positions[pos]]

        # Try to add a room in a random direction
        directions = list(Direction)
        random.shuffle(directions)

        expanded = False
        for direction in directions:
            dx, dy = direction.value
            new_pos = (pos[0] + dx, pos[1] + dy)

            if new_pos in positions:
                continue

            # Select room type
            room_type = _weighted_choice(room_weights)

            # Create room
            new_room = _create_room(room_id, room_type, new_pos[0], new_pos[1])

            # Connect rooms
            current_room.exits[direction] = room_id
            new_room.exits[direction.opposite] = positions[pos]

            # Chance for locked door
            if random.random() < 0.15:
                current_room.locked_doors.add(direction)
                new_room.locked_doors.add(direction.opposite)

            # Add to dungeon
            dungeon.rooms[room_id] = new_room
            positions[new_pos] = room_id
            frontier.append(new_pos)

            room_id += 1
            expanded = True
            break

        if not expanded:
            frontier.remove(pos)

    # Add boss room at the end
    if frontier:
        # Find furthest room from entrance
        furthest_pos = max(frontier, key=lambda p: abs(p[0]) + abs(p[1]))
        furthest_room = dungeon.rooms[positions[furthest_pos]]

        # Find an open direction
        for direction in Direction:
            if direction not in furthest_room.exits:
                dx, dy = direction.value
                boss_pos = (furthest_pos[0] + dx, furthest_pos[1] + dy)

                if boss_pos not in positions:
                    boss_room = _create_room(room_id, RoomType.BOSS, boss_pos[0], boss_pos[1])
                    furthest_room.exits[direction] = room_id
                    boss_room.exits[direction.opposite] = positions[furthest_pos]
                    dungeon.rooms[room_id] = boss_room
                    break

    return dungeon


def _create_room(room_id: int, room_type: RoomType, x: int, y: int) -> Room:
    """Create a room with appropriate description and features."""
    name = random.choice(ROOM_NAMES.get(room_type, ["Room"]))
    description = random.choice(ROOM_DESCRIPTIONS.get(room_type, ["An empty room."]))

    room = Room(
        id=room_id,
        room_type=room_type,
        name=name,
        description=description,
        x=x,
        y=y,
    )

    # Add features
    if room_type in FEATURES:
        num_features = random.randint(0, 2)
        available_features = FEATURES[room_type]
        for _ in range(min(num_features, len(available_features))):
            fname, fdesc = random.choice(available_features)
            room.features.append(RoomFeature(fname, fdesc))

    # Add trap if trap room
    if room_type == RoomType.TRAP:
        room.trap = random.choice(TRAP_TEMPLATES)

    return room


def _weighted_choice(weights: Dict[RoomType, int]) -> RoomType:
    """Select a room type based on weights."""
    total = sum(weights.values())
    r = random.randint(1, total)
    cumulative = 0
    for room_type, weight in weights.items():
        cumulative += weight
        if r <= cumulative:
            return room_type
    return RoomType.EMPTY
