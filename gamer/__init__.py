"""D&D 5e Text-Based RPG package."""

__version__ = "0.1.0"
__author__ = "D&D RPG Team"

# Keep package import lightweight. Heavy modules are imported lazily.
__all__ = ["GameEngine", "GameState", "Character", "CombatEncounter"]


def __getattr__(name):
    """Lazily import commonly used symbols."""
    if name in {"GameEngine", "GameState"}:
        from .game.engine import GameEngine, GameState
        return {"GameEngine": GameEngine, "GameState": GameState}[name]
    if name == "Character":
        from .characters.character import Character
        return Character
    if name == "CombatEncounter":
        from .combat.combat import CombatEncounter
        return CombatEncounter
    raise AttributeError(name)
