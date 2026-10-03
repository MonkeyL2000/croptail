# croptail

> 项目级稳定事实。**每轮都会注入上下文,保持精简。**
> 进度 / 待办 / 卡点 → `docs/PROGRESS.md`;方案取舍 → `docs/DECISIONS.md`。

创建于 2026-10-03

## 项目定位

- 一句话:像素风小农场 —— 锄地、播种、浇水、收获、卖钱。
- 类型:2D top-down 农场模拟(单机,非商业)
- 仓库:https://github.com/MonkeyL2000/croptail
- 素材:Sprout Lands Basic Pack(Cup Nooble)—— 只许非商业使用、必须署名、禁止 AI 训练,
  详见 `ASSET_CREDITS.md`,改素材前先读它。

## 环境

- Godot:`D:\Godot_v4.3-stable_win64.exe\Godot_v4.3-stable_win64.exe`
- 项目路径:`D:\godot_projects\croptail`(bash:`/d/godot_projects/croptail`)
- 引擎版本:Godot 4.3.stable
- 主场景:`res://scenes/main.tscn`
- autoload:`GameState`(工具/金币/物品栏)、`TimeManager`(天数)—— 都在 `project.godot` 的 `[autoload]`

## 目录约定

| 路径 | 用途 |
|---|---|
| `scenes/` | 场景。`main.tscn`=主场景,`world/`=地图,`characters/`, `ui/`, `dev/`(自检场景) |
| `scripts/core/` | 全局:`game_state.gd`、`time_manager.gd`、`main.gd`、`game_input_events.gd` |
| `scripts/farm/` | 农田:`crop_data.gd`、`crop_db.gd`、`farm_cell.gd`(一格)、`farm_plot.gd`(网格+规则)、`target_indicator.gd`(面前那格的指示框) |
| `scripts/player/` | 玩家本体 + 三个状态(idle/walk/use) |
| `scripts/state_machine/` | 通用节点状态机(与游戏解耦) |
| `scripts/world/`, `scripts/ui/` | 地图生成、HUD |
| `main.tscn` 的节点顺序 | `FarmMap` → `Player` → `TargetIndicator`(指示框必须在最后 = 画在最上面),HUD 是 `CanvasLayer` 永远在最上 |
| `scenes/dev/` | 开发工具场景:`selftest`(自检)、`screenshot`(出图)、`map_dump`(ASCII 地图)、`retile`(重算地形图块)、`grass_terrain_ref`(旧地图快照,当 peering 的标准答案) |
| `scripts/dev/` | 上面那些工具的实现。都是 dev-only,不影响主场景 |
| `game_source/` | 原版素材,勿改名(名字里有空格,勿动);`game_source/font/` 是生成的 HUD 点阵字体 |
| `tools/` | 生成器(Python)。**生成物已入库,不跑也能开发**;要改字体/玩家场景/对照图才跑 |
| `docs/art/` | 给图集加的坐标网格图 / peering 对照图 / 整张地图渲染(`tools/annotate_*.py`、`tools/render_map.py` 生成),用来人工确认「哪格是什么」 |
| `tilesets/test_tilemap.tres` | TileSet(仍沿用旧文件名) |
| `docs/` | 长期记忆:进度、决策 |

### `tools/` 里的生成器

| 脚本 | 作用 |
|---|---|
| `gen_pixel_font.py` | 生成 `game_source/font/sprout_ui.{png,fnt}` + `docs/art/font_preview.png` |
| `gen_player_scene.py` | 重新生成 `scenes/characters/player.tscn`(24 个动画 + Camera2D) |
| `annotate_sheet.py` | 给图集画格线存到 `docs/art/`,方便人工核对格子含义 |
| `annotate_actions.py` | 把 `Basic Charakter Actions.png` 的版式(3 个动作组 x 4 个朝向)框出来标好,存 `docs/art/actions_groups.png` |
| `annotate_terrain.py` | 把 TileSet 的 peering 信息画到图集上(`docs/art/terrain_*.png`):每格右上角一个九宫格,填色 = 那个方向也是同种地面 |
| `render_map.py` | 离线把 `farm_map.tscn` 的地形层合成成一张整图(`docs/art/map.png`)。**看草坪对不对看这张**,不要在游戏里对着一小块猜 |
| `extract_props.py` | 连通域分析道具图集(只是**建议**,权威表在 `prop_db.gd`) |

生成器是「离线算一遍,结果入库」的路子 —— 不要把它们塞进构建流程。

## 硬性约定

