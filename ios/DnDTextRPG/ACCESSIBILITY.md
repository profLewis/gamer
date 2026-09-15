# Accessibility Statement

DnD Text RPG is committed to providing an inclusive gaming experience. The following accessibility features are available:

## Visual Accessibility

- **Adjustable Text Size** -- Font size can be set to Small, Medium, or Large in Settings > Accessibility, and on iPhone/iPad it also follows the system text size (Dynamic Type: Settings > Display & Brightness > Text Size, or Accessibility > Larger Text), capped so text never spills off the screen. *System Size Off* in Font Size turns that off. The entire terminal interface scales accordingly.
- **High-Contrast Display** -- The terminal-style interface uses bright text on a dark background. Every text colour meets WCAG AA contrast (at least 4.5:1 on black — the dimmest green is 5:1); with the system's *Increase Contrast* setting on, the dim colours step up to AAA (7:1 or more). Button colours are distinct and meaningful: green for actions, cyan for chat, amber for NPCs, red for destructive actions.

## Audio Accessibility

- **DM Voice Output** -- The Dungeon Master can read responses aloud using text-to-speech, allowing players to listen to game narration rather than reading it. Customise the voice, speed, and pitch in Settings > DM Voice.
- **Speaker Mode** -- A persistent read-aloud toggle (tap the speaker icon) that narrates story text as you play. Stays on until you switch it off. Reads only story and narration — not button labels.
- **Voice Input** -- Players can speak commands and questions to the Dungeon Master using voice input (tap the microphone icon), reducing the need for typing.
- **Voice Menu Control** -- Enable Voice Menus in Settings > Accessibility to select menu options by speaking the button name or number.
- **Combat Sound Effects** -- Optional hit flash effects can be toggled off in Settings > Accessibility (Hits Off).
- **Music Controls** -- Background music and battle sounds can be independently toggled in Settings.

## Motor Accessibility

- **Minimum Tap Targets** -- All interactive buttons and controls meet the recommended 44x44 point minimum tap area for comfortable interaction.
- **Swipe Navigation** -- Swipe left to go back from any screen, reducing the need for precise tapping.
- **Long-Press Shortcuts** -- Many actions have long-press alternatives for faster access (e.g. long-press Rest for a long rest, long-press party size to auto-fill).
- **Keyboard Return** -- Press return with empty input to take a default action (select the default button, or move in a random direction during exploration).
- **Custom On-Screen Keyboard** -- An optional simplified keyboard optimised for game input.
- **macOS Keyboard Support** -- Full keyboard navigation on Mac: arrow keys and WASD for movement, letter keys for menu selection.

## Cognitive Accessibility

- **Simple Navigation** -- Menu-driven interface with clear, labelled options avoids complex gesture requirements.
- **Undo/Redo** -- Character editing, party review, and settings screens support undo and redo for reversible changes.
- **Context-Sensitive Tips** -- Gameplay hints appear periodically based on what you're currently doing.
- **Comprehensive Help** -- 12 help topics, 50+ FAQ entries, in-game bestiary, and NPC guide available from the How to Play menu.

- **Reading at your own pace** — screens that move on by themselves (Auto-Continue) show a countdown hourglass at the right of the input line, so nothing disappears as a surprise. Tap it to pause (it turns orange) and the screen waits for you; long-press to hurry; tap anywhere to continue at once. Auto-Continue, its timeout, and the hourglass itself can each be changed or turned off in Settings > Gameplay.

## Using the accessibility tools

The game follows the usual accessibility checklist (WCAG 2.2's perceivable / operable / understandable / robust principles, and Apple's Human Interface Guidelines for VoiceOver, Dynamic Type, Reduce Motion and touch targets). Everything below is in **Settings > Accessibility** or **Settings > Gameplay** unless noted.

**Vision**
- *Display Size* — Small / Medium / Large text and icons together.
- *DM Voice* and *speaker mode* — the Dungeon Master reads the story aloud; *Companion Voices* give party members their own voices.
- *VoiceOver* — menu buttons read their names; the D-pad reads "Go North", "North, barred", "Search the room", "Listen", "Light torch"; the 3-bar cell reads "Help", "Back", "Next page"; the map pane reads a summary ("You are in the Crumbling Chamber. Exits: North, South. Here: a merchant."). Decorative ASCII art is skipped.
- Colour is never the only signal — every coloured state also has text (PLAYING / W / L, "paused", "(locked)").

**Hearing**
- All sound is optional (*Music*, *Sound FX*); every sound effect has a matching line of text.

**Motor**
- Buttons are at least 44 pt tall. *Long Press* sets how long a long-press takes.
- *Left/Right-Handed* — which edge of the text is kept free for scrolling.
- Type or speak instead of tapping: typing a button's name presses it; text mode lets you play entirely by typing; *Voice Menus* adds a microphone.
- Long-press a destructive button to skip its "are you sure?".

**Reading at your own pace / cognitive**
- *Auto-Continue* with a visible countdown hourglass you can pause, hurry or turn off; *Info Timeout* sets the wait, and a screen never moves on before it could be read.
- *Auto-Scroll* (off by default) — pages always open at the top; turn it on to glide down long text at a chosen speed.
- *Reduce Animations* — stops flashes, blinking and spinning (follows the device's Reduce Motion until you choose).
- A breadcrumb at the top of each page says where you came from and what just happened; every screen has a **?** help page; links in help text jump straight to the setting they mention and **Back** returns you.

## Playing with VoiceOver — notes and suggestions

These notes come from a review of the app's code and labels; they still need confirming by a VoiceOver user on a real device.

What should work well
- Every menu choice is a real button with its full name ("1. Actions"), including the 3-bar navigation ("Back", "Help").
- The D-pad, corner icons, close and microphone buttons all have spoken labels.
- The story text is ordinary text, read line by line; ASCII art is skipped; the map pane is a spoken summary.
- **New text is announced**: when a result, warning or new page appears, VoiceOver reads it out even if your focus is down on a button (gathered for a moment, then queued behind whatever VoiceOver is saying). Off in speaker mode, which reads aloud itself.
- **Stats are read with their values**: box lines and bar graphics are dropped and shorthand spelt out — a character card's "STR ████░░ 16" is read "strength 16", "HP 12/20" "hit points 12 of 20".
- **Reading order** is top to bottom: the map, the story, then the buttons, then the input line — in both portrait and landscape.
- Icon buttons all have names: Undo, Redo, Read the screen aloud, Next/Previous card, Random, Hide keyboard; D-pad directions say "Go north", "North, locked", "North, can't see in the dark".
- The auto-continue hourglass is a labelled button ("Auto-continue countdown. Tap to pause, long-press to hurry").

Recommended settings
- *Card Navigation: Use Buttons* — card browsing by swipe clashes with VoiceOver's own swipe gestures.
- *Auto-Continue* off, or a long *Info Timeout* — so screens don't move on while VoiceOver is still reading.
- *Idle Prompts* off — otherwise taking a long time over a combat choice gives an attack penalty ("hesitation").
- *DM Voice* can double up with VoiceOver; most VoiceOver users will prefer one or the other.
- Long-press = VoiceOver double-tap-and-hold.

Known gaps / ideas for improvement
- Screen titles aren't marked as headings, so the VoiceOver rotor can't jump between sections yet.
- The Atlas map overlay is visual; its room list (Explore) is the accessible way to use it.
- Combat hesitation should probably switch itself off whenever VoiceOver is running.

## Feedback

If you have suggestions for improving accessibility in DnD Text RPG, please open an issue at [github.com/profLewis/gamer](https://github.com/profLewis/gamer).
