# Adventure files

Each new adventure opens with a tale: the village in trouble, the villain waiting at the bottom of the dungeon (the Level 7 guardian), the quest, and the party setting off.

The game keeps its adventures as small JSON files in its own **Adventures** folder:

- Seven default adventures ship with the game and are written there on first use.
- The game reads every `.json` file in that folder.
- To add your own, use **Adventure Log > Import Log** and choose the file.
- When a new adventure doesn't have the AI story writer, it may play one of these files' tales, with the party and dungeon filled in.
- When the story writer (AI) is on, it's shown two tales from the folder as examples of the style, and writes a new one for your party.
- Every tale it writes is kept in the folder (up to 40) as another example, so the style carries on and grows.

## Format

```json
{
  "title": "The Salt Wells",
  "village": "Brackenford",
  "villain": "Morwen the Brine Witch",
  "goal": "break the curse that has turned Brackenford's wells to salt",
  "stakes": "before the last barrel of fresh water runs dry",
  "reward": "a year's free ale at the Drowned Duck, and three hundred gold",
  "tale": [
    "In Brackenford the wells have turned to salt, and the children cry for water in their sleep.",
    "…",
    "The stone door of {dungeon} is cold and wet, and it smells of the sea."
  ],
  "author": "Your name"
}
```

- `tale` is 3 to 14 lines, one short paragraph each. The last line should see the party step into the dungeon.
- These placeholders are filled in when the tale is played: `{party}` (the adventurers' names), `{dungeon}`, `{village}`, `{villain}`, `{goal}`, `{stakes}` and `{reward}`.
- The villain's name before any comma is what they're called in the final fight ("Mother Sable, the Hag of the Deep" → "Mother Sable").
