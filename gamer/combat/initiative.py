"""Initiative tracking for D&D 5e combat."""

from dataclasses import dataclass, field
from typing import List, Dict, Optional, Any
from ..utils.dice import d20


@dataclass
class InitiativeEntry:
    """An entry in the initiative order."""
    name: str
    initiative: int
    dex_modifier: int
    entity_id: str
    is_player: bool = True
    has_acted: bool = False

    def __lt__(self, other: 'InitiativeEntry') -> bool:
        """Sort by initiative (descending), then DEX mod (descending)."""
        if self.initiative != other.initiative:
            return self.initiative > other.initiative  # Higher goes first
        return self.dex_modifier > other.dex_modifier


class InitiativeTracker:
    """Tracks initiative order in combat."""

    def __init__(self):
        """Initialize the tracker."""
        self.entries: List[InitiativeEntry] = []
        self.current_index: int = 0
        self.round_number: int = 1

    def add_combatant(self, name: str, entity_id: str, dex_modifier: int,
                      is_player: bool = True, roll: Optional[int] = None) -> int:
        """Add a combatant and roll initiative. Returns the initiative value."""
        if roll is None:
            roll = d20(modifier=dex_modifier)

        entry = InitiativeEntry(
            name=name,
            initiative=roll,
            dex_modifier=dex_modifier,
            entity_id=entity_id,
            is_player=is_player,
        )
        self.entries.append(entry)
        self._sort()
        return roll

    def remove_combatant(self, entity_id: str) -> bool:
        """Remove a combatant from initiative."""
        for i, entry in enumerate(self.entries):
            if entry.entity_id == entity_id:
                self.entries.pop(i)
                # Adjust current index if needed
                if i < self.current_index:
                    self.current_index -= 1
                elif i == self.current_index and self.current_index >= len(self.entries):
                    self.current_index = 0
                return True
        return False

    def _sort(self) -> None:
        """Sort entries by initiative order."""
        self.entries.sort()

    def get_current(self) -> Optional[InitiativeEntry]:
        """Get the current combatant."""
        if not self.entries:
            return None
        return self.entries[self.current_index]

    def next_turn(self) -> Optional[InitiativeEntry]:
        """Advance to the next turn. Returns the new current combatant."""
        if not self.entries:
            return None

        # Mark current as having acted
        self.entries[self.current_index].has_acted = True

        # Move to next
        self.current_index += 1

        # Check for new round
        if self.current_index >= len(self.entries):
            self.current_index = 0
            self.round_number += 1
            # Reset has_acted flags
            for entry in self.entries:
                entry.has_acted = False

        return self.get_current()

    def get_order(self) -> List[InitiativeEntry]:
        """Get the full initiative order."""
        return list(self.entries)

    def get_entry(self, entity_id: str) -> Optional[InitiativeEntry]:
        """Get an entry by entity ID."""
        for entry in self.entries:
            if entry.entity_id == entity_id:
                return entry
        return None

    def set_initiative(self, entity_id: str, new_initiative: int) -> bool:
        """Change a combatant's initiative."""
        entry = self.get_entry(entity_id)
        if entry:
            entry.initiative = new_initiative
            self._sort()
            # Find new index of current combatant
            current = self.entries[self.current_index]
            for i, e in enumerate(self.entries):
                if e.entity_id == current.entity_id:
                    self.current_index = i
                    break
            return True
        return False

    def delay_turn(self, entity_id: str, new_initiative: int) -> bool:
        """Delay a combatant's turn to a lower initiative."""
        entry = self.get_entry(entity_id)
        if entry and new_initiative < entry.initiative:
            return self.set_initiative(entity_id, new_initiative)
        return False

    def ready_action(self, entity_id: str) -> bool:
        """Mark a combatant as readying an action."""
        entry = self.get_entry(entity_id)
        if entry:
            entry.has_acted = True
            return True
        return False

    def reset(self) -> None:
        """Reset the tracker for a new combat."""
        self.entries.clear()
        self.current_index = 0
        self.round_number = 1

    def is_players_turn(self) -> bool:
        """Check if it's a player's turn."""
        current = self.get_current()
        return current.is_player if current else False

    def get_remaining_combatants(self, is_player: Optional[bool] = None) -> List[InitiativeEntry]:
        """Get combatants who haven't acted this round."""
        remaining = [e for e in self.entries if not e.has_acted]
        if is_player is not None:
            remaining = [e for e in remaining if e.is_player == is_player]
        return remaining

    def to_dict(self) -> Dict:
        """Convert to dictionary for serialization."""
        return {
            'entries': [
                {
                    'name': e.name,
                    'initiative': e.initiative,
                    'dex_modifier': e.dex_modifier,
                    'entity_id': e.entity_id,
                    'is_player': e.is_player,
                    'has_acted': e.has_acted,
                }
                for e in self.entries
            ],
            'current_index': self.current_index,
            'round_number': self.round_number,
        }

    @classmethod
    def from_dict(cls, data: Dict) -> 'InitiativeTracker':
        """Create from dictionary."""
        tracker = cls()
        tracker.current_index = data['current_index']
        tracker.round_number = data['round_number']

        for entry_data in data['entries']:
            entry = InitiativeEntry(
                name=entry_data['name'],
                initiative=entry_data['initiative'],
                dex_modifier=entry_data['dex_modifier'],
                entity_id=entry_data['entity_id'],
                is_player=entry_data['is_player'],
                has_acted=entry_data['has_acted'],
            )
            tracker.entries.append(entry)

        return tracker

    def display(self) -> str:
        """Return a formatted display of initiative order."""
        lines = [f"=== Round {self.round_number} ==="]

        for i, entry in enumerate(self.entries):
            marker = ">" if i == self.current_index else " "
            acted = "[x]" if entry.has_acted else "[ ]"
            side = "PC" if entry.is_player else "NPC"
            lines.append(f"{marker} {acted} {entry.initiative:2d} - {entry.name} ({side})")

        return "\n".join(lines)
