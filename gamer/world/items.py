"""Items, weapons, armor, and equipment for D&D 5e."""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any
from enum import Enum


class ItemRarity(Enum):
    """Item rarity levels."""
    COMMON = "Common"
    UNCOMMON = "Uncommon"
    RARE = "Rare"
    VERY_RARE = "Very Rare"
    LEGENDARY = "Legendary"


class DamageType(Enum):
    """Types of damage."""
    BLUDGEONING = "bludgeoning"
    PIERCING = "piercing"
    SLASHING = "slashing"
    FIRE = "fire"
    COLD = "cold"
    LIGHTNING = "lightning"
    THUNDER = "thunder"
    ACID = "acid"
    POISON = "poison"
    NECROTIC = "necrotic"
    RADIANT = "radiant"
    FORCE = "force"
    PSYCHIC = "psychic"


@dataclass
class Item:
    """A generic item."""
    name: str
    description: str
    weight: float = 0  # pounds
    value: int = 0  # gold pieces
    rarity: ItemRarity = ItemRarity.COMMON
    magical: bool = False
    consumable: bool = False
    charges: int = 0
    max_charges: int = 0

    def to_dict(self) -> Dict:
        return {
            'name': self.name,
            'description': self.description,
            'weight': self.weight,
            'value': self.value,
            'rarity': self.rarity.value,
            'magical': self.magical,
            'consumable': self.consumable,
            'charges': self.charges,
            'max_charges': self.max_charges,
        }


@dataclass
class Weapon(Item):
    """A weapon."""
    damage: str = "1d4"  # dice notation
    damage_type: DamageType = DamageType.BLUDGEONING
    properties: List[str] = field(default_factory=list)
    range_normal: int = 5  # feet
    range_long: int = 0  # feet, 0 if melee
    versatile_damage: str = ""  # damage when used two-handed

    @property
    def is_finesse(self) -> bool:
        return "finesse" in self.properties

    @property
    def is_ranged(self) -> bool:
        return "ammunition" in self.properties or self.range_long > 0

    @property
    def is_two_handed(self) -> bool:
        return "two-handed" in self.properties

    @property
    def is_light(self) -> bool:
        return "light" in self.properties

    def to_dict(self) -> Dict:
        data = super().to_dict()
        data.update({
            'damage': self.damage,
            'damage_type': self.damage_type.value,
            'properties': self.properties,
            'range_normal': self.range_normal,
            'range_long': self.range_long,
            'versatile_damage': self.versatile_damage,
        })
        return data


@dataclass
class Armor(Item):
    """Armor and shields."""
    ac_base: int = 10
    ac_dex_bonus: bool = True  # whether to add DEX mod
    ac_max_dex: Optional[int] = None  # max DEX bonus, None for no limit
    strength_requirement: int = 0
    stealth_disadvantage: bool = False
    armor_type: str = "light"  # light, medium, heavy, shield

    def calculate_ac(self, dex_modifier: int) -> int:
        """Calculate AC with this armor."""
        if self.armor_type == "shield":
            return 2  # Shield bonus

        if not self.ac_dex_bonus:
            return self.ac_base

        dex_bonus = dex_modifier
        if self.ac_max_dex is not None:
            dex_bonus = min(dex_modifier, self.ac_max_dex)

        return self.ac_base + dex_bonus

    def to_dict(self) -> Dict:
        data = super().to_dict()
        data.update({
            'ac_base': self.ac_base,
            'ac_dex_bonus': self.ac_dex_bonus,
            'ac_max_dex': self.ac_max_dex,
            'strength_requirement': self.strength_requirement,
            'stealth_disadvantage': self.stealth_disadvantage,
            'armor_type': self.armor_type,
        })
        return data


@dataclass
class Potion(Item):
    """A potion or consumable."""
    effect: str = ""
    healing: str = ""  # dice for healing, e.g., "2d4+2"

    def __post_init__(self):
        self.consumable = True


@dataclass
class Treasure:
    """Treasure and valuables."""
    gold: int = 0
    silver: int = 0
    copper: int = 0
    gems: List[Dict[str, Any]] = field(default_factory=list)
    art_objects: List[Dict[str, Any]] = field(default_factory=list)
    items: List[Item] = field(default_factory=list)

    @property
    def total_gold_value(self) -> float:
        """Calculate total value in gold."""
        total = self.gold + self.silver / 10 + self.copper / 100
        total += sum(g.get('value', 0) for g in self.gems)
        total += sum(a.get('value', 0) for a in self.art_objects)
        total += sum(i.value for i in self.items)
        return total


