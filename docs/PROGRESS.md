# croptail — 进度

> **只有 `run_project` 跑过且 `get_debug_output` 无 ERROR 的东西,才准写进 Done。**
> Next 必须可执行(给路径 / 函数名),不要写「继续做农场系统」。

## 目标

一个能玩的像素小农场:锄地 → 播种 → 浇水 → 过天生长 → 收获卖钱。
非商业个人项目,素材用 Sprout Lands Basic(Cup Nooble)。

## 固定信息

| 项 | 值 |
|---|---|
| 主场景 | `res://scenes/main.tscn` |
| 自检场景 | `res://scenes/dev/selftest.tscn`(**逻辑改动的验收口**) |
| 截图工具 | `res://scenes/dev/screenshot.tscn` → `res://screenshots/shot_*.png` |
| 地形整图 | `python tools/render_map.py docs/art/map.png`(离线合成,看草坪对不对看这张) |
| 动作版式图 | `python tools/annotate_actions.py` → `docs/art/actions_groups.png`(3 个动作组 x 4 个朝向,人工核对用) |
| 地形图块重算 | `res://scenes/dev/retile.tscn`(改了地图形状后要跑;先自校验参考图) |
| 地图速览 | `res://scenes/dev/map_dump.tscn`(打 ASCII 地图) |
| autoload | `GameState`=`res://scripts/core/game_state.gd`,`TimeManager`=`res://scripts/core/time_manager.gd` |
| 地图 | `res://scenes/world/farm_map.tscn`(1938 格草 + 3312 格水,72x46 格)。改完形状要重跑 `res://scenes/dev/retile.tscn`,否则新格子的图块是错的 |
| 道具 | `FarmMap/Props`(`scripts/world/farm_props.gd` + 表 `prop_db.gd`),~390 个,碰撞从贴图 alpha 现算 |
| TileSet | `res://tilesets/test_tilemap.tres`(旧名沿用;水墙碰撞由 `farm_map.gd` 运行时生成) |
| 玩家 | `res://scenes/characters/player.tscn`(24 个动画 + Camera2D;由 `tools/gen_player_scene.py` 生成) |
| HUD | `res://scenes/ui/hud.tscn` + `scripts/ui/hud.gd`(字体由 `tools/gen_pixel_font.py` 生成) |
| 目标格指示框 | `scripts/farm/target_indicator.gd`(挂在 `main.tscn` 的 `TargetIndicator`,画在**所有东西之上**) |
| 导出 preset | **无**(还没建) |

## 操作

| 键 | 作用 |
|---|---|
| WASD / 方向键 | 四方向移动(相机跟随) |
| Space | 用当前工具作用在**面前那一格** —— 那一格地上有指示框(先按方向键定朝向) |
| 1 / 2 / 3 / 4 | 锄头 / 水壶 / 种子 / 收获 |
| Q / E | 上/下一个工具 |
| R | 换作物(小麦 ⇄ 叶菜) |
| B | 买 1 颗当前作物的种子(扣金币) |
| T | 立刻过一天(测试用;平时 45 秒自动过一天) |

## Done

- [x] **2026-10-03 接手并重做玩法**:项目从 `D:\GODOT_PROJ\croptail` 搬来(逐文件 md5 校验),
      原样导入前的问题清单见提交 `a627f7f` 的说明。
- [x] **2026-10-03 修复原项目的致命问题**
  - 设主场景 `res://scenes/main.tscn`(原来没有 `run/main_scene`,F5 会弹窗)
  - `Player.player_direction` 从 `static var` 改成实例变量 `facing`
  - `NodeState.transition` 信号补上参数(原来 `emit("walk")` 会 "too many arguments" 崩掉)
  - 去掉状态机每物理帧的 `print`(原项目控制台被刷爆)
  - **目录规范化**:`sence/`→`scenes/`、`script/`→`scripts/`、`state_machiine/`→`state_machine/`
- [x] **2026-10-03 玩法骨架**:`FarmPlot`(12x7)+ `FarmCell`、`CropDB`(小麦/叶菜,各 4 阶段)、
      `TimeManager`(45 秒一天,浇水才长、水会干)、`GameState`(工具/金币/种子)
