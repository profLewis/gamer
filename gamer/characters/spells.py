"""D&D 5e spell system with spell slots and casting."""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Set
from enum import Enum

from .abilities import Ability


class SpellSchool(Enum):
    """Schools of magic in D&D 5e."""
    ABJURATION = "Abjuration"
    CONJURATION = "Conjuration"
    DIVINATION = "Divination"
    ENCHANTMENT = "Enchantment"
    EVOCATION = "Evocation"
    ILLUSION = "Illusion"
    NECROMANCY = "Necromancy"
    TRANSMUTATION = "Transmutation"


class CastingTime(Enum):
    """Spell casting times."""
    ACTION = "1 action"
    BONUS_ACTION = "1 bonus action"
    REACTION = "1 reaction"
    MINUTE_1 = "1 minute"
    MINUTE_10 = "10 minutes"
    HOUR_1 = "1 hour"


class SpellRange(Enum):
    """Common spell ranges."""
    SELF = "Self"
    TOUCH = "Touch"
    FEET_5 = "5 feet"
    FEET_10 = "10 feet"
    FEET_30 = "30 feet"
    FEET_60 = "60 feet"
    FEET_90 = "90 feet"
    FEET_120 = "120 feet"
    FEET_150 = "150 feet"
    UNLIMITED = "Unlimited"


@dataclass
class Spell:
    """A D&D 5e spell."""
    name: str
    level: int  # 0 for cantrips
    school: SpellSchool
    casting_time: CastingTime
    range: str  # Can be SpellRange value or custom
    components: str  # V, S, M (material)
    duration: str
    description: str
    damage_dice: str = ""  # e.g., "1d10", "8d6"
    damage_type: str = ""
    saving_throw: Optional[Ability] = None
    concentration: bool = False
    ritual: bool = False
    classes: List[str] = field(default_factory=list)
    higher_levels: str = ""  # Effect when cast at higher level

    def is_cantrip(self) -> bool:
        """Check if this is a cantrip."""
        return self.level == 0

    def to_dict(self) -> Dict:
        """Convert to dictionary."""
        return {
            'name': self.name,
            'level': self.level,
            'school': self.school.value,
            'casting_time': self.casting_time.value,
            'range': self.range,
            'components': self.components,
            'duration': self.duration,
            'description': self.description,
            'damage_dice': self.damage_dice,
            'damage_type': self.damage_type,
            'saving_throw': self.saving_throw.value if self.saving_throw else None,
            'concentration': self.concentration,
            'ritual': self.ritual,
            'classes': self.classes,
            'higher_levels': self.higher_levels,
        }


# Spell database
SPELLS: Dict[str, Spell] = {}


def _register_spell(spell: Spell) -> None:
    """Register a spell in the database."""
    SPELLS[spell.name.lower()] = spell


# Cantrips
_register_spell(Spell(
    name="Fire Bolt",
    level=0,
    school=SpellSchool.EVOCATION,
    casting_time=CastingTime.ACTION,
    range="120 feet",
    components="V, S",
    duration="Instantaneous",
    description="Hurl a mote of fire at a creature or object. Make a ranged spell attack. On hit, target takes 1d10 fire damage.",
    damage_dice="1d10",
    damage_type="fire",
    classes=["wizard"],
    higher_levels="Damage increases by 1d10 at 5th, 11th, and 17th level.",
))

_register_spell(Spell(
    name="Sacred Flame",
    level=0,
    school=SpellSchool.EVOCATION,
    casting_time=CastingTime.ACTION,
    range="60 feet",
    components="V, S",
    duration="Instantaneous",
    description="Flame-like radiance descends on a creature. Target must succeed on DEX save or take 1d8 radiant damage. No benefit from cover.",
    damage_dice="1d8",
    damage_type="radiant",
    saving_throw=Ability.DEXTERITY,
    classes=["cleric"],
    higher_levels="Damage increases by 1d8 at 5th, 11th, and 17th level.",
))

_register_spell(Spell(
    name="Light",
    level=0,
    school=SpellSchool.EVOCATION,
    casting_time=CastingTime.ACTION,
    range="Touch",
    components="V, M (a firefly or phosphorescent moss)",
    duration="1 hour",
    description="Touch one object no larger than 10 feet. It sheds bright light in 20-foot radius, dim light for additional 20 feet.",
    classes=["cleric", "wizard"],
))

