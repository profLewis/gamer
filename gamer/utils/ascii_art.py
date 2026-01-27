"""ASCII art rendering for characters and maps."""

from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass

# Character class ASCII art templates
CHARACTER_ART: Dict[str, List[str]] = {
    "fighter": [
        "    ╔═╗    ",
        "   ╔╩═╩╗   ",
        "   ║ᴗ ᴗ║   ",
        "   ║ ▽ ║   ",
        "  ╔╩═══╩╗  ",
        " ╔╝║   ║╚╗ ",
        " ║ ║▓▓▓║ ║▄",
        " ║ ║▓▓▓║ ╠═",
        " ║ ╚═══╝ ║ ",
        " ║ ┌─┬─┐ ║ ",
        " ╚═╡ │ ╞═╝ ",
        "   │ │ │   ",
        "   ╘═╧═╛   ",
    ],
    "wizard": [
        "     ▲     ",
        "    ╱█╲    ",
        "   ╱ ★ ╲   ",
        "  ╱─────╲  ",
        "   ║ᴗ ᴗ║   ",
        "   ║ ◡ ║   ",
        "  ╔╩═══╩╗  ",
        " ╔╝ ░░░ ╚╗ ",
        " ║ ░░░░░ ║ ",
        "▒║ ░░░░░ ║ ",
        "▒╚══╤═╤══╝ ",
        "    │ │    ",
        "   ═╧═╧═   ",
    ],
    "rogue": [
        "           ",
        "    ┌─┐    ",
        "   ╔╧═╧╗   ",
        "   ║• •║   ",
        "   ║ ▾ ║   ",
        "  ╔╩═══╩╗  ",
        " ╔╝░░░░░╚╗ ",
        "▄╣░░░░░░░╠ ",
        " ╚╗░░░░░╔╝ ",
        "  ╠═╤═╤═╣  ",
        "  │ │ │ │  ",
        "  │ │ │ │  ",
        "  ╘═╛ ╘═╛  ",
    ],
    "cleric": [
        "    ╬╬╬    ",
        "    ╬╬╬    ",
        "   ╔═══╗   ",
        "   ║ᴗ ᴗ║   ",
        "   ║ ◠ ║   ",
        "  ╔╩═══╩╗  ",
        " ╔╝▓▓▓▓▓╚╗ ",
        " ║▓▓╬╬╬▓▓║ ",
        " ║▓▓╬╬╬▓▓║ ",
        " ╚═╤═══╤═╝ ",
        "   │   │   ",
        "   │   │   ",
        "  ═╧═ ═╧═  ",
    ],
    "ranger": [
        "     │     ",
        "    ╱│╲    ",
        "   ╔═╧═╗   ",
        "   ║• •║   ",
        "   ║ ▿ ║   ",
        "  ╔╩═══╩╗  ",
        " ╔╝░▓░▓░╚╗ ",
        "◄║░▓░▓░▓░║ ",
        " ║░▓░▓░▓░║►",
        " ╚══╤═╤══╝ ",
        "    │ │    ",
        "    │ │    ",
        "   ═╧═╧═   ",
    ],
    "barbarian": [
        "   ╲   ╱   ",
        "    ╲ ╱    ",
        "   ╔═══╗   ",
        "   ║ᴗ ᴗ║   ",
        "   ║ ▿ ║   ",
        "  ╔╩═══╩╗  ",
        " ╔╝█████╚╗ ",
        " ║ █████ ╠▄",
        " ║ █████ ║ ",
        " ╚══╤═╤══╝ ",
        "    │█│    ",
        "    │█│    ",
        "   ═╧═╧═   ",
    ],
    "default": [
        "           ",
        "   ┌───┐   ",
        "   │@ @│   ",
        "   │ ▽ │   ",
        "   └─┬─┘   ",
        "  ╔══╧══╗  ",
        "  ║ ░░░ ║  ",
        "  ║ ░░░ ║  ",
        "  ║ ░░░ ║  ",
        "  ╚═╤═╤═╝  ",
        "    │ │    ",
        "    │ │    ",
        "   ═╧═╧═   ",
    ],
}