# Item databases
WEAPONS: Dict[str, Weapon] = {}
ARMORS: Dict[str, Armor] = {}
ITEMS: Dict[str, Item] = {}


def _register_weapon(weapon: Weapon) -> None:
    WEAPONS[weapon.name.lower()] = weapon


def _register_armor(armor: Armor) -> None:
    ARMORS[armor.name.lower()] = armor


def _register_item(item: Item) -> None:
    ITEMS[item.name.lower()] = item


# Simple Melee Weapons
_register_weapon(Weapon(
    name="Club",
    description="A simple wooden club.",
    damage="1d4", damage_type=DamageType.BLUDGEONING,
    properties=["light"],
    weight=2, value=0.1,
))

_register_weapon(Weapon(
    name="Dagger",
    description="A small blade for close combat or throwing.",
    damage="1d4", damage_type=DamageType.PIERCING,
    properties=["finesse", "light", "thrown"],
    range_normal=5, range_long=20,
    weight=1, value=2,
))

_register_weapon(Weapon(
    name="Greatclub",
    description="A large, heavy club.",
    damage="1d8", damage_type=DamageType.BLUDGEONING,
    properties=["two-handed"],
    weight=10, value=0.2,
))

_register_weapon(Weapon(
    name="Handaxe",
    description="A light axe that can be thrown.",
    damage="1d6", damage_type=DamageType.SLASHING,
    properties=["light", "thrown"],
    range_normal=5, range_long=20,
    weight=2, value=5,
))

_register_weapon(Weapon(
    name="Javelin",
    description="A light spear designed for throwing.",
    damage="1d6", damage_type=DamageType.PIERCING,
    properties=["thrown"],
    range_normal=5, range_long=30,
    weight=2, value=0.5,
))

_register_weapon(Weapon(
    name="Light Hammer",
    description="A small hammer that can be thrown.",
    damage="1d4", damage_type=DamageType.BLUDGEONING,
    properties=["light", "thrown"],
    range_normal=5, range_long=20,
    weight=2, value=2,
))

_register_weapon(Weapon(
    name="Mace",
    description="A heavy club with a metal head.",
    damage="1d6", damage_type=DamageType.BLUDGEONING,
    properties=[],
    weight=4, value=5,
))

_register_weapon(Weapon(
    name="Quarterstaff",
    description="A versatile wooden staff.",
    damage="1d6", damage_type=DamageType.BLUDGEONING,
    properties=["versatile"],
    versatile_damage="1d8",
    weight=4, value=0.2,
))

_register_weapon(Weapon(
    name="Spear",
    description="A simple polearm.",
    damage="1d6", damage_type=DamageType.PIERCING,
    properties=["thrown", "versatile"],
    range_normal=5, range_long=20,
    versatile_damage="1d8",
    weight=3, value=1,
))

# Simple Ranged Weapons
_register_weapon(Weapon(
    name="Light Crossbow",
    description="A mechanical bow that fires bolts.",
    damage="1d8", damage_type=DamageType.PIERCING,
    properties=["ammunition", "loading", "two-handed"],
    range_normal=80, range_long=320,
    weight=5, value=25,
))

_register_weapon(Weapon(
    name="Shortbow",
    description="A small, simple bow.",
    damage="1d6", damage_type=DamageType.PIERCING,
    properties=["ammunition", "two-handed"],
    range_normal=80, range_long=320,
    weight=2, value=25,
))

# Martial Melee Weapons
_register_weapon(Weapon(
    name="Battleaxe",
    description="A large axe designed for combat.",
    damage="1d8", damage_type=DamageType.SLASHING,
    properties=["versatile"],
    versatile_damage="1d10",
    weight=4, value=10,
))

_register_weapon(Weapon(
    name="Greataxe",
    description="A massive two-handed axe.",
    damage="1d12", damage_type=DamageType.SLASHING,
    properties=["heavy", "two-handed"],
    weight=7, value=30,
))

