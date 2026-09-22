# D&D 5e Text Adventure

A retro terminal-style 5th Edition fantasy RPG for iPhone, iPad, Mac, Apple TV and Apple Vision Pro, with AI Dungeon Master support.

![Dragon](images/dragon_animation.gif)

## What's New Since 2.4 (version 3.0)

Version 3.0 is the biggest update yet: many rounds of play-testing by Beau and Professor Lewis, turned into a very long list of changes. The highlights are grouped below; the in-game help (the **?** on every screen) covers each one in more detail.

### Now on five platforms
- **iPhone and iPad**, as before, plus a native **Mac** app (resizable panes, the whole map beside the story, keyboard play), **Apple TV** (text sized to read across a room, played with the Siri Remote) and **Apple Vision Pro** (a native visionOS app, not the iPad version in a window).
- One set of saves and settings format across all of them.

### Quests, deadlines and a reason to go down
- **A main quest from the start**, told in-character by whoever needs you, with a proper opening tale, and **several side quests** at once from almost anyone you meet.
- **Quests that differ in what they ask**, not just in the words: rescue, fetch, find, clear, escort and more, each with its own win condition.
- **Deadlines in days** on a calendar the DM knows about ("by the full moon, day 12"), counted down on the status screen. Slow quests get a chaser: carry on, give up, or hold out for a bigger prize.
- **A guardian on every floor.** Beat it and the way down opens; the last floor holds the villain from your opening tale. Nudges tell you when you've explored most of a floor without finding it.
- **Sealed wings on the deeper, harder floors**: part of a floor can be cut off entirely — no passage joins it, and it shows on the map as an island with no lines running to it — often with the guardian's lair inside. Two ways in, always: a teleport pad, or up the stairs to the gallery above, along, and down again on the far side. An Easy game never splits a floor; the chance grows with difficulty and depth:

  ```
  Easy, or floors 1–2:  never
  otherwise:            min(85, 12 × (difficulty − 1) + 10 × (floor − 2))  per cent
  ```

  with difficulty 1 Easy, 2 Medium, 3 Hard, 4 Brutal — so Medium runs 22% on floor 3 to 62% on floor 7, Hard 34% to 74%, and Brutal 46% up to the 85% ceiling.
- **Depth follows difficulty**: Easy is a single, smaller floor with the guardian's lair pointed out as you go; Medium is about five floors; Hard about seven, with harder fights rather than longer ones. You can raise the difficulty mid-game (one way only).
- **Endgame**: an outro tale, fireworks, a **certificate** with your stats and the maps of every floor (saved as a PDF), a Hall of Fame entry, and, if the party falls, encouragement and a Try Again.

### Fewer fights, more to do
- **Riddles, logic puzzles, word puzzles and cryptic clues** in libraries and shrines, harder the deeper you go. New puzzles arrive in small **signed puzzle packs** the game checks for once a day; anyone can **Suggest a Puzzle** from Settings.
- **Tolls and talk as well as swords**: on Easy many encounters can be passed without a fight.
- **Merchants worth talking to**: they remember you, keep their own stock between visits, haggle (with an Accept button for the counter-offer), quote the prices they'll actually charge, and react to your reputation.
- **Gyms** train whoever paid (with a Multi-Gym Pass and certificates of training); **bards** perform for tips; **lock-picking** wears your Thieves' Tools, which smiths can mend.
- **Locked doors, keys, forcing and barring**: bar a door behind you to keep monsters out.
- **Teleport pads**, including rare deep-blue ones that drop you a floor.

### Fights you can follow
- **The DM narrates the blows** with Read Aloud on, and tells each fight back as a short story afterwards (**How We Fared**).
- **Replay Fight**: step back through a finished fight screen by screen from the victory screen.
- **Dynamic combat help**: the **?** in a fight lists the enemy's hit points and armour, what each of your adventurers carries (weapon, best spell, potions, class tricks), their real chance to hit and likely damage against this enemy, roughly how many rounds the fight will take, and why the turn order is what it is.
- **Poison that lasts** until cured or worn off; **companions' and monsters' turns move quicker**; the winning blow gets a proper pause before the victory screen; **Fight Club** acts out the fight in ASCII (Mac right pane, optional on iOS).
- **Willpower Surge** to resist mind-control, and a rare **Emergency Drop** that can save a party from a total wipe.

