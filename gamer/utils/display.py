"""Display utilities for text formatting and output."""

import sys
import os
import shutil
from typing import List, Dict, Any, Optional, Tuple

# ANSI escape codes for terminal colors
# These work on macOS, Linux, and modern Windows terminals

# Terminal theme: Black background, green text (classic terminal look)
_BG = '\033[40m'      # Black background
_FG = '\033[32m'      # Green foreground
_BRIGHT = '\033[92m'  # Bright green
_BOLD = '\033[1m'
_DIM = '\033[2m'
_RESET_ALL = '\033[0m'


class Colors:
    """Color constants - black background with green text theme."""
    # Everything resets back to green on black, not default terminal colors
    RESET = f'{_BG}{_FG}'
    RESET_ALL = f'{_BG}{_FG}'

    # Text styles (all green-based)
    BOLD = f'{_BG}{_BRIGHT}{_BOLD}'
    DIM = f'{_BG}{_FG}{_DIM}'

    # Semantic colors - mostly green with minimal accents
    TITLE = f'{_BG}{_BRIGHT}{_BOLD}'    # Bright green bold
    SUBTITLE = f'{_BG}{_FG}'             # Normal green
    SUCCESS = f'{_BG}{_BRIGHT}'          # Bright green
    DANGER = f'{_BG}\033[91m'            # Red (for enemies/damage only)
    WARNING = f'{_BG}\033[93m'           # Yellow (sparingly)
    INFO = f'{_BG}{_FG}'                 # Green
    MUTED = f'{_BG}{_FG}{_DIM}'          # Dim green

    # Character colors - keep it green
    PLAYER = f'{_BG}{_BRIGHT}{_BOLD}'    # Bright green bold
    ENEMY = f'{_BG}\033[91m'             # Red
    NPC = f'{_BG}{_BRIGHT}'              # Bright green

    # Combat - green with red for damage
    DAMAGE = f'{_BG}\033[91m'            # Red
    HEALING = f'{_BG}{_BRIGHT}'          # Bright green
    MAGIC = f'{_BG}{_BRIGHT}'            # Bright green


def set_terminal_theme(clear: bool = True):
    """Set terminal to black background with green text."""
    print(f'{_BG}{_FG}', end='', flush=True)

    if clear:
        clear_screen(preserve_scrollback=True)


def reset_terminal():
    """Reset terminal to default colors."""
    print(_RESET_ALL, end='', flush=True)


# -----------------------------------------------------------------------------
# Terminal Size and Paging
# -----------------------------------------------------------------------------

def get_terminal_size() -> Tuple[int, int]:
    """Get terminal size (columns, rows). Returns (80, 24) as fallback."""
    try:
        size = shutil.get_terminal_size((80, 24))
        return (size.columns, size.lines)
    except Exception:
        return (80, 24)


def paged_print(text: str, page_size: int = 0) -> None:
    """
    Print text with paging support for long content.

    Args:
        text: Text to print (can be multiline)
        page_size: Lines per page. If 0, auto-detect from terminal.
    """
    lines = text.split('\n')

    if page_size <= 0:
        _, term_height = get_terminal_size()
        page_size = term_height - 3  # Leave room for prompt

    if len(lines) <= page_size:
        # Short enough, just print
        print(text)
        return

    # Page through content
    i = 0
    while i < len(lines):
        # Print a page
        page_end = min(i + page_size, len(lines))
        for line in lines[i:page_end]:
            print(line)

        i = page_end

        if i < len(lines):
            # More content - show prompt
            remaining = len(lines) - i
            try:
                prompt = f"{Colors.MUTED}-- More ({remaining} lines) [Enter=continue, q=quit] --{Colors.RESET}"
                response = input(prompt).strip().lower()
                if response == 'q':
                    break
            except (EOFError, KeyboardInterrupt):
                break


def fits_in_terminal(text: str, margin: int = 5) -> bool:
    """Check if text fits in current terminal without scrolling."""
    _, term_height = get_terminal_size()
    lines = text.count('\n') + 1
    return lines <= (term_height - margin)


# -----------------------------------------------------------------------------
# Status Panel - Fixed panel at bottom of screen for messages
# -----------------------------------------------------------------------------

