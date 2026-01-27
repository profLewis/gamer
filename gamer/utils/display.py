"""Display utilities for text formatting and output."""

import sys
import os
from typing import List, Dict, Any, Optional

# ANSI escape codes for terminal control
ANSI_BLACK_BG = '\033[40m'      # Black background
ANSI_GREEN_FG = '\033[32m'      # Green text
ANSI_BRIGHT_GREEN = '\033[92m'  # Bright green
ANSI_RESET = '\033[0m'          # Reset all
ANSI_CLEAR = '\033[2J\033[H'    # Clear screen
ANSI_BOLD = '\033[1m'           # Bold

# Try to import colorama for cross-platform colored output
try:
    from colorama import Fore, Back, Style, init
    init(autoreset=False)  # We'll manage reset ourselves for the theme
    HAS_COLOR = True
except ImportError:
    HAS_COLOR = False
    # Create dummy color constants
    class DummyColor:
        def __getattr__(self, name):
            return ''
    Fore = DummyColor()
    Back = DummyColor()
    Style = DummyColor()


def set_terminal_theme():
    """Set terminal to black background with green text."""
    if sys.platform == 'win32':
        # Windows: use colorama or ANSI codes
        if HAS_COLOR:
            print(Back.BLACK + Fore.GREEN, end='')
        else:
            print(ANSI_BLACK_BG + ANSI_GREEN_FG, end='')
    else:
        # Unix-like: use ANSI escape codes
        print(ANSI_BLACK_BG + ANSI_GREEN_FG, end='')

    # Clear screen with new colors
    clear_screen()


def reset_terminal():
    """Reset terminal to default colors."""
    print(ANSI_RESET, end='')
    if HAS_COLOR:
        print(Style.RESET_ALL, end='')


# Color shortcuts - Green theme on black background
class Colors:
    """Color constants for display - Matrix/retro terminal style."""
    # Use bright green as primary, with accents
    TITLE = ANSI_BRIGHT_GREEN + ANSI_BOLD if not HAS_COLOR else Fore.LIGHTGREEN_EX + Style.BRIGHT
    SUBTITLE = ANSI_GREEN_FG if not HAS_COLOR else Fore.GREEN
    SUCCESS = ANSI_BRIGHT_GREEN if not HAS_COLOR else Fore.LIGHTGREEN_EX
    DANGER = '\033[91m' if not HAS_COLOR else Fore.LIGHTRED_EX  # Bright red for danger
    WARNING = '\033[93m' if not HAS_COLOR else Fore.LIGHTYELLOW_EX  # Yellow for warnings
    INFO = ANSI_GREEN_FG if not HAS_COLOR else Fore.GREEN
    MUTED = '\033[90m' if not HAS_COLOR else Fore.LIGHTBLACK_EX  # Dim gray
    RESET = ANSI_GREEN_FG if not HAS_COLOR else Fore.GREEN  # Reset to green, not white
    BOLD = ANSI_BOLD if not HAS_COLOR else Style.BRIGHT
    RESET_ALL = ANSI_RESET if not HAS_COLOR else Style.RESET_ALL

    # Character-specific
    PLAYER = ANSI_BRIGHT_GREEN if not HAS_COLOR else Fore.LIGHTGREEN_EX + Style.BRIGHT
    ENEMY = '\033[91m' if not HAS_COLOR else Fore.LIGHTRED_EX + Style.BRIGHT
    NPC = '\033[96m' if not HAS_COLOR else Fore.LIGHTCYAN_EX

    # Damage types
    DAMAGE = '\033[91m' if not HAS_COLOR else Fore.LIGHTRED_EX
    HEALING = ANSI_BRIGHT_GREEN if not HAS_COLOR else Fore.LIGHTGREEN_EX
    MAGIC = '\033[95m' if not HAS_COLOR else Fore.LIGHTMAGENTA_EX


# D&D Splash Screen ASCII Art
SPLASH_SCREEN = r'''
{title}
                         ⚔️  DnD  ⚔️
                        5th Edition

                  .==.        .==.
                 //`^\\      //^`\\
                // ^ ^\(\__/)/^ ^^\\
               //^ ^^ ^/6  6\ ^^ ^ \\
              //^ ^^ ^/( .. )\^ ^ ^ \\
             // ^^ ^/\| v""v |/\^ ^ ^\\
            // ^^/\/ /  `~~`  \ \/\^ ^\\
           _____ /  /          \  \ _____
          | DnD |  / __    __   \  | DnD |
           -----     \_    _/      -----
                       \  /
                        \/

                ╔═════════════════════════════════╗
                ║     ██████╗ ███╗   ██╗██████╗   ║
                ║     ██╔══██╗████╗  ██║██╔══██╗  ║
                ║     ██║  ██║██╔██╗ ██║██║  ██║  ║
                ║     ██║  ██║██║╚██╗██║██║  ██║  ║
                ║     ██████╔╝██║ ╚████║██████╔╝  ║
                ║     ╚═════╝ ╚═╝  ╚═══╝╚═════╝   ║
                ║                                 ║
                ║      TEXT-BASED ADVENTURE       ║
                ╚═════════════════════════════════╝

                   By Lewis & Claude Code

                    Roll for initiative...
{reset}
'''

