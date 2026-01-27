"""Combat encounter manager for D&D 5e."""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any, Union
from enum import Enum, auto

from .initiative import InitiativeTracker
from .actions import (
    ActionEconomy, ActionResult, CombatAction, ActionType,
    STANDARD_ACTIONS, CLASS_BONUS_ACTIONS, get_weapon_data, is_finesse_weapon
)
from ..characters.character import Character
from ..characters.abilities import Ability
from ..utils.dice import d20, roll


class CombatState(Enum):
    """States of a combat encounter."""
    NOT_STARTED = auto()
    ROLLING_INITIATIVE = auto()
    IN_PROGRESS = auto()
    VICTORY = auto()
    DEFEAT = auto()
    FLED = auto()


@dataclass
class Combatant:
    """A participant in combat."""
    entity: Any  # Character or Monster
    entity_id: str
    is_player: bool
    action_economy: ActionEconomy = field(default_factory=ActionEconomy)
    is_dodging: bool = False
    is_hidden: bool = False
    helped_by: Optional[str] = None  # ID of helper
    readied_action: Optional[str] = None

    @property
    def name(self) -> str:
        return self.entity.name

    @property
    def is_alive(self) -> bool:
        if hasattr(self.entity, 'is_alive'):
            return self.entity.is_alive
        return self.entity.current_hp > 0

    @property
    def is_conscious(self) -> bool:
        if hasattr(self.entity, 'is_conscious'):
            return self.entity.is_conscious
        return self.entity.current_hp > 0


