#!/usr/bin/env python3
from pathlib import Path
import json
import re
import sys


SEARCH_PATTERNS = [
    r"youtube\.com/results\?",
    r"amazon\.[^/\" ]+/s\?k=",
    r"abebooks\.com/servlet/SearchResults",
    r"worldofbooks\.com/.*/search\?",
    r"imdb\.com/find/\?q=",
    r"en\.wikipedia\.org/wiki/Special:Search\?search=",
]

# Card-dex entries covering actively-enforced trademarks (WotC Product Identity,
# Tolkien Estate/Middle-earth Enterprises, Mattel, Conan Properties, Red Sonja LLC,
# King Features, Warner Bros) per data/outputs/copyright_review.md. These must ship
# with no lore description text, in both the static lore pages and cards.json (the
# file lore.js actually fetches and renders from at runtime). Medium/low-risk
# entries may carry restored lore text per that audit's own prioritization.
HIGH_RISK_CARD_IDS = {
    "location-001", "location-002", "location-003", "location-004",
    "location-005", "location-006", "location-007", "location-008",
    "location-009", "location-010", "location-011", "location-012",
    "location-013", "location-014", "location-015",
    "location-030", "location-033", "location-034",
    "player-001", "player-002", "player-059",
    "player-027",
    "player-030", "player-052",
    "player-036",
    "player-041", "player-042", "player-043",
    "player-053", "player-057",
    "player-058", "player-060",
    "player-061", "player-078", "player-079",
}

# WotC Product Identity monster names that must never appear verbatim in shipped
# content (renamed in the Swift MonsterType enum; cards.json must match).
RETIRED_MONSTER_NAMES = {"Beholder", "Mind Flayer", "Displacer Beast", "Vecna", "Demogorgon"}


def fail(msg: str) -> None:
    print(f"FAIL: {msg}")


def main() -> int:
    repo = Path(__file__).resolve().parents[1]
    entities_dir = repo / "ios_card_images" / "card-dex" / "entities"
    lore_dir = repo / "ios_card_images" / "card-dex" / "lore"

    issues = 0
    rx = [re.compile(p, re.I) for p in SEARCH_PATTERNS]

    # 1) No site-search links in card content/scripts.
    scan_files = list(entities_dir.glob("*.html")) + list(lore_dir.glob("*.html")) + [
        lore_dir / "lore.js",
        repo / "bin" / "generate_ios_cards.py",
    ]
    for p in scan_files:
        if not p.exists():
            continue
        text = p.read_text(encoding="utf-8")
        for r in rx:
            if r.search(text):
                fail(f"search-style link pattern '{r.pattern}' found in {p}")
                issues += 1

    # 2) Entity summary policy: allow informative summaries, but cap overly long blocks.
    summary_rx = re.compile(r'<p class="summary">(.*?)</p>', re.S)
    for p in entities_dir.glob("*.html"):
        if p.name == "index.html":
            continue
        text = p.read_text(encoding="utf-8")
        for m in summary_rx.finditer(text):
            summary = re.sub(r"<[^>]+>", "", m.group(1)).strip()
            if len(summary.split()) > 130:
                fail(f"long summary (>130 words) in {p}")
                issues += 1

    # 3) Lore payload policy: high-risk entries must ship with no embedded
    # description body in the static lore page HTML source.
    for card_id in sorted(HIGH_RISK_CARD_IDS):
        p = lore_dir / f"{card_id}.html"
        if not p.exists():
            continue
        text = p.read_text(encoding="utf-8")
        if '"description": ""' not in text:
            fail(f'high-risk lore page missing sanitized description field in {p}')
            issues += 1

    # 4) cards.json is what lore.js actually fetches and renders at runtime, so it
    # must be held to the same policy as the static lore pages.
    cards_json_path = repo / "ios_card_images" / "cards.json"
    if cards_json_path.exists():
        cards = json.loads(cards_json_path.read_text(encoding="utf-8"))
        for key in ("players", "locations"):
            for card in cards.get(key, []):
                if card.get("id") in HIGH_RISK_CARD_IDS and card.get("description"):
                    fail(f'cards.json: high-risk card {card.get("id")} has a non-empty description')
                    issues += 1
        for monster in cards.get("monsters", []):
            if monster.get("name") in RETIRED_MONSTER_NAMES:
                fail(f'cards.json: retired WotC Product Identity monster name "{monster.get("name")}" still present ({monster.get("id")})')
                issues += 1

    if issues:
        print(f"\nPolicy check failed with {issues} issue(s).")
        return 1
    print("PASS: card text/link policy checks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