SPLASH_DRAGON = r'''
{title}
                                  __                  _
                                 / /\                /\ \
                                / /  \              /  \ \
                               / / /\ \            / /\ \ \
                  _           / / /\ \ \          / / /\ \ \
                 /\_\        / / /  \ \ \        / / /  \ \_\
                / / /  _    / / /___/ /\ \      / / /   / / /
               / / /  /\_\ / / /_____/ /\ \    / / /   / / /
              / / /__/ / // /_________/\ \ \  / / /___/ / /
             / / /____/ // / /_       __\ \_\/ / /____\/ /
             \/________/ \_\___\     /____/_/\/_________/

                            ,     \    /      ,
                           / \    )\__/(     / \
                          /   \  (_\  /_)   /   \
                     ____/_____\__\@  @/___/_____\____
                    |             |\../|              |
                    |              \VV/               |
                    |         ---- DnD ----          |
                    |_________________________________|
                     |    /\ /      \\       \ /\    |
                     |  /   V        ))       V   \  |
                     |/     `       //        '     \|
                     `              V                '

                ╔═════════════════════════════════════════╗
                ║         ██████╗ ███╗   ██╗██████╗       ║
                ║         ██╔══██╗████╗  ██║██╔══██╗      ║
                ║         ██║  ██║██╔██╗ ██║██║  ██║      ║
                ║         ██║  ██║██║╚██╗██║██║  ██║      ║
                ║         ██████╔╝██║ ╚████║██████╔╝      ║
                ║         ╚═════╝ ╚═╝  ╚═══╝╚═════╝       ║
                ║                                         ║
                ║           ⚔️  5th Edition  ⚔️            ║
                ╚═════════════════════════════════════════╝

                       By Lewis & Claude Code

                        Press ENTER to begin...
{reset}
'''

SPLASH_SIMPLE = r'''
{title}
    ╔══════════════════════════════════════════════════════════════╗
    ║                                                              ║
    ║              ██████╗ ███╗   ██╗██████╗                       ║
    ║              ██╔══██╗████╗  ██║██╔══██╗                      ║
    ║              ██║  ██║██╔██╗ ██║██║  ██║                      ║
    ║              ██║  ██║██║╚██╗██║██║  ██║                      ║
    ║              ██████╔╝██║ ╚████║██████╔╝                      ║
    ║              ╚═════╝ ╚═╝  ╚═══╝╚═════╝                       ║
    ║                                                              ║
    ║                    ━━━ 5th Edition ━━━                       ║
    ║                                                              ║
    ║                         <>=======()                          ║
    ║                        (/\___   /|\\                         ║
    ║                              \_/ | \\                        ║
    ║                                \_|  \\                       ║
    ║                                  \|\/|\_                     ║
    ║                                   (oo)\_                     ║
    ║                                  //_/\_\                     ║
    ║                                 @@/  |_\                     ║
    ║                                    \_\  \                    ║
    ║                                     \_|  \                   ║
    ║                                      \____\                  ║
    ║                                      _|| ||_                 ║
    ║                                     (___||___)               ║
    ║                                                              ║
    ║                    ┌───────────────────┐                     ║
    ║                    │  TEXT-BASED  RPG  │                     ║
    ║                    └───────────────────┘                     ║
    ║                                                              ║
    ║                   By Lewis & Claude Code                     ║
    ║                                                              ║
    ╚══════════════════════════════════════════════════════════════╝
{reset}
'''


def show_splash_screen(style: str = "dragon") -> None:
    """Display the D&D splash screen."""
    clear_screen()

    if style == "dragon":
        splash = SPLASH_DRAGON
    elif style == "simple":
        splash = SPLASH_SIMPLE
    else:
        splash = SPLASH_SCREEN

    # Format with colors
    formatted = splash.format(
        title=Colors.TITLE,
        reset=Colors.RESET
    )

    print(formatted)

    try:
        input()  # Wait for Enter
    except EOFError:
        pass  # Handle piped input


