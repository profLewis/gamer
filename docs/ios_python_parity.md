# iOS to Python Parity Matrix

This document tracks reconciliation between the iOS game flow and the Python terminal game.

## Main Navigation

| iOS Feature | Python Status | Notes |
|---|---|---|
| Continue Quest | Implemented | Main Menu now includes `Continue Quest` and loads latest save. |
| Play Menu | Implemented | New sub-menu: New Adventure, Saved Adventures, Multiplayer Matches. |
| Hall of Fame | Implemented | Main Menu and System Menu expose scoreboard/hall view. |
| How to Play | Implemented | 12 core topics plus extra gallery hooks in terminal. |
| Settings | Implemented | Tree-style settings menu with DM/Accessibility/Mood/Gameplay/Saving. |

## Character and Adventure Setup

| iOS Feature | Python Status | Notes |
|---|---|---|
| Party size 1-4 with random option | Implemented | `0` now chooses random size 1-4. |
| Name suggestions + custom names | Implemented | Character and dungeon naming now offer suggestions from `ios_card_images/cards.json`. |
| Race/Class/Ability setup | Implemented | Existing Python flow retained and integrated with new menu hierarchy. |

## In-Game Experience

| iOS Feature | Python Status | Notes |
|---|---|---|
| System menu from exploration | Implemented | Expanded to include Hall of Fame, How to Play, Settings. |
| Map visibility option | Implemented | `map_radius` setting applied to map rendering. |
| Gameplay toggles | Implemented | Card navigation, NPCs, multiplayer, adventure log toggles in settings. |
| DM provider settings | Implemented | AI backend and timeout exposed via settings and CLI flags. |

## Help, Lore, and Galleries

| iOS Feature | Python Status | Notes |
|---|---|---|
| Bestiary topic | Implemented | Interactive bestiary with ASCII art, stats, traits, and action tips. |
| NPC topic / Rogues Gallery | Implemented | iOS named roster + runtime roles + markdown NPC gallery access. |
| In-room NPC interaction | Implemented | Exploration now supports `Talk to NPC` with dialogue trees, contextual advice, and quest/shop effects. |
| Name Lore topic | Implemented | Card-lore browser from iOS card dataset. |
| FAQ corpus and lookup | Implemented | Python imports iOS `FAQData.swift` entries for browse/search and DM FAQ-grounded replies. |
| Races/Rooms gallery content | Implemented | Reads and displays markdown content from `gallery/`. |

## Style and Controls

| iOS Feature | Python Status | Notes |
|---|---|---|
| Green-on-black terminal style | Implemented | Existing theme retained and configurable in settings. |
| Arrow-key navigation | Implemented | Existing interactive menu behavior now user-toggleable. |
| CLI options for play style | Implemented | Added `--map-radius`, `--no-arrow-keys`, `--no-card-nav`, `--no-npcs`, `--no-multiplayer`. |

## Known Gaps

| Area | Gap |
|---|---|
| Audio/Voice | iOS speech and music systems are not replicated in Python terminal mode. |
| Touch/UI widgets | iOS tap/long-press/mobile UX patterns cannot be mirrored directly in CLI. |
| Voice/audio platform features | iOS speech/music controls remain platform-specific and are not mirrored in CLI runtime. |
