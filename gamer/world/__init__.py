"""World modules for dungeon, encounters, monsters, items, and NPCs."""

from .monsters import Monster, get_monster, get_monsters_by_cr
from .items import Item, Weapon, Armor, get_item, get_weapon, get_armor
from .dungeon import Dungeon, Room, generate_dungeon
from .encounters import Encounter, generate_encounter, calculate_difficulty
from .npcs import NPC, generate_npc

__all__ = [
    'Monster', 'get_monster', 'get_monsters_by_cr',
    'Item', 'Weapon', 'Armor', 'get_item', 'get_weapon', 'get_armor',
    'Dungeon', 'Room', 'generate_dungeon',
    'Encounter', 'generate_encounter', 'calculate_difficulty',
    'NPC', 'generate_npc',
]
