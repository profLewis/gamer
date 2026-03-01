# D&D 5e Text-Based RPG — iOS App

A native iOS port of the D&D 5e Text-Based RPG, featuring a terminal-style interface with green text on a black background.

## Features

### Terminal Interface
- Authentic retro terminal look with green-on-black theme
- Animated splash screen with ASCII dragon art
- Tap-based menu selection with long-press shortcuts
- Back buttons and Main Menu exit in all screens
- Persistent ASCII dungeon minimap during exploration
- Text input for naming characters and dungeons
- Configurable font size (small, medium, large)

### Full D&D 5e Implementation (OGL)
- **12 Races**: Human, Elf (High/Wood), Dwarf (Hill/Mountain), Halfling (Lightfoot/Stout), Half-Elf, Half-Orc, Gnome, Tiefling, Dragonborn
- **6 Classes**: Fighter, Wizard, Rogue, Cleric, Ranger, Barbarian
- **18 Skills**: Full skill proficiency system
- **Spellcasting**: Cantrips and spell slots for Wizard, Cleric, Ranger

### Dungeon Exploration
- Procedurally generated multi-level dungeons
- 11 room types: corridors, chambers, treasure, traps, shrines, libraries, armories, prisons, boss rooms, and more
- Persistent ASCII minimap with dynamic key (only shows symbols present)
- Search, collect, rest, and shop mechanics
- Trap rooms with automatic triggers (poison darts, pit traps, flame jets, etc.)

### Combat System
- D20-based attack rolls with advantage/disadvantage
- Critical hits and misses, death saving throws
- Class features: Sneak Attack, Rage, Second Wind, Hunter's Mark
- **Dodge**: Grants attackers disadvantage on their next attack
- **Play Dead**: Bluff with CHA + Deception to escape combat
- **Flee**: Escape to the previous room
- **Poison**: Venomous creatures can poison characters (CON save DC 14 to recover)
- Creative actions via the AI Dungeon Master
- Monsters with flavourful attack descriptions

### AI Dungeon Master

The game has three tiers of DM intelligence:

1. **Basic DM** (all devices) — A simple built-in DM with canned responses. Works everywhere but gives only very basic room descriptions and atmosphere. No AI, no setup needed.
2. **Apple On-Device AI** (iPhone 16 / iPad with M-series or newer, running iOS 26+) — A much smarter DM that runs entirely on your device. No API key, no account, works offline. May refuse some queries — try rephrasing if needed.
3. **Cloud AI** (any device) — The best DM experience. Supports Claude (Anthropic), GPT (OpenAI), and **Gemini (Google — free if you have a Google account, ages 18+)**. Requires an API key configured in Settings.

Features:
- 4 DM ad-lib levels: Off, Flavor Only, Moderate, Full
- At Moderate+, the DM can grant items, award gold, heal, deal damage, move the party, and teleport
- DM actions update the game world in real time (map, inventory, HP)
- ASCII art responses when asked to draw or show something
- **DM Voice**: Text-to-speech reads DM responses aloud (built into iOS)

### Save System
- Multiple save slots with automatic breakpoints (up to 5 per slot)
- Configurable autosave interval
- Load any breakpoint from a slot's history
- Rename and delete save slots

### Hall of Fame & Game Center
- Scoring: victories, gold, monsters slain, exploration, difficulty multiplier
- Game Center leaderboards and achievements

## Platform Support

| Platform  | Minimum Version |
|-----------|----------------|
| iPhone    | iOS 16.0       |
| iPad      | iPadOS 16.0    |

## Requirements

- Xcode 15.0+ (for building)
- Apple Developer account (free or paid) for device installation

## Building the App

### Simulator

1. Open the project in Xcode:
   ```bash
   cd ios/DnDTextRPG
   open DnDTextRPG.xcodeproj
   ```

2. Select a simulator from the device menu (e.g. "iPhone 17 Pro")

3. Press Cmd+R to build and run

### Installing on a Physical iPhone

1. Connect your iPhone to your Mac via USB (or use Wi-Fi pairing)

2. Open the project in Xcode:
   ```bash
   cd ios/DnDTextRPG
   open DnDTextRPG.xcodeproj
   ```

3. Select your iPhone from the device dropdown in the Xcode toolbar

4. If this is your first time:
   - Go to **Xcode > Settings > Accounts** and sign in with your Apple ID
   - In the project settings, under **Signing & Capabilities**, select your team
   - Xcode will automatically create a provisioning profile

