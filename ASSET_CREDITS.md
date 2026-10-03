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
| `Characters/Basic Charakter Actions.png` | 96x576 = 2 cols x 12 rows of 48x48. **One action is a 2x2 block** (rows 2b,2b+1 x cols 0,1), not a row — see below |
| `Characters/Free Chicken Sprites.png`, `Free Cow Sprites.png` | Animals (not wired up yet) |
| `Characters/Egg_And_Nest.png`, `Objects/Egg_item.png` | Animal produce (not wired up yet) |
| `Objects/Basic_Plants.png` | 96x32, 6x2 cells of 16x16: crop growth stages (see `docs/DECISIONS.md`) |
| `Objects/` (others) | Furniture, grass-biome decor, chest, chicken house, paths, bridge, tools, milk item |
| `Sprout Lands color pallet/` | Reference palette (`.aseprite` + `.png`) |

## Sheet layouts used by the code

`sence`-era assumptions are documented in `docs/DECISIONS.md`. Short version:

**`Basic Charakter Spritesheet.png`** — 48x48 frames, two frames per animation,
laid out as `(x = 0 then 48)` by direction rows `A=down, B=up, C=left, D=right`:

| Animation | Sheet | x | y |
|---|---|---|---|
| `idle_front/back/left/right` | Spritesheet | 0, 48 | 0 / 48 / 96 / 144 |
| `walk_front/back/left/right` | Spritesheet | 96, 144 | 0 / 48 / 96 / 144 |

**`Basic Charakter Actions.png`** — 96x576 = **2 cols x 12 rows** of 48x48.
The sheet is only 96px wide, so a 4-frame animation **cannot** be one row:
one action is a **2x2 block** (rows `2b`, `2b+1`; columns 0, 1), giving 6 blocks
= 3 actions x 2 orientation groups (even blocks face front/back, odd blocks
left/right). Frames run in reading order: `(0,0) (1,0) (0,1) (1,1)`.

Which game tool uses which block is in `tools/gen_player_scene.py`
(`TOOL_ACTION`); the frame rectangles are asserted to be inside the texture by
`scripts/dev/selftest.gd`.

**`Characters/Tools.png`** — 96x96 = 6x6 cells of 16x16. It is **not** 36 tools:
it is **3 tools x 2 states x 6 orientations** (rows 0/1 = tool A, rows 2/3 = tool B,
rows 4/5 = tool C; the second row of each pair is the "in use" state). Picking
several cells out of the same pair is what produced the old "all four tool icons
are the same tool" bug. The icon table lives in `scripts/ui/tool_icons.gd`.

**`Objects/Basic_Plants.png`** — 16x16 cells, row 0 = wheat (green → yellow),
row 1 = greens; columns 1..4 are the growth stages, column 0 is a dirt mound,
column 5 a rock.

**`Tilesets/Tilled_Dirt_Wide.png`** — cell `1:1` is the only fully opaque,
single-colour flat soil tile (verified per-cell); it is used as the tilled-soil
sprite in `scripts/farm/farm_cell.gd`.

The `_v2` variants are simply the non-`_v2` files with the RGB of fully
transparent pixels zeroed out — visually identical; the non-`_v2` ones are used.

---

# HUD pixel font (`game_source/font/`)

**The Sprout Lands pack contains no font file**, and Godot's default font is an
anti-aliased vector face that looks wrong on a pixel-art screen. So the HUD font
is generated: `tools/gen_pixel_font.py` renders ASCII through a system font and
thresholds it to 1-bit, emitting `sprout_ui.png` + `sprout_ui.fnt` (BMFont text
format).

**Source font: Noto Sans SC** (`C:/Windows/Fonts/NotoSansSC-VF.ttf`), by Google /
Monotype, licensed under the **SIL Open Font License 1.1**. The OFL permits
redistribution and embedding of derived works, so the generated bitmap font may
ship with this repository.

> An earlier revision of the font was rasterised from **Consolas** (Microsoft).
> Consolas is bundled with Windows and **may not be redistributed**, which is a
> licence problem for a public repository, so it was replaced.

Noto Sans SC is a variable font whose default instance is **Thin** (weight 100);
at 12px that rasterises to broken 1px strokes. The generator drives the `Weight`
axis to 400 before rendering — see the comment at the top of the script.
