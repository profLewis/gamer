# Dungeons & Dragons 5e Text RPG — Version 2.4

## What's New in Version 2.4

### Victory Screen Overhaul
- Rich D&D-flavoured narrative when you conquer a dungeon — references your party, the boss you defeated, and your accomplishments
- Boxed "Spoils of Victory" stats display with gold, monsters slain, combats won, XP, rooms explored
- Party hero listing showing HP and levels
- "The Depths Beckon" teaser encouraging you to descend to the next level
- Save & Continue, Continue, Save & End, and End Adventure options
- Encourages saving before descending deeper

### Multiplayer Improvements
- **Clear turn indicators**: Play menu now shows `>> YOUR TURN <<` in bold green, `Waiting for partner...`, or `Partner left` status
- **Button labels include status**: `[YOUR TURN]`, `[INVITE]`, `[SOLO]`, `[waiting]`
- **Invitation decline handling**: When a player declines an invite, the host is immediately notified and can continue as a local game with AI companions
- **Lobby polling**: The host lobby now polls for match status changes to detect declined/quit players in real time
- **Clearer prompts**: "Play Now" / "Accept Invite" instead of generic "Connect"; "Decline" instead of "Ignore"
- **Crash robustness**: Fixed race conditions in multiplayer state sync, nudge timers, and match polling
- **Nudge/pass-turn fix**: Fixed conflict when passing turn while nudge countdown is active
- **Live action echo**: Active player's actions appear on the waiting player's screen in real time
- **Scrollable waiting screens**: All multiplayer waiting/catch-up screens are now scrollable

### Hall of Fame
- **Replay from Hall of Fame now works**: Victory and defeat entries now link to a save game, so you can tap "Relive" or "Rewrite History" to replay any recorded adventure

### UI & Quality of Life
- Character indicator: `◀` marker shows which character you control locally
- Rest clock: System clock ticks during rest showing hours elapsing
- Undo/redo isolation: Undo/redo stacks are strictly local to each screen
- Save slot limit: Maximum 10 save slots enforced, oldest deleted automatically
- "Since your last turn" prettified with box borders in multiplayer

---

## Complete Feature List

### Core Gameplay
- **D&D 5e Rules**: Faithful implementation of D&D 5th Edition mechanics
- **6 Playable Classes**: Fighter, Wizard, Rogue, Cleric, Ranger, Barbarian — each with unique class features
- **12 Playable Races**: Human, High Elf, Wood Elf, Hill Dwarf, Mountain Dwarf, Lightfoot Halfling, Stout Halfling, Half-Elf, Half-Orc, Gnome, Tiefling, Dragonborn
- **Party of 1–4 Characters**: Mix of player-controlled and AI companions
- **Turn-Based Combat**: Attack rolls, armour class, damage, advantage/disadvantage, critical hits
- **30+ Monster Types**: From Giant Rats and Goblins to Beholders, Young Dragons, and Vecna
- **D&D 5e Spellcasting**: Cantrips, 1st and 2nd level spells with spell slots, targets, damage types
- **Level Progression**: XP-based levelling with HP gains and new abilities
- **Death Saving Throws**: D&D 5e stabilisation system — 3 successes or 3 failures
- **Status Effects**: Poisoning, unconsciousness, fleeing, playing dead, dodging

### Exploration
- **Procedural Dungeons**: Randomly generated multi-level dungeons with 12 room types
- **Minimap Display**: ASCII dungeon map showing your position, exits, and room types
- **Torch System**: Light/douse torches for better visibility; torches degrade over time
- **Room Events**: Treasure rooms, trap rooms (acid spray, poison darts, spike pit, etc.), shrines, shops, libraries, prisons
- **Search & Listen**: Perception-based room searching and adjacent room listening
- **Door Security**: Barricade doors to reduce ambush risk
- **Multi-Level Progression**: Defeat the boss to descend deeper — harder foes and greater treasures

### Inventory & Equipment
- **Full Inventory System**: Carry weight based on Strength, equip weapons/armour/shields
- **Shop System**: Buy and sell gear from wandering merchants
- **Potions & Items**: Healing potions, antidotes, torches, and more
- **Starting Equipment**: Class-appropriate gear for every new character

### AI Dungeon Master
- **Multi-AI Provider Support**: Claude, GPT, Gemini (free tier with Gemini)
- **Apple Intelligence**: On-device AI when available
- **Adaptive Commentary**: DM narrates exploration, combat, and events
- **Ad-lib Levels**: Off, Flavour Only, Moderate, Full — control how much the DM talks
- **DM Chat**: Type messages to converse with the DM anytime
- **Ask the DM**: Available from inventory and exploration screens
- **World Consistency**: DM remembers context across the session

### NPCs & Encounters
- **13 NPC Types**: Wandering Trader, Prisoner, Hermit, Ghostly Scholar, Dwarven Smith, Elf Scout, Goblin Defector, Mysterious Stranger, Wounded Knight, Mad Alchemist, Old Priestess, Rat Catcher, Gatekeeper
- **NPC Dialogue**: Unique conversations with each NPC type
- **Gatekeeper Quests**: Accept quests for gold rewards on dungeon completion
- **Elf Scout**: Reveals traps ahead

