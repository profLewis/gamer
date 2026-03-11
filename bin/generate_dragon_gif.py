#!/usr/bin/env python3
"""Generate animated dragon GIF using Boulton symbol tiles from Set A and Set B.

High-resolution approach: render the ASCII dragon text onto a large image using
a monospace font, then sample each tile-sized cell's average brightness to pick
the appropriate density Boulton tile. This gives a much denser grid (~200+ cols,
50+ rows) compared to the old 1-char-per-tile approach.
"""

from PIL import Image, ImageDraw, ImageFont
import os
import platform

# --- Configuration ---
TILE_SIZE = 10
SET_A_DIR = "/Users/plewis/Documents/GitHub/boulton-data/Symbol Set A"
SET_B_DIR = "/Users/plewis/Documents/GitHub/boulton-data/Symbol Set B"
GREEN = (0, 220, 0)

# High-res rendering: font size for rendering ASCII art onto the temp image.
# Larger = more detail captured before tile sampling.
FONT_SIZE = 54

# --- Dragon art: fixed rows (0-6, 9-15) + variable rows (7-8) ---

FIXED = {
    0:  "               ___=====_       _-====__",
    1:  "                _--^^^####//      \\#####^^^--_",
    2:  "             _-^#########//  (    ) \\\\##########^-_",
    3:  "            -############//   |^^/|   \\\\############-",
    4:  "          _/##############//   (@::@)   \\\\##############\\_",
    5:  "         /################((    \\\\//    ))################\\",
    6:  "        -##################\\\\    (oo)    //##################-",
    9:  "      _##/|##########/\\######(    ^    )######/\\##########|\\##_",
    10: "      |/  |#/\\#/\\#/\\/  \\#/\\##\\  | |  /##/\\#/  \\/\\#/\\#/\\#|  \\|",
    11: "      `   |/  V  V  `   V  \\#|  | |  |#/  V   '  V  V  \\|   '",
    12: "          `   `   `       `  |  | |  |  '       '   '   '",
    13: "                             (  | |  )",
    14: "                              \\_\\ /_/",
    15: "                        (vvv(VVV)(VVV)vvv)",
}


def make_row7(n):
    """Wing row with '/ VV \\' center. n = number of # chars per wing."""
    left = "-" + "#" * n + "\\\\"
    right = "//" + "#" * n + "-"
    center = "/ VV \\"
    avail = 30 - len(left)
    gap = min(6, max(2, avail))
    pad = max(0, avail - gap)
    return " " * pad + left + " " * gap + center + " " * gap + right


def make_row8(n7):
    """Trailing wing edge row."""
    left = "-" + "#" * (n7 - 1) + "\\\\/"
    right = "\\\\//" + "#" * (n7 - 2) + "-"
    pad7 = max(0, 30 - (n7 + 3) - min(6, max(2, 30 - (n7 + 3))))
    pad8 = max(0, pad7 - 1)
    return " " * pad8 + left + " " * 20 + right


def make_frame_text(n_hashes):
    """Assemble a 16-line dragon frame with given wing spread."""
    lines = []
    for row in range(16):
        if row == 7:
            lines.append(make_row7(n_hashes))
        elif row == 8:
            lines.append(make_row8(n_hashes))
        else:
            lines.append(FIXED[row])
    return "\n".join(lines)


WING_SIZES = [7, 10, 14, 18, 21, 18, 14, 10]
DURATIONS = [180, 100, 80, 100, 180, 100, 80, 100]

# --- Tile loading and colorization ---

def load_and_colorize(path, fg=GREEN):
    """Load a tile and convert from black-on-white to green-on-black.

    Tiles are kept at native TILE_SIZE (10x10) -- no SCALE upscaling since
    the high-res approach already produces many more grid cells.
    """
    img = Image.open(path).convert("L")
    img = img.resize((TILE_SIZE, TILE_SIZE), Image.NEAREST)

    result = Image.new("RGB", (TILE_SIZE, TILE_SIZE), (0, 0, 0))
    px_in = img.load()
    px_out = result.load()
    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            b = px_in[x, y]
            f = (255 - b) / 255.0  # dark pixels -> bright green
            px_out[x, y] = (int(fg[0] * f), int(fg[1] * f), int(fg[2] * f))
    return result


def load_tiles(directory):
    """Load all tiles from a symbol set directory, keyed by letter."""
    tiles = {}
    for fname in sorted(os.listdir(directory)):
        if fname.endswith('.png'):
            letter = fname[0]
            tiles[letter] = load_and_colorize(os.path.join(directory, fname))
    return tiles


# --- Brightness-to-tile mapping ---
# Density reference (percentage of dark/filled pixels):
#   A=4%  B=9%  C=24%  D=38%  E=52%  F=56%(A only)  G=68%(B only)  H=81%  I=100%
#
# We define brightness thresholds: given a cell's average brightness (0=black, 255=white),
# map to a tile density letter. Higher brightness from the rendered text means denser tile.

# Sorted by density. We pair (Set A letter, Set B letter) at each level.
DENSITY_LEVELS = [
    # (threshold, set_a_letter, set_b_letter)
    # brightness >= threshold -> use this tile
    (230, 'I', 'I'),   # 100% - very bright text pixels
    (190, 'H', 'H'),   # 81%
    (155, 'F', 'G'),   # 56% / 68%
    (120, 'E', 'E'),   # 52%
    (85,  'D', 'D'),   # 38%
    (55,  'C', 'C'),   # 24%
    (25,  'B', 'B'),   # 9%
    (8,   'A', 'A'),   # 4%
]


