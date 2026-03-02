# D&D 5e Text Adventure

A retro terminal-style Dungeons & Dragons 5th Edition RPG for iOS, with AI Dungeon Master support.

![Dragon](dragon_animation.gif)

## Features

### Character Creation
- **12 Races**: Human, High Elf, Wood Elf, Hill Dwarf, Mountain Dwarf, Lightfoot Halfling, Stout Halfling, Half-Elf, Half-Orc, Rock Gnome, Tiefling, Dragonborn
- **6 Classes**: Fighter, Wizard, Rogue, Cleric, Ranger, Barbarian
- **Ability Scores**: Standard array or 4d6 drop lowest
- **18 Skills** with proficiency system
- **Parties** of 1-4 characters (human or AI-controlled)
- **Long-press** any party size to auto-generate an all-AI party

### Combat (D&D 5e Rules)
- Initiative, attack rolls, saving throws, critical hits
- Death saving throws (nat 20 revive, nat 1 double failure)
- Class features: Sneak Attack, Rage, Second Wind, Hunter's Mark
- **Dodge** grants attackers disadvantage on their next attack
- **Play Dead** — bluff your way out of a fight (CHA + Deception check)
- **Flee** — escape to the previous room
- Creative actions via the AI DM
- Monsters grouped by type with numbered targeting
- **Poison** — venomous creatures can poison party members (CON save to recover)

### Spellcasting
- **Wizard**: Fire Bolt, Ray of Frost, Magic Missile, Burning Hands, Sleep
- **Cleric**: Sacred Flame, Cure Wounds, Guiding Bolt, Healing Word, Spare the Dying
- **Ranger**: Hunter's Mark, Cure Wounds
- Cantrips (unlimited) and spell slots that recover on long rest

### Procedural Dungeons
- 11 room types: corridors, chambers, treasure rooms, armories, shrines, libraries, prisons, trap rooms, boss chambers, and more
- ASCII minimap showing only visited rooms with dynamic key (only shows symbols present on the map)
- Encounters and traps scaled by dungeon level
- Treasure, equipment, potions, and a merchant in armory rooms
- Multi-level progression — defeat the boss to descend deeper

### 30 Monsters

The dungeon is home to 30 different creature types, from lowly rats and kobolds to terrifying beholders and dragons.

![Bestiary](all_monsters.png)

### AI Dungeon Master

The game has three tiers of DM intelligence:

1. **Basic DM** (all devices) — A simple built-in DM with canned responses. Works everywhere but gives only very basic room descriptions and atmosphere. No AI, no setup needed.
2. **Apple On-Device AI** (iPhone 16 / iPad with M-series or newer, iOS 26+) — A much smarter DM that runs entirely on your device. No API key, no account, works offline. May be fussy with some queries — try rephrasing if it won't answer.
3. **Cloud AI** (any device) — The best DM experience. Supports Claude (Anthropic), GPT (OpenAI), and **Gemini (Google — free if you have a Google account, ages 18+)**. Requires an API key configured in Settings.

Features:
- 4 DM levels: Off, Flavor Only, Moderate, Full
- At Moderate+, the DM can grant items, award gold, heal, deal damage, move the party, and teleport
- Ask the DM during exploration or combat for creative actions
- DM actions update the world state in real time (map, inventory, HP)
- ASCII art responses when you ask the DM to draw something
- **DM Voice** — text-to-speech reads DM responses aloud (built into iOS, no API key needed)

### Save System
- Save slots with automatic breakpoints (up to 5 per slot)
- Autosave on room changes (configurable interval)
- Load any breakpoint from a slot's history
- Rename and delete save slots

### Hall of Fame
- Scoring: victories, gold, monsters slain, exploration, difficulty multiplier
- Pre-seeded with Stranger Things-themed entries

### Game Center
- Leaderboards: Gold collected, Victories, Monsters slain
- 6 Achievements: First Blood, Dungeon Master, Hoarder, Slayer, Veteran, Legend

## Interface

Green-on-black terminal aesthetic with monospaced text, ASCII art for characters and monsters, and a D-pad for dungeon navigation. Configurable font size (small, medium, large).

## Building

Requires Xcode 15.0+. Open `ios/DnDTextRPG/DnDTextRPG.xcodeproj` and build for iOS 16.0+.

See [ios/README.md](ios/README.md) for detailed build instructions.

## Credits

- **Created by** Prof. Lewis
- **AI assistance** by Claude (Anthropic)
- **A Timbaloo app**

## License

Game mechanics from the D&D 5e System Reference Document under the Open Gaming License v1.0a. Dungeons & Dragons is a trademark of Wizards of the Coast LLC.
