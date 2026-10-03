# croptail

A small pixel farming game: **till soil, plant seeds, water them daily, harvest,
sell for coins.** Built with Godot 4.3 on the
[Sprout Lands Basic Pack](https://cupnooble.itch.io/sprout-lands-asset-pack)
by [Cup Nooble](https://cupnooble.carrd.co).

> **Asset licence:** the art is non-commercial only, credit is required, and it
> may not be used for AI training. Any fork must keep `ASSET_CREDITS.md` and
> `read_me.txt`. See [`ASSET_CREDITS.md`](ASSET_CREDITS.md).

## Play

Requires Godot 4.3 (no build step, no export preset yet).

```
godot --path /path/to/croptail
```

or open `project.godot` in the editor and hit F5.

### Controls

| Key | Action |
|---|---|
| WASD / arrow keys | walk (4 directions) |
| Space | use the current tool on **the tile you are facing** |
| 1 / 2 / 3 / 4 | hoe / watering can / seeds / harvest |
| Q / E | previous / next tool |
| R | switch crop (wheat ⇄ greens) |
| B | buy 1 seed of the current crop (costs coins) |
| T | skip to the next day (a day is 45s on its own) |

### The loop

1. Hoe a tile in the farm plot — it becomes tilled soil.
2. Plant seeds (you start with a few; buy more with `B`).
3. Water the planted tile. **Only watered crops grow, and watering dries up
   overnight**, so every tile needs attention every day.
4. After 4 watered days the crop is mature (it glints); harvest it with `4`.
5. Harvesting pays coins. A day passes on its own every 45 seconds, or press `T`.

## Layout

| Path | Contents |
|---|---|
| `scenes/main.tscn` | main scene: map + farm plot + player + HUD |
| `scenes/dev/selftest.tscn` | logic self-check scene (not the game) |
| `scenes/world/farm_map.tscn` | water / grass / decor tile layers |
| `scripts/core/` | autoloads (`GameState`, `TimeManager`) and main wiring |
| `scripts/farm/` | `FarmPlot`, `FarmCell`, `CropData`, `CropDB` |
| `scripts/player/` | player body + idle / walk / use states |
| `scripts/state_machine/` | generic node-based FSM, game-agnostic |
| `scripts/world/`, `scripts/ui/` | map collision generation, HUD |
| `docs/` | `PROGRESS.md` (where it is) and `DECISIONS.md` (why) |

## Self-check

Logic changes are verified with an in-engine assertion scene rather than by
hand — it drives the real scenes and prints a summary:

```bash
godot --path . res://scenes/dev/selftest.tscn
```

It ends with `=== SELFTEST END: N checks, 0 failed ===` and covers soil rules,
the growth cycle, sprite atlas coordinates, state transitions, movement,
main-scene wiring, and the water collision wall.

## Credits

- Art — **Sprout Lands Basic Pack, by Cup Nooble** (required credit).
- Code — MIT-style: use it however you like.

## Roadmap

See [`docs/PROGRESS.md`](docs/PROGRESS.md). Next up: map furniture (chicken
house, bridge, fences), animal produce, a real shop instead of instant coin
gain, and saving.
