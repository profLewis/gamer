#!/usr/bin/env python3
"""Generate an animated GIF of a dragon that roars periodically.

Dragon art sourced from GameEngine.swift asciiDragon property.
"""

from PIL import Image, ImageDraw, ImageFont
import os

OUTPUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                      "images", "dragon_flapping.gif")

FONT_PATH = "/System/Library/Fonts/Menlo.ttc"
FONT_SIZE = 13
LINE_HEIGHT = 16
IMG_W = 567
IMG_H = 376

BG_COLOR = (0, 0, 0)
FG_COLOR = (0, 230, 0)


def dragon_lines(eyes="@", nostrils="o"):
    """Build dragon lines with customizable eyes and nostrils.

    Art taken verbatim from GameEngine.swift asciiDragon.
    In Swift, \\\\ is a literal \\. Here in Python strings,
    \\\\ also produces \\.
    """
    return [
        "          ___====-_  _-====___",
        "    _--^^^#####//      \\\\#####^^^--_",
        " _-^##########// (    ) \\\\##########^-_",
        "    -############//  |\\^^/|  \\\\############-",
        f"  _/############//   ({eyes}::{eyes})   \\\\############\\_",
        " /#############((     \\\\//     ))#############\\",
        f"-###############\\\\    ({nostrils}{nostrils})    //###############-",
        "   -#################\\\\  / VV \\  //#################-",
        "  -###################\\\\/      \\\\//###################-",
        " _#/|##########/\\######(   /\\   )######/\\##########|\\#_",
        " |/ |#/\\#/\\#/\\/  \\#/\\##\\  |  |  /##/\\#/  \\/\\#/\\#/\\#| \\|",
        " `  |/  V  V  `   V  \\#\\| |  | |/#/  V   '  V  V  \\|  '",
        "    `   `  `      `   / | |  | | \\   '      '  '   '",
        "                       (  | |  | |  )",
        "                      __\\ | |  | | /__",
        "                     (vvv(VVV)(VVV)vvv)",
    ]


def render_frame(lines, font):
    img = Image.new("RGB", (IMG_W, IMG_H), BG_COLOR)
    draw = ImageDraw.Draw(img)

    # Center the text block vertically
    total_h = len(lines) * LINE_HEIGHT
    y = (IMG_H - total_h) // 2

    # Measure max width for horizontal centering
    max_w = 0
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font)
        max_w = max(max_w, bbox[2] - bbox[0])
    x = (IMG_W - max_w) // 2

    for line in lines:
        draw.text((x, y), line, font=font, fill=FG_COLOR)
        y += LINE_HEIGHT

    return img


def main():
    font = ImageFont.truetype(FONT_PATH, FONT_SIZE)

    frames = []
    durations = []

    idle = dragon_lines(eyes="@", nostrils="o")
    roar = dragon_lines(eyes="-", nostrils="0")

    # Idle 3s, then 3 roar cycles (1s each: 500ms roar + 500ms normal)
    frames.append(render_frame(idle, font))
    durations.append(3000)

    for _ in range(3):
        frames.append(render_frame(roar, font))
        durations.append(500)
        frames.append(render_frame(idle, font))
        durations.append(500)

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    frames[0].save(
        OUTPUT,
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        optimize=False,
    )
    print(f"Saved {len(frames)} frames to {OUTPUT}")
    print(f"  Total loop: {sum(durations)}ms")


if __name__ == "__main__":
    main()
