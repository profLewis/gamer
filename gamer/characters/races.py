"""D&D 5e races with traits and ability bonuses."""

from dataclasses import dataclass, field
from typing import Dict, List, Optional
from enum import Enum


class Size(Enum):
    """Creature sizes in D&D 5e."""
    TINY = "Tiny"
    SMALL = "Small"
    MEDIUM = "Medium"
    LARGE = "Large"
    HUGE = "Huge"
    GARGANTUAN = "Gargantuan"


@dataclass
class RacialTrait:
    """A racial trait or feature."""
    name: str
    description: str


@dataclass
class Race:
    """A D&D 5e race."""
    name: str
    size: Size
    speed: int
    ability_bonuses: Dict[str, int]
    traits: List[RacialTrait] = field(default_factory=list)
    languages: List[str] = field(default_factory=list)
    darkvision: int = 0  # Range in feet, 0 if none
    subrace: Optional[str] = None
    skill_proficiencies: List[str] = field(default_factory=list)
    weapon_proficiencies: List[str] = field(default_factory=list)
    armor_proficiencies: List[str] = field(default_factory=list)
    tool_proficiencies: List[str] = field(default_factory=list)
    damage_resistances: List[str] = field(default_factory=list)
    cantrips: List[str] = field(default_factory=list)

    def get_full_name(self) -> str:
        """Get the full race name including subrace."""
        if self.subrace:
            return f"{self.subrace} {self.name}"
        return self.name

    def to_dict(self) -> Dict:
        """Convert to dictionary for serialization."""
        return {
            'name': self.name,
            'subrace': self.subrace,
            'size': self.size.value,
            'speed': self.speed,
            'ability_bonuses': self.ability_bonuses,
            'traits': [{'name': t.name, 'description': t.description} for t in self.traits],
            'languages': self.languages,
            'darkvision': self.darkvision,
            'skill_proficiencies': self.skill_proficiencies,
            'weapon_proficiencies': self.weapon_proficiencies,
            'armor_proficiencies': self.armor_proficiencies,
            'tool_proficiencies': self.tool_proficiencies,
            'damage_resistances': self.damage_resistances,
            'cantrips': self.cantrips,
        }


# Define all races
RACES: Dict[str, Race] = {}


def _register_race(race: Race) -> None:
    """Register a race in the RACES dictionary."""
    key = race.get_full_name().lower().replace(' ', '_')
    RACES[key] = race


# Human
_register_race(Race(
    name="Human",
    size=Size.MEDIUM,
    speed=30,
    ability_bonuses={'str': 1, 'dex': 1, 'con': 1, 'int': 1, 'wis': 1, 'cha': 1},
    languages=["Common", "Choice"],
    traits=[
        RacialTrait("Versatile", "Humans gain +1 to all ability scores.")
    ]
))

# High Elf
_register_race(Race(
    name="Elf",
    subrace="High",
    size=Size.MEDIUM,
    speed=30,
    ability_bonuses={'dex': 2, 'int': 1},
    darkvision=60,
    languages=["Common", "Elvish", "Choice"],
    traits=[
        RacialTrait("Fey Ancestry", "Advantage on saves vs. charm, immunity to magic sleep."),
        RacialTrait("Trance", "Elves don't sleep. They meditate for 4 hours."),
        RacialTrait("Keen Senses", "Proficiency in Perception."),
        RacialTrait("Cantrip", "You know one cantrip from the wizard spell list."),
    ],
    skill_proficiencies=["perception"],
    weapon_proficiencies=["longsword", "shortsword", "shortbow", "longbow"],
))

# Wood Elf
_register_race(Race(
    name="Elf",
    subrace="Wood",
    size=Size.MEDIUM,
    speed=35,
    ability_bonuses={'dex': 2, 'wis': 1},
    darkvision=60,
    languages=["Common", "Elvish"],
    traits=[
        RacialTrait("Fey Ancestry", "Advantage on saves vs. charm, immunity to magic sleep."),
        RacialTrait("Trance", "Elves don't sleep. They meditate for 4 hours."),
        RacialTrait("Keen Senses", "Proficiency in Perception."),
        RacialTrait("Fleet of Foot", "Base walking speed is 35 feet."),
        RacialTrait("Mask of the Wild", "Can attempt to hide in light natural obscurement."),
    ],
    skill_proficiencies=["perception"],
    weapon_proficiencies=["longsword", "shortsword", "shortbow", "longbow"],
))

# Hill Dwarf
_register_race(Race(
    name="Dwarf",
    subrace="Hill",
    size=Size.MEDIUM,
    speed=25,
    ability_bonuses={'con': 2, 'wis': 1},
    darkvision=60,
    languages=["Common", "Dwarvish"],
    traits=[
        RacialTrait("Dwarven Resilience", "Advantage on saves vs. poison, resistance to poison damage."),
        RacialTrait("Stonecunning", "Double proficiency on History checks related to stonework."),
        RacialTrait("Dwarven Toughness", "HP maximum increases by 1 per level."),
    ],
    weapon_proficiencies=["battleaxe", "handaxe", "light_hammer", "warhammer"],
    tool_proficiencies=["smith's_tools", "brewer's_supplies", "mason's_tools"],
    damage_resistances=["poison"],
))

