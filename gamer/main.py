#!/usr/bin/env python3
"""
D&D 5e Text-Based RPG
Main entry point for the game.
"""
from __future__ import annotations

import sys
import argparse
import json
import random
import textwrap
import time
import os
import signal
from datetime import datetime
from pathlib import Path
from typing import List, Optional

# Runtime imports are bootstrapped in main() to avoid slow/hanging eager imports.
# Names are populated by _bootstrap_runtime_imports().
GameEngine = None
GameState = None
list_sessions = None
load_session = None
session_exists = None
validate_session_payload = None
quarantine_invalid_saves = None
Character = None
get_all_races = None
get_race = None
get_all_classes = None
get_class = None
Ability = None
get_all_monsters = None
NPC = None
generate_npc = None
generate_quest_giver = None
HumanPlayer = None
AIPlayer = None
AIPersonality = None
Direction = None
NPCRole = None
NPC_TEMPLATES = None
print_title = None
print_subtitle = None
print_menu = None
get_input = None
get_menu_choice = None
confirm = None
print_separator = None
paged_print = None
print_stat_block = None
Colors = None
clear_screen = None
set_terminal_theme = None
reset_terminal = None
show_splash_screen = None
setup_status_panel = None
status_message = None
teardown_status_panel = None
UserInterruptRequest = None
UserSuspendRequest = None
roll_ability_scores = None
standard_array = None
render_character = None
render_party = None
render_dungeon_map = None
render_combat_scene = None
render_monster = None
render_encounter = None
SharedFileMultiplayer = None
SocketMultiplayer = None
get_local_ip = None
PlayerRole = None
Scoreboard = None
SessionManager = None
TimeoutManager = None
HallOfFameManager = None

# Global multiplayer instance
_multiplayer = None

# Global session manager (initialized during runtime bootstrap)
_session = None
_room_npcs = {}
_runtime_state = {
    "explore_steps": 0,
    "tip_history": set(),
    "victory_art_index": 0,
    "blocked_door_attempts": set(),
}

# Global config for defaults
_config = {
    'use_defaults': True,   # Allow pressing Enter to use defaults
    'use_theme': True,      # Use green-on-black terminal theme
    'show_splash': True,    # Show splash screen
    'timeout': 120,         # Seconds before DM takes over (0 to disable)
    'auto_save': True,      # Auto-save periodically
    'ai_backend': 'local',  # AI DM backend: 'local', 'anthropic', 'openai'
    'splash_style': 'dragon',
    'use_arrow_keys': True,
    'map_radius': 3,
    'card_navigation': True,
    'npcs_enabled': True,
    'multiplayer_enabled': True,
    'adventure_log_enabled': True,
    'auto_show_map': True,
    'idle_prompts': True,
    'verbose': False,       # Verbose runtime logging to stderr
}

def vlog(message: str) -> None:
    """Emit verbose runtime logs when --verbose is enabled."""
    if not _config.get('verbose'):
        return
    ts = datetime.now().strftime("%H:%M:%S")
    print(f"[gamer {ts}] {message}", file=sys.stderr, flush=True)


def _bootstrap_runtime_imports() -> None:
    """Load heavyweight imports lazily at runtime."""
    global GameEngine, GameState
    global list_sessions, load_session, session_exists, validate_session_payload, quarantine_invalid_saves
    global Character, get_all_races, get_race, get_all_classes, get_class, Ability, get_all_monsters
    global NPC, generate_npc, generate_quest_giver
    global HumanPlayer, AIPlayer, AIPersonality, Direction
    global NPCRole, NPC_TEMPLATES
    global print_title, print_subtitle, print_menu, get_input, get_menu_choice
    global confirm, print_separator, paged_print, print_stat_block, Colors, clear_screen
    global set_terminal_theme, reset_terminal, show_splash_screen
    global setup_status_panel, status_message, teardown_status_panel
    global UserInterruptRequest, UserSuspendRequest
    global roll_ability_scores, standard_array
    global render_character, render_party, render_dungeon_map, render_combat_scene
    global render_monster, render_encounter
    global SharedFileMultiplayer, SocketMultiplayer, get_local_ip, PlayerRole
    global Scoreboard, SessionManager, TimeoutManager, HallOfFameManager, _session

    from .game.engine import GameEngine as _GameEngine, GameState as _GameState
    from .game.session import (
        list_sessions as _list_sessions,
        load_session as _load_session,
        session_exists as _session_exists,
        validate_session_payload as _validate_session_payload,
        quarantine_invalid_saves as _quarantine_invalid_saves,
    )
    from .characters.character import Character as _Character
    from .characters.races import get_all_races as _get_all_races, get_race as _get_race
    from .characters.classes import get_all_classes as _get_all_classes, get_class as _get_class
    from .characters.abilities import Ability as _Ability
    from .world.monsters import get_all_monsters as _get_all_monsters
    from .world.dungeon import Direction as _Direction
    from .world.npcs import (
        NPC as _NPC,
        generate_npc as _generate_npc,
        generate_quest_giver as _generate_quest_giver,
        NPCRole as _NPCRole,
        NPC_TEMPLATES as _NPC_TEMPLATES,
    )
    from .players.human_player import HumanPlayer as _HumanPlayer
    from .players.ai_player import AIPlayer as _AIPlayer, AIPersonality as _AIPersonality
    from .utils.display import (
        print_title as _print_title, print_subtitle as _print_subtitle, print_menu as _print_menu,
        get_input as _get_input, get_menu_choice as _get_menu_choice, confirm as _confirm,
        print_separator as _print_separator, Colors as _Colors, clear_screen as _clear_screen,
        paged_print as _paged_print, print_stat_block as _print_stat_block,
        set_terminal_theme as _set_terminal_theme, reset_terminal as _reset_terminal,
        show_splash_screen as _show_splash_screen, setup_status_panel as _setup_status_panel,
        status_message as _status_message, teardown_status_panel as _teardown_status_panel,
        UserInterruptRequest as _UserInterruptRequest, UserSuspendRequest as _UserSuspendRequest,
    )
    from .utils.dice import roll_ability_scores as _roll_ability_scores, standard_array as _standard_array
    from .utils.ascii_art import (
        render_character as _render_character, render_party as _render_party,
        render_dungeon_map as _render_dungeon_map, render_combat_scene as _render_combat_scene,
        render_monster as _render_monster, render_encounter as _render_encounter,
    )
    from .game.multiplayer import (
        SharedFileMultiplayer as _SharedFileMultiplayer, SocketMultiplayer as _SocketMultiplayer,
        get_local_ip as _get_local_ip, PlayerRole as _PlayerRole,
    )
    from .game.scoreboard import Scoreboard as _Scoreboard, SessionManager as _SessionManager, TimeoutManager as _TimeoutManager
    from .game.hall_of_fame import HallOfFameManager as _HallOfFameManager

    GameEngine, GameState = _GameEngine, _GameState
    list_sessions, load_session, session_exists, validate_session_payload, quarantine_invalid_saves = (
        _list_sessions, _load_session, _session_exists, _validate_session_payload, _quarantine_invalid_saves
    )
    Character, get_all_races, get_race = _Character, _get_all_races, _get_race
    get_all_classes, get_class, Ability = _get_all_classes, _get_class, _Ability
    get_all_monsters = _get_all_monsters
    NPC, generate_npc, generate_quest_giver = _NPC, _generate_npc, _generate_quest_giver
    HumanPlayer, AIPlayer, AIPersonality = _HumanPlayer, _AIPlayer, _AIPersonality
    Direction = _Direction
    NPCRole, NPC_TEMPLATES = _NPCRole, _NPC_TEMPLATES
    print_title, print_subtitle, print_menu = _print_title, _print_subtitle, _print_menu
    get_input, get_menu_choice, confirm = _get_input, _get_menu_choice, _confirm
    print_separator, paged_print, print_stat_block = _print_separator, _paged_print, _print_stat_block
    Colors, clear_screen = _Colors, _clear_screen
    set_terminal_theme, reset_terminal, show_splash_screen = _set_terminal_theme, _reset_terminal, _show_splash_screen
    setup_status_panel, status_message, teardown_status_panel = _setup_status_panel, _status_message, _teardown_status_panel
    UserInterruptRequest, UserSuspendRequest = _UserInterruptRequest, _UserSuspendRequest
    roll_ability_scores, standard_array = _roll_ability_scores, _standard_array
    render_character, render_party = _render_character, _render_party
    render_dungeon_map, render_combat_scene = _render_dungeon_map, _render_combat_scene
    render_monster, render_encounter = _render_monster, _render_encounter
    SharedFileMultiplayer, SocketMultiplayer = _SharedFileMultiplayer, _SocketMultiplayer
    get_local_ip, PlayerRole = _get_local_ip, _PlayerRole
    Scoreboard, SessionManager, TimeoutManager = _Scoreboard, _SessionManager, _TimeoutManager
    HallOfFameManager = _HallOfFameManager
    _session = SessionManager()


def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description='D&D 5e Text-Based RPG',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  python run_game.py                  # Normal start with defaults enabled
  python run_game.py --no-defaults    # Disable pressing Enter for defaults
  python run_game.py --no-theme       # Use default terminal colors
  python run_game.py --no-splash      # Skip splash screen
  python run_game.py --quick          # Quick start (no splash, no theme)