- [x] **2026-10-03 玩家**:3 状态机(idle/walk/use)、脚下 r=5 小碰撞圆、Camera2D 跟随
- [x] **2026-10-03 自动水墙**:`farm_map.gd` 按「水格减草格」生成 80 个碰撞形状,玩家走不出岛
- [x] **2026-10-03 地图放大 + 随机撒道具**:草地 263→1938 格、水 960→3312 格;
      `FarmProps` 按格子撒 ~390 个树/石/木/装饰(固定 RNG 种子,可复现),
      碰撞**从贴图 alpha 逐行算**(不手写表),撒点后跑 BFS 保证农田可达
- [x] **2026-10-03 HUD**:顶栏(天数+进度 / 金币 / 当前工具 / 当前作物)、
      左下工具条(4 个格 + 选中高亮)、右下背包(2 种作物 + 种子数)、底部 3 秒提示,
      全部 ASCII + 自生成点阵字体(见 `docs/DECISIONS.md#bitmap-font-yoffset`)
- [x] **2026-10-03 工具各自有各自的素材和动画**(这一轮的主任务)
  - **图标**:`scripts/ui/tool_icons.gd` 重写。根因是 `Tools.png` 并非「6 种工具」,
    而是「3 种工具 x 6 个朝向」—— 旧表从一个工具组里挑了 3 格,所以 4 个图标里
    3 个长得一样。现在一个工具取一整组,第 4 个(收获)取**成熟作物**的贴图。
  - **动画**:`Basic Charakter Actions.png` 是 **2 列 x 12 行** = 3 个动作 x 4 个朝向,
    **一行(2 帧)= 一个动作的一个朝向**。`tools/gen_player_scene.py` 重生成
    `player.tscn`,24 个动画 / 48 张 AtlasTexture。锄头/水壶/种子/收获各一套动作,和朝向正交。
  - 工具条图标跟随当前工具高亮;收获图标跟随当前作物变(`GameState.crop_changed`)
- [x] **2026-10-03 修复「锄地/收割/浇水的动作会朝两边施放」** —— 用户指出后查出来的
  - **根因**:上一轮把 `行 2b, 2b+1` 两行当成「一个动作的 4 帧」,于是
    ① `use_*_left` 和 `use_*_right` 拿到**同一对行 = 同一个动画**(左右一样),
    ② 一个动画里左一帧、右一帧交替 —— 就是「朝两边施放」。
  - **真版式**:2 列 = 两帧,12 行 = 3 个动作 x 4 个朝向(组内顺序同立绘表:前/后/左/右)。
    证据链写在 `docs/DECISIONS.md#action-blocks`(镜像对、头部轮廓、脸上的肤色像素);
    对照图 `docs/art/actions_groups.png`(`python tools/annotate_actions.py`)。
  - 现在 `use_N_*` 每个动画只取自**一行**,2 帧;`TOOL_ACTION` 改成给组起始行。
    动作分配:锄头 A(头顶抡下)/ 收割 B(体侧扫下)/ 洒水壶 C(纯金属、身前低位)/ 种子借 B。
  - **新增 4 条回归**:动画不跨行、同一工具四个朝向占四行不同行、
    左帧是右帧的逐像素镜像、前视图有脸/后视图没有。
- [x] **2026-10-03 自检场景扩到 137 项断言**,新增覆盖:道具撒点/可达性、树真的挡住人、
      每个 `use_*` 帧矩形在贴图内、动画不跨行且四个朝向占四行、左/右帧逐像素镜像、
      四个工具图标逐像素不同、HUD 字体/字号/行高、以及**读一帧真实画面**量 DayLabel 墨迹有没有被裁