class StatusPanel:
    """
    Manages a fixed status panel at the bottom of the terminal.

    The screen is split into:
    - Main area (top): scrollable game content
    - Status panel (bottom): fixed area for messages/status
    """

    PANEL_HEIGHT = 4  # Number of lines for status panel

    def __init__(self):
        self.enabled = False
        self.messages: List[str] = []
        self._main_area_height = 0

    def setup(self) -> None:
        """Set up the split screen with status panel at bottom."""
        cols, rows = get_terminal_size()
        self._main_area_height = rows - self.PANEL_HEIGHT - 1

        # Clear screen
        print('\033[2J', end='')

        # Set scrolling region to top portion (leave bottom for panel)
        # ESC[top;bottom r - set scroll region
        print(f'\033[1;{self._main_area_height}r', end='')

        # Move cursor to top
        print('\033[H', end='')

        # Draw the panel border
        self._draw_panel_border()

        # Move cursor back to main area
        print(f'\033[1;1H', end='', flush=True)

        self.enabled = True

    def _draw_panel_border(self) -> None:
        """Draw the border line above the status panel."""
        cols, rows = get_terminal_size()

        # Save cursor position
        print('\033[s', end='')

        # Move to panel border line
        border_row = self._main_area_height + 1
        print(f'\033[{border_row};1H', end='')

        # Draw border
        border = '─' * cols
        print(f'{Colors.MUTED}{border}{Colors.RESET}', end='')

        # Clear panel area
        for i in range(self.PANEL_HEIGHT):
            print(f'\033[{border_row + 1 + i};1H\033[2K', end='')

        # Restore cursor position
        print('\033[u', end='', flush=True)

    def show_message(self, text: str) -> None:
        """Display a message in the status panel."""
        if not self.enabled:
            print(text)
            return

        cols, rows = get_terminal_size()

        # Add to message history
        self.messages.append(text)
        # Keep only last few messages
        if len(self.messages) > self.PANEL_HEIGHT:
            self.messages = self.messages[-self.PANEL_HEIGHT:]

        # Save cursor position
        print('\033[s', end='')

        # Move to panel area (below border)
        panel_start = self._main_area_height + 2

        # Clear and redraw panel content
        for i, msg in enumerate(self.messages[-self.PANEL_HEIGHT:]):
            row = panel_start + i
            print(f'\033[{row};1H\033[2K', end='')  # Move and clear line
            # Truncate if too long
            display_msg = msg[:cols-2] if len(msg) > cols-2 else msg
            print(f'{Colors.INFO}{display_msg}{Colors.RESET}', end='')

        # Restore cursor position
        print('\033[u', end='', flush=True)

    def clear(self) -> None:
        """Clear the status panel."""
        if not self.enabled:
            return

        self.messages = []
        cols, rows = get_terminal_size()

        # Save cursor
        print('\033[s', end='')

        # Clear panel lines
        panel_start = self._main_area_height + 2
        for i in range(self.PANEL_HEIGHT):
            print(f'\033[{panel_start + i};1H\033[2K', end='')

        # Restore cursor
        print('\033[u', end='', flush=True)

    def teardown(self) -> None:
        """Reset terminal to normal scrolling."""
        if not self.enabled:
            return

        # Reset scroll region to full screen
        print('\033[r', end='')

        # Move to bottom
        _, rows = get_terminal_size()
        print(f'\033[{rows};1H', end='', flush=True)

        self.enabled = False


# Global status panel instance
_status_panel = StatusPanel()


def setup_status_panel() -> None:
    """Set up the status panel at bottom of screen."""
    _status_panel.setup()


def status_message(text: str) -> None:
    """Show a message in the status panel."""
    _status_panel.show_message(text)


def clear_status_panel() -> None:
    """Clear the status panel."""
    _status_panel.clear()


def teardown_status_panel() -> None:
    """Remove the status panel and restore normal terminal."""
    _status_panel.teardown()


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
    # Use scrollback-preserving clear
    clear_screen(preserve_scrollback=True)

    if style == "dragon":
        splash = SPLASH_DRAGON
    elif style == "simple":
        splash = SPLASH_SIMPLE
    else:
        splash = SPLASH_SCREEN

    # Check if splash fits in terminal
    _, term_height = get_terminal_size()
    splash_lines = splash.count('\n')

    # Use simple splash if terminal is too small
    if splash_lines > term_height - 2 and style != "simple":
        splash = SPLASH_SIMPLE

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