- 开发必须通过 Godot MCP 驱动,不要用 `godot --headless` 绕过(见 skill `godot-dev`)。
- **改了 `game_source/` 里的资源(`.png`/`.fnt`/…）后,必须 `launch_editor` 开一次项目
  让它重新导入,再 `run_project`。`run_project`(godot -d)**不会**重新导入,
  于是你会一直在量/看**旧缓存**,而引擎不报任何错。
  判断是否真的重新导入了:看 `.godot/imported/<名字>-*.md5`/`*.ctex` 的 mtime
  是否比 `game_source/` 里的源文件新。
  (踩过:改了三版字形度量都没生效,白查了很久。新增 `class_name` 脚本同理。)
- 每次改动后跑 `run_project` + `get_debug_output`,无 ERROR 才算完成。
- **逻辑改动就跑自检场景**:`run_project {scene: "res://scenes/dev/selftest.tscn"}`,
  输出里有 `=== SELFTEST END: N checks, 0 failed ===` 才算过。
  人按键验不了规则,自检才是这类改动的「跑通」。
- **全部 UI 文案用 ASCII**:HUD 用的点阵字体只覆盖 ASCII(见 `ASSET_CREDITS.md`),
  中文会显示成方块/空白。
- **HUD 的字体和字号必须在代码里显式钉死**(`hud.gd::_apply_theme()`):
  只写 `Theme.default_font` 不写 `Label` 类型那一份,`get_theme_font()` 会
  静默回退到 Godot 内置的 Open Sans;字号不钉成 12 则点阵字被放大 16/12,
  行高从 15 变 20,字顶被顶出面板裁掉。两条都有自检断言钉着。
- **地形的 atlas 坐标不要自己指派**:草地/泥地该画哪一块由 TileSet 的 terrain
  (peering)决定,**只有引擎知道**(`scripts/dev/retile.gd` 调
  `set_cells_terrain_connect()`)。刷完地图形状要重跑一次 `retile.gd`,
  否则新格子全是同一个角块(踩过:整片草坪铺满左上角块,见 DECISIONS#grass-terrain)。
- **每个 `TileMapLayer` 自己的 `position` 不同**(water 在 (0,0)、grass 在 (-8,-5)),
  所以**两层的格坐标不能直接运算** —— 它们差半格。要比就先换算成世界坐标。
  `FarmProps` 在 (0,0),与 grass 层也差半格:拿 grass 的格号去查 `FarmProps` 的
  格子集合会选到**差 8px 的另一格**(踩过:自检跑到树里,玩家一步都动不了)。
  统一入口:`FarmProps.to_local_cell(global_point)` / `cell_center(cell)`。
- **动作图集一行 = 一个朝向的 2 帧**,不要把相邻两行当成「一个动作的 4 帧」:
  `Basic Charakter Actions.png` 是 2 列 x 12 行 = 3 个动作 x 4 个朝向(前/后/左/右),
  弄错会让左右两套动画变成同一个、顺便「朝两边挥」(踩过两次,见 DECISIONS#action-blocks)。
  版式对照图:`python tools/annotate_actions.py` → `docs/art/actions_groups.png`。
- **自检里不要依赖合成按键**(`Input.action_press` 会时灵时不灵:状态机还在 idle,
  玩家一步不动 —— 那才是「偶发失败」的真正来源)。验碰撞就自己给 `velocity` +
  `move_and_slide()`;验输入就等条件(等到真的动了)并设上限,别写死等 N 帧。
  见 DECISIONS#synthetic-input。
- **目标格只准用 `Player.target_cell()` 算**,它 = 「脚下碰撞圆那格 + 朝向一格」。
  别写 `world_to_cell(global_position + facing * 16)`:玩家的 `global_position` 是
  **身体中心**,比脚高 6px,拿它当锤点上下朝向会差**一整格**(用户报的「锄地有点歪」
  就是这个)。地上那个指示框和工具走的是同一个 `target_cell()`,别另开一套。
  见 DECISIONS#targeting / #target-indicator。
- **要验证画面里某个东西画在哪,别猜相机位置** —— 相机节点自己在 `(0,-6)`,
  而且会被地图边界夹。用 `get_viewport().get_canvas_transform()`(渲染用的同一套
  变换)把世界坐标换到屏幕坐标。截图工具已经会把 `canvas xform` 和指示框状态打出来,
  见 DECISIONS#canvas-transform。
- **改 `scenes/`/`scripts/` 的排版或字体后,看画面用**
  `run_project {scene: "res://scenes/dev/screenshot.tscn"}`(存到 `res://screenshots/`);
  看整张地形对不对用 `python tools/render_map.py docs/art/map.png`;
  看地图布局用 `res://scenes/dev/map_dump.tscn`(打 ASCII 地图)。
- GDScript 缩进必须用 Tab。
- `GameState`/`TimeManager` 的函数**不要写成 `static`**:它们是 autoload 实例,
  从实例调用 static 函数引擎会报错(踩过,见 DECISIONS)。
- 收工前更新 `docs/PROGRESS.md` 并 commit(可用 `/handoff`)。
