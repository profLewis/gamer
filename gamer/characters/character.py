"""Character class combining all character components."""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any
import uuid

from .abilities import Abilities, AbilityScores, Ability
from .races import Race, get_race
from .classes import CharacterClass, get_class, get_proficiency_bonus, calculate_hp
from .skills import SkillManager
from .spells import Spellbook


@dataclass
class Equipment:
    """Character equipment and inventory."""
    weapons: List[str] = field(default_factory=list)
    armor: Optional[str] = None
    shield: bool = False
    items: List[str] = field(default_factory=list)
    gold: int = 0

    def to_dict(self) -> Dict:
        return {
            'weapons': self.weapons,
            'armor': self.armor,
            'shield': self.shield,
            'items': self.items,
            'gold': self.gold,
        }

    @classmethod
    def from_dict(cls, data: Dict) -> 'Equipment':
        return cls(**data)


class Character:
    """A player character in D&D 5e."""

    def __init__(self, name: str, race: Race, char_class: CharacterClass,
                 abilities: Abilities):
        """Initialize a new character."""
        self.id = str(uuid.uuid4())
        self.name = name
        self.race = race
        self.char_class = char_class
        self.abilities = abilities
        self.level = 1
        self.experience = 0

        # Apply racial ability bonuses
        self.abilities.scores.apply_bonuses(race.ability_bonuses)

        # Set saving throw proficiencies from class
        for ability in char_class.saving_throw_proficiencies:
            self.abilities.add_saving_throw_proficiency(ability)

        # Calculate HP
        con_mod = self.abilities.get_modifier(Ability.CONSTITUTION)
        self.max_hp = calculate_hp(char_class, self.level, con_mod)
        self.current_hp = self.max_hp
        self.temp_hp = 0

        # Hit dice
        self.hit_dice_remaining = self.level
        self.hit_die_size = char_class.hit_die

        # Death saves
        self.death_save_successes = 0
        self.death_save_failures = 0

        # Skills
        self.skills = SkillManager()
        # Add racial skill proficiencies
        for skill in race.skill_proficiencies:
            self.skills.add_proficiency(skill)

        # Spellcasting
        if char_class.is_spellcaster():
            self.spellbook = Spellbook(char_class.spellcasting_ability)
            slots = char_class.get_spell_slots(self.level)
            self.spellbook.slot_tracker.set_max_slots({
                1: slots.slot_1,
                2: slots.slot_2,
                3: slots.slot_3,
                4: slots.slot_4,
                5: slots.slot_5,
            })
        else:
            self.spellbook = None

        # Equipment
        self.equipment = Equipment()
        for item in char_class.starting_equipment:
            if 'sword' in item or 'axe' in item or 'bow' in item or 'dagger' in item or \
               'mace' in item or 'staff' in item or 'crossbow' in item:
                self.equipment.weapons.append(item)
            elif 'mail' in item or 'armor' in item or 'leather' in item:
                self.equipment.armor = item
            elif 'shield' in item:
                self.equipment.shield = True
            else:
                self.equipment.items.append(item)

        # Conditions
        self.conditions: List[str] = []

        # Combat state
        self.initiative: int = 0
        self.is_concentrating: bool = False

    @property
    def proficiency_bonus(self) -> int:
        """Get proficiency bonus based on level."""
        return get_proficiency_bonus(self.level)

    @property
    def armor_class(self) -> int:
        """Calculate armor class."""
        dex_mod = self.abilities.get_modifier(Ability.DEXTERITY)

        # Base AC calculation
        if self.equipment.armor is None:
            # Unarmored
            base_ac = 10 + dex_mod

            # Barbarian unarmored defense
            if self.char_class.name == "Barbarian":
                con_mod = self.abilities.get_modifier(Ability.CONSTITUTION)
                base_ac = 10 + dex_mod + con_mod
        elif 'leather' in self.equipment.armor:
            base_ac = 11 + dex_mod
        elif 'hide' in self.equipment.armor:
            base_ac = 12 + min(dex_mod, 2)
        elif 'chain_shirt' in self.equipment.armor:
            base_ac = 13 + min(dex_mod, 2)
        elif 'scale' in self.equipment.armor:
            base_ac = 14 + min(dex_mod, 2)
        elif 'breastplate' in self.equipment.armor:
            base_ac = 14 + min(dex_mod, 2)
        elif 'half_plate' in self.equipment.armor:
            base_ac = 15 + min(dex_mod, 2)
        elif 'ring' in self.equipment.armor:
            base_ac = 14
        elif 'chain_mail' in self.equipment.armor:
            base_ac = 16
        elif 'splint' in self.equipment.armor:
            base_ac = 17
        elif 'plate' in self.equipment.armor:
            base_ac = 18
        else:
            base_ac = 10 + dex_mod

        # Shield bonus
        if self.equipment.shield:
            base_ac += 2

        return base_ac

    @property
    def speed(self) -> int:
        """Get movement speed."""
        speed = self.race.speed

        # Barbarian fast movement at level 5
        if self.char_class.name == "Barbarian" and self.level >= 5:
            if self.equipment.armor is None or 'heavy' not in str(self.equipment.armor):
                speed += 10

        return speed

    @property
    def passive_perception(self) -> int:
        """Calculate passive perception."""
        wis_mod = self.abilities.get_modifier(Ability.WISDOM)
        skill_mod = self.skills.get_skill_modifier("perception", wis_mod, self.proficiency_bonus)
        return 10 + skill_mod

    @property
    def is_alive(self) -> bool:
        """Check if character is alive."""
        return self.current_hp > 0 or self.death_save_failures < 3

    @property
    def is_conscious(self) -> bool:
        """Check if character is conscious."""
        return self.current_hp > 0

    @property
    def is_stable(self) -> bool:
        """Check if character is stable (unconscious but not dying)."""
        return self.current_hp == 0 and self.death_save_successes >= 3

    def take_damage(self, amount: int) -> Dict[str, Any]:
        """Take damage and return result info."""
        result = {
            'damage_taken': 0,
            'temp_hp_absorbed': 0,
            'knocked_unconscious': False,
            'instant_death': False,
        }

        # Absorb with temp HP first
        if self.temp_hp > 0:
            absorbed = min(self.temp_hp, amount)
            self.temp_hp -= absorbed
            amount -= absorbed
            result['temp_hp_absorbed'] = absorbed

        if amount <= 0:
            result['damage_taken'] = result['temp_hp_absorbed']
            return result

        # Check for instant death
        if self.current_hp > 0 and amount >= self.current_hp + self.max_hp:
            self.current_hp = 0
            self.death_save_failures = 3
            result['instant_death'] = True
            result['damage_taken'] = amount
            return result

        # Apply remaining damage
        old_hp = self.current_hp
        self.current_hp = max(0, self.current_hp - amount)
        result['damage_taken'] = old_hp - self.current_hp + result['temp_hp_absorbed']

        if old_hp > 0 and self.current_hp == 0:
            result['knocked_unconscious'] = True
            self.death_save_successes = 0
            self.death_save_failures = 0

        return result

    def heal(self, amount: int) -> int:
        """Heal HP and return actual amount healed."""
        if self.current_hp <= 0:
            # Regaining consciousness
            self.death_save_successes = 0
            self.death_save_failures = 0

        old_hp = self.current_hp
        self.current_hp = min(self.max_hp, self.current_hp + amount)
        return self.current_hp - old_hp

    def add_temp_hp(self, amount: int) -> None:
        """Add temporary HP (doesn't stack, takes higher)."""
        self.temp_hp = max(self.temp_hp, amount)

    def death_save(self, roll: int) -> Dict[str, Any]:
        """Make a death saving throw."""
        result = {
            'roll': roll,
            'success': False,
            'stabilized': False,
            'revived': False,
            'died': False,
        }

        if roll == 20:
            # Natural 20: regain 1 HP
            self.current_hp = 1
            self.death_save_successes = 0
            self.death_save_failures = 0
            result['success'] = True
            result['revived'] = True
        elif roll == 1:
            # Natural 1: two failures
            self.death_save_failures += 2
            if self.death_save_failures >= 3:
                result['died'] = True
        elif roll >= 10:
            self.death_save_successes += 1
            result['success'] = True
            if self.death_save_successes >= 3:
                result['stabilized'] = True
        else:
            self.death_save_failures += 1
            if self.death_save_failures >= 3:
                result['died'] = True

        return result

    def add_condition(self, condition: str) -> None:
        """Add a condition."""
        if condition not in self.conditions:
            self.conditions.append(condition)

    def remove_condition(self, condition: str) -> None:
        """Remove a condition."""
        if condition in self.conditions:
            self.conditions.remove(condition)

    def has_condition(self, condition: str) -> bool:
        """Check if has a condition."""
        return condition in self.conditions

    def short_rest(self) -> Dict[str, int]:
        """Take a short rest. Returns resources recovered."""
        result = {'hp_healed': 0, 'hit_dice_used': 0}

        # Can spend hit dice to heal
        con_mod = self.abilities.get_modifier(Ability.CONSTITUTION)

        # For simplicity, use all available hit dice
        while self.hit_dice_remaining > 0 and self.current_hp < self.max_hp:
            # Roll hit die + CON mod
            from ..utils.dice import roll_dice
            heal_roll, _ = roll_dice(1, self.hit_die_size, con_mod)
            heal_roll = max(0, heal_roll)

            healed = self.heal(heal_roll)
            result['hp_healed'] += healed
            result['hit_dice_used'] += 1
            self.hit_dice_remaining -= 1

            if self.current_hp >= self.max_hp:
                break

        return result

    def long_rest(self) -> Dict[str, int]:
        """Take a long rest. Returns resources recovered."""
        result = {
            'hp_healed': self.max_hp - self.current_hp,
            'hit_dice_recovered': 0,
            'spell_slots_recovered': 0,
        }

        # Restore all HP
        self.current_hp = self.max_hp
        self.temp_hp = 0

        # Restore half hit dice (minimum 1)
        dice_to_restore = max(1, self.level // 2)
        dice_restored = min(dice_to_restore, self.level - self.hit_dice_remaining)
        self.hit_dice_remaining += dice_restored
        result['hit_dice_recovered'] = dice_restored

        # Restore all spell slots
        if self.spellbook:
            self.spellbook.slot_tracker.restore_all()
            result['spell_slots_recovered'] = sum(self.spellbook.slot_tracker.max_slots.values())

        # Clear death saves
        self.death_save_successes = 0
        self.death_save_failures = 0

        # Clear certain conditions
        self.conditions = [c for c in self.conditions if c not in ['exhaustion_1']]

        return result

    def gain_experience(self, amount: int) -> bool:
        """Gain XP. Returns True if leveled up."""
        self.experience += amount

        # XP thresholds for levels 1-5
        thresholds = {
            1: 0,
            2: 300,
            3: 900,
            4: 2700,
            5: 6500,
        }

        # Check for level up
        for level in range(5, 0, -1):
            if self.experience >= thresholds[level] and self.level < level:
                self.level_up(level)
                return True

        return False

    def level_up(self, new_level: int) -> Dict[str, Any]:
        """Level up the character."""
        result = {
            'old_level': self.level,
            'new_level': new_level,
            'hp_gained': 0,
            'features_gained': [],
        }

        self.level = new_level

        # Increase HP
        con_mod = self.abilities.get_modifier(Ability.CONSTITUTION)
        self.max_hp = calculate_hp(self.char_class, self.level, con_mod)
        self.current_hp = self.max_hp  # Full heal on level up

        # Increase hit dice
        self.hit_dice_remaining = self.level

        # Update spell slots
        if self.spellbook:
            slots = self.char_class.get_spell_slots(self.level)
            self.spellbook.slot_tracker.set_max_slots({
                1: slots.slot_1,
                2: slots.slot_2,
                3: slots.slot_3,
                4: slots.slot_4,
                5: slots.slot_5,
            })

        # Get new features
        result['features_gained'] = [
            f.name for f in self.char_class.get_new_features_at_level(new_level)
        ]

        return result

    def get_attack_bonus(self, weapon: str, is_finesse: bool = False) -> int:
        """Calculate attack bonus for a weapon."""
        # Determine ability modifier
        if is_finesse:
            str_mod = self.abilities.get_modifier(Ability.STRENGTH)
            dex_mod = self.abilities.get_modifier(Ability.DEXTERITY)
            ability_mod = max(str_mod, dex_mod)
        elif 'bow' in weapon or 'crossbow' in weapon or weapon in ['dart', 'sling']:
            ability_mod = self.abilities.get_modifier(Ability.DEXTERITY)
        else:
            ability_mod = self.abilities.get_modifier(Ability.STRENGTH)

        return ability_mod + self.proficiency_bonus

    def get_damage_bonus(self, weapon: str, is_finesse: bool = False) -> int:
        """Calculate damage bonus for a weapon."""
        if is_finesse:
            str_mod = self.abilities.get_modifier(Ability.STRENGTH)
            dex_mod = self.abilities.get_modifier(Ability.DEXTERITY)
            return max(str_mod, dex_mod)
        elif 'bow' in weapon or 'crossbow' in weapon or weapon in ['dart', 'sling']:
            return self.abilities.get_modifier(Ability.DEXTERITY)
        else:
            return self.abilities.get_modifier(Ability.STRENGTH)

    def get_skill_modifier(self, skill_name: str) -> int:
        """Get total modifier for a skill check."""
        from .skills import SKILLS

        skill_key = skill_name.lower().replace(' ', '_')
        skill = SKILLS.get(skill_key)
        if not skill:
            return 0

        ability_mod = self.abilities.get_modifier(skill.ability)
        return self.skills.get_skill_modifier(skill_key, ability_mod, self.proficiency_bonus)

    def get_saving_throw_modifier(self, ability: Ability) -> int:
        """Get modifier for a saving throw."""
        return self.abilities.get_saving_throw(ability, self.proficiency_bonus)

    def to_dict(self) -> Dict:
        """Convert to dictionary for serialization."""
        return {
            'id': self.id,
            'name': self.name,
            'race': self.race.to_dict(),
            'class': self.char_class.to_dict(),
            'abilities': self.abilities.to_dict(),
            'level': self.level,
            'experience': self.experience,
            'max_hp': self.max_hp,
            'current_hp': self.current_hp,
            'temp_hp': self.temp_hp,
            'hit_dice_remaining': self.hit_dice_remaining,
            'death_save_successes': self.death_save_successes,
            'death_save_failures': self.death_save_failures,
            'skills': self.skills.to_dict(),
            'spellbook': self.spellbook.to_dict() if self.spellbook else None,
            'equipment': self.equipment.to_dict(),
            'conditions': self.conditions,
        }

    @classmethod
    def from_dict(cls, data: Dict) -> 'Character':
        """Create character from dictionary."""
        race = get_race(data['race']['name'])
        if data['race'].get('subrace'):
            race = get_race(f"{data['race']['subrace']} {data['race']['name']}")

        char_class = get_class(data['class']['name'])
        abilities = Abilities.from_dict(data['abilities'])

        # Create with basic data
        char = cls(data['name'], race, char_class, abilities)

        # Restore full state
        char.id = data['id']
        char.level = data['level']
        char.experience = data['experience']
        char.max_hp = data['max_hp']
        char.current_hp = data['current_hp']
        char.temp_hp = data['temp_hp']
        char.hit_dice_remaining = data['hit_dice_remaining']
        char.death_save_successes = data['death_save_successes']
        char.death_save_failures = data['death_save_failures']
        char.skills = SkillManager.from_dict(data['skills'])
        if data.get('spellbook'):
            char.spellbook = Spellbook.from_dict(data['spellbook'])
        char.equipment = Equipment.from_dict(data['equipment'])
        char.conditions = data['conditions']

        return char

    def __str__(self) -> str:
        """String representation."""
        return f"{self.name} - Level {self.level} {self.race.get_full_name()} {self.char_class.name}"

    def display_sheet(self) -> str:
        """Return a formatted character sheet."""
        lines = [
            f"{'=' * 50}",
            f"  {self.name.upper()}",
            f"  Level {self.level} {self.race.get_full_name()} {self.char_class.name}",
            f"{'=' * 50}",
            f"",
            f"  HP: {self.current_hp}/{self.max_hp}  AC: {self.armor_class}  Speed: {self.speed} ft",
            f"  Proficiency Bonus: +{self.proficiency_bonus}",
            f"",
            f"  ABILITY SCORES",
            f"  {self.abilities.display_scores()}",
            f"",
        ]

        # Skills
        proficient_skills = self.skills.get_proficient_skills()
        if proficient_skills:
            lines.append("  SKILL PROFICIENCIES")
            for skill in proficient_skills:
                mod = self.get_skill_modifier(skill)
                mod_str = f"+{mod}" if mod >= 0 else str(mod)
                lines.append(f"    {skill.replace('_', ' ').title()}: {mod_str}")
            lines.append("")

        # Equipment
        lines.append("  EQUIPMENT")
        if self.equipment.weapons:
            lines.append(f"    Weapons: {', '.join(self.equipment.weapons)}")
        if self.equipment.armor:
            lines.append(f"    Armor: {self.equipment.armor}")
        if self.equipment.shield:
            lines.append("    Shield")
        lines.append("")

        # Features
        lines.append("  CLASS FEATURES")
        for feature in self.char_class.get_features_at_level(self.level):
            lines.append(f"    - {feature.name}")

        lines.append(f"{'=' * 50}")
        return "\n".join(lines)
