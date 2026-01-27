"""D&D 5e skills with proficiency system."""

from dataclasses import dataclass
from typing import Dict, List, Optional
from enum import Enum

from .abilities import Ability


@dataclass
class Skill:
    """A D&D 5e skill."""
    name: str
    ability: Ability
    description: str


# All 18 skills in D&D 5e
SKILLS: Dict[str, Skill] = {
    "acrobatics": Skill("Acrobatics", Ability.DEXTERITY,
                        "Balance, tumbling, and aerial maneuvers."),
    "animal_handling": Skill("Animal Handling", Ability.WISDOM,
                             "Calm, control, or intuit animals."),
    "arcana": Skill("Arcana", Ability.INTELLIGENCE,
                    "Recall lore about spells, magic items, and planes."),
    "athletics": Skill("Athletics", Ability.STRENGTH,
                       "Climb, jump, swim, and feats of strength."),
    "deception": Skill("Deception", Ability.CHARISMA,
                       "Lie, mislead, or disguise intentions."),
    "history": Skill("History", Ability.INTELLIGENCE,
                     "Recall lore about events, people, and places."),
    "insight": Skill("Insight", Ability.WISDOM,
                     "Determine true intentions and detect lies."),
    "intimidation": Skill("Intimidation", Ability.CHARISMA,
                          "Influence through threats or hostile actions."),
    "investigation": Skill("Investigation", Ability.INTELLIGENCE,
                           "Search for clues and deduce information."),
    "medicine": Skill("Medicine", Ability.WISDOM,
                      "Stabilize dying creatures and diagnose illness."),
    "nature": Skill("Nature", Ability.INTELLIGENCE,
                    "Recall lore about terrain, plants, animals, and weather."),
    "perception": Skill("Perception", Ability.WISDOM,
                        "Spot, hear, or detect the presence of something."),
    "performance": Skill("Performance", Ability.CHARISMA,
                         "Entertain through music, dance, or acting."),
    "persuasion": Skill("Persuasion", Ability.CHARISMA,
                        "Influence through tact, social graces, or good nature."),
    "religion": Skill("Religion", Ability.INTELLIGENCE,
                      "Recall lore about deities, rites, and holy symbols."),
    "sleight_of_hand": Skill("Sleight of Hand", Ability.DEXTERITY,
                             "Manual trickery, pickpocketing, and concealment."),
    "stealth": Skill("Stealth", Ability.DEXTERITY,
                     "Hide, move silently, and avoid detection."),
    "survival": Skill("Survival", Ability.WISDOM,
                      "Track, hunt, navigate, and avoid natural hazards."),
}


class SkillProficiency(Enum):
    """Level of proficiency in a skill."""
    NONE = 0
    PROFICIENT = 1
    EXPERTISE = 2  # Double proficiency (Rogues, Bards)


class SkillManager:
    """Manages skill proficiencies and checks for a character."""

    def __init__(self):
        """Initialize with no proficiencies."""
        self.proficiencies: Dict[str, SkillProficiency] = {
            skill: SkillProficiency.NONE for skill in SKILLS
        }

    def add_proficiency(self, skill_name: str) -> bool:
        """Add proficiency in a skill. Returns True if successful."""
        skill_key = skill_name.lower().replace(' ', '_')
        if skill_key in SKILLS:
            if self.proficiencies[skill_key] == SkillProficiency.NONE:
                self.proficiencies[skill_key] = SkillProficiency.PROFICIENT
                return True
        return False

    def add_expertise(self, skill_name: str) -> bool:
        """Add expertise in a skill. Returns True if successful."""
        skill_key = skill_name.lower().replace(' ', '_')
        if skill_key in SKILLS:
            if self.proficiencies[skill_key] == SkillProficiency.PROFICIENT:
                self.proficiencies[skill_key] = SkillProficiency.EXPERTISE
                return True
        return False

    def is_proficient(self, skill_name: str) -> bool:
        """Check if proficient in a skill."""
        skill_key = skill_name.lower().replace(' ', '_')
        return self.proficiencies.get(skill_key, SkillProficiency.NONE) != SkillProficiency.NONE

    def has_expertise(self, skill_name: str) -> bool:
        """Check if has expertise in a skill."""
        skill_key = skill_name.lower().replace(' ', '_')
        return self.proficiencies.get(skill_key, SkillProficiency.NONE) == SkillProficiency.EXPERTISE

    def get_proficiency_level(self, skill_name: str) -> SkillProficiency:
        """Get proficiency level for a skill."""
        skill_key = skill_name.lower().replace(' ', '_')
        return self.proficiencies.get(skill_key, SkillProficiency.NONE)

    def get_skill_modifier(self, skill_name: str, ability_modifier: int,
                           proficiency_bonus: int) -> int:
        """Calculate total skill modifier."""
        skill_key = skill_name.lower().replace(' ', '_')
        prof_level = self.proficiencies.get(skill_key, SkillProficiency.NONE)

        modifier = ability_modifier
        if prof_level == SkillProficiency.PROFICIENT:
            modifier += proficiency_bonus
        elif prof_level == SkillProficiency.EXPERTISE:
            modifier += proficiency_bonus * 2

        return modifier

    def get_proficient_skills(self) -> List[str]:
        """Get list of skills with proficiency."""
        return [
            skill for skill, prof in self.proficiencies.items()
            if prof != SkillProficiency.NONE
        ]

    def get_expertise_skills(self) -> List[str]:
        """Get list of skills with expertise."""
        return [
            skill for skill, prof in self.proficiencies.items()
            if prof == SkillProficiency.EXPERTISE
        ]

    def to_dict(self) -> Dict[str, int]:
        """Convert to dictionary for serialization."""
        return {skill: prof.value for skill, prof in self.proficiencies.items()}

    @classmethod
    def from_dict(cls, data: Dict[str, int]) -> 'SkillManager':
        """Create from dictionary."""
        manager = cls()
        for skill, prof_value in data.items():
            if skill in SKILLS:
                manager.proficiencies[skill] = SkillProficiency(prof_value)
        return manager


def get_skill(name: str) -> Optional[Skill]:
    """Get a skill by name."""
    key = name.lower().replace(' ', '_')
    return SKILLS.get(key)


def get_skills_by_ability(ability: Ability) -> List[Skill]:
    """Get all skills that use a specific ability."""
    return [skill for skill in SKILLS.values() if skill.ability == ability]


def get_all_skills() -> List[Skill]:
    """Get all skills."""
    return list(SKILLS.values())


def get_skill_names() -> List[str]:
    """Get all skill names."""
    return list(SKILLS.keys())