def get_tile_for_brightness(brightness, row, col, tiles_a, tiles_b):
    """Pick a Boulton tile based on average cell brightness, alternating sets."""
    if brightness < 8:
        return None  # too dark, leave as black background

    for threshold, a_letter, b_letter in DENSITY_LEVELS:
        if brightness >= threshold:
            if (row + col) % 2 == 0:
                tile = tiles_a.get(a_letter)
                if tile is None:
                    tile = tiles_b.get(b_letter)
            else:
                tile = tiles_b.get(b_letter)
                if tile is None:
                    tile = tiles_a.get(a_letter)
            return tile

    return None


# --- Font selection ---

def get_monospace_font(size):
    """Try to load a monospace font, falling back to default."""
    candidates = [
        "/System/Library/Fonts/Menlo.ttc",
        "/System/Library/Fonts/Monaco.dfont",
        "/System/Library/Fonts/Courier.dfont",
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    # Fallback
    return ImageFont.load_default()


# --- High-resolution text rendering ---

def render_text_to_image(text, font):
    """Render ASCII art text onto a grayscale image (white text on black).

    Returns a PIL Image in mode "L".
    """
    lines = text.split("\n")
    # Measure text extents
    dummy = Image.new("L", (1, 1), 0)
    draw = ImageDraw.Draw(dummy)

    # Measure each line to find max width and total height
    max_w = 0
    line_heights = []
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font)
        w = bbox[2] - bbox[0]
        h = bbox[3] - bbox[1]
        max_w = max(max_w, w)
        line_heights.append(h)

    # Use consistent line spacing
    line_h = int(font.size * 1.15)
    img_w = max_w + 40  # small padding
    img_h = line_h * len(lines) + 40

    img = Image.new("L", (img_w, img_h), 0)
    draw = ImageDraw.Draw(img)

    y = 20
    for line in lines:
        draw.text((20, y), line, fill=255, font=font)
        y += line_h

    return img


# --- Frame rendering via brightness sampling ---

def render_frame_hires(text, font, tiles_a, tiles_b):
    """Render one frame at high resolution by:
    1. Drawing the ASCII art onto a temp image with a monospace font
    2. Dividing into a grid of TILE_SIZE x TILE_SIZE cells
    3. Measuring average brightness per cell
    4. Placing the matching density Boulton tile
    """
    text_img = render_text_to_image(text, font)
    tw, th = text_img.size
    px = text_img.load()

    # Grid dimensions (number of tile cells)
    grid_cols = tw // TILE_SIZE
    grid_rows = th // TILE_SIZE

    # Output canvas
    canvas_w = grid_cols * TILE_SIZE
    canvas_h = grid_rows * TILE_SIZE
    canvas = Image.new("RGB", (canvas_w, canvas_h), (0, 0, 0))

    for row in range(grid_rows):
        for col in range(grid_cols):
            # Compute average brightness in this cell
            x0 = col * TILE_SIZE
            y0 = row * TILE_SIZE
            total = 0
            for dy in range(TILE_SIZE):
                for dx in range(TILE_SIZE):
                    total += px[x0 + dx, y0 + dy]
            avg = total / (TILE_SIZE * TILE_SIZE)

            tile = get_tile_for_brightness(avg, row, col, tiles_a, tiles_b)
            if tile is not None:
                canvas.paste(tile, (x0, y0))

    return canvas


def main():
    print("Loading symbol tiles...")
    tiles_a = load_tiles(SET_A_DIR)
    tiles_b = load_tiles(SET_B_DIR)
    print(f"  Set A: {sorted(tiles_a.keys())}")
    print(f"  Set B: {sorted(tiles_b.keys())}")

    print("Loading monospace font...")
    font = get_monospace_font(FONT_SIZE)
    print(f"  Font size: {FONT_SIZE}")

    print("Generating frames...")
    frames_text = [make_frame_text(n) for n in WING_SIZES]

    # Preview grid dimensions from the first frame
    preview_img = render_text_to_image(frames_text[0], font)
    pw, ph = preview_img.size
    print(f"  Text render size: {pw}x{ph}")
    print(f"  Tile grid: {pw // TILE_SIZE} cols x {ph // TILE_SIZE} rows")

    frames = []
    for i, ft in enumerate(frames_text):
        frame = render_frame_hires(ft, font, tiles_a, tiles_b)
        frames.append(frame)
        print(f"  Frame {i+1}/{len(frames_text)} (wing #{WING_SIZES[i]}) - {frame.size[0]}x{frame.size[1]}")

    # Ensure all frames are the same size (pad smaller ones)
    max_w = max(f.size[0] for f in frames)
    max_h = max(f.size[1] for f in frames)
    padded = []
    for f in frames:
        if f.size[0] < max_w or f.size[1] < max_h:
            p = Image.new("RGB", (max_w, max_h), (0, 0, 0))
            x_off = (max_w - f.size[0]) // 2
            y_off = (max_h - f.size[1]) // 2
            p.paste(f, (x_off, y_off))
            padded.append(p)
        else:
            padded.append(f)

    out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       "images", "dragon_boulton.gif")
    padded[0].save(
        out,
        save_all=True,
        append_images=padded[1:],
        duration=DURATIONS,
        loop=0,
        optimize=False,
    )
    print(f"Saved: {out}")
    print(f"  {len(padded)} frames, {max_w}x{max_h}, {os.path.getsize(out)} bytes")


if __name__ == "__main__":
    main()
