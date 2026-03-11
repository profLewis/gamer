#!/usr/bin/env python3
"""Generate an animated GIF of a dragon that roars periodically."""

from PIL import Image, ImageDraw, ImageFont
import os

OUTPUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "images", "dragon_flapping.gif")

FONT_PATH = "/System/Library/Fonts/Menlo.ttc"
FONT_SIZE = 13
LINE_HEIGHT = 16
IMG_W = 564
IMG_H = 340

BG_COLOR = (0, 0, 0)
FG_COLOR = (0, 230, 0)

# The dragon art as 16 lines. Lines 4 and 6 have the eyes (@) and nostrils (o)
# that change during the roar.

def dragon_lines(eyes="@", nostrils="o"):
    """Build the 16 dragon lines with customizable eyes and nostrils."""
    return [
        "               ___=====_       _-====__",
        "                _--^^^####//      \\#####^^^--_",
        "             _-^##########//   (    )   \\\\##########^-_",
        "            -############//   |^^/|   \\\\############-",
        f"          _/##############//   ({eyes}::{eyes})   \\\\##############\\_",
        "         /################((    \\\\//    ))################\\",
        f"        -##################\\\\    ({nostrils}{nostrils})    //##################-",
        "       -##############\\\\      / VV \\      //##############-",
        "      -#############\\\\/                    \\\\//############-",
        "      _##/|##########/\\######(    ^    )######/\\##########|\\##_",
        "      |/  |#/\\#/\\#/\\/  \\#/\\##\\  | |  /##/\\#/  \\/\\#/\\#/\\#|  \\|",
        "      `   |/  V  V  `   V  \\#|  | |  |#/  V   '  V  V  \\|   '",
        "          `   `   `       `  |  | |  |  '       '   '   '",
        "                             (  | |  )",
        "                              \\_\\ /_/",
        "                        (vvv(VVV)(VVV)vvv)",
    ]


def render_frame(lines, font):
    img = Image.new("RGB", (IMG_W, IMG_H), BG_COLOR)
    draw = ImageDraw.Draw(img)
    y = 8
    for line in lines:
        draw.text((6, y), line, font=font, fill=FG_COLOR)
        y += LINE_HEIGHT
    return img


def main():
    font = ImageFont.truetype(FONT_PATH, FONT_SIZE)

    # --- Build animation sequence ---
    # Idle for ~3 seconds, then roar (3 cycles of eyes/nostrils change, ~1s each),
    # then idle again. Total loop ~6 seconds.
    #
    # Idle: eyes=@, nostrils=o
    # Roar: eyes=-, nostrils=0  (squinting eyes, flared nostrils)
    #
    # Each roar cycle = 1 second:
    #   - 500ms roar (eyes=-, nostrils=0)
    #   - 500ms normal (eyes=@, nostrils=o)

    frames = []
    durations = []  # ms

    idle = dragon_lines(eyes="@", nostrils="o")
    roar = dragon_lines(eyes="-", nostrils="0")

    # --- Idle period: 3 seconds (single frame held for 3000ms) ---
    frames.append(render_frame(idle, font))
    durations.append(3000)

    # --- 3 roar cycles, each 1 second ---
    for _ in range(3):
        # Roar: 500ms
        frames.append(render_frame(roar, font))
        durations.append(500)
        # Back to normal: 500ms
        frames.append(render_frame(idle, font))
        durations.append(500)

    frames[0].save(
        OUTPUT,
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        optimize=False,
    )
    print(f"Saved {len(frames)} frames to {OUTPUT}")
    total_ms = sum(durations)
    print(f"  Total loop: {total_ms}ms ({total_ms/1000:.1f}s)")
    for i, d in enumerate(durations):
        eyes = "@" if i == 0 or i % 2 == 0 else "-"
        print(f"  Frame {i}: {d}ms")


if __name__ == "__main__":
    main()
