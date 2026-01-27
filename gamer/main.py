#!/usr/bin/env python3
"""
D&D 5e Text-Based RPG
Main entry point for the game.
"""

import sys
import argparse
from typing import List, Optional

from .game.engine import GameEngine, GameState
from .game.session import list_sessions, load_session, session_exists
from .characters.character import Character
from .characters.races import get_all_races, get_race
from .characters.classes import get_all_classes, get_class
from .characters.abilities import Ability
from .players.human_player import HumanPlayer
from .players.ai_player import AIPlayer, AIPersonality
from .world.dungeon import Direction
from .utils.display import (
    print_title, print_subtitle, print_menu, get_input, get_menu_choice,
    confirm, print_separator, Colors, clear_screen,
    set_terminal_theme, reset_terminal, show_splash_screen
)
from .utils.dice import roll_ability_scores, standard_array
from .utils.ascii_art import (
    render_character, render_party, render_dungeon_map, render_combat_scene,
    render_monster, render_encounter
)
from .game.multiplayer import (
    SharedFileMultiplayer, SocketMultiplayer, get_local_ip, PlayerRole
)
from .game.scoreboard import Scoreboard, SessionManager, TimeoutManager

# Global multiplayer instance
_multiplayer = None

# Global session manager
_session = SessionManager()

# Global config for defaults
_config = {
    'use_defaults': True,   # Allow pressing Enter to use defaults
    'use_theme': True,      # Use green-on-black terminal theme
    'show_splash': True,    # Show splash screen
    'timeout': 120,         # Seconds before DM takes over (0 to disable)
    'auto_save': True,      # Auto-save periodically
    'ai_backend': 'local',  # AI DM backend: 'local', 'anthropic', 'openai'
}


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

    return parser.parse_args()


def main():
    """Main game loop."""
    global _config, _session

    # Parse command line arguments
    args = parse_args()

    # Apply config from args
    _config['use_defaults'] = not args.no_defaults
    _config['use_theme'] = not args.no_theme and not args.quick
    _config['show_splash'] = not args.no_splash and not args.quick
    _config['timeout'] = 0 if args.no_timeout else args.timeout
    _config['auto_save'] = not args.no_autosave
    _config['ai_backend'] = args.ai

    # Initialize AI DM
    from .game.ai_dm import get_ai_dm
    ai_dm = get_ai_dm(_config['ai_backend'])

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

        while True:
            if engine.state == GameState.MAIN_MENU:
                handle_main_menu(engine)

            elif engine.state == GameState.PARTY_SETUP:
                handle_party_setup(engine)

            elif engine.state == GameState.EXPLORING:
                handle_exploration(engine)

            elif engine.state == GameState.IN_COMBAT:
                handle_combat(engine)

            elif engine.state == GameState.GAME_OVER:
                print_title("GAME OVER")
                print("Your adventure has come to an end.")
                if confirm("Return to main menu?"):
                    engine.state = GameState.MAIN_MENU
                else:
                    break

            elif engine.state == GameState.VICTORY:
                print_title("VICTORY!")
                print("You have conquered the dungeon!")
                print(engine.get_game_summary())
                if confirm("Return to main menu?"):
                    engine.state = GameState.MAIN_MENU
                else:
                    break

    finally:
        # Reset terminal colors on exit
        if _config['use_theme']:
            reset_terminal()


