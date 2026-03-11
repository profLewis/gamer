#!/usr/bin/env python3
"""Animated GIF: dragon with horns, teeth & scaly neck peeks over castle wall."""

from PIL import Image, ImageDraw, ImageFont
import os

def get_font(size):
    for f in ["/System/Library/Fonts/Menlo.ttc",
              "/Library/Fonts/Courier New.ttf"]:
        if os.path.exists(f):
            try:
                return ImageFont.truetype(f, size)
            except Exception:
                continue
    return ImageFont.load_default()

font = get_font(14)

# ── Castle ────────────────────────────────────────────────────────
castle = [
    "                    |>>>                              |>>>",
    "                    |                                 |",
    "                _  _|_  _                         _  _|_  _",
    "               |;| |;| |;|                       |;| |;| |;|",
    "               \\.    .  /                         \\.    .  /",
    "                \\:. .:/                             \\:. .:/",
    "                 ]:.[                                 ]:.[",
    "               /  | .\\                             /  | .\\",
    "              |   | .  |                           |   | .  |",
    "              |   | .  |                           |   | .  |",
    "              |   | .  | ___ ___ ___ ___ ___ ___  |   | .  |",
    "              |   | .  ||   |   |   |   |   |   | |   | .  |",
    "              |   | .  ||   |   |   |   |   |   | |   | .  |",
    "              |   | .  ||___|___|___|___|___|___| |   | .  |",
    "              |   | .  ||   |   |   |   |   |   | |   | .  |",
    "              |   | .  ||   |   |   |   |   |   | |   | .  |",
    "     _________|___|_.__|___|___|___|___|___|___|__|___|_.__|________",
    "    /\\_____________________________________________________________ /\\",
    "   / /                    |           |                            / /",
    "  / /                     |    ___    |                           / /",
    " / /                      |   |   |   |                         / /",
    "/ /                       |   |   |   |                        / /",
    "\\/________________________|___|___|___|_______________________\\/",
]

# ── Dragon head + neck (5 lines) ─────────────────────────────────
# Overlaid onto castle lines 5-9, centered in the gap between towers
# Non-space chars are written over the castle; spaces are transparent
DRAGON_COL = 31         # left edge of dragon art in castle columns
DRAGON_BOTTOM = 9       # lowest castle line the dragon occupies

dragon_open = [
    "/~\\      /~\\",       # swept horns with scale ridges
    "(  (@::@)  )",         # head with big eyes
    " \\_/\\/\\_/ ",        # jaw with teeth
    "   |~::~|  ",          # scaly neck
    "   |~::~|  ",          # scaly neck
]

dragon_wink_l = [
    "/~\\      /~\\",
    "(  (-::@)  )",
    " \\_/\\/\\_/ ",
    "   |~::~|  ",
    "   |~::~|  ",
]

dragon_wink_r = [
    "/~\\      /~\\",
    "(  (@::-)  )",
    " \\_/\\/\\_/ ",
    "   |~::~|  ",
    "   |~::~|  ",
]

N_DRAGON = len(dragon_open)
max_width = max(len(l) for l in castle)

# ── Flag animation (flapping ripple) ─────────────────────────────
FLAG_STATES = [">>>", ">>~", ">~~", "~~>"]
FLAG_COLS = [21, 55]    # columns where flag text starts (after the | pole)

def overlay(base, text, col):
    """Write non-space chars from text onto base at column offset."""
    result = list(base.ljust(max_width))
    for i, ch in enumerate(text):
        if ch != ' ':
            pos = col + i
            if 0 <= pos < len(result):
                result[pos] = ch
    return ''.join(result)

def build_frame(art, num_visible, flag_idx):
    """Build castle with dragon and animated flags."""
    lines = list(castle)
    # Animate flags on line 0
    flag = FLAG_STATES[flag_idx % len(FLAG_STATES)]
    line0 = list(lines[0].ljust(max_width))
    for col in FLAG_COLS:
        for j, ch in enumerate(flag):
            if col + j < len(line0):
                line0[col + j] = ch
    lines[0] = ''.join(line0)
    # Overlay dragon
    for i in range(num_visible):
        row = DRAGON_BOTTOM - num_visible + 1 + i
        if 0 <= row < len(lines):
            lines[row] = overlay(lines[row], art[i], DRAGON_COL)
    return lines

# ── Animation ─────────────────────────────────────────────────────
timeline = [
    (dragon_open,   0, 1000),   # hidden
    (dragon_open,   1, 180),    # horns peek up
    (dragon_open,   2, 180),    # eyes appear
    (dragon_open,   3, 180),    # jaw with teeth
    (dragon_open,   4, 200),    # upper neck
    (dragon_open,   5, 700),    # full head + neck
    (dragon_wink_l, 5, 250),    # wink left
    (dragon_open,   5, 500),
    (dragon_wink_r, 5, 250),    # wink right
    (dragon_open,   5, 400),
    (dragon_wink_l, 5, 150),    # double wink
    (dragon_wink_r, 5, 150),
    (dragon_open,   5, 800),    # pause
    (dragon_open,   4, 140),    # descending
    (dragon_open,   3, 140),
    (dragon_open,   2, 140),
    (dragon_open,   1, 140),
    (dragon_open,   0, 1200),   # hidden
]

BG = (0, 0, 0)
FG = (0, 210, 0)

def render(lines):
    lines = [l.ljust(max_width) for l in lines]
    cw, ch = 8.4, 17
    w = int(max_width * cw) + 40
    h = int(len(lines) * ch) + 40
    img = Image.new("RGB", (w, h), BG)
    draw = ImageDraw.Draw(img)
    y = 20
    for line in lines:
        draw.text((20, y), line, fill=FG, font=font)
        y += ch
    return img

frames = []
durations = []
for idx, (art, nvis, dur) in enumerate(timeline):
    frames.append(render(build_frame(art, nvis, idx)))
    durations.append(dur)

out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "images", "dragon_castle.gif")
frames[0].save(out, save_all=True, append_images=frames[1:],
               duration=durations, loop=0, optimize=True)
print(f"Saved: {out} ({frames[0].size[0]}x{frames[0].size[1]}, {len(frames)} frames)")