class CombatEncounter:
    """Manages a combat encounter."""

    def __init__(self):
        """Initialize the encounter."""
        self.state = CombatState.NOT_STARTED
        self.initiative = InitiativeTracker()
        self.combatants: Dict[str, Combatant] = {}
        self.combat_log: List[str] = []
        self.turn_number = 0

    def add_player(self, character: Character) -> int:
        """Add a player character to combat. Returns initiative roll."""
        dex_mod = character.abilities.get_modifier(Ability.DEXTERITY)

        combatant = Combatant(
            entity=character,
            entity_id=character.id,
            is_player=True,
        )
        self.combatants[character.id] = combatant

        init_roll = self.initiative.add_combatant(
            name=character.name,
            entity_id=character.id,
            dex_modifier=dex_mod,
            is_player=True,
        )

        self._log(f"{character.name} rolls initiative: {init_roll}")
        return init_roll

    def add_monster(self, monster: Any) -> int:
        """Add a monster to combat. Returns initiative roll."""
        # Monster should have dex_modifier or dexterity attribute
        if hasattr(monster, 'dex_modifier'):
            dex_mod = monster.dex_modifier
        elif hasattr(monster, 'abilities'):
            dex_mod = monster.abilities.get_modifier(Ability.DEXTERITY)
        else:
            dex_mod = 0

        combatant = Combatant(
            entity=monster,
            entity_id=monster.id,
            is_player=False,
        )
        self.combatants[monster.id] = combatant

        init_roll = self.initiative.add_combatant(
            name=monster.name,
            entity_id=monster.id,
            dex_modifier=dex_mod,
            is_player=False,
        )

        self._log(f"{monster.name} rolls initiative: {init_roll}")
        return init_roll

    def start_combat(self) -> None:
        """Start the combat encounter."""
        self.state = CombatState.IN_PROGRESS
        self._log("=== COMBAT BEGINS ===")
        self._start_turn()

    def _start_turn(self) -> None:
        """Start a new turn."""
        current = self.initiative.get_current()
        if not current:
            return

        combatant = self.combatants.get(current.entity_id)
        if not combatant:
            return

        self.turn_number += 1

        # Reset action economy
        combatant.action_economy.reset()

        # Set movement
        if hasattr(combatant.entity, 'speed'):
            combatant.action_economy.set_movement(combatant.entity.speed)
        else:
            combatant.action_economy.set_movement(30)  # Default

        # Set extra attacks
        if combatant.is_player:
            char = combatant.entity
            if char.level >= 5 and char.char_class.name in ['Fighter', 'Ranger', 'Barbarian']:
                combatant.action_economy.extra_attacks = 1

        # Clear turn-based conditions
        combatant.is_dodging = False
        combatant.helped_by = None

        self._log(f"\n--- {combatant.name}'s Turn (Round {self.initiative.round_number}) ---")

    def get_current_combatant(self) -> Optional[Combatant]:
        """Get the current combatant."""
        current = self.initiative.get_current()
        if current:
            return self.combatants.get(current.entity_id)
        return None

    def get_combatant(self, entity_id: str) -> Optional[Combatant]:
        """Get a combatant by ID."""
        return self.combatants.get(entity_id)

    def next_turn(self) -> Optional[Combatant]:
        """Advance to the next turn."""
        # Check for combat end
        if self._check_combat_end():
            return None

        self.initiative.next_turn()
        self._start_turn()

        # Skip unconscious combatants (but they might need death saves)
        current = self.get_current_combatant()
        if current and not current.is_conscious:
            if current.is_player:
                # Player needs death save
                self._log(f"{current.name} is unconscious and must make a death saving throw.")
            else:
                # Skip unconscious enemies
                return self.next_turn()

        return current

    def _check_combat_end(self) -> bool:
        """Check if combat should end."""
        players_alive = any(
            c.is_alive for c in self.combatants.values() if c.is_player
        )
        enemies_alive = any(
            c.is_alive for c in self.combatants.values() if not c.is_player
        )

        if not enemies_alive:
            self.state = CombatState.VICTORY
            self._log("\n=== VICTORY! ===")
            return True

        if not players_alive:
            self.state = CombatState.DEFEAT
            self._log("\n=== DEFEAT ===")
            return True

        return False

    def attack(self, attacker_id: str, target_id: str, weapon: str = "unarmed") -> ActionResult:
        """Make an attack."""
        attacker = self.combatants.get(attacker_id)
        target = self.combatants.get(target_id)

        if not attacker or not target:
            return ActionResult(success=False, description="Invalid attacker or target")

        # Check action availability
        economy = attacker.action_economy
        if not economy.action_available and economy.extra_attacks <= 0:
            return ActionResult(success=False, description="No attacks remaining")

        # Use action or extra attack
        if economy.action_available:
            economy.use_action()
        else:
            economy.extra_attacks -= 1

        # Calculate attack roll
        entity = attacker.entity
        weapon_data = get_weapon_data(weapon)
        is_finesse = is_finesse_weapon(weapon)

        if hasattr(entity, 'get_attack_bonus'):
            attack_bonus = entity.get_attack_bonus(weapon, is_finesse)
        else:
            attack_bonus = entity.attack_bonus if hasattr(entity, 'attack_bonus') else 0

        # Check for advantage/disadvantage
        advantage = False
        disadvantage = False

        if target.is_dodging and target.is_conscious:
            disadvantage = True

        if attacker.helped_by:
            advantage = True

        if hasattr(attacker.entity, 'has_condition'):
            if attacker.entity.has_condition('prone'):
                disadvantage = True

        if hasattr(target.entity, 'has_condition'):
            if target.entity.has_condition('prone'):
                advantage = True
            if target.entity.has_condition('paralyzed') or target.entity.has_condition('stunned'):
                advantage = True

        # Roll attack
        if advantage and not disadvantage:
            roll1, roll2 = d20(), d20()
            attack_roll = max(roll1, roll2)
            roll_str = f"(adv: {roll1}, {roll2})"
        elif disadvantage and not advantage:
            roll1, roll2 = d20(), d20()
            attack_roll = min(roll1, roll2)
            roll_str = f"(dis: {roll1}, {roll2})"
        else:
            attack_roll = d20()
            roll_str = f"({attack_roll})"

        total_attack = attack_roll + attack_bonus
        is_crit = attack_roll == 20
        is_miss = attack_roll == 1

        # Get target AC
        target_ac = target.entity.armor_class if hasattr(target.entity, 'armor_class') else target.entity.ac

        result = ActionResult(
            success=False,
            description="",
            roll_details={
                'attack_roll': attack_roll,
                'attack_bonus': attack_bonus,
                'total': total_attack,
                'target_ac': target_ac,
            }
        )

        # Check hit
        if is_miss:
            result.description = f"{attacker.name} attacks {target.name} with {weapon}: {roll_str}+{attack_bonus}={total_attack} - CRITICAL MISS!"
            self._log(result.description)
            return result

        if not is_crit and total_attack < target_ac:
            result.description = f"{attacker.name} attacks {target.name} with {weapon}: {roll_str}+{attack_bonus}={total_attack} vs AC {target_ac} - MISS"
            self._log(result.description)
            return result

        # Hit! Calculate damage
        result.success = True
        result.critical = is_crit

        damage_dice = weapon_data['damage']
        damage_type = weapon_data['type']

        # Roll damage
        damage_total, damage_rolls, _ = roll(damage_dice)

        # Critical hit doubles dice
        if is_crit:
            crit_damage, crit_rolls, _ = roll(damage_dice)
            damage_total += crit_damage
            damage_rolls.extend(crit_rolls)

        # Add damage modifier
        if hasattr(entity, 'get_damage_bonus'):
            damage_mod = entity.get_damage_bonus(weapon, is_finesse)
        else:
            damage_mod = entity.damage_bonus if hasattr(entity, 'damage_bonus') else 0

        damage_total += damage_mod
        damage_total = max(0, damage_total)

        # Apply damage
        damage_result = target.entity.take_damage(damage_total)
        result.damage_dealt = damage_result['damage_taken']
        result.damage_type = damage_type
        result.target_id = target_id

        crit_str = " CRITICAL HIT!" if is_crit else ""
        result.description = f"{attacker.name} attacks {target.name} with {weapon}: {roll_str}+{attack_bonus}={total_attack} vs AC {target_ac} - HIT!{crit_str} {damage_total} {damage_type} damage"

        if damage_result.get('knocked_unconscious'):
            result.description += f" - {target.name} falls unconscious!"
        if damage_result.get('instant_death'):
            result.description += f" - {target.name} is killed instantly!"

        self._log(result.description)
        return result

    def cast_spell(self, caster_id: str, spell_name: str, target_id: Optional[str] = None,
                   slot_level: Optional[int] = None) -> ActionResult:
        """Cast a spell."""
        caster = self.combatants.get(caster_id)
        if not caster:
            return ActionResult(success=False, description="Invalid caster")

        entity = caster.entity
        if not hasattr(entity, 'spellbook') or entity.spellbook is None:
            return ActionResult(success=False, description="Cannot cast spells")

        # Check if can cast
        if not entity.spellbook.can_cast(spell_name, slot_level):
            return ActionResult(success=False, description=f"Cannot cast {spell_name}")

        # Check action economy
        from ..characters.spells import get_spell, CastingTime
        spell = get_spell(spell_name)
        if not spell:
            return ActionResult(success=False, description=f"Unknown spell: {spell_name}")

        economy = caster.action_economy
        if spell.casting_time == CastingTime.ACTION:
            if not economy.use_action():
                return ActionResult(success=False, description="No action available")
        elif spell.casting_time == CastingTime.BONUS_ACTION:
            if not economy.use_bonus_action():
                return ActionResult(success=False, description="No bonus action available")
        elif spell.casting_time == CastingTime.REACTION:
            if not economy.use_reaction():
                return ActionResult(success=False, description="No reaction available")

        # Cast the spell
        cast_result = entity.spellbook.cast_spell(spell_name, slot_level)
        if not cast_result:
            return ActionResult(success=False, description=f"Failed to cast {spell_name}")

        result = ActionResult(
            success=True,
            description=f"{caster.name} casts {spell.name}",
            spell_used=spell.name,
            slot_used=slot_level or spell.level,
        )

        # Handle spell effects
        if spell.damage_dice and target_id:
            target = self.combatants.get(target_id)
            if target:
                # Spell attack or saving throw
                if spell.saving_throw:
                    # Target makes saving throw
                    save_dc = entity.spellbook.get_spell_save_dc(
                        entity.proficiency_bonus,
                        entity.abilities.get_modifier(entity.spellbook.spellcasting_ability)
                    )

                    if hasattr(target.entity, 'get_saving_throw_modifier'):
                        save_mod = target.entity.get_saving_throw_modifier(spell.saving_throw)
                    else:
                        save_mod = 0

                    save_roll = d20() + save_mod
                    saved = save_roll >= save_dc

                    # Roll damage
                    damage_total, _, _ = roll(spell.damage_dice)
                    if saved:
                        damage_total //= 2  # Half damage on save

                    damage_result = target.entity.take_damage(damage_total)
                    result.damage_dealt = damage_result['damage_taken']
                    result.damage_type = spell.damage_type
                    result.target_id = target_id

                    save_str = "saves" if saved else "fails"
                    result.description = f"{caster.name} casts {spell.name} on {target.name}. {target.name} {save_str} (DC {save_dc}). {damage_total} {spell.damage_type} damage"

                else:
                    # Spell attack
                    spell_attack = entity.spellbook.get_spell_attack_bonus(
                        entity.proficiency_bonus,
                        entity.abilities.get_modifier(entity.spellbook.spellcasting_ability)
                    )

                    attack_roll = d20()
                    total = attack_roll + spell_attack
                    target_ac = target.entity.armor_class if hasattr(target.entity, 'armor_class') else target.entity.ac

                    if total >= target_ac:
                        damage_total, _, _ = roll(spell.damage_dice)
                        damage_result = target.entity.take_damage(damage_total)
                        result.damage_dealt = damage_result['damage_taken']
                        result.damage_type = spell.damage_type
                        result.target_id = target_id
                        result.description = f"{caster.name} casts {spell.name} at {target.name}: {attack_roll}+{spell_attack}={total} vs AC {target_ac} - HIT! {damage_total} {spell.damage_type} damage"
                    else:
                        result.description = f"{caster.name} casts {spell.name} at {target.name}: {attack_roll}+{spell_attack}={total} vs AC {target_ac} - MISS"

        self._log(result.description)
        return result

    def dodge(self, combatant_id: str) -> ActionResult:
        """Take the Dodge action."""
        combatant = self.combatants.get(combatant_id)
        if not combatant:
            return ActionResult(success=False, description="Invalid combatant")

        if not combatant.action_economy.use_action():
            return ActionResult(success=False, description="No action available")

        combatant.is_dodging = True
        result = ActionResult(
            success=True,
            description=f"{combatant.name} takes the Dodge action. Attacks against them have disadvantage."
        )
        self._log(result.description)
        return result

    def dash(self, combatant_id: str, is_bonus_action: bool = False) -> ActionResult:
        """Take the Dash action."""
        combatant = self.combatants.get(combatant_id)
        if not combatant:
            return ActionResult(success=False, description="Invalid combatant")

        if is_bonus_action:
            if not combatant.action_economy.use_bonus_action():
                return ActionResult(success=False, description="No bonus action available")
        else:
            if not combatant.action_economy.use_action():
                return ActionResult(success=False, description="No action available")

        # Double remaining movement
        speed = combatant.entity.speed if hasattr(combatant.entity, 'speed') else 30
        combatant.action_economy.movement_remaining += speed

        result = ActionResult(
            success=True,
            description=f"{combatant.name} Dashes! Movement increased to {combatant.action_economy.movement_remaining} ft."
        )
        self._log(result.description)
        return result

    def disengage(self, combatant_id: str, is_bonus_action: bool = False) -> ActionResult:
        """Take the Disengage action."""
        combatant = self.combatants.get(combatant_id)
        if not combatant:
            return ActionResult(success=False, description="Invalid combatant")

        if is_bonus_action:
            if not combatant.action_economy.use_bonus_action():
                return ActionResult(success=False, description="No bonus action available")
        else:
            if not combatant.action_economy.use_action():
                return ActionResult(success=False, description="No action available")

        result = ActionResult(
            success=True,
            description=f"{combatant.name} Disengages. Movement won't provoke opportunity attacks."
        )
        self._log(result.description)
        return result

    def help_action(self, helper_id: str, target_id: str) -> ActionResult:
        """Take the Help action."""
        helper = self.combatants.get(helper_id)
        target = self.combatants.get(target_id)

        if not helper or not target:
            return ActionResult(success=False, description="Invalid helper or target")

        if not helper.action_economy.use_action():
            return ActionResult(success=False, description="No action available")

        target.helped_by = helper_id
        result = ActionResult(
            success=True,
            description=f"{helper.name} helps {target.name}. Their next attack or check has advantage."
        )
        self._log(result.description)
        return result

    def death_save(self, combatant_id: str) -> ActionResult:
        """Make a death saving throw."""
        combatant = self.combatants.get(combatant_id)
        if not combatant:
            return ActionResult(success=False, description="Invalid combatant")

        if combatant.is_conscious:
            return ActionResult(success=False, description="Not unconscious")

        roll_result = d20()
        save_result = combatant.entity.death_save(roll_result)

        result = ActionResult(
            success=save_result['success'],
            description=f"{combatant.name} makes a death save: {roll_result}",
            roll_details={'roll': roll_result}
        )

        if save_result.get('revived'):
            result.description += f" - Natural 20! {combatant.name} regains 1 HP!"
        elif save_result.get('stabilized'):
            result.description += f" - Stabilized! (3 successes)"
        elif save_result.get('died'):
            result.description += f" - {combatant.name} has died. (3 failures)"
        else:
            successes = combatant.entity.death_save_successes
            failures = combatant.entity.death_save_failures
            result.description += f" - {'Success' if save_result['success'] else 'Failure'} ({successes} successes, {failures} failures)"

        self._log(result.description)
        return result

    def end_combat(self, reason: str = "Combat ended") -> None:
        """End the combat encounter."""
        if self.state == CombatState.IN_PROGRESS:
            self.state = CombatState.FLED
        self._log(f"\n=== {reason} ===")

    def _log(self, message: str) -> None:
        """Add a message to the combat log."""
        self.combat_log.append(message)

    def get_combat_log(self) -> List[str]:
        """Get the combat log."""
        return self.combat_log

    def get_available_actions(self, combatant_id: str) -> List[CombatAction]:
        """Get available actions for a combatant."""
        combatant = self.combatants.get(combatant_id)
        if not combatant:
            return []

        actions = []
        economy = combatant.action_economy

        # Standard actions
        if economy.action_available or economy.extra_attacks > 0:
            actions.append(STANDARD_ACTIONS['attack'])
        if economy.action_available:
            actions.extend([
                STANDARD_ACTIONS['dash'],
                STANDARD_ACTIONS['disengage'],
                STANDARD_ACTIONS['dodge'],
                STANDARD_ACTIONS['help'],
                STANDARD_ACTIONS['hide'],
            ])

        # Class bonus actions
        if economy.bonus_action_available and combatant.is_player:
            class_name = combatant.entity.char_class.name.lower()
            if class_name in CLASS_BONUS_ACTIONS:
                actions.extend(CLASS_BONUS_ACTIONS[class_name])

        return actions

    def get_valid_targets(self, combatant_id: str, friendly: bool = False) -> List[Combatant]:
        """Get valid targets for an action."""
        combatant = self.combatants.get(combatant_id)
        if not combatant:
            return []

        targets = []
        for c in self.combatants.values():
            if c.entity_id == combatant_id:
                continue
            if not c.is_alive:
                continue

            # Friendly targets (allies)
            if friendly and c.is_player == combatant.is_player:
                targets.append(c)
            # Hostile targets (enemies)
            elif not friendly and c.is_player != combatant.is_player:
                targets.append(c)

        return targets

    def to_dict(self) -> Dict:
        """Convert to dictionary for serialization."""
        return {
            'state': self.state.name,
            'initiative': self.initiative.to_dict(),
            'combatants': {
                cid: {
                    'entity_id': c.entity_id,
                    'is_player': c.is_player,
                    'action_economy': c.action_economy.to_dict(),
                    'is_dodging': c.is_dodging,
                    'is_hidden': c.is_hidden,
                    'helped_by': c.helped_by,
                    'readied_action': c.readied_action,
                }
                for cid, c in self.combatants.items()
            },
            'combat_log': self.combat_log,
            'turn_number': self.turn_number,
        }

    def display_status(self) -> str:
        """Return a formatted combat status display."""
        lines = [
            f"\n{'=' * 50}",
            f"  COMBAT - Round {self.initiative.round_number}",
            f"{'=' * 50}",
        ]

        # Initiative order
        lines.append("\nInitiative Order:")
        for i, entry in enumerate(self.initiative.get_order()):
            combatant = self.combatants.get(entry.entity_id)
            if combatant:
                marker = ">>>" if i == self.initiative.current_index else "   "
                hp_str = f"{combatant.entity.current_hp}/{combatant.entity.max_hp}" if hasattr(combatant.entity, 'max_hp') else f"{combatant.entity.current_hp} HP"
                status = ""
                if not combatant.is_conscious:
                    status = " [UNCONSCIOUS]"
                elif combatant.is_dodging:
                    status = " [DODGING]"
                lines.append(f"{marker} {entry.initiative:2d} | {entry.name:20s} | {hp_str}{status}")

        lines.append(f"{'=' * 50}")
        return "\n".join(lines)
