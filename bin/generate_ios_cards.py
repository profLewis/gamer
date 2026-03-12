#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import textwrap
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
GAME_ENGINE = ROOT / "ios/DnDTextRPG/DnDTextRPG/Game/GameEngine.swift"
COMBAT_MODELS = ROOT / "ios/DnDTextRPG/DnDTextRPG/Models/CombatModels.swift"
OUT_ROOT = ROOT / "ios_card_images"


@dataclass
class NameEntry:
    name: str
    source: str
    description: str
    category: str
    art: List[str]
    power: int
    cunning: int
    magic: int
    fame: int
    charm: int


@dataclass
class MonsterEntry:
    key: str
    name: str
    hp: int
    ac: int
    attack_bonus: int
    damage: str
    cr: str
    xp: int
    description: str
    art: List[str]


def decode_swift_string(s: str) -> str:
    return bytes(s, "utf-8").decode("unicode_escape")


def slugify(s: str) -> str:
    s = s.lower().strip()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    s = re.sub(r"-+", "-", s).strip("-")
    return s


def extract_parenthesized(text: str, start_idx: int) -> str:
    depth = 0
    in_str = False
    esc = False
    out: List[str] = []
    for i in range(start_idx, len(text)):
        ch = text[i]
        out.append(ch)
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
            continue

        if ch == '"':
            in_str = True
        elif ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                break
    return "".join(out)


def parse_name_entries(swift: str) -> List[NameEntry]:
    marker = "private var nameEntries: [NameEntry]"
    m = swift.find(marker)
    if m == -1:
        raise RuntimeError("Could not locate nameEntries in GameEngine.swift")
    text = swift[m:]

    entries: List[NameEntry] = []
    idx = 0
    while True:
        pos = text.find("NameEntry(", idx)
        if pos == -1:
            break
        call = extract_parenthesized(text, pos + len("NameEntry") )

        def field(name: str) -> str:
            fm = re.search(rf"{name}:\s*\"((?:\\.|[^\"\\])*)\"", call, flags=re.DOTALL)
            if not fm:
                raise RuntimeError(f"Missing field {name} in NameEntry")
            return decode_swift_string(fm.group(1)).strip()

        def int_field(name: str, default: int = 0) -> int:
            fm = re.search(rf"{name}:\s*(\d+)", call)
            if not fm:
                return default
            return int(fm.group(1))

        art_match = re.search(r"art:\s*\[(.*?)\],\s*power:", call, flags=re.DOTALL)
        if not art_match:
            raise RuntimeError("Missing art in NameEntry")
        art_inner = art_match.group(1)
        art = [decode_swift_string(x) for x in re.findall(r'\"((?:\\.|[^\"\\])*)\"', art_inner)]

        entries.append(
            NameEntry(
                name=field("name"),
                source=field("source"),
                description=field("description"),
                category=field("category"),
                art=art,
                power=int_field("power"),
                cunning=int_field("cunning"),
                magic=int_field("magic"),
                fame=int_field("fame"),
                charm=int_field("charm"),
            )
        )
        idx = pos + len(call)
    return entries


