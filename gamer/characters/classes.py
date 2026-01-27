"""D&D 5e character classes with features and hit dice."""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Set
from enum import Enum

from .abilities import Ability


class ArmorType(Enum):
    """Armor proficiency types."""
    LIGHT = "light"
    MEDIUM = "medium"
    HEAVY = "heavy"
    SHIELDS = "shields"


@dataclass
class ClassFeature:
    """A class feature gained at a specific level."""
    name: str
    description: str
    level: int


@dataclass
class SpellSlots:
    """Spell slots for a spellcasting class at a given level."""
    cantrips: int = 0
    slot_1: int = 0
    slot_2: int = 0
    slot_3: int = 0
    slot_4: int = 0
    slot_5: int = 0

    def get_slots(self, spell_level: int) -> int:
        """Get number of slots for a spell level."""
        slots = {
            1: self.slot_1,
            2: self.slot_2,
            3: self.slot_3,
            4: self.slot_4,
            5: self.slot_5,
        }
        return slots.get(spell_level, 0)


@dataclass
class CharacterClass:
    """A D&D 5e character class."""
    name: str
    hit_die: int  # d6, d8, d10, d12
    primary_ability: Ability
    saving_throw_proficiencies: List[Ability]
    armor_proficiencies: List[ArmorType]
    weapon_proficiencies: List[str]
    tool_proficiencies: List[str] = field(default_factory=list)
    skill_choices: List[str] = field(default_factory=list)
    num_skill_choices: int = 2
    features: List[ClassFeature] = field(default_factory=list)
    spellcasting_ability: Optional[Ability] = None
    spell_slots_by_level: Dict[int, SpellSlots] = field(default_factory=dict)
    starting_equipment: List[str] = field(default_factory=list)

    def get_features_at_level(self, level: int) -> List[ClassFeature]:
        """Get all features available at or below a level."""
        return [f for f in self.features if f.level <= level]

    def get_new_features_at_level(self, level: int) -> List[ClassFeature]:
        """Get features gained at exactly this level."""
        return [f for f in self.features if f.level == level]

    def get_spell_slots(self, level: int) -> SpellSlots:
        """Get spell slots at a character level."""
        return self.spell_slots_by_level.get(level, SpellSlots())

    def is_spellcaster(self) -> bool:
        """Check if this class can cast spells."""
        return self.spellcasting_ability is not None

    def to_dict(self) -> Dict:
        """Convert to dictionary for serialization."""
        return {
            'name': self.name,
            'hit_die': self.hit_die,
            'primary_ability': self.primary_ability.value,
        }


# Proficiency bonus by level
PROFICIENCY_BONUS = {
    1: 2, 2: 2, 3: 2, 4: 2,
    5: 3, 6: 3, 7: 3, 8: 3,
    9: 4, 10: 4, 11: 4, 12: 4,
    13: 5, 14: 5, 15: 5, 16: 5,
    17: 6, 18: 6, 19: 6, 20: 6,
}


def get_proficiency_bonus(level: int) -> int:
    """Get proficiency bonus for a character level."""
    return PROFICIENCY_BONUS.get(level, 2)


# Define all classes
CLASSES: Dict[str, CharacterClass] = {}


def _register_class(char_class: CharacterClass) -> None:
    """Register a class in the CLASSES dictionary."""
    CLASSES[char_class.name.lower()] = char_class


# Fighter
_register_class(CharacterClass(
    name="Fighter",
    hit_die=10,
    primary_ability=Ability.STRENGTH,
    saving_throw_proficiencies=[Ability.STRENGTH, Ability.CONSTITUTION],
    armor_proficiencies=[ArmorType.LIGHT, ArmorType.MEDIUM, ArmorType.HEAVY, ArmorType.SHIELDS],
    weapon_proficiencies=["simple", "martial"],
    skill_choices=["acrobatics", "animal_handling", "athletics", "history",
                   "insight", "intimidation", "perception", "survival"],
    num_skill_choices=2,
    features=[
        ClassFeature("Fighting Style", "Choose a fighting style: Archery, Defense, Dueling, Great Weapon Fighting, Protection, or Two-Weapon Fighting.", 1),
        ClassFeature("Second Wind", "Bonus action to regain 1d10 + fighter level HP once per short rest.", 1),
        ClassFeature("Action Surge", "Take one additional action on your turn once per short rest.", 2),
        ClassFeature("Martial Archetype", "Choose Champion, Battle Master, or Eldritch Knight.", 3),
        ClassFeature("Ability Score Improvement", "Increase one ability by 2, or two abilities by 1.", 4),
        ClassFeature("Extra Attack", "Attack twice when you take the Attack action.", 5),
    ],
    starting_equipment=["chain_mail", "shield", "longsword", "light_crossbow", "20_bolts"],
))