def _getch(timeout: Optional[float] = None) -> Optional[str]:
    """
    Read a single character from stdin without waiting for Enter.
    Works on Unix/macOS. Returns the character or escape sequence.

    Args:
        timeout: Optional timeout in seconds. Returns None if timeout occurs.
    """
    import termios
    import tty
    import select
    import fcntl

    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    old_flags = fcntl.fcntl(fd, fcntl.F_GETFL)

    try:
        tty.setraw(fd)

        # Use select to wait with timeout for first character
        if timeout is not None:
            ready, _, _ = select.select([sys.stdin], [], [], timeout)
            if not ready:
                return None  # Timeout

        ch = sys.stdin.read(1)

        # Handle escape sequences (arrow keys)
        if ch == '\x1b':  # ESC
            # Set non-blocking mode to read rest of sequence
            fcntl.fcntl(fd, fcntl.F_SETFL, old_flags | os.O_NONBLOCK)

            try:
                # Try to read next character
                ch2 = sys.stdin.read(1)
                if ch2 == '[':
                    # CSI sequence (most common for arrow keys)
                    ch3 = sys.stdin.read(1)
                    # Arrow keys: A=up, B=down, C=right, D=left
                    return f'\x1b[{ch3}'
                elif ch2 == 'O':
                    # SS3 sequence (alternative arrow key format)
                    ch3 = sys.stdin.read(1)
                    return f'\x1bO{ch3}'
                elif ch2:
                    return ch + ch2
                else:
                    return ch  # Just ESC
            except (IOError, TypeError):
                # No more characters available - just ESC
                return ch
            finally:
                # Restore blocking mode
                fcntl.fcntl(fd, fcntl.F_SETFL, old_flags)

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


def _print_interactive_menu(options: List[str], title: str, selected: int,
                            allow_back: bool = False) -> None:
    """Print menu with visual selection indicator."""
    print(f"\n{Colors.SUBTITLE}{title}{Colors.RESET}")
    back_hint = ", ←/b=back" if allow_back else ""
    print(f"{Colors.MUTED}  (↑↓/jk: navigate, Enter: select{back_hint}){Colors.RESET}")
    print()
    for i, option in enumerate(options, 1):
        if i == selected:
            # Highlighted selection
            print(f"  {Colors.TITLE}> {i}. {option} <{Colors.RESET}")
        else:
            print(f"    {Colors.MUTED}{i}.{Colors.RESET} {option}")
    if allow_back:
        print(f"    {Colors.MUTED}0.{Colors.RESET} ← Back")
    print()


