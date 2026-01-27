"""
Scoreboard and party statistics for D&D 5e Text-Based RPG.

Tracks:
- Party stats and health
- Combat statistics (kills, damage dealt/taken)
- Exploration progress
- Session time and achievements
"""

from typing import Dict, List, Optional, Any
from dataclasses import dataclass, field, asdict
from datetime import datetime, timedelta
from enum import Enum


class Achievement(Enum):
    """Achievements players can earn."""
    FIRST_BLOOD = "first_blood"              # First enemy killed
    DRAGON_SLAYER = "dragon_slayer"          # Kill a dragon
    DUNGEON_DELVER = "dungeon_delver"        # Explore 10 rooms
    TREASURE_HUNTER = "treasure_hunter"      # Collect 1000 gold
    SURVIVOR = "survivor"                     # Survive a deadly encounter
    HEALER = "healer"                         # Heal 100 HP total
    CRITICAL_MASTER = "critical_master"      # Land 10 critical hits
    BOSS_SLAYER = "boss_slayer"              # Defeat the dungeon boss
    SPEEDRUNNER = "speedrunner"              # Complete dungeon in under 30 min
    PACIFIST = "pacifist"                     # Complete a room without combat
    UNTOUCHABLE = "untouchable"              # Win combat without taking damage


@dataclass
class CharacterStats:
    """Statistics for a single character."""
    name: str
    character_class: str
    level: int
    current_hp: int
    max_hp: int

    # Combat stats
    kills: int = 0
    damage_dealt: int = 0
    damage_taken: int = 0
    critical_hits: int = 0
    spells_cast: int = 0
    healing_done: int = 0

    # Death/revival
    times_downed: int = 0
    death_saves_succeeded: int = 0
    death_saves_failed: int = 0

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> 'CharacterStats':
        return cls(**data)


