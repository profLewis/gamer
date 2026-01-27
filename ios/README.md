# D&D 5e Text-Based RPG - iOS App

A native iOS port of the D&D 5e Text-Based RPG, featuring a terminal-style interface with green text on a black background.

## Features

### Terminal Interface
- Authentic retro terminal look with green-on-black theme
- Animated splash screen with ASCII dragon art
- Tap-based menu selection (no keyboard required for most actions)
- Text input for naming characters and dungeons

### Full D&D 5e Implementation
- **12 Races**: Human, Elf (High/Wood), Dwarf (Hill/Mountain), Halfling (Lightfoot/Stout), Half-Elf, Half-Orc, Gnome, Tiefling, Dragonborn
- **6 Classes**: Fighter, Wizard, Rogue, Cleric, Ranger, Barbarian
- **18 Skills**: Full skill proficiency system
- **Combat**: Turn-based with initiative, attack rolls, and damage

### Dungeon Exploration
- Procedurally generated dungeons
- Multiple room types (treasure, traps, shrines, etc.)
- ASCII map display
- Search and collect mechanics

### Combat System
- D20-based attack rolls
- Critical hits and misses
- Multiple monster types with different stats
- Boss encounters

## Requirements

- iOS 16.0 or later
- iPhone or iPad
- Xcode 15.0+ (for building)

## Building the App

1. Open the project in Xcode:
   ```bash
   cd ios/DnDTextRPG
   open DnDTextRPG.xcodeproj
   ```

2. Select your target device or simulator

3. Press Cmd+R to build and run

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
- **How to Play**: View instructions
- **Quit**: Exit the app

### Character Creation
1. Choose party size (1-4 characters)
2. Name each character
3. Select race (with ability bonuses)
4. Select class (determines HP and abilities)
5. Assign ability scores (Standard Array or 4d6 drop lowest)
6. Choose skill proficiencies

### Exploration
- Move through the dungeon using directional buttons
- Search rooms for hidden treasure
- Collect loot from cleared rooms
- View the dungeon map
- Check party status
- Rest to recover HP

### Combat
- Combat triggers automatically when entering rooms with enemies
- Initiative determines turn order
- Tap enemy names to attack
- Defeat all enemies to win
- Party wipe = game over

## Screenshots

The app features a classic terminal aesthetic:
- Black background
- Green monospace text
- ASCII art and box-drawing characters
- Retro gaming feel

## Credits

Based on the D&D 5th Edition System Reference Document (SRD) by Wizards of the Coast, available under the Open Gaming License (OGL).

## License

This project is for educational and entertainment purposes. D&D and Dungeons & Dragons are trademarks of Wizards of the Coast LLC.