# Race modifiers for character art (head decorations)
RACE_DECORATIONS: Dict[str, List[Tuple[int, int, str]]] = {
    "elf": [(0, 3, "╱"), (0, 7, "╲")],  # Pointed ear hints
    "high_elf": [(0, 3, "╱"), (0, 7, "╲")],
    "wood_elf": [(0, 3, "╱"), (0, 7, "╲")],
    "dwarf": [(1, 4, "▄"), (1, 5, "▄"), (1, 6, "▄")],  # Beard
    "hill_dwarf": [(1, 4, "▄"), (1, 5, "▄"), (1, 6, "▄")],
    "mountain_dwarf": [(1, 4, "█"), (1, 5, "█"), (1, 6, "█")],  # Thicker beard
    "halfling": [],  # Smaller, no decoration needed
    "half-orc": [(3, 4, "╲"), (3, 6, "╱")],  # Tusks
    "tiefling": [(0, 3, "╱"), (0, 7, "╲"), (1, 2, "│"), (1, 8, "│")],  # Horns
    "dragonborn": [(0, 2, "▄"), (0, 8, "▄")],  # Head ridges
}

# Monster ASCII art
MONSTER_ART: Dict[str, List[str]] = {
    "goblin": [
        "  ╱▔▔╲  ",
        " ╱•  •╲ ",
        " │ ▿▿ │ ",
        "  ╲▂▂╱  ",
        "   ▓▓   ",
        "  ╱▓▓╲  ",
        " ╱ ▓▓ ╲ ",
        "   ││   ",
    ],
    "skeleton": [
        "  ┌───┐  ",
        "  │○ ○│  ",
        "  │ ▽ │  ",
        "  └┬─┬┘  ",
        "   │█│   ",
        "  ╱│█│╲  ",
        " ╱ │█│ ╲ ",
        "   │ │   ",
    ],
    "orc": [
        "  ▄███▄  ",
        " █ᴗ  ᴗ█ ",
        " █╲▽▽╱█ ",
        "  █▀▀█  ",
        "  ████  ",
        " ▓████▓ ",
        "  █  █  ",
        " ▀▀  ▀▀ ",
    ],
    "ogre": [
        " ▄█████▄ ",
        "██ᴗ   ᴗ██",
        "██  ▽  ██",
        " ▀█▄▄▄█▀ ",
        "  █████  ",
        " ███████ ",
        " ███████ ",
        "  ██  ██ ",
    ],
    "default": [
        "  ▄▄▄▄  ",
        " █?  ?█ ",
        " █ ▽▽ █ ",
        "  ▀▀▀▀  ",
        "   ██   ",
        "  ████  ",
        "  █  █  ",
        "  ▀  ▀  ",
    ],
}

# Map symbols for different room types
ROOM_SYMBOLS: Dict[str, str] = {
    "ENTRANCE": "◊",
    "CORRIDOR": "░",
    "CHAMBER": "▪",
    "TREASURE": "$",
    "TRAP": "!",
    "BOSS": "☠",
    "REST": "♥",
    "SHRINE": "†",
    "LIBRARY": "📖",
    "ARMORY": "⚔",
    "PRISON": "▥",
    "EMPTY": "·",
    "CURRENT": "@",
    "UNKNOWN": "?",
}

# Simple fallback symbols (ASCII only)
ROOM_SYMBOLS_ASCII: Dict[str, str] = {
    "ENTRANCE": "E",
    "CORRIDOR": "=",
    "CHAMBER": "#",
    "TREASURE": "$",
    "TRAP": "!",
    "BOSS": "B",
    "REST": "+",
    "SHRINE": "T",
    "LIBRARY": "L",
    "ARMORY": "A",
    "PRISON": "P",
    "EMPTY": ".",
    "CURRENT": "@",
    "UNKNOWN": "?",
}