def print_title(text: str, char: str = '=') -> None:
    """Print a title with decorative borders."""
    border = char * (len(text) + 4)
    print(f"\n{Colors.TITLE}{border}")
    print(f"  {text}  ")
    print(f"{border}{Colors.RESET}\n")


def print_subtitle(text: str) -> None:
    """Print a subtitle."""
    print(f"\n{Colors.SUBTITLE}--- {text} ---{Colors.RESET}\n")


def print_separator(char: str = '-', width: int = 50) -> None:
    """Print a separator line."""
    print(f"{Colors.MUTED}{char * width}{Colors.RESET}")


def print_boxed(text: str, width: int = 50) -> None:
    """Print text in a box."""
    lines = text.split('\n')
    print(f"┌{'─' * (width - 2)}┐")
    for line in lines:
        padded = line.ljust(width - 4)
        print(f"│ {padded} │")
    print(f"└{'─' * (width - 2)}┘")


def print_table(headers: List[str], rows: List[List[Any]],
                col_widths: Optional[List[int]] = None) -> None:
    """Print a formatted table."""
    if not col_widths:
        col_widths = []
        for i, header in enumerate(headers):
            max_width = len(str(header))
            for row in rows:
                if i < len(row):
                    max_width = max(max_width, len(str(row[i])))
            col_widths.append(max_width + 2)

    # Header
    header_str = '│'
    for i, header in enumerate(headers):
        header_str += f" {str(header).center(col_widths[i] - 2)} │"

    border_top = '┌' + '┬'.join('─' * w for w in col_widths) + '┐'
    border_mid = '├' + '┼'.join('─' * w for w in col_widths) + '┤'
    border_bot = '└' + '┴'.join('─' * w for w in col_widths) + '┘'

    print(border_top)
    print(f"{Colors.BOLD}{header_str}{Colors.RESET}")
    print(border_mid)

    for row in rows:
        row_str = '│'
        for i, cell in enumerate(row):
            if i < len(col_widths):
                row_str += f" {str(cell).ljust(col_widths[i] - 2)} │"
        print(row_str)

    print(border_bot)


def print_stat_block(name: str, stats: Dict[str, Any]) -> None:
    """Print a D&D-style stat block."""
    print_separator('═', 40)
    print(f"{Colors.TITLE}{name.upper()}{Colors.RESET}")
    print_separator('─', 40)

    for key, value in stats.items():
        print(f"  {Colors.BOLD}{key}:{Colors.RESET} {value}")

    print_separator('═', 40)


def format_roll(total: int, rolls: List[int], modifier: int = 0,
                label: str = "") -> str:
    """Format a dice roll result for display."""
    roll_str = '+'.join(str(r) for r in rolls)
    mod_str = f"+{modifier}" if modifier > 0 else (f"{modifier}" if modifier < 0 else "")

    result = f"[{roll_str}]{mod_str} = {Colors.BOLD}{total}{Colors.RESET}"
    if label:
        result = f"{label}: {result}"
    return result


def format_hp(current: int, maximum: int) -> str:
    """Format HP with color based on percentage."""
    percentage = current / maximum if maximum > 0 else 0

    if percentage > 0.5:
        color = Colors.SUCCESS
    elif percentage > 0.25:
        color = Colors.WARNING
    else:
        color = Colors.DANGER

    return f"{color}{current}/{maximum}{Colors.RESET}"


def format_modifier(mod: int) -> str:
    """Format an ability modifier."""
    if mod >= 0:
        return f"+{mod}"
    return str(mod)


# -----------------------------------------------------------------------------
# Keyboard Input Handling (for arrow keys and hjkl navigation)
# -----------------------------------------------------------------------------

def _getch() -> str:
    """
    Read a single character from stdin without waiting for Enter.
    Works on Unix/macOS. Returns the character or escape sequence.
    """
    import termios
    import tty

    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        ch = sys.stdin.read(1)

        # Handle escape sequences (arrow keys)
        if ch == '\x1b':  # ESC
            # Read additional characters for arrow keys
            ch2 = sys.stdin.read(1)
            if ch2 == '[':
                ch3 = sys.stdin.read(1)
                # Arrow keys: A=up, B=down, C=right, D=left
                return f'\x1b[{ch3}'
            return ch + ch2
        return ch
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)


def _is_tty() -> bool:
    """Check if stdin is a terminal (not piped input)."""
    return sys.stdin.isatty()


def _move_cursor_up(lines: int = 1) -> None:
    """Move cursor up n lines."""
    print(f'\x1b[{lines}A', end='')


def _clear_line() -> None:
    """Clear the current line."""
    print('\x1b[2K\r', end='')


