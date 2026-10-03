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
| `scripts/farm/` | 农田:`crop_data.gd`、`crop_db.gd`、`farm_cell.gd`(一格)、`farm_plot.gd`(网格+规则) |
| `scripts/player/` | 玩家本体 + 三个状态(idle/walk/use) |
| `scripts/state_machine/` | 通用节点状态机(与游戏解耦) |
| `scripts/world/`, `scripts/ui/` | 地图生成、HUD |
| `scripts/dev/selftest.gd` | 逻辑自检(**不是主场景**) |
| `game_source/` | 原版素材,勿改名(名字里有空格,勿动) |
| `tilesets/test_tilemap.tres` | TileSet(仍沿用旧文件名) |
| `docs/` | 长期记忆:进度、决策 |

## 硬性约定

- 开发必须通过 Godot MCP 驱动,不要用 `godot --headless` 绕过(见 skill `godot-dev`)。
- 每次改动后跑 `run_project` + `get_debug_output`,无 ERROR 才算完成。
- **逻辑改动就跑自检场景**:`run_project {scene: "res://scenes/dev/selftest.tscn"}`,
  输出里有 `=== SELFTEST END: N checks, 0 failed ===` 才算过。
  人按键验不了规则,自检才是这类改动的「跑通」。
- **全部 UI 文案用 ASCII**:Godot 默认字体没有 CJK 字形,中文会显示成方块。
- GDScript 缩进必须用 Tab。
- `GameState`/`TimeManager` 的函数**不要写成 `static`**:它们是 autoload 实例,
  从实例调用 static 函数引擎会报错(踩过,见 DECISIONS)。
- 收工前更新 `docs/PROGRESS.md` 并 commit(可用 `/handoff`)。
