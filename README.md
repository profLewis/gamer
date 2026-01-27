# D&D 5e Text-Based RPG

A text-based Dungeons & Dragons 5th Edition role-playing game in Python where the computer acts as Dungeon Master, supporting multiple human or AI-controlled players.

## Features

### Character System (D&D 5e Faithful)
- **Ability Scores**: STR, DEX, CON, INT, WIS, CHA with standard modifiers
- **Generation Methods**: Standard array [15,14,13,12,10,8] or 4d6 drop lowest
- **Races**: Human, Elf (High/Wood), Dwarf (Hill/Mountain), Halfling (Lightfoot/Stout), Half-Elf, Half-Orc, Gnome, Tiefling, Dragonborn
- **Classes**: Fighter, Wizard, Rogue, Cleric, Ranger, Barbarian (levels 1-5)
- **Skills**: All 18 skills with proficiency and expertise system

### Combat System (D&D 5e Faithful)
- **Initiative**: d20 + DEX modifier, descending order
- **Action Economy**: Action, Bonus Action, Movement, Reaction per turn
- **Attacks**: d20 + proficiency + ability mod vs AC
- **Damage**: Weapon dice + ability modifier
- **Saving Throws**: d20 + ability mod (+ proficiency if proficient)
- **Death Saves**: 3 successes = stable, 3 failures = death

### Spell System
- **Spell Slots**: Per class table (Wizard: INT-based, Cleric: WIS-based)
- **Cantrips**: Unlimited use
- **Spell Save DC**: 8 + proficiency + spellcasting ability mod
- **Concentration**: One spell at a time

### AI Dungeon Master
- **Narration**: Procedural descriptions for rooms, events, NPCs
- **Dungeon Generation**: Rooms, corridors, doors, traps, treasure
- **Encounter Balancing**: CR-based encounter difficulty (Easy/Medium/Hard/Deadly)

### AI Players
- **Combat AI**: Target selection, ability usage
- **Personality System**: Aggressive/Cautious/Balanced/Supportive
- **Cooperation**: Heal allies, focus fire, protect weak party members

### Multiplayer Support
- **Shared File Mode**: Play with friends on the same local network (NFS, SMB, or shared folders)
- **Network Socket Mode**: Direct TCP connection for play across networks
- **Real-time sync**: Game state synchronized between all players
- **Chat system**: Send messages to other players while playing

### Enhanced Display
- **ASCII Character Art**: Visual representations of each class (Fighter, Wizard, Rogue, Cleric, Ranger, Barbarian)
- **Enhanced Map**: Detailed dungeon map with room connections, doors, and legend
- **Combat Scene**: Visual display of party vs enemies during combat
- **HP Bars**: Graphical health bars for characters and monsters

## Installation

### Requirements
- Python 3.8+
- Optional: `colorama` for colored terminal output

### Quick Start

```bash
# Clone the repository
git clone <repository-url>
cd gamer

# Optional: Install colorama for colors
pip install colorama

# Run the game
python run_game.py
```

## How to Play

### Starting a New Game
1. Run `python run_game.py`
2. Select "New Game" from the main menu
3. Enter a name for your adventure
4. Create your party (1-4 characters)
5. Choose human or AI control for each character
6. Complete character creation for all characters
7. Name your dungeon and select difficulty
8. Begin exploring!

### Exploration Commands
- **Go North/South/East/West**: Move through dungeon passages
- **Search Room**: Look for hidden items and secret doors
- **Take a Rest**: Short rest (1 hour) or Long rest (8 hours)
- **Party Status**: View detailed character information
- **View Map**: See explored areas
- **Collect Treasure**: Pick up loot from cleared rooms
- **Save Game**: Save your progress
- **Quit to Menu**: Return to main menu

### Combat
When encountering enemies, combat begins automatically:
1. Initiative is rolled for all combatants
2. On your turn, choose from available actions:
   - **Attack**: Make a weapon attack
   - **Cast Spell**: Use a spell (if available)
   - **Dodge**: Disadvantage on attacks against you
   - **Dash**: Double your movement
   - **Disengage**: Move without provoking opportunity attacks
   - **Help**: Give an ally advantage
3. Combat continues until one side is defeated

### Character Creation
1. **Name**: Enter your character's name
2. **Race**: Choose from available races (each has unique bonuses)
3. **Class**: Select your class (determines abilities and playstyle)
4. **Ability Scores**: Assign scores using standard array or rolled values
5. **Skills**: Choose proficiencies from your class's skill list

### Multiplayer

#### Hosting a Game

**Shared File Mode** (for players on the same local network with shared folders):
1. Select "Multiplayer" from the main menu
2. Choose "Host Game (Shared File - Local Network)"
3. Enter your player name and session name
4. Share the session ID with other players
5. Wait for players to join, then press Enter to start