### A Dungeon Master that listens
- **Talk instead of tapping**: continuous voice commands with an "enter word", or one command at a time. Button numbers, button names and directions ("north", "go east") are matched first, before anything is read as free speech.
- **The DM can't hear itself**: the mic is deaf while the game speaks, and starting to speak stops the game talking.
- **DM chat**: the current exchange is bright and the rest dimmed; what you say appears in the conversation; leaving the chat gives a **recap** of what was said and anything gained or lost.
- **@names** to talk to a companion ("@mol climb the wall"); robot companions ("R. Athos") are understood as names.
- **A key check at startup**: if your AI key stops working (no credit, deleted key, no internet) the game says why, links to the provider's billing and key pages, and offers Change AI Brain. A key that passes its test is saved to the Keychain automatically.
- **Mood switches**, a DM calendar, and the DM told firmly never to invent actions for you.

### Choose your Dungeon Master's brain
- **Apple's on-device AI is the default** where the device has it (iPhone 15 Pro or later, M-series iPad or Mac, iOS 26+ with Apple Intelligence on): free, private, offline, no account.
- **Hugging Face** is new: one free account and token reach many open models (Llama, Gemma, Qwen…). A free account comes with a small monthly allowance (US$0.10 of credit; the game's compact prompts make that several hundred DM replies). The key screen walks through making the token step by step, with links.
- **A saved Hugging Face token is the backup** on devices without Apple Intelligence, and steps in if the chosen cloud brain fails. When nothing is available the game's own built-in DM runs everything.
- **Choose a model** for every provider (Change Brain > provider > Model): a few recommended models with a note on speed, cost and cleverness, **More Models** for everything the service offers right now, or **Custom** for any model name. The game tests each choice.
- **Test Brain** on the Dungeon Master Brain screen tests whichever brain is in use, and offers to keep a working key in the Keychain.
- Without a cloud key, the game says **once** which brain it's using and how to get a better one; after that the main menu shows a quiet "DM: …" line.

### Built for VoiceOver
- The story is read as **a few sections, each starting at its heading**, not line by line, and each screen starts by saying **where you are**.
- Every button is named; empty slots say **"No button"**; symbols like triangles and middle dots are no longer read out.
- **Long press** is a VoiceOver action on every button that has one; **three-finger swipe** scrolls the story; a **VoiceOver help** link on every screen explains both, and how to switch VoiceOver off with the Accessibility Shortcut.
- With VoiceOver on, the game's own voice speaks **through VoiceOver**, so there is only ever one voice, and animations and auto-scroll pause until VoiceOver is off again.
- **Read Aloud** reads each page's title as well as its text, and switching it off (or the DM voice off) always silences it at once.

### Finding your way
- **Back and Next** in the 3-bar undo and redo a step while exploring; **< Back** also looks back through the screens you've left.
- **The Atlas**: long-press the map for the whole floor, every floor you've mapped, pinch-zoom, room labels, a full key, and a printable PDF.
- **Lesser magick**: a party with the gift can speak incantations (`magick: show …`) that mark things on the map, in their own colours, on every floor.

### Saves, settings and the rest
- **Continue Adventure** sorts by date or by points (then it's the **Hall of Fame**), with a Character Hall of Fame; unfinished adventures show their points so far.
- **Timeouts**: every automatic wait adjustable by kind; an hourglass that only turns while a countdown is really running, tap to pause.
- **Auto-Scroll** for long pages, which picks up again a few seconds after you scroll by hand.
- **Font sizes** down to Tiny, with the text re-wrapped to fit; a cog menu everywhere; tappable Settings lines.
- **Bug reports** carry the save and the steps that led there, and load back in for replay.
- Saves from 2.4 load; a content-safety tool; reputation ("Glyphkeeper"); the Settings overhaul described in RELEASE_NOTES_v3.0.md.

### Multiplayer: still experimental
Game Center multiplayer (turn-based, shared party, remote players becoming robots if they leave) is in the build but **largely untested**. Expect rough edges; it will need some iteration, and reports are very welcome (Adventure Log > Report a Bug, or an issue on GitHub).

## Features

### Character Creation
- **12 Races**: Human, High Elf, Wood Elf, Hill Dwarf, Mountain Dwarf, Lightfoot Halfling, Stout Halfling, Half-Elf, Half-Orc, Rock Gnome, Tiefling, Dragonborn
- **6 Classes**: Fighter, Wizard, Rogue, Cleric, Ranger, Barbarian
- **Ability Scores**: Standard array or 4d6 drop lowest
- **Ability Score Improvement**: raise an ability score by 2 (your choice, capped at 20) at D&D 5e ASI levels as you level up
- **Experience & Leveling**: standard D&D 5e XP thresholds — Level 2 at 300 XP, Level 3 at 900 XP, Level 4 at 2,700 XP, Level 5 (cap) at 6,500 XP. Earned from combat and awarded by the DM; shown on Party Status alongside how much is needed for the next level
- **18 Skills** with proficiency system
- **Parties** of 1-4 characters (human or AI-controlled)
- **Long-press** any party size to auto-generate an all-AI party
- **Name suggestions** drawn from D&D shows, films, and sci-fi classics (Stranger Things, Community, Futurama, Dune, The Matrix, and more)
- **DnD-dex** [showing character and location cards used as the name suggestions in the game](https://proflewis.github.io/gamer/ios_card_images/card-dex/index.html).

### Combat (D&D 5e Rules)
- Initiative, attack rolls, saving throws, critical hits
- Death saving throws (nat 20 revive, nat 1 double failure)
- Class features: Sneak Attack, Rage, Second Wind, Hunter's Mark
- **Dodge** grants attackers disadvantage on their next attack
- **Play Dead** — bluff your way out of a fight (CHA + Deception check)
- **Flee** — escape to the previous room
- Creative actions via the AI DM
- Monsters grouped by type with numbered targeting
- **Fight Club** — each fight acted out in animated ASCII: fighters lunge, swoop, shoot, throw, lob gadgets and breathe fire; spells fly in their element's colour; hits spark and shake, crits flash, damage rises off the struck, misses are dodged and the fallen crumple — with everyone's health bars along the bottom. On a Mac it plays below the buttons; on iPhone/iPad tap **@** on the input line during a fight (tap again to hide). Onlookers on both sides cheer and jeer, with crowd sounds. Settings > Gameplay > Fight Club.
- **Dungeon Quirks** (Settings > Gameplay, off by default) — little oddities, like the dragon's winks wandering into the words ("g- -n" still means go on)
- **Poison** — venomous creatures can poison party members (CON save to recover)
- **Dynamic Difficulty** — monster HP and accuracy scale up gradually as your party's average level rises, on top of your chosen difficulty, so the challenge keeps pace with your growing skill (shown on Party Status)

### Spellcasting
- **Wizard**: Fire Bolt, Ray of Frost, Magic Missile, Burning Hands, Sleep
- **Cleric**: Sacred Flame, Cure Wounds, Guiding Bolt, Healing Word, Spare the Dying
- **Ranger**: Hunter's Mark, Cure Wounds
- Cantrips (unlimited) and spell slots that recover on long rest

### Sealed Wings (deeper, harder floors)

Part of a floor with no passage to the rest of it — an island on the map — usually holding the guardian's lair. Reached by a teleport pad, or by the gallery above (stairs up, along, stairs down). Locked doors are never placed inside one, and both routes are built by hand during generation, so a wing can never be unreachable. Chance per floor (`Dungeon.sealedWingChance`):

```
Easy, or floors 1–2:  never
otherwise:            min(85, 12 × (difficulty − 1) + 10 × (floor − 2))  per cent
```

| Floor | Medium | Hard | Brutal |
|---|---|---|---|
| 3 | 22% | 34% | 46% |
| 5 | 42% | 54% | 66% |
| 7 | 62% | 74% | 85% (cap) |

### Procedural Dungeons
- 11 room types: corridors, chambers, treasure rooms, armories, shrines, libraries, prisons, trap rooms, boss chambers, and more
- ASCII minimap showing only visited rooms with dynamic key (only shows symbols present on the map) — merchant rooms are marked with `[M]`
- Encounters and traps scaled by dungeon level
- Treasure, equipment, and potions throughout; shop rooms always have a merchant, and armouries sometimes do too
- **Always downward** — you start on the ground floor (floor 0, Level 1) and descend to the lowest level, where the villain waits. Seven floors by default; **Settings > Gameplay > Levels** sets how deep a *new* dungeon goes (1 to 12), and a dungeon keeps the depth it was made with, so changing the setting never reshapes a game in progress. Each floor's guardian (the `B` room) must fall before the way down opens; a rare deep-blue teleport pad can carry you down a floor early. Stairs and ropes within a floor link its two galleries — shortcuts across the same depth, not a way down
- **Locked doors** — occasionally gate a passage; open them with a matching key (findable elsewhere in the dungeon), by picking the lock (Thieves' Tools), or by forcing it (Strength check). Door state persists — leave and come back and it's exactly as you left it — and holding the key, you can lock it again behind you to keep monsters out

### Merchants
- **4 tiers**, scaling with dungeon depth: Wandering Peddler, General Store, Trading Post, and Hyperstore
- Each merchant is a named character with their own shop name and persona, not a generic vendor
- **Buy, Sell, Haggle** (a Persuasion check for a discount), and **Ask About Rare Goods** (a chance at an under-the-counter item at a premium)
- Merchants occasionally offer unsolicited advice
- Bargaining and rare-goods outcomes are always resolved as real game mechanics (dice rolls, item tables) — the DM only narrates on top, so it works with cloud AI, Apple on-device AI, or no AI at all
- Found in shop rooms (guaranteed once per dungeon level), some armouries, and via Wandering Trader NPCs — a **Visit Merchant** button appears whenever one is present

### Training Gyms
- Found by chance in chamber rooms, run by a named trainer with a specialty skill
- Get in by **paying a membership fee** or **sparring** (a skill check against the trainer) for free entry
- Training teaches a character a new skill proficiency outright, or a small XP bonus if they already have it
- A **Visit Gym** button appears whenever one is present, marked `[G]` on the minimap

### 36 Monsters

The dungeon is home to 36 different creature types, from lowly rats and kobolds to terrifying eye tyrants and dragons.

![Bestiary](images/all_monsters.png)

### 13 NPCs

Friendly NPCs appear in dungeon rooms — traders, healers, scholars, smiths, scouts, and more. Talk to them for quests, services, and lore. The Gatekeeper guards the entrance and offers gold rewards for clearing the dungeon.

![NPCs](images/all_npcs.png)

### AI Dungeon Master

The DM's "brain" is chosen in **Settings (cog) > Change Brain…**. In order of preference when nothing else is chosen:

1. **A cloud AI with your own key** (any device) — the best DM. Choose Claude (Anthropic), GPT (OpenAI), Gemini (Google — free tier, adults 18+) or **Hugging Face** (free account with a monthly allowance; open models such as Llama 3.3 70B). Each provider has a **Model** screen to pick which of its models runs the DM.
2. **Apple On-Device AI** (iPhone 15 Pro or later, or an M-series iPad/Mac, on iOS 26+ with Apple Intelligence switched on) — the default where available. Runs entirely on the device: no key, no account, works offline. May refuse some queries — try rephrasing.
3. **Hugging Face as backup** — on a device without Apple Intelligence, a saved Hugging Face token takes over automatically.
4. **Built-in DM** (all devices) — simpler, ready-written replies. No AI, no setup; the whole game works with it.

| Provider | Cost | Key from | Default model |
|---|---|---|---|
| Apple On-Device | Free | — (built in) | Apple Foundation Model |
| Hugging Face | Free monthly allowance (US$0.10 credit; PRO US$2) | [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens/new?tokenType=fineGrained) — tick *Make calls to Inference Providers* | Llama 3.3 70B |
| Google Gemini | Free tier (18+) | [aistudio.google.com/apikey](https://aistudio.google.com/apikey) | Auto (newest Flash) |
| Anthropic Claude | Pay as you go, a few pence a session | [platform.claude.com/settings/keys](https://platform.claude.com/settings/keys) | Claude Sonnet 4.5 |
| OpenAI GPT | Pay as you go | [platform.openai.com/api-keys](https://platform.openai.com/api-keys) | GPT-4o mini |

Keys stay on the device (and in its Keychain once tested); prompts go straight from the device to the provider you chose.

Features:
- 4 DM levels: Off, Flavour Only, Moderate, Full
- At Moderate+, the DM can grant items, award gold, heal, deal damage, move the party, and teleport
- Ask the DM during exploration or combat for creative actions
- DM actions update the world state in real time (map, inventory, HP)
- ASCII art responses when you ask the DM to draw something
- **DM Voice** — text-to-speech reads DM responses aloud (built into iOS, no API key needed)
- **Speaker Mode** — persistent read-aloud toggle that narrates story text as you play

### Save System
- Save slots with automatic breakpoints (up to 5 per slot)
- Autosave on room changes (configurable interval)
- Load any breakpoint from a slot's history
- Rename and delete save slots

### Character Roster
- Save individual characters independent of game saves — a separate system from Saved Adventures, reached inside **New Adventure**'s character selection rather than as its own Play menu button, so the Play menu stays to just "New Adventure" / "Continue Adventure"
- **Save to Roster** is available wherever it matters: on the Party Review card for every character before an adventure starts (covers new, auto-generated, and quick-start parties alike), during party creation, and from Party Status mid-adventure (handy right after a level-up)
- Starts pre-seeded with one Level 1 example of each class, so there's always something to load right away
- **Load Character**, offered while picking party members, opens the Character Hall of Fame — pick any inducted hero, or tap "Manage Saves" there to browse and delete the full roster (not just Hall-of-Famers). Loading brings a character in at their current level, gear, and gold (HP/spell slots/combat state reset for the fresh start)
- Starting a brand new adventure automatically offers to bring back your most recently inducted hero for the first party slot
- Up to 20 characters can be kept in the roster

### Hall of Fame
- Scoring: victories, gold, monsters slain, exploration, difficulty multiplier
- Pre-seeded with Stranger Things-themed entries
- Reached via **Continue Adventure** in the Play menu; each entry is a numbered button (tap to read its tale, matching how the Character Hall of Fame lists its heroes), and a "Manage Saves" button opens actual save-game management (resume, rename, delete) — including adventures still in progress, which never earn a Hall of Fame entry of their own
- **Character Hall of Fame** — every survivor of a victorious adventure is automatically saved to the Character Roster and inducted here, the character-level counterpart to the game Hall of Fame; reached from New Adventure's character selection, with its own "Manage Saves" for the full roster

### Game Center
- Leaderboards: Gold collected, Victories, Monsters slain
- 6 Achievements: First Blood, Dungeon Master, Hoarder, Slayer, Veteran, Legend
- Turn-based multiplayer via Game Center

### Multiplayer
- Turn-based async multiplayer via Game Center
- Host controls exploration; each player controls their own character in combat
- Party chat with @mentions
- Invite friends mid-game or during party setup
- Nudge idle players

### Comprehensive Help System
- 12 help topics: Getting Started, Exploration, Combat, Character & Party, Recovery, Dungeon Master, Multiplayer, Tips & Tricks, FAQs, Bestiary, NPCs, Name Lore
- 50+ FAQ entries organised by topic
- Context-sensitive gameplay tips
- In-game bestiary with ASCII art for all 30 monsters
- Name Lore gallery with character cards and pop culture origins

## Interface

Green-on-black terminal aesthetic with monospaced text, ASCII art for characters and monsters, and a D-pad for dungeon navigation. Features include:
- Configurable font size (small, medium, large, extra large)
- Animated dragon GIF on the main menu
- Swipe-left to go back from any screen
- Voice input via microphone
- Speaker mode for hands-free narration
- Custom on-screen keyboard
- Undo/redo for character editing and settings
- macOS keyboard shortcuts (arrow keys, WASD, letter keys for menus)
- Long-press shortcuts throughout the UI (e.g. long-press Quit Without Saving or Delete to skip "are you sure?")
- Auto-Continue with a countdown hourglass by the `>` prompt — see below
- Pages always open at the top; optional **Auto-Scroll** (Settings > Accessibility: Slow / Medium / Fast, with a live demo) glides down long pages, and text added later — results, warnings — is scrolled into view
- A short breadcrumb at the top of each page says where you came from and what just happened
- Tappable links in help text (e.g. → Settings > Gameplay) open that setting; Back returns to where you were

## Auto-Continue & the Countdown Hourglass

Many screens — a combat round, a search result, a merchant's reply — are *tap-to-continue*: nothing happens until you tap. With **Auto-Continue** on (the default), those screens also move on by themselves after a short wait: the **Info Timeout** (5 seconds by default; other tap-to-continue screens wait twice that).

While a screen is counting down you'll see a small **hourglass** at the right-hand end of the input line — it turns over, and a thin ring around it shows the time left. You can:

- **Tap anywhere** on the screen to continue straight away.
- **Wait** — when the hourglass runs out, the game moves on by itself.
- **Tap the hourglass** to pause — this **freezes time**. It turns **orange** and *paused* pulses gently beside it. While frozen nothing happens: the DM stops nudging you to continue (it just says time is frozen and how to unfreeze), buttons and taps wait, combat hesitation doesn't count against you, and anything you type makes the game ask whether to unfreeze first (say *yes* and what you typed goes through). Tap the orange hourglass again (or press Space on a Mac) to unfreeze; it carries on from where it stopped. A **?** beside *paused* explains all this.
- **Long-press the hourglass** to hurry the countdown along.
- **Type** at the prompt: typing pauses the countdown; *go on* continues, and anything else continues and then does what you typed.
- Wait a while and a dim hint reminds you of these options.
- **The dots are the wait.** While a screen is waiting for you it counts quietly to itself — a single `.`, then `..`, then `…`. That is all the dots mean: the game is holding the screen for you, and nothing is wrong. Tap anywhere (or press Return) to carry on. If you leave it much longer, the dots give way to a line with a bit more character to it — the dungeon wondering whether you are still there.
- On a Mac, press **Space** to pause or resume.

**Why we do it.** Auto-Continue keeps the game flowing if you glance away, play one-handed, or listen with speaker mode — you're never stuck on a screen. But a screen that moves on by itself can also snatch text away before you've finished reading it: a long combat report, a merchant's counter-offer, a trap you want to think about. The hourglass makes the timer *visible*, so a screen never moves on as a surprise, and it puts pause right beside where you read and type — instead of burying it in Settings. That matters most if you read at your own pace, get interrupted, use a screen reader or large text, or simply want to savour the story.

**Settings** (Settings > Gameplay):

- **Auto-Continue** On/Off — Off means every such screen waits for your tap.
- **Info Timeout** — how long screens wait before moving on.
- **Countdown Icon** On/Off — hides the hourglass. Auto-Continue itself carries on as set (Space still pauses on a Mac).
- **Blinking Cursor** — the ordinary cursor by the prompt, on or off.

## Accessibility

Display size, DM narration, VoiceOver labels (D-pad, map summary, navigation), Reduce Animations, Auto-Scroll, a pausable auto-continue countdown, left/right-handed layout, typing or voice instead of tapping, and long-press shortcuts. See [ios/DnDTextRPG/ACCESSIBILITY.md](ios/DnDTextRPG/ACCESSIBILITY.md) for how to use each tool and notes on playing with VoiceOver.

## How to…

Short answers to the things people actually ask. Every screen also has a **?**
button, and the Dungeon Master will answer in plain words if you ask.

### How to find a new main quest
Open **Party Status → By the Campfire**. The party sits down and asks whether
this is still the quest worth risking everything for. Choose **Hear Another
Plea** and someone new comes forward with their own trouble. You can take it
up, turn it down, or try to go back to the one you had — though a village you
walked away from may not want you back. Be warned: the dungeon dislikes
oath-breakers, and taking up a new quest can fling you back to the entrance,
with things falling out of packs on the way.

### How to abandon a quest
Same screen: **By the Campfire → Give Up Quest**. You lose the progress and
keep a little gold in goodwill, which makes room for another. **Long-press**
the button to skip the "are you sure?" step once you know you mean it.

### How to play with no quests at all
Two ways. When a plea is offered, choose **No Quest** and set off for the
adventure of it — there are always errands on the way. Or switch them off
entirely: **Settings → Gameplay → Main Quests → Off**. A new adventure then
skips the plea and goes straight down into the dark, and anything to do with a
main quest is greyed out. Errands from the people you meet are unaffected
either way.

### How to stay healthy
Resting and eating are both under **Rest** in the actions:

| What | Costs | Good for |
|---|---|---|
| **Short Rest** | 1 hour | Some hit points back, quickly |
| **Long Rest** | 8 hours | Everyone back to full |
| **Eat & Drink** | A few minutes | Hit points, and some food has its own effect |
| **Wash** | A few minutes | Morale, and how people treat you |

Two things worth knowing. **Eating in the dark only does half the good** — you
can't see what you're eating, or how much. Light a torch first. And a **Long
Rest costs eight hours**, which is most of a day: fine when nothing is chasing
you, expensive when something is.

### How to keep an eye on the clock
The day counter runs from the moment you go down. If your quest has a deadline,
it shows on the quest line as **☾ Harvest Moon in 3 days** — and then "is
today!", and then "has passed — late, but not lost". A passed deadline doesn't
end the quest; it halves the reward, and what the village feared happens anyway.

If you have also set **Settings → Gameplay → Time Limit**, the adventure ends in
defeat when game time runs out. With a time limit *and* a deadline, sleeping
eight hours twice over can cost you both. Short Rests and food are the cheap way
to stay standing.

### How to get the guardian to talk
Beat the guardian on any floor and it gives up a piece of the quest before it
goes still — what this floor was hiding, and how much of it you need. Gather
those on the way down and the ending is a better one. Some quests cannot be
finished without them at all: see **Quest objectives**, below.

### How to tell what a quest actually wants
Not every quest ends with a dead guardian. The plea says which kind it is:

- **Slay** — beat the guardian at the bottom.
- **Remedy** — killing it is not enough. Without the makings gathered floor by
  floor, the sickness goes on and the village is no better off.
- **Mystery** — you must learn enough on the way to know *who* was behind it.
  Kill the wrong thing and nobody can say whether it was the right one.
- **Rival** — another company set out before you. This is a race.

### How to find things
**Search Room** uses whoever has the best Perception — or whoever you have named
under **Actor**. Once a room's hidden things are found, searching again
scavenges instead: odds and ends, and sometimes what the guardian asked you to
gather. A room can only be scavenged once. In the dark it is far harder, and it
can go wrong.

### How to work a little magick

There are lesser magicks. If someone in your party can work them — a spellcaster, or someone clever, wise or forceful enough — speak an incantation at the > prompt: `magick:` (or `magic:`, `magik:`) followed by `show …` and something that might be on the map. What answers is for you to find out; `hide …` undoes it. (Spoken, just say the word: "magick show …".)

The full Book of Small Magicks is kept on a private page.

### How to make the game faster or slower
- **Settings → Gameplay → Timeouts** — how long each kind of screen waits before
  moving on by itself.
- **Settings → Mood → Music Speed** — how quickly the tunes play.
- Tap the **hourglass** by the input line to pause a countdown; long-press to
  hurry it along.

## Building

Requires Xcode 15.0+. Open `ios/DnDTextRPG/DnDTextRPG.xcodeproj` and build for iOS 16.0+ or macOS.

See [ios/README.md](ios/README.md) for detailed build instructions.

## Testing

- Manual QA checklist covering every system — combat, spells, leveling,
  merchants, riddles, traps, save/load, DM tiers, and more:
  [docs/QA_CHECKLIST.md](docs/QA_CHECKLIST.md)

## iOS/Python Feature Parity

- Current reconciliation status and mapping:
  [docs/ios_python_parity.md](docs/ios_python_parity.md)

## DnDex (Card Dex)

- Browse all generated player, monster, and location cards in the **DnDex** viewer:
  [https://proflewis.github.io/gamer/ios_card_images/card-dex/index.html](https://proflewis.github.io/gamer/ios_card_images/card-dex/index.html)
- Browse the **Rogues Gallery Viewer** (rooms, races, monsters, NPCs, with voice showcase):
  [https://proflewis.github.io/gamer/gallery/index.html](https://proflewis.github.io/gamer/gallery/index.html)
- Deep source references (authors, films, TV, modules, worlds):
  [https://proflewis.github.io/gamer/ios_card_images/card-dex/entities/index.html](https://proflewis.github.io/gamer/ios_card_images/card-dex/entities/index.html)
- Photo provenance for downloaded reference images:
  [https://proflewis.github.io/gamer/ios_card_images/PHOTO_SOURCES.md](https://proflewis.github.io/gamer/ios_card_images/PHOTO_SOURCES.md)
- Markdown catalogs for direct image links:
  [https://proflewis.github.io/gamer/ios_card_images/README.md](https://proflewis.github.io/gamer/ios_card_images/README.md)
- If your browser blocks local `file://` data loading, run from repo root:
  `python3 -m http.server 8000`
  then open `http://localhost:8000/ios_card_images/card-dex/index.html`
  or `http://localhost:8000/gallery/index.html`

## Credits

- **Created by** Prof. Lewis
- **Co-author — world creation, storytelling, gameplay structure and style, and game testing:** Beau Lewis
- **AI assistance** by Claude (Anthropic)
- **A Timbaloo app**

## License

Game mechanics from the D&D 5e System Reference Document under the Open Gaming License v1.0a. Dungeons & Dragons is a trademark of Wizards of the Coast LLC.
