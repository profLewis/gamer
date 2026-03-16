#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import textwrap
import unicodedata
from datetime import datetime, timezone
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List
from urllib.parse import quote
from urllib.request import Request, urlopen

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


@dataclass
class SourceEntity:
    source: str
    kind: str
    wiki_title: str | None
    wiki_url: str | None
    summary: str
    photo_remote_url: str | None
    photo_local_path: str | None
    entity_page: str
    entity_card_image: str


def decode_swift_string(s: str) -> str:
    # Avoid mojibake: only decode escape sequences when present.
    # Literal Unicode in source (for example em dash or symbols) should remain unchanged.
    if "\\" not in s:
        return s
    return bytes(s, "utf-8").decode("unicode_escape")


def sanitize_ascii_text(s: str) -> str:
    if not s:
        return s
    # Normalize common punctuation and frequent mojibake artifacts.
    replacements = {
        "—": "-",
        "–": "-",
        "−": "-",
        "“": '"',
        "”": '"',
        "’": "'",
        "‘": "'",
        "…": "...",
        "•": "-",
        "♥": "H",
        "ø": "o",
        "Ø": "O",
        "â€”": "-",
        "â€“": "-",
        "â€˜": "'",
        "â€™": "'",
        "â€œ": '"',
        "â€\x9d": '"',
        "â€¦": "...",
    }
    for a, b in replacements.items():
        s = s.replace(a, b)
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode("ascii")
    s = re.sub(r"\s+", " ", s).strip()
    return s


def slugify(s: str) -> str:
    s = s.lower().strip()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    s = re.sub(r"-+", "-", s).strip("-")
    return s


def source_kind(source: str) -> str:
    s = source.lower()
    if "d&d module" in s:
        return "module"
    if any(x in s for x in ["tolkien", "moorcock", "le guin", "pratchett", "howard", "asimov", "burroughs"]):
        return "author"
    if any(x in s for x in ["stranger things", "community", "futurama", "doctor who", "he-man", "thundercats", "dogtanian", "blake's 7", "robin of sherwood"]):
        return "tv"
    if any(x in s for x in ["star wars", "alien", "king kong", "forbidden planet", "honour among thieves", "willow", "labyrinth", "highlander", "legend", "dragonslayer", "neverending"]):
        return "movie"
    if "classic sci-fi" in s or "famous robots" in s:
        return "franchise"
    return "book"


def http_json(url: str) -> dict | list | None:
    req = Request(url, headers={"User-Agent": "DnDex/1.0 (+https://github.com/profLewis/gamer)"})
    try:
        with urlopen(req, timeout=20) as resp:
            if resp.status != 200:
                return None
            return json.loads(resp.read().decode("utf-8"))
    except Exception:
        return None


def wiki_best_match(query: str) -> tuple[str | None, dict | None]:
    search_url = (
        "https://en.wikipedia.org/w/api.php?action=opensearch&limit=1&namespace=0&format=json&search="
        + quote(query)
    )
    data = http_json(search_url)
    if not isinstance(data, list) or len(data) < 2 or not isinstance(data[1], list) or not data[1]:
        return None, None
    title = str(data[1][0])
    sum_url = f"https://en.wikipedia.org/api/rest_v1/page/summary/{quote(title)}"
    summary = http_json(sum_url)
    if not isinstance(summary, dict):
        return title, None
    return title, summary