_register_weapon(Weapon(
    name="Greatsword",
    description="A large two-handed sword.",
    damage="2d6", damage_type=DamageType.SLASHING,
    properties=["heavy", "two-handed"],
    weight=6, value=50,
))

_register_weapon(Weapon(
    name="Longsword",
    description="A versatile one-handed sword.",
    damage="1d8", damage_type=DamageType.SLASHING,
    properties=["versatile"],
    versatile_damage="1d10",
    weight=3, value=15,
))

_register_weapon(Weapon(
    name="Rapier",
    description="A slender thrusting sword.",
    damage="1d8", damage_type=DamageType.PIERCING,
    properties=["finesse"],
    weight=2, value=25,
))

_register_weapon(Weapon(
    name="Scimitar",
    description="A curved blade favored by sailors.",
    damage="1d6", damage_type=DamageType.SLASHING,
    properties=["finesse", "light"],
    weight=3, value=25,
))

_register_weapon(Weapon(
    name="Shortsword",
    description="A short, versatile blade.",
    damage="1d6", damage_type=DamageType.PIERCING,
    properties=["finesse", "light"],
    weight=2, value=10,
))

_register_weapon(Weapon(
    name="Warhammer",
    description="A heavy hammer for combat.",
    damage="1d8", damage_type=DamageType.BLUDGEONING,
    properties=["versatile"],
    versatile_damage="1d10",
    weight=2, value=15,
))

# Martial Ranged Weapons
_register_weapon(Weapon(
    name="Hand Crossbow",
    description="A small crossbow that can be used one-handed.",
    damage="1d6", damage_type=DamageType.PIERCING,
    properties=["ammunition", "light", "loading"],
    range_normal=30, range_long=120,
    weight=3, value=75,
))

_register_weapon(Weapon(
    name="Heavy Crossbow",
    description="A powerful mechanical crossbow.",
    damage="1d10", damage_type=DamageType.PIERCING,
    properties=["ammunition", "heavy", "loading", "two-handed"],
    range_normal=100, range_long=400,
    weight=18, value=50,
))

_register_weapon(Weapon(
    name="Longbow",
    description="A tall bow with excellent range.",
    damage="1d8", damage_type=DamageType.PIERCING,
    properties=["ammunition", "heavy", "two-handed"],
    range_normal=150, range_long=600,
    weight=2, value=50,
))

# Light Armor
_register_armor(Armor(
    name="Padded",
    description="Quilted layers of cloth and batting.",
    ac_base=11, ac_dex_bonus=True,
    stealth_disadvantage=True,
    armor_type="light",
    weight=8, value=5,
))

_register_armor(Armor(
    name="Leather",
    description="Basic leather armor.",
    ac_base=11, ac_dex_bonus=True,
    armor_type="light",
    weight=10, value=10,
))

_register_armor(Armor(
    name="Studded Leather",
    description="Leather reinforced with metal rivets.",
    ac_base=12, ac_dex_bonus=True,
    armor_type="light",
    weight=13, value=45,
))

# Medium Armor
_register_armor(Armor(
    name="Hide",
    description="Crude armor made from thick hides.",
    ac_base=12, ac_dex_bonus=True, ac_max_dex=2,
    armor_type="medium",
    weight=12, value=10,
))

_register_armor(Armor(
    name="Chain Shirt",
    description="A shirt of interlocking metal rings.",
    ac_base=13, ac_dex_bonus=True, ac_max_dex=2,
    armor_type="medium",
    weight=20, value=50,
))

_register_armor(Armor(
    name="Scale Mail",
    description="Armor made of overlapping metal scales.",
    ac_base=14, ac_dex_bonus=True, ac_max_dex=2,
    stealth_disadvantage=True,
    armor_type="medium",
    weight=45, value=50,
))

_register_armor(Armor(
    name="Breastplate",
    description="A fitted metal chest piece.",
    ac_base=14, ac_dex_bonus=True, ac_max_dex=2,
    armor_type="medium",
    weight=20, value=400,
))

_register_armor(Armor(
    name="Half Plate",
    description="Partial plate armor covering vital areas.",
    ac_base=15, ac_dex_bonus=True, ac_max_dex=2,
    stealth_disadvantage=True,
    armor_type="medium",
    weight=40, value=750,
))