def _redraw_interactive_menu(options: List[str], title: str, selected: int,
                              total_lines: int, allow_back: bool = False) -> None:
    """Redraw the menu in place by moving cursor up and reprinting."""
    # Move cursor up to the start of the menu
    _move_cursor_up(total_lines)

    # Reprint the menu
    _clear_line()
    print(f"{Colors.SUBTITLE}{title}{Colors.RESET}")
    _clear_line()
    back_hint = ", ←/b=back" if allow_back else ""
    print(f"{Colors.MUTED}  (↑↓/jk: navigate, Enter: select{back_hint}){Colors.RESET}")
    _clear_line()
    print()

    for i, option in enumerate(options, 1):
        _clear_line()
        if i == selected:
            print(f"  {Colors.TITLE}> {i}. {option} <{Colors.RESET}")
        else:
            print(f"    {Colors.MUTED}{i}.{Colors.RESET} {option}")

    if allow_back:
        _clear_line()
        print(f"    {Colors.MUTED}0.{Colors.RESET} ← Back")

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
                    timeout: Optional[float] = None, allow_back: bool = False) -> int:
    """
    Display menu and get valid choice.

    Supports:
    - Arrow keys (up/down) for navigation
    - hjkl vim-style keys (j=down, k=up)
    - Number keys for direct selection
    - Enter to confirm selection
    - Left arrow / Backspace / 'b' for back (when allow_back=True)

    Args:
        options: List of menu options
        title: Menu title
        default: Default option (1-indexed). If set, pressing Enter selects it.
        allow_default: Whether to allow pressing Enter for default (global config)
        timeout: Optional timeout in seconds for input
        allow_back: Whether to allow going back (returns 0 if back is pressed)

    Returns:
        Selected option (1-indexed), or 0 if back was pressed
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
        return _get_menu_choice_interactive(options, title, default or 1, allow_back)
    else:
        return _get_menu_choice_fallback(options, title, default, use_defaults, timeout, allow_back)


def _get_menu_choice_interactive(options: List[str], title: str, default: int,
                                  allow_back: bool = False) -> int:
    """Interactive menu selection with arrow keys and hjkl."""
    selected = default
    num_options = len(options)

    # Calculate total lines for redrawing (title + hint + blank + options + back? + blank)
    total_lines = 3 + num_options + (1 if allow_back else 0) + 1

    # Initial draw
    _print_interactive_menu(options, title, selected, allow_back)
    _hide_cursor()

    try:
        while True:
            try:
                ch = _getch()

                # Arrow keys
                if ch == '\x1b[A' or ch == 'k':  # Up arrow or k
                    selected = selected - 1 if selected > 1 else num_options
                    _redraw_interactive_menu(options, title, selected, total_lines, allow_back)

                elif ch == '\x1b[B' or ch == 'j':  # Down arrow or j
                    selected = selected + 1 if selected < num_options else 1
                    _redraw_interactive_menu(options, title, selected, total_lines, allow_back)

                elif ch == '\x1b[C' or ch == 'l':  # Right arrow or l - same as Enter
                    return selected

                elif ch == '\x1b[D' or ch == 'h':  # Left arrow or h - back if allowed
                    if allow_back:
                        return 0  # Back
                    else:
                        selected = 1
                        _redraw_interactive_menu(options, title, selected, total_lines, allow_back)

                elif ch == '\r' or ch == '\n' or ch == ' ':  # Enter or Space
                    return selected

                elif ch == '\x1b' or ch == 'q':  # ESC or q - back if allowed, else default
                    if allow_back:
                        return 0
                    return default

                elif ch == '\x7f' or ch == 'b':  # Backspace or 'b' - back if allowed
                    if allow_back:
                        return 0

                elif ch == 'g':  # g - go to first (vim style)
                    selected = 1
                    _redraw_interactive_menu(options, title, selected, total_lines, allow_back)

                elif ch == 'G':  # G - go to last (vim style)
                    selected = num_options
                    _redraw_interactive_menu(options, title, selected, total_lines, allow_back)

                elif ch.isdigit():  # Number key
                    num = int(ch)
                    if 1 <= num <= num_options:
                        return num
                    elif num == 0:
                        if allow_back:
                            return 0  # 0 = back
                        elif num_options >= 10:
                            return 10

            except (EOFError, KeyboardInterrupt):
                if allow_back:
                    return 0
                return default

    finally:
        _show_cursor()


def _get_menu_choice_fallback(options: List[str], title: str, default: Optional[int],
                               use_defaults: bool, timeout: Optional[float],
                               allow_back: bool = False) -> int:
    """Fallback menu selection for non-TTY or when interactive is disabled."""
    print_menu(options, title, default if use_defaults else None)
    if allow_back:
        print(f"    {Colors.MUTED}0.{Colors.RESET} ← Back")
        print()

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
            if choice == 0 and allow_back:
                return 0  # Back
            if 1 <= choice <= len(options):
                return choice
            max_val = len(options)
            min_val = 0 if allow_back else 1
            print(f"{Colors.WARNING}Please enter a number between {min_val} and {max_val}{Colors.RESET}")
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


def clear_screen(preserve_scrollback: bool = False) -> None:
    """
    Clear the terminal screen.

    Args:
        preserve_scrollback: If True, scroll content up instead of erasing.
                            This preserves ability to scroll back.
    """
    if preserve_scrollback:
        # Scroll the screen content up by printing newlines
        _, term_height = get_terminal_size()
        print('\n' * term_height, end='')
    else:
        # Full clear (destroys scrollback)
        print('\033[2J\033[H', end='')


def print_dm(text: str) -> None:
    """Print DM narration text."""
    print(f"\n{Colors.MUTED}*{Colors.RESET} {text}")


def print_dialogue(speaker: str, text: str) -> None:
    """Print NPC dialogue."""
    print(f"\n{Colors.NPC}{speaker}:{Colors.RESET} \"{text}\"")