def render_character(char_class: str, race: str = "", name: str = "",
                     level: int = 1, hp: int = 0, max_hp: int = 0) -> str:
    """Render a character as ASCII art with stats."""
    # Get base art for class
    class_key = char_class.lower()
    art = CHARACTER_ART.get(class_key, CHARACTER_ART["default"])
    art = [list(line) for line in art]  # Make mutable

    # Apply race decorations (optional, can get complex)
    race_key = race.lower().replace(" ", "_")
    if race_key in RACE_DECORATIONS:
        for row, col, char in RACE_DECORATIONS[race_key]:
            if row < len(art) and col < len(art[row]):
                art[row][col] = char

    # Convert back to strings
    art_lines = ["".join(line) for line in art]

    # Build the full display
    lines = []
    lines.append("╔" + "═" * 24 + "╗")
    lines.append("║" + f" {name[:22]:^22} " + "║")
    lines.append("║" + f" Lv.{level} {race} {char_class} "[:22].center(22) + "  ║")
    lines.append("╠" + "═" * 24 + "╣")

    # Center the character art
    for art_line in art_lines:
        padded = f"{art_line:^22}"
        lines.append("║ " + padded + " ║")

    lines.append("╠" + "═" * 24 + "╣")

    # HP bar
    if max_hp > 0:
        hp_pct = hp / max_hp
        bar_width = 18
        filled = int(hp_pct * bar_width)
        bar = "█" * filled + "░" * (bar_width - filled)
        lines.append(f"║  HP: {bar} ║")
        lines.append(f"║      {hp:3d}/{max_hp:3d}          ║")
    else:
        lines.append("║" + " " * 24 + "║")
        lines.append("║" + " " * 24 + "║")

    lines.append("╚" + "═" * 24 + "╝")

    return "\n".join(lines)


def render_monster(monster_name: str, hp: int = 0, max_hp: int = 0) -> str:
    """Render a monster as ASCII art."""
    key = monster_name.lower()
    art = MONSTER_ART.get(key, MONSTER_ART["default"])

    lines = []
    lines.append("┌" + "─" * 14 + "┐")
    lines.append("│" + f" {monster_name[:12]:^12} " + "│")
    lines.append("├" + "─" * 14 + "┤")

    for art_line in art:
        padded = f"{art_line:^12}"
        lines.append("│ " + padded + " │")

    if max_hp > 0:
        hp_pct = hp / max_hp
        bar_width = 10
        filled = int(hp_pct * bar_width)
        bar = "█" * filled + "░" * (bar_width - filled)
        lines.append("├" + "─" * 14 + "┤")
        lines.append(f"│  {bar}  │")
        lines.append(f"│  {hp:3d}/{max_hp:3d} HP  │")

    lines.append("└" + "─" * 14 + "┘")

    return "\n".join(lines)


def render_party(characters: list) -> str:
    """Render multiple characters side by side."""
    if not characters:
        return "No party members."

    # Render each character
    rendered = []
    for char in characters[:4]:  # Max 4 characters
        char_render = render_character(
            char.char_class.name,
            char.race.get_full_name(),
            char.name,
            char.level,
            char.current_hp,
            char.max_hp
        )
        rendered.append(char_render.split("\n"))

    # Combine side by side
    if not rendered:
        return ""

    max_lines = max(len(r) for r in rendered)

    # Pad shorter renders
    for r in rendered:
        while len(r) < max_lines:
            r.append(" " * len(r[0]) if r else "")

    # Combine
    combined_lines = []
    for i in range(max_lines):
        line_parts = [r[i] if i < len(r) else " " * 26 for r in rendered]
        combined_lines.append("  ".join(line_parts))

    return "\n".join(combined_lines)


