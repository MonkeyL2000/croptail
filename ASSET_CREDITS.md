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
| `Characters/Basic Charakter Actions.png` | 96x576 = 2 cols x 12 rows of 48x48. **2 columns = the two frames of one action; 12 rows = 3 actions x 4 directions** — see below |
| `Characters/Free Chicken Sprites.png` | 64x32, two 2-frame rows (idle / walk); used by `scripts/world/chicken.gd` |
| `Characters/Free Cow Sprites.png` | Cow (not wired up yet) |
| `Characters/Egg_And_Nest.png`, `Objects/Egg_item.png` | Animal produce (not wired up yet) |
| `Objects/Basic_Plants.png` | 96x32, 6x2 cells of 16x16: crop growth stages (see `docs/DECISIONS.md`) |
| `Objects/` (others) | Furniture, grass-biome decor, chest, chicken house, paths, bridge, milk item |
| `Objects/Basic_tools_and_meterials.png` | 48x32 = 3x2 cells: rocks + logs, **and two unused hand-tool sprites** used here as axe / pickaxe (inferred names — see `docs/DECISIONS.md#gather-tools`) |
| `Tilesets/Fences.png` | 64x64 = 4x4 cells: post + horizontal rails (rows 1/2 have the rails); used for the chicken pen |
| `Objects/Free_Chicken_House.png` | 48x48 = one 3x3-cell chicken coop |
| `Sprout Lands color pallet/` | Reference palette (`.aseprite` + `.png`) |
| `Pets/` | **Not part of the pack** — the pet dog, supplied by the project owner. See the section at the bottom of this file |

## Sheet layouts used by the code

`sence`-era assumptions are documented in `docs/DECISIONS.md`. Short version:

**`Basic Charakter Spritesheet.png`** — 48x48 frames, two frames per animation,
laid out as `(x = 0 then 48)` by direction rows `A=down, B=up, C=left, D=right`:

| Animation | Sheet | x | y |
|---|---|---|---|
| `idle_front/back/left/right` | Spritesheet | 0, 48 | 0 / 48 / 96 / 144 |
| `walk_front/back/left/right` | Spritesheet | 96, 144 | 0 / 48 / 96 / 144 |

**`Basic Charakter Actions.png`** — 96x576 = **2 cols x 12 rows** of 48x48.
**The two columns are the two frames of one action, and one row is one
*direction***: 12 rows = 3 actions (rows `0-3`, `4-7`, `8-11`) x 4 directions,
ordered front / back / left / right inside each action. Rows are exact mirror
pairs for left/right, which is how the layout was measured.

> An earlier revision read rows `2b` and `2b+1` as "4 frames of one action".
> That made `use_*_left` and `use_*_right` the *same* animation (each alternating
> a left and a right frame) — the reported "the action swings to both sides" bug.
> Evidence and the annotated layout image are in `docs/DECISIONS.md#action-blocks`
> and `docs/art/actions_groups.png`.

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

---

# Pet dog (`game_source/Pets/`) — **licence unconfirmed**

**This is not part of the Sprout Lands pack.** The project owner supplied it as
`lilpuddinpuggums.png` (96x192, RGB, white background, 3 cols x 4 rows of 32x48).
The filename suggests a third-party itch.io asset, but **the author, source and
licence have not been confirmed yet** — see `docs/PROGRESS.md` > 卡点 > 待确认 4.

**Until that is settled, do not publish this folder or ship it in a release.**
If the terms turn out not to allow redistribution, add `game_source/Pets/` to
`.gitignore`: the game still runs without it (only the dog disappears), because
`scenes/main.tscn` only references the packed sheet.

| Path | Contents |
|---|---|
| `Pets/lilpuddinpuggums.png` | the raw source, kept unmodified as pipeline input |
| `Pets/pug_walk.png` | 48x96 = 3 cols x 4 rows of 16x24, produced by `tools/pack_dog.py` — this is what the game loads |

`tools/pack_dog.py` keys the white background to alpha, centres each row, and
samples 2:1 (the source is a clean 2x nearest-neighbour upscale — verified: only
152 of 18432 pixel pairs differ). The right-facing row is sampled on odd x
because the mirror axis sits on a half source-pixel; that makes the left frames
exact mirrors of the right ones. Human-checkable preview: `docs/art/pug_sheet.png`.
Re-run it (then one editor pass to reimport) if the source is ever replaced.