def _hide_cursor() -> None:
    """Hide the terminal cursor."""
    print('\x1b[?25l', end='', flush=True)


def _show_cursor() -> None:
    """Show the terminal cursor."""
    print('\x1b[?25h', end='', flush=True)


def print_menu(options: List[str], title: str = "Choose an option:",
               default: Optional[int] = None, show_default: bool = True) -> None:
    """Print a numbered menu with optional default highlighted."""
    print(f"\n{Colors.SUBTITLE}{title}{Colors.RESET}")
    for i, option in enumerate(options, 1):
        if default is not None and i == default and show_default:
            # Highlight default option
            print(f"  {Colors.BOLD}{i}.{Colors.RESET} {Colors.TITLE}{option} [default]{Colors.RESET}")
        else:
            print(f"  {Colors.BOLD}{i}.{Colors.RESET} {option}")
    print()


def _print_interactive_menu(options: List[str], title: str, selected: int) -> None:
    """Print menu with visual selection indicator."""
    print(f"\n{Colors.SUBTITLE}{title}{Colors.RESET}")
    print(f"{Colors.MUTED}  (Use arrows/hjkl to navigate, Enter to select){Colors.RESET}")
    print()
    for i, option in enumerate(options, 1):
        if i == selected:
            # Highlighted selection
            print(f"  {Colors.TITLE}> {i}. {option} <{Colors.RESET}")
        else:
            print(f"    {Colors.MUTED}{i}.{Colors.RESET} {option}")
    print()


def _redraw_interactive_menu(options: List[str], title: str, selected: int,
                              total_lines: int) -> None:
    """Redraw the menu in place by moving cursor up and reprinting."""
    # Move cursor up to the start of the menu
    _move_cursor_up(total_lines)

    # Reprint the menu
    _clear_line()
    print(f"{Colors.SUBTITLE}{title}{Colors.RESET}")
    _clear_line()
    print(f"{Colors.MUTED}  (Use arrows/hjkl to navigate, Enter to select){Colors.RESET}")
    _clear_line()
    print()

    for i, option in enumerate(options, 1):
        _clear_line()
        if i == selected:
            print(f"  {Colors.TITLE}> {i}. {option} <{Colors.RESET}")
        else:
            print(f"    {Colors.MUTED}{i}.{Colors.RESET} {option}")

    _clear_line()
    print()


def get_input(prompt: str = "> ", timeout: Optional[float] = None,
               default: Optional[str] = None) -> str:
    """Get input from user with colored prompt, optional timeout, and optional default."""
    # Build prompt with default indicator
    if default is not None:
        display_prompt = f"{prompt}[{default}] "
    else:
        display_prompt = prompt

    if timeout is not None:
        # Timeout input (Unix only)
        import select
        print(f"{Colors.INFO}{display_prompt}{Colors.RESET}", end='', flush=True)
        ready, _, _ = select.select([sys.stdin], [], [], timeout)
        if ready:
            result = sys.stdin.readline().rstrip('\n')
            return result if result else (default or "")
        else:
            return default or ""  # Timeout - return default

    try:
        result = input(f"{Colors.INFO}{display_prompt}{Colors.RESET}")
        return result if result else (default or "")
    except EOFError:
        return default or ""


def get_menu_choice(options: List[str], title: str = "Choose an option:",
                    default: Optional[int] = None, allow_default: bool = True,
                    timeout: Optional[float] = None) -> int:
    """
    Display menu and get valid choice.

    Supports:
    - Arrow keys (up/down) for navigation
    - hjkl vim-style keys (j=down, k=up)
    - Number keys for direct selection
    - Enter to confirm selection

    Args:
        options: List of menu options
        title: Menu title
        default: Default option (1-indexed). If set, pressing Enter selects it.
        allow_default: Whether to allow pressing Enter for default (global config)
        timeout: Optional timeout in seconds for input

    Returns:
        Selected option (1-indexed)
    """
    # Import config (may not be available during import)
    try:
        from ..main import _config
        use_defaults = _config.get('use_defaults', True) and allow_default
        use_arrow_keys = _config.get('use_arrow_keys', True)
    except (ImportError, KeyError):
        use_defaults = allow_default
        use_arrow_keys = True

    # If no default specified and defaults are enabled, use first option
    if default is None and use_defaults:
        default = 1

    # Check if we can use interactive mode (requires TTY)
    interactive = use_arrow_keys and _is_tty() and timeout is None

    if interactive:
        return _get_menu_choice_interactive(options, title, default or 1)
    else:
        return _get_menu_choice_fallback(options, title, default, use_defaults, timeout)


