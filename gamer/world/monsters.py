"""Monster stat blocks for D&D 5e."""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any
import uuid

from ..characters.abilities import Ability


@dataclass
class MonsterAction:
    """An action a monster can take."""
    name: str
    description: str
    attack_bonus: int = 0
    damage: str = ""  # e.g., "2d6+3"
    damage_type: str = ""
    reach: int = 5  # feet
    is_ranged: bool = False
    range: int = 0  # for ranged attacks


@dataclass
class MonsterTrait:
    """A special trait or ability."""
    name: str
    description: str


@dataclass
class Monster:
    """A monster stat block."""
    name: str
    size: str  # Tiny, Small, Medium, Large, Huge, Gargantuan
    monster_type: str  # beast, humanoid, undead, etc.
    alignment: str
    ac: int
    max_hp: int
    speed: int
    cr: float  # Challenge Rating

    # Ability scores
    strength: int = 10
    dexterity: int = 10
    constitution: int = 10
    intelligence: int = 10
    wisdom: int = 10
    charisma: int = 10

    # Combat
    actions: List[MonsterAction] = field(default_factory=list)
    traits: List[MonsterTrait] = field(default_factory=list)

    # Proficiencies
    saving_throws: List[str] = field(default_factory=list)  # e.g., ["dex", "wis"]
    skills: Dict[str, int] = field(default_factory=dict)  # skill: bonus

    # Resistances/immunities
    damage_resistances: List[str] = field(default_factory=list)
    damage_immunities: List[str] = field(default_factory=list)
    condition_immunities: List[str] = field(default_factory=list)

    # Senses
    darkvision: int = 0
    passive_perception: int = 10

    # Languages
    languages: List[str] = field(default_factory=list)

    # XP reward
    xp: int = 0

    # Instance state
    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    current_hp: int = 0

    def __post_init__(self):
        if self.current_hp == 0:
            self.current_hp = self.max_hp

    @property
    def str_modifier(self) -> int:
        return (self.strength - 10) // 2

    @property
    def dex_modifier(self) -> int:
        return (self.dexterity - 10) // 2

    @property
    def con_modifier(self) -> int:
        return (self.constitution - 10) // 2

    @property
    def int_modifier(self) -> int:
        return (self.intelligence - 10) // 2

    @property
    def wis_modifier(self) -> int:
        return (self.wisdom - 10) // 2

    @property
    def cha_modifier(self) -> int:
        return (self.charisma - 10) // 2

    @property
    def armor_class(self) -> int:
        return self.ac

    @property
    def is_alive(self) -> bool:
        return self.current_hp > 0

    @property
    def proficiency_bonus(self) -> int:
        """Calculate proficiency bonus from CR."""
        if self.cr < 5:
            return 2
        elif self.cr < 9:
            return 3
        elif self.cr < 13:
            return 4
        elif self.cr < 17:
            return 5
        else:
            return 6

    def take_damage(self, amount: int) -> Dict[str, Any]:
        """Take damage."""
        old_hp = self.current_hp
        self.current_hp = max(0, self.current_hp - amount)
        return {
            'damage_taken': old_hp - self.current_hp,
            'knocked_unconscious': old_hp > 0 and self.current_hp == 0,
            'instant_death': False,
            'temp_hp_absorbed': 0,
        }

    def heal(self, amount: int) -> int:
        """Heal HP."""
        old_hp = self.current_hp
        self.current_hp = min(self.max_hp, self.current_hp + amount)
        return self.current_hp - old_hp

    def get_primary_attack(self) -> Optional[MonsterAction]:
        """Get the monster's primary attack action."""
        if self.actions:
            return self.actions[0]
        return None

    def get_saving_throw_modifier(self, ability: Ability) -> int:
        """Get modifier for a saving throw."""
        ability_mod = {
            Ability.STRENGTH: self.str_modifier,
            Ability.DEXTERITY: self.dex_modifier,
            Ability.CONSTITUTION: self.con_modifier,
            Ability.INTELLIGENCE: self.int_modifier,
            Ability.WISDOM: self.wis_modifier,
            Ability.CHARISMA: self.cha_modifier,
        }.get(ability, 0)

        # Check for proficiency
        ability_short = ability.value.lower()
        if ability_short in self.saving_throws:
            return ability_mod + self.proficiency_bonus
        return ability_mod

    def to_dict(self) -> Dict:
        """Convert to dictionary."""
        return {
            'name': self.name,
            'id': self.id,
            'current_hp': self.current_hp,
            'max_hp': self.max_hp,
        }

    def copy(self) -> 'Monster':
        """Create a copy with a new ID."""
        import copy
        new_monster = copy.deepcopy(self)
        new_monster.id = str(uuid.uuid4())
        new_monster.current_hp = new_monster.max_hp
        return new_monster


