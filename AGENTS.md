# croptail

> 项目级稳定事实。**每轮都会注入上下文,保持精简。**
> 进度 / 待办 / 卡点 → `docs/PROGRESS.md`;方案取舍 → `docs/DECISIONS.md`。

创建于 2026-10-03

## 项目定位

- 一句话:像素风小农场 —— 锄地、播种、浇水、收获、卖钱。
- 类型:2D top-down 农场模拟(单机,非商业)
- 仓库:https://github.com/MonkeyL2000/croptail
- 素材:**只能用工程 `game_source/` 里的**。不许去工程外面找 / 拷素材 ——
  除非用户明确说「就用外面那份」(比如用户自己给的宠物狗)。工程外的付费包就算有
  也不能用,要拷得先得到用户明确同意(只拷用到的那几个文件 + 写上出处)。
  现有素材是 Sprout Lands Basic Pack(Cup Nooble)—— 只许非商业使用、必须署名、禁止 AI 训练,
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
| `scripts/world/` | 地图与地面物件:`farm_map.gd`(水墙)、`farm_props.gd`(撒道具/地标/斧镐规则)、`farm_path.gd`(**小路 = `TileMapLayer` + TileSet 里那套 `dirt` 地形**)、`prop_db.gd`(道具表,45 条 rect:树 3 / 石 6 / 木 5 / 荷叶 4 / 花草灌木 16 / **停用 6** / 围栏 4 / 鸡舍 1)、`chicken.gd`、`cow.gd`、`dog.gd`(宠物狗,重走玩家的脚印跟随) |
| `scripts/ui/` | HUD(`hud.gd`)、图标表(`tool_icons.gd` / `item_icon.gd`) |
| `main.tscn` 的节点顺序 | `FarmMap` → `Player` → `Dog` → `TargetIndicator`(指示框必须在最后 = 画在最上面),HUD 是 `CanvasLayer` 永远在最上 |
| `scenes/dev/` | 开发工具场景:`selftest`(自检)、`screenshot`(出图)、`map_dump`(ASCII 地图)、`retile`(重算地形图块)、`grass_terrain_ref`(旧地图快照,当 peering 的标准答案) |
| `scripts/dev/` | 上面那些工具的实现。都是 dev-only,不影响主场景 |
| `game_source/` | 原版素材,勿改名(名字里有空格,勿动);`game_source/font/` 是生成的 HUD 点阵字体;`game_source/Pets/` 是**用户另外给的外部素材**(白底原图 + `tools/pack_dog.py` 处理出的图集),授权待确认 |
| `tools/` | 生成器(Python)。**生成物已入库,不跑也能开发**;要改字体/玩家场景/对照图才跑 |
| `docs/art/` | 给图集加的坐标网格图 / peering 对照图 / 整张地图渲染(`tools/annotate_*.py`、`tools/render_map.py` 生成),用来人工确认「哪格是什么」 |
| `tilesets/test_tilemap.tres` | TileSet(仍沿用旧文件名) |
| `docs/` | 长期记忆:进度、决策 |

### `tools/` 里的生成器

