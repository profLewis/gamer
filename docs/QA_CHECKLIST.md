# Manual QA Checklist

A run-through checklist for verifying the game works as intended. Not
automated — walk through each section in-game and check items off. Re-run
the relevant section after any change that touches that system.

Tip: the [Adventure Log export](../README.md) (Adventure Log > Export Log)
is a good way to capture a session's events afterward if you spot something
wrong and want a record to report back.

## 1. Character Creation

- [ ] Create a party of 1, then 2, then 4 characters
- [ ] Each of the 12 races is selectable and applies its ability bonuses
- [ ] Each of the 6 classes is selectable and grants correct starting gear
- [ ] Standard array and 4d6-drop-lowest both work for ability scores
- [ ] Long-press a party size auto-generates an all-AI party
- [ ] Name suggestions appear and can be picked or typed freely
- [ ] Starting HP, AC, and inventory match the chosen class/race

## 2. Exploration

- [ ] Minimap shows current position; dynamic key only lists symbols present
- [ ] Merchant-bearing rooms show `[M]` on the map once discovered
- [ ] Torch lighting/dousing changes visibility and map detail correctly
- [ ] Search finds hidden items/gold in rooms that have them; corridors and
      empty rooms occasionally yield a "dropped purse" of gold
- [ ] Barricading/unsecuring a door works and persists
- [ ] Listening at a door gives a sound hint about what's beyond
- [ ] Trap rooms trigger correctly:
  - [ ] Thieves' Tools in the party sometimes disarms a trap entirely
  - [ ] Rope halves damage specifically on a Pit Trap
  - [ ] Damage lands correctly when neither item is carried
- [ ] Riddle rooms (library/shrine): "Solve Riddle" button appears, question
      displays, multiple-choice answer works, correct answer grants gold +
      item, two wrong attempts ends the challenge without other penalty,
      "Leave it" exits cleanly

## 3. Combat

- [ ] Initiative order, attack rolls, and damage resolve correctly
- [ ] Critical hits (nat 20) and misses (nat 1) behave correctly
- [ ] Death saving throws: 3 successes stabilizes, 3 failures kills
- [ ] Class features fire at the right level: Second Wind (Fighter L2),
      Sneak Attack scaling (Rogue), Rage (Barbarian), Hunter's Mark (Ranger)
- [ ] Dodge grants disadvantage to attackers next turn
- [ ] Play Dead (CHA/Deception) can bluff out of combat
- [ ] Flee returns to the previous room
- [ ] Poison applies and resolves (CON save to recover) each turn
- [ ] A sharpened weapon (Whetstone used) shows +1 to hit/damage for exactly
      3 attacks, then reverts

## 4. Spellcasting

- [ ] Cantrips are unlimited-use for casters
- [ ] Level 1 spell slots consume/refill correctly (short/long rest)
- [ ] **Level 3 Wizard/Cleric**: gains 2nd-level slots AND is taught new
      2nd-level spells (Scorching Ray/Acid Arrow for Wizard, Spiritual
      Weapon/Prayer of Healing for Cleric) — verify the new spells actually
      appear in both Party Status and the combat "Choose a spell" menu, each
      correctly labeled by level with correct slot counts
- [ ] Casting a spell (any level) deducts the correct slot, not just level 1
- [ ] Ranger's Hunter's Mark/Cure Wounds granted at level 2

## 5. Leveling

- [ ] XP awarded correctly after combat wins (both boss and non-boss)
- [ ] Level-up triggers automatically once enough XP is earned — including
      from ordinary (non-boss) fights, not just after defeating a boss
- [ ] HP gain on level-up uses hit die + CON mod
- [ ] **Ability Score Improvement** at level 4: player is offered a choice
      of ability to increase by 2 (capped at 20); AI-controlled party
      members auto-pick their class's primary ability; the increase is
      visible in Party Status and affects attack/damage rolls afterward
- [ ] Multiple level-ups in one jump (large XP reward) all process in
      sequence, not skipped

## 6. Merchants & the NPC Economy

- [ ] Shop room always has a merchant with a name/shop name/persona; tier
      (Wandering Peddler/General Store/Trading Post/Hyperstore) scales with
      dungeon depth
- [ ] Armoury rooms: when the room text says "a merchant has set up shop
      here," a merchant is actually reachable via "Visit Merchant"