# Monster database
MONSTERS: Dict[str, Monster] = {}


def _register_monster(monster: Monster) -> None:
    """Register a monster in the database."""
    MONSTERS[monster.name.lower()] = monster


# CR 0 - 1/8
_register_monster(Monster(
    name="Kobold",
    size="Small",
    monster_type="humanoid",
    alignment="lawful evil",
    ac=12,
    max_hp=5,
    speed=30,
    cr=0.125,
    strength=7, dexterity=15, constitution=9, intelligence=8, wisdom=7, charisma=8,
    darkvision=60,
    passive_perception=8,
    languages=["Common", "Draconic"],
    xp=25,
    traits=[
        MonsterTrait("Sunlight Sensitivity", "Disadvantage on attacks and Perception in sunlight."),
        MonsterTrait("Pack Tactics", "Advantage on attacks if ally is within 5 ft of target."),
    ],
    actions=[
        MonsterAction("Dagger", "Melee or ranged attack", attack_bonus=4, damage="1d4+2", damage_type="piercing"),
        MonsterAction("Sling", "Ranged attack", attack_bonus=4, damage="1d4+2", damage_type="bludgeoning", is_ranged=True, range=30),
    ],
))

_register_monster(Monster(
    name="Giant Rat",
    size="Small",
    monster_type="beast",
    alignment="unaligned",
    ac=12,
    max_hp=7,
    speed=30,
    cr=0.125,
    strength=7, dexterity=15, constitution=11, intelligence=2, wisdom=10, charisma=4,
    darkvision=60,
    passive_perception=10,
    xp=25,
    traits=[
        MonsterTrait("Keen Smell", "Advantage on Perception checks using smell."),
        MonsterTrait("Pack Tactics", "Advantage on attacks if ally is within 5 ft of target."),
    ],
    actions=[
        MonsterAction("Bite", "Melee attack", attack_bonus=4, damage="1d4+2", damage_type="piercing"),
    ],
))

# CR 1/4
_register_monster(Monster(
    name="Goblin",
    size="Small",
    monster_type="humanoid",
    alignment="neutral evil",
    ac=15,
    max_hp=7,
    speed=30,
    cr=0.25,
    strength=8, dexterity=14, constitution=10, intelligence=10, wisdom=8, charisma=8,
    skills={"stealth": 6},
    darkvision=60,
    passive_perception=9,
    languages=["Common", "Goblin"],
    xp=50,
    traits=[
        MonsterTrait("Nimble Escape", "Can Disengage or Hide as bonus action."),
    ],
    actions=[
        MonsterAction("Scimitar", "Melee attack", attack_bonus=4, damage="1d6+2", damage_type="slashing"),
        MonsterAction("Shortbow", "Ranged attack", attack_bonus=4, damage="1d6+2", damage_type="piercing", is_ranged=True, range=80),
    ],
))

_register_monster(Monster(
    name="Skeleton",
    size="Medium",
    monster_type="undead",
    alignment="lawful evil",
    ac=13,
    max_hp=13,
    speed=30,
    cr=0.25,
    strength=10, dexterity=14, constitution=15, intelligence=6, wisdom=8, charisma=5,
    damage_immunities=["poison"],
    condition_immunities=["exhaustion", "poisoned"],
    darkvision=60,
    passive_perception=9,
    languages=["understands languages it knew in life"],
    xp=50,
    actions=[
        MonsterAction("Shortsword", "Melee attack", attack_bonus=4, damage="1d6+2", damage_type="piercing"),
        MonsterAction("Shortbow", "Ranged attack", attack_bonus=4, damage="1d6+2", damage_type="piercing", is_ranged=True, range=80),
    ],
))