_register_spell(Spell(
    name="Mage Hand",
    level=0,
    school=SpellSchool.CONJURATION,
    casting_time=CastingTime.ACTION,
    range="30 feet",
    components="V, S",
    duration="1 minute",
    description="A spectral hand appears. Use it to manipulate objects, open doors, retrieve items. Cannot attack or activate magic items.",
    classes=["wizard"],
))

_register_spell(Spell(
    name="Minor Illusion",
    level=0,
    school=SpellSchool.ILLUSION,
    casting_time=CastingTime.ACTION,
    range="30 feet",
    components="S, M (a bit of fleece)",
    duration="1 minute",
    description="Create a sound or image of an object. Investigation check vs spell save DC reveals illusion.",
    classes=["wizard"],
))

_register_spell(Spell(
    name="Thaumaturgy",
    level=0,
    school=SpellSchool.TRANSMUTATION,
    casting_time=CastingTime.ACTION,
    range="30 feet",
    components="V",
    duration="Up to 1 minute",
    description="Minor magical effects: amplify voice, cause flames to flicker, cause tremors, create sounds, etc.",
    classes=["cleric"],
))

_register_spell(Spell(
    name="Ray of Frost",
    level=0,
    school=SpellSchool.EVOCATION,
    casting_time=CastingTime.ACTION,
    range="60 feet",
    components="V, S",
    duration="Instantaneous",
    description="Frigid beam strikes creature. Make ranged spell attack. On hit, 1d8 cold damage and speed reduced by 10 until your next turn.",
    damage_dice="1d8",
    damage_type="cold",
    classes=["wizard"],
    higher_levels="Damage increases by 1d8 at 5th, 11th, and 17th level.",
))

# Level 1 Spells
_register_spell(Spell(
    name="Magic Missile",
    level=1,
    school=SpellSchool.EVOCATION,
    casting_time=CastingTime.ACTION,
    range="120 feet",
    components="V, S",
    duration="Instantaneous",
    description="Create three glowing darts. Each dart hits a creature of your choice, dealing 1d4+1 force damage.",
    damage_dice="1d4+1",
    damage_type="force",
    classes=["wizard"],
    higher_levels="One additional dart per slot level above 1st.",
))

_register_spell(Spell(
    name="Shield",
    level=1,
    school=SpellSchool.ABJURATION,
    casting_time=CastingTime.REACTION,
    range="Self",
    components="V, S",
    duration="1 round",
    description="Reaction when hit by attack or targeted by magic missile. +5 AC until start of your next turn, including vs triggering attack.",
    classes=["wizard"],
))

_register_spell(Spell(
    name="Cure Wounds",
    level=1,
    school=SpellSchool.EVOCATION,
    casting_time=CastingTime.ACTION,
    range="Touch",
    components="V, S",
    duration="Instantaneous",
    description="Creature you touch regains 1d8 + spellcasting modifier HP. No effect on undead or constructs.",
    classes=["cleric", "ranger"],
    higher_levels="Healing increases by 1d8 per slot level above 1st.",
))

_register_spell(Spell(
    name="Healing Word",
    level=1,
    school=SpellSchool.EVOCATION,
    casting_time=CastingTime.BONUS_ACTION,
    range="60 feet",
    components="V",
    duration="Instantaneous",
    description="Creature of your choice that you can see regains 1d4 + spellcasting modifier HP.",
    classes=["cleric"],
    higher_levels="Healing increases by 1d4 per slot level above 1st.",
))

_register_spell(Spell(
    name="Guiding Bolt",
    level=1,
    school=SpellSchool.EVOCATION,
    casting_time=CastingTime.ACTION,
    range="120 feet",
    components="V, S",
    duration="1 round",
    description="Flash of light streaks toward creature. Ranged spell attack deals 4d6 radiant. Next attack against target has advantage.",
    damage_dice="4d6",
    damage_type="radiant",
    classes=["cleric"],
    higher_levels="Damage increases by 1d6 per slot level above 1st.",
))

_register_spell(Spell(
    name="Bless",
    level=1,
    school=SpellSchool.ENCHANTMENT,
    casting_time=CastingTime.ACTION,
    range="30 feet",
    components="V, S, M (holy water)",
    duration="1 minute",
    description="Up to 3 creatures of choice add 1d4 to attack rolls and saving throws.",
    concentration=True,
    classes=["cleric"],
    higher_levels="One additional creature per slot level above 1st.",
))

