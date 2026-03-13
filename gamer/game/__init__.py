"""Game engine and session management."""

# Keep package import lightweight. Modules are imported lazily.
__all__ = ["GameEngine", "GameState", "DungeonMaster", "Session", "save_session", "load_session"]


def __getattr__(name):
    if name in {"GameEngine", "GameState"}:
        from .engine import GameEngine, GameState
        return {"GameEngine": GameEngine, "GameState": GameState}[name]
    if name == "DungeonMaster":
        from .dm import DungeonMaster
        return DungeonMaster
    if name in {"Session", "save_session", "load_session"}:
        from .session import Session, save_session, load_session
        return {"Session": Session, "save_session": save_session, "load_session": load_session}[name]
    raise AttributeError(name)