def download_binary(url: str, dst: Path) -> bool:
    req = Request(url, headers={"User-Agent": "DnDex/1.0 (+https://github.com/profLewis/gamer)"})
    try:
        with urlopen(req, timeout=30) as resp:
            if resp.status != 200:
                return False
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(resp.read())
            return True
    except Exception:
        return False

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
            return sanitize_ascii_text(decode_swift_string(fm.group(1)).strip())

        def int_field(name: str, default: int = 0) -> int:
            fm = re.search(rf"{name}:\s*(\d+)", call)
            if not fm:
                return default
            return int(fm.group(1))

        art_match = re.search(r"art:\s*\[(.*?)\],\s*power:", call, flags=re.DOTALL)
        if not art_match:
            raise RuntimeError("Missing art in NameEntry")
        art_inner = art_match.group(1)
        art = [sanitize_ascii_text(decode_swift_string(x)) for x in re.findall(r'\"((?:\\.|[^\"\\])*)\"', art_inner)]

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
        m.group(1): sanitize_ascii_text(decode_swift_string(m.group(2)))
        for m in re.finditer(r'case\s+\.(\w+):\s*return\s+\"((?:\\.|[^\"\\])*)\"', desc_block.group(1))
    }

    art_block = re.search(r"var asciiArt: \[String\] \{\s*switch self \{(.*?)\n\s*\}\n\s*\}\n\n\s*/// Animation frames", swift, flags=re.DOTALL)
    if not art_block:
        raise RuntimeError("Could not parse monster asciiArt")
    art_map: Dict[str, List[str]] = {}
    for m in re.finditer(r"case\s+\.(\w+):\s*\n\s*return\s*\[(.*?)\n\s*\]", art_block.group(1), flags=re.DOTALL):
        key = m.group(1)
        lines = [sanitize_ascii_text(decode_swift_string(s)) for s in re.findall(r'\"((?:\\.|[^\"\\])*)\"', m.group(2))]
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
        "5. [Deep Source Cards](card-dex/entities/index.html)",
        "6. [Photo Sources](PHOTO_SOURCES.md)",
        "",
    ]
    index.write_text("\n".join(index_lines), encoding="utf-8")