def render_dungeon_map(dungeon, radius: int = 3, use_unicode: bool = True) -> str:
    """
    Render an enhanced dungeon map.

    Args:
        dungeon: The Dungeon object
        radius: How many rooms to show in each direction
        use_unicode: Use Unicode symbols (True) or ASCII only (False)
    """
    if not dungeon or not dungeon.current_room:
        return "No map available."

    current = dungeon.current_room
    symbols = ROOM_SYMBOLS if use_unicode else ROOM_SYMBOLS_ASCII

    # Find bounds of visited rooms
    visited_rooms = [r for r in dungeon.rooms.values() if r.visited]
    if not visited_rooms:
        return "No explored areas."

    min_x = min(r.x for r in visited_rooms)
    max_x = max(r.x for r in visited_rooms)
    min_y = min(r.y for r in visited_rooms)
    max_y = max(r.y for r in visited_rooms)

    # Limit to radius
    min_x = max(min_x, current.x - radius)
    max_x = min(max_x, current.x + radius)
    min_y = max(min_y, current.y - radius)
    max_y = min(max_y, current.y + radius)

    # Create position lookup
    pos_to_room = {}
    for room in dungeon.rooms.values():
        if room.visited:
            pos_to_room[(room.x, room.y)] = room

    # Build the map with walls and connections
    # Each cell is 5 chars wide, 3 chars tall
    cell_width = 7
    cell_height = 3

    map_width = (max_x - min_x + 1) * cell_width + 1
    map_height = (max_y - min_y + 1) * cell_height + 1

    # Initialize grid
    grid = [[' ' for _ in range(map_width)] for _ in range(map_height)]

    def draw_room(room, gx, gy):
        """Draw a room at grid position."""
        # Room box
        is_current = room.id == dungeon.current_room_id

        # Get room symbol
        if is_current:
            symbol = symbols["CURRENT"]
        else:
            symbol = symbols.get(room.room_type.name, symbols["UNKNOWN"])

        # Status indicator
        if not room.cleared and room.encounter:
            status = "!" if not is_current else "@"
        elif room.treasure:
            status = "$"
        else:
            status = symbol

        # Draw corners and walls
        # Top-left corner
        grid[gy][gx] = "┌" if use_unicode else "+"
        # Top-right corner
        grid[gy][gx + cell_width - 1] = "┐" if use_unicode else "+"
        # Bottom-left corner
        grid[gy + cell_height - 1][gx] = "└" if use_unicode else "+"
        # Bottom-right corner
        grid[gy + cell_height - 1][gx + cell_width - 1] = "┘" if use_unicode else "+"

        # Top and bottom walls
        for i in range(1, cell_width - 1):
            grid[gy][gx + i] = "─" if use_unicode else "-"
            grid[gy + cell_height - 1][gx + i] = "─" if use_unicode else "-"

        # Side walls
        for i in range(1, cell_height - 1):
            grid[gy + i][gx] = "│" if use_unicode else "|"
            grid[gy + i][gx + cell_width - 1] = "│" if use_unicode else "|"

        # Room content (center)
        center_y = gy + cell_height // 2
        center_x = gx + cell_width // 2

        # Show room type and status
        if is_current:
            # Highlight current room
            grid[center_y][center_x - 1] = "["
            grid[center_y][center_x] = "@"
            grid[center_y][center_x + 1] = "]"
        else:
            grid[center_y][center_x] = status

        # Draw exits/connections
        from ..world.dungeon import Direction
        for direction in room.exits.keys():
            dx, dy = direction.value
            # Calculate door position
            if direction == Direction.NORTH:
                door_x = gx + cell_width // 2
                door_y = gy
                grid[door_y][door_x] = "╨" if use_unicode else "^"
            elif direction == Direction.SOUTH:
                door_x = gx + cell_width // 2
                door_y = gy + cell_height - 1
                grid[door_y][door_x] = "╥" if use_unicode else "v"
            elif direction == Direction.EAST:
                door_x = gx + cell_width - 1
                door_y = gy + cell_height // 2
                grid[door_y][door_x] = "╡" if use_unicode else ">"
            elif direction == Direction.WEST:
                door_x = gx
                door_y = gy + cell_height // 2
                grid[door_y][door_x] = "╞" if use_unicode else "<"

            # Mark locked doors
            if direction in room.locked_doors:
                if direction in [Direction.NORTH, Direction.SOUTH]:
                    grid[door_y][door_x] = "╪" if use_unicode else "X"
                else:
                    grid[door_y][door_x] = "╫" if use_unicode else "X"

    # Draw each room
    for room in visited_rooms:
        if min_x <= room.x <= max_x and min_y <= room.y <= max_y:
            gx = (room.x - min_x) * cell_width
            gy = (room.y - min_y) * cell_height
            draw_room(room, gx, gy)

    # Draw corridors between rooms
    for room in visited_rooms:
        if min_x <= room.x <= max_x and min_y <= room.y <= max_y:
            gx = (room.x - min_x) * cell_width
            gy = (room.y - min_y) * cell_height
            from ..world.dungeon import Direction

            for direction, target_id in room.exits.items():
                target = dungeon.rooms.get(target_id)
                if target and target.visited:
                    dx, dy = direction.value
                    # Draw corridor
                    if direction == Direction.SOUTH and target.y <= max_y:
                        # Vertical corridor going down
                        for i in range(1, cell_height):
                            cy = gy + cell_height - 1 + i
                            cx = gx + cell_width // 2
                            if cy < map_height and grid[cy][cx] == ' ':
                                grid[cy][cx] = "│" if use_unicode else "|"
                    elif direction == Direction.EAST and target.x <= max_x:
                        # Horizontal corridor going right
                        for i in range(1, cell_width):
                            cy = gy + cell_height // 2
                            cx = gx + cell_width - 1 + i
                            if cx < map_width and grid[cy][cx] == ' ':
                                grid[cy][cx] = "─" if use_unicode else "-"

    # Convert grid to string
    lines = ["".join(row).rstrip() for row in grid]

    # Remove empty lines from top and bottom
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()

    # Build final output with header and legend
    output = []
    output.append(f"╔{'═' * 40}╗")
    output.append(f"║{'DUNGEON MAP':^40}║")
    output.append(f"║{dungeon.name[:38]:^40}║")
    output.append(f"╠{'═' * 40}╣")

    for line in lines:
        padded = f"  {line}"
        if len(padded) < 40:
            padded = padded + " " * (40 - len(padded))
        output.append(f"║{padded[:40]}║")

    output.append(f"╠{'═' * 40}╣")
    output.append(f"║ Legend:                                ║")
    output.append(f"║  [@] You   [!] Danger   [$] Treasure   ║")
    output.append(f"║  [E] Entry [B] Boss     [+] Rest       ║")
    output.append(f"╚{'═' * 40}╝")

    return "\n".join(output)


