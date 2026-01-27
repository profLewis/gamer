"""Base player interface."""

from abc import ABC, abstractmethod
from typing import Dict, List, Optional, Any, TYPE_CHECKING

if TYPE_CHECKING:
    from ..combat.combat import CombatEncounter, Combatant
    from ..characters.character import Character


class Player(ABC):
    """Base class for player controllers (human or AI)."""

    def __init__(self, name: str):
        """Initialize the player."""
        self.name = name
        self.is_human: bool = True

    @abstractmethod
    def get_combat_action(self, combat: 'CombatEncounter',
                         combatant: 'Combatant') -> Dict[str, Any]:
        """
        Get the player's chosen combat action.

        Args:
            combat: The current combat encounter
            combatant: The player's combatant

        Returns:
            Dict with 'action', 'target_id', and any additional parameters
        """
        pass

    @abstractmethod
    def get_exploration_action(self, available_actions: List[str]) -> str:
        """
        Get the player's chosen exploration action.

        Args:
            available_actions: List of available action names

        Returns:
            The chosen action name
        """
        pass

    @abstractmethod
    def get_dialogue_choice(self, options: List[str]) -> int:
        """
        Get the player's dialogue choice.

        Args:
            options: List of dialogue options

        Returns:
            Index of chosen option
        """
        pass

    @abstractmethod
    def choose_target(self, targets: List[Any]) -> Optional[str]:
        """
        Choose a target from a list.

        Args:
            targets: List of potential targets

        Returns:
            ID of chosen target, or None
        """
        pass

    @abstractmethod
    def confirm(self, prompt: str) -> bool:
        """
        Get yes/no confirmation from player.

        Args:
            prompt: The confirmation prompt

        Returns:
            True if confirmed, False otherwise
        """
        pass

    def notify(self, message: str) -> None:
        """
        Send a notification to the player.
        Default implementation does nothing - override as needed.

        Args:
            message: The notification message
        """
        pass

    def display_status(self, character: 'Character') -> None:
        """
        Display character status to the player.
        Default implementation does nothing - override as needed.

        Args:
            character: The character to display
        """
        pass