def write_lore_pages(players: List[dict], locations: List[dict]) -> None:
    lore_root = OUT_ROOT / "card-dex" / "lore"
    lore_root.mkdir(parents=True, exist_ok=True)

    lore_css = """\
:root {
  --bg: #050805;
  --panel: #0b120c;
  --line: #2f8f4a;
  --text: #d6f2d8;
  --muted: #8baa8f;
  --accent: #6bff89;
}
* { box-sizing: border-box; }
body {
  margin: 0;
  min-height: 100vh;
  background: radial-gradient(circle at 20% 10%, #102114 0%, var(--bg) 45%), var(--bg);
  color: var(--text);
  font-family: "Avenir Next", "Trebuchet MS", sans-serif;
}
.wrap {
  max-width: 1000px;
  margin: 0 auto;
  padding: 16px;
}
.topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}
.back {
  color: #9ad8a7;
  text-decoration: none;
  border: 1px solid #2f6a3e;
  border-radius: 8px;
  padding: 6px 10px;
  background: #0a100b;
}
.lore-nav {
  margin-top: 10px;
  display: flex;
  align-items: center;
  gap: 8px;
}
.btn {
  color: #9ad8a7;
  border: 1px solid #2f6a3e;
  border-radius: 8px;
  padding: 6px 10px;
  background: #0a100b;
  cursor: pointer;
}
.lore-pos {
  margin-left: auto;
  color: #8baa8f;
  font-size: 0.85rem;
}
h1 {
  margin: 10px 0 2px;
  color: var(--accent);
  font-size: 1.9rem;
  font-family: "Copperplate", "Palatino Linotype", serif;
}
.meta { color: var(--muted); margin: 0 0 10px; }
.layout {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 14px;
}
.panel {
  border: 1px solid #1f5e34;
  border-radius: 12px;
  background: linear-gradient(180deg, rgba(12, 22, 14, 0.96), rgba(9, 14, 10, 0.98));
  padding: 12px;
}
.card-img {
  width: 100%;
  border-radius: 10px;
  border: 1px solid #2f673f;
  background: #070c08;
}
.wiki-img {
  width: 100%;
  border-radius: 10px;
  border: 1px solid #2f673f;
  background: #070c08;
  max-height: 420px;
  object-fit: contain;
}
.summary {
  margin-top: 10px;
  color: #b8d2bd;
  line-height: 1.45;
  text-align: justify;
  overflow-wrap: anywhere;
}
h2 {
  margin: 0 0 8px;
  color: #95d39f;
  font-size: 1.1rem;
}
.links {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
.links a {
  color: #8ce6a1;
  text-decoration: none;
  border: 1px solid #2f6a3e;
  border-radius: 8px;
  padding: 6px 9px;
  background: #0a100b;
  font-size: 0.9rem;
}
.small { color: #83a288; font-size: 0.8rem; margin-top: 8px; }
.source-profile {
  margin-top: 12px;
  border: 1px solid #215f36;
  border-radius: 10px;
  background: #08110b;
  padding: 10px;
}
.source-profile .label {
  color: #7ecf90;
  font-size: 0.75rem;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  margin-bottom: 4px;
}
.source-profile .value {
  color: #d9f6de;
  font-weight: 700;
  line-height: 1.25;
  margin-bottom: 8px;
}
.profile-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-bottom: 8px;
}
.profile-chip {
  font-size: 0.75rem;
  color: #b9e5c2;
  border: 1px solid #2c6d40;
  border-radius: 999px;
  padding: 3px 8px;
  background: #0b160d;
}
.source-links {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.source-links a {
  font-size: 0.8rem;
  color: #93ecaa;
  text-decoration: none;
  border: 1px solid #2a6a3d;
  border-radius: 8px;
  padding: 5px 8px;
  background: #0a130c;
}
.ace-cover-gallery {
  margin-top: 8px;
}
.ace-cover-grid {
  margin-top: 6px;
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
  gap: 8px;
}
.ace-cover-grid a {
  display: block;
  border: 1px solid #2b6b3e;
  border-radius: 8px;
  overflow: hidden;
  background: #08110b;
}
.ace-cover-grid img {
  width: 100%;
  height: 170px;
  object-fit: cover;
  display: block;
}
@media (max-width: 900px) {
  .layout { grid-template-columns: 1fr; }
}
"""

    lore_js = """\
const card = window.CARD;

function byId(id) { return document.getElementById(id); }

function q(s) { return encodeURIComponent(s); }

function outboundLinks(c) {
  const links = [];
  if (c.source_entity_page) {
    links.push({ label: 'Source Card', href: `../${c.source_entity_page}` });
  }
  return links;
}

async function findWikiTitle(query) {
  const url = `https://en.wikipedia.org/w/api.php?action=opensearch&search=${q(query)}&limit=1&namespace=0&format=json&origin=*`;
  const res = await fetch(url);
  if (!res.ok) return null;
  const data = await res.json();
  if (Array.isArray(data) && Array.isArray(data[1]) && data[1].length > 0) {
    return data[1][0];
  }
  return null;
}

async function fetchWikiSummary(title) {
  const url = `https://en.wikipedia.org/api/rest_v1/page/summary/${q(title)}`;
  const res = await fetch(url);
  if (!res.ok) return null;
  return await res.json();
}

async function loadWiki(c) {
  const queries = [
    `${c.name} ${c.source || ''}`.trim(),
    c.name,
    c.source || '',
  ].filter(Boolean);
  for (const query of queries) {
    try {
      const title = await findWikiTitle(query);
      if (!title) continue;
      const sum = await fetchWikiSummary(title);
      if (!sum || !sum.extract) continue;
      return { title, summary: sum };
    } catch (_) {}
  }
  return null;
}

function renderStatic(c) {
  byId('title').textContent = c.name;
  byId('meta').textContent = `${(c.type || '').toUpperCase()} - ${c.source || 'Reference'}`;
  byId('cardImg').src = `../../${c.image}`;
  byId('cardImg').alt = c.name;
  byId('summary').textContent = 'This lore panel uses project-written text only. For external facts, use the attributed references.';

  const links = outboundLinks(c);
  if (c.source_entity_page) {
    links.unshift({ label: 'Source Card', href: `../${c.source_entity_page}` });
  }
  const linksWrap = byId('links');
  for (const l of links) {
    const a = document.createElement('a');
    a.href = l.href;
    a.target = '_blank';
    a.rel = 'noopener noreferrer';
    a.textContent = l.label;
    linksWrap.appendChild(a);
  }
}

async function renderWiki(c) {
  const wiki = await loadWiki(c);
  if (!wiki) return;

  if (wiki.summary.thumbnail && wiki.summary.thumbnail.source) {
    const img = byId('wikiImg');
    img.src = wiki.summary.thumbnail.source;
    img.alt = `${wiki.title} reference image`;
    img.style.display = 'block';
  }
  if (wiki.summary.content_urls && wiki.summary.content_urls.desktop && wiki.summary.content_urls.desktop.page) {
    const a = document.createElement('a');
    a.href = wiki.summary.content_urls.desktop.page;
    a.target = '_blank';
    a.rel = 'noopener noreferrer';
    a.textContent = 'Wikipedia Article';
    byId('links').prepend(a);
  }
}

renderStatic(card);
renderWiki(card);
"""

    lore_template_head = """\
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>DnDex Lore</title>
  <link rel="stylesheet" href="lore.css" />
</head>
<body>
  <div class="wrap">
    <div class="topbar">
      <a class="back" href="../index.html">Back to DnDex</a>
    </div>
    <h1 id="title"></h1>
    <p id="meta" class="meta"></p>
    <div class="layout">
      <section class="panel">
        <h2>Card</h2>
        <img id="cardImg" class="card-img" alt="" />
      </section>
      <section class="panel">
        <h2>Reference</h2>
        <img id="wikiImg" class="wiki-img" alt="" style="display:none" />
        <p id="summary" class="summary"></p>
      </section>
    </div>
    <section class="panel" style="margin-top:14px">
      <h2>Find More</h2>
      <div id="links" class="links"></div>
      <p class="small">External links are provided for convenience and open in a new tab.</p>
    </section>
  </div>
"""
    lore_template_tail = """\
</body>
</html>
"""

    (lore_root / "lore.css").write_text(lore_css, encoding="utf-8")
    lore_js_path = lore_root / "lore.js"
    # Keep curated lore.js behavior if it already exists.
    if not lore_js_path.exists():
        lore_js_path.write_text(lore_js, encoding="utf-8")

    def write_one(card: dict) -> str:
        page_name = f"{card['id']}.html"
        page_path = lore_root / page_name
        lore_payload = dict(card)
        # Keep lore page payload lean per policy checks; full text is loaded at runtime from cards.json.
        lore_payload["description"] = ""
        payload = json.dumps(lore_payload, ensure_ascii=True)
        html = (
            lore_template_head
            + f"<script>window.CARD = {payload};</script>\n"
            + '<script src="lore.js"></script>\n'
            + lore_template_tail
        )
        page_path.write_text(html, encoding="utf-8")
        return f"card-dex/lore/{page_name}"

    for card in players + locations:
        card["lore_page"] = write_one(card)