- [ ] Wandering Trader NPCs also carry a named Merchant persona
- [ ] Buy: item list shows description + usage hint for each item; purchase
      deducts gold and adds the item; insufficient gold/carry weight blocks
      correctly
- [ ] Sell: items sell for half value
- [ ] Haggle: Persuasion check shown (roll + mod vs DC); success gives a
      15-30% discount and completes the purchase; failure leaves price as-is
- [ ] Ask About Rare Goods: chance-gated reveal; **the item, price, and Buy
      button must appear promptly (within ~5 seconds) even with AI enabled
      — this must never hang or time out silently.** Haggle option also
      available on the rare item at a slightly harder DC
- [ ] Occasional unsolicited advice line after shopping
- [ ] Non-merchant NPCs: "Ask to Trade" appears once per NPC; most decline
      in character; several (Dwarven Smith, Elf Scout, Mad Alchemist,
      Wounded Knight, Old Priestess, sometimes Mysterious Stranger) offer a
      one-off item sale; Goblin Defector has a chance to attack instead
      (verify this correctly starts combat and removes the NPC from the room)

## 7. Items & Inventory

- [ ] Pack (Inventory > Pack) lists every carried item
- [ ] "Use Item" button is enabled whenever a potion OR a Whetstone is
      carried (not just potions)
- [ ] Pack Help (the "?" button) lists every carried item with its
      description and a concrete usage hint (use/equip/passive/no action)
- [ ] Potions heal correctly; Antidote cures poison and no-ops otherwise
- [ ] Whetstone: blocked with a clear message if no weapon is equipped
- [ ] Equip/unequip weapons, armor, shields via the Equipment menu
- [ ] Drop Item and Give Item both work and respect carry weight

## 8. DM (all three tiers)

- [ ] **Basic (no AI)**: ask about merchants/shopping, leveling/getting
      stronger, quests/objectives/bosses, resting, combat tactics, lore,
      and party/companions — each should give a relevant, varied (not
      always identical) answer, not just generic atmosphere text
- [ ] **Apple on-device** (iOS 26+, supported hardware): responses should
      actually come from the model (context-aware, varies each time) rather
      than always falling back to the same canned Basic-tier lines — if it
      consistently looks identical to Basic-tier responses, the on-device
      call may be failing silently again
- [ ] **Cloud** (API key configured): richest responses, can affect game
      state at Moderate/Full ad-lib levels per Settings
- [ ] Ask an NPC repeatedly about "the boss"/"boss lair"/etc. — the boss
      type is progressively revealed with NPC-flavored text
- [ ] DM Voice / Speaker Mode read responses aloud without errors

## 9. Victory / Defeat

- [ ] Boss victory: Victory screen displays, stats/loot correct, Hall of
      Fame entry created
- [ ] The victory decision menu (Save & Continue / Continue / Save & End /
      End Adventure) responds to every tap reliably, including right after
      a long-press elsewhere in the app
- [ ] Any subsequent "press to continue" screen (level-up, "descends
      deeper...") can always be advanced by tapping the visible text, not
      only via the corner X icon or a keyboard Return press
- [ ] Defeat screen displays and returns to main menu correctly
- [ ] Time-limit-expired defeat (if a time limit is set) behaves the same way

## 10. Save / Load & Adventure Log

- [ ] Save, quick-save, and autosave all work; multiple save slots persist
- [ ] Loading a save restores party, inventory, dungeon, and log correctly
- [ ] **Loading an old (pre-this-update) save**: doesn't crash; merchants
      just won't appear in already-generated rooms (expected — only new
      dungeons/levels get merchants)
- [ ] Adventure Log: Export Log produces a readable .txt file with a
      header (date, event count) and all logged events
- [ ] Adventure Log: Import Log appends an external .txt file's lines to
      the current log (does not erase existing log entries)

## 11. Multiplayer

- [ ] Inviting a remote player via Game Center works
- [ ] Turn indicators (YOUR TURN / waiting / partner left) are correct
- [ ] Declining an invite lets the host continue solo with AI companions
- [ ] Nudge and pass-turn work without crashing mid-countdown
- [ ] Party chat with @mentions delivers correctly

## 12. Platform (iPhone / iPad / Mac)

- [ ] Builds and runs on iPhone (primary target)
- [ ] Builds and runs on iPad Simulator — layout is usable, not just
      technically running
- [ ] Builds and runs natively on Mac ("My Mac" destination) — keyboard
      input, window resizing, and menu navigation all behave sensibly
