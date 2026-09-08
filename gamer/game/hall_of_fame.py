"""Hall of Fame persistence and iOS-seeded default runs."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import List
import json
import os
import uuid

_hof_dir_cache: Path | None = None
_hof_dir_warned = False


def _get_hall_of_fame_dir() -> Path:
    """Resolve a writable Hall of Fame directory."""
    global _hof_dir_cache, _hof_dir_warned

    if _hof_dir_cache is not None:
        return _hof_dir_cache

    env_dir = os.environ.get("DND_RPG_HOF_DIR", "").strip()
    candidates: list[Path] = []
    if env_dir:
        candidates.append(Path(env_dir).expanduser())
    candidates.append(Path.home() / ".dnd_rpg" / "hall_of_fame")
    candidates.append(Path.cwd() / ".dnd_rpg" / "hall_of_fame")

    for candidate in candidates:
        try:
            candidate.mkdir(parents=True, exist_ok=True)
            test_file = candidate / ".write_test"
            test_file.write_text("ok", encoding="utf-8")
            test_file.unlink(missing_ok=True)
            _hof_dir_cache = candidate
            return candidate
        except Exception:
            continue

    fallback = Path("/tmp") / "dnd_rpg" / "hall_of_fame"
    fallback.mkdir(parents=True, exist_ok=True)
    if not _hof_dir_warned:
        print(f"Warning: Using fallback Hall of Fame path: {fallback}")
        _hof_dir_warned = True
    _hof_dir_cache = fallback
    return fallback


@dataclass
class HallOfFameEntry:
    """Single completed run record."""
    id: str
    date: str
    party_names: List[str]
    party_description: str
    dungeon_name: str
    dungeon_level: int
    outcome: str  # "victory" | "defeat"
    gold_collected: int
    monsters_slain: int
    combats_won: int
    rooms_explored: int
    total_rooms: int
    game_time_minutes: int

    @property
    def score(self) -> int:
        """Composite score used by iOS hall of fame."""
        victory_bonus = 500 if self.outcome == "victory" else 0
        exploration_bonus = (self.rooms_explored * 100 // self.total_rooms) if self.total_rooms > 0 else 0
        return (victory_bonus + self.gold_collected + self.monsters_slain * 20 + self.combats_won * 50 + exploration_bonus) * self.dungeon_level

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "date": self.date,
            "party_names": self.party_names,
            "party_description": self.party_description,
            "dungeon_name": self.dungeon_name,
            "dungeon_level": self.dungeon_level,
            "outcome": self.outcome,
            "gold_collected": self.gold_collected,
            "monsters_slain": self.monsters_slain,
            "combats_won": self.combats_won,
            "rooms_explored": self.rooms_explored,
            "total_rooms": self.total_rooms,
            "game_time_minutes": self.game_time_minutes,
        }

    @classmethod
    def from_dict(cls, data: dict) -> "HallOfFameEntry":
        return cls(
            id=data["id"],
            date=data["date"],
            party_names=data.get("party_names", []),
            party_description=data.get("party_description", ""),
            dungeon_name=data.get("dungeon_name", ""),
            dungeon_level=int(data.get("dungeon_level", 1)),
            outcome=data.get("outcome", "defeat"),
            gold_collected=int(data.get("gold_collected", 0)),
            monsters_slain=int(data.get("monsters_slain", 0)),
            combats_won=int(data.get("combats_won", 0)),
            rooms_explored=int(data.get("rooms_explored", 0)),
            total_rooms=int(data.get("total_rooms", 0)),
            game_time_minutes=int(data.get("game_time_minutes", 0)),
        )


class HallOfFameManager:
    """File-backed Hall of Fame with seeded defaults."""

    def __init__(self) -> None:
        self._dir = _get_hall_of_fame_dir()

    def _path_for(self, entry_id: str) -> Path:
        return self._dir / f"{entry_id}.json"

    def list_entries(self) -> List[HallOfFameEntry]:
        entries: List[HallOfFameEntry] = []
        for p in self._dir.glob("*.json"):
            try:
                data = json.loads(p.read_text(encoding="utf-8"))
                entries.append(HallOfFameEntry.from_dict(data))
            except Exception:
                continue
        entries.sort(key=lambda e: e.score, reverse=True)
        return entries

    def add_entry(self, entry: HallOfFameEntry) -> None:
        self._path_for(entry.id).write_text(json.dumps(entry.to_dict(), indent=2), encoding="utf-8")
        self.trim_to_top(10)

    def trim_to_top(self, limit: int = 10) -> None:
        entries = self.list_entries()
        if len(entries) <= limit:
            return
        for e in entries[limit:]:
            try:
                self._path_for(e.id).unlink(missing_ok=True)
            except Exception:
                pass

    def seed_if_empty(self) -> None:
        """Seed iOS default Hall of Fame entries when storage is empty."""
        if self.list_entries():
            return
        now = datetime.now()

        def make(days_ago: int, party_names: List[str], party_description: str, dungeon_name: str,
                 dungeon_level: int, outcome: str, gold_collected: int, monsters_slain: int,
                 combats_won: int, rooms_explored: int, total_rooms: int, game_time_minutes: int) -> HallOfFameEntry:
            return HallOfFameEntry(
                id=str(uuid.uuid4()),
                date=(now - timedelta(days=days_ago)).isoformat(),
                party_names=party_names,
                party_description=party_description,
                dungeon_name=dungeon_name,
                dungeon_level=dungeon_level,
                outcome=outcome,
                gold_collected=gold_collected,
                monsters_slain=monsters_slain,
                combats_won=combats_won,
                rooms_explored=rooms_explored,
                total_rooms=total_rooms,
                game_time_minutes=game_time_minutes,
            )

        seed_entries = [
            make(2, ["Robin of Loxley", "Ged", "Granny Weatherwax"], "Robin of Loxley (Ranger), Ged (Wizard), Granny Weatherwax (Cleric)", "Erewhon", 3, "victory", 420, 18, 7, 12, 14, 1400),
            make(5, ["Valerian", "Willow", "Hawk", "Beast Master"], "Valerian (Fighter), Willow (Wizard), Hawk (Ranger), Beast Master (Fighter)", "Skull Island", 3, "victory", 380, 16, 6, 11, 14, 1200),
            make(8, ["Edgin", "Holga", "Xenk"], "Edgin (Rogue), Holga (Barbarian), Xenk (Fighter)", "Barsoom", 3, "defeat", 280, 14, 5, 8, 14, 1100),
            make(10, ["Rincewind", "DEATH"], "Rincewind (Wizard), DEATH (Fighter)", "Ankh-Morpork", 1, "victory", 140, 7, 4, 9, 10, 660),
            make(14, ["Ripley", "Atreides", "Snake Plissken"], "Ripley (Ranger), Atreides (Wizard), Snake Plissken (Rogue)", "Trantor", 2, "victory", 220, 11, 5, 10, 12, 900),
            make(18, ["Top Cat", "Danger Mouse", "Penelope Pitstop"], "Top Cat (Rogue), Danger Mouse (Ranger), Penelope Pitstop (Fighter)", "The Labyrinth", 2, "victory", 190, 9, 4, 10, 12, 840),
            make(22, ["Daneel", "K-9", "Marvin"], "Daneel (Rogue), K-9 (Wizard), Marvin (Wizard)", "Nostromo", 2, "defeat", 95, 6, 3, 6, 12, 540),
            make(28, ["Eddie Munson", "Will the Wise", "Eleven"], "Eddie Munson (Rogue), Will the Wise (Cleric), Eleven (Wizard)", "Krell Laboratory", 1, "defeat", 65, 4, 2, 5, 10, 480),
            make(32, ["Doct Carter", "Dejah Thoris", "Tars Tarkas"], "Doct Carter (Fighter), Dejah Thoris (Barbarian), Tars Tarkas (Fighter)", "The Scarlet Citadel", 3, "victory", 350, 15, 6, 13, 14, 1300),
            make(36, ["Athos", "Porthos", "Aramis", "D'Artagnan"], "Athos (Fighter), Porthos (Fighter), Aramis (Cleric), D'Artagnan (Rogue)", "The Iron Tower", 2, "victory", 260, 12, 5, 11, 12, 950),
        ]

        for e in seed_entries:
            self.add_entry(e)
