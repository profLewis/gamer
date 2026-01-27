"""D&D 5e Text-Based RPG Game Package."""

__version__ = "0.1.0"
__author__ = "D&D RPG Team"

from .game.engine import GameEngine, GameState
from .characters.character import Character
from .combat.combat import CombatEncounter

__all__ = ['GameEngine', 'GameState', 'Character', 'CombatEncounter']
