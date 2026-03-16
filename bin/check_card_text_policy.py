#!/usr/bin/env python3
from pathlib import Path
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

    # 3) Lore payload policy: no embedded long description bodies in HTML source.
    for p in lore_dir.glob("*.html"):
        text = p.read_text(encoding="utf-8")
        if '"description": ""' not in text:
            fail(f'lore page missing sanitized description field in {p}')
            issues += 1

    if issues:
        print(f"\nPolicy check failed with {issues} issue(s).")
        return 1
    print("PASS: card text/link policy checks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
