# Crystalize

An idle "cookie clicker"-style mobile game about crystals, built with **Godot 4.3**.

Tap the crystal to earn shards, spend them on generators that mine for you, and come back later to collect what they dug up while you were away.

## Running it

1. Install [Godot 4.3](https://godotengine.org/download) (standard build, not .NET).
2. Open Godot, click **Import**, and pick `project.godot` in this folder.
3. Press **F5** (or the ▶ button) to play.

The window opens in a phone-shaped portrait layout (720×1280, scaled down on desktop).

## What's in the game so far

- **Tap the crystal** for shards (with a bounce and floating "+N").
- **Sharper Pickaxe** upgrade doubles shards per tap each level.
- **Geodes**: buy them with shards (each costs 18% more than the last) or find them by tapping (1.5% chance per tap). Opening one reveals a crystal from seven rarities, and every crystal you own permanently boosts all production:

  | Rarity | Crystal | Chance | Bonus each |
  | --- | --- | --- | --- |
  | Common | Quartz | 55% | +1% |
  | Uncommon | Amethyst | 25% | +3% |
  | Rare | Sapphire | 12% | +8% |
  | Epic | Void Opal | 5.5% | +20% |
  | Legendary | Sunstone | 2% | +50% |
  | Mythic | Bloodheart Ruby | 0.45% | +150% |
  | Celestial | Starcore Diamond | 0.05% | +500% |

- **Six generators** (Shard Miner → Crystal Temple) that produce shards every second. Each purchase raises that generator's price by 15%.
- **Saving**: progress autosaves every 10 seconds and whenever the app is closed or sent to the background (`user://save.json`).
- **Offline income**: when you come back, you get everything your generators would have made while you were gone, up to 8 hours, with a "Welcome back!" popup.

## Project layout

| Path | What it is |
| --- | --- |
| `scripts/game_state.gd` | Autoload `Game`: economy, geodes and rarities, save/load, offline income, number formatting |
| `scripts/main.gd` | Main screen UI (built in code) |
| `scripts/crystal.gd` | The tappable crystal (picked art, or drawn procedurally) |
| `scripts/art.gd` | Loads picked art by slot name |
| `tools/artgen/` | Generate and pick art with OpenAI |
| `scenes/main.tscn` | Main scene |
| `tests/test_game_state.gd` | Headless logic tests |

## Tests

```sh
godot --headless --path . -s tests/test_game_state.gd
```

Exits with code 0 when all checks pass. (One "Parse JSON failed" error in the output is expected: it comes from the corrupt-save test.)

## Art

The game draws everything procedurally until real art is picked. Pictures go in
`assets/art/<slot>.png` and are loaded automatically (`scripts/art.gd`):

| Slot | Used for |
| --- | --- |
| `crystal` | The big tappable crystal |
| `background` | Main screen background (720×1280) |
| `gem_common` … `gem_celestial` | The gem shown when a geode is opened, one per rarity |

`tools/artgen/artgen.py` makes options with the OpenAI Images API (needs `OPENAI_API_KEY`):

```sh
python3 tools/artgen/artgen.py generate crystal "a glowing violet crystal cluster"
python3 tools/artgen/artgen.py pick /mnt/project-files/art/candidates/crystal/<round> 2
```

`generate` saves 3 options and a numbered `preview.png`; run it again to retry.
`pick` resizes the chosen option into `assets/art/`.

## Next steps

- Android export preset and APK build
- Real art, sound, and more upgrade types