def render_source_entity_card(entity: SourceEntity, out_path: Path) -> None:
    w, h = 1200, 1700
    im = Image.new("RGB", (w, h), "#030703")
    d = ImageDraw.Draw(im)
    title_f = load_font(56, mono=False)
    sub_f = load_font(30, mono=False)
    body_f = load_font(30, mono=False)

    d.rounded_rectangle((80, 80, w - 80, h - 80), radius=28, fill="#091209", outline="#3EAF57", width=4)

    title = entity.source
    tw = d.textbbox((0, 0), title, font=title_f)[2]
    d.text(((w - tw) / 2, 130), title, fill="#82FF9C", font=title_f)

    subtitle = f"{entity.kind.upper()} SOURCE CARD"
    sw = d.textbbox((0, 0), subtitle, font=sub_f)[2]
    d.text(((w - sw) / 2, 210), subtitle, fill="#A7F0B2", font=sub_f)
    d.line((140, 270, w - 140, 270), fill="#3EAF57", width=3)

    y = 300
    if entity.photo_local_path:
        img_path = OUT_ROOT / entity.photo_local_path
        if img_path.exists():
            try:
                p = Image.open(img_path).convert("RGB")
                p.thumbnail((w - 220, 700))
                x = (w - p.width) // 2
                im.paste(p, (x, y))
                y += p.height + 20
            except Exception:
                pass

    d.line((140, y, w - 140, y), fill="#2E6B3F", width=2)
    y += 20

    summary = entity.summary or "Reference material for this source."
    for line in textwrap.wrap(summary, width=62):
        d.text((170, y), line, fill="#9CCAA6", font=body_f)
        y += 38
        if y > h - 150:
            break

    out_path.parent.mkdir(parents=True, exist_ok=True)
    im.save(out_path)