- [x] **2026-10-03 修复「草坪全是错的」** —— 用户指出后查出来的
  - **根因**:地图形状是脚本刷的,刷的时候**每一格都写了同一个 atlas 坐标**(左上角块)。
    而「该画哪一块」由 TileSet 的 terrain(peering)决定:内部用 `(1,1)`,四条边各一块,
    四个角各一块,还有四种内凹块 —— 一共 32 块。刷错的那一下不报错,只是画面不对。
  - **修法**:`scripts/dev/retile.gd` 调引擎自己的 `set_cells_terrain_connect()` 重算,
    把 `tile_map_data` 写出来,再用 `tools/retile_grass.py` 贴回 .tscn。
    新表 = 1760 内部块 + 边 +**正好 4 个角块**(矩形岛就该是这样)。
  - **方法怎么验证的**:拿旧地图(263 格)当标准答案 —— 那是原作者用地形笔刷点的,
    重算结果和存着的**逐格一致(0 处不同)**。快照留在 `scenes/dev/grass_terrain_ref.tscn`,
    工具每次跑都先校验它。
  - **顺带修了一个水墙的坐标系 bug**:`water` 层在 (0,0)、`grass` 层在 (-8,-5),
    两层格坐标差半格,「水格减草格」算出来的墙整体横移一格 —— 左边一堵隐形墙
    (走不到岸边),右边一条能走到水上的缝。现在改成按**草地层的岛轮廓**生成,
    玩家停在「草沿 + 半径」± 1px 内(实测 草左沿 -264 / 玩家 -259,半径 5)。
  - **新增回归断言**:拿同一个 TileSet 开临时层跑一遍引擎的 peering 再逐格对比;
    内部格必须是 `(1,1)`;岸边真走一遍并量停下的坐标
    (旧的松断言**恰好能让隐形墙通过**,这就是它当初漏掉的原因)。
- [x] **2026-10-03 项目记忆 + 仓库**:`AGENTS.md` / `docs/` / `ASSET_CREDITS.md` / `README.md`;
      推到 GitHub:**https://github.com/MonkeyL2000/croptail**(public)
- [x] **2026-10-03 目标格指示框 + 修「锄地有点歪,不是正前方那块」** —— 用户指出后做的
  - **「歪」的根因**:`global_position` 是**身体中心**,脚下碰撞圆却在 `(0,6)`,差 6px。
    老写法 `world_to_cell(global_position + facing * 16)` 拿身体中心当锚点 →
    上下朝向差**一整格**,而且在格子里挪几像素目标格就跳。
    现在 `target_cell() = standing_cell() + facing_cell_offset()`,锚点是脚下那个圆
    (偏移从 `CollisionShape2D.position` 读,不写死)。见 `DECISIONS.md#targeting`。
  - **指示框**:`scripts/farm/target_indicator.gd`,把「工具会作用到哪一格」画在地上。
    农田内 = 奶油色框线 + 16% 白填充;农田外 = 暗灰框线、不填充(提示按了没用)。
  - **它和工具是同一个坐标来源**:都调 `Player.target_cell()`。自检先读框的格子、
    再真锄一次,比对锄过的是不是同一格。
  - **画在最上层(含角色之上)**:一开始画在地面层,从**真实截图的像素**量出来不行 ——
    角色精灵 48x48 比一格(16px)大得多,面朝上时面前整格都被角色盖住,框线一条看不见。
    (也没用 `z_index = -1`:负 z 会被父节点的 z 抵消下场,连底板都盖不住。)
  - **自检 137 → 154 项**:新增 `-- tool targeting`(9 条,含「身体中心压在格子边界上、
    面朝下必须锄脚下那格的下方」这条回归)和指示框 6 条(含真读一帧画面量墨迹:
    框开着 luma 0.821 / 藏起来 0.786,证明真的产生了像素)。
  - **截图逐像素复核**:农田内 `(0,1)`/`(4,6)` 都是完整 16x16 方框(奶油线+白填充),
    农田外 `(15,15)` 只有暗灰框线、无填充。截图工具现在会打印 `canvas xform` 和
    指示框状态,见 `DECISIONS.md#canvas-transform`。

## Next(按顺序做)

1. **把 HUD 的「提示」用起来**:现在只有 `main.gd` 开机时那一条。
   在 `farm_cell.gd` / `player.gd` 的失败分支上 `GameState` 发消息
   (比如「要用锄头」「这里已经种了」「水够多了」),让玩家知道为什么按了没反应。
2. **卖东西的经济闭环**:现在收获即加钱。改成把作物拿到 `Chest`/摊位卖,
   让 `GameState.add_coins` 只在一个地方被调用,方便以后加价格波动。
   素材:`game_source/Objects/Chest.png`(240x96,检视里切区域)。
3. **鸡舍产蛋**:新建 `scripts/farm/animal_pen.gd`,每天产 1 个蛋,
   玩家用收获工具走到旁边捡起。素材:`Characters/Egg_And_Nest.png`、
   `Objects/Egg_item.png`(16x16)、`Characters/Free Chicken Sprites.png`。
4. **存档**:`user://save.json`,序列化 `GameState.inventory/coins/selected_crop`
   + `TimeManager.day` + 每个 `FarmCell` 的 (soil, watered, crop id, growth)。
   `FarmPlot` 已经有稳定的 `grid_pos` 键;`TimeManager.day_fraction()` 是派生值不用存。
