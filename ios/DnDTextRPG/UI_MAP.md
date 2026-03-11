# UI Navigation Map

```
┌─────────────────────────────────────────────────────────────────────┐
│                        MAIN MENU                                    │
│                   D&D 5e ASCII Adventure                            │
├─────────────┬──────────────┬──────────────┬────────────┬────────────┤
│             │              │              │            │            │
▼             ▼              ▼              ▼            ▼            │
Continue    Play        Hall of Fame   How to Play   Settings        │
Quest*      Menu                                                     │
│             │              │              │            │            │
│             │              │              │            ├─► DM Settings
│             │              │              │            ├─► Accessibility
│             │              │              │            ├─► Mood
│             │              │              │            ├─► Gameplay
│             │              │              │            └─► Saving
│             │              │              │
│             │              │              ├─► Getting Started
│             │              │              ├─► Exploration
│             │              │              ├─► Combat
│             │              │              ├─► Character & Party
│             │              │              ├─► Recovery
│             │              │              ├─► Dungeon Master
│             │              │              ├─► Multiplayer
│             │              │              ├─► Tips & Tricks
│             │              │              ├─► FAQs
│             │              │              ├─► Bestiary
│             │              │              ├─► Rogues Gallery (NPCs)
│             │              │              └─► Name Lore
│             │              │
│             │              ├─► Tale Selector
│             │              │     └─► Tale Detail
│             │              └─► Leaderboard
│             │
│             ├─► New Adventure ─────────────────────────────────┐
│             ├─► Saved Adventures                               │
│             ├─► Multiplayer Matches*                           │
│             └─► Manage Saves                                   │
│                                                                │
│   ┌────────────────────────────────────────────────────────────┘
│   │
│   ▼  NEW ADVENTURE FLOW
│   │
│   ├─► 1. Party Size (1-4 or Random)
│   │
│   ├─► 2. Character Creation (repeated per character)
│   │       ├─► Name Entry (suggestions + custom)
│   │       ├─► Race Selection
│   │       ├─► Class Selection
│   │       ├─► Ability Score Method (Auto/Standard/Roll)
│   │       │     └─► Assign Scores (if manual)
│   │       └─► Skill Selection
│   │
│   ├─► 3. Party Review
│   │       └─► Character Cards (Edit Type/Race/Class/Voice)
│   │
│   ├─► 4. Dungeon Naming (suggestions + custom)
│   │
│   ├─► 5. Difficulty Selection (Easy/Medium/Hard/Custom)
│   │
│   └─► 6. Ready to Begin?
│           ├─► Enter the Dungeon ──────────────────────────────┐
│           ├─► Difficulty (change)                             │
│           ├─► Rename (change)                                 │
│           └─► Undo / Redo                                     │
│                                                                │
├───────────────────────────────────────────────────────────────────┘
│
▼  IN-GAME (EXPLORATION)
┌─────────────────────────────────────────────────────────────────────┐
│                      EXPLORATION VIEW                               │
│            Map · Room Description · Party HP · Exits                │
├────────────┬────────────┬──────────────┬──────────────┬─────────────┤
│            │            │              │              │             │
▼            ▼            ▼              ▼              ▼             │
D-Pad      Actions    Inventory    Party Status      Help            │
Movement                                                             │
│            │            │              │                            │
│ ┌──────────┘            │              │                            │
│ │                       │              │                            │
│ ├─► Search Room         │              ├─► Character Details        │
│ ├─► Listen              │              ├─► Cure Poison*             │
│ ├─► Pick Up Items*      │              ├─► Adventure Log            │
│ ├─► Take Treasure*      │              ├─► Party Review             │
│ ├─► Illuminate/Douse    │              └─► Settings                 │
│ ├─► Secure Room         │                                          │
│ ├─► Inventory           │                                          │
│ └─► Quick Save          │                                          │
│                         │                                          │
│              ┌──────────┘                                          │
│              │                                                     │
│              ├─► Equipment                                         │
│              │     ├─► Weapon Slots                                │
│              │     ├─► Armour Slots                                │
│              │     └─► Shield Slots                                │
│              ├─► Open Pack                                         │
│              │     ├─► Use Potion                                  │
│              │     ├─► Equip Item                                  │
│              │     ├─► Drop Item                                   │
│              │     └─► Give to Party Member                        │
│              └─► Other Character's Pack                            │
│                                                                    │
│  D-PAD CONTROLS                                                    │
│  ┌─────┬─────┬─────┐                                              │
│  │     │  N  │ NPC │    Centre: Short Rest                         │
│  ├─────┼─────┼─────┤    Centre Long-Press: Long Rest               │
│  │  W  │ REST│  E  │    SE Corner: Talk to NPC*                    │
│  ├─────┼─────┼─────┤                                               │
│  │     │  S  │     │    * = conditional (shown when available)      │
│  └─────┴─────┴─────┘                                              │
│                                                                    │
│  COMBAT (triggered by encounter)                                   │
│  ├─► Attack                                                        │
│  ├─► Cast Spell*                                                   │
│  ├─► Use Item                                                      │
│  ├─► Defend                                                        │
│  └─► Retreat*                                                      │
│                                                                    │
│  SAVE/QUIT (X button during exploration)                           │
│  ├─► Save & Quit                                                   │
│  ├─► Continue                                                      │
│  └─► Delete Save                                                   │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                        SETTINGS TREE                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Settings                                                           │
│  ├─► DM Settings                                                    │
│  │     ├─► AI Provider (OpenAI / Anthropic / Local)                │
│  │     ├─► API Key                                                  │
│  │     ├─► Ad-Lib Level (Off / Light / Standard / Heavy)           │
│  │     ├─► Log Context                                             │
│  │     └─► Help                                                     │
│  │                                                                  │
│  ├─► Accessibility                                                  │
│  │     ├─► Font Size                                                │
│  │     ├─► Icon Size                                                │
│  │     ├─► Hit Animations (toggle)                                 │
│  │     ├─► DM Voice (toggle)                                       │
│  │     ├─► Companion Voices (toggle)                               │
│  │     ├─► Voice Menus (toggle)                                    │
│  │     └─► Help                                                     │
│  │                                                                  │
│  ├─► Mood                                                           │
│  │     ├─► Music (toggle + melody select)                          │
│  │     ├─► Sound Effects (toggle)                                  │
│  │     ├─► Voice & Speech                                           │
│  │     │     ├─► DM Voice                                           │
│  │     │     ├─► Companion Voices                                   │
│  │     │     │     └─► Per-Character Voice Picker                  │
│  │     │     ├─► Voice Pool                                        │
│  │     │     ├─► Speech Speed                                      │
│  │     │     └─► Speech Pitch                                      │
│  │     └─► Help                                                     │
│  │                                                                  │
│  ├─► Gameplay                                                       │
│  │     ├─► Map Visibility Radius                                   │
│  │     ├─► Card Navigation (toggle)                                │
│  │     ├─► Info Timeout                                            │
│  │     ├─► Max Buttons Per Screen                                  │
│  │     ├─► Long-Press Guide                                        │
│  │     ├─► NPCs (toggle)                                           │
│  │     ├─► Multiplayer (toggle)                                    │
│  │     ├─► Adventure Log (toggle)                                  │
│  │     ├─► Time Limit (toggle)                                     │
│  │     ├─► Idle Prompts (toggle)                                   │
│  │     ├─► Custom Keyboard (toggle)                                │
│  │     └─► Help                                                     │
│  │                                                                  │
│  ├─► Saving                                                        │
│  │     ├─► Autosave Interval                                       │
│  │     ├─► Manage Saves                                             │
│  │     ├─► Clear All Saves                                         │
│  │     ├─► Settings Backup                                         │
│  │     ├─► API Key Backup                                          │
│  │     └─► Help                                                     │
│  │                                                                  │
│  └─► Help (Settings overview)                                      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

* = only shown when condition is met
```