def parse_monsters(swift: str) -> List[MonsterEntry]:
    enum_match = re.search(r"enum MonsterType:.*?\{(.*?)\n\s*struct Stats", swift, flags=re.DOTALL)
    if not enum_match:
        raise RuntimeError("Could not locate MonsterType enum")
    enum_body = enum_match.group(1)
    ordered_cases = re.findall(r'case\s+(\w+)\s*=\s*\"([^\"]+)\"', enum_body)

    stats_matches = re.finditer(
        r'case\s+\.(\w+):\s*\n\s*return Stats\(hp:\s*(\d+),\s*ac:\s*(\d+),\s*attackBonus:\s*(\d+),\s*damage:\s*\"([^\"]+)\",\s*cr:\s*([0-9.]+),\s*xp:\s*(\d+)\)',
        swift,
        flags=re.DOTALL,
    )
    stats_map: Dict[str, dict] = {
        m.group(1): {
            "hp": int(m.group(2)),
            "ac": int(m.group(3)),
            "attack_bonus": int(m.group(4)),
            "damage": m.group(5),
            "cr": m.group(6),
            "xp": int(m.group(7)),
        }
        for m in stats_matches
    }

    desc_block = re.search(r"var description: String \{\s*switch self \{(.*?)\n\s*\}\n\s*\}\n", swift, flags=re.DOTALL)
    if not desc_block:
        raise RuntimeError("Could not parse monster descriptions")
    desc_map = {
        m.group(1): decode_swift_string(m.group(2))
        for m in re.finditer(r'case\s+\.(\w+):\s*return\s+\"((?:\\.|[^\"\\])*)\"', desc_block.group(1))
    }

    art_block = re.search(r"var asciiArt: \[String\] \{\s*switch self \{(.*?)\n\s*\}\n\s*\}\n\n\s*/// Animation frames", swift, flags=re.DOTALL)
    if not art_block:
        raise RuntimeError("Could not parse monster asciiArt")
    art_map: Dict[str, List[str]] = {}
    for m in re.finditer(r"case\s+\.(\w+):\s*\n\s*return\s*\[(.*?)\n\s*\]", art_block.group(1), flags=re.DOTALL):
        key = m.group(1)
        lines = [decode_swift_string(s) for s in re.findall(r'\"((?:\\.|[^\"\\])*)\"', m.group(2))]
        art_map[key] = lines

    monsters: List[MonsterEntry] = []
    for key, display_name in ordered_cases:
        if key not in stats_map or key not in desc_map or key not in art_map:
            raise RuntimeError(f"Missing parsed data for monster {key}")
        s = stats_map[key]
        monsters.append(
            MonsterEntry(
                key=key,
                name=display_name,
                hp=s["hp"],
                ac=s["ac"],
                attack_bonus=s["attack_bonus"],
                damage=s["damage"],
                cr=s["cr"],
                xp=s["xp"],
                description=desc_map[key],
                art=art_map[key],
            )
        )
    return monsters


def load_font(size: int, mono: bool = True) -> ImageFont.FreeTypeFont:
    candidates = [
        "/System/Library/Fonts/Menlo.ttc",
        "/System/Library/Fonts/Supplemental/Courier New.ttf",
    ] if mono else [
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/SFNS.ttf",
    ]
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def draw_stat_bar(draw: ImageDraw.ImageDraw, x: int, y: int, label: str, value: int, width: int, font: ImageFont.ImageFont):
    draw.text((x, y), f"{label}", fill="#A7F0B2", font=font)
    bar_x = x + 140
    bar_w = width - 220
    bar_h = 20
    draw.rounded_rectangle((bar_x, y + 6, bar_x + bar_w, y + 6 + bar_h), radius=6, fill="#173120")
    fill_w = int(max(0, min(10, value)) / 10 * bar_w)
    draw.rounded_rectangle((bar_x, y + 6, bar_x + fill_w, y + 6 + bar_h), radius=6, fill="#4ED16C")
    draw.text((bar_x + bar_w + 12, y), str(value), fill="#A7F0B2", font=font)


def render_name_card(entry: NameEntry, out_path: Path):
    w, h = 1200, 1700
    im = Image.new("RGB", (w, h), "#030703")
    d = ImageDraw.Draw(im)

    title_f = load_font(58, mono=False)
    sub_f = load_font(34, mono=False)
    mono_f = load_font(38, mono=True)
    stat_f = load_font(32, mono=True)
    body_f = load_font(30, mono=False)

    card = (80, 80, w - 80, h - 80)
    d.rounded_rectangle(card, radius=28, fill="#091209", outline="#3EAF57", width=4)

    title = entry.name
    tw = d.textbbox((0, 0), title, font=title_f)[2]
    d.text(((w - tw) / 2, 130), title, fill="#82FF9C", font=title_f)

    subtitle = entry.source
    sw = d.textbbox((0, 0), subtitle, font=sub_f)[2]
    d.text(((w - sw) / 2, 210), subtitle, fill="#A7F0B2", font=sub_f)

    d.line((140, 280, w - 140, 280), fill="#3EAF57", width=3)

    y = 330
    for line in entry.art:
        lw = d.textbbox((0, 0), line, font=mono_f)[2]
        d.text(((w - lw) / 2, y), line, fill="#93F2AA", font=mono_f)
        y += 46

    d.line((140, y + 10, w - 140, y + 10), fill="#3EAF57", width=3)
    y += 40

    if entry.category == "hero":
        stats = [
            ("Power", entry.power),
            ("Cunning", entry.cunning),
            ("Magic", entry.magic),
            ("Fame", entry.fame),
            ("Charm", entry.charm),
        ]
    else:
        stats = [
            ("Danger", entry.power),
            ("Puzzle", entry.cunning),
            ("Magic", entry.magic),
            ("Fame", entry.fame),
            ("Dread", entry.charm),
        ]

    for label, val in stats:
        draw_stat_bar(d, 170, y, label, val, width=w - 340, font=stat_f)
        y += 54

    y += 10
    d.line((140, y, w - 140, y), fill="#2E6B3F", width=2)
    y += 28

    for para in textwrap.wrap(entry.description, width=62):
        d.text((170, y), para, fill="#9CCAA6", font=body_f)
        y += 40
        if y > h - 130:
            break

    out_path.parent.mkdir(parents=True, exist_ok=True)
    im.save(out_path)


