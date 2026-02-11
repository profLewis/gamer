# D&D 5e Text-Based RPG - iOS & tvOS App

A native iOS and Apple TV port of the D&D 5e Text-Based RPG, featuring a terminal-style interface with green text on a black background.

## Features

### Terminal Interface
- Authentic retro terminal look with green-on-black theme
- Animated splash screen with ASCII dragon art
- Tap-based menu selection (no keyboard required for most actions)
- Back buttons in all menus for easy navigation
- Persistent ASCII dungeon map during exploration
- Text input for naming characters and dungeons

### Full D&D 5e Implementation (OGL)
- **12 Races**: Human, Elf (High/Wood), Dwarf (Hill/Mountain), Halfling (Lightfoot/Stout), Half-Elf, Half-Orc, Gnome, Tiefling, Dragonborn
- **6 Classes**: Fighter, Wizard, Rogue, Cleric, Ranger, Barbarian
- **18 Skills**: Full skill proficiency system
- **Combat**: Turn-based with initiative, attack rolls, and damage

### Dungeon Exploration
- Procedurally generated dungeons
- Multiple room types (treasure, traps, shrines, etc.)
- Persistent ASCII map with room connections
- Search and collect mechanics

### Combat System
- D20-based attack rolls
- Critical hits and misses
- Multiple monster types with different stats
- Boss encounters

## Platform Support

| Platform  | Minimum Version |
|-----------|----------------|
| iPhone    | iOS 16.0       |
| iPad      | iPadOS 16.0    |
| Apple TV  | tvOS 16.0      |

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

2. Select a simulator from the device menu (e.g. "iPhone 17 Pro" or "Apple TV")

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

### Apple TV

1. Ensure your Apple TV is on the same network as your Mac
2. In Xcode, go to **Window > Devices and Simulators** and pair your Apple TV
3. Select your Apple TV from the device dropdown
4. Press Cmd+R to build and install

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
    │   ├── CharacterModels.swift   # Character, race, class
    │   ├── DungeonModels.swift     # Dungeon and rooms
    │   └── CombatModels.swift      # Combat and monsters
    ├── Game/
    │   └── GameEngine.swift   # Main game logic
    ├── Utils/
    │   └── Dice.swift         # Dice rolling utilities
    └── Assets.xcassets/       # App icons and colors
```

## Gameplay

### Main Menu
- **New Game**: Start a new adventure
- **Load Game**: Resume a saved game (coming soon)
- **How to Play**: View instructions and OGL notice
- **Quit**: Return to title screen

### Character Creation
1. Choose party size (1-4 characters)
2. Name each character
3. Select race (with ability bonuses)
4. Select class (determines HP and abilities)
5. Assign ability scores (Standard Array or 4d6 drop lowest)
6. Choose skill proficiencies

Use **< Back** at any step to return to the previous choice.

### Exploration
- ASCII dungeon map always visible at the top of screen
- Move through the dungeon using directional buttons
- Search rooms for hidden treasure
- Collect loot from cleared rooms
- Check party status
- Rest to recover HP

### Combat
- Combat triggers automatically when entering rooms with enemies
- Initiative determines turn order
- Tap enemy names to attack
- Defeat all enemies to win
- Party wipe = game over

## Open Gaming License

This game implements mechanics from the **Dungeons & Dragons 5th Edition System Reference Document (SRD)**, published by Wizards of the Coast under the **Open Gaming License (OGL) v1.0a**.

All game mechanics, including races, classes, spells, monsters, ability scores, combat rules, and encounter systems are derived from the D&D 5e SRD which is freely available under the OGL.

D&D, Dungeons & Dragons, and their respective logos are trademarks of Wizards of the Coast LLC. This project is not affiliated with, endorsed, or sponsored by Wizards of the Coast.

The source code for this game is provided as-is for educational and entertainment purposes.

## Author

Created by **Prof. Lewis**, assisted by [Claude](https://claude.ai) (Anthropic).

Source code: [github.com/profLewis/gamer](https://github.com/profLewis/gamer)
