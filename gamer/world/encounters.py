"""Encounter generation and balancing for D&D 5e."""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple
from enum import Enum
import random

from .monsters import Monster, get_monster, get_monsters_by_cr_range, MONSTERS


class Difficulty(Enum):
    """Encounter difficulty levels."""
    EASY = "Easy"
    MEDIUM = "Medium"
    HARD = "Hard"
    DEADLY = "Deadly"


# XP thresholds by character level
XP_THRESHOLDS: Dict[int, Dict[Difficulty, int]] = {
    1: {Difficulty.EASY: 25, Difficulty.MEDIUM: 50, Difficulty.HARD: 75, Difficulty.DEADLY: 100},
    2: {Difficulty.EASY: 50, Difficulty.MEDIUM: 100, Difficulty.HARD: 150, Difficulty.DEADLY: 200},
    3: {Difficulty.EASY: 75, Difficulty.MEDIUM: 150, Difficulty.HARD: 225, Difficulty.DEADLY: 400},
    4: {Difficulty.EASY: 125, Difficulty.MEDIUM: 250, Difficulty.HARD: 375, Difficulty.DEADLY: 500},
    5: {Difficulty.EASY: 250, Difficulty.MEDIUM: 500, Difficulty.HARD: 750, Difficulty.DEADLY: 1100},
}

# XP by CR
CR_XP: Dict[float, int] = {
    0: 10,
    0.125: 25,
    0.25: 50,
    0.5: 100,
    1: 200,
    2: 450,
    3: 700,
    4: 1100,
    5: 1800,
}

# Encounter multipliers based on number of monsters
ENCOUNTER_MULTIPLIERS: Dict[Tuple[int, int], float] = {
    (1, 1): 1.0,
    (2, 2): 1.5,
    (3, 6): 2.0,
    (7, 10): 2.5,
    (11, 14): 3.0,
    (15, 999): 4.0,
}


def get_xp_threshold(level: int, difficulty: Difficulty) -> int:
    """Get XP threshold for a character level and difficulty."""
    if level > 5:
        level = 5  # Cap at level 5 for now
    return XP_THRESHOLDS.get(level, XP_THRESHOLDS[1]).get(difficulty, 0)


def get_party_threshold(party_levels: List[int], difficulty: Difficulty) -> int:
    """Get total XP threshold for a party."""
    return sum(get_xp_threshold(level, difficulty) for level in party_levels)


def get_cr_xp(cr: float) -> int:
    """Get XP value for a CR."""
    return CR_XP.get(cr, int(cr * 200))


def get_encounter_multiplier(num_monsters: int) -> float:
    """Get the encounter multiplier for a number of monsters."""
    for (min_count, max_count), multiplier in ENCOUNTER_MULTIPLIERS.items():
        if min_count <= num_monsters <= max_count:
            return multiplier
    return 4.0


@dataclass
class Encounter:
    """A combat encounter."""
    monsters: List[Monster] = field(default_factory=list)
    difficulty: Difficulty = Difficulty.MEDIUM
    total_xp: int = 0
    adjusted_xp: int = 0
    description: str = ""

    def add_monster(self, monster: Monster) -> None:
        """Add a monster to the encounter."""
        self.monsters.append(monster)
        self._recalculate_xp()

    def _recalculate_xp(self) -> None:
        """Recalculate total and adjusted XP."""
        self.total_xp = sum(get_cr_xp(m.cr) for m in self.monsters)
        multiplier = get_encounter_multiplier(len(self.monsters))
        self.adjusted_xp = int(self.total_xp * multiplier)

    def get_xp_reward(self) -> int:
        """Get XP reward for defeating this encounter."""
        return self.total_xp  # Reward is base XP, not adjusted

    def to_dict(self) -> Dict:
        """Convert to dictionary."""
        return {
            'monsters': [m.to_dict() for m in self.monsters],
            'difficulty': self.difficulty.value,
            'total_xp': self.total_xp,
            'adjusted_xp': self.adjusted_xp,
            'description': self.description,
        }


def calculate_difficulty(party_levels: List[int], monsters: List[Monster]) -> Difficulty:
    """Calculate encounter difficulty for a party against monsters."""
    if not monsters:
        return Difficulty.EASY

    # Calculate adjusted XP
    total_xp = sum(get_cr_xp(m.cr) for m in monsters)
    multiplier = get_encounter_multiplier(len(monsters))
    adjusted_xp = int(total_xp * multiplier)

    # Compare to thresholds
    thresholds = {
        diff: get_party_threshold(party_levels, diff)
        for diff in Difficulty
    }

    if adjusted_xp >= thresholds[Difficulty.DEADLY]:
        return Difficulty.DEADLY
    elif adjusted_xp >= thresholds[Difficulty.HARD]:
        return Difficulty.HARD
    elif adjusted_xp >= thresholds[Difficulty.MEDIUM]:
        return Difficulty.MEDIUM
    else:
        return Difficulty.EASY


