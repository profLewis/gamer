# D&D 5e Text-Based RPG — iOS & macOS App

A native iOS and macOS port of the D&D 5e Text-Based RPG, featuring a terminal-style interface with green text on a black background.

## Features

### Terminal Interface
- Authentic retro terminal look with green-on-black theme
- Animated splash screen with cross-stitch dragon art
- Tap-based menu selection with long-press shortcuts
- Back buttons and Main Menu exit in all screens
- Persistent ASCII dungeon minimap during exploration
- Text input for naming characters and dungeons
- Configurable font size (small, medium, large, extra large)
- Swipe-left to go back from any screen
- Custom on-screen keyboard
- Undo/redo for character editing, party review, and settings
- Colour-coded buttons: green (actions), dim green (navigation), cyan (chat/multiplayer), amber (NPCs/special), red (destructive)

### Full D&D 5e Implementation (OGL)
- **12 Races**: Human, Elf (High/Wood), Dwarf (Hill/Mountain), Halfling (Lightfoot/Stout), Half-Elf, Half-Orc, Gnome, Tiefling, Dragonborn
- **6 Classes**: Fighter, Wizard, Cleric, Rogue, Ranger, Barbarian
- **18 Skills**: Full skill proficiency system
- **Spellcasting**: Cantrips and spell slots for Wizard, Cleric, Ranger

### Dungeon Exploration
- Procedurally generated multi-level dungeons
- 11 room types: corridors, chambers, treasure, traps, shrines, libraries, armories, prisons, boss rooms, and more
- Persistent ASCII minimap with dynamic key (only shows symbols present)
- Search, collect, rest, and shop mechanics
- Trap rooms with automatic triggers (poison darts, pit traps, flame jets, etc.)
- Barricade doors behind you (long-press direction buttons)
- Listen at doors to hear what lies ahead
- Dark mode exploration — douse your torch to sneak past monsters

### 30 Monsters
- Full bestiary with ASCII art for every creature
- Monsters scaled by dungeon level
- Flavourful attack descriptions
- Venomous creatures with poison mechanics

### 13 NPCs
- Friendly NPCs appear in dungeon rooms: Wandering Trader, Prisoner, Hermit, Ghostly Scholar, Dwarven Smith, Elf Scout, Goblin Defector, Mysterious Stranger, Wounded Knight, Mad Alchemist, Old Priestess, Rat Catcher, Gatekeeper
- Talk to NPCs for quests, healing, item repair, and dungeon lore
- Gatekeeper at the entrance offers gold rewards for clearing the dungeon

### Combat System
- D20-based attack rolls with advantage/disadvantage
- Critical hits and misses, death saving throws
- Class features: Sneak Attack, Rage, Second Wind, Hunter's Mark
- **Dodge**: Grants attackers disadvantage on their next attack
- **Play Dead**: Bluff with CHA + Deception to escape combat
- **Flee**: Escape to the previous room
- **Poison**: Venomous creatures can poison characters (CON save DC 14 to recover)
- Creative actions via the AI Dungeon Master

### AI Dungeon Master

The game has three tiers of DM intelligence:

1. **Basic DM** (all devices) — A simple built-in DM with canned responses. Works everywhere but gives only very basic room descriptions and atmosphere. No AI, no setup needed.
2. **Apple On-Device AI** (iPhone 16 / iPad with M-series or newer, running iOS 26+) — A much smarter DM that runs entirely on your device. No API key, no account, works offline. May refuse some queries — try rephrasing if needed.
3. **Cloud AI** (any device) — The best DM experience. Supports Claude (Anthropic), GPT (OpenAI), and **Gemini (Google — free if you have a Google account, ages 18+)**. Requires an API key configured in Settings.

Features:
- 4 DM ad-lib levels: Off, Flavour Only, Moderate, Full
- At Moderate+, the DM can grant items, award gold, heal, deal damage, move the party, and teleport
- DM actions update the game world in real time (map, inventory, HP)
- ASCII art responses when asked to draw or show something
- **DM Voice**: Text-to-speech reads DM responses aloud (built into iOS)
- **Speaker Mode**: Persistent narration toggle — tap the speaker icon to have story text read aloud continuously

### Voice Input
- Microphone icon for speech-to-text input
- Works in chat, menu selection, and text entry
- Voice menu control (enable in Accessibility settings)

### Save System
- Multiple save slots with automatic breakpoints (up to 5 per slot)
- Configurable autosave interval
- Load any breakpoint from a slot's history
- Rename and delete save slots

### Multiplayer
- Turn-based async multiplayer via Game Center
- Host controls exploration; each player controls their own character in combat
- Party chat with @mentions
- Invite friends mid-game or during party setup
- Nudge idle players
- Remote games shown in cyan in the Play menu with status indicators

