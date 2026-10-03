# The Sprout Lands Basic Pack

Sprite and tileset credits:

- **Assets from: Sprout Lands - By: Cup Nooble**
- Asset pack page: https://cupnooble.itch.io/sprout-lands-asset-pack

## License summary (see `read_me.txt` for the full text)

This project uses the **Sprout Lands Basic Pack** by Cup Nooble. The pack's terms:

- **Non-commercial use only.** All assets are licensed for non-commercial projects.
- **Credit is required:** "Assets From: Sprout Lands - By: Cup Nooble".
- **AI training is not allowed** — the pack may not be used to train AI models, and
  NFTs are explicitly excluded.
- **Do not redistribute or resell the asset pack itself** (even slightly modified).
  Shipping your own game made with the assets, including open source, is allowed.
- Modifying the assets and making new sprites in the same style is allowed.

If you fork this repository, these terms travel with the `game_source/` folder.

## What is in `game_source/`

| Path | Contents |
|---|---|
| `Tilesets/` | Grass / Hills / Tilled_Dirt(_Wide)(_v2) 176x112 sheets, Water, Fences, Doors, house roof & walls |
| `Tilesets/Bitmask references 1-2.png` | Terrain peering-bit reference sheets (not used at runtime) |
| `Characters/Basic Charakter Spritesheet.png` | 192x192, 4x4 grid of 48x48 frames: idle (row A) + walk (row C) in 4 directions |
| `Characters/Basic Charakter Actions.png` | 96x576: tilling / watering / hoeing / axe / pickaxe actions, same 48x48 layout |
| `Characters/Free Chicken Sprites.png`, `Free Cow Sprites.png` | Animals (not wired up yet) |
| `Characters/Egg_And_Nest.png`, `Objects/Egg_item.png` | Animal produce (not wired up yet) |
| `Objects/Basic_Plants.png` | 96x32, 6x2 cells of 16x16: crop growth stages (see `docs/DECISIONS.md`) |
| `Objects/` (others) | Furniture, grass-biome decor, chest, chicken house, paths, bridge, tools, milk item |
| `Sprout Lands color pallet/` | Reference palette (`.aseprite` + `.png`) |

## Sheet layouts used by the code

`sence`-era assumptions are documented in `docs/DECISIONS.md`. Short version:

**`Basic Charakter Spritesheet.png` / `Basic Charakter Actions.png`** — 48x48 frames,
two frames per animation, laid out as `(x = 0 then 48)` by direction rows
`A=down, B=up, C=left, D=right`:

| Animation | Sheet | x | y |
|---|---|---|---|
| `idle_front/back/left/right` | Spritesheet | 0, 48 | 0 / 48 / 96 / 144 |
| `walk_front/back/left/right` | Spritesheet | 96, 144 | 0 / 48 / 96 / 144 |
| `use_front/back/left/right` | Actions | 0, 48 | 0 / 48 / 96 / 144 |

**`Objects/Basic_Plants.png`** — 16x16 cells, row 0 = wheat (green → yellow),
row 1 = greens; columns 1..4 are the growth stages, column 0 is a dirt mound,
column 5 a rock.

**`Tilesets/Tilled_Dirt_Wide.png`** — cell `1:1` is the only fully opaque,
single-colour flat soil tile (verified per-cell); it is used as the tilled-soil
sprite in `scripts/farm/farm_cell.gd`.

The `_v2` variants are simply the non-`_v2` files with the RGB of fully
transparent pixels zeroed out — visually identical; the non-`_v2` ones are used.