def render_combat_scene(party: list, enemies: list) -> str:
    """Render a combat scene with party vs enemies."""
    lines = []
    lines.append("╔" + "═" * 60 + "╗")
    lines.append("║" + " COMBAT ".center(60) + "║")
    lines.append("╠" + "═" * 60 + "╣")

    # Show party on left, enemies on right
    party_lines = []
    enemy_lines = []

    for char in party[:2]:  # Show up to 2 party members
        art = render_mini_character(char.name, char.current_hp, char.max_hp, True)
        party_lines.extend(art)

    for enemy in enemies[:2]:  # Show up to 2 enemies
        art = render_mini_character(enemy.name, enemy.current_hp, enemy.max_hp, False)
        enemy_lines.extend(art)

    # Combine
    max_lines = max(len(party_lines), len(enemy_lines), 1)

    for i in range(max_lines):
        left = party_lines[i] if i < len(party_lines) else " " * 25
        right = enemy_lines[i] if i < len(enemy_lines) else " " * 25
        vs = " VS " if i == max_lines // 2 else "    "
        lines.append(f"║ {left:25}{vs}{right:25}  ║")

    lines.append("╚" + "═" * 60 + "╝")
    return "\n".join(lines)


def render_mini_character(name: str, hp: int, max_hp: int, is_ally: bool) -> List[str]:
    """Render a small character representation."""
    hp_pct = hp / max_hp if max_hp > 0 else 0
    bar_width = 15
    filled = int(hp_pct * bar_width)
    bar = "█" * filled + "░" * (bar_width - filled)

    if is_ally:
        icon = "☺" if hp > 0 else "☠"
    else:
        icon = "☻" if hp > 0 else "☠"

    return [
        f"  {icon} {name[:18]:18}",
        f"  [{bar}]",
        f"   {hp:3d}/{max_hp:3d} HP",
        "",
    ]