def handle_main_menu(engine: GameEngine) -> None:
    """Handle main menu interactions."""
    global _multiplayer

    options = ["New Game", "Load Game", "Multiplayer", "Quit"]
    choice = get_menu_choice(options, "Main Menu")

    if choice == 1:  # New Game
        session_name = get_input("Enter a name for your adventure: ", default="Adventure")
        if session_exists(session_name):
            if not confirm(f"A save named '{session_name}' exists. Overwrite?"):
                return
        engine.new_game(session_name)

    elif choice == 2:  # Load Game
        sessions = list_sessions()
        if not sessions:
            print(f"{Colors.WARNING}No saved games found.{Colors.RESET}")
            return

        print_subtitle("Saved Games")
        session_names = [f"{s['name']} (Last played: {s['last_played'][:10]})" for s in sessions]

        load_choice = get_menu_choice(session_names, "Select a save to load:", allow_back=True)
        if load_choice == 0:  # Back
            return
        if load_choice <= len(sessions):
            session = load_session(sessions[load_choice - 1]['name'])
            if session:
                engine.load_game(session)
                print(f"{Colors.SUCCESS}Game loaded!{Colors.RESET}")
            else:
                print(f"{Colors.DANGER}Failed to load game.{Colors.RESET}")

    elif choice == 3:  # Multiplayer
        handle_multiplayer_menu(engine)

    elif choice == 4:  # Quit
        if _multiplayer:
            _multiplayer.leave_game() if hasattr(_multiplayer, 'leave_game') else _multiplayer.close()
        if confirm("Are you sure you want to quit?"):
            print("Thanks for playing!")
            sys.exit(0)


def handle_multiplayer_menu(engine: GameEngine) -> None:
    """Handle multiplayer menu."""
    global _multiplayer

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
            if character:
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
            if character:
                # Remote player controls via multiplayer
                ai_player = AIPlayer(character.name, AIPersonality.BALANCED)
                engine.add_character_to_party(character, ai_player)
                mp.assign_character(character.name)

    # Start adventure
    if engine.party:
        dungeon_name = get_input("\nName your dungeon: ", default="The Dark Depths")

        difficulty = get_menu_choice(
            ["Easy (Level 1)", "Medium (Level 2)", "Hard (Level 3)"],
            "Choose difficulty:"
        )

        description = engine.start_adventure(dungeon_name, difficulty)

        # Sync game state to all players
        mp.update_game_state({
            "dungeon_name": dungeon_name,
            "difficulty": difficulty,
            "party": [c.name for c in engine.party]
        })

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

    # Get number of party members
    print("How many adventurers in your party? (1-4)")
    while True:
        try:
            num_input = get_input("Number of party members: ", default="1")
            num_party = int(num_input)
            if 1 <= num_party <= 4:
                break
            print(f"{Colors.WARNING}Please enter a number between 1 and 4.{Colors.RESET}")
        except ValueError:
            print(f"{Colors.WARNING}Please enter a valid number.{Colors.RESET}")

    # Create each party member
    for i in range(num_party):
        print_subtitle(f"Character {i + 1} of {num_party}")

        # Human or AI?
        player_type = get_menu_choice(
            ["Human Player", "AI Player"],
            "Who will control this character?"
        )

        # Create character
        character = create_character_interactive()
        if not character:
            print(f"{Colors.DANGER}Character creation failed.{Colors.RESET}")
            continue

        # Create player controller
        if player_type == 1:
            player = HumanPlayer(character.name)
        else:
            personality_choice = get_menu_choice(
                ["Balanced", "Aggressive", "Defensive", "Supportive"],
                "Choose AI personality:"
            )
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

    # Start adventure
    if engine.party:
        print_subtitle("Adventure Awaits!")
        dungeon_name = get_input("Name your dungeon: ", default="The Dark Depths")

        difficulty = get_menu_choice(
            ["Easy (Level 1)", "Medium (Level 2)", "Hard (Level 3)"],
            "Choose difficulty:"
        )

        # Start session tracking
        _session.start_session(dungeon_name)

        description = engine.start_adventure(dungeon_name, difficulty)
        print(description)
    else:
        print(f"{Colors.DANGER}No characters created. Returning to menu.{Colors.RESET}")
        engine.state = GameState.MAIN_MENU