5. On your iPhone, go to **Settings > General > VPN & Device Management** and trust your developer certificate (first time only)

6. Press Cmd+R to build and install

### Command-Line Installation

```bash
# Build for iPhone
xcodebuild -project ios/DnDTextRPG/DnDTextRPG.xcodeproj \
  -scheme DnDTextRPG \
  -destination 'platform=iOS,name=iPhone' \
  -configuration Debug

# Install on device
xcrun devicectl device install app --device <DEVICE_UDID> \
  ~/Library/Developer/Xcode/DerivedData/DnDTextRPG-*/Build/Products/Debug-iphoneos/DnDTextRPG.app
```

## Project Structure

```
ios/DnDTextRPG/
├── DnDTextRPG.xcodeproj/     # Xcode project file
└── DnDTextRPG/
    ├── DnDTextRPGApp.swift   # App entry point
    ├── Views/
    │   ├── ContentView.swift  # Main view with splash
    │   └── TerminalView.swift # Terminal UI components
    ├── Models/
    │   ├── TerminalModels.swift    # Terminal display models
    │   ├── CharacterModels.swift   # Character, race, class, status effects
    │   ├── DungeonModels.swift     # Dungeon, rooms, minimap
    │   └── CombatModels.swift      # Combat, monsters, poison, attacks
    ├── Game/
    │   └── GameEngine.swift   # Main game logic (~5000+ lines)
    ├── Utils/
    │   ├── Dice.swift         # Dice rolling utilities
    │   ├── DMEngine.swift     # AI DM (Apple, Claude, GPT, Gemini)
    │   ├── SpeechEngine.swift # Text-to-speech for DM voice
    │   ├── SoundManager.swift # Music and sound effects
    │   └── SaveGameManager.swift  # Save/load system
    └── Assets.xcassets/       # App icons and colors
```

## Gameplay

### Main Menu
- **New Game**: Create a party and start a new adventure
- **Load Game**: Resume a saved game
- **Hall of Fame**: View high scores
- **How to Play**: View instructions
- **Settings**: AI provider, DM level, voice, font size, autosave
- **Quit**: Exit the game

### Character Creation
1. Choose party size (1-4 characters, or Random Party)
2. Name each character (or long-press to auto-generate)
3. Select race (with ability bonuses)
4. Select class (determines HP and abilities)
5. Assign ability scores (Standard Array or 4d6 drop lowest)
6. Choose skill proficiencies
7. Name your dungeon and select difficulty

Use **< Back** at any step to return to the previous choice.

### Exploration
- ASCII dungeon minimap always visible at the top
- Move through the dungeon using directional buttons (N/S/E/W)
- Search rooms, collect treasure, visit merchants
- Check party status and inventory
- Rest to recover HP (short or long rest)
- Ask the DM for hints, lore, or creative actions
- Save your game at any time
- Exit to Main Menu when needed

### Combat
- Combat triggers automatically when entering rooms with enemies
- Initiative determines turn order
- Attack, cast spells, dodge, play dead, flee, or ask the DM
- Dodge gives attackers disadvantage
- Play Dead uses CHA + Deception to bluff monsters
- Flee escapes to the previous room
- Beware of poison from venomous creatures
- Defeat all enemies to win — or suffer a party wipe

### Tips
- Long-press a button to auto-fill all remaining choices
- Hold the screen to speed up rest animations
- The DM can move your party, give items, and affect HP
- Trap rooms trigger automatically — some also have monsters!

## Open Gaming License

This game implements mechanics from the **Dungeons & Dragons 5th Edition System Reference Document (SRD)**, published by Wizards of the Coast under the **Open Gaming License (OGL) v1.0a**.

All game mechanics, including races, classes, spells, monsters, ability scores, combat rules, and encounter systems are derived from the D&D 5e SRD which is freely available under the OGL.

D&D, Dungeons & Dragons, and their respective logos are trademarks of Wizards of the Coast LLC. This project is not affiliated with, endorsed, or sponsored by Wizards of the Coast.

The source code for this game is provided as-is for educational and entertainment purposes.

## Author

Created by **Prof. Lewis**, assisted by [Claude](https://claude.ai) (Anthropic).

Source code: [github.com/profLewis/gamer](https://github.com/profLewis/gamer)