def render_monster_card(entry: MonsterEntry, out_path: Path):
    w, h = 1200, 1700
    im = Image.new("RGB", (w, h), "#030703")
    d = ImageDraw.Draw(im)

    title_f = load_font(56, mono=False)
    sub_f = load_font(34, mono=False)
    mono_f = load_font(34, mono=True)
    stat_f = load_font(34, mono=True)
    body_f = load_font(30, mono=False)

    card = (80, 80, w - 80, h - 80)
    d.rounded_rectangle(card, radius=28, fill="#091209", outline="#3EAF57", width=4)

    tw = d.textbbox((0, 0), entry.name, font=title_f)[2]
    d.text(((w - tw) / 2, 130), entry.name, fill="#82FF9C", font=title_f)

    subtitle = "Monster"
    sw = d.textbbox((0, 0), subtitle, font=sub_f)[2]
    d.text(((w - sw) / 2, 210), subtitle, fill="#A7F0B2", font=sub_f)

    d.line((140, 280, w - 140, 280), fill="#3EAF57", width=3)

    y = 330
    for line in entry.art:
        lw = d.textbbox((0, 0), line, font=mono_f)[2]
        d.text(((w - lw) / 2, y), line, fill="#93F2AA", font=mono_f)
        y += 42

    y += 8
    d.line((140, y, w - 140, y), fill="#3EAF57", width=3)
    y += 28

    stat_lines = [
        f"HP: {entry.hp}        AC: {entry.ac}",
        f"ATK: +{entry.attack_bonus}     DMG: {entry.damage}",
        f"CR: {entry.cr}        XP: {entry.xp}",
    ]
    for line in stat_lines:
        lw = d.textbbox((0, 0), line, font=stat_f)[2]
        d.text(((w - lw) / 2, y), line, fill="#A7F0B2", font=stat_f)
        y += 48

    y += 10
    d.line((140, y, w - 140, y), fill="#2E6B3F", width=2)
    y += 28

    for para in textwrap.wrap(entry.description, width=62):
        d.text((170, y), para, fill="#9CCAA6", font=body_f)
        y += 40
        if y > h - 130:
            break

    out_path.parent.mkdir(parents=True, exist_ok=True)
    im.save(out_path)


def build_unique_paths(entries: List[NameEntry], folder: Path) -> Dict[int, Path]:
    counts: Dict[str, int] = {}
    out: Dict[int, Path] = {}
    for i, e in enumerate(entries):
        base = slugify(e.name)
        counts[base] = counts.get(base, 0) + 1
        if counts[base] == 1:
            slug = base
        else:
            slug = f"{base}-{slugify(e.source)}"
        out[i] = folder / f"{i + 1:03d}-{slug}.png"
    return out


