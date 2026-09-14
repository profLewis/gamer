# Puzzles

The game poses puzzles in libraries and shrines. They get harder the deeper you go:

| Levels | Tier | Kind | How you answer |
|---|---|---|---|
| 1–2 | 1 | Riddles | Pick one of four |
| 3–4 | 2 | Logic puzzles | Pick one of four |
| 5–6 | 3 | Word puzzles | Type the answer |
| 7 | 4 | Cryptic clues | Type the answer (hints cost a little of the reward) |

A good set is built into the app. More arrive from this folder without an app update.

## Suggest a puzzle

In the game: **Settings > Puzzles > Suggest a Puzzle**. That opens a pre-filled GitHub issue.
Or open one yourself with the label `puzzle-suggestion` and include:

- the question,
- the answer (and any other answers that should count),
- up to three hints, easiest last,
- which levels it suits,
- where it comes from. Only your own puzzles or traditional, public-domain ones, please.

## Format

`source.json` is the editable list. Each puzzle is:

```json
{
  "id": "unique-id",
  "tier": 2,
  "kind": "logic",
  "question": "…",
  "options": ["Correct answer first", "Wrong", "Wrong", "Wrong"],
  "answers": ["typed answer", "another accepted spelling"],
  "hints": ["A nudge", "A bigger nudge"],
  "source": "Where it's from"
}
```

- `tier` is 1–4 (see the table above).
- Use `options` for multiple choice, with the correct answer first (the game shuffles them). Use `answers` for typed puzzles.
- Typed answers ignore capitals, spaces, punctuation and a leading "a", "an" or "the".
- A puzzle whose `id` matches a built-in one replaces it.

## Publishing a new pack (maintainer)

The game only installs `pack.json` if:

- its Ed25519 signature matches the public key built into the app;
- its `version` is newer than the one the player already has, so it can't be rolled back;
- it's under 256 KB and every puzzle passes the same checks as the signing tool.

1. Edit `source.json` and bump `version`.
2. Run `swift tools/sign-puzzle-pack.swift puzzles/source.json puzzles/pack.json`. The private key lives at `~/.config/gamer/puzzle-signing-key`, **never in the repo**.
3. Commit both files to `main`.

Players pick the pack up within a day, or straight away with **Settings > Puzzles > Check for New Puzzles**. Both files are small text files, well within normal Git limits (no LFS needed).