'''
    )
    parser.add_argument(
        '--no-defaults', '-D',
        action='store_true',
        help='Disable default selections (must explicitly choose options)'
    )
    parser.add_argument(
        '--no-theme', '-T',
        action='store_true',
        help='Disable green-on-black terminal theme'
    )
    parser.add_argument(
        '--no-splash', '-S',
        action='store_true',
        help='Skip the splash screen'
    )
    parser.add_argument(
        '--quick', '-q',
        action='store_true',
        help='Quick start: skip splash and theme'
    )
    parser.add_argument(
        '--splash-style',
        choices=['dragon', 'simple', 'classic'],
        default='dragon',
        help='Splash screen style (default: dragon)'
    )
    parser.add_argument(
        '--timeout', '-t',
        type=int,
        default=120,
        help='Seconds before DM takes over if no input (0 to disable, default: 120)'
    )
    parser.add_argument(
        '--no-timeout',
        action='store_true',
        help='Disable input timeout (DM never takes over)'
    )
    parser.add_argument(
        '--no-autosave',
        action='store_true',
        help='Disable automatic saving'
    )
    parser.add_argument(
        '--ai',
        choices=['local', 'anthropic', 'openai'],
        default='local',
        help='AI backend for DM narration (default: local). Set ANTHROPIC_API_KEY or OPENAI_API_KEY env var.'
    )
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Enable verbose runtime logging to stderr'
    )
    parser.add_argument(
        '--map-radius',
        type=int,
        default=3,
        help='Map visibility radius in rooms (1-6, default: 3)'
    )
    parser.add_argument(
        '--no-arrow-keys',
        action='store_true',
        help='Disable interactive arrow-key menus'
    )
    parser.add_argument(
        '--no-card-nav',
        action='store_true',
        help='Disable card-style help/bestiary navigation preference'
    )
    parser.add_argument(
        '--no-npcs',
        action='store_true',
        help='Disable NPC systems where optional'
    )
    parser.add_argument(
        '--no-multiplayer',
        action='store_true',
        help='Disable multiplayer menu/options'
    )

    return parser.parse_args()


def _suspend_process() -> None:
    """Suspend process with default shell job-control behavior."""
    previous = signal.getsignal(signal.SIGTSTP)
    try:
        signal.signal(signal.SIGTSTP, signal.SIG_DFL)
        os.kill(os.getpid(), signal.SIGTSTP)
    finally:
        signal.signal(signal.SIGTSTP, previous)


def _handle_interrupt_request() -> bool:
    """Prompt user on Ctrl-C. Returns True if game should quit."""
    print()
    return confirm("Ctrl-C pressed. Quit game now?", default=False)


def _handle_suspend_request() -> None:
    """Prompt user on Ctrl-Z and suspend only if confirmed."""
    print()
    print(f"{Colors.WARNING}Ctrl-Z suspends the game. It will NOT run in background while suspended.{Colors.RESET}")
    if confirm("Suspend to background?", default=False):
        _suspend_process()


def main():
    """Main game loop."""
    global _config, _session

    # Parse command line arguments
    args = parse_args()

    _bootstrap_runtime_imports()
    vlog("Runtime imports bootstrapped")

    try:
        quarantine_summary = quarantine_invalid_saves(include_legacy_home=True)
    except Exception as exc:
        quarantine_summary = {"moved": 0, "errors": [str(exc)]}
    if quarantine_summary.get("moved", 0) > 0:
        print(f"{Colors.WARNING}Quarantined {quarantine_summary['moved']} invalid save(s).{Colors.RESET}")
        vlog(f"Invalid saves quarantined: {quarantine_summary.get('moved_files', [])}")
    if quarantine_summary.get("errors"):
        vlog(f"Save quarantine warnings: {quarantine_summary.get('errors')}")

    def _on_sigint(_signum, _frame):
        raise UserInterruptRequest

    def _on_sigtstp(_signum, _frame):
        raise UserSuspendRequest

    previous_sigint = signal.getsignal(signal.SIGINT)
    previous_sigtstp = signal.getsignal(signal.SIGTSTP)
    signal.signal(signal.SIGINT, _on_sigint)
    signal.signal(signal.SIGTSTP, _on_sigtstp)

    # Apply config from args
    _config['use_defaults'] = not args.no_defaults
    _config['use_theme'] = not args.no_theme and not args.quick
    _config['show_splash'] = not args.no_splash and not args.quick
    _config['timeout'] = 0 if args.no_timeout else args.timeout
    _config['auto_save'] = not args.no_autosave
    _config['ai_backend'] = args.ai
    _config['splash_style'] = args.splash_style
    _config['use_arrow_keys'] = not args.no_arrow_keys
    _config['map_radius'] = max(1, min(6, int(args.map_radius)))
    _config['card_navigation'] = not args.no_card_nav
    _config['npcs_enabled'] = not args.no_npcs
    _config['multiplayer_enabled'] = not args.no_multiplayer
    _config['idle_prompts'] = _config['timeout'] > 0
    _config['verbose'] = args.verbose
    vlog(f"Config loaded: ai={_config['ai_backend']}, timeout={_config['timeout']}, "
         f"theme={_config['use_theme']}, splash={_config['show_splash']}, defaults={_config['use_defaults']}")

    # Initialize AI DM
    from .game.ai_dm import get_ai_dm
    ai_dm = get_ai_dm(_config['ai_backend'])
    vlog(f"AI DM initialized (backend={_config['ai_backend']})")

    # Configure session manager
    if _config['timeout'] > 0:
        _session.timeout_manager.set_timeout(_config['timeout'])
        _session.timeout_manager.set_enabled(True)
    else:
        _session.timeout_manager.set_enabled(False)

    # Set up terminal theme (green on black)
    if _config['use_theme']:
        set_terminal_theme()

    try:
        # Show splash screen
        if _config['show_splash']:
            show_splash_screen(args.splash_style)

        # Print title
        print_title("D&D 5e Text Adventure")
        print("A text-based role-playing game")
        if _config['use_defaults']:
            print(f"{Colors.MUTED}(Press Enter to use default options){Colors.RESET}")
        if _config['timeout'] > 0:
            print(f"{Colors.MUTED}(DM timeout: {_config['timeout']}s){Colors.RESET}")
        print()

        engine = GameEngine()
        vlog("GameEngine created")
        last_state = None

        while True:
            try:
                if engine.state != last_state:
                    vlog(f"State transition: {last_state} -> {engine.state}")
                    last_state = engine.state
                if engine.state == GameState.MAIN_MENU:
                    vlog("Entering main menu handler")
                    handle_main_menu(engine)

                elif engine.state == GameState.PARTY_SETUP:
                    vlog("Entering party setup handler")
                    handle_party_setup(engine)

                elif engine.state == GameState.EXPLORING:
                    if not _ensure_exploration_ready(engine):
                        vlog("Exploration blocked: missing party and/or dungeon")
                        continue
                    vlog("Entering exploration handler")
                    handle_exploration(engine)

                elif engine.state == GameState.IN_COMBAT:
                    vlog("Entering combat handler")
                    handle_combat(engine)

                elif engine.state == GameState.GAME_OVER:
                    print_title("GAME OVER")
                    print("Your adventure has come to an end.")
                    if confirm("Return to main menu?"):
                        engine.state = GameState.MAIN_MENU
                    else:
                        break

                elif engine.state == GameState.VICTORY:
                    _print_victory_art()
                    print_title("VICTORY!")
                    print("You have conquered the dungeon!")
                    print(engine.get_game_summary())
                    if confirm("Return to main menu?"):
                        engine.state = GameState.MAIN_MENU
                    else:
                        break
            except UserInterruptRequest:
                if _handle_interrupt_request():
                    break
            except UserSuspendRequest:
                _handle_suspend_request()

    finally:
        signal.signal(signal.SIGINT, previous_sigint)
        signal.signal(signal.SIGTSTP, previous_sigtstp)
        # Cleanup status panel
        teardown_status_panel()
        # Reset terminal colors on exit
        if _config['use_theme']:
            reset_terminal()


def _repo_root() -> Path:
    """Repository root path."""
    return Path(__file__).resolve().parent.parent


def _load_card_catalog() -> dict:
    """Load card data used for iOS name suggestions and lore parity."""
    if hasattr(_load_card_catalog, "_cache"):
        return getattr(_load_card_catalog, "_cache")

    cards_path = _repo_root() / "ios_card_images" / "cards.json"
    data = {}
    try:
        with cards_path.open("r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as exc:
        vlog(f"Unable to load card catalog from {cards_path}: {exc}")
        data = {}

    setattr(_load_card_catalog, "_cache", data)
    return data


def _load_ios_faq_index() -> dict:
    """Parse iOS FAQData.swift into category/entry structures for Python use."""
    if hasattr(_load_ios_faq_index, "_cache"):
        return getattr(_load_ios_faq_index, "_cache")

    faq_path = _repo_root() / "ios" / "DnDTextRPG" / "DnDTextRPG" / "Utils" / "FAQData.swift"
    data = {"categories": [], "entries": []}
    if not faq_path.exists():
        setattr(_load_ios_faq_index, "_cache", data)
        return data

    try:
        lines = faq_path.read_text(encoding="utf-8").splitlines()
    except Exception:
        setattr(_load_ios_faq_index, "_cache", data)
        return data

    categories = []
    entries = []
    current_category = None
    current_contexts = []
    pending_question = None

    for raw_line in lines:
        line = raw_line.strip()
        if "FAQCategory(title:" in line and "contexts:" in line:
            # Example: static let combat = FAQCategory(title: "Combat", contexts: ["combat"], entries: [
            title = ""
            if 'title: "' in line:
                title = line.split('title: "', 1)[1].split('"', 1)[0]
            contexts = []
            if "contexts: [" in line:
                context_part = line.split("contexts: [", 1)[1].split("]", 1)[0]
                contexts = [c.strip().strip('"') for c in context_part.split(",") if c.strip()]
            current_category = title or "General"
            current_contexts = contexts
            categories.append({
                "title": current_category,
                "contexts": current_contexts,
                "entries": [],
            })
            continue

        if line.startswith("question: "):
            # question: "..."
            q = line.split('question: "', 1)[1].rsplit('"', 1)[0]
            pending_question = _sanitize_text(q)
            continue

        if line.startswith("answer: ") and pending_question:
            a = line.split('answer: "', 1)[1].rsplit('"', 1)[0]
            answer = _sanitize_text(a)
            entry = {
                "category": current_category or "General",
                "contexts": list(current_contexts),
                "question": pending_question,
                "answer": answer,
            }
            entries.append(entry)
            if categories:
                categories[-1]["entries"].append(entry)
            pending_question = None

    data = {"categories": categories, "entries": entries}
    setattr(_load_ios_faq_index, "_cache", data)
    return data


def _find_relevant_faq(query: str, limit: int = 5) -> List[dict]:
    """Find FAQ entries relevant to a player query."""
    q = query.lower().strip()
    if not q:
        return []
    words = {w for w in "".join(ch if ch.isalnum() else " " for ch in q).split() if len(w) > 2}
    scored = []
    for e in _load_ios_faq_index().get("entries", []):
        question = e["question"].lower()
        answer = e["answer"].lower()
        score = 0
        for w in words:
            if w in question:
                score += 3
            elif w in answer:
                score += 1
        if q in question:
            score += 10
        if score > 0:
            scored.append((score, e))
    scored.sort(key=lambda x: x[0], reverse=True)
    return [e for _, e in scored[:limit]]


def _context_weighted_tip(context: str) -> Optional[str]:
    """Pick a context-aware tip using iOS FAQ entries with repeat avoidance."""
    index = _load_ios_faq_index()
    entries = index.get("entries", [])
    if not entries:
        return None

    candidates = []
    fallback = []
    for i, e in enumerate(entries):
        answer = e.get("answer", "")
        if not answer or len(answer) > 220:
            continue
        if i in _runtime_state["tip_history"]:
            continue
        fallback.append((i, answer))
        if context in e.get("contexts", []):
            candidates.append((i, answer))

    pool = candidates if candidates else fallback
    if not pool:
        _runtime_state["tip_history"] = set()
        return None

    picked_i, tip = random.choice(pool)
    _runtime_state["tip_history"].add(picked_i)
    if len(_runtime_state["tip_history"]) > 40:
        _runtime_state["tip_history"] = set(list(_runtime_state["tip_history"])[-20:])
    return tip


def _sanitize_text(text: str) -> str:
    """Normalize text for terminal output and remove common mojibake."""
    if not text:
        return ""
    if any(token in text for token in ("â", "Ã", "Â")):
        try:
            text = text.encode("latin1", errors="ignore").decode("utf-8", errors="ignore")
        except Exception:
            pass
    replacements = {
        "—": "-",
        "–": "-",
        "’": "'",
        "‘": "'",
        "“": '"',
        "”": '"',
        "…": "...",
        "\u00a0": " ",
    }
    for src, dst in replacements.items():
        text = text.replace(src, dst)
    return text


def _render_sleep_marker(progress: float, width: int = 30) -> str:
    """Render a rest-time marker like [Zzzz..........zzz......zzz...]."""
    progress = max(0.0, min(1.0, progress))
    filled = int(progress * width)
    pattern = "Zzzz...zzz...zzz..."
    chars = []
    for i in range(width):
        if i < filled:
            chars.append(pattern[i % len(pattern)])
        else:
            chars.append(".")
    return "[" + "".join(chars) + "]"


def _play_rest_pause(is_long_rest: bool) -> bool:
    """Show a short rest animation; hold z to accelerate, q to quit."""
    from .utils.display import _getch, _is_tty

    ticks = 56 if is_long_rest else 32
    base_wait = 0.11 if is_long_rest else 0.09
    label = "Long Rest" if is_long_rest else "Short Rest"

    if not _is_tty():
        marker = _render_sleep_marker(1.0)
        print(f"{Colors.MUTED}{label} {marker}{Colors.RESET}")
        time.sleep(0.5 if is_long_rest else 0.3)
        return True

    print(f"{Colors.MUTED}{label} - hold z to speed up, q to quit{Colors.RESET}")
    progress = 0
    while progress < ticks:
        marker = _render_sleep_marker(progress / ticks)
        print(f"\r{Colors.MUTED}{marker}{Colors.RESET}", end="", flush=True)
        ch = _getch(timeout=base_wait)
        if ch in ("q", "Q"):
            print()
            return False
        if ch in ("z", "Z"):
            progress += 4
        else:
            progress += 1

    print(f"\r{Colors.MUTED}{_render_sleep_marker(1.0)}{Colors.RESET}")
    return True


_VICTORY_ART_SCENES = [
    r"""
                 _^_
              .-"   "-.
             /  .-.-.  \
            /  /  _  \  \              /\_/\  /\_/\ 
       /\  /  /  (_)  \  \            /     \/     \
      /  \/  /   __    \  \____      /  /\      /\  \
     / /\   /   /  \    \      \____/  /  \____/  \  \
    /_/  \_/___/____\____\___________/\____________/\_\

                     /\                       //
                    /  \__      __          _//
                   / /\   \____/  \__   __-'
      /\          / /  \            \_-'
  ___/  \___     /_/    \__  __     /     __
 /  _    _  \             /_/  \___/   __/  \__
/  /_\  /_\  \                         /  /\   \
\_/   \/   \_/                        /__/  \___\
""",
    r"""
      /\                                   |>>>>
  /\ /  \ /\                               |    
 /  V /\ V  \                              |    
/    /  \    \      * * *  * * *           |    
\___/ /\ \___/   < < < < < < < < <==       |    
    \/_  _\/      * * *  * * *             |    
      /\/\                                     __[]__
     /_/  \_           _                     _|_o__o_|_
      / /\ \          / \                   |  []  []  |
     /_/  \_\     ___/___\___      _________|__________|____
                   |  _   _  |    |  [] [] [] [] [] [] []  |
                   | |_| |_| |____|_________________________|
                   |  ___ ___|_____|  _   _   _   _   _    |
                   | |   |   |     | |_| |_| |_| |_| |_|   |
                   |_|___|___|     |_______________________|
""",
]


def _print_victory_art() -> None:
    """Render a celebratory ASCII scene on victory."""
    idx = _runtime_state.get("victory_art_index", 0) % len(_VICTORY_ART_SCENES)
    _runtime_state["victory_art_index"] = idx + 1
    art = _VICTORY_ART_SCENES[idx].strip("\n")
    print(f"{Colors.SUCCESS}{art}{Colors.RESET}\n")


def _card_name_suggestions(category: str, count: int = 8) -> List[str]:
    """Get random name suggestions from card catalog."""
    data = _load_card_catalog()
    entries = data.get(category, [])
    names = []
    for e in entries:
        name = _sanitize_text(str(e.get("name", "")).strip())
        if name:
            names.append(name)
    if not names:
        return []
    sample_n = min(count, len(names))
    return random.sample(names, sample_n)


def _sorted_sessions(playable_only: bool = False) -> List[dict]:
    """Return sessions sorted by last played (most recent first)."""
    sessions = list_sessions() or []
    if playable_only:
        sessions = [s for s in sessions if s.get("playable", True)]
    sessions.sort(key=lambda s: s.get("last_played", ""), reverse=True)
    return sessions


def _sync_loaded_party_to_scoreboard(engine: GameEngine) -> None:
    """Refresh session scoreboard from loaded engine state."""
    session_name = "Loaded Adventure"
    if engine.session and getattr(engine.session, "name", None):
        session_name = str(engine.session.name)
    elif engine.dm and engine.dm.dungeon and getattr(engine.dm.dungeon, "name", None):
        session_name = str(engine.dm.dungeon.name)

    _session.start_session(session_name)
    _session.scoreboard.character_stats = {}
    for character in engine.party:
        _session.scoreboard.add_character(
            character.name,
            character.char_class.name,
            character.level,
            character.current_hp,
            character.max_hp,
        )


def _load_game_interactive(engine: GameEngine) -> None:
    """Load a game from save slots."""
    sessions = _sorted_sessions()
    if not sessions:
        print(f"{Colors.WARNING}No saved games found.{Colors.RESET}")
        return

    session_names = []
    for s in sessions:
        status = "" if s.get("playable", True) else " [INVALID]"
        session_names.append(f"{s['name']} (Last played: {s['last_played'][:10]}){status}")
    load_choice = get_menu_choice(session_names, "Select a save to load:", allow_back=True)
    if load_choice == 0:
        return
    if load_choice <= len(sessions):
        selected = sessions[load_choice - 1]
        if not selected.get("playable", True):
            issues = selected.get("issues") or ["Save is not playable"]
            print(f"{Colors.WARNING}Cannot load this save: {', '.join(issues)}.{Colors.RESET}")
            return
        session = load_session(sessions[load_choice - 1]["name"])
        if session:
            engine.load_game(session)
            if engine.party and engine.dm and engine.dm.dungeon and engine.dm.dungeon.current_room:
                _sync_loaded_party_to_scoreboard(engine)
                print(f"{Colors.SUCCESS}Game loaded!{Colors.RESET}")
            else:
                print(f"{Colors.WARNING}Save loaded, but adventure state is incomplete. Choose Load or Set Up when prompted.{Colors.RESET}")
        else:
            print(f"{Colors.DANGER}Failed to load game.{Colors.RESET}")


def _continue_last_quest(engine: GameEngine) -> None:
    """Load most recently played quest."""
    sessions = _sorted_sessions(playable_only=True)
    if not sessions:
        print(f"{Colors.WARNING}No playable saved quests found. Start a new adventure or repair invalid saves.{Colors.RESET}")
        return
    latest = sessions[0]
    session = load_session(latest["name"])
    if session:
        engine.load_game(session)
        if engine.party and engine.dm and engine.dm.dungeon and engine.dm.dungeon.current_room:
            _sync_loaded_party_to_scoreboard(engine)
            print(f"{Colors.SUCCESS}Continued quest: {latest['name']}{Colors.RESET}")
        else:
            print(f"{Colors.WARNING}Loaded '{latest['name']}', but the dungeon state is incomplete.{Colors.RESET}")
    else:
        print(f"{Colors.DANGER}Could not load latest quest.{Colors.RESET}")


def _ensure_exploration_ready(engine: GameEngine) -> bool:
    """
    Ensure exploration has required state.

    Returns True when exploration can proceed, otherwise redirects user flow
    to load/setup/menu and returns False.
    """
    has_party = bool(engine.party)
    has_dungeon = bool(engine.dm and engine.dm.dungeon and engine.dm.dungeon.current_room)
    if has_party and has_dungeon:
        return True

    print_title("Adventure Not Ready")
    print("Cannot enter exploration right now.")
    print(f"- Party: {'OK' if has_party else 'Missing'}")
    print(f"- Dungeon: {'OK' if has_dungeon else 'Missing'}")
    print()

    options = []
    actions = []
    if _sorted_sessions():
        options.append("Load Saved Adventure")
        actions.append("load")
    options.append("Set Up New Party")
    actions.append("setup")
    options.append("Return to Main Menu")
    actions.append("menu")

    choice = get_menu_choice(options, "Choose next step")
    action = actions[choice - 1]

    if action == "load":
        _load_game_interactive(engine)
        return bool(engine.party and engine.dm and engine.dm.dungeon and engine.dm.dungeon.current_room)

    if action == "setup":
        session_name = get_input("Enter a name for your adventure: ", default="Adventure")
        if session_exists(session_name):
            if not confirm(f"A save named '{session_name}' exists. Overwrite?"):
                engine.state = GameState.MAIN_MENU
                return False
        engine.new_game(session_name)
        return False

    engine.state = GameState.MAIN_MENU
    return False


def _show_hall_of_fame() -> None:
    """Interactive Hall of Fame browser."""
    print_title("Hall of Fame")
    print(_session.scoreboard.display_scoreboard())

    hof = HallOfFameManager()
    hof.seed_if_empty()
    entries = hof.list_entries()

    if not entries:
        print(f"{Colors.WARNING}No Hall of Fame entries yet.{Colors.RESET}")
        get_input("\nPress Enter to continue...", default="")
        return

    while True:
        options = [
            f"#{i+1} {e.dungeon_name}  L{e.dungeon_level}  {e.outcome.upper()}  Score {e.score}"
            for i, e in enumerate(entries[:10])
        ]
        choice = get_menu_choice(options, "Select a Hall of Fame entry", allow_back=True)
        if choice == 0:
            return

        e = entries[choice - 1]
        print_title(f"Run #{choice}: {e.dungeon_name}")
        print_stat_block("Hall of Fame Entry", {
            "Date": e.date[:10],
            "Outcome": e.outcome.upper(),
            "Score": e.score,
            "Dungeon Level": e.dungeon_level,
            "Party": ", ".join(e.party_names) if e.party_names else "Unknown",
            "Gold Collected": e.gold_collected,
            "Monsters Slain": e.monsters_slain,
            "Combats Won": e.combats_won,
            "Rooms Explored": f"{e.rooms_explored}/{e.total_rooms}",
            "Game Time (min)": e.game_time_minutes,
        })
        if e.party_description:
            print(f"\n{Colors.INFO}{_sanitize_text(e.party_description)}{Colors.RESET}")
        get_input("\nPress Enter to return to Hall of Fame list...", default="")


def _print_seeded_hall_of_famers(limit: int = 10) -> None:
    """Print top seeded/persisted Hall of Fame entries."""
    hof = HallOfFameManager()
    hof.seed_if_empty()
    entries = hof.list_entries()
    if not entries:
        print(f"{Colors.WARNING}No Hall of Fame entries available.{Colors.RESET}")
        return

    print_subtitle("iOS Hall of Famers")
    for i, e in enumerate(entries[:limit], 1):
        party = ", ".join(e.party_names[:3]) if e.party_names else "Unknown party"
        print(
            f"{i:2}. {e.dungeon_name:<22} "
            f"L{e.dungeon_level}  {e.outcome.upper():7}  "
            f"Score {e.score:4}  - {party}"
        )


def _show_markdown_gallery(section: str, title: str) -> None:
    """Show gallery markdown pages (rooms/races/npcs/monsters) in terminal."""
    base = _repo_root() / "gallery" / section
    if not base.exists():
        print(f"{Colors.WARNING}Gallery section not found: {section}{Colors.RESET}")
        return

    files = sorted(base.glob("*.md"))
    if not files:
        print(f"{Colors.WARNING}No gallery entries in {section}.{Colors.RESET}")
        return

    options = [f.stem.replace("-", " ").title() for f in files]
    while True:
        choice = get_menu_choice(options, f"{title} Gallery", allow_back=True)
        if choice == 0:
            return
        selected = files[choice - 1]
        try:
            text = selected.read_text(encoding="utf-8")
            paged_print(_sanitize_text(text))
        except Exception as exc:
            print(f"{Colors.DANGER}Could not open {selected.name}: {exc}{Colors.RESET}")
        get_input("\nPress Enter to return to gallery...", default="")


def _show_bestiary() -> None:
    """Show a bestiary with stats and ASCII art."""
    monsters = sorted(get_all_monsters(), key=lambda m: (m.cr, m.name))
    options = [f"{m.name} (CR {m.cr:g})" for m in monsters]

    while True:
        choice = get_menu_choice(options, "Bestiary", allow_back=True)
        if choice == 0:
            return
        m = monsters[choice - 1]
        print_title(m.name)
        print(render_monster(m.name, m.current_hp, m.max_hp))
        print_stat_block(m.name, {
            "Type": f"{m.size} {m.monster_type}",
            "AC": m.ac,
            "HP": f"{m.current_hp}/{m.max_hp}",
            "Speed": f"{m.speed} ft",
            "CR": m.cr,
            "XP": m.xp,
            "STR DEX CON INT WIS CHA": f"{m.strength:2} {m.dexterity:2} {m.constitution:2} {m.intelligence:2} {m.wisdom:2} {m.charisma:2}",
        })
        if m.traits:
            print_subtitle("Traits")
            for trait in m.traits[:3]:
                print(f"- {trait.name}: {_sanitize_text(trait.description)}")
        if m.actions:
            print_subtitle("Combat Tips")
            for action in m.actions[:2]:
                tip = f"{action.name}: attack +{action.attack_bonus}, {action.damage} {action.damage_type}".strip()
                print(f"- {tip}")
        get_input("\nPress Enter to continue...", default="")


def _show_npc_guide() -> None:
    """Show NPC reference cards and deeper gallery pages."""
    if not _config.get("npcs_enabled", True):
        print(f"{Colors.WARNING}NPC systems are disabled in Settings -> Gameplay.{Colors.RESET}")
        return

    print_title("Rogues Gallery")
    roster = [
        "Wandering Trader", "Prisoner", "Hermit", "Ghostly Scholar", "Dwarven Smith",
        "Elf Scout", "Goblin Defector", "Mysterious Stranger", "Wounded Knight",
        "Mad Alchemist", "Old Priestess", "Rat Catcher", "Gatekeeper",
    ]
    print("Named iOS NPC roster:")
    for name in roster:
        print(f"- {name}")
    print_subtitle("NPC Roles (Python Runtime)")
    for role in NPCRole:
        template = NPC_TEMPLATES.get(role, {})
        desc = (template.get("descriptions") or ["No description."])[0]
        print(f"- {role.value}: {_sanitize_text(desc)}")
    if confirm("Open markdown NPC gallery?"):
        _show_markdown_gallery("npcs", "NPC")


def _show_name_lore() -> None:
    """Show name lore cards from iOS card dataset."""
    data = _load_card_catalog()
    players = data.get("players", [])
    locations = data.get("locations", [])
    monsters = data.get("monsters", [])
    groups = [("Players", players), ("Locations", locations), ("Monsters", monsters)]

    while True:
        group_choice = get_menu_choice([g[0] for g in groups], "Name Lore", allow_back=True)
        if group_choice == 0:
            return
        group_name, entries = groups[group_choice - 1]
        if not entries:
            print(f"{Colors.WARNING}No lore entries found for {group_name}.{Colors.RESET}")
            continue
        title_opts = [f"{_sanitize_text(e.get('name', 'Unknown'))} - {_sanitize_text(e.get('source', ''))}" for e in entries]
        entry_choice = get_menu_choice(title_opts, f"{group_name} Lore", allow_back=True)
        if entry_choice == 0:
            continue
        e = entries[entry_choice - 1]
        print_title(_sanitize_text(e.get("name", "Unknown")))
        source = _sanitize_text(e.get("source", ""))
        if source:
            print(f"{Colors.INFO}Source: {source}{Colors.RESET}")
        desc = _sanitize_text(e.get("description", ""))
        print()
        paged_print(textwrap.fill(desc, width=76))
        stats = e.get("stats") or {}
        if stats:
            print()
            print_stat_block("Card Stats", {k: v for k, v in stats.items()})
        get_input("\nPress Enter to continue...", default="")


def _show_help_menu() -> None:
    """How-to-play menu aligned with the iOS topic set."""
    topics = [
        "Getting Started",
        "Exploration",
        "Combat",
        "Character & Party",
        "Recovery",
        "Dungeon Master",
        "Multiplayer",
        "Tips & Tricks",
        "FAQs",
        "Bestiary",
        "NPCs",
        "Name Lore",
        "Races Gallery",
        "Rooms Gallery",
    ]
    help_text = {
        "Getting Started": "Create a party, name your dungeon, pick a difficulty, and enter the dungeon. In this terminal version, Enter chooses defaults quickly.",
        "Exploration": "Use arrow keys or WASD/HJKL to move. Search rooms for treasure, check the map often, and clear rooms before resting. You can enable automatic map display after movement in Settings -> Gameplay.",
        "Combat": "On your turn, choose attacks, spells, or tactical actions. Focus dangerous enemies first and watch HP bars closely.",
        "Character & Party": "Party Status shows ASCII character cards and sheets. Build balanced teams with front-line, damage, and support roles.",
        "Recovery": "Short rest for quick HP recovery; long rest for deeper recovery. During the sleep marker, hold z to speed it up, or press q to quit out to menu. Rest in safer rooms when possible.",
        "Dungeon Master": "Use Talk to DM for narrative actions or lore questions. AI backend is configurable in Settings.",
        "Multiplayer": "Python supports local shared-file or socket multiplayer sessions. Host from Play -> Multiplayer.",
        "Tips & Tricks": "Search every room, carry torches, and avoid unnecessary fights before boss rooms.",
        "FAQs": "Search or browse the imported iOS FAQ corpus for controls, combat, torch, saving, and accessibility help.",
    }

    while True:
        choice = get_menu_choice(topics, "How to Play", allow_back=True)
        if choice == 0:
            return
        topic = topics[choice - 1]
        if topic == "Bestiary":
            _show_bestiary()
        elif topic == "NPCs":
            _show_npc_guide()
        elif topic == "Name Lore":
            _show_name_lore()
        elif topic == "Races Gallery":
            _show_markdown_gallery("races", "Races")
        elif topic == "Rooms Gallery":
            _show_markdown_gallery("rooms", "Rooms")
        elif topic == "FAQs":
            _show_faq_browser()
        else:
            print_title(topic)
            paged_print(textwrap.fill(_sanitize_text(help_text.get(topic, "No details yet.")), width=76))
            get_input("\nPress Enter to continue...", default="")


def _show_faq_browser() -> None:
    """Browse and search imported FAQ entries from the iOS app."""
    faq = _load_ios_faq_index()
    categories = faq.get("categories", [])
    if not categories:
        print(f"{Colors.WARNING}FAQ data is unavailable.{Colors.RESET}")
        return

    while True:
        options = ["Search FAQ"] + [c["title"] for c in categories] + ["Back"]
        choice = get_menu_choice(options, "FAQs")
        if choice == len(options):
            return

        if choice == 1:
            query = get_input("Ask your FAQ question: ", default="")
            results = _find_relevant_faq(query, limit=8)
            if not results:
                print(f"{Colors.WARNING}No strong FAQ match found.{Colors.RESET}")
                continue
            result_opts = [r["question"] for r in results]
            picked = get_menu_choice(result_opts, "FAQ Results", allow_back=True)
            if picked == 0:
                continue
            entry = results[picked - 1]
            print_title(entry["question"])
            paged_print(textwrap.fill(entry["answer"], width=76))
            get_input("\nPress Enter to continue...", default="")
            continue

        category = categories[choice - 2]
        entries = category.get("entries", [])
        if not entries:
            print(f"{Colors.WARNING}No FAQ entries in this category.{Colors.RESET}")
            continue
        entry_choice = get_menu_choice([e["question"] for e in entries], category["title"], allow_back=True)
        if entry_choice == 0:
            continue
        entry = entries[entry_choice - 1]
        print_title(entry["question"])
        paged_print(textwrap.fill(entry["answer"], width=76))
        get_input("\nPress Enter to continue...", default="")


def _handle_play_menu(engine: GameEngine) -> None:
    """Play menu (new, load, multiplayer) aligned with iOS flow."""
    options = ["New Adventure", "Saved Adventures"]
    actions = ["new", "load"]
    if _config.get("multiplayer_enabled", True):
        options.append("Multiplayer Matches")
        actions.append("multiplayer")
    options.append("Back")
    actions.append("back")

    choice = get_menu_choice(options, "Play Menu")
    action = actions[choice - 1]
    if action == "new":
        session_name = get_input("Enter a name for your adventure: ", default="Adventure")
        if session_exists(session_name):
            if not confirm(f"A save named '{session_name}' exists. Overwrite?"):
                return
        engine.new_game(session_name)
    elif action == "load":
        _load_game_interactive(engine)
    elif action == "multiplayer":
        handle_multiplayer_menu(engine)


def handle_settings_menu(engine: Optional[GameEngine] = None) -> None:
    """Settings tree inspired by iOS categories."""
    while True:
        options = ["DM Settings", "Accessibility", "Mood", "Gameplay", "Saving", "Back"]
        choice = get_menu_choice(options, "Settings")
        if choice == 6:
            return

        if choice == 1:
            dm_options = [
                f"AI Provider: {_config['ai_backend']}",
                f"DM Timeout: {_config['timeout']}s",
                f"Idle Prompts: {'On' if _config['idle_prompts'] else 'Off'}",
                "Back",
            ]
            dm_choice = get_menu_choice(dm_options, "DM Settings")
            if dm_choice == 1:
                ai = get_menu_choice(["local", "anthropic", "openai"], "Choose AI provider")
                _config['ai_backend'] = ["local", "anthropic", "openai"][ai - 1]
            elif dm_choice == 2:
                timeout_raw = get_input("Timeout seconds (0 disables): ", default=str(_config["timeout"]))
                try:
                    _config["timeout"] = max(0, int(timeout_raw))
                    _config["idle_prompts"] = _config["timeout"] > 0
                except ValueError:
                    print(f"{Colors.WARNING}Invalid timeout.{Colors.RESET}")
            elif dm_choice == 3:
                _config["idle_prompts"] = not _config["idle_prompts"]
                if not _config["idle_prompts"]:
                    _config["timeout"] = 0
                elif _config["timeout"] == 0:
                    _config["timeout"] = 120

        elif choice == 2:
            acc_options = [
                f"Arrow-Key Menus: {'On' if _config['use_arrow_keys'] else 'Off'}",
                f"Use Defaults on Enter: {'On' if _config['use_defaults'] else 'Off'}",
                "Back",
            ]
            acc_choice = get_menu_choice(acc_options, "Accessibility")
            if acc_choice == 1:
                _config["use_arrow_keys"] = not _config["use_arrow_keys"]
            elif acc_choice == 2:
                _config["use_defaults"] = not _config["use_defaults"]

        elif choice == 3:
            mood_options = [
                f"Theme: {'Green-on-Black' if _config['use_theme'] else 'Terminal Default'}",
                f"Splash Screen: {'On' if _config['show_splash'] else 'Off'}",
                f"Splash Style: {_config.get('splash_style', 'dragon')}",
                "Back",
            ]
            mood_choice = get_menu_choice(mood_options, "Mood")
            if mood_choice == 1:
                _config["use_theme"] = not _config["use_theme"]
                if _config["use_theme"]:
                    set_terminal_theme(clear=False)
                else:
                    reset_terminal()
            elif mood_choice == 2:
                _config["show_splash"] = not _config["show_splash"]
            elif mood_choice == 3:
                style_choice = get_menu_choice(["dragon", "castle", "simple", "classic"], "Choose splash style")
                _config["splash_style"] = ["dragon", "castle", "simple", "classic"][style_choice - 1]

        elif choice == 4:
            game_options = [
                f"Map Radius: {_config['map_radius']}",
                f"Card Navigation: {'On' if _config['card_navigation'] else 'Off'}",
                f"NPCs: {'On' if _config['npcs_enabled'] else 'Off'}",
                f"Multiplayer: {'On' if _config['multiplayer_enabled'] else 'Off'}",
                f"Adventure Log: {'On' if _config['adventure_log_enabled'] else 'Off'}",
                f"Auto-Show Map After Move: {'On' if _config['auto_show_map'] else 'Off'}",
                "Back",
            ]
            game_choice = get_menu_choice(game_options, "Gameplay")
            if game_choice == 1:
                radius_raw = get_input("Map radius (1-6): ", default=str(_config["map_radius"]))
                try:
                    _config["map_radius"] = max(1, min(6, int(radius_raw)))
                except ValueError:
                    print(f"{Colors.WARNING}Invalid radius.{Colors.RESET}")
            elif game_choice == 2:
                _config["card_navigation"] = not _config["card_navigation"]
            elif game_choice == 3:
                _config["npcs_enabled"] = not _config["npcs_enabled"]
            elif game_choice == 4:
                _config["multiplayer_enabled"] = not _config["multiplayer_enabled"]
            elif game_choice == 5:
                _config["adventure_log_enabled"] = not _config["adventure_log_enabled"]
            elif game_choice == 6:
                _config["auto_show_map"] = not _config["auto_show_map"]

        elif choice == 5:
            save_options = [
                f"Auto-save: {'On' if _config['auto_save'] else 'Off'}",
                "Manage Saves (list only)",
                "Back",
            ]
            save_choice = get_menu_choice(save_options, "Saving")
            if save_choice == 1:
                _config["auto_save"] = not _config["auto_save"]
            elif save_choice == 2:
                sessions = _sorted_sessions()
                print_subtitle("Saved Adventures")
                if not sessions:
                    print("No saves yet.")
                else:
                    for i, s in enumerate(sessions, 1):
                        print(f"{i:2}. {s.get('name', 'Unknown')}  [{s.get('last_played', '')[:19]}]")
                get_input("\nPress Enter to continue...", default="")


def handle_main_menu(engine: GameEngine) -> None:
    """Handle iOS-style main menu interactions."""
    global _multiplayer

    options = ["Continue Quest", "Play", "Hall of Fame", "How to Play", "Settings", "Quit"]
    vlog("Awaiting main menu choice")
    choice = get_menu_choice(options, "Main Menu")
    vlog(f"Main menu choice={choice}")

    if choice == 1:
        _continue_last_quest(engine)
    elif choice == 2:
        _handle_play_menu(engine)
    elif choice == 3:
        _show_hall_of_fame()
    elif choice == 4:
        _show_help_menu()
    elif choice == 5:
        handle_settings_menu(engine)
    elif choice == 6:
        if _multiplayer:
            _multiplayer.leave_game() if hasattr(_multiplayer, 'leave_game') else _multiplayer.close()
        print("Thanks for playing!")
        sys.exit(0)


def handle_multiplayer_menu(engine: GameEngine) -> None:
    """Handle multiplayer menu."""
    global _multiplayer

    if not _config.get("multiplayer_enabled", True):
        print(f"{Colors.WARNING}Multiplayer is disabled in Settings -> Gameplay.{Colors.RESET}")
        return

    print_title("Multiplayer")
    print(f"Your IP: {get_local_ip()}")
    print()

    options = [
        "Host Game (Shared File - Local Network)",
        "Host Game (Network Socket)",
        "Join Game (Shared File)",
        "Join Game (Network Socket)",
        "List Available Games",
    ]
    choice = get_menu_choice(options, "Multiplayer Options", allow_back=True)

    if choice == 0:  # Back
        return

    player_name = get_input("Enter your player name: ", default="Player")

    if choice == 1:  # Host - Shared File
        _multiplayer = SharedFileMultiplayer(player_name)
        session_name = get_input("Enter session name: ", default="MyGame")
        if True:
            try:
                session_id = _multiplayer.host_game(session_name)
                print(f"\n{Colors.SUCCESS}Game hosted!{Colors.RESET}")
                print(f"Session ID: {Colors.INFO}{session_id}{Colors.RESET}")
                print("Other players can join using this Session ID.")
                print(f"Session file: ~/.dnd_multiplayer/{session_id}.json")
                print()
                wait_for_players_and_start(engine, _multiplayer)
            except Exception as e:
                print(f"{Colors.DANGER}Failed to host game: {e}{Colors.RESET}")

    elif choice == 2:  # Host - Socket
        _multiplayer = SocketMultiplayer(player_name)
        try:
            connection_info = _multiplayer.host_game()
            print(f"\n{Colors.SUCCESS}Game hosted!{Colors.RESET}")
            print(f"Connection info: {Colors.INFO}{connection_info}{Colors.RESET}")
            print("Other players can connect using this address.")
            print()
            wait_for_players_and_start(engine, _multiplayer)
        except Exception as e:
            print(f"{Colors.DANGER}Failed to host game: {e}{Colors.RESET}")

    elif choice == 3:  # Join - Shared File
        _multiplayer = SharedFileMultiplayer(player_name)

        # List available sessions
        sessions = _multiplayer.list_sessions()
        if sessions:
            print("\nAvailable sessions:")
            for i, s in enumerate(sessions, 1):
                print(f"  {i}. {s['session_id']} (Host: {s['host']}, Players: {s['player_count']})")
            print()

        # Default to first available session if any
        default_session = sessions[0]['session_id'] if sessions else ""
        session_id = get_input("Enter session ID to join: ", default=default_session if default_session else None)
        if session_id:
            if _multiplayer.join_game(session_id):
                print(f"\n{Colors.SUCCESS}Joined game!{Colors.RESET}")
                wait_as_player(engine, _multiplayer)
            else:
                print(f"{Colors.DANGER}Failed to join game. Session may not exist.{Colors.RESET}")

    elif choice == 4:  # Join - Socket
        _multiplayer = SocketMultiplayer(player_name)
        address = get_input("Enter host address (IP:port): ", default="localhost:5555")
        if address:
            if _multiplayer.join_game(address):
                print(f"\n{Colors.SUCCESS}Connected to game!{Colors.RESET}")
                wait_as_player(engine, _multiplayer)
            else:
                print(f"{Colors.DANGER}Failed to connect. Check the address and try again.{Colors.RESET}")

    elif choice == 5:  # List games
        mp = SharedFileMultiplayer(player_name)
        sessions = mp.list_sessions()
        if sessions:
            print_subtitle("Available Games (Shared File)")
            for s in sessions:
                print(f"  {s['session_id']}")
                print(f"    Host: {s['host']}, Players: {s['player_count']}")
                print(f"    Last active: {s['last_active'][:19]}")
                print()
        else:
            print(f"{Colors.WARNING}No active games found.{Colors.RESET}")

    # choice == 6 returns to main menu


def wait_for_players_and_start(engine: GameEngine, mp) -> None:
    """Host waits for players to join, then starts the game."""
    print_subtitle("Waiting for Players")
    print("Players will appear here as they join.")
    print("Press Enter when ready to start (or 'q' to cancel).")
    print()

    def on_state_change(state):
        print(f"\r{Colors.INFO}Players ({len(state.players)}):{Colors.RESET} ", end="")
        names = [p.name for p in state.players.values()]
        print(", ".join(names), end="    \n")

    mp.on_state_change(on_state_change)

    # Show initial state
    if mp.state:
        on_state_change(mp.state)

    while True:
        cmd = get_input("").strip().lower()
        if cmd == 'q':
            if hasattr(mp, 'close_session'):
                mp.close_session()
            else:
                mp.close()
            return
        elif cmd == '' or cmd == 'start':
            break

    # Start the game
    print(f"\n{Colors.SUCCESS}Starting game...{Colors.RESET}")

    # Create session
    session_name = mp.state.session_id if mp.state else "multiplayer_game"
    engine.new_game(session_name)

    # Set up character assignment for each player
    setup_multiplayer_party(engine, mp)


def setup_multiplayer_party(engine: GameEngine, mp) -> None:
    """Set up party with characters assigned to multiplayer players."""
    if not mp.state:
        return

    players = list(mp.state.players.values())
    print_subtitle("Party Setup (Multiplayer)")
    print(f"Creating characters for {len(players)} player(s).\n")

    for player_info in players:
        print(f"\n{Colors.SUBTITLE}Creating character for {player_info.name}{Colors.RESET}")

        if player_info.role == PlayerRole.HOST:
            # Host creates their character locally
            character = create_character_interactive()
            if not character:
                print(f"{Colors.WARNING}Multiplayer setup cancelled by host.{Colors.RESET}")
                if hasattr(mp, 'close_session'):
                    mp.close_session()
                else:
                    mp.close()
                engine.state = GameState.MAIN_MENU
                return
            human_player = HumanPlayer(character.name)
            engine.add_character_to_party(character, human_player)
            mp.assign_character(character.name)
            print(f"\n{Colors.SUCCESS}{character.name} joins the party!{Colors.RESET}")
        else:
            # For remote players, host creates a placeholder or waits
            # In a full implementation, we'd sync character creation
            print(f"  Waiting for {player_info.name} to create character...")
            # For now, create AI placeholder
            character = create_character_interactive()
            if not character:
                print(f"{Colors.WARNING}Skipped character for {player_info.name}.{Colors.RESET}")
                continue
            # Remote player controls via multiplayer
            ai_player = AIPlayer(character.name, AIPersonality.BALANCED)
            engine.add_character_to_party(character, ai_player)
            mp.assign_character(character.name)

    # Start adventure
    if engine.party:
        dungeon_name = _choose_name_with_suggestions_optional(
            "Name your dungeon",
            suggestions=_card_name_suggestions("locations", count=10),
            default_name="The Dark Depths",
        )
        if not dungeon_name:
            print(f"{Colors.WARNING}Multiplayer adventure start cancelled.{Colors.RESET}")
            if hasattr(mp, 'close_session'):
                mp.close_session()
            else:
                mp.close()
            engine.state = GameState.MAIN_MENU
            return

        difficulty = _choose_difficulty_optional("Choose difficulty:")
        if difficulty is None:
            print(f"{Colors.WARNING}Multiplayer adventure start cancelled.{Colors.RESET}")
            if hasattr(mp, 'close_session'):
                mp.close_session()
            else:
                mp.close()
            engine.state = GameState.MAIN_MENU
            return

        description = engine.start_adventure(dungeon_name, difficulty)

        # Sync game state to all players
        mp.update_game_state({
            "dungeon_name": dungeon_name,
            "difficulty": difficulty,
            "party": [c.name for c in engine.party]
        })

        clear_screen(preserve_scrollback=True)
        print(description)


def wait_as_player(engine: GameEngine, mp) -> None:
    """Client player waits for game to start and plays."""
    print_subtitle("Waiting for Game to Start")
    print("The host will start the game when all players are ready.")
    print()

    # Mark ourselves as ready
    mp.set_ready(True)

    def on_state_change(state):
        # Show current players
        print(f"\r{Colors.INFO}Players:{Colors.RESET} ", end="")
        for p in state.players.values():
            status = "[Ready]" if p.ready else "[...]"
            print(f"{p.name} {status}", end="  ")
        print()

        # Check for game start
        if state.game_state.get("dungeon_name"):
            print(f"\n{Colors.SUCCESS}Game started!{Colors.RESET}")
            print(f"Dungeon: {state.game_state['dungeon_name']}")

        # Show messages
        for msg in state.messages[-3:]:
            if msg.get('type') == 'chat':
                print(f"  [{msg['player']}]: {msg['text']}")
            elif msg.get('type') == 'system':
                print(f"  {Colors.INFO}{msg['text']}{Colors.RESET}")

    mp.on_state_change(on_state_change)

    # Wait for game to start
    print("You can chat while waiting. Type messages and press Enter.")
    print("Type 'q' to leave.\n")

    while True:
        msg = get_input("").strip()
        if msg.lower() == 'q':
            mp.leave_game() if hasattr(mp, 'leave_game') else mp.close()
            return
        elif msg:
            mp.send_message(msg)

        # Check if game started
        if mp.state and mp.state.game_state.get("dungeon_name"):
            break

    # Game has started - for now, show spectator view
    # Full implementation would integrate with game engine
    print("\n" + "=" * 40)
    print("Game in progress! (Spectator mode)")
    print("Full player sync coming in next update.")
    print("=" * 40)


def handle_party_setup(engine: GameEngine) -> None:
    """Handle party creation."""
    print_title("Party Setup")
    vlog("Party setup started")

    # Get number of party members
    print("How many adventurers in your party? (1-4, or 0 for random)")
    while True:
        try:
            num_input = get_input("Number of party members: ", default="1")
            num_party = int(num_input)
            if num_party == 0:
                num_party = random.randint(1, 4)
                print(f"{Colors.INFO}Random party size selected: {num_party}{Colors.RESET}")
                break
            if 1 <= num_party <= 4:
                break
            print(f"{Colors.WARNING}Please enter 0, or a number between 1 and 4.{Colors.RESET}")
        except ValueError:
            print(f"{Colors.WARNING}Please enter a valid number.{Colors.RESET}")

    # Create each party member
    created = 0
    while created < num_party:
        print_subtitle(f"Character {created + 1} of {num_party}")

        # Human or AI?
        player_type = get_menu_choice(
            ["Human Player", "AI Player"],
            "Who will control this character?",
            allow_back=True,
        )
        if player_type == 0:
            print(f"{Colors.WARNING}Party setup cancelled.{Colors.RESET}")
            engine.state = GameState.MAIN_MENU
            return

        # Create character
        character = create_character_interactive()
        if not character:
            print(f"{Colors.WARNING}Character creation cancelled.{Colors.RESET}")
            if confirm("Cancel party setup and return to main menu?", default=True):
                engine.state = GameState.MAIN_MENU
                return
            continue

        # Create player controller
        if player_type == 1:
            player = HumanPlayer(character.name)
        else:
            personality_choice = get_menu_choice(
                ["Balanced", "Aggressive", "Defensive", "Supportive"],
                "Choose AI personality:",
                allow_back=True,
            )
            if personality_choice == 0:
                print(f"{Colors.WARNING}Character control selection cancelled.{Colors.RESET}")
                continue
            personalities = [
                AIPersonality.BALANCED,
                AIPersonality.AGGRESSIVE,
                AIPersonality.DEFENSIVE,
                AIPersonality.SUPPORTIVE,
            ]
            player = AIPlayer(character.name, personalities[personality_choice - 1])

        engine.add_character_to_party(character, player)
        print(f"\n{Colors.SUCCESS}{character.name} joins the party!{Colors.RESET}")
        print(character.display_sheet())

        # Add character to scoreboard
        _session.scoreboard.add_character(
            character.name,
            character.char_class.name,
            character.level,
            character.current_hp,
            character.max_hp
        )
        created += 1

    # Start adventure
    if engine.party:
        print_subtitle("Adventure Awaits!")
        dungeon_name = _choose_name_with_suggestions_optional(
            "Name your dungeon",
            suggestions=_card_name_suggestions("locations", count=10),
            default_name="The Dark Depths",
        )
        if not dungeon_name:
            print(f"{Colors.WARNING}Adventure start cancelled.{Colors.RESET}")
            engine.state = GameState.MAIN_MENU
            return

        difficulty = _choose_difficulty_optional("Choose difficulty:")
        if difficulty is None:
            print(f"{Colors.WARNING}Adventure start cancelled.{Colors.RESET}")
            engine.state = GameState.MAIN_MENU
            return

        # Start session tracking
        _session.start_session(dungeon_name)

        description = engine.start_adventure(dungeon_name, difficulty)
        clear_screen(preserve_scrollback=True)
        print(description)
    else:
        print(f"{Colors.DANGER}No characters created. Returning to menu.{Colors.RESET}")
        engine.state = GameState.MAIN_MENU


def _choose_name_with_suggestions(prompt: str, suggestions: List[str], default_name: str) -> str:
    """Choose a custom name or pick from suggestions."""
    suggestions = [s for s in suggestions if s]
    if not suggestions:
        return get_input(f"{prompt}: ", default=default_name)

    options = [f"Custom ({default_name})"] + suggestions[:10] + ["Random Suggestion"]
    choice = get_menu_choice(options, f"{prompt} (suggestions)", allow_back=False)
    if choice == 1:
        return get_input(f"{prompt}: ", default=default_name)
    if choice == len(options):
        return random.choice(suggestions[:10])
    return suggestions[choice - 2]


def _choose_name_with_suggestions_optional(prompt: str, suggestions: List[str], default_name: str) -> Optional[str]:
    """Choose a custom name/suggestion with Back support."""
    suggestions = [s for s in suggestions if s]
    options = [f"Custom ({default_name})"]
    if suggestions:
        options.extend(suggestions[:10])
        options.append("Random Suggestion")
    choice = get_menu_choice(options, f"{prompt} (suggestions)", allow_back=True)
    if choice == 0:
        return None
    if choice == 1:
        return get_input(f"{prompt}: ", default=default_name)
    if suggestions and choice == len(options):
        return random.choice(suggestions[:10])
    return suggestions[choice - 2] if suggestions else default_name


def _choose_difficulty_optional(title: str = "Choose difficulty:") -> Optional[int]:
    """Pick difficulty with Back/Cancel support."""
    choice = get_menu_choice(
        ["Easy (Level 1)", "Medium (Level 2)", "Hard (Level 3)"],
        title,
        allow_back=True,
    )
    if choice == 0:
        return None
    return choice


def _auto_build_character() -> Character:
    """Create a full auto character."""
    races = get_all_races()
    classes = get_all_classes()
    race = random.choice(races)
    char_class = random.choice(classes)
    name = random.choice(_card_name_suggestions("players", count=20) or ["Adventurer"])

    abilities = ["Strength", "Dexterity", "Constitution", "Intelligence", "Wisdom", "Charisma"]
    assigned_scores = assign_ability_scores(standard_array(), abilities, char_class, force_auto=True) or {
        "strength": 10, "dexterity": 10, "constitution": 10,
        "intelligence": 10, "wisdom": 10, "charisma": 10,
    }

    from .characters.abilities import Abilities, AbilityScores
    ability_scores = AbilityScores(
        strength=assigned_scores['strength'],
        dexterity=assigned_scores['dexterity'],
        constitution=assigned_scores['constitution'],
        intelligence=assigned_scores['intelligence'],
        wisdom=assigned_scores['wisdom'],
        charisma=assigned_scores['charisma'],
    )
    character = Character(name, race, char_class, Abilities(ability_scores))

    available_skills = list(char_class.skill_choices)
    random.shuffle(available_skills)
    for skill in available_skills[:char_class.num_skill_choices]:
        character.skills.add_proficiency(skill)

    if character.spellbook:
        add_starting_spells(character)
    return character


def create_character_interactive() -> Optional[Character]:
    """Interactive character creation."""
    mode = get_menu_choice(
        ["Manual Build", "Auto Build Character"],
        "Character Creation",
        allow_back=True
    )
    if mode == 0:
        return None
    if mode == 2:
        character = _auto_build_character()
        print(f"{Colors.SUCCESS}Auto-built {character.name} ({character.race.name} {character.char_class.name}).{Colors.RESET}")
        return character

    # Get name with iOS-style suggestions + custom
    name = _choose_name_with_suggestions_optional(
        "Enter character name",
        suggestions=_card_name_suggestions("players", count=12),
        default_name="Adventurer",
    )
    if not name:
        return None

    # Choose race
    races = get_all_races()
    race_names = [r.get_full_name() for r in races]
    print_menu(race_names, "Choose your race:")
    race_choice = get_menu_choice(race_names, "Race:", allow_back=True)
    if race_choice == 0:
        return None
    race = races[race_choice - 1]

    # Choose class
    classes = get_all_classes()
    class_names = [c.name for c in classes]
    print_menu(class_names, "Choose your class:")
    class_choice = get_menu_choice(class_names, "Class:", allow_back=True)
    if class_choice == 0:
        return None
    char_class = classes[class_choice - 1]

    # Ability scores
    print_subtitle("Ability Scores")
    method = get_menu_choice(
        ["Auto (Recommended)", "Standard Array (15, 14, 13, 12, 10, 8)", "Roll 4d6 drop lowest"],
        "Choose ability score method:",
        allow_back=True
    )
    if method == 0:
        return None

    if method == 1:
        scores = standard_array()
    elif method == 2:
        scores = standard_array()
    else:
        scores = roll_ability_scores()
        print(f"You rolled: {scores}")

    # Assign scores
    abilities = ["Strength", "Dexterity", "Constitution", "Intelligence", "Wisdom", "Charisma"]
    assigned_scores = assign_ability_scores(scores, abilities, char_class, force_auto=(method == 1))
    if not assigned_scores:
        return None

    # Choose skills
    print_subtitle("Skill Proficiencies")
    available_skills = char_class.skill_choices
    num_skills = char_class.num_skill_choices
    print(f"Choose {num_skills} skills from: {', '.join(available_skills)}")

    chosen_skills = []
    remaining_skills = available_skills.copy()
    i = 0
    while i < num_skills:
        options = list(remaining_skills) + ["Auto Remaining Skills"]
        print_menu(options, f"Skill {i + 1} of {num_skills}:")
        skill_choice = get_menu_choice(options, "Choose skill:", allow_back=True)
        if skill_choice == 0:
            return None
        if skill_choice == len(options):
            need = num_skills - len(chosen_skills)
            random.shuffle(remaining_skills)
            chosen_skills.extend(remaining_skills[:need])
            remaining_skills = remaining_skills[need:]
            break
        skill = remaining_skills.pop(skill_choice - 1)
        chosen_skills.append(skill)
        i += 1

    # Create character using engine method would be cleaner but we'll do it directly
    from .characters.abilities import Abilities, AbilityScores

    ability_scores = AbilityScores(
        strength=assigned_scores['strength'],
        dexterity=assigned_scores['dexterity'],
        constitution=assigned_scores['constitution'],
        intelligence=assigned_scores['intelligence'],
        wisdom=assigned_scores['wisdom'],
        charisma=assigned_scores['charisma'],
    )
    abilities_obj = Abilities(ability_scores)

    character = Character(name, race, char_class, abilities_obj)

    # Add skill proficiencies
    for skill in chosen_skills:
        character.skills.add_proficiency(skill)

    # Add starting spells for spellcasters
    if character.spellbook:
        add_starting_spells(character)

    return character


def assign_ability_scores(scores: List[int], abilities: List[str],
                         char_class, force_auto: bool = False) -> Optional[dict]:
    """Let player assign ability scores with auto/manual/cancel options."""
    assigned = {}
    remaining_scores = sorted(scores, reverse=True)
    remaining_abilities = abilities.copy()

    # Show recommendation
    primary = char_class.primary_ability.name.title()
    print(f"\n{Colors.INFO}Tip: {char_class.name}s use {primary} as their primary ability.{Colors.RESET}")
    print(f"{Colors.MUTED}(Press Enter to auto-assign optimal scores){Colors.RESET}")

    # Define optimal ability order based on class
    class_ability_priority = {
        "Fighter": ["Strength", "Constitution", "Dexterity", "Wisdom", "Charisma", "Intelligence"],
        "Wizard": ["Intelligence", "Constitution", "Dexterity", "Wisdom", "Charisma", "Strength"],
        "Rogue": ["Dexterity", "Constitution", "Intelligence", "Wisdom", "Charisma", "Strength"],
        "Cleric": ["Wisdom", "Constitution", "Strength", "Dexterity", "Charisma", "Intelligence"],
        "Ranger": ["Dexterity", "Wisdom", "Constitution", "Intelligence", "Strength", "Charisma"],
        "Barbarian": ["Strength", "Constitution", "Dexterity", "Wisdom", "Charisma", "Intelligence"],
    }

    print(f"\nScores to assign: {remaining_scores}")
    if force_auto:
        auto_assign = True
    else:
        mode = get_menu_choice(
            ["Auto Assign (Recommended)", "Manual Assign"],
            "Ability Assignment",
            allow_back=True
        )
        if mode == 0:
            return None
        auto_assign = mode == 1

    if auto_assign:
        # Auto-assign based on class priority
        priority = class_ability_priority.get(char_class.name, abilities)
        for ability in priority:
            if ability in remaining_abilities and remaining_scores:
                score = remaining_scores.pop(0)  # Take highest remaining
                assigned[ability.lower()] = score
                remaining_abilities.remove(ability)
                print(f"  {ability}: {score}")
        return assigned

    # Manual assignment
    for _ in range(len(abilities)):
        print(f"\nRemaining scores: {remaining_scores}")

        # Default to first ability (or recommended if available)
        default_idx = 1
        for i, ab in enumerate(remaining_abilities, 1):
            if ab.upper() == primary.upper():
                default_idx = i
                break

        ability_opts = []
        for ability in remaining_abilities:
            rec = " (Recommended)" if ability.upper() == primary.upper() else ""
            ability_opts.append(f"{ability}{rec}")
        ability_choice = get_menu_choice(
            ability_opts,
            "Choose ability to assign",
            default=default_idx,
            allow_back=True
        )
        if ability_choice == 0:
            return None

        ability = remaining_abilities.pop(ability_choice - 1)

        # Choose score - default to highest remaining
        score_options = [str(s) for s in remaining_scores]
        score_choice = get_menu_choice(
            score_options,
            f"Choose score for {ability}",
            default=1,
            allow_back=True
        )
        if score_choice == 0:
            return None
        score_value = int(score_options[score_choice - 1])
        remaining_scores.remove(score_value)

        assigned[ability.lower()] = score_value
        print(f"{ability}: {score_value}")

    return assigned


def add_starting_spells(character: Character) -> None:
    """Add appropriate starting spells to a spellcasting character."""
    from .characters.spells import get_spells_by_class, get_cantrips

    class_name = character.char_class.name.lower()

    # Get spells for this class
    class_cantrips = [s for s in get_cantrips() if class_name in s.classes]
    class_spells = [s for s in get_spells_by_class(class_name) if s.level == 1]

    # Add cantrips (up to class limit)
    spell_slots = character.char_class.get_spell_slots(1)
    for cantrip in class_cantrips[:spell_slots.cantrips]:
        character.spellbook.learn_spell(cantrip.name)

    # Add level 1 spells
    if class_name == "wizard":
        # Wizards get 6 spells in spellbook
        for spell in class_spells[:6]:
            character.spellbook.learn_spell(spell.name)
    else:
        # Other casters prepare from full list
        for spell in class_spells:
            character.spellbook.learn_spell(spell.name)


def _ensure_room_npc(engine: GameEngine):
    """Create or fetch a persistent NPC for the current room when applicable."""
    if not _config.get("npcs_enabled", True):
        return None
    if not engine.dm.dungeon or not engine.dm.dungeon.current_room:
        return None

    room = engine.dm.dungeon.current_room
    if room.id in _room_npcs:
        return _room_npcs[room.id]

    # Room-type driven spawn chance for richer iOS-style encounters.
    spawn_table = {
        "ENTRANCE": (1.0, "quest"),
        "REST": (0.55, NPCRole.PRIEST),
        "SHRINE": (0.65, NPCRole.PRIEST),
        "LIBRARY": (0.45, NPCRole.SCHOLAR),
        "PRISON": (0.50, NPCRole.QUEST_GIVER),
        "ARMORY": (0.40, NPCRole.BLACKSMITH),
        "TREASURE": (0.35, NPCRole.MERCHANT),
    }

    key = room.room_type.name if hasattr(room.room_type, "name") else str(room.room_type)
    entry = spawn_table.get(key)
    if not entry:
        return None
    chance, role_or_marker = entry
    if random.random() > chance:
        return None

    if role_or_marker == "quest":
        npc, _ = generate_quest_giver()
        npc.name = "Gatekeeper"
        npc.description = "A weathered warden who tracks your progress and offers reward for clearing the dungeon."
    else:
        npc = generate_npc(role_or_marker)

    _room_npcs[room.id] = npc
    return npc


def _npc_contextual_line(npc: NPC, engine: GameEngine) -> str:
    """Generate an in-character contextual line aligned to current room state."""
    room = engine.dm.dungeon.current_room if engine.dm.dungeon else None
    if not room:
        return "These halls hide more than they reveal."

    warnings = []
    if room.encounter and not room.cleared:
        warnings.append("You have hostiles nearby. Stay sharp.")
    if room.treasure:
        warnings.append("I can smell coin in this room.")
    if room.trap and not room.trap.disarmed:
        warnings.append("Watch your step; these stones are not to be trusted.")

    if warnings:
        return random.choice(warnings)

    context = "exploration"
    if any(c.current_hp < (c.max_hp * 0.4) for c in engine.party):
        context = "low_health"
    return engine.dm.get_dm_tip(context)


def handle_npc_interaction(engine: GameEngine) -> None:
    """Interactive NPC dialogue flow with context-aware responses."""
    npc = _ensure_room_npc(engine)
    if not npc:
        status_message("No one here responds.")
        return

    print_title(f"Talk: {npc.name}")
    print(engine.dm.describe_npc(npc))

    key = "start"
    while True:
        line = npc.get_dialogue(key)
        if not line:
            break
        print()
        print(f"{Colors.NPC}{npc.name}:{Colors.RESET} {_sanitize_text(line.text)}")

        options = [r.text for r in line.responses]
        options.append("Any advice for this room?")
        options.append("Leave")
        choice = get_menu_choice(options, "Choose your reply")

        if choice == len(options):
            break
        if choice == len(options) - 1:
            tip = _npc_contextual_line(npc, engine)
            print(f"\n{Colors.INFO}{npc.name}:{Colors.RESET} {_sanitize_text(tip)}")
            continue

        response = line.responses[choice - 1]
        effect = (response.effect or "").lower()
        if effect == "open_shop":
            stock = ", ".join(npc.inventory[:6]) if npc.inventory else "basic supplies"
            print(f"\n{Colors.INFO}{npc.name}{Colors.RESET} shows wares: {stock}.")
        elif effect == "accept_quest" and npc.quest:
            print(f"\n{Colors.SUCCESS}Quest accepted:{Colors.RESET} {npc.quest.name}")
            print(_sanitize_text(npc.quest.description))
        elif effect == "improve_attitude":
            npc.improve_attitude()

        if response.next_dialogue:
            key = response.next_dialogue
        else:
            break

    get_input("\nPress Enter to continue...", default="")


def _strike(text: str) -> str:
    """ANSI strikethrough text."""
    return f"\x1b[9m{text}\x1b[29m"


def _direction_option(direction: str, available: bool, room_lit: bool, tried_blocked: bool) -> str:
    """Render a directional menu option respecting lighting and attempt history."""
    arrow = {"north": "↑", "south": "↓", "west": "←", "east": "→"}[direction]
    hotkey = {"north": "N", "south": "S", "west": "W", "east": "E"}[direction]
    label = direction.title()

    if available:
        return f"{arrow} {label} [{hotkey}]"

    if room_lit:
        return f"{arrow} {_strike(label)} [-]"

    # Dark room: hide unknown exits until player tests them.
    unknown = _strike("?") if tried_blocked else "?"
    return f"{arrow} {unknown} [?]"


def show_game_menu(
    directions_available: List[str],
    can_collect: bool,
    can_talk_npc: bool = False,
    room_lit: bool = True,
    room_id: Optional[int] = None,
) -> str:
    """
    Show the main game menu with arrow key support for movement.

    Returns the action to take.
    """
    from .utils.display import _getch, _is_tty, _hide_cursor, _show_cursor
    import random

    # Build game menu options
    options = []
    actions = []

    # Movement options (always shown; unavailable ones are marked contextually).
    blocked_attempts = _runtime_state.get("blocked_door_attempts", set())
    for direction in ["north", "south", "west", "east"]:
        tried_blocked = (room_id, direction) in blocked_attempts if room_id is not None else False
        options.append(
            _direction_option(
                direction=direction,
                available=(direction in directions_available),
                room_lit=room_lit,
                tried_blocked=tried_blocked,
            )
        )
        actions.append(direction)

    # Game actions
    options.append("🔍 Search Room")
    actions.append('search')
    options.append("💤 Take a Rest")
    actions.append('rest')
    options.append("📊 Party Status")
    actions.append('status')
    options.append("🗺  View Map")
    actions.append('map')

    if can_collect:
        options.append("💰 Collect Treasure")
        actions.append('collect')
    # Unified talk menu (DM, NPC if present, companions).
    options.append("💬 Talk")
    actions.append('talk')

    # System menu access
    options.append("⚙  System Menu")
    actions.append('system')

    # Determine auto-action for timeout
    if directions_available:
        auto_action = random.choice(directions_available)
    else:
        auto_action = 'search'

    # Check if we can use interactive mode
    if _is_tty():
        vlog(f"Game menu interactive mode: directions={directions_available}, can_collect={can_collect}")
        return _game_menu_interactive(options, actions, directions_available, auto_action)
    else:
        # Fallback to regular menu with timeout
        timeout = _config.get('timeout', 0)
        vlog(f"Game menu fallback mode: timeout={timeout}, auto_action={auto_action}")
        if timeout > 0:
            choice = get_menu_choice(options, "What do you do?", timeout=float(timeout))
            if choice == 0:  # Timeout
                print(f"\n{Colors.WARNING}⏰ Time's up! Moving {auto_action}...{Colors.RESET}")
                return auto_action
        else:
            choice = get_menu_choice(options, "What do you do?")
        return actions[choice - 1]


def _game_menu_interactive(options: List[str], actions: List[str],
                           directions_available: List[str], auto_action: str = 'search') -> str:
    """
    Interactive game menu with arrow key navigation.
    Standard interface: arrows navigate, Enter selects, hjkl for movement.
    """
    from .utils.display import _getch, _hide_cursor, _show_cursor, Colors

    import time

    selected = 0
    num_options = len(options)
    timeout = _config.get('timeout', 0)
    start_time = time.time()

    def get_remaining():
        if timeout <= 0:
            return None
        return max(0, timeout - (time.time() - start_time))

    def draw_menu(status_msg: str = ""):
        """Draw the complete menu with current selection highlighted."""
        # Move cursor up to redraw menu in place (if not first draw)
        # Title line + hint line + blank + options + blank = num_options + 4 lines
        lines_to_clear = num_options + 4

        # Clear previous menu
        for _ in range(lines_to_clear):
            print('\x1b[A\x1b[2K', end='')  # Move up and clear line

        # Draw menu
        print(f"{Colors.SUBTITLE}What do you do?{Colors.RESET}")
        print(f"{Colors.MUTED}  ↑↓=navigate  Enter=select  hjkl=move WSEN  ESC=system{Colors.RESET}")
        if status_msg:
            print(f"{Colors.WARNING}  {status_msg}{Colors.RESET}")
        else:
            print()

        for i, option in enumerate(options):
            if i == selected:
                # Highlighted selection
                print(f"  {Colors.TITLE}> {i+1}. {option}{Colors.RESET}")
            else:
                print(f"    {i+1}. {option}")
        print()

    def select_action(action: str) -> str:
        """Select an action and briefly highlight it."""
        nonlocal selected
        if action in actions:
            selected = actions.index(action)
            draw_menu(f"-> {action}")
            time.sleep(0.1)
        return action

    # Initial draw - print blank lines first so draw_menu can clear them
    print()  # Title
    print()  # Hint
    print()  # Blank/status
    for _ in options:
        print()  # Options
    print()  # Trailing blank

    draw_menu()
    _hide_cursor()

    try:
        while True:
            # Check timeout
            remaining = get_remaining()
            if remaining is not None:
                if remaining <= 0:
                    print(f"{Colors.WARNING}⏰ Time's up! The DM moves you {auto_action}...{Colors.RESET}")
                    return auto_action
                elif remaining <= 30:
                    draw_menu(f"[{int(remaining)}s remaining]")

            # Wait for input with short timeout for responsiveness
            ch = _getch(timeout=1.0)
            if ch is None:
                continue  # Check timeout again

            # Arrow keys: MENU NAVIGATION
            if ch == '\x1b[A':  # Up arrow = menu up
                selected = (selected - 1) % num_options
                draw_menu()
            elif ch == '\x1b[B':  # Down arrow = menu down
                selected = (selected + 1) % num_options
                draw_menu()
            elif ch == '\x1b[D':  # Left arrow = back/system menu
                return select_action('system')
            elif ch == '\x1b[C':  # Right arrow = select current
                return actions[selected]

            # hjkl: MOVEMENT (h=West, j=South, k=North, l=East)
            elif ch == 'h' or ch == 'H':  # h = West
                if 'west' in directions_available:
                    return select_action('west')
                else:
                    draw_menu("(no exit west)")
            elif ch == 'j' or ch == 'J':  # j = South
                if 'south' in directions_available:
                    return select_action('south')
                else:
                    draw_menu("(no exit south)")
            elif ch == 'k' or ch == 'K':  # k = North
                if 'north' in directions_available:
                    return select_action('north')
                else:
                    draw_menu("(no exit north)")
            elif ch == 'l' or ch == 'L':  # l = East
                if 'east' in directions_available:
                    return select_action('east')
                else:
                    draw_menu("(no exit east)")

            # ESC or Tab = System menu (up level)
            elif ch == '\x1b' or ch == '\t':
                return select_action('system')

            # Enter/Space to select current option
            elif ch == '\r' or ch == '\n' or ch == ' ':
                return actions[selected]

            # Number keys for direct menu selection
            elif ch.isdigit():
                num = int(ch)
                if 1 <= num <= num_options:
                    return select_action(actions[num - 1])

            # Shortcut keys for menu items
            elif ch == '/':  # Search
                return select_action('search')
            elif ch == 'r' or ch == 'R':  # Rest
                return select_action('rest')
            elif ch == 'p' or ch == 'P':  # Party status
                return select_action('status')
            elif ch == 'm' or ch == 'M':  # Map
                return select_action('map')
            elif ch == 'c' or ch == 'C':  # Collect
                if 'collect' in actions:
                    return select_action('collect')
            elif ch == 't' or ch == 'T':  # Talk menu
                return select_action('talk')
            elif ch == 'o' or ch == 'O':  # Options/System menu
                return select_action('system')
            elif ch == 'q' or ch == 'Q':  # Quit to system
                return select_action('system')

            # WASD as alternative movement
            elif ch == 'w' or ch == 'W':
                if 'north' in directions_available:
                    return select_action('north')
            elif ch == 's' or ch == 'S':
                if 'south' in directions_available:
                    return select_action('south')
            elif ch == 'a' or ch == 'A':
                if 'west' in directions_available:
                    return select_action('west')
            elif ch == 'd' or ch == 'D':
                if 'east' in directions_available:
                    return select_action('east')

    except EOFError:
        return 'system'
    except KeyboardInterrupt:
        raise
    finally:
        _show_cursor()


def show_system_menu() -> str:
    """Show the system menu (scoreboard, save, pause, quit)."""
    options = [
        "📈 Scoreboard",
        "🏆 Hall of Fame",
        "📚 How to Play",
        "⚙  Settings",
        "💾 Save Game",
        "⏸  Pause Game",
        "🚪 Quit to Menu",
    ]
    actions = ['scoreboard', 'hall_of_fame', 'help', 'settings', 'save', 'pause', 'quit']

    choice = get_menu_choice(options, "System Menu", allow_back=True)
    if choice == 0:
        return 'back'
    return actions[choice - 1]


def handle_system_action(engine: GameEngine, action: str) -> None:
    """Handle system menu actions."""
    global _session

    if action == 'scoreboard':
        print("\n" + _session.scoreboard.display_scoreboard())
        if not _session.scoreboard.character_stats:
            _print_seeded_hall_of_famers(limit=10)
        get_input("\nPress Enter to continue...", default="")
    elif action == 'hall_of_fame':
        _show_hall_of_fame()
    elif action == 'help':
        _show_help_menu()
    elif action == 'settings':
        handle_settings_menu(engine)

    elif action == 'save':
        if engine.save_game():
            print(f"{Colors.SUCCESS}Game saved!{Colors.RESET}")
            _session.mark_saved()
        else:
            print(f"{Colors.DANGER}Failed to save game.{Colors.RESET}")

    elif action == 'pause':
        handle_pause(engine)

    elif action == 'quit':
        if _config.get('auto_save', True):
            engine.save_game()
            _session.mark_saved()
        _session.end_session()
        engine.state = GameState.MAIN_MENU

    # 'back' just returns to game


def handle_exploration(engine: GameEngine) -> None:
    """Handle exploration mode with two-level menu system."""
    global _session

    # Set up status panel on first call
    if not hasattr(handle_exploration, '_panel_setup'):
        setup_status_panel()
        handle_exploration._panel_setup = True

    # Check for auto-save
    if _config['auto_save'] and _session.should_auto_save():
        if engine.save_game():
            status_message("[Auto-saved]")
            _session.mark_saved()

    print_separator()

    # Show session playtime in header
    playtime = _session.scoreboard.get_playtime()
    print(f"{Colors.MUTED}⏱ {playtime}{Colors.RESET}")

    # Show current location
    if engine.dm.dungeon:
        room = engine.dm.dungeon.current_room
        if room:
            print(f"\n{Colors.SUBTITLE}Location: {room.name}{Colors.RESET}")

    # Show compact party status bar
    print(f"\n{_session.scoreboard.display_party_status()}")

    # Context-weighted gameplay tip cadence (iOS-style hinting).
    _runtime_state["explore_steps"] += 1
    if _runtime_state["explore_steps"] % 4 == 0:
        tip_context = "exploration"
        if any(c.current_hp < (c.max_hp * 0.4) for c in engine.party):
            tip_context = "low_health"
        tip = _context_weighted_tip(tip_context)
        if tip:
            status_message(f"Tip: {tip}")

    # Get available movement directions
    available_actions = engine.get_available_actions()
    directions_available = [a for a in available_actions if a in ['north', 'south', 'east', 'west']]

    # Show available directions
    if directions_available:
        dir_display = ', '.join([d.upper()[0] for d in directions_available])
        print(f"\n{Colors.INFO}Exits: {dir_display}{Colors.RESET}")

    # Use the game menu
    room = engine.dm.dungeon.current_room if (engine.dm and engine.dm.dungeon) else None
    room_lit = bool(room.lit) if room else True
    room_id = room.id if room else None
    has_npc = _ensure_room_npc(engine) is not None
    action = show_game_menu(
        directions_available,
        'collect' in available_actions,
        can_talk_npc=has_npc,
        room_lit=room_lit,
        room_id=room_id,
    )

    # Handle action
    if action in ['north', 'south', 'east', 'west']:
        if action in directions_available:
            direction_map = {
                'north': Direction.NORTH,
                'south': Direction.SOUTH,
                'east': Direction.EAST,
                'west': Direction.WEST,
            }
            result = engine.explore(direction_map[action])

            # Use AI DM for enhanced room narration
            from .game.ai_dm import get_ai_dm
            ai_dm = get_ai_dm()
            if engine.dm.dungeon and engine.dm.dungeon.current_room:
                room = engine.dm.dungeon.current_room
                ai_dm.update_context(
                    dungeon_name=engine.dm.dungeon.name,
                    current_room=room.name,
                    room_description=room.description,
                    party_members=[c.name for c in engine.party],
                )
                # Get AI-enhanced description
                # Convert features to strings (they may be enum objects)
                features = []
                if hasattr(room, 'features'):
                    for f in room.features:
                        features.append(f.value if hasattr(f, 'value') else str(f))
                narration = ai_dm.describe_room(
                    room.name,
                    room.room_type.value if hasattr(room.room_type, 'value') else str(room.room_type),
                    features
                )
                status_message(narration)
                ai_dm.add_event(f"Entered {room.name}")
                npc = _ensure_room_npc(engine)
                if npc:
                    status_message(f"You spot {npc.name} here. You can talk to NPC.")

            status_message(result)
            _session.scoreboard.record_room_explored()
            if _config.get("auto_show_map", True) and engine.dm.dungeon:
                print()
                print(render_dungeon_map(engine.dm.dungeon, radius=_config.get("map_radius", 3)))
        else:
            if room_id is not None:
                _runtime_state.setdefault("blocked_door_attempts", set()).add((room_id, action))
            status_message("You can't go that way.")

    elif action == 'search':
        result = engine.search_room()
        status_message(result)

    elif action == 'rest':
        rest_type = get_menu_choice(
            ["Short Rest (1 hour)", "Long Rest (8 hours)"],
            "Choose rest type:",
            allow_back=True
        )
        if rest_type == 0:  # Back
            return
        if not _play_rest_pause(is_long_rest=(rest_type == 2)):
            _session.end_session()
            engine.state = GameState.MAIN_MENU
            status_message("Rest interrupted. Returning to main menu.")
            return
        result = engine.rest(is_long_rest=(rest_type == 2))
        status_message(result)

    elif action == 'status':
        # Show ASCII art party view
        print("\n" + render_party(engine.party))
        print()
        # Also offer detailed view
        if confirm("Show detailed character sheets?"):
            for char in engine.party:
                print(char.display_sheet())
                print()

    elif action == 'map':
        if engine.dm.dungeon:
            # Show the map in a stable view; keep it on screen until acknowledged.
            map_text = render_dungeon_map(
                engine.dm.dungeon,
                radius=_config.get("map_radius", 3),
            )
            print()
            paged_print(map_text)
            get_input("\nPress Enter to continue...", default="")
        else:
            status_message("No map is available right now.")

    elif action == 'collect':
        if 'collect' in available_actions:
            result = engine.collect_treasure()
            status_message(result)
        else:
            status_message("Nothing to collect here.")

    elif action == 'talk':
        handle_talk_menu(engine)

    elif action == 'npc':
        # Legacy compatibility route.
        handle_talk_menu(engine)

    elif action == 'system':
        # Open system menu
        system_action = show_system_menu()
        handle_system_action(engine, system_action)


def handle_talk_to_dm(engine: GameEngine, initial_message: Optional[str] = None) -> None:
    """Handle free text input to the AI DM."""
    from .game.ai_dm import get_ai_dm

    ai_dm = get_ai_dm()

    # Update AI DM context with current game state
    if engine.dm.dungeon:
        room = engine.dm.dungeon.current_room
        ai_dm.update_context(
            dungeon_name=engine.dm.dungeon.name,
            current_room=room.name if room else "",
            room_description=room.description if room else "",
            party_members=[c.name for c in engine.party],
            party_status=_session.scoreboard.display_party_status(),
            combat_active=(engine.state == GameState.IN_COMBAT),
        )

    print(f"\n{Colors.SUBTITLE}Talk to the DM{Colors.RESET}")
    print(f"{Colors.MUTED}(Type your message, or press Enter to go back){Colors.RESET}")
    print()

    player_input = initial_message if initial_message is not None else get_input("You say: ", default="")
    if not player_input.strip():
        return

    lowered = " ".join(player_input.lower().split())

    # Allow voice-like commands to open exit/system menu regardless of AI backend.
    exit_triggers = {
        "exit", "quit", "quite", "leave", "leave game", "exit game",
        "menu", "system menu", "exit menu", "quit menu", "options",
        "go to menu", "go to exit menu", "open menu", "open exit menu",
        "back to menu", "return to menu",
    }
    if lowered in exit_triggers:
        status_message("Opening system menu...")
        system_action = show_system_menu()
        handle_system_action(engine, system_action)
        return

    # FAQ grounding first for practical gameplay questions.
    faq_matches = _find_relevant_faq(player_input, limit=1)
    if faq_matches:
        faq = faq_matches[0]
        status_message(f"DM (FAQ): {faq['answer']}")
        ai_dm.add_event(f"FAQ used: {faq['question']}")
        return

    # Explicit tip query.
    if "tip" in lowered or "hint" in lowered:
        context = "combat" if engine.state == GameState.IN_COMBAT else "exploration"
        tip = _context_weighted_tip(context) or engine.dm.get_dm_tip(context)
        status_message(f"DM Tip: {tip}")
        return

    # Get response from AI DM
    response = ai_dm.respond_to_player(player_input)

    # Display DM response in status panel
    status_message(f"DM: {response}")

    # Log the interaction
    ai_dm.add_event(f"Player said: {player_input[:50]}...")


def _match_mention_target(engine: GameEngine, mention: str):
    """Resolve @mention to dm, npc, or companion target."""
    token = mention.strip().lower()
    if token in {"dm", "dungeonmaster", "dungeon-master"}:
        return ("dm", None)

    npc = _ensure_room_npc(engine)
    if npc:
        npc_key = "".join(ch for ch in npc.name.lower() if ch.isalnum())
        if token == npc_key or npc_key.startswith(token) or token.startswith(npc_key):
            return ("npc", npc)

    for companion in engine.party:
        name_key = "".join(ch for ch in companion.name.lower() if ch.isalnum())
        if token == name_key or name_key.startswith(token) or token.startswith(name_key):
            return ("companion", companion)

    return (None, None)


def _parse_talk_input(engine: GameEngine, raw_input: str, default_target: str, default_obj=None):
    """Parse free text and optional @mention rerouting."""
    text = raw_input.strip()
    if not text:
        return (None, None, "")
    if not text.startswith("@"):
        return (default_target, default_obj, text)

    first, *rest = text.split(maxsplit=1)
    mention = first[1:] if len(first) > 1 else ""
    routed_target, routed_obj = _match_mention_target(engine, mention)
    payload = rest[0].strip() if rest else ""
    if routed_target:
        return (routed_target, routed_obj, payload)
    return (default_target, default_obj, text)


def handle_talk_to_npc(engine: GameEngine, npc: Optional[NPC] = None) -> None:
    """Free text chat with current room NPC."""
    npc = npc or _ensure_room_npc(engine)
    if not npc:
        status_message("No NPC is available to talk right now.")
        return

    print(f"\n{Colors.SUBTITLE}Talk to NPC: {npc.name}{Colors.RESET}")
    print(f"{Colors.MUTED}(Try @dm hey, or @<companion-name> hello){Colors.RESET}")
    message = get_input("You say: ", default="").strip()
    if not message:
        return

    target, obj, payload = _parse_talk_input(engine, message, default_target="npc", default_obj=npc)
    if target == "dm":
        return handle_talk_to_dm(engine, initial_message=payload)
    if target == "companion":
        return handle_talk_to_companions(engine, initial_message=payload, focus_companion=obj)
    if not payload:
        return

    from .game.ai_dm import get_ai_dm
    ai_dm = get_ai_dm()
    room = engine.dm.dungeon.current_room if engine.dm and engine.dm.dungeon else None
    if room:
        ai_dm.update_context(
            dungeon_name=engine.dm.dungeon.name,
            current_room=room.name,
            room_description=room.description,
            party_members=[c.name for c in engine.party],
        )
    npc_reply = ai_dm.respond_to_player(
        f"In character as NPC {npc.name}, reply briefly and helpfully to: {payload}"
    )
    status_message(f"{npc.name}: {npc_reply}")


def handle_talk_to_companions(engine: GameEngine, initial_message: Optional[str] = None, focus_companion=None) -> None:
    """Free text chat with party companions."""
    if not engine.party:
        status_message("No companions are available.")
        return

    print(f"\n{Colors.SUBTITLE}Talk to Companions{Colors.RESET}")
    print(f"{Colors.MUTED}(Try @dm hey, or @eof if companion name is eof){Colors.RESET}")
    message = initial_message if initial_message is not None else get_input("You say: ", default="")
    message = (message or "").strip()
    if not message:
        return

    target, obj, payload = _parse_talk_input(engine, message, default_target="companion", default_obj=focus_companion)
    if target == "dm":
        return handle_talk_to_dm(engine, initial_message=payload)
    if target == "npc":
        return handle_talk_to_npc(engine, npc=obj)
    if not payload:
        return

    companions = [c for c in engine.party if not focus_companion or c.name == focus_companion.name]
    speaker = random.choice(companions) if companions else random.choice(engine.party)

    from .game.ai_dm import get_ai_dm
    ai_dm = get_ai_dm()
    companion_reply = ai_dm.respond_to_player(
        f"In character as companion {speaker.name}, respond briefly to teammate message: {payload}"
    )
    status_message(f"{speaker.name}: {companion_reply}")


def handle_talk_menu(engine: GameEngine) -> None:
    """Unified talk menu with DM/NPC/companions and free text routing."""
    npc = _ensure_room_npc(engine)
    options = ["Dungeon Master", "Companions"]
    actions = ["dm", "companions"]
    if npc:
        options.insert(1, f"NPC ({npc.name})")
        actions.insert(1, "npc")

    print(f"{Colors.MUTED}Tip: Use @dm hey or @name hello (e.g. @eof hi).{Colors.RESET}")
    choice = get_menu_choice(options, "Talk Menu", allow_back=True)
    if choice == 0:
        return
    action = actions[choice - 1]
    if action == "dm":
        handle_talk_to_dm(engine)
    elif action == "npc":
        handle_talk_to_npc(engine, npc=npc)
    else:
        handle_talk_to_companions(engine)


def handle_pause(engine: GameEngine) -> None:
    """Handle pause menu."""
    global _session

    print(_session.pause())

    while True:
        choice = _session.get_pause_menu_choice()

        if choice == 'r':  # Resume
            _session.resume()
            print(f"{Colors.SUCCESS}Game resumed!{Colors.RESET}")
            break

        elif choice == 's':  # Save and quit
            if engine.save_game():
                print(f"{Colors.SUCCESS}Game saved!{Colors.RESET}")
                _session.mark_saved()
            engine.state = GameState.MAIN_MENU
            _session.resume()
            break

        elif choice == 'q':  # Quit without saving
            engine.state = GameState.MAIN_MENU
            _session.resume()
            break

        elif choice == 'b':  # View scoreboard
            print("\n" + _session.scoreboard.display_scoreboard())
            print(_session.pause())  # Show pause menu again


def handle_combat(engine: GameEngine) -> None:
    """Handle combat mode."""
    if not engine.current_combat:
        engine.state = GameState.EXPLORING
        return

    combat = engine.current_combat

    # Display ASCII combat scene
    enemies = [c for c in combat.combatants.values() if not c.is_player and c.is_conscious]
    print(render_combat_scene(engine.party, enemies))

    # Use AI DM for combat narration (only on first turn)
    if combat.current_round == 1 and combat.current_turn_index == 0:
        from .game.ai_dm import get_ai_dm
        ai_dm = get_ai_dm()
        enemy_names = [e.name for e in enemies]
        if enemy_names:
            ai_dm.update_context(
                combat_active=True,
                enemies=enemy_names,
                party_members=[c.name for c in engine.party],
            )
            combat_intro = ai_dm.describe_combat_start(enemy_names)
            print(f"\n{Colors.DANGER}{combat_intro}{Colors.RESET}\n")
            ai_dm.add_event(f"Combat started with {', '.join(enemy_names)}")

    # Display combat status
    print(combat.display_status())

    # Get current combatant
    combatant = combat.get_current_combatant()
    if not combatant:
        # Combat ended
        engine.state = GameState.EXPLORING
        return

    if not combatant.is_conscious:
        # Handle death saves for unconscious players
        if combatant.is_player:
            print(f"\n{combatant.name} is unconscious and must make a death saving throw.")
            input("Press Enter to roll...")
            result = combat.death_save(combatant.entity_id)
            print(result.description)
            combat.next_turn()
            return
        else:
            combat.next_turn()
            return

    if combatant.is_player:
        # Human turn
        player = engine.players.get(combatant.entity_id)
        if player:
            action_info = player.get_combat_action(combat, combatant)
            result = engine.execute_player_action(
                action_info.get('action', 'end_turn'),
                action_info.get('target_id'),
                **{k: v for k, v in action_info.items() if k not in ['action', 'target_id']}
            )
            print(result)
    else:
        # Monster turn (handled by engine)
        print(f"\n{combatant.name}'s turn...")
        result = engine.process_combat_turn()
        print(result)

    # Check for combat end
    if combat.state in [combat.state.VICTORY, combat.state.DEFEAT]:
        if combat.state == combat.state.VICTORY:
            result = engine._handle_combat_victory()
        else:
            result = engine._handle_combat_defeat()
        print(result)

    input("\nPress Enter to continue...")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nGame interrupted. Goodbye!")
        sys.exit(0)