| 脚本 | 作用 |
|---|---|
| `gen_pixel_font.py` | 生成 `game_source/font/sprout_ui.{png,fnt}` + `docs/art/font_preview.png` |
| `gen_player_scene.py` | 重新生成 `scenes/characters/player.tscn`(32 个动画 = idle/walk x 4 朝向 + 6 把工具 x 4 朝向 + Camera2D) |
| `annotate_sheet.py` | 给图集画格线存到 `docs/art/`,方便人工核对格子含义 |
| `annotate_actions.py` | 把 `Basic Charakter Actions.png` 的版式(3 个动作组 x 4 个朝向)框出来标好,存 `docs/art/actions_groups.png` |
| `annotate_terrain.py` | 把 TileSet 的 peering 信息画到图集上(`docs/art/terrain_*.png`):每格右上角一个九宫格,填色 = 那个方向也是同种地面 |
| `annotate_objects.py` | 把**代码认定的名字**写在斧/镐/围栏/鸡舍的放大图上(`docs/art/tools_objects.png`),核对「哪格是什么」用 |
| `check_props.py` | **道具表体检**:每条 rect 是不是只围了**一个连通域**(按像素归属数,不是比包围盒;+1px 容差)、kind 和调色板对不对、有没有两条共用/重叠、图集里的精灵有没有漏登记。退出码 0 = 全过。改 `prop_db.gd` 后**必跑** |
| `sprite_inventory.py` | 任意一张图集的**连通域清单**(包围盒 / 像素数 / 颜色家族 / ASCII 缩略图),可交叉对照 `prop_db.gd` 的 rect(`--rects` 会标出 `covered_by=NOTHING`)。「这一格到底画的什么」先问它 |
| `ascii_sheet.py` | 把图集/单条 rect 打成**字符画**(一个像素一个字母、按颜色家族上色)—— 助手看不到图,只能靠这个分 «树 / 倒木»「荷叶 / 灌木」这种靠形状的差别 |
| `annotate_props.py` | 把 `prop_db.gd` 里每条 rect 描边 + 编号画到两个道具图集上(`docs/art/props_sheet.png`) —— 「素材放错了」的对照图,人工核对用 |
| `zoom_props.py` | 把指定的几条(或 `--all` 全部 45 条)道具 8 倍放大拼成一张图,左上角印**全局大编号**(`python tools/zoom_props.py --all --out docs/art/props_numbered.png`)—— 拿去问用户「你说的是哪一号」时用;编号在任何一张放大图上都一致。`--list` 列全部名字 |
| `check_leaf_shots.py` | 拿截图数像素,验证**荷叶真画在水面上**(`python tools/check_leaf_shots.py <leaf.log>`,`[leaf]` 行由 `scenes/dev/screenshot.tscn` 打印)。荷叶有 4 种尺寸,调色板和 rect 都**按名字从 `prop_db.gd` 现查**;它会把 HUD 面板减掉(见下面那条) |
| `carve_ponds.py` | 按椭圆删草地格、挖出池塘(`--dry-run` 可看效果)。改完**必须**跑 `retile.tscn` + `retile_grass.py` |
| `render_map.py` | 离线把 `farm_map.tscn` 的地形层合成成一张整图(`docs/art/map.png`)。**看草坪对不对看这张**,不要在游戏里对着一小块猜 |
| `extract_props.py` | 连通域分析道具图集(只是**建议**,权威表在 `prop_db.gd`)。⚠️ 它的 rect 会把**挨着摆的两块精灵粘成一块**,只能当参考 —— 见 DECISIONS#prop-art-rects |
| `pack_dog.py` | 把宠物狗原图(`game_source/Pets/lilpuddinpuggums.png`,白底 96x192、3x4 格 32x48)处理成游戏图集 `game_source/Pets/pug_walk.png`(48x96 = 3x4 格 16x24):抠白底、按行居中、2:1 取样缩小,左右两行取样相位对齐。跑完要 `launch_editor` 一次;`--preview` 只打 ASCII 不写文件 |

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
  **池塘也是这么挖的**:`carve_ponds.py` 只是**删草地格**(水层本来就铺满整张图,在草下面),
  所以啃了地图形状就一定要重跑 retile + retile_grass(见 DECISIONS#ponds)。
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
- **`Sprite2D.new()` 之后必须自己设 `position`**:把精灵摆到父节点的**中心**。
  格子的原点在左上角,而 `Sprite2D` 默认 `centered = true` —— 不设位置的话贴图会以
  左上角为圆心画、整块偏左上半格。它**不报错**、逻辑测试也全绿,只有看画面才发现
  (用户报的「指示器的格子和实际作用的格子不是一格」就是这个,见 DECISIONS#cell-sprites)。
- **改完贴图/精灵的落点,要拿画面量一次**:`scripts/dev/screenshot.gd` 会把农田锄满,
  于是整块农田是个纯色 192x112 方块 —— 它的包围盒必须正好等于 `FarmPlot` 的外框。
- **道具 rect 必须「一条 = 一个连通域」**:图集里有些精灵是紧挨着的(灌木 + 树桩),
  连通域(flood fill)会把它们糊成一块;**反过来把矩形切开也是错**(切掉的灌木缺一条边,
  剩下的一半又会被当成单独道具撒一地 —— 用户报的「树还是倒下的」就是这个,踩了两轮)。
  判据(离线 / 引擎内各一份,逻辑一致):**rect 里的像素只能属于一个连通域**,
  而且那个连通域的包围盒**不许超出 rect 超 1px**。拼图块(`fence`/`house`)不适用。
  改 `prop_db.gd` 后**必跑** `python tools/check_props.py`,要看图用
  `python tools/annotate_props.py`(`docs/art/props_sheet.png`)。
  **kind 由颜色家族决定,不由形状**:粉 ⇒ 花 ⇒ `deco`(永远不许 solid)、灰 ⇒ 石、
  木色 ⇒ `wood`、绿 ⇒ 草/灌木。引擎侧也有回归断言(`selftest.gd::_test_prop_art()`),
  见 DECISIONS#prop-art-rects。
- **小路是「地形」,不是贴花**:`GameTilemap/Path` 是一个 `TileMapLayer`,铺的是
  TileSet 里一直没人用的 **`dirt` 地形**(`terrain_set 0 / terrain 1`,图集
  `Tilled_Dirt_Wide.png`)—— 用 `set_cells_terrain_connect()`,**绝不手填图块坐标**。
  边缘的草边由 peering bit 自动接(所以路看起来是「中间一条土、上下各 3px 草」)。
  `Paths.png` 那套 3px 条子贴花已**废弃不用**。
  这一层**没有 position 偏移**(和 `FarmProps` 同一套格坐标);路占的格子由
  `FarmProps._path_cells()` 预留,不然树会长在路中间。改路线只改 `RUNS`,
  自检 `_test_path()` 会验「每格都是草 / 连通成一条 / 路在出生点上 /
  **每块图都来自 dirt 图集** / 涂的格子 == 折线算出的格子」。见 DECISIONS#farm-path。
- **`kind "parked"` = 「登记在表里,但永远不摆」**:平躺的树(`#19 bush_low` /
  `#21 bush_wide_alt`,要 90° 转像素才像样,用户说「不行就先不用它」)和
  4 个「看着像果实」的圆球花都挂在这个 kind 上。它不在 `SCATTER_KINDS`、
  不是 `pond`、也不是地标 → 三条摆放路径全绕开它,但仍在 `KINDS` 里,
  所以运行日志会打 `0 parked`(变多就是有东西漏进了摆放路径)。见 DECISIONS#parked-kind。
- **拿不定「这格素材是什么」时,别接着推**:`tools/annotate_sheet.py` /
  `annotate_objects.py` / `annotate_props.py` / `annotate_terrain.py` 会把格子坐标和
  代码认定的名字画到图上,让用户看一眼就能回答。斧/镐的名字就是这么来的
  (推断值,见 DECISIONS#gather-tools);不报错但画错的 bug 都靠这个抓。
- **荷叶(kind `pond`)只浮在池塘水面上,不许回到草地撒点里**:`prop_db.gd` 里它
  不在 `SCATTER_KINDS`,只由 `farm_props.gd::_place_pond_decor()` 摆
  (离岸 ≥1 格、两片不挨着、居中在格心上)。用户认出 `bush_leafy`(白边的圆叶子)
  也是荷叶,但它和三张小叶子尺寸不同,所以用 `POND_LEAF_MIX` **混着放**、
  `bush_leafy` 占多数(不然「荷叶又跑回草地」的 bug 会复活)。
  要验它:引擎内 13 条 + 截图数像素(`tools/check_leaf_shots.py`)。
  见 DECISIONS#pond-lily-pads。
- **截图查像素时先把 HUD 减掉**:HUD 是 `CanvasLayer`,永远画在世界之上。
  同一个屏幕矩形,一片荷叶在 shot_1 里数出 30 个叶子像素、在 shot_3 里数出 0 ——
  因为它正好压在底部消息栏 `(112,310,416,20)` 底下。**看不见不等于没画**。
  五块面板:`(0,0,640,22)` / `(112,310,416,20)` / `(0,330,166,30)` /
  `(524,330,54,30)` / `(582,330,54,30)`。见 DECISIONS#hud-hides-world。
- **测试不许断言「随机的初始状态」**:牛的朝向原来断言「进场时 `flip_h` 是 false」,
  实际是在赌「随机挑的第一个目标在它右边」—— 荷叶换 kind 之后 `_rng` 消耗次数变了,
  这条就无端变红。要把状态**驱动**到想验的样子(换活动范围 / 直接设状态 / 注入种子),
  再看结果。见 DECISIONS#tests-must-not-depend-on-rng。
- **自检里带 `await` 的测试函数必须 `await` 调用**:`_test_ponds()` 内部有 60 个物理帧的
  推墙循环,一开始是「不 await 直接调」—— 它就成了发射后不管的协程,和后面的测试
  **抢玩家位置**,报出一个假失败(算出的落点停在 416.8,期望 -221)。任何 `await` 过的
  测试都是在和其他 `await` 过的代码交替执行,顺序必须自己握牢(见 DECISIONS#selftest-await)。
- **外部素材(白底 / 整数倍放大的图)不许直接怼进游戏**:先写个 `tools/pack_*.py`
  把它处理成**规则图集**(抠底、按行居中、整数倍取样缩小),再在代码里按格坐标引用。
  白底直接引会在游戏里变成一块白方块,而且**不报错**、逻辑测试全绿 ——
  只有看画面才发现。处理完记得 `launch_editor` 一次再跑。参考 `tools/pack_dog.py`
  (宠物狗就是这么进来的,见 DECISIONS#dog-pet)。
- **动物图集的行帧数可以不一样,别按规则网格切**:`Free Cow Sprites.png` 是
  3 列 x 2 行、每格 32x32,但**第 2 行只有 2 帧**(第 3 格全透明)—— 按 3 帧播
  走路会隔一会儿闪一下空白,而且**不报错**。切之前先逐格数 alpha,并且
  自检里钉一条「每一帧都不空」(见 DECISIONS#cow-art)。
- GDScript 缩进必须用 Tab。
- `GameState`/`TimeManager` 的函数**不要写成 `static`**:它们是 autoload 实例,
  从实例调用 static 函数引擎会报错(踩过,见 DECISIONS)。
- 收工前更新 `docs/PROGRESS.md` 并 commit(可用 `/handoff`)。
