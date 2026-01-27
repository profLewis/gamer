"""Combat actions for D&D 5e."""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any, Callable
from enum import Enum, auto


class ActionType(Enum):
    """Types of actions in combat."""
    ACTION = auto()
    BONUS_ACTION = auto()
    REACTION = auto()
    MOVEMENT = auto()
    FREE_ACTION = auto()


class ActionCategory(Enum):
    """Categories of combat actions."""
    ATTACK = "Attack"
    CAST_SPELL = "Cast a Spell"
    DASH = "Dash"
    DISENGAGE = "Disengage"
    DODGE = "Dodge"
    HELP = "Help"
    HIDE = "Hide"
    READY = "Ready"
    SEARCH = "Search"
    USE_OBJECT = "Use an Object"
    GRAPPLE = "Grapple"
    SHOVE = "Shove"
    OTHER = "Other"


@dataclass
class ActionResult:
    """Result of a combat action."""
    success: bool
    description: str
    damage_dealt: int = 0
    damage_type: str = ""
    healing_done: int = 0
    target_id: Optional[str] = None
    conditions_applied: List[str] = field(default_factory=list)
    conditions_removed: List[str] = field(default_factory=list)
    spell_used: Optional[str] = None
    slot_used: int = 0
    critical: bool = False
    roll_details: Dict[str, Any] = field(default_factory=dict)


@dataclass
class CombatAction:
    """A combat action that can be taken."""
    name: str
    action_type: ActionType
    category: ActionCategory
    description: str
    requires_target: bool = True
    range_feet: int = 5  # Melee range by default

    def to_dict(self) -> Dict:
        """Convert to dictionary."""
        return {
            'name': self.name,
            'action_type': self.action_type.name,
            'category': self.category.value,
            'description': self.description,
            'requires_target': self.requires_target,
            'range_feet': self.range_feet,
        }


# Standard actions available to all characters
STANDARD_ACTIONS: Dict[str, CombatAction] = {
    'attack': CombatAction(
        name="Attack",
        action_type=ActionType.ACTION,
        category=ActionCategory.ATTACK,
        description="Make a melee or ranged attack against a target.",
        requires_target=True,
    ),
    'dash': CombatAction(
        name="Dash",
        action_type=ActionType.ACTION,
        category=ActionCategory.DASH,
        description="Double your movement speed for this turn.",
        requires_target=False,
    ),
    'disengage': CombatAction(
        name="Disengage",
        action_type=ActionType.ACTION,
        category=ActionCategory.DISENGAGE,
        description="Your movement doesn't provoke opportunity attacks this turn.",
        requires_target=False,
    ),
    'dodge': CombatAction(
        name="Dodge",
        action_type=ActionType.ACTION,
        category=ActionCategory.DODGE,
        description="Until your next turn, attacks against you have disadvantage and you have advantage on DEX saves.",
        requires_target=False,
    ),
    'help': CombatAction(
        name="Help",
        action_type=ActionType.ACTION,
        category=ActionCategory.HELP,
        description="Give an ally advantage on their next ability check or attack roll.",
        requires_target=True,
    ),
    'hide': CombatAction(
        name="Hide",
        action_type=ActionType.ACTION,
        category=ActionCategory.HIDE,
        description="Make a Stealth check to hide from enemies.",
        requires_target=False,
    ),
    'ready': CombatAction(
        name="Ready",
        action_type=ActionType.ACTION,
        category=ActionCategory.READY,
        description="Prepare an action to trigger on a specific condition.",
        requires_target=False,
    ),
    'search': CombatAction(
        name="Search",
        action_type=ActionType.ACTION,
        category=ActionCategory.SEARCH,
        description="Make a Perception or Investigation check.",
        requires_target=False,
    ),
    'use_object': CombatAction(
        name="Use Object",
        action_type=ActionType.ACTION,
        category=ActionCategory.USE_OBJECT,
        description="Interact with an object that requires your action.",
        requires_target=False,
    ),
    'grapple': CombatAction(
        name="Grapple",
        action_type=ActionType.ACTION,
        category=ActionCategory.GRAPPLE,
        description="Attempt to grapple a creature (replaces one attack).",
        requires_target=True,
    ),
    'shove': CombatAction(
        name="Shove",
        action_type=ActionType.ACTION,
        category=ActionCategory.SHOVE,
        description="Shove a creature prone or away from you (replaces one attack).",
        requires_target=True,
    ),
}


# Class-specific bonus actions
CLASS_BONUS_ACTIONS: Dict[str, List[CombatAction]] = {
    'rogue': [
        CombatAction(
            name="Cunning Action: Dash",
            action_type=ActionType.BONUS_ACTION,
            category=ActionCategory.DASH,
            description="Use your cunning to Dash as a bonus action.",
            requires_target=False,
        ),
        CombatAction(
            name="Cunning Action: Disengage",
            action_type=ActionType.BONUS_ACTION,
            category=ActionCategory.DISENGAGE,
            description="Use your cunning to Disengage as a bonus action.",
            requires_target=False,
        ),
        CombatAction(
            name="Cunning Action: Hide",
            action_type=ActionType.BONUS_ACTION,
            category=ActionCategory.HIDE,
            description="Use your cunning to Hide as a bonus action.",
            requires_target=False,
        ),
    ],
    'fighter': [
        CombatAction(
            name="Second Wind",
            action_type=ActionType.BONUS_ACTION,
            category=ActionCategory.OTHER,
            description="Regain 1d10 + fighter level HP (once per short rest).",
            requires_target=False,
        ),
    ],
    'barbarian': [
        CombatAction(
            name="Rage",
            action_type=ActionType.BONUS_ACTION,
            category=ActionCategory.OTHER,
            description="Enter a rage: +2 damage, resistance to physical damage, advantage on STR checks.",
            requires_target=False,
        ),
    ],
}


