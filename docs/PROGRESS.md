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
| 地图速览 | `res://scenes/dev/map_dump.tscn`(打 ASCII 地图) |
| autoload | `GameState`=`res://scripts/core/game_state.gd`,`TimeManager`=`res://scripts/core/time_manager.gd` |
| 地图 | `res://scenes/world/farm_map.tscn`(1938 格草 + 3312 格水,72x46 格) |
| 道具 | `FarmMap/Props`(`scripts/world/farm_props.gd` + 表 `prop_db.gd`),~390 个,碰撞从贴图 alpha 现算 |
| TileSet | `res://tilesets/test_tilemap.tres`(旧名沿用;水墙碰撞由 `farm_map.gd` 运行时生成) |
| 玩家 | `res://scenes/characters/player.tscn`(24 个动画 + Camera2D;由 `tools/gen_player_scene.py` 生成) |
| HUD | `res://scenes/ui/hud.tscn` + `scripts/ui/hud.gd`(字体由 `tools/gen_pixel_font.py` 生成) |
| 导出 preset | **无**(还没建) |

## 操作

| 键 | 作用 |
|---|---|
| WASD / 方向键 | 四方向移动(相机跟随) |
| Space | 用当前工具作用在**面前那一格**(先按方向键定朝向) |
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
  - **动画**:`Basic Charakter Actions.png` 的一帧不是「一列」而是 **2x2 块**
    (图只有 96 宽),旧生成器去取 x=96/144 已经**出了图界**,每个 `use_*` 的第 3、4 帧是空的。
    `tools/gen_player_scene.py` 重生成 `player.tscn`,24 个动画 / 80 张 AtlasTexture。
    锄头/水壶/种子/收获各一套动作,和朝向正交。
  - 工具条图标跟随当前工具高亮;收获图标跟随当前作物变(`GameState.crop_changed`)
- [x] **2026-10-03 自检场景扩到 128 项断言**,新增覆盖:道具撒点/可达性、树真的挡住人、
      每个 `use_*` 帧矩形在贴图内、四个工具图标逐像素不同、
      HUD 字体/字号/行高、以及**读一帧真实画面**量 DayLabel 墨迹有没有被裁
- [x] **2026-10-03 项目记忆 + 仓库**:`AGENTS.md` / `docs/` / `ASSET_CREDITS.md` / `README.md`;
      推到 GitHub:**https://github.com/MonkeyL2000/croptail**(public)

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
- 角色动画是一整块图集切出来的,没有图例。改 `tools/gen_player_scene.py` 之后
  **必须**跑一次 `launch_editor` 重新导入,否则看的是旧缓存(见 `DECISIONS.md#reimport`)。
- 没有音频素材(原包里就没有)。

## 最近一次验证

- `run_project {scene: "res://scenes/dev/selftest.tscn"}` + `get_debug_output`
  → **`=== SELFTEST END: 128 checks, 0 failed ===`**,ERROR 区为空
  (`docs/DECISIONS.md#bitmap-font-yoffset` 的探针会打印
  `'D' 墨迹在 Label 内的行 3..11`,以及 `DayLabel rect y 4..19, ink rows 7..18`)
- `run_project {scene: "res://scenes/dev/screenshot.tscn"}` → `screenshots/shot_1..3.png`,
  逐像素复核:四个工具图标精确(0 误差)命中各自的素材格
  `Tools(0,2) / Tools(0,0) / Tools(0,4) / Plants(4,0)`
- 主场景 `run_project {projectPath: "D:\\godot_projects\\croptail"}`:仅
  `[farm_props] ~390 props ... 19xx collision boxes` + `[farm_map] water walls: 80 collision shapes`,无 ERROR
- 日期:2026-10-03

## 待补的记录

- 导出 preset 还没建(要发 itch.io 时再建 Windows/Linux 两个)
