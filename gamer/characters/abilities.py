"""Ability scores and modifiers for D&D 5e."""

from dataclasses import dataclass
from typing import Dict, List, Optional
from enum import Enum


class Ability(Enum):
    """The six ability scores in D&D 5e."""
    STRENGTH = "STR"
    DEXTERITY = "DEX"
    CONSTITUTION = "CON"
    INTELLIGENCE = "INT"
    WISDOM = "WIS"
    CHARISMA = "CHA"


# Mapping of ability names to enum
ABILITY_NAMES = {
    'str': Ability.STRENGTH,
    'strength': Ability.STRENGTH,
    'dex': Ability.DEXTERITY,
    'dexterity': Ability.DEXTERITY,
    'con': Ability.CONSTITUTION,
    'constitution': Ability.CONSTITUTION,
    'int': Ability.INTELLIGENCE,
    'intelligence': Ability.INTELLIGENCE,
    'wis': Ability.WISDOM,
    'wisdom': Ability.WISDOM,
    'cha': Ability.CHARISMA,
    'charisma': Ability.CHARISMA,
}


def get_modifier(score: int) -> int:
    """Calculate ability modifier from score."""
    return (score - 10) // 2


@dataclass
class AbilityScores:
    """Container for the six ability scores."""
    strength: int = 10
    dexterity: int = 10
    constitution: int = 10
    intelligence: int = 10
    wisdom: int = 10
    charisma: int = 10

    def get_score(self, ability: Ability) -> int:
        """Get the score for an ability."""
        mapping = {
            Ability.STRENGTH: self.strength,
            Ability.DEXTERITY: self.dexterity,
            Ability.CONSTITUTION: self.constitution,
            Ability.INTELLIGENCE: self.intelligence,
            Ability.WISDOM: self.wisdom,
            Ability.CHARISMA: self.charisma,
        }
        return mapping[ability]

    def set_score(self, ability: Ability, value: int) -> None:
        """Set the score for an ability."""
        if ability == Ability.STRENGTH:
            self.strength = value
        elif ability == Ability.DEXTERITY:
            self.dexterity = value
        elif ability == Ability.CONSTITUTION:
            self.constitution = value
        elif ability == Ability.INTELLIGENCE:
            self.intelligence = value
        elif ability == Ability.WISDOM:
            self.wisdom = value
        elif ability == Ability.CHARISMA:
            self.charisma = value

    def get_modifier(self, ability: Ability) -> int:
        """Get the modifier for an ability."""
        return get_modifier(self.get_score(ability))

    def apply_bonuses(self, bonuses: Dict[str, int]) -> None:
        """Apply racial or other bonuses to ability scores."""
        for ability_name, bonus in bonuses.items():
            ability = ABILITY_NAMES.get(ability_name.lower())
            if ability:
                current = self.get_score(ability)
                self.set_score(ability, current + bonus)

    def to_dict(self) -> Dict[str, int]:
        """Convert to dictionary."""
        return {
            'strength': self.strength,
            'dexterity': self.dexterity,
            'constitution': self.constitution,
            'intelligence': self.intelligence,
            'wisdom': self.wisdom,
            'charisma': self.charisma,
        }

    @classmethod
    def from_dict(cls, data: Dict[str, int]) -> 'AbilityScores':
        """Create from dictionary."""
        return cls(**data)

    @classmethod
    def from_list(cls, scores: List[int], order: Optional[List[Ability]] = None) -> 'AbilityScores':
        """Create from a list of scores in standard order or custom order."""
        if order is None:
            order = [Ability.STRENGTH, Ability.DEXTERITY, Ability.CONSTITUTION,
                     Ability.INTELLIGENCE, Ability.WISDOM, Ability.CHARISMA]

        instance = cls()
        for ability, score in zip(order, scores):
            instance.set_score(ability, score)
        return instance


class Abilities:
    """Manager for ability scores with saving throw proficiencies."""

    def __init__(self, scores: Optional[AbilityScores] = None):
        """Initialize abilities."""
        self.scores = scores or AbilityScores()
        self.saving_throw_proficiencies: List[Ability] = []

    def get_score(self, ability: Ability) -> int:
        """Get ability score."""
        return self.scores.get_score(ability)

    def get_modifier(self, ability: Ability) -> int:
        """Get ability modifier."""
        return self.scores.get_modifier(ability)

    def get_saving_throw(self, ability: Ability, proficiency_bonus: int = 0) -> int:
        """Get saving throw modifier."""
        modifier = self.get_modifier(ability)
        if ability in self.saving_throw_proficiencies:
            modifier += proficiency_bonus
        return modifier

    def add_saving_throw_proficiency(self, ability: Ability) -> None:
        """Add proficiency in a saving throw."""
        if ability not in self.saving_throw_proficiencies:
            self.saving_throw_proficiencies.append(ability)

    def is_proficient_in_save(self, ability: Ability) -> bool:
        """Check if proficient in a saving throw."""
        return ability in self.saving_throw_proficiencies

    def to_dict(self) -> Dict:
        """Convert to dictionary for serialization."""
        return {
            'scores': self.scores.to_dict(),
            'saving_throw_proficiencies': [a.value for a in self.saving_throw_proficiencies]
        }

    @classmethod
    def from_dict(cls, data: Dict) -> 'Abilities':
        """Create from dictionary."""
        instance = cls(AbilityScores.from_dict(data['scores']))
        for ability_value in data.get('saving_throw_proficiencies', []):
            for ability in Ability:
                if ability.value == ability_value:
                    instance.add_saving_throw_proficiency(ability)
                    break
        return instance

    def display_scores(self) -> str:
        """Return a formatted string of ability scores."""
        lines = []
        for ability in Ability:
            score = self.get_score(ability)
            mod = self.get_modifier(ability)
            mod_str = f"+{mod}" if mod >= 0 else str(mod)
            prof = "*" if ability in self.saving_throw_proficiencies else " "
            lines.append(f"{ability.value}: {score:2d} ({mod_str:>3}){prof}")
        return "\n".join(lines)