@dataclass
class SessionStats:
    """Statistics for the current game session."""
    session_name: str
    started_at: str = ""
    total_playtime_seconds: int = 0

    # Exploration
    rooms_explored: int = 0
    secrets_found: int = 0
    traps_triggered: int = 0
    traps_disarmed: int = 0

    # Combat
    encounters_won: int = 0
    encounters_fled: int = 0
    total_enemies_killed: int = 0

    # Loot
    gold_collected: int = 0
    items_found: int = 0
    potions_used: int = 0

    # Achievements
    achievements: List[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> 'SessionStats':
        return cls(**data)


class Scoreboard:
    """Manages party statistics and scoreboard display."""

    def __init__(self):
        self.character_stats: Dict[str, CharacterStats] = {}
        self.session_stats: Optional[SessionStats] = None
        self._session_start: Optional[datetime] = None
        self._last_activity: Optional[datetime] = None

    def start_session(self, session_name: str) -> None:
        """Start a new game session."""
        self._session_start = datetime.now()
        self._last_activity = self._session_start
        self.session_stats = SessionStats(
            session_name=session_name,
            started_at=self._session_start.isoformat()
        )

    def end_session(self) -> None:
        """End the current session."""
        if self.session_stats:
            self.session_stats.ended_at = datetime.now().isoformat()
        self._session_start = None

    def add_character(self, name: str, char_class: str, level: int,
                      current_hp: int, max_hp: int) -> None:
        """Add a character to tracking."""
        self.character_stats[name] = CharacterStats(
            name=name,
            character_class=char_class,
            level=level,
            current_hp=current_hp,
            max_hp=max_hp
        )

    def update_character_hp(self, name: str, current_hp: int, max_hp: int) -> None:
        """Update character HP."""
        if name in self.character_stats:
            self.character_stats[name].current_hp = current_hp
            self.character_stats[name].max_hp = max_hp

    def record_damage_dealt(self, name: str, amount: int, is_critical: bool = False) -> None:
        """Record damage dealt by a character."""
        if name in self.character_stats:
            self.character_stats[name].damage_dealt += amount
            if is_critical:
                self.character_stats[name].critical_hits += 1
                self._check_achievement(Achievement.CRITICAL_MASTER)

    def record_damage_taken(self, name: str, amount: int) -> None:
        """Record damage taken by a character."""
        if name in self.character_stats:
            self.character_stats[name].damage_taken += amount

    def record_kill(self, name: str, enemy_name: str) -> None:
        """Record an enemy kill."""
        if name in self.character_stats:
            self.character_stats[name].kills += 1
            if self.session_stats:
                self.session_stats.total_enemies_killed += 1

            # Check first blood
            total_kills = sum(c.kills for c in self.character_stats.values())
            if total_kills == 1:
                self._grant_achievement(Achievement.FIRST_BLOOD)

            # Check dragon slayer
            if 'dragon' in enemy_name.lower():
                self._grant_achievement(Achievement.DRAGON_SLAYER)

    def record_healing(self, healer_name: str, amount: int) -> None:
        """Record healing done."""
        if healer_name in self.character_stats:
            self.character_stats[healer_name].healing_done += amount
            if self.character_stats[healer_name].healing_done >= 100:
                self._grant_achievement(Achievement.HEALER)

    def record_spell_cast(self, name: str) -> None:
        """Record a spell being cast."""
        if name in self.character_stats:
            self.character_stats[name].spells_cast += 1

    def record_downed(self, name: str) -> None:
        """Record a character being downed."""
        if name in self.character_stats:
            self.character_stats[name].times_downed += 1

    def record_room_explored(self) -> None:
        """Record exploring a room."""
        if self.session_stats:
            self.session_stats.rooms_explored += 1
            if self.session_stats.rooms_explored >= 10:
                self._grant_achievement(Achievement.DUNGEON_DELVER)

    def record_gold(self, amount: int) -> None:
        """Record gold collected."""
        if self.session_stats:
            self.session_stats.gold_collected += amount
            if self.session_stats.gold_collected >= 1000:
                self._grant_achievement(Achievement.TREASURE_HUNTER)

    def record_encounter_won(self, took_damage: bool = True) -> None:
        """Record winning a combat encounter."""
        if self.session_stats:
            self.session_stats.encounters_won += 1
            if not took_damage:
                self._grant_achievement(Achievement.UNTOUCHABLE)

    def record_boss_killed(self) -> None:
        """Record killing the dungeon boss."""
        self._grant_achievement(Achievement.BOSS_SLAYER)

    def record_activity(self) -> None:
        """Record player activity (for timeout tracking)."""
        self._last_activity = datetime.now()

    def get_idle_time(self) -> float:
        """Get seconds since last activity."""
        if self._last_activity:
            return (datetime.now() - self._last_activity).total_seconds()
        return 0

    def _grant_achievement(self, achievement: Achievement) -> None:
        """Grant an achievement if not already earned."""
        if self.session_stats and achievement.value not in self.session_stats.achievements:
            self.session_stats.achievements.append(achievement.value)

    def _check_achievement(self, achievement: Achievement) -> None:
        """Check if an achievement should be granted."""
        if achievement == Achievement.CRITICAL_MASTER:
            total_crits = sum(c.critical_hits for c in self.character_stats.values())
            if total_crits >= 10:
                self._grant_achievement(achievement)

    def get_playtime(self) -> str:
        """Get formatted playtime."""
        if not self._session_start:
            return "0:00:00"

        elapsed = datetime.now() - self._session_start
        hours, remainder = divmod(int(elapsed.total_seconds()), 3600)
        minutes, seconds = divmod(remainder, 60)
        return f"{hours}:{minutes:02d}:{seconds:02d}"

    def display_scoreboard(self) -> str:
        """Generate the scoreboard display."""
        lines = []

        lines.append("╔════════════════════════════════════════════════════╗")
        lines.append("║                  ⚔️  SCOREBOARD  ⚔️                  ║")
        lines.append("╠════════════════════════════════════════════════════╣")

        if self.session_stats:
            lines.append(f"║  Session: {self.session_stats.session_name[:36]:36}  ║")
            lines.append(f"║  Playtime: {self.get_playtime():14}                   ║")
            lines.append("╠════════════════════════════════════════════════════╣")

        # Party stats
        lines.append("║  PARTY STATUS                                      ║")
        lines.append("╠────────────────────────────────────────────────────╣")

        for char in self.character_stats.values():
            hp_pct = char.current_hp / char.max_hp if char.max_hp > 0 else 0
            bar_width = 15
            filled = int(hp_pct * bar_width)
            hp_bar = "█" * filled + "░" * (bar_width - filled)

            lines.append(f"║  {char.name[:14]:14} Lv{char.level} {char.character_class[:8]:8}      ║")
            lines.append(f"║    HP: [{hp_bar}] {char.current_hp:3}/{char.max_hp:3}       ║")
            lines.append(f"║    Kills: {char.kills:3}  Dmg: {char.damage_dealt:5}  Heals: {char.healing_done:4}  ║")
            lines.append("║                                                    ║")

        # Session stats
        if self.session_stats:
            lines.append("╠════════════════════════════════════════════════════╣")
            lines.append("║  SESSION STATS                                     ║")
            lines.append("╠────────────────────────────────────────────────────╣")
            lines.append(f"║  Rooms Explored: {self.session_stats.rooms_explored:3}    Encounters Won: {self.session_stats.encounters_won:3}    ║")
            lines.append(f"║  Gold Collected: {self.session_stats.gold_collected:5}  Items Found: {self.session_stats.items_found:3}      ║")
            lines.append(f"║  Enemies Slain:  {self.session_stats.total_enemies_killed:3}    Secrets Found: {self.session_stats.secrets_found:3}   ║")

            # Achievements
            if self.session_stats.achievements:
                lines.append("╠════════════════════════════════════════════════════╣")
                lines.append("║  🏆 ACHIEVEMENTS                                    ║")
                lines.append("╠────────────────────────────────────────────────────╣")
                for ach in self.session_stats.achievements[:5]:
                    ach_display = ach.replace('_', ' ').title()
                    lines.append(f"║    ★ {ach_display:44}  ║")

        lines.append("╚════════════════════════════════════════════════════╝")

        return "\n".join(lines)

    def display_party_status(self) -> str:
        """Display compact party status bar."""
        if not self.character_stats:
            return "No party members"

        parts = []
        for char in self.character_stats.values():
            hp_pct = char.current_hp / char.max_hp if char.max_hp > 0 else 0
            if hp_pct > 0.5:
                status = "●"  # Green/healthy
            elif hp_pct > 0.25:
                status = "◐"  # Yellow/wounded
            elif hp_pct > 0:
                status = "○"  # Red/critical
            else:
                status = "✗"  # Dead

            parts.append(f"{char.name[:8]}: {status} {char.current_hp}/{char.max_hp}")

        return " | ".join(parts)

    def to_dict(self) -> dict:
        """Serialize scoreboard to dict."""
        return {
            "character_stats": {k: v.to_dict() for k, v in self.character_stats.items()},
            "session_stats": self.session_stats.to_dict() if self.session_stats else None,
            "session_start": self._session_start.isoformat() if self._session_start else None
        }

    @classmethod
    def from_dict(cls, data: dict) -> 'Scoreboard':
        """Deserialize scoreboard from dict."""
        sb = cls()
        sb.character_stats = {
            k: CharacterStats.from_dict(v)
            for k, v in data.get("character_stats", {}).items()
        }
        if data.get("session_stats"):
            sb.session_stats = SessionStats.from_dict(data["session_stats"])
        if data.get("session_start"):
            sb._session_start = datetime.fromisoformat(data["session_start"])
        return sb


class TimeoutManager:
    """
    Manages input timeouts and DM auto-actions.

    When a player doesn't respond within the timeout, the DM can
    take actions on their behalf.
    """

    DEFAULT_TIMEOUT = 120  # 2 minutes
    WARNING_TIME = 30      # Warn 30 seconds before timeout

    def __init__(self, timeout: float = DEFAULT_TIMEOUT):
        self.timeout = timeout
        self.enabled = True
        self._last_prompt: Optional[datetime] = None
        self._warned = False

    def start_prompt(self) -> None:
        """Start timing for a prompt."""
        self._last_prompt = datetime.now()
        self._warned = False

    def check_timeout(self) -> tuple[bool, bool]:
        """
        Check timeout status.

        Returns:
            (should_warn, has_timed_out)
        """
        if not self.enabled or not self._last_prompt:
            return False, False

        elapsed = (datetime.now() - self._last_prompt).total_seconds()

        should_warn = (elapsed >= self.timeout - self.WARNING_TIME and
                       not self._warned)
        if should_warn:
            self._warned = True

        has_timed_out = elapsed >= self.timeout

        return should_warn, has_timed_out

    def get_remaining_time(self) -> float:
        """Get seconds remaining before timeout."""
        if not self._last_prompt:
            return self.timeout

        elapsed = (datetime.now() - self._last_prompt).total_seconds()
        return max(0, self.timeout - elapsed)

    def get_warning_message(self) -> str:
        """Get timeout warning message."""
        remaining = int(self.get_remaining_time())
        return f"⏰ {remaining} seconds until DM takes over..."

    def get_timeout_message(self) -> str:
        """Get timeout occurred message."""
        return "⏰ Time's up! The DM takes action on your behalf..."

    def set_enabled(self, enabled: bool) -> None:
        """Enable or disable timeout."""
        self.enabled = enabled

    def set_timeout(self, seconds: float) -> None:
        """Set the timeout duration."""
        self.timeout = max(30, seconds)  # Minimum 30 seconds


class SessionManager:
    """
    Manages game session state, including:
    - Save/pause functionality
    - Timeout handling
    - Scoreboard tracking
    """

    def __init__(self):
        self.scoreboard = Scoreboard()
        self.timeout_manager = TimeoutManager()
        self.paused = False
        self._auto_save_interval = 300  # 5 minutes
        self._last_auto_save: Optional[datetime] = None

    def start_session(self, name: str) -> None:
        """Start a new session."""
        self.scoreboard.start_session(name)
        self._last_auto_save = datetime.now()

    def should_auto_save(self) -> bool:
        """Check if auto-save should trigger."""
        if not self._last_auto_save:
            return True

        elapsed = (datetime.now() - self._last_auto_save).total_seconds()
        return elapsed >= self._auto_save_interval

    def mark_saved(self) -> None:
        """Mark that a save just occurred."""
        self._last_auto_save = datetime.now()

    def pause(self) -> str:
        """Pause the game."""
        self.paused = True
        return """
╔════════════════════════════════════════╗
║             ⏸️  GAME PAUSED             ║
╠════════════════════════════════════════╣
║                                        ║
║  The game is paused.                   ║
║                                        ║
║  Options:                              ║
║    [R] Resume game                     ║
║    [S] Save and quit                   ║
║    [Q] Quit without saving             ║
║    [B] View scoreboard                 ║
║                                        ║
╚════════════════════════════════════════╝
"""

    def resume(self) -> None:
        """Resume the game."""
        self.paused = False
        self.scoreboard.record_activity()

    def end_session(self) -> None:
        """End the current session."""
        self.scoreboard.end_session()
        self.paused = False

    def get_pause_menu_choice(self) -> str:
        """Get choice from pause menu."""
        while True:
            choice = input("Choice: ").strip().lower()
            if choice in ['r', 's', 'q', 'b', 'resume', 'save', 'quit', 'board']:
                return choice[0]
            print("Invalid choice. Enter R, S, Q, or B.")