def write_markdown_pages(players: List[dict], locations: List[dict], monsters: List[dict]) -> None:
    def write_category_page(title: str, rel_path: str, items: List[dict], intro: str) -> None:
        path = OUT_ROOT / rel_path
        lines = [f"# {title}", "", intro, ""]
        for i, item in enumerate(items, start=1):
            name = item["name"]
            image = item["image"]
            source = item.get("source", "")
            detail = f" - {source}" if source else ""
            lines.append(f"{i}. [{name}]({image}){detail}")
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    write_category_page(
        title="Player Cards",
        rel_path="players.md",
        items=players,
        intro="Hyperlinked index of all player cards exported from iOS Name Lore hero entries.",
    )
    write_category_page(
        title="Location Cards",
        rel_path="locations.md",
        items=locations,
        intro="Hyperlinked index of all location cards exported from iOS Name Lore dungeon entries.",
    )
    write_category_page(
        title="Monster Cards",
        rel_path="monsters.md",
        items=monsters,
        intro="Hyperlinked index of all monster cards exported from iOS Bestiary definitions.",
    )

    index = OUT_ROOT / "README.md"
    index_lines = [
        "# iOS Card Exports",
        "",
        "Generated card image catalogs from the iOS codebase.",
        "",
        "## Browse",
        "",
        "1. [Player Cards](players.md)",
        "2. [Location Cards](locations.md)",
        "3. [Monster Cards](monsters.md)",
        "4. [Card Dex Viewer](card-dex/index.html)",
        "",
    ]
    index.write_text("\n".join(index_lines), encoding="utf-8")


def main() -> None:
    game_swift = GAME_ENGINE.read_text(encoding="utf-8")
    combat_swift = COMBAT_MODELS.read_text(encoding="utf-8")

    name_entries = parse_name_entries(game_swift)
    monsters = parse_monsters(combat_swift)

    heroes = [e for e in name_entries if e.category == "hero"]
    locations = [e for e in name_entries if e.category == "dungeon"]

    if OUT_ROOT.exists():
        for p in OUT_ROOT.rglob("*.png"):
            p.unlink()

    player_cards: List[dict] = []
    location_cards: List[dict] = []
    monster_cards: List[dict] = []

    hero_paths = build_unique_paths(heroes, OUT_ROOT / "players")
    for i, e in enumerate(heroes):
        out_path = hero_paths[i]
        render_name_card(e, out_path)
        player_cards.append({
            "id": f"player-{i + 1:03d}",
            "type": "player",
            "name": e.name,
            "source": e.source,
            "description": e.description,
            "stats": {
                "Power": e.power,
                "Cunning": e.cunning,
                "Magic": e.magic,
                "Fame": e.fame,
                "Charm": e.charm,
            },
            "image": str(out_path.relative_to(OUT_ROOT)),
        })

    location_paths = build_unique_paths(locations, OUT_ROOT / "locations")
    for i, e in enumerate(locations):
        out_path = location_paths[i]
        render_name_card(e, out_path)
        location_cards.append({
            "id": f"location-{i + 1:03d}",
            "type": "location",
            "name": e.name,
            "source": e.source,
            "description": e.description,
            "stats": {
                "Danger": e.power,
                "Puzzle": e.cunning,
                "Magic": e.magic,
                "Fame": e.fame,
                "Dread": e.charm,
            },
            "image": str(out_path.relative_to(OUT_ROOT)),
        })
    for m in monsters:
        out_path = OUT_ROOT / "monsters" / f"{slugify(m.name)}.png"
        render_monster_card(m, out_path)
        monster_cards.append({
            "id": f"monster-{m.key}",
            "type": "monster",
            "name": m.name,
            "source": "Bestiary",
            "description": m.description,
            "stats": {
                "HP": m.hp,
                "AC": m.ac,
                "ATK": f"+{m.attack_bonus}",
                "DMG": m.damage,
                "CR": m.cr,
                "XP": m.xp,
            },
            "image": str(out_path.relative_to(OUT_ROOT)),
        })

    write_markdown_pages(player_cards, location_cards, monster_cards)
    cards_json = {
        "players": player_cards,
        "locations": location_cards,
        "monsters": monster_cards,
    }
    (OUT_ROOT / "cards.json").write_text(json.dumps(cards_json, indent=2), encoding="utf-8")
    (OUT_ROOT / "cards.js").write_text(
        "window.CARD_DATA = " + json.dumps(cards_json, indent=2) + ";\n",
        encoding="utf-8",
    )

    manifest = {
        "players": len(player_cards),
        "locations": len(location_cards),
        "monsters": len(monster_cards),
        "total": len(player_cards) + len(location_cards) + len(monster_cards),
    }
    (OUT_ROOT / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