def create_character_interactive() -> Optional[Character]:
    """Interactive character creation."""
    # Get name
    name = get_input("Enter character name: ", default="Adventurer")

    # Choose race
    races = get_all_races()
    race_names = [r.get_full_name() for r in races]
    print_menu(race_names, "Choose your race:")
    race_choice = get_menu_choice(race_names, "Race:")
    race = races[race_choice - 1]

    # Choose class
    classes = get_all_classes()
    class_names = [c.name for c in classes]
    print_menu(class_names, "Choose your class:")
    class_choice = get_menu_choice(class_names, "Class:")
    char_class = classes[class_choice - 1]

    # Ability scores
    print_subtitle("Ability Scores")
    method = get_menu_choice(
        ["Standard Array (15, 14, 13, 12, 10, 8)", "Roll 4d6 drop lowest"],
        "Choose ability score method:"
    )

    if method == 1:
        scores = standard_array()
    else:
        scores = roll_ability_scores()
        print(f"You rolled: {scores}")

    # Assign scores
    abilities = ["Strength", "Dexterity", "Constitution", "Intelligence", "Wisdom", "Charisma"]
    assigned_scores = assign_ability_scores(scores, abilities, char_class)

    # Choose skills
    print_subtitle("Skill Proficiencies")
    available_skills = char_class.skill_choices
    num_skills = char_class.num_skill_choices
    print(f"Choose {num_skills} skills from: {', '.join(available_skills)}")

    chosen_skills = []
    remaining_skills = available_skills.copy()
    for i in range(num_skills):
        print_menu(remaining_skills, f"Skill {i + 1} of {num_skills}:")
        skill_choice = get_menu_choice(remaining_skills, "Choose skill:")
        skill = remaining_skills.pop(skill_choice - 1)
        chosen_skills.append(skill)

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
                         char_class) -> dict:
    """Let player assign ability scores with recommendations. Press Enter for auto-assign."""
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
    auto_assign = get_input("Auto-assign scores optimally? ", default="y").lower().startswith("y")

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

        # Show abilities with index
        for i, ability in enumerate(remaining_abilities, 1):
            rec = " (Recommended)" if ability.upper() == primary.upper() else ""
            print(f"  {i}. {ability}{rec}")

        # Default to first ability (or recommended if available)
        default_idx = 1
        for i, ab in enumerate(remaining_abilities, 1):
            if ab.upper() == primary.upper():
                default_idx = i
                break

        while True:
            try:
                choice_input = get_input("Choose ability: ", default=str(default_idx))
                ability_choice = int(choice_input)
                if 1 <= ability_choice <= len(remaining_abilities):
                    break
                print(f"{Colors.WARNING}Invalid choice.{Colors.RESET}")
            except ValueError:
                print(f"{Colors.WARNING}Please enter a number.{Colors.RESET}")

        ability = remaining_abilities.pop(ability_choice - 1)

        # Choose score - default to highest remaining
        print(f"Available scores: {remaining_scores}")
        default_score = str(remaining_scores[0])
        while True:
            try:
                score_input = get_input(f"Choose score for {ability}: ", default=default_score)
                score_choice = int(score_input)
                if score_choice in remaining_scores:
                    remaining_scores.remove(score_choice)
                    break
                print(f"{Colors.WARNING}That score is not available.{Colors.RESET}")
            except ValueError:
                print(f"{Colors.WARNING}Please enter a valid score.{Colors.RESET}")

        assigned[ability.lower()] = score_choice
        print(f"{ability}: {score_choice}")

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


def show_game_menu(directions_available: List[str], can_collect: bool) -> str:
    """
    Show the main game menu with arrow key support for movement.

    Returns the action to take.
    """
    from .utils.display import _getch, _is_tty, _hide_cursor, _show_cursor
    import random

    # Build game menu options
    options = []
    actions = []

    # Movement options (always show, but some may be unavailable)
    options.append(f"↑ North {'[N]' if 'north' in directions_available else '[-]'}")
    actions.append('north')
    options.append(f"↓ South {'[S]' if 'south' in directions_available else '[-]'}")
    actions.append('south')
    options.append(f"← West  {'[W]' if 'west' in directions_available else '[-]'}")
    actions.append('west')
    options.append(f"→ East  {'[E]' if 'east' in directions_available else '[-]'}")
    actions.append('east')

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

    # Talk to DM (free text input)
    options.append("💬 Talk to DM")
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
        return _game_menu_interactive(options, actions, directions_available, auto_action)
    else:
        # Fallback to regular menu with timeout
        timeout = _config.get('timeout', 0)
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
            elif ch == 't' or ch == 'T':  # Talk to DM
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

    except (EOFError, KeyboardInterrupt):
        return 'system'
    finally:
        _show_cursor()


