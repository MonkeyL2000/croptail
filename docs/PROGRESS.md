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
| autoload | `GameState`=`res://scripts/core/game_state.gd`,`TimeManager`=`res://scripts/core/time_manager.gd` |
| 地图 | `res://scenes/world/farm_map.tscn`(960 格水 + 263 格草 + 10 格装饰) |
| TileSet | `res://tilesets/test_tilemap.tres`(旧名沿用;碰撞由 `farm_map.gd` 运行时生成) |
| 玩家 | `res://scenes/characters/player.tscn`(12 个动画 + 3 状态) |
| 导出 preset | **无**(还没建) |

## 操作

| 键 | 作用 |
|---|---|
| WASD / 方向键 | 四方向移动 |
| Space | 用当前工具作用在**面前那一格**(先按方向键定朝向) |
| 1 / 2 / 3 / 4 | 锄头 / 水壶 / 种子 / 收获 |
| Q / E | 上/下一个工具 |
| R | 换作物(小麦 ⇄ 叶菜) |
| B | 买 1 颗当前作物的种子(扣金币) |
| T | 立刻过一天(测试用;平时 45 秒自动过一天) |

## Done

- [x] **2026-10-03 接手并重做玩法**:项目从 `D:\GODOT_PROJ\croptail` 搬来(逐文件 md5 校验),
      原样导入前的问题清单见提交 `a627f7f` 的说明;搬迁时的完整分析也在那。
- [x] **2026-10-03 修复原项目的致命问题**
  - 设主场景 `res://scenes/main.tscn`(原来没有 `run/main_scene`,F5 会弹窗)
  - `Player.player_direction` 从 `static var` 改成实例变量 `facing`(Godot 4.4 起会直接报错)
  - `NodeState.transition` 信号补上参数(原来 `emit("walk")` 会 "too many arguments" 崩掉)
  - 去掉了状态机每物理帧的 `print`(原项目控制台被刷爆)
  - **目录规范化**:`sence/`→`scenes/`、`script/`→`scripts/`、
    `state_machiine/`→`state_machine/`,脚本按 core/farm/player/ui/world/dev 分层
- [x] **2026-10-03 玩法骨架**:`FarmPlot`(12x7)+ `FarmCell`(土壤/湿土/作物/成熟)、
      `CropDB`(小麦、叶菜,各 4 个生长阶段)、`TimeManager`(45 秒一天,浇水才长、水会干)、
      `GameState`(工具条 / 金币 / 种子库存)
- [x] **2026-10-03 玩家**:3 状态机(idle / walk / use),12 个动画(原来 4 个动画名错成 `tiling_*`)、
      脚下 r=5 小碰撞圆(原来 r=9 的车轮子)、Camera2D 跟随
- [x] **2026-10-03 自动水墙**:`farm_map.gd` 按水格生成 41 个碰撞形状,玩家走不出岛
- [x] **2026-10-03 HUD**:天数+进度 / 金币 / 工具 / 各种子数量 / 3 秒提示(全 ASCII)
- [x] **2026-10-03 自检场景**:`scenes/dev/selftest.tscn`,62 项断言(规则 / 生长 / 图集坐标 /
      状态机 / 移动 / 主场景集成 / 水墙挡人)全绿
- [x] **2026-10-03 项目记忆 + 仓库**:`AGENTS.md` / `docs/` / `ASSET_CREDITS.md` / `README.md`;
      `git init`(分支 main),推到 GitHub:**https://github.com/MonkeyL2000/croptail**(public)
      - `a627f7f` 一次性初始化提交(搬迁后的干净版本就是初始状态,没有造「先坏后好」的假历史)
      - `7b19659` 补 README(操作说明 / 种植循环 / 素材许可)

## Next(按顺序做)

1. **往地图上放静态物件**(纯关卡编辑,不动逻辑):
   在 `scenes/world/farm_map.tscn` 加一个 `Objects` (Node2D) 并实例化 Sprite2D:
   `game_source/Objects/Free_Chicken_House.png`(48x48)放在草地上、
   `Chest.png`(240x96,检视里切区域)、`Wood_Bridge.png`(80x48)跨水、
   `Fences.png`(64x64)围地。记得给会挡路的东西加 `StaticBody2D`
   (参考 `scripts/world/farm_map.gd` 里造墙的写法)。
2. **鸡舍产蛋**:新建 `scripts/farm/animal_pen.gd`,每天产 1 个 `Egg_item.png` 对应的物品,
   玩家用收获工具走到旁边捡起(复用 `field` 的 `use_tool` 思路,但作用在「物件」而不是「格子」)。
   素材:`Characters/Egg_And_Nest.png`(64x16)、`Objects/Egg_item.png`(16x16)、
   `Characters/Free Chicken Sprites.png`。
3. **卖东西的经济闭环**:现在只有「收获即加钱」。改成把作物拿到 `Chest`/摊位卖,
   让 `GameState.add_coins` 只在一个地方被调用,方便以后加价格波动。
4. **存档**:`user://save.json`,序列化 `GameState.inventory/coins` + `TimeManager.day`
   + 每个 `FarmCell` 的 (soil, watered, crop id, growth)。`FarmPlot` 已经有稳定的 `grid_pos` 键。
5. **HUD 右侧画出当前工具/种子图标**(现在只有文字),素材在 `Characters/Tools.png`(96x96)。

## 卡点 / 风险

- **素材许可是非商业 + 禁止 AI 训练**,仓库是公开的 —— 改素材或加新素材前先读 `ASSET_CREDITS.md`。
- `Basic_Plants.png` 的格子含义是像素级推断(见 `DECISIONS.md#plant-cells`),
  如果发现作物长得不对,先怀疑那里。
- 杂草 / 石头会挡农田的格子 —— 现在 `FarmCell` 没有「障碍物」概念,以后加野草要顺手加这一位。
- 没有音频素材(原包里就没有)。

## 最近一次验证

- 命令:`run_project {projectPath: "D:\\godot_projects\\croptail", scene: "res://scenes/dev/selftest.tscn"}`
  + `get_debug_output`
- 结果:**`=== SELFTEST END: 62 checks, 0 failed ===`,ERROR 区为空**
  (只有一条预期内的 `push_warning: 未知状态 'nonexistent'` —— 那是故意测非法状态名的用例)
- 主场景 `run_project {projectPath: "D:\\godot_projects\\croptail"}`:仅
  `[farm_map] water walls: 41 collision shapes`,无 ERROR
- 日期:2026-10-03

## 待补的记录

- 导出 preset 还没建(要发 itch.io 时再建 Windows/Linux 两个)