_register_spell(Spell(
    name="Sleep",
    level=1,
    school=SpellSchool.ENCHANTMENT,
    casting_time=CastingTime.ACTION,
    range="90 feet",
    components="V, S, M (sand or rose petals)",
    duration="1 minute",
    description="Roll 5d8. Creatures in 20-foot radius fall asleep starting from lowest HP until total exceeded.",
    classes=["wizard"],
    higher_levels="Roll additional 2d8 per slot level above 1st.",
))

_register_spell(Spell(
    name="Burning Hands",
    level=1,
    school=SpellSchool.EVOCATION,
    casting_time=CastingTime.ACTION,
    range="Self (15-foot cone)",
    components="V, S",
    duration="Instantaneous",
    description="15-foot cone of fire. DEX save for half. Creatures take 3d6 fire damage.",
    damage_dice="3d6",
    damage_type="fire",
    saving_throw=Ability.DEXTERITY,
    classes=["wizard"],
    higher_levels="Damage increases by 1d6 per slot level above 1st.",
))

_register_spell(Spell(
    name="Thunderwave",
    level=1,
    school=SpellSchool.EVOCATION,
    casting_time=CastingTime.ACTION,
    range="Self (15-foot cube)",
    components="V, S",
    duration="Instantaneous",
    description="Wave of thunder from you. CON save or 2d8 thunder damage and pushed 10 feet. Half on save, no push.",
    damage_dice="2d8",
    damage_type="thunder",
    saving_throw=Ability.CONSTITUTION,
    classes=["wizard"],
    higher_levels="Damage increases by 1d8 per slot level above 1st.",
))

_register_spell(Spell(
    name="Hunter's Mark",
    level=1,
    school=SpellSchool.DIVINATION,
    casting_time=CastingTime.BONUS_ACTION,
    range="90 feet",
    components="V",
    duration="1 hour",
    description="Mark a creature. Deal extra 1d6 damage to it with weapon attacks. Advantage on Perception/Survival to find it.",
    concentration=True,
    classes=["ranger"],
    higher_levels="Duration increases: 8 hours at 3rd, 24 hours at 5th level.",
))

# Level 2 Spells
_register_spell(Spell(
    name="Scorching Ray",
    level=2,
    school=SpellSchool.EVOCATION,
    casting_time=CastingTime.ACTION,
    range="120 feet",
    components="V, S",
    duration="Instantaneous",
    description="Create three rays of fire. Make ranged spell attack for each. On hit, 2d6 fire damage per ray.",
    damage_dice="2d6",
    damage_type="fire",
    classes=["wizard"],
    higher_levels="One additional ray per slot level above 2nd.",
))

_register_spell(Spell(
    name="Hold Person",
    level=2,
    school=SpellSchool.ENCHANTMENT,
    casting_time=CastingTime.ACTION,
    range="60 feet",
    components="V, S, M (small piece of iron)",
    duration="1 minute",
    description="Humanoid must succeed WIS save or be paralyzed. Repeat save at end of each turn.",
    saving_throw=Ability.WISDOM,
    concentration=True,
    classes=["cleric", "wizard"],
    higher_levels="Target one additional humanoid per slot level above 2nd.",
))

_register_spell(Spell(
    name="Spiritual Weapon",
    level=2,
    school=SpellSchool.EVOCATION,
    casting_time=CastingTime.BONUS_ACTION,
    range="60 feet",
    components="V, S",
    duration="1 minute",
    description="Create floating spectral weapon. On cast and as bonus action, melee spell attack for 1d8 + spellcasting mod force damage.",
    damage_dice="1d8",
    damage_type="force",
    classes=["cleric"],
    higher_levels="Damage increases by 1d8 per two slot levels above 2nd.",
))

_register_spell(Spell(
    name="Misty Step",
    level=2,
    school=SpellSchool.CONJURATION,
    casting_time=CastingTime.BONUS_ACTION,
    range="Self",
    components="V",
    duration="Instantaneous",
    description="Teleport up to 30 feet to an unoccupied space you can see.",
    classes=["wizard"],
))

# Level 3 Spells
_register_spell(Spell(
    name="Fireball",
    level=3,
    school=SpellSchool.EVOCATION,
    casting_time=CastingTime.ACTION,
    range="150 feet",
    components="V, S, M (bat guano and sulfur)",
    duration="Instantaneous",
    description="Bright streak to point in range then blossoms. 20-foot radius. DEX save for half. 8d6 fire damage.",
    damage_dice="8d6",
    damage_type="fire",
    saving_throw=Ability.DEXTERITY,
    classes=["wizard"],
    higher_levels="Damage increases by 1d6 per slot level above 3rd.",
))