# Weapon data for damage calculation
WEAPON_DATA: Dict[str, Dict[str, Any]] = {
    'longsword': {'damage': '1d8', 'type': 'slashing', 'properties': ['versatile']},
    'shortsword': {'damage': '1d6', 'type': 'piercing', 'properties': ['finesse', 'light']},
    'greatsword': {'damage': '2d6', 'type': 'slashing', 'properties': ['two-handed', 'heavy']},
    'greataxe': {'damage': '1d12', 'type': 'slashing', 'properties': ['two-handed', 'heavy']},
    'rapier': {'damage': '1d8', 'type': 'piercing', 'properties': ['finesse']},
    'dagger': {'damage': '1d4', 'type': 'piercing', 'properties': ['finesse', 'light', 'thrown']},
    'handaxe': {'damage': '1d6', 'type': 'slashing', 'properties': ['light', 'thrown']},
    'javelin': {'damage': '1d6', 'type': 'piercing', 'properties': ['thrown']},
    'mace': {'damage': '1d6', 'type': 'bludgeoning', 'properties': []},
    'quarterstaff': {'damage': '1d6', 'type': 'bludgeoning', 'properties': ['versatile']},
    'warhammer': {'damage': '1d8', 'type': 'bludgeoning', 'properties': ['versatile']},
    'battleaxe': {'damage': '1d8', 'type': 'slashing', 'properties': ['versatile']},
    'longbow': {'damage': '1d8', 'type': 'piercing', 'properties': ['two-handed', 'ammunition'], 'range': 150},
    'shortbow': {'damage': '1d6', 'type': 'piercing', 'properties': ['two-handed', 'ammunition'], 'range': 80},
    'light_crossbow': {'damage': '1d8', 'type': 'piercing', 'properties': ['two-handed', 'ammunition', 'loading'], 'range': 80},
    'hand_crossbow': {'damage': '1d6', 'type': 'piercing', 'properties': ['light', 'ammunition', 'loading'], 'range': 30},
}


def get_weapon_data(weapon_name: str) -> Dict[str, Any]:
    """Get weapon data, returning defaults for unknown weapons."""
    # Normalize weapon name
    key = weapon_name.lower().replace(' ', '_')

    # Check direct match
    if key in WEAPON_DATA:
        return WEAPON_DATA[key]

    # Check partial matches
    for weapon_key, data in WEAPON_DATA.items():
        if weapon_key in key or key in weapon_key:
            return data

    # Default melee weapon
    return {'damage': '1d4', 'type': 'bludgeoning', 'properties': []}


def is_finesse_weapon(weapon_name: str) -> bool:
    """Check if a weapon has the finesse property."""
    data = get_weapon_data(weapon_name)
    return 'finesse' in data.get('properties', [])


def is_ranged_weapon(weapon_name: str) -> bool:
    """Check if a weapon is ranged."""
    data = get_weapon_data(weapon_name)
    return 'ammunition' in data.get('properties', []) or 'thrown' in data.get('properties', [])


def get_weapon_range(weapon_name: str) -> int:
    """Get weapon range in feet."""
    data = get_weapon_data(weapon_name)
    return data.get('range', 5)


class ActionEconomy:
    """Tracks available actions for a turn."""

    def __init__(self):
        """Initialize with all actions available."""
        self.action_available = True
        self.bonus_action_available = True
        self.reaction_available = True
        self.movement_remaining = 0
        self.extra_attacks = 0  # For Extra Attack feature

    def set_movement(self, speed: int, is_dashing: bool = False) -> None:
        """Set available movement for the turn."""
        self.movement_remaining = speed * 2 if is_dashing else speed

    def use_action(self) -> bool:
        """Use the action. Returns True if successful."""
        if self.action_available:
            self.action_available = False
            return True
        return False

    def use_bonus_action(self) -> bool:
        """Use the bonus action. Returns True if successful."""
        if self.bonus_action_available:
            self.bonus_action_available = False
            return True
        return False

    def use_reaction(self) -> bool:
        """Use the reaction. Returns True if successful."""
        if self.reaction_available:
            self.reaction_available = False
            return True
        return False

    def use_movement(self, feet: int) -> bool:
        """Use movement. Returns True if successful."""
        if feet <= self.movement_remaining:
            self.movement_remaining -= feet
            return True
        return False

    def reset(self) -> None:
        """Reset for a new turn."""
        self.action_available = True
        self.bonus_action_available = True
        # Reaction resets at start of your turn
        self.reaction_available = True
        self.movement_remaining = 0
        self.extra_attacks = 0

    def reset_reaction(self) -> None:
        """Reset just the reaction (at start of turn)."""
        self.reaction_available = True

    def get_available_actions(self) -> Dict[str, bool]:
        """Get status of all action types."""
        return {
            'action': self.action_available,
            'bonus_action': self.bonus_action_available,
            'reaction': self.reaction_available,
            'movement': self.movement_remaining,
            'extra_attacks': self.extra_attacks,
        }

    def to_dict(self) -> Dict:
        """Convert to dictionary."""
        return {
            'action_available': self.action_available,
            'bonus_action_available': self.bonus_action_available,
            'reaction_available': self.reaction_available,
            'movement_remaining': self.movement_remaining,
            'extra_attacks': self.extra_attacks,
        }

    @classmethod
    def from_dict(cls, data: Dict) -> 'ActionEconomy':
        """Create from dictionary."""
        economy = cls()
        economy.action_available = data['action_available']
        economy.bonus_action_available = data['bonus_action_available']
        economy.reaction_available = data['reaction_available']
        economy.movement_remaining = data['movement_remaining']
        economy.extra_attacks = data.get('extra_attacks', 0)
        return economy