def show_system_menu() -> str:
    """Show the system menu (scoreboard, save, pause, quit)."""
    options = [
        "📈 Scoreboard",
        "💾 Save Game",
        "⏸  Pause Game",
        "🚪 Quit to Menu",
    ]
    actions = ['scoreboard', 'save', 'pause', 'quit']

    choice = get_menu_choice(options, "System Menu", allow_back=True)
    if choice == 0:
        return 'back'
    return actions[choice - 1]


def handle_system_action(engine: GameEngine, action: str) -> None:
    """Handle system menu actions."""
    global _session

    if action == 'scoreboard':
        print("\n" + _session.scoreboard.display_scoreboard())
        get_input("\nPress Enter to continue...", default="")

    elif action == 'save':
        if engine.save_game():
            print(f"{Colors.SUCCESS}Game saved!{Colors.RESET}")
            _session.mark_saved()
        else:
            print(f"{Colors.DANGER}Failed to save game.{Colors.RESET}")

    elif action == 'pause':
        handle_pause(engine)

    elif action == 'quit':
        if confirm("Save before quitting?"):
            engine.save_game()
            _session.mark_saved()
        _session.end_session()
        engine.state = GameState.MAIN_MENU

    # 'back' just returns to game


def handle_exploration(engine: GameEngine) -> None:
    """Handle exploration mode with two-level menu system."""
    global _session

    # Check for auto-save
    if _config['auto_save'] and _session.should_auto_save():
        if engine.save_game():
            print(f"{Colors.MUTED}[Auto-saved]{Colors.RESET}")
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

    # Get available movement directions
    available_actions = engine.get_available_actions()
    directions_available = [a for a in available_actions if a in ['north', 'south', 'east', 'west']]

    # Show available directions
    if directions_available:
        dir_display = ', '.join([d.upper()[0] for d in directions_available])
        print(f"\n{Colors.INFO}Exits: {dir_display}{Colors.RESET}")

    # Use the game menu
    action = show_game_menu(directions_available, 'collect' in available_actions)

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
                print(f"\n{Colors.INFO}{narration}{Colors.RESET}")
                ai_dm.add_event(f"Entered {room.name}")

            print(result)
            _session.scoreboard.record_room_explored()
        else:
            print(f"{Colors.WARNING}You can't go that way.{Colors.RESET}")

    elif action == 'search':
        result = engine.search_room()
        print(result)

    elif action == 'rest':
        rest_type = get_menu_choice(
            ["Short Rest (1 hour)", "Long Rest (8 hours)"],
            "Choose rest type:",
            allow_back=True
        )
        if rest_type == 0:  # Back
            return
        result = engine.rest(is_long_rest=(rest_type == 2))
        print(result)

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
            # Use enhanced ASCII map
            print("\n" + render_dungeon_map(engine.dm.dungeon))

    elif action == 'collect':
        if 'collect' in available_actions:
            result = engine.collect_treasure()
            print(result)
        else:
            print(f"{Colors.WARNING}Nothing to collect here.{Colors.RESET}")

    elif action == 'talk':
        # Free text input to AI DM
        handle_talk_to_dm(engine)

    elif action == 'system':
        # Open system menu
        system_action = show_system_menu()
        handle_system_action(engine, system_action)


def handle_talk_to_dm(engine: GameEngine) -> None:
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

    player_input = get_input("You say: ", default="")
    if not player_input.strip():
        return

    # Get response from AI DM
    response = ai_dm.respond_to_player(player_input)

    # Display DM response with styling
    print(f"\n{Colors.INFO}DM:{Colors.RESET} {response}")
    print()

    # Log the interaction
    ai_dm.add_event(f"Player said: {player_input[:50]}...")

    get_input("Press Enter to continue...", default="")


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
            if confirm("Are you sure you want to quit without saving?"):
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
    enemies = [c for c in combat.combatants if not c.is_player and c.is_conscious]
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
