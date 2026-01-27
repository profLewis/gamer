"""Game session save/load functionality."""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any
import json
import os
from datetime import datetime
from pathlib import Path

from ..characters.character import Character


@dataclass
class Session:
    """A game session containing all save data."""
    name: str
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())
    last_played: str = field(default_factory=lambda: datetime.now().isoformat())

    # Game state
    party: List[Dict] = field(default_factory=list)  # Serialized characters
    dungeon_state: Optional[Dict] = None
    dm_state: Optional[Dict] = None

    # Progress
    total_xp_earned: int = 0
    monsters_defeated: int = 0
    rooms_explored: int = 0
    gold_collected: int = 0
    deaths: int = 0

    # Settings
    difficulty: str = "medium"
    auto_save: bool = True

    def update_timestamp(self) -> None:
        """Update the last played timestamp."""
        self.last_played = datetime.now().isoformat()

    def add_character(self, character: Character) -> None:
        """Add a character to the session."""
        self.party.append(character.to_dict())

    def get_characters(self) -> List[Character]:
        """Reconstruct characters from saved data."""
        characters = []
        for char_data in self.party:
            try:
                char = Character.from_dict(char_data)
                characters.append(char)
            except Exception as e:
                print(f"Warning: Could not load character: {e}")
        return characters

    def to_dict(self) -> Dict:
        """Convert session to dictionary for JSON serialization."""
        return {
            'name': self.name,
            'created_at': self.created_at,
            'last_played': self.last_played,
            'party': self.party,
            'dungeon_state': self.dungeon_state,
            'dm_state': self.dm_state,
            'total_xp_earned': self.total_xp_earned,
            'monsters_defeated': self.monsters_defeated,
            'rooms_explored': self.rooms_explored,
            'gold_collected': self.gold_collected,
            'deaths': self.deaths,
            'difficulty': self.difficulty,
            'auto_save': self.auto_save,
        }

    @classmethod
    def from_dict(cls, data: Dict) -> 'Session':
        """Create session from dictionary."""
        return cls(
            name=data['name'],
            created_at=data.get('created_at', datetime.now().isoformat()),
            last_played=data.get('last_played', datetime.now().isoformat()),
            party=data.get('party', []),
            dungeon_state=data.get('dungeon_state'),
            dm_state=data.get('dm_state'),
            total_xp_earned=data.get('total_xp_earned', 0),
            monsters_defeated=data.get('monsters_defeated', 0),
            rooms_explored=data.get('rooms_explored', 0),
            gold_collected=data.get('gold_collected', 0),
            deaths=data.get('deaths', 0),
            difficulty=data.get('difficulty', 'medium'),
            auto_save=data.get('auto_save', True),
        )

    def get_summary(self) -> str:
        """Get a summary of the session."""
        lines = [
            f"Session: {self.name}",
            f"Created: {self.created_at[:10]}",
            f"Last Played: {self.last_played[:10]}",
            f"Party Size: {len(self.party)}",
            f"XP Earned: {self.total_xp_earned}",
            f"Monsters Defeated: {self.monsters_defeated}",
            f"Rooms Explored: {self.rooms_explored}",
        ]
        return "\n".join(lines)


def get_save_directory() -> Path:
    """Get the save game directory, creating it if necessary."""
    # Use user's home directory
    save_dir = Path.home() / ".dnd_rpg" / "saves"
    save_dir.mkdir(parents=True, exist_ok=True)
    return save_dir


def get_save_path(session_name: str) -> Path:
    """Get the full path for a save file."""
    # Sanitize session name for filename
    safe_name = "".join(c for c in session_name if c.isalnum() or c in "._- ")
    safe_name = safe_name.replace(" ", "_")
    return get_save_directory() / f"{safe_name}.json"


def save_session(session: Session) -> bool:
    """
    Save a session to disk.

    Returns True if successful, False otherwise.
    """
    try:
        session.update_timestamp()
        save_path = get_save_path(session.name)

        with open(save_path, 'w') as f:
            json.dump(session.to_dict(), f, indent=2)

        return True
    except Exception as e:
        print(f"Error saving session: {e}")
        return False


def load_session(session_name: str) -> Optional[Session]:
    """
    Load a session from disk.

    Returns the Session if successful, None otherwise.
    """
    try:
        save_path = get_save_path(session_name)

        if not save_path.exists():
            return None

        with open(save_path, 'r') as f:
            data = json.load(f)

        return Session.from_dict(data)
    except Exception as e:
        print(f"Error loading session: {e}")
        return None


def delete_session(session_name: str) -> bool:
    """
    Delete a saved session.

    Returns True if successful, False otherwise.
    """
    try:
        save_path = get_save_path(session_name)

        if save_path.exists():
            os.remove(save_path)
            return True
        return False
    except Exception as e:
        print(f"Error deleting session: {e}")
        return False


def list_sessions() -> List[Dict[str, Any]]:
    """
    List all saved sessions.

    Returns a list of session summaries.
    """
    sessions = []
    save_dir = get_save_directory()

    for save_file in save_dir.glob("*.json"):
        try:
            with open(save_file, 'r') as f:
                data = json.load(f)

            sessions.append({
                'name': data['name'],
                'last_played': data.get('last_played', 'Unknown'),
                'party_size': len(data.get('party', [])),
                'file_path': str(save_file),
            })
        except Exception:
            continue

    # Sort by last played, most recent first
    sessions.sort(key=lambda x: x['last_played'], reverse=True)
    return sessions


def session_exists(session_name: str) -> bool:
    """Check if a session with the given name exists."""
    save_path = get_save_path(session_name)
    return save_path.exists()


def auto_save(session: Session) -> None:
    """Perform an auto-save if enabled."""
    if session.auto_save:
        save_session(session)


def create_backup(session: Session) -> bool:
    """Create a backup of the current session."""
    try:
        backup_name = f"{session.name}_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        backup_session = Session.from_dict(session.to_dict())
        backup_session.name = backup_name
        return save_session(backup_session)
    except Exception as e:
        print(f"Error creating backup: {e}")
        return False
