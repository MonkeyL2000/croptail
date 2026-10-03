# croptail

A small pixel farming game: **till soil, plant seeds, water them daily, harvest,
sell for coins — and chop trees or mine rocks for materials.** There is a fenced
chicken pen with wandering chickens and a few ponds carved into the island.
Built with Godot 4.3 on the
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
| Space | use the current tool on **the tile you are facing** (an on-ground box shows it) |
| 1 / 2 / 3 / 4 | hoe / watering can / seeds / harvest |
| 5 / 6 | axe (trees, logs) / pickaxe (rocks) |
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

### Extras

- **Axe (`5`)** fells trees and chops logs for wood, **pickaxe (`6`)** breaks
  rocks for stone; the items show up in the materials box in the HUD corner.
  The box in front of you lights up when the current tool can act on that tile.
- **Chickens** wander inside the fenced pen east of the farm; **ponds** are real
  water (you cannot walk in) and the shore collision is generated from the grass
  island's outline at runtime.

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
| `scripts/world/` | map collision (`farm_map.gd`), ground props + landmarks + gather rules (`farm_props.gd`, `prop_db.gd`), chickens (`chicken.gd`) |
| `scripts/ui/` | HUD and the icon atlases (`hud.gd`, `tool_icons.gd`, `item_icon.gd`) |
| `docs/` | `PROGRESS.md` (where it is) and `DECISIONS.md` (why) |
| `docs/art/` | generated reference images (map render, sheet grids, action layout) |

## Self-check

Logic changes are verified with an in-engine assertion scene rather than by
hand — it drives the real scenes and prints a summary:

```bash
godot --path . res://scenes/dev/selftest.tscn
```

It ends with `=== SELFTEST END: N checks, 0 failed ===` (223 checks at the time
of writing) and covers soil rules, the growth cycle, sprite atlas coordinates,
state transitions, movement, main-scene wiring, the water collision walls, the
fence pen / chickens, axe & pickaxe rules, and the ponds.

## Credits

- Art — **Sprout Lands Basic Pack, by Cup Nooble** (required credit).
- Code — MIT-style: use it however you like.

## Roadmap

See [`docs/PROGRESS.md`](docs/PROGRESS.md). Next up: HUD hint messages for the
farm tools, a real shop instead of instant coin gain, eggs from the chickens,
and saving.