# Wizard
_register_class(CharacterClass(
    name="Wizard",
    hit_die=6,
    primary_ability=Ability.INTELLIGENCE,
    saving_throw_proficiencies=[Ability.INTELLIGENCE, Ability.WISDOM],
    armor_proficiencies=[],
    weapon_proficiencies=["dagger", "dart", "sling", "quarterstaff", "light_crossbow"],
    skill_choices=["arcana", "history", "insight", "investigation", "medicine", "religion"],
    num_skill_choices=2,
    spellcasting_ability=Ability.INTELLIGENCE,
    spell_slots_by_level={
        1: SpellSlots(cantrips=3, slot_1=2),
        2: SpellSlots(cantrips=3, slot_1=3),
        3: SpellSlots(cantrips=3, slot_1=4, slot_2=2),
        4: SpellSlots(cantrips=4, slot_1=4, slot_2=3),
        5: SpellSlots(cantrips=4, slot_1=4, slot_2=3, slot_3=2),
    },
    features=[
        ClassFeature("Spellcasting", "Cast wizard spells using Intelligence.", 1),
        ClassFeature("Arcane Recovery", "Recover spell slots on short rest (level/2 rounded up in total slot levels).", 1),
        ClassFeature("Arcane Tradition", "Choose School of Evocation, Abjuration, etc.", 2),
        ClassFeature("Ability Score Improvement", "Increase one ability by 2, or two abilities by 1.", 4),
    ],
    starting_equipment=["quarterstaff", "component_pouch", "scholar's_pack", "spellbook"],
))

# Rogue
_register_class(CharacterClass(
    name="Rogue",
    hit_die=8,
    primary_ability=Ability.DEXTERITY,
    saving_throw_proficiencies=[Ability.DEXTERITY, Ability.INTELLIGENCE],
    armor_proficiencies=[ArmorType.LIGHT],
    weapon_proficiencies=["simple", "hand_crossbow", "longsword", "rapier", "shortsword"],
    tool_proficiencies=["thieves_tools"],
    skill_choices=["acrobatics", "athletics", "deception", "insight", "intimidation",
                   "investigation", "perception", "performance", "persuasion",
                   "sleight_of_hand", "stealth"],
    num_skill_choices=4,
    features=[
        ClassFeature("Expertise", "Double proficiency bonus for two skills or thieves' tools.", 1),
        ClassFeature("Sneak Attack", "Deal extra 1d6 damage when you have advantage or an ally is adjacent to target.", 1),
        ClassFeature("Thieves' Cant", "Secret language of thieves and rogues.", 1),
        ClassFeature("Cunning Action", "Bonus action to Dash, Disengage, or Hide.", 2),
        ClassFeature("Roguish Archetype", "Choose Thief, Assassin, or Arcane Trickster.", 3),
        ClassFeature("Ability Score Improvement", "Increase one ability by 2, or two abilities by 1.", 4),
        ClassFeature("Uncanny Dodge", "Reaction to halve attack damage.", 5),
    ],
    starting_equipment=["rapier", "shortbow", "20_arrows", "leather_armor", "thieves_tools"],
))

# Cleric
_register_class(CharacterClass(
    name="Cleric",
    hit_die=8,
    primary_ability=Ability.WISDOM,
    saving_throw_proficiencies=[Ability.WISDOM, Ability.CHARISMA],
    armor_proficiencies=[ArmorType.LIGHT, ArmorType.MEDIUM, ArmorType.SHIELDS],
    weapon_proficiencies=["simple"],
    skill_choices=["history", "insight", "medicine", "persuasion", "religion"],
    num_skill_choices=2,
    spellcasting_ability=Ability.WISDOM,
    spell_slots_by_level={
        1: SpellSlots(cantrips=3, slot_1=2),
        2: SpellSlots(cantrips=3, slot_1=3),
        3: SpellSlots(cantrips=3, slot_1=4, slot_2=2),
        4: SpellSlots(cantrips=4, slot_1=4, slot_2=3),
        5: SpellSlots(cantrips=4, slot_1=4, slot_2=3, slot_3=2),
    },
    features=[
        ClassFeature("Spellcasting", "Cast cleric spells using Wisdom.", 1),
        ClassFeature("Divine Domain", "Choose Life, Light, War, etc. for bonus spells and features.", 1),
        ClassFeature("Channel Divinity", "Channel divine energy once per rest. Turn Undead available to all.", 2),
        ClassFeature("Ability Score Improvement", "Increase one ability by 2, or two abilities by 1.", 4),
        ClassFeature("Destroy Undead", "Undead of CR 1/2 or lower are destroyed by Turn Undead.", 5),
    ],
    starting_equipment=["mace", "scale_mail", "shield", "holy_symbol"],
))