_register_monster(Monster(
    name="Zombie",
    size="Medium",
    monster_type="undead",
    alignment="neutral evil",
    ac=8,
    max_hp=22,
    speed=20,
    cr=0.25,
    strength=13, dexterity=6, constitution=16, intelligence=3, wisdom=6, charisma=5,
    saving_throws=["wis"],
    damage_immunities=["poison"],
    condition_immunities=["poisoned"],
    darkvision=60,
    passive_perception=8,
    languages=["understands languages it knew in life"],
    xp=50,
    traits=[
        MonsterTrait("Undead Fortitude", "If damage reduces zombie to 0 HP, CON save (DC 5 + damage) to drop to 1 HP instead. Doesn't work for radiant or critical hits."),
    ],
    actions=[
        MonsterAction("Slam", "Melee attack", attack_bonus=3, damage="1d6+1", damage_type="bludgeoning"),
    ],
))

# CR 1/2
_register_monster(Monster(
    name="Orc",
    size="Medium",
    monster_type="humanoid",
    alignment="chaotic evil",
    ac=13,
    max_hp=15,
    speed=30,
    cr=0.5,
    strength=16, dexterity=12, constitution=16, intelligence=7, wisdom=11, charisma=10,
    skills={"intimidation": 2},
    darkvision=60,
    passive_perception=10,
    languages=["Common", "Orc"],
    xp=100,
    traits=[
        MonsterTrait("Aggressive", "Bonus action to move up to speed toward hostile creature."),
    ],
    actions=[
        MonsterAction("Greataxe", "Melee attack", attack_bonus=5, damage="1d12+3", damage_type="slashing"),
        MonsterAction("Javelin", "Melee or ranged attack", attack_bonus=5, damage="1d6+3", damage_type="piercing", is_ranged=True, range=30),
    ],
))

_register_monster(Monster(
    name="Hobgoblin",
    size="Medium",
    monster_type="humanoid",
    alignment="lawful evil",
    ac=18,
    max_hp=11,
    speed=30,
    cr=0.5,
    strength=13, dexterity=12, constitution=12, intelligence=10, wisdom=10, charisma=9,
    darkvision=60,
    passive_perception=10,
    languages=["Common", "Goblin"],
    xp=100,
    traits=[
        MonsterTrait("Martial Advantage", "Once per turn, +2d6 damage if ally is within 5 ft of target."),
    ],
    actions=[
        MonsterAction("Longsword", "Melee attack", attack_bonus=3, damage="1d10+1", damage_type="slashing"),
        MonsterAction("Longbow", "Ranged attack", attack_bonus=3, damage="1d8+1", damage_type="piercing", is_ranged=True, range=150),
    ],
))

# CR 1
_register_monster(Monster(
    name="Bugbear",
    size="Medium",
    monster_type="humanoid",
    alignment="chaotic evil",
    ac=16,
    max_hp=27,
    speed=30,
    cr=1,
    strength=15, dexterity=14, constitution=13, intelligence=8, wisdom=11, charisma=9,
    skills={"stealth": 6, "survival": 2},
    darkvision=60,
    passive_perception=10,
    languages=["Common", "Goblin"],
    xp=200,
    traits=[
        MonsterTrait("Brute", "Melee weapon deals one extra die of damage."),
        MonsterTrait("Surprise Attack", "+2d6 damage if target is surprised in first round."),
    ],
    actions=[
        MonsterAction("Morningstar", "Melee attack", attack_bonus=4, damage="2d8+2", damage_type="piercing"),
        MonsterAction("Javelin", "Melee or ranged attack", attack_bonus=4, damage="2d6+2", damage_type="piercing", is_ranged=True, range=30),
    ],
))

_register_monster(Monster(
    name="Ghoul",
    size="Medium",
    monster_type="undead",
    alignment="chaotic evil",
    ac=12,
    max_hp=22,
    speed=30,
    cr=1,
    strength=13, dexterity=15, constitution=10, intelligence=7, wisdom=10, charisma=6,
    damage_immunities=["poison"],
    condition_immunities=["charmed", "exhaustion", "poisoned"],
    darkvision=60,
    passive_perception=10,
    languages=["Common"],
    xp=200,
    actions=[
        MonsterAction("Bite", "Melee attack", attack_bonus=2, damage="2d6+2", damage_type="piercing"),
        MonsterAction("Claws", "Melee attack, DC 10 CON save or paralyzed 1 min", attack_bonus=4, damage="2d4+2", damage_type="slashing"),
    ],
))

