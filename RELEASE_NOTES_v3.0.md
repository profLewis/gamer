# Dungeons & Dragons 5e Text RPG — Version 3.0

## What's New in Version 3.0

### AI Dungeon Master Safety & Trust
- **Content Safety tool ("Reyes Failsafe")**: a real-world tabletop safety tool (the "X-Card" concept) built into the AI DM. If the story ever goes somewhere too dark, gory, or uncomfortable, use it any time to scrub the DM's last response and steer future narration in a safer direction — no explanation needed, reusable any number of times
- **Fixed Gemini/Google AI keys**: Google's AI Studio now issues a newer key format ("AQ." prefix) that wasn't being accepted — Gemini now authenticates correctly with both the new and legacy key formats
- **Smarter model fallback**: if your configured Gemini model becomes unavailable, the app automatically discovers and switches to the newest working model instead of just failing

### Reputation & Alignment ("Glyphkeeper")
- Characters now track a running ethical/reputation score (Villainous → Heroic) based on tracked choices, visible on the character sheet with a log of what shaped it
- The AI DM sees each character's reputation and lets it colour narration and NPC reactions
- Merchants react to your reputation directly — a good name makes haggling easier, a bad one makes it harder

### Settings Overhaul
- **Save Settings**: a dedicated screen for backing up/restoring your settings and API keys — Quick Save (one tap, includes your API keys), Save As (named backups), Load (with a full preview of what's in a backup before applying, instant apply with no restart needed, and an Undo button), and API key Keychain backup/restore
- **Game Saves vs. Save Settings, clearly separated**: "Game Saves" is now just your adventures in progress; settings and API key backup live under "Save Settings" instead
- **Reset, unified**: one Reset screen with three independent toggles (Reset Settings / Clear API Keys / Delete Saved Games) instead of two separate all-or-nothing options — mix and match, see exactly what will change before applying, and back out to a saved backup at any point
- **Set API Key screen reorganized**: switch AI provider right from this screen, view/copy/test/save-to-Keychain your key, and the screen now pages (`<< >>`) instead of piling up buttons
- Fixed Test/Paste/Edit/Load Key incorrectly bouncing you back to the AI Provider menu instead of staying on the key screen

### Fixed & Improved
- **Hall of Fame** now has an actual button (on Continue Adventure) — previously only reachable by typing a hidden command
- **Info/result screens** (rest, trap, NPC results, etc.) can now be scrolled back through instead of the whole screen being one giant "tap to continue" — tap the left edge to move on early, scroll the rest to reread; default wait time increased to 10 seconds
- AI Provider screen no longer nags with "not set up yet" once every provider actually has a key
- DM Voice settings screen gained its missing help button