def _get_menu_choice_interactive(options: List[str], title: str, default: int) -> int:
    """Interactive menu selection with arrow keys and hjkl."""
    selected = default
    num_options = len(options)

    # Calculate total lines for redrawing (title + hint + blank + options + blank)
    total_lines = 3 + num_options + 1

    # Initial draw
    _print_interactive_menu(options, title, selected)
    _hide_cursor()

    try:
        while True:
            try:
                ch = _getch()

                # Arrow keys
                if ch == '\x1b[A' or ch == 'k':  # Up arrow or k
                    selected = selected - 1 if selected > 1 else num_options
                    _redraw_interactive_menu(options, title, selected, total_lines)

                elif ch == '\x1b[B' or ch == 'j':  # Down arrow or j
                    selected = selected + 1 if selected < num_options else 1
                    _redraw_interactive_menu(options, title, selected, total_lines)

                elif ch == '\x1b[C' or ch == 'l':  # Right arrow or l - same as Enter
                    return selected

                elif ch == '\x1b[D' or ch == 'h':  # Left arrow or h - go to first
                    selected = 1
                    _redraw_interactive_menu(options, title, selected, total_lines)

                elif ch == '\r' or ch == '\n' or ch == ' ':  # Enter or Space
                    return selected

                elif ch == 'q' or ch == '\x1b':  # q or ESC - select default/first
                    return default

                elif ch == 'g':  # g - go to first (vim style)
                    selected = 1
                    _redraw_interactive_menu(options, title, selected, total_lines)

                elif ch == 'G':  # G - go to last (vim style)
                    selected = num_options
                    _redraw_interactive_menu(options, title, selected, total_lines)

                elif ch.isdigit():  # Number key
                    num = int(ch)
                    if 1 <= num <= num_options:
                        return num
                    elif num == 0 and num_options >= 10:
                        # Allow 0 for option 10
                        return 10

            except (EOFError, KeyboardInterrupt):
                return default

    finally:
        _show_cursor()


def _get_menu_choice_fallback(options: List[str], title: str, default: Optional[int],
                               use_defaults: bool, timeout: Optional[float]) -> int:
    """Fallback menu selection for non-TTY or when interactive is disabled."""
    print_menu(options, title, default if use_defaults else None)

    prompt = "Enter choice"
    if default and use_defaults:
        prompt += f" [{default}]"
    prompt += ": "

    while True:
        try:
            user_input = get_input(prompt, timeout)

            # If empty and defaults allowed, use default
            if user_input.strip() == "":
                if default and use_defaults:
                    return default
                elif timeout is not None:
                    # Timeout occurred
                    return default if default else 1
                else:
                    print(f"{Colors.WARNING}Please enter a choice{Colors.RESET}")
                    continue

            choice = int(user_input)
            if 1 <= choice <= len(options):
                return choice
            print(f"{Colors.WARNING}Please enter a number between 1 and {len(options)}{Colors.RESET}")
        except ValueError:
            print(f"{Colors.WARNING}Please enter a valid number{Colors.RESET}")


def confirm(prompt: str = "Continue?", default: bool = True) -> bool:
    """Get yes/no confirmation. Default is yes."""
    default_str = "y" if default else "n"
    hint = "Y/n" if default else "y/N"
    response = get_input(f"{prompt} ({hint}): ", default=default_str).lower().strip()
    return response in ('y', 'yes', '')


def print_combat_action(actor: str, action: str, target: str = "",
                        result: str = "") -> None:
    """Print a formatted combat action."""
    msg = f"{Colors.BOLD}{actor}{Colors.RESET} {action}"
    if target:
        msg += f" {Colors.BOLD}{target}{Colors.RESET}"
    if result:
        msg += f" - {result}"
    print(msg)


def print_damage(amount: int, damage_type: str = "") -> str:
    """Format damage for display."""
    type_str = f" {damage_type}" if damage_type else ""
    return f"{Colors.DAMAGE}{amount}{type_str} damage{Colors.RESET}"


def print_healing(amount: int) -> str:
    """Format healing for display."""
    return f"{Colors.HEALING}{amount} HP healed{Colors.RESET}"


def clear_screen() -> None:
    """Clear the terminal screen."""
    print('\033[2J\033[H', end='')


def print_dm(text: str) -> None:
    """Print DM narration text."""
    print(f"\n{Colors.MUTED}*{Colors.RESET} {text}")


def print_dialogue(speaker: str, text: str) -> None:
    """Print NPC dialogue."""
    print(f"\n{Colors.NPC}{speaker}:{Colors.RESET} \"{text}\"")
