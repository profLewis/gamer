"""Human player controller with CLI input."""

from typing import Dict, List, Optional, Any, TYPE_CHECKING

from .player import Player
from ..utils.display import (
    print_menu, get_input, get_menu_choice, confirm,
    print_table, Colors, print_separator, format_hp
)

if TYPE_CHECKING:
    from ..combat.combat import CombatEncounter, Combatant
    from ..characters.character import Character


class HumanPlayer(Player):
    """Human player that uses CLI for input."""

    def __init__(self, name: str):
        """Initialize human player."""
        super().__init__(name)
        self.is_human = True

    def get_combat_action(self, combat: 'CombatEncounter',
                         combatant: 'Combatant') -> Dict[str, Any]:
        """Get combat action from human player via CLI."""
        print(f"\n{Colors.BOLD}{combatant.name}'s turn{Colors.RESET}")
        print(combat.display_status())

        # Show available actions
        available = combat.get_available_actions(combatant.entity_id)
        action_names = [a.name for a in available]

        # Add end turn option
        action_names.append("End Turn")

        print_menu(action_names, "Choose your action:")
        choice = self._get_valid_choice(len(action_names))

        if choice == len(action_names):  # End Turn
            return {'action': 'end_turn'}

        chosen_action = available[choice - 1]

        result = {
            'action': chosen_action.category.value.lower().replace(' ', '_'),
        }

        # Get target if needed
        if chosen_action.requires_target:
            # Determine if friendly or hostile target
            if chosen_action.category.value in ['Help']:
                targets = combat.get_valid_targets(combatant.entity_id, friendly=True)
            else:
                targets = combat.get_valid_targets(combatant.entity_id, friendly=False)

            if targets:
                target_id = self.choose_target(targets)
                result['target_id'] = target_id

        # Get additional parameters based on action type
        if chosen_action.category.value == 'Attack':
            result['action'] = 'attack'
            # Let player choose weapon
            weapons = combatant.entity.equipment.weapons
            if weapons:
                print_menu(weapons, "Choose weapon:")
                weapon_choice = self._get_valid_choice(len(weapons))
                result['weapon'] = weapons[weapon_choice - 1]

        elif chosen_action.category.value == 'Cast a Spell':
            result['action'] = 'cast'
            # List available spells
            if hasattr(combatant.entity, 'spellbook') and combatant.entity.spellbook:
                spellbook = combatant.entity.spellbook
                available_spells = list(spellbook.cantrips) + list(spellbook.known_spells)
                if available_spells:
                    print_menu(available_spells, "Choose spell:")
                    spell_choice = self._get_valid_choice(len(available_spells))
                    result['spell'] = available_spells[spell_choice - 1]

        return result

    def get_exploration_action(self, available_actions: List[str]) -> str:
        """Get exploration action from human player."""
        print_menu(available_actions, "What would you like to do?")
        choice = self._get_valid_choice(len(available_actions))
        return available_actions[choice - 1]

    def get_dialogue_choice(self, options: List[str]) -> int:
        """Get dialogue choice from human player."""
        print_menu(options, "Your response:")
        return self._get_valid_choice(len(options)) - 1

    def choose_target(self, targets: List[Any]) -> Optional[str]:
        """Let human player choose a target."""
        if not targets:
            return None

        target_names = []
        for t in targets:
            if hasattr(t, 'entity'):
                hp_str = f" ({t.entity.current_hp}/{t.entity.max_hp} HP)" if hasattr(t.entity, 'max_hp') else ""
                target_names.append(f"{t.name}{hp_str}")
            else:
                target_names.append(str(t))

        print_menu(target_names, "Choose target:")
        choice = self._get_valid_choice(len(targets))

        target = targets[choice - 1]
        return target.entity_id if hasattr(target, 'entity_id') else str(target)

    def confirm(self, prompt: str) -> bool:
        """Get yes/no confirmation from human player."""
        return confirm(prompt)

    def notify(self, message: str) -> None:
        """Display a notification to the player."""
        print(f"\n{Colors.INFO}[{self.name}]{Colors.RESET} {message}")

    def display_status(self, character: 'Character') -> None:
        """Display character status."""
        print(character.display_sheet())

    def _get_valid_choice(self, max_choice: int) -> int:
        """Get a valid menu choice from the player."""
        while True:
            try:
                choice_str = get_input("Enter choice: ")
                choice = int(choice_str)
                if 1 <= choice <= max_choice:
                    return choice
                print(f"{Colors.WARNING}Please enter a number between 1 and {max_choice}{Colors.RESET}")
            except ValueError:
                print(f"{Colors.WARNING}Please enter a valid number{Colors.RESET}")

    def get_ability_score_assignment(self, scores: List[int],
                                     abilities: List[str]) -> Dict[str, int]:
        """Let player assign ability scores."""
        assigned = {}
        remaining_scores = scores.copy()
        remaining_abilities = abilities.copy()

        print("\nAssign your ability scores:")
        print(f"Scores available: {remaining_scores}")

        for _ in range(len(abilities)):
            # Show remaining
            print(f"\nRemaining scores: {remaining_scores}")
            print(f"Remaining abilities: {', '.join(remaining_abilities)}")

            # Choose ability
            print_menu(remaining_abilities, "Choose ability to assign:")
            ability_choice = self._get_valid_choice(len(remaining_abilities))
            ability = remaining_abilities.pop(ability_choice - 1)

            # Choose score
            score_strs = [str(s) for s in remaining_scores]
            print_menu(score_strs, f"Choose score for {ability}:")
            score_choice = self._get_valid_choice(len(remaining_scores))
            score = remaining_scores.pop(score_choice - 1)

            assigned[ability.lower()] = score
            print(f"{ability}: {score}")

        return assigned

    def choose_skills(self, available_skills: List[str], num_choices: int) -> List[str]:
        """Let player choose skill proficiencies."""
        chosen = []
        remaining = available_skills.copy()

        print(f"\nChoose {num_choices} skill proficiencies:")

        for i in range(num_choices):
            print(f"\nChoice {i + 1} of {num_choices}")
            print_menu(remaining, "Choose skill:")
            choice = self._get_valid_choice(len(remaining))
            skill = remaining.pop(choice - 1)
            chosen.append(skill)
            print(f"Selected: {skill}")

        return chosen

    def get_character_name(self) -> str:
        """Get character name from player."""
        while True:
            name = get_input("Enter character name: ").strip()
            if name:
                return name
            print(f"{Colors.WARNING}Please enter a valid name{Colors.RESET}")

    def display_combat_status(self, combat: 'CombatEncounter') -> None:
        """Display current combat status."""
        print(combat.display_status())

    def display_inventory(self, character: 'Character') -> None:
        """Display character inventory."""
        eq = character.equipment

        print(f"\n{Colors.SUBTITLE}=== {character.name}'s Inventory ==={Colors.RESET}")
        print(f"Gold: {eq.gold} gp")

        if eq.weapons:
            print(f"Weapons: {', '.join(eq.weapons)}")
        if eq.armor:
            print(f"Armor: {eq.armor}")
        if eq.shield:
            print("Shield: Yes")
        if eq.items:
            print(f"Items: {', '.join(eq.items)}")

    def display_spells(self, character: 'Character') -> None:
        """Display character's spells."""
        if not character.spellbook:
            print("This character cannot cast spells.")
            return

        spellbook = character.spellbook
        print(f"\n{Colors.SUBTITLE}=== {character.name}'s Spellbook ==={Colors.RESET}")

        if spellbook.cantrips:
            print(f"Cantrips: {', '.join(spellbook.cantrips)}")

        if spellbook.known_spells:
            print(f"Known Spells: {', '.join(spellbook.known_spells)}")

        # Show spell slots
        print("\nSpell Slots:")
        for level in range(1, 6):
            current = spellbook.slot_tracker.get_slots(level)
            maximum = spellbook.slot_tracker.get_max_slots(level)
            if maximum > 0:
                print(f"  Level {level}: {current}/{maximum}")

        if spellbook.concentrating_on:
            print(f"\nConcentrating on: {spellbook.concentrating_on}")