# Ranger
_register_class(CharacterClass(
    name="Ranger",
    hit_die=10,
    primary_ability=Ability.DEXTERITY,
    saving_throw_proficiencies=[Ability.STRENGTH, Ability.DEXTERITY],
    armor_proficiencies=[ArmorType.LIGHT, ArmorType.MEDIUM, ArmorType.SHIELDS],
    weapon_proficiencies=["simple", "martial"],
    skill_choices=["animal_handling", "athletics", "insight", "investigation",
                   "nature", "perception", "stealth", "survival"],
    num_skill_choices=3,
    spellcasting_ability=Ability.WISDOM,
    spell_slots_by_level={
        2: SpellSlots(slot_1=2),
        3: SpellSlots(slot_1=3),
        4: SpellSlots(slot_1=3),
        5: SpellSlots(slot_1=4, slot_2=2),
    },
    features=[
        ClassFeature("Favored Enemy", "Advantage on Survival checks to track and Intelligence checks to recall info about chosen enemy type.", 1),
        ClassFeature("Natural Explorer", "Double proficiency on INT/WIS checks in favored terrain. Travel benefits.", 1),
        ClassFeature("Fighting Style", "Choose Archery, Defense, Dueling, or Two-Weapon Fighting.", 2),
        ClassFeature("Spellcasting", "Cast ranger spells using Wisdom.", 2),
        ClassFeature("Ranger Archetype", "Choose Hunter or Beast Master.", 3),
        ClassFeature("Primeval Awareness", "Sense aberrations, celestials, dragons, elementals, fey, fiends, undead within 1 mile.", 3),
        ClassFeature("Ability Score Improvement", "Increase one ability by 2, or two abilities by 1.", 4),
        ClassFeature("Extra Attack", "Attack twice when you take the Attack action.", 5),
    ],
    starting_equipment=["scale_mail", "two_shortswords", "longbow", "20_arrows"],
))

# Barbarian
_register_class(CharacterClass(
    name="Barbarian",
    hit_die=12,
    primary_ability=Ability.STRENGTH,
    saving_throw_proficiencies=[Ability.STRENGTH, Ability.CONSTITUTION],
    armor_proficiencies=[ArmorType.LIGHT, ArmorType.MEDIUM, ArmorType.SHIELDS],
    weapon_proficiencies=["simple", "martial"],
    skill_choices=["animal_handling", "athletics", "intimidation", "nature",
                   "perception", "survival"],
    num_skill_choices=2,
    features=[
        ClassFeature("Rage", "Bonus action to rage: advantage on STR checks/saves, +2 melee damage, resistance to bludgeoning/piercing/slashing.", 1),
        ClassFeature("Unarmored Defense", "AC = 10 + DEX mod + CON mod when not wearing armor.", 1),
        ClassFeature("Reckless Attack", "Advantage on melee attacks this turn, but attacks against you have advantage.", 2),
        ClassFeature("Danger Sense", "Advantage on DEX saves against effects you can see.", 2),
        ClassFeature("Primal Path", "Choose Path of the Berserker or Totem Warrior.", 3),
        ClassFeature("Ability Score Improvement", "Increase one ability by 2, or two abilities by 1.", 4),
        ClassFeature("Extra Attack", "Attack twice when you take the Attack action.", 5),
        ClassFeature("Fast Movement", "+10 feet speed when not wearing heavy armor.", 5),
    ],
    starting_equipment=["greataxe", "two_handaxes", "explorer's_pack", "4_javelins"],
))


def get_class(name: str) -> Optional[CharacterClass]:
    """Get a class by name."""
    return CLASSES.get(name.lower())


def get_all_classes() -> List[CharacterClass]:
    """Get all available classes."""
    return list(CLASSES.values())


def get_class_names() -> List[str]:
    """Get all class names."""
    return [c.name for c in CLASSES.values()]


def calculate_hp(char_class: CharacterClass, level: int, con_modifier: int) -> int:
    """Calculate HP for a class at a given level."""
    # First level: max hit die + CON mod
    hp = char_class.hit_die + con_modifier

    # Additional levels: average hit die (rounded up) + CON mod per level
    avg_roll = (char_class.hit_die // 2) + 1
    for _ in range(level - 1):
        hp += avg_roll + con_modifier

    return max(hp, 1)  # Minimum 1 HP