# CR 2
_register_monster(Monster(
    name="Ogre",
    size="Large",
    monster_type="giant",
    alignment="chaotic evil",
    ac=11,
    max_hp=59,
    speed=40,
    cr=2,
    strength=19, dexterity=8, constitution=16, intelligence=5, wisdom=7, charisma=7,
    darkvision=60,
    passive_perception=8,
    languages=["Common", "Giant"],
    xp=450,
    actions=[
        MonsterAction("Greatclub", "Melee attack", attack_bonus=6, damage="2d8+4", damage_type="bludgeoning", reach=5),
        MonsterAction("Javelin", "Melee or ranged attack", attack_bonus=6, damage="2d6+4", damage_type="piercing", is_ranged=True, range=30),
    ],
))

_register_monster(Monster(
    name="Gnoll",
    size="Medium",
    monster_type="humanoid",
    alignment="chaotic evil",
    ac=15,
    max_hp=22,
    speed=30,
    cr=0.5,
    strength=14, dexterity=12, constitution=11, intelligence=6, wisdom=10, charisma=7,
    darkvision=60,
    passive_perception=10,
    languages=["Gnoll"],
    xp=100,
    traits=[
        MonsterTrait("Rampage", "When reduces creature to 0 HP, bonus action to move and bite."),
    ],
    actions=[
        MonsterAction("Bite", "Melee attack", attack_bonus=4, damage="1d4+2", damage_type="piercing"),
        MonsterAction("Spear", "Melee or ranged attack", attack_bonus=4, damage="1d6+2", damage_type="piercing", is_ranged=True, range=20),
        MonsterAction("Longbow", "Ranged attack", attack_bonus=3, damage="1d8+1", damage_type="piercing", is_ranged=True, range=150),
    ],
))

# CR 3
_register_monster(Monster(
    name="Owlbear",
    size="Large",
    monster_type="monstrosity",
    alignment="unaligned",
    ac=13,
    max_hp=59,
    speed=40,
    cr=3,
    strength=20, dexterity=12, constitution=17, intelligence=3, wisdom=12, charisma=7,
    skills={"perception": 3},
    darkvision=60,
    passive_perception=13,
    xp=700,
    traits=[
        MonsterTrait("Keen Sight and Smell", "Advantage on Perception checks using sight or smell."),
    ],
    actions=[
        MonsterAction("Beak", "Melee attack", attack_bonus=7, damage="1d10+5", damage_type="piercing"),
        MonsterAction("Claws", "Melee attack", attack_bonus=7, damage="2d8+5", damage_type="slashing"),
    ],
))

_register_monster(Monster(
    name="Minotaur",
    size="Large",
    monster_type="monstrosity",
    alignment="chaotic evil",
    ac=14,
    max_hp=76,
    speed=40,
    cr=3,
    strength=18, dexterity=11, constitution=16, intelligence=6, wisdom=16, charisma=9,
    skills={"perception": 7},
    darkvision=60,
    passive_perception=17,
    languages=["Abyssal"],
    xp=700,
    traits=[
        MonsterTrait("Charge", "If moves 10+ ft straight then hits with gore, +2d8 damage and DC 14 STR save or knocked prone."),
        MonsterTrait("Labyrinthine Recall", "Can perfectly recall any path it has traveled."),
        MonsterTrait("Reckless", "At start of turn, can gain advantage on all melee attacks but attacks against it have advantage."),
    ],
    actions=[
        MonsterAction("Greataxe", "Melee attack", attack_bonus=6, damage="2d12+4", damage_type="slashing"),
        MonsterAction("Gore", "Melee attack", attack_bonus=6, damage="2d8+4", damage_type="piercing"),
    ],
))


def get_monster(name: str) -> Optional[Monster]:
    """Get a monster by name. Returns a new instance."""
    template = MONSTERS.get(name.lower())
    if template:
        return template.copy()
    return None


def get_monsters_by_cr(cr: float) -> List[Monster]:
    """Get all monsters of a specific CR."""
    return [m for m in MONSTERS.values() if m.cr == cr]


def get_monsters_by_cr_range(min_cr: float, max_cr: float) -> List[Monster]:
    """Get all monsters within a CR range."""
    return [m for m in MONSTERS.values() if min_cr <= m.cr <= max_cr]


def get_all_monsters() -> List[Monster]:
    """Get all monsters."""
    return list(MONSTERS.values())


def get_monster_names() -> List[str]:
    """Get all monster names."""
    return [m.name for m in MONSTERS.values()]
