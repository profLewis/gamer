#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
NPC_SWIFT = ROOT / "ios/DnDTextRPG/DnDTextRPG/Models/NPCModels.swift"
OUT = ROOT / "images/all_npcs.png"


def decode_swift_string(s: str) -> str:
    return bytes(s, "utf-8").decode("unicode_escape")


def parse_npcs(src: str):
    enum_block = re.search(r"enum NPCType:.*?\{(.*?)\n\s*// MARK: - ASCII Art", src, flags=re.DOTALL)
    art_block = re.search(r"var asciiArt: \[String\] \{\s*switch self \{(.*?)\n\s*\}\n\s*\}\n\n\s*// MARK: - Description", src, flags=re.DOTALL)
    if not enum_block or not art_block:
        raise RuntimeError("Could not parse NPC definitions")

    order = re.findall(r'case\s+(\w+)\s*=\s*"([^"]+)"', enum_block.group(1))
    art_map = {}
    for m in re.finditer(r"case\s+\.(\w+):\s*\n\s*return\s*\[(.*?)\n\s*\]", art_block.group(1), flags=re.DOTALL):
        key = m.group(1)
        lines = [decode_swift_string(x) for x in re.findall(r'"((?:\\.|[^"\\])*)"', m.group(2))]
        art_map[key] = lines

    npcs = []
    for key, name in order:
        art = art_map.get(key)
        if not art:
            raise RuntimeError(f"Missing asciiArt for {key}")
        npcs.append((name, art))
    return npcs


def load_font(path_options, size):
    for p in path_options:
        if Path(p).exists():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def main():
    src = NPC_SWIFT.read_text(encoding="utf-8")
    npcs = parse_npcs(src)

    w, h = 940, 670
    cols, rows = 6, 3
    pad = 12
    cell_w = (w - pad * (cols + 1)) // cols
    cell_h = (h - pad * (rows + 1)) // rows

    img = Image.new("RGB", (w, h), "#050705")
    d = ImageDraw.Draw(img)

    title_font = load_font([
        "/System/Library/Fonts/Supplemental/Courier New Bold.ttf",
        "/System/Library/Fonts/Menlo.ttc",
    ], 15)
    art_font = load_font([
        "/System/Library/Fonts/Menlo.ttc",
        "/System/Library/Fonts/Supplemental/Courier New.ttf",
    ], 14)

    border = "#1f5f2f"
    text = "#8df29f"
    dim = "#5fbf72"

    for i, (name, art) in enumerate(npcs):
        r = i // cols
        c = i % cols
        x0 = pad + c * (cell_w + pad)
        y0 = pad + r * (cell_h + pad)
        x1 = x0 + cell_w
        y1 = y0 + cell_h

        d.rectangle((x0, y0, x1, y1), outline=border, width=1, fill="#091009")

        # Name (simple two-line wrap)
        max_chars = 15
        words = name.split()
        l1, l2 = "", ""
        for w_ in words:
            if len((l1 + " " + w_).strip()) <= max_chars:
                l1 = (l1 + " " + w_).strip()
            else:
                l2 = (l2 + " " + w_).strip()
        name_lines = [l1] + ([l2] if l2 else [])

        y = y0 + 6
        for line in name_lines[:2]:
            tw = d.textbbox((0, 0), line, font=title_font)[2]
            d.text((x0 + (cell_w - tw) // 2, y), line, fill=text, font=title_font)
            y += 16

        d.line((x0 + 8, y + 2, x1 - 8, y + 2), fill=border, width=1)
        y += 8

        for line in art:
            tw = d.textbbox((0, 0), line, font=art_font)[2]
            d.text((x0 + (cell_w - tw) // 2, y), line, fill=dim, font=art_font)
            y += 15

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
