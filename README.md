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
- **Six generators** (Shard Miner → Crystal Temple) that produce shards every second. Each purchase raises that generator's price by 15%.
- **Saving**: progress autosaves every 10 seconds and whenever the app is closed or sent to the background (`user://save.json`).
- **Offline income**: when you come back, you get everything your generators would have made while you were gone, up to 8 hours, with a "Welcome back!" popup.

## Project layout

| Path | What it is |
| --- | --- |
| `scripts/game_state.gd` | Autoload `Game`: economy, save/load, offline income, number formatting |
| `scripts/main.gd` | Main screen UI (built in code) |
| `scripts/crystal.gd` | The procedurally drawn, tappable crystal |
| `scenes/main.tscn` | Main scene |
| `tests/test_game_state.gd` | Headless logic tests |

## Tests

```sh
godot --headless --path . -s tests/test_game_state.gd
```

Exits with code 0 when all checks pass. (One "Parse JSON failed" error in the output is expected: it comes from the corrupt-save test.)

## Next steps

- Android export preset and APK build
- Real art, sound, and more upgrade types