# Heavy Armor
_register_armor(Armor(
    name="Ring Mail",
    description="Leather armor with metal rings sewn on.",
    ac_base=14, ac_dex_bonus=False,
    stealth_disadvantage=True,
    armor_type="heavy",
    weight=40, value=30,
))

_register_armor(Armor(
    name="Chain Mail",
    description="Full suit of interlocking metal rings.",
    ac_base=16, ac_dex_bonus=False,
    strength_requirement=13,
    stealth_disadvantage=True,
    armor_type="heavy",
    weight=55, value=75,
))

_register_armor(Armor(
    name="Splint",
    description="Armor made of metal strips.",
    ac_base=17, ac_dex_bonus=False,
    strength_requirement=15,
    stealth_disadvantage=True,
    armor_type="heavy",
    weight=60, value=200,
))

_register_armor(Armor(
    name="Plate",
    description="Full suit of plate armor.",
    ac_base=18, ac_dex_bonus=False,
    strength_requirement=15,
    stealth_disadvantage=True,
    armor_type="heavy",
    weight=65, value=1500,
))

# Shield
_register_armor(Armor(
    name="Shield",
    description="A wooden or metal shield.",
    ac_base=2, ac_dex_bonus=False,
    armor_type="shield",
    weight=6, value=10,
))

# Adventuring Gear
_register_item(Item(
    name="Torch",
    description="Provides bright light in 20-foot radius, dim light for 20 more. Burns for 1 hour.",
    weight=1, value=0.01,
))

_register_item(Item(
    name="Rope (50 feet)",
    description="Hemp rope, 50 feet.",
    weight=10, value=1,
))

_register_item(Item(
    name="Rations (1 day)",
    description="Dried food for one day.",
    weight=2, value=0.5, consumable=True,
))

_register_item(Item(
    name="Waterskin",
    description="Holds 4 pints of liquid.",
    weight=5, value=0.2,
))

_register_item(Item(
    name="Backpack",
    description="Can hold 1 cubic foot or 30 pounds of gear.",
    weight=5, value=2,
))

_register_item(Item(
    name="Bedroll",
    description="A sleeping roll for camping.",
    weight=7, value=1,
))

_register_item(Item(
    name="Tinderbox",
    description="Flint, fire steel, and tinder for starting fires.",
    weight=1, value=0.5,
))

_register_item(Item(
    name="Thieves' Tools",
    description="A set of lockpicks and tools for disabling traps.",
    weight=1, value=25,
))

_register_item(Item(
    name="Holy Symbol",
    description="A symbol of a deity.",
    weight=1, value=5,
))

_register_item(Item(
    name="Component Pouch",
    description="A pouch for spell components.",
    weight=2, value=25,
))

# Potions
POTIONS: Dict[str, Potion] = {}


def _register_potion(potion: Potion) -> None:
    POTIONS[potion.name.lower()] = potion


_register_potion(Potion(
    name="Potion of Healing",
    description="Regain 2d4+2 hit points.",
    healing="2d4+2",
    effect="healing",
    weight=0.5, value=50,
    rarity=ItemRarity.COMMON,
    magical=True,
))

_register_potion(Potion(
    name="Potion of Greater Healing",
    description="Regain 4d4+4 hit points.",
    healing="4d4+4",
    effect="healing",
    weight=0.5, value=150,
    rarity=ItemRarity.UNCOMMON,
    magical=True,
))

_register_potion(Potion(
    name="Antitoxin",
    description="Advantage on saves vs. poison for 1 hour.",
    effect="poison_resistance",
    weight=0, value=50,
))


def get_weapon(name: str) -> Optional[Weapon]:
    """Get a weapon by name."""
    return WEAPONS.get(name.lower())


def get_armor(name: str) -> Optional[Armor]:
    """Get armor by name."""
    return ARMORS.get(name.lower())


def get_item(name: str) -> Optional[Item]:
    """Get an item by name."""
    return ITEMS.get(name.lower())


def get_potion(name: str) -> Optional[Potion]:
    """Get a potion by name."""
    return POTIONS.get(name.lower())


def get_all_weapons() -> List[Weapon]:
    """Get all weapons."""
    return list(WEAPONS.values())


def get_all_armors() -> List[Armor]:
    """Get all armor."""
    return list(ARMORS.values())


def get_all_items() -> List[Item]:
    """Get all items."""
    return list(ITEMS.values())