**Network Socket Mode** (for play across networks):
1. Select "Multiplayer" from the main menu
2. Choose "Host Game (Network Socket)"
3. Enter your player name
4. Share your IP:port (displayed on screen) with other players
5. Wait for players to join, then press Enter to start

#### Joining a Game

**Shared File Mode**:
1. Ensure you have access to the same shared folder as the host
2. Select "Multiplayer" → "Join Game (Shared File)"
3. Enter your player name
4. Enter the session ID provided by the host
5. Wait for the host to start the game

**Network Socket Mode**:
1. Select "Multiplayer" → "Join Game (Network Socket)"
2. Enter your player name
3. Enter the host's IP:port (e.g., `192.168.1.100:5555`)
4. Wait for the host to start the game

## Project Structure

```
gamer/
├── run_game.py             # Entry point script
├── gamer/
│   ├── __init__.py
│   ├── main.py             # Main game loop
│   ├── game/
│   │   ├── engine.py       # Game state management
│   │   ├── dm.py           # AI Dungeon Master
│   │   ├── session.py      # Save/load functionality
│   │   └── multiplayer.py  # Multiplayer networking
│   ├── characters/
│   │   ├── character.py    # Character class
│   │   ├── races.py        # D&D 5e races
│   │   ├── classes.py      # D&D 5e classes
│   │   ├── abilities.py    # Ability scores & modifiers
│   │   ├── skills.py       # Skills & proficiencies
│   │   └── spells.py       # Spell system
│   ├── combat/
│   │   ├── combat.py       # Combat encounter manager
│   │   ├── initiative.py   # Initiative tracker
│   │   └── actions.py      # Combat actions
│   ├── world/
│   │   ├── dungeon.py      # Procedural dungeon generation
│   │   ├── encounters.py   # Encounter generation
│   │   ├── monsters.py     # Monster stat blocks
│   │   ├── items.py        # Equipment & items
│   │   └── npcs.py         # NPC generation
│   ├── players/
│   │   ├── player.py       # Player interface
│   │   ├── human_player.py # CLI input handler
│   │   └── ai_player.py    # AI decision making
│   ├── utils/
│   │   ├── dice.py         # Dice rolling utilities
│   │   ├── display.py      # Text formatting
│   │   └── ascii_art.py    # ASCII character & map rendering
│   └── data/
│       ├── races.json      # Race definitions
│       ├── classes.json    # Class definitions
│       ├── spells.json     # Spell database
│       ├── monsters.json   # Monster database
│       └── items.json      # Item database
```

## Game Mechanics Reference

### Ability Scores
| Score | Modifier |
|-------|----------|
| 1     | -5       |
| 2-3   | -4       |
| 4-5   | -3       |
| 6-7   | -2       |
| 8-9   | -1       |
| 10-11 | 0        |
| 12-13 | +1       |
| 14-15 | +2       |
| 16-17 | +3       |
| 18-19 | +4       |
| 20    | +5       |

### Proficiency Bonus by Level
| Level | Bonus |
|-------|-------|
| 1-4   | +2    |
| 5-8   | +3    |
| 9-12  | +4    |
| 13-16 | +5    |
| 17-20 | +6    |

### Encounter Difficulty (XP Thresholds)
| Level | Easy | Medium | Hard | Deadly |
|-------|------|--------|------|--------|
| 1     | 25   | 50     | 75   | 100    |
| 2     | 50   | 100    | 150  | 200    |
| 3     | 75   | 150    | 225  | 400    |
| 4     | 125  | 250    | 375  | 500    |
| 5     | 250  | 500    | 750  | 1100   |

## Rules References

This game implements rules from the **Dungeons & Dragons 5th Edition** System Reference Document (SRD), which is available under the Open Gaming License (OGL).

### Sources
- **D&D 5e SRD**: The core mechanics, races, classes, spells, and monsters are based on the D&D 5th Edition System Reference Document published by Wizards of the Coast under the OGL.
- **Basic Rules**: Additional information from the D&D Basic Rules, freely available from Wizards of the Coast.

### Key Rule Implementations
- **Combat**: Follows 5e combat rules including initiative, action economy, attack rolls, damage, and saving throws
- **Spellcasting**: Implements spell slots, spell preparation, and spell effects per 5e rules
- **Character Creation**: Uses standard 5e character creation with races, classes, and backgrounds
- **Monster Statistics**: Monster stat blocks follow the 5e format with Challenge Rating (CR) for encounter balancing

## License

This project implements mechanics from the D&D 5e SRD under the Open Gaming License v1.0a. Dungeons & Dragons, D&D, and their respective logos are trademarks of Wizards of the Coast LLC.

The source code for this game is provided as-is for educational and entertainment purposes.

## Contributing

Contributions are welcome! Areas for improvement include:
- Additional races and classes
- More spells and monsters
- Enhanced AI behavior
- Graphical user interface
- Multiplayer support
- More dungeon generation variety

## Acknowledgments

- Wizards of the Coast for the D&D 5e System Reference Document
- The D&D community for inspiration and feedback
