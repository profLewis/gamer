# D&D 5e Text Adventure

A retro terminal-style Dungeons & Dragons 5th Edition RPG for iOS, with AI Dungeon Master support.

<p align="center">
  <img src="data/splash.jpg" width="300" alt="D&D Text Adventure splash screen">
</p>

## Features

### Character Creation
- **12 Races**: Human, High Elf, Wood Elf, Hill Dwarf, Mountain Dwarf, Lightfoot Halfling, Stout Halfling, Half-Elf, Half-Orc, Rock Gnome, Tiefling, Dragonborn
- **6 Classes**: Fighter, Wizard, Rogue, Cleric, Ranger, Barbarian
- **Ability Scores**: Standard array or 4d6 drop lowest
- **18 Skills** with proficiency system
- **Parties** of 1-4 characters

### Combat (D&D 5e Rules)
- Initiative, attack rolls, saving throws, critical hits
- Death saving throws (nat 20 revive, nat 1 double failure)
- Class features: Sneak Attack, Rage, Second Wind
- Dodge, flee, and creative actions via the DM
- Monsters grouped by type with numbered targeting

### Spellcasting
- **Wizard**: Fire Bolt, Ray of Frost, Magic Missile, Burning Hands, Sleep
- **Cleric**: Sacred Flame, Cure Wounds, Guiding Bolt, Healing Word, Spare the Dying
- **Ranger**: Hunter's Mark, Cure Wounds
- Cantrips (unlimited) and spell slots that recover on long rest

### Procedural Dungeons
- 10 room types: corridors, chambers, treasure rooms, armories, shrines, boss chambers, and more
- ASCII map with explored rooms, danger markers, and boss location
- Encounters scaled by dungeon level
- Treasure, equipment, potions, and a merchant in armory rooms

### AI Dungeon Master
- Supports **Claude** (Anthropic), **GPT** (OpenAI), and **Gemini** (Google)
- 4 DM levels: Off, Flavor Only, Moderate, Full (can grant items and gold)
- Ask the DM during exploration or combat for creative actions
- Persistent conversation context

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

Green-on-black terminal aesthetic with monospaced text, ASCII art for characters and monsters, and a D-pad for dungeon navigation.

## Building

Requires Xcode. Open `ios/DnDTextRPG/DnDTextRPG.xcodeproj` and build for iOS.

## Credits

- **Created by** Prof. Lewis
- **AI assistance** by Claude (Anthropic)
- **A Timbaloo app**

## License

Game mechanics from the D&D 5e System Reference Document under the Open Gaming License v1.0a. Dungeons & Dragons is a trademark of Wizards of the Coast LLC.