def generate_encounter(
    party_levels: List[int],
    difficulty: Difficulty = Difficulty.MEDIUM,
    environment: str = "dungeon",
    monster_types: Optional[List[str]] = None
) -> Encounter:
    """
    Generate a balanced encounter for a party.

    Args:
        party_levels: List of character levels in the party
        difficulty: Target difficulty
        environment: Environment type (affects monster selection)
        monster_types: Optional filter for monster types
    """
    encounter = Encounter(difficulty=difficulty)

    # Calculate target XP range
    target_xp = get_party_threshold(party_levels, difficulty)
    min_xp = int(target_xp * 0.7)
    max_xp = int(target_xp * 1.3)

    # Get average party level to determine appropriate CR range
    avg_level = sum(party_levels) / len(party_levels)

    # CR range based on party level and difficulty
    if difficulty == Difficulty.EASY:
        max_cr = avg_level * 0.25
    elif difficulty == Difficulty.MEDIUM:
        max_cr = avg_level * 0.5
    elif difficulty == Difficulty.HARD:
        max_cr = avg_level * 0.75
    else:  # Deadly
        max_cr = avg_level

    max_cr = max(0.125, min(max_cr, 5))  # Clamp between 1/8 and 5

    # Get available monsters
    available = get_monsters_by_cr_range(0, max_cr)

    # Filter by type if specified
    if monster_types:
        available = [m for m in available if m.monster_type in monster_types]

    if not available:
        # Fallback to any low-CR monster
        available = get_monsters_by_cr_range(0, 1)

    if not available:
        # Ultimate fallback
        available = list(MONSTERS.values())[:5]

    # Build encounter
    current_xp = 0
    attempts = 0
    max_attempts = 50

    while current_xp < min_xp and attempts < max_attempts:
        # Pick a random monster
        monster_template = random.choice(available)

        # Check if adding it would exceed max
        new_monster = monster_template.copy()
        test_monsters = encounter.monsters + [new_monster]
        test_xp = sum(get_cr_xp(m.cr) for m in test_monsters)
        test_multiplier = get_encounter_multiplier(len(test_monsters))
        test_adjusted = int(test_xp * test_multiplier)

        if test_adjusted <= max_xp:
            encounter.add_monster(new_monster)
            current_xp = encounter.adjusted_xp
        else:
            # Try a weaker monster
            weaker = [m for m in available if get_cr_xp(m.cr) < get_cr_xp(monster_template.cr)]
            if weaker:
                available = weaker

        attempts += 1

    # Set description
    if len(encounter.monsters) == 1:
        encounter.description = f"A lone {encounter.monsters[0].name} blocks your path!"
    elif len(set(m.name for m in encounter.monsters)) == 1:
        encounter.description = f"A group of {len(encounter.monsters)} {encounter.monsters[0].name}s attacks!"
    else:
        monster_names = list(set(m.name for m in encounter.monsters))
        encounter.description = f"You face {', '.join(monster_names)}!"

    return encounter


def generate_boss_encounter(
    party_levels: List[int],
    boss_name: Optional[str] = None
) -> Encounter:
    """Generate a boss encounter with optional minions."""
    encounter = Encounter(difficulty=Difficulty.DEADLY)

    # Calculate target XP for deadly encounter
    target_xp = get_party_threshold(party_levels, Difficulty.DEADLY)

    # Get average party level
    avg_level = sum(party_levels) / len(party_levels)

    # Select or find boss
    if boss_name:
        boss = get_monster(boss_name)
    else:
        # Find a suitable boss based on party level
        boss_cr = avg_level * 0.75
        candidates = get_monsters_by_cr_range(boss_cr - 0.5, boss_cr + 1)
        if candidates:
            boss = random.choice(candidates).copy()
        else:
            # Fallback to strongest available
            all_monsters = list(MONSTERS.values())
            boss = max(all_monsters, key=lambda m: m.cr).copy()

    if boss:
        encounter.add_monster(boss)

        # Maybe add minions
        remaining_xp = target_xp - encounter.adjusted_xp
        if remaining_xp > 50:
            # Add some weaker minions
            minion_cr = max(0.125, boss.cr * 0.25)
            minions = get_monsters_by_cr_range(0, minion_cr)
            if minions:
                minion_template = random.choice(minions)
                num_minions = min(4, remaining_xp // get_cr_xp(minion_template.cr))
                for _ in range(int(num_minions)):
                    encounter.add_monster(minion_template.copy())

        encounter.description = f"The {boss.name} awaits with its minions!"

    return encounter


# Encounter templates for specific scenarios
ENCOUNTER_TEMPLATES: Dict[str, List[Dict]] = {
    "goblin_ambush": [
        {"monster": "goblin", "count": (3, 6)},
    ],
    "undead_crypt": [
        {"monster": "skeleton", "count": (2, 4)},
        {"monster": "zombie", "count": (1, 2)},
    ],
    "orc_patrol": [
        {"monster": "orc", "count": (2, 4)},
    ],
    "beast_den": [
        {"monster": "giant_rat", "count": (4, 8)},
    ],
    "bugbear_hideout": [
        {"monster": "bugbear", "count": (1, 2)},
        {"monster": "goblin", "count": (2, 4)},
    ],
}


def generate_encounter_from_template(template_name: str) -> Optional[Encounter]:
    """Generate an encounter from a template."""
    template = ENCOUNTER_TEMPLATES.get(template_name)
    if not template:
        return None

    encounter = Encounter()

    for entry in template:
        monster = get_monster(entry["monster"])
        if monster:
            min_count, max_count = entry["count"]
            count = random.randint(min_count, max_count)
            for _ in range(count):
                encounter.add_monster(monster.copy())

    encounter.difficulty = Difficulty.MEDIUM  # Templates are designed for medium
    return encounter