def write_source_entities(cards: List[dict]) -> Dict[str, SourceEntity]:
    entities_dir = OUT_ROOT / "entities"
    photos_dir = entities_dir / "photos"
    cards_dir = entities_dir / "cards"
    pages_dir = OUT_ROOT / "card-dex" / "entities"
    pages_dir.mkdir(parents=True, exist_ok=True)

    unique_sources = sorted({c.get("source", "").strip() for c in cards if c.get("source")})
    entities: Dict[str, SourceEntity] = {}
    provenance_rows: List[dict] = []

    def compose_source_summary(source: str, kind: str) -> str:
        if source.startswith("Ace Double D-"):
            m = re.search(r"(D-\\d+)\\s*\\((\\d{4})\\)", source)
            code = m.group(1) if m else "D-series"
            year = m.group(2) if m else "the period"
            return (
                f"Ace Double {code} ({year}) reflects the two-in-one paperback format that paired works "
                "for contrast, discovery, and collector appeal. It is used here as a compact inspiration "
                "source for mixed-genre tone in default DnDex naming."
            )

        if kind == "movie":
            return (
                f"This film entry describes how {source} contributes atmosphere, archetypes, and pacing cues "
                "to the default DnDex source set. It is written from information in the referenced sources "
                "listed on this page."
            )
        if kind == "tv":
            return (
                f"This television source card outlines how {source} informs recurring character types and "
                "world texture used by default game names. It is written from information in the referenced "
                "sources listed on this page."
            )
        if kind == "author":
            return (
                f"This author page frames {source} as a creative root for style, setting motifs, and naming "
                "patterns in the default DnDex references. It is written from information in the referenced "
                "sources listed on this page."
            )
        if kind == "module":
            return (
                f"This module entry highlights how {source} shapes dungeon logic, encounter rhythm, and place "
                "naming in the default DnDex corpus. It is written from information in the referenced sources "
                "listed on this page."
            )
        if kind == "book":
            return (
                f"This book source card maps {source} to the fantasy and science-fantasy flavor used by default "
                "DnDex entities. It is written from information in the referenced sources listed on this page."
            )
        return (
            f"This source card positions {source} as part of the inspiration layer behind default DnDex content. "
            "It is written from information in the referenced sources listed on this page."
        )

    for source in unique_sources:
        kind = source_kind(source)
        queries = [source, re.sub(r"\s*\(\d{4}\)\s*$", "", source)]
        title = None
        summary = None
        for q in queries:
            q = q.strip()
            if not q:
                continue
            t, s = wiki_best_match(q)
            if t:
                title = t
            if s:
                summary = s
                break

        wiki_url = None
        summary_text = compose_source_summary(source, kind)
        remote_photo = None
        local_photo = None
        if isinstance(summary, dict):
            desktop = summary.get("content_urls", {}).get("desktop", {})
            if isinstance(desktop, dict):
                wiki_url = desktop.get("page")
            thumb = summary.get("thumbnail", {})
            if isinstance(thumb, dict):
                remote_photo = thumb.get("source")
        if not wiki_url and title:
            wiki_url = f"https://en.wikipedia.org/wiki/{quote(title.replace(' ', '_'))}"

        if remote_photo:
            ext = ".jpg"
            if isinstance(remote_photo, str) and remote_photo.lower().endswith(".png"):
                ext = ".png"
            local_name = f"{slugify(source)}{ext}"
            local_path = photos_dir / local_name
            if download_binary(remote_photo, local_path):
                local_photo = str(local_path.relative_to(OUT_ROOT))
                provenance_rows.append({
                    "source": source,
                    "local_photo": local_photo,
                    "wiki_title": title or "",
                    "wiki_page": wiki_url or "",
                    "image_url": remote_photo,
                    "retrieved_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                })

        entity_page = f"card-dex/entities/{slugify(source)}.html"
        entity_card_image = f"entities/cards/{slugify(source)}.png"
        entity = SourceEntity(
            source=source,
            kind=kind,
            wiki_title=title,
            wiki_url=wiki_url,
            summary=summary_text,
            photo_remote_url=remote_photo,
            photo_local_path=local_photo,
            entity_page=entity_page,
            entity_card_image=entity_card_image,
        )
        entities[source] = entity

        render_source_entity_card(entity, OUT_ROOT / entity_card_image)

        # Per-entity page in DnDex style
        photo_html = (
            f'<img class="wiki-img" src="../../{local_photo}" alt="{source} image" />'
            if local_photo else '<p class="small">No local photo available for this source yet.</p>'
        )
        wiki_btn = (
            f'<a href="{wiki_url}" target="_blank" rel="noopener noreferrer">Wikipedia</a>'
            if wiki_url else ""
        )
        source_links = []
        links_html = "".join(
            f'<a href="{u}" target="_blank" rel="noopener noreferrer">{label}</a>' for label, u in source_links
        )
        html = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>{source} - DnDex Source</title>
  <link rel="stylesheet" href="../lore/lore.css" />
</head>
<body>
  <div class="wrap">
    <div class="topbar">
      <a class="back" href="../index.html">Back to DnDex</a>
    </div>
    <nav id="entityNav" class="entity-nav" aria-label="Source card navigation">
  <button id="entityBackBtn" class="btn" type="button">Back</button>
  <button id="entityPrevBtn" class="btn" type="button">Prev</button>
  <button id="entityDiceBtn" class="btn" type="button">d20</button>
  <button id="entityNextBtn" class="btn" type="button">Next</button>
</nav>
    <h1>{source}</h1>
    <p class="meta">{kind.upper()} source card</p>
    <div class="layout">
      <section class="panel">
        <h2>Source Card</h2>
        <img class="card-img" src="../../{entity_card_image}" alt="{source} source card" />
      </section>
      <section class="panel">
        <h2>Photo</h2>
        {photo_html}
        <p class="summary">{summary_text}</p>
      </section>
    </div>
    <section class="panel" style="margin-top:14px">
      <h2>External Links</h2>
      <div class="links">{wiki_btn}{links_html}</div>
      <p class="small">This page aggregates references to the source material behind Name Lore entries.</p>
    </section>
  </div>
  <script src="./entity-nav.js"></script>
  <script src="./entity-enhance.js"></script>
  <script src="./entity-references.js"></script>
</body>
</html>
"""
        (pages_dir / f"{slugify(source)}.html").write_text(html, encoding="utf-8")

    # Index page for all entities
    entity_cards = []
    for e in entities.values():
        entity_cards.append(
            f'<a class="entity-card" href="./{slugify(e.source)}.html"><img src="../../{e.entity_card_image}" alt="{e.source}"><span>{e.source}</span></a>'
        )
    index_html = """<!doctype html>
<html lang="en"><head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>DnDex Sources</title>
<style>
body{margin:0;background:#050805;color:#d6f2d8;font-family:Arial,sans-serif}
.wrap{padding:16px;max-width:1100px;margin:0 auto}
a{color:#8ce6a1}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:12px}
.entity-card{display:flex;flex-direction:column;gap:6px;text-decoration:none;border:1px solid #2f6a3e;border-radius:10px;padding:8px;background:#091209}
.entity-card img{width:100%;aspect-ratio:3/4;object-fit:cover;border-radius:8px;border:1px solid #2f673f}
.entity-card span{color:#b8d2bd;font-size:0.9rem}
</style>
</head><body><div class="wrap">
<p><a href="../index.html">Back to DnDex</a></p>
<h1>Deep Source Cards</h1>
<p>Authors, films, TV, modules, and reference worlds behind the in-game default names.</p>
<div class="grid">""" + "".join(entity_cards) + "</div></div></body></html>"
    (pages_dir / "index.html").write_text(index_html, encoding="utf-8")

    # Provenance markdown for local photos
    prov_md = OUT_ROOT / "PHOTO_SOURCES.md"
    lines = [
        "# DnDex Photo Sources",
        "",
        "Local copies of reference photos used in source/entity pages.",
        "",
        "| Source | Local File | Wiki Page | Remote Image URL | Retrieved (UTC) |",
        "|---|---|---|---|---|",
    ]
    for row in provenance_rows:
        lines.append(
            f"| {row['source']} | `{row['local_photo']}` | {row['wiki_page']} | {row['image_url']} | {row['retrieved_at_utc']} |"
        )
    prov_md.write_text("\n".join(lines) + "\n", encoding="utf-8")

    return entities


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

    source_entities = write_source_entities(player_cards + location_cards)
    for card in player_cards + location_cards:
        ent = source_entities.get(card.get("source", ""))
        if ent:
            card["source_entity_page"] = ent.entity_page
            card["source_entity_card"] = ent.entity_card_image

    write_lore_pages(player_cards, location_cards)
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