5. **背包格显示收获物数量**:`hud.gd::_build_backpack()` 里已经有 `harvested` 的数值,
   现在只画了种子数(右下角)。要同时显示就再加一个左下角的 Label。

## 卡点 / 风险

- **素材许可是非商业 + 禁止 AI 训练**,仓库是公开的 —— 改素材或加新素材前先读 `ASSET_CREDITS.md`。
  HUD 点阵字体来自 Noto Sans SC(SIL OFL 1.1,可再分发),**不要**换回 Consolas 之类的商用字体。
- `Basic_Plants.png` 的格子含义是像素级推断(见 `DECISIONS.md#plant-cells`),
  `Tools.png` 里「哪组是锄头」也是推断 —— 两处都有对照图可人工核对:
  `docs/art/plants_sheet.png`、`docs/art/tools_sheet.png`(`tools/annotate_sheet.py` 生成)。
- 杂草 / 石头会挡农田的格子 —— 现在 `FarmCell` 没有「障碍物」概念,以后加野草要顺手加这一位。
- ⚠️ **待确认**:种子图标取的是 `Tools.png` 行 4,但那一行的像素是「木件 + 金属箍」,
  不像种子袋(见 `DECISIONS.md#tools-sheet` 的表)。四个图标确实互不相同,需求已满足;
  但若找到真正的种子袋素材(也许在 `Objects/Basic_tools_and_meterials.png` 里),应该换过去。
- 角色动画是一整块图集切出来的,没有图例。改 `tools/gen_player_scene.py` 之后
  **必须**跑一次 `launch_editor` 重新导入,否则看的是旧缓存(见 `DECISIONS.md#reimport`)。
- 自检里**合成按键不可靠**(会时灵时不灵),验物理的用例不要依赖它;
  另有「格坐标跨节点混用」的坑 —— 见 `DECISIONS.md#synthetic-input`、`#frame-mixing`。
- 没有音频素材(原包里就没有)。

## 最近一次验证

- `run_project {scene: "res://scenes/dev/selftest.tscn"}` + `get_debug_output`
  → **`=== SELFTEST END: 154 checks, 0 failed ===`**,连跑 3 次都 0 failed,ERROR 区为空。关键几条:
  - `facing down from there targets the next row, not your own` —— 「锄地有点歪」的回归
  - `the indicator pointed at the cell that got tilled` —— 框 == 工具作用的那格
  - `the indicator really draws pixels`(luma 0.821 有框 / 0.786 无框)
  - `each direction of a tool uses its own atlas row` —— 「朝两边挥」那个 bug 的回归
  - `left frames are the exact mirror of the right frames (8 frames)`
  - `front action frames show the face, back frames do not`
  - `grass tiles match the TileSet's own terrain peering`(拿引擎当标准答案逐格比)
  - `a fully surrounded cell uses the interior tile`(`(1,1)`)
  - `water wall is flush with the shore (within 1px)`(岸边实测 草沿 -264,玩家 -259,**零抖动**)
  - 字体探针 `'D' 墨迹在 Label 内的行 3..11`、`DayLabel rect y 4..19, ink rows 7..18`
- `scripts/dev/retile.gd` → **`REFERENCE CHECK: PASS`**(263 格标准答案 0 差异)
- `python tools/render_map.py docs/art/map.png` → 1152x736 整张地形图;
  `python tools/annotate_terrain.py` → `docs/art/terrain_grass.png`(peering 九宫格对照)
- `run_project {scene: "res://scenes/dev/screenshot.tscn"}` → `screenshots/shot_1..3.png`,
  逐像素复核:四个工具图标精确(0 误差)命中各自的素材格
  `Tools(0,2) / Tools(0,0) / Tools(0,4) / Plants(4,0)`;
  指示框 = 16x16 方框套住目标格(农田内亮框+填充 / 农田外暗框,见上)
- 主场景 `run_project {projectPath: "D:\\godot_projects\\croptail"}`:仅
  `[farm_props] ~390 props ... 19xx collision boxes` + `[farm_map] water walls: 76 collision shapes`,无 ERROR
- 日期:2026-10-03

## 待补的记录

- 导出 preset 还没建(要发 itch.io 时再建 Windows/Linux 两个)
