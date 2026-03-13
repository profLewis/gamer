"""Player controllers for human and AI players."""

# Keep package import lightweight. Modules are imported lazily.
__all__ = ["Player", "HumanPlayer", "AIPlayer"]


def __getattr__(name):
    if name == "Player":
        from .player import Player
        return Player
    if name == "HumanPlayer":
        from .human_player import HumanPlayer
        return HumanPlayer
    if name == "AIPlayer":
        from .ai_player import AIPlayer
        return AIPlayer
    raise AttributeError(name)