_register_spell(Spell(
    name="Lightning Bolt",
    level=3,
    school=SpellSchool.EVOCATION,
    casting_time=CastingTime.ACTION,
    range="Self (100-foot line)",
    components="V, S, M (fur and glass rod)",
    duration="Instantaneous",
    description="100-foot long, 5-foot wide line. DEX save for half. 8d6 lightning damage.",
    damage_dice="8d6",
    damage_type="lightning",
    saving_throw=Ability.DEXTERITY,
    classes=["wizard"],
    higher_levels="Damage increases by 1d6 per slot level above 3rd.",
))

_register_spell(Spell(
    name="Spirit Guardians",
    level=3,
    school=SpellSchool.CONJURATION,
    casting_time=CastingTime.ACTION,
    range="Self (15-foot radius)",
    components="V, S, M (holy symbol)",
    duration="10 minutes",
    description="Spirits protect 15-foot radius. Enemies' speed halved. WIS save or 3d8 radiant/necrotic damage when entering or starting turn.",
    damage_dice="3d8",
    damage_type="radiant",
    saving_throw=Ability.WISDOM,
    concentration=True,
    classes=["cleric"],
    higher_levels="Damage increases by 1d8 per slot level above 3rd.",
))

_register_spell(Spell(
    name="Revivify",
    level=3,
    school=SpellSchool.NECROMANCY,
    casting_time=CastingTime.ACTION,
    range="Touch",
    components="V, S, M (diamonds worth 300 gp, consumed)",
    duration="Instantaneous",
    description="Touch creature that died within 1 minute. It returns with 1 HP. Cannot restore missing body parts.",
    classes=["cleric"],
))


class SpellSlotTracker:
    """Tracks available spell slots for a character."""

    def __init__(self, max_slots: Optional[Dict[int, int]] = None):
        """Initialize spell slots."""
        self.max_slots: Dict[int, int] = max_slots or {}
        self.current_slots: Dict[int, int] = dict(self.max_slots)

    def get_slots(self, level: int) -> int:
        """Get current slots at a spell level."""
        return self.current_slots.get(level, 0)

    def get_max_slots(self, level: int) -> int:
        """Get maximum slots at a spell level."""
        return self.max_slots.get(level, 0)

    def use_slot(self, level: int) -> bool:
        """Use a spell slot. Returns True if successful."""
        if self.current_slots.get(level, 0) > 0:
            self.current_slots[level] -= 1
            return True
        return False

    def restore_slot(self, level: int, amount: int = 1) -> None:
        """Restore spell slots."""
        max_slots = self.max_slots.get(level, 0)
        current = self.current_slots.get(level, 0)
        self.current_slots[level] = min(current + amount, max_slots)

    def restore_all(self) -> None:
        """Restore all spell slots (long rest)."""
        self.current_slots = dict(self.max_slots)

    def has_slot(self, level: int) -> bool:
        """Check if a slot is available at this level."""
        return self.current_slots.get(level, 0) > 0

    def get_highest_available_slot(self) -> int:
        """Get highest level slot available."""
        for level in range(9, 0, -1):
            if self.has_slot(level):
                return level
        return 0

    def set_max_slots(self, slots: Dict[int, int]) -> None:
        """Set maximum slots (when leveling up)."""
        self.max_slots = slots
        # Only add new slots, don't reduce current
        for level, max_count in slots.items():
            if level not in self.current_slots:
                self.current_slots[level] = max_count
            elif self.current_slots[level] > max_count:
                self.current_slots[level] = max_count

    def to_dict(self) -> Dict:
        """Convert to dictionary."""
        return {
            'max_slots': self.max_slots,
            'current_slots': self.current_slots,
        }

    @classmethod
    def from_dict(cls, data: Dict) -> 'SpellSlotTracker':
        """Create from dictionary."""
        tracker = cls(data['max_slots'])
        tracker.current_slots = data['current_slots']
        return tracker