### Hall of Fame & Game Center
- Scoring: victories, gold, monsters slain, exploration, difficulty multiplier
- Game Center leaderboards and achievements

### Help System
- 12 help topics: Getting Started, Exploration, Combat, Character & Party, Recovery, Dungeon Master, Multiplayer, Tips & Tricks, FAQs, Bestiary, NPCs, Name Lore
- 50+ FAQ entries organised by topic with DM knowledge lookup
- Context-weighted gameplay tips
- In-game bestiary with ASCII art and stats for all 30 monsters
- NPC bestiary with descriptions and services
- Name Lore gallery with Top Trump-style cards and pop culture origins

## Platform Support

| Platform  | Minimum Version |
|-----------|----------------|
| iPhone    | iOS 16.0       |
| iPad      | iPadOS 16.0    |
| Mac       | macOS 13.0     |

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
    │   ├── ContentView.swift  # Main view with splash screen
    │   └── TerminalView.swift # Terminal UI, input, D-pad, GIF view
    ├── Models/
    │   ├── TerminalModels.swift    # Terminal display models
    │   ├── CharacterModels.swift   # Character, race, class, status effects
    │   ├── DungeonModels.swift     # Dungeon, rooms, minimap
    │   ├── CombatModels.swift      # Combat, monsters, poison, attacks
    │   ├── ItemModels.swift        # Weapons, armour, potions, items
    │   ├── SpellModels.swift       # Spells and spell slots
    │   ├── NPCModels.swift         # Dungeon NPCs (13 types)
    │   ├── MultiplayerModels.swift # Multiplayer state and sync
    │   ├── SaveGameModels.swift    # Save/load data structures
    │   ├── HallOfFame.swift        # Hall of Fame scoring
    │   ├── StateSnapshot.swift     # Game state snapshots
    │   └── StateDiff.swift         # State diffing for multiplayer
    ├── Game/
    │   └── GameEngine.swift   # Main game logic (~20,000+ lines)
    ├── Utils/
    │   ├── Dice.swift              # Dice rolling utilities
    │   ├── DMEngine.swift          # AI DM (Apple, Claude, GPT, Gemini)
    │   ├── SpeechEngine.swift      # Text-to-speech for DM voice
    │   ├── SoundManager.swift      # Music and sound effects
    │   ├── GameCenterManager.swift # Game Center integration
    │   ├── StateSnapshotManager.swift # Save/load system
    │   ├── FAQData.swift           # FAQ entries and DM knowledge lookup
    │   └── VoiceInputManager.swift # Speech-to-text input
    └── Assets.xcassets/       # App icons, dragon art, and colours
```

## Gameplay

### Main Menu
- **Play**: Start a new game, load a saved game, or join a multiplayer match
- **Hall of Fame**: View high scores and past adventures
- **How to Play**: 12 help topics, FAQs, bestiary, Name Lore
- **Settings**: AI provider, DM level, voice, font size, autosave, sound, accessibility

### Character Creation
1. Choose party size (1-4 characters, or Random Party)
2. Name each character (or press return for a random name)
3. Select race (with ability bonuses)
4. Select class (determines HP and abilities)
5. Assign ability scores (Standard Array or 4d6 drop lowest)
6. Choose skill proficiencies
7. Name your dungeon and select difficulty

Use **long-press** at any step to auto-fill all remaining choices.

### Exploration
- ASCII dungeon minimap always visible at the top
- Move through the dungeon using directional buttons (N/S/E/W) or the D-pad
- Search rooms, collect treasure, visit merchants
- Talk to NPCs for quests, healing, and lore
- Check party status and inventory
- Rest to recover HP (tap for short rest, long-press for long rest)
- Ask the DM for hints, lore, or creative actions
- Save your game at any time
- Press return with empty input to move in a random available direction

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
- Long-press buttons for hidden shortcuts throughout the game
- Hold the Rest button for a fast long rest
- Long-press a direction to barricade a door
- Douse your torch to sneak past monsters
- The DM can move your party, give items, and affect HP
- Type button names or numbers at the prompt instead of tapping
- Swipe left to go back from any screen

## Open Gaming License

This game implements mechanics from the **Dungeons & Dragons 5th Edition System Reference Document (SRD)**, published by Wizards of the Coast under the **Open Gaming License (OGL) v1.0a**.

All game mechanics, including races, classes, spells, monsters, ability scores, combat rules, and encounter systems are derived from the D&D 5e SRD which is freely available under the OGL.

D&D, Dungeons & Dragons, and their respective logos are trademarks of Wizards of the Coast LLC. This project is not affiliated with, endorsed, or sponsored by Wizards of the Coast.

The source code for this game is provided as-is for educational and entertainment purposes.

## Author

Created by **Prof. Lewis**, assisted by [Claude](https://claude.ai) (Anthropic).

Source code: [github.com/profLewis/gamer](https://github.com/profLewis/gamer)