### Bestiary & DnDex
- **Monster Bestiary**: Browse all 30+ monsters with ASCII art, stats, and lore
- **Rogues Gallery**: Track every NPC you've encountered across runs
- **DnDex Card Encyclopedia**: Full card catalogue with lore pages, sourced references, related-card connections, and navigation
- **Character Cards**: Every character, monster, and NPC has a detailed card with art, stats, and backstory

### Multiplayer (Game Centre)
- **Turn-Based Multiplayer**: Play with friends via Game Centre — no need to be online simultaneously
- **Remote Player Slots**: Convert any AI companion to a remote player
- **Lobby System**: Send invites, track confirmation, nudge waiting players
- **Live Action Echo**: See what the active player is doing in real time while you wait
- **Nudge System**: Send dramatic nudge reminders with flashing notifications
- **Turn Passing**: Clear status indicators and reconnection handling
- **Solo Conversion**: If a player leaves, their character becomes AI-controlled seamlessly

### Hall of Fame & Scoring
- **Hall of Fame**: Permanent record of every adventure — victory or defeat
- **Composite Scoring**: Points based on victory, gold, kills, exploration, and difficulty
- **Replay Adventures**: Relive victories or rewrite defeats from Hall of Fame entries
- **Game Centre Leaderboards**: Compete globally for gold, monsters slain, and total victories
- **Achievements**: Unlock achievements for combat, exploration, and dungeon mastery

### Save System
- **Multiple Save Slots**: Up to 10 adventure slots with 5 breakpoints each
- **Quick Save**: One-tap save during exploration
- **Autosave**: Configurable automatic saving
- **Save Management**: Create, overwrite, rename, and delete saves
- **Continue Quest**: Resume any saved adventure from the Play menu

### Sound & Music
- **Procedural Music**: Synthesised background music for menu, exploration, combat, and chat
- **Layered Composition**: Multi-voice atmospheric D&D music
- **Sound Effects**: Retro synthesised effects for combat, saves, notifications
- **Music Ducking**: Background music lowers when DM speaks

### Accessibility
- **Text-to-Speech**: DM voice narration with curated English voices
- **Speaker Mode**: Continuous narration with character-specific voices
- **Voice Input**: Speak to the DM using your microphone
- **Configurable Icon Size**: Normal, Large, Extra-Large
- **Font Size**: Larger text on iPad/macOS

### Custom Keyboard
- **In-App Terminal Keyboard**: No system keyboard needed
- **Language Adaptation**: QWERTY, QWERTZ (German), AZERTY (French)
- **Shift, Caps Lock, Symbols**: Full text input with smooth collapse/expand

### Settings
- **5 Settings Submenus**: DM, Accessibility, Mood/Music, Gameplay, Saving
- **Help Pages**: Every settings submenu has a dedicated help page
- **Undo/Redo**: Per-screen undo/redo for settings changes
- **British English**: Armour, colour, defence — throughout

### Platform Support
- **iPhone**: Optimised for all iPhone sizes
- **iPad**: Larger fonts and adapted layout
- **macOS**: Keyboard shortcuts, fullscreen mode
- **Apple TV**: Basic support

---

## What's New Since Original App Store Release (v1.1)

### Added in v1.1 → v2.0
- Inventory system with equipment, shops, starting gear
- Stranger Things character names and iconic monsters
- Autosave system
- Multi-AI provider support (Claude, GPT, Gemini)
- D&D 5e spell system, level-up, class features, death saves
- Direction D-pad for movement
- Talking DM with voice selection
- Background music ducking when DM speaks
- Hourglass rest animation
- Multi-level dungeon progression (boss → next level)
- Room-aware search descriptions
- DM chat persistence
- Tips section in How to Play
- Rebalanced early levels with weaker starter monsters
- Gemini as default free AI provider

### Added in v2.1
- Expanded to 30+ monster types
- Monster Bestiary with animated galleries
- British English spelling throughout
- DM fixes and improvements

### Added in v2.2
- Custom in-app keyboard with language adaptation
- NPC Gallery (Rogues Gallery)
- Torch rebalancing
- Settings help pages for all submenus
- Speaker mode deduplication
- Skill selection overhaul with undo/redo
- Live voice transcription
- NPCs and idle prompts off by default

### Added in v2.3
- Dragon ASCII art animations on splash screen
- Compact UI buttons
- Diverse Hall of Fame display
- Direction movement improvements (D-pad feedback)
- DnDex card encyclopedia with lore, references, and navigation
- Arrow-key navigation across card grids
- Entity galleries with source provenance

### Added in v2.4 (This Release)
- Victory screen overhaul with D&D narrative
- Multiplayer turn-based play with Game Centre
- Live action echo for spectating players
- Nudge system with dramatic notifications
- Invitation decline/accept flow with clear feedback
- Lobby polling for real-time status detection
- Hall of Fame replay (Relive/Rewrite History)
- Character indicator (◀ YOU) in exploration and combat
- Rest clock showing time elapsing
- Per-screen undo/redo isolation
- Save slot limit (max 10) with auto-cleanup
- Multiplayer crash robustness fixes
- "Since your last turn" prettified display