class Spellbook:
    """Manages known/prepared spells for a character."""

    def __init__(self, spellcasting_ability: Optional[Ability] = None):
        """Initialize spellbook."""
        self.spellcasting_ability = spellcasting_ability
        self.known_spells: Set[str] = set()  # Spell names (lowercase)
        self.prepared_spells: Set[str] = set()  # Subset of known for prepared casters
        self.cantrips: Set[str] = set()
        self.slot_tracker = SpellSlotTracker()
        self.concentrating_on: Optional[str] = None

    def learn_spell(self, spell_name: str) -> bool:
        """Learn a spell. Returns True if successful."""
        spell = get_spell(spell_name)
        if spell:
            if spell.is_cantrip():
                self.cantrips.add(spell.name.lower())
            else:
                self.known_spells.add(spell.name.lower())
            return True
        return False

    def prepare_spell(self, spell_name: str) -> bool:
        """Prepare a known spell."""
        key = spell_name.lower()
        if key in self.known_spells:
            self.prepared_spells.add(key)
            return True
        return False

    def unprepare_spell(self, spell_name: str) -> None:
        """Unprepare a spell."""
        self.prepared_spells.discard(spell_name.lower())

    def can_cast(self, spell_name: str, slot_level: Optional[int] = None) -> bool:
        """Check if spell can be cast."""
        key = spell_name.lower()
        spell = get_spell(key)
        if not spell:
            return False

        # Cantrips can always be cast
        if spell.is_cantrip() and key in self.cantrips:
            return True

        # Must know/prepare the spell
        if key not in self.known_spells and key not in self.prepared_spells:
            return False

        # Must have an appropriate slot
        cast_level = slot_level or spell.level
        if cast_level < spell.level:
            return False

        return self.slot_tracker.has_slot(cast_level)

    def cast_spell(self, spell_name: str, slot_level: Optional[int] = None) -> Optional[Spell]:
        """Cast a spell, using a slot. Returns the spell if successful."""
        key = spell_name.lower()
        spell = get_spell(key)
        if not spell:
            return None

        # Cantrips don't use slots
        if spell.is_cantrip():
            if key in self.cantrips:
                return spell
            return None

        # Determine slot level
        cast_level = slot_level or spell.level
        if cast_level < spell.level:
            return None

        # Use slot
        if not self.slot_tracker.use_slot(cast_level):
            return None

        # Handle concentration
        if spell.concentration:
            self.concentrating_on = spell.name

        return spell

    def break_concentration(self) -> Optional[str]:
        """Break concentration. Returns spell name if was concentrating."""
        spell = self.concentrating_on
        self.concentrating_on = None
        return spell

    def get_spell_save_dc(self, proficiency_bonus: int, ability_modifier: int) -> int:
        """Calculate spell save DC."""
        return 8 + proficiency_bonus + ability_modifier

    def get_spell_attack_bonus(self, proficiency_bonus: int, ability_modifier: int) -> int:
        """Calculate spell attack bonus."""
        return proficiency_bonus + ability_modifier

    def to_dict(self) -> Dict:
        """Convert to dictionary."""
        return {
            'spellcasting_ability': self.spellcasting_ability.value if self.spellcasting_ability else None,
            'known_spells': list(self.known_spells),
            'prepared_spells': list(self.prepared_spells),
            'cantrips': list(self.cantrips),
            'slot_tracker': self.slot_tracker.to_dict(),
            'concentrating_on': self.concentrating_on,
        }

    @classmethod
    def from_dict(cls, data: Dict) -> 'Spellbook':
        """Create from dictionary."""
        ability = None
        if data.get('spellcasting_ability'):
            for a in Ability:
                if a.value == data['spellcasting_ability']:
                    ability = a
                    break

        book = cls(ability)
        book.known_spells = set(data.get('known_spells', []))
        book.prepared_spells = set(data.get('prepared_spells', []))
        book.cantrips = set(data.get('cantrips', []))
        book.slot_tracker = SpellSlotTracker.from_dict(data['slot_tracker'])
        book.concentrating_on = data.get('concentrating_on')
        return book


def get_spell(name: str) -> Optional[Spell]:
    """Get a spell by name."""
    return SPELLS.get(name.lower())


def get_spells_by_class(class_name: str) -> List[Spell]:
    """Get all spells available to a class."""
    return [s for s in SPELLS.values() if class_name.lower() in s.classes]


def get_spells_by_level(level: int) -> List[Spell]:
    """Get all spells of a specific level."""
    return [s for s in SPELLS.values() if s.level == level]


def get_cantrips() -> List[Spell]:
    """Get all cantrips."""
    return get_spells_by_level(0)


def get_all_spells() -> List[Spell]:
    """Get all spells."""
    return list(SPELLS.values())