# Mountain Dwarf
_register_race(Race(
    name="Dwarf",
    subrace="Mountain",
    size=Size.MEDIUM,
    speed=25,
    ability_bonuses={'con': 2, 'str': 2},
    darkvision=60,
    languages=["Common", "Dwarvish"],
    traits=[
        RacialTrait("Dwarven Resilience", "Advantage on saves vs. poison, resistance to poison damage."),
        RacialTrait("Stonecunning", "Double proficiency on History checks related to stonework."),
        RacialTrait("Dwarven Armor Training", "Proficiency with light and medium armor."),
    ],
    weapon_proficiencies=["battleaxe", "handaxe", "light_hammer", "warhammer"],
    armor_proficiencies=["light", "medium"],
    tool_proficiencies=["smith's_tools", "brewer's_supplies", "mason's_tools"],
    damage_resistances=["poison"],
))

# Lightfoot Halfling
_register_race(Race(
    name="Halfling",
    subrace="Lightfoot",
    size=Size.SMALL,
    speed=25,
    ability_bonuses={'dex': 2, 'cha': 1},
    languages=["Common", "Halfling"],
    traits=[
        RacialTrait("Lucky", "Reroll 1s on d20 rolls."),
        RacialTrait("Brave", "Advantage on saves vs. frightened."),
        RacialTrait("Halfling Nimbleness", "Move through space of larger creatures."),
        RacialTrait("Naturally Stealthy", "Can hide behind creatures one size larger."),
    ],
))

# Stout Halfling
_register_race(Race(
    name="Halfling",
    subrace="Stout",
    size=Size.SMALL,
    speed=25,
    ability_bonuses={'dex': 2, 'con': 1},
    languages=["Common", "Halfling"],
    traits=[
        RacialTrait("Lucky", "Reroll 1s on d20 rolls."),
        RacialTrait("Brave", "Advantage on saves vs. frightened."),
        RacialTrait("Halfling Nimbleness", "Move through space of larger creatures."),
        RacialTrait("Stout Resilience", "Advantage on saves vs. poison, resistance to poison damage."),
    ],
    damage_resistances=["poison"],
))

# Half-Elf
_register_race(Race(
    name="Half-Elf",
    size=Size.MEDIUM,
    speed=30,
    ability_bonuses={'cha': 2},  # Plus 2 other +1s of choice
    darkvision=60,
    languages=["Common", "Elvish", "Choice"],
    traits=[
        RacialTrait("Fey Ancestry", "Advantage on saves vs. charm, immunity to magic sleep."),
        RacialTrait("Skill Versatility", "Proficiency in two skills of your choice."),
        RacialTrait("Ability Score Increase", "+1 to two ability scores of your choice."),
    ],
))

# Half-Orc
_register_race(Race(
    name="Half-Orc",
    size=Size.MEDIUM,
    speed=30,
    ability_bonuses={'str': 2, 'con': 1},
    darkvision=60,
    languages=["Common", "Orc"],
    traits=[
        RacialTrait("Menacing", "Proficiency in Intimidation."),
        RacialTrait("Relentless Endurance", "Drop to 1 HP instead of 0 once per long rest."),
        RacialTrait("Savage Attacks", "Extra damage die on critical melee hits."),
    ],
    skill_proficiencies=["intimidation"],
))

# Gnome (Rock)
_register_race(Race(
    name="Gnome",
    subrace="Rock",
    size=Size.SMALL,
    speed=25,
    ability_bonuses={'int': 2, 'con': 1},
    darkvision=60,
    languages=["Common", "Gnomish"],
    traits=[
        RacialTrait("Gnome Cunning", "Advantage on INT, WIS, CHA saves vs. magic."),
        RacialTrait("Artificer's Lore", "Double proficiency on magic item History checks."),
        RacialTrait("Tinker", "Can create tiny clockwork devices."),
    ],
))

# Tiefling
_register_race(Race(
    name="Tiefling",
    size=Size.MEDIUM,
    speed=30,
    ability_bonuses={'cha': 2, 'int': 1},
    darkvision=60,
    languages=["Common", "Infernal"],
    traits=[
        RacialTrait("Hellish Resistance", "Resistance to fire damage."),
        RacialTrait("Infernal Legacy", "Know Thaumaturgy cantrip. At 3rd level, cast Hellish Rebuke once per day. At 5th level, cast Darkness once per day."),
    ],
    damage_resistances=["fire"],
    cantrips=["thaumaturgy"],
))

# Dragonborn
_register_race(Race(
    name="Dragonborn",
    size=Size.MEDIUM,
    speed=30,
    ability_bonuses={'str': 2, 'cha': 1},
    languages=["Common", "Draconic"],
    traits=[
        RacialTrait("Draconic Ancestry", "Choose a dragon type for breath weapon and resistance."),
        RacialTrait("Breath Weapon", "Exhale destructive energy as an action."),
        RacialTrait("Damage Resistance", "Resistance to damage type of your draconic ancestry."),
    ],
))


def get_race(name: str) -> Optional[Race]:
    """Get a race by name."""
    key = name.lower().replace(' ', '_')
    return RACES.get(key)


def get_all_races() -> List[Race]:
    """Get all available races."""
    return list(RACES.values())


def get_race_names() -> List[str]:
    """Get all race names."""
    return [race.get_full_name() for race in RACES.values()]
