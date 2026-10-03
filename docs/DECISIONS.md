# croptail — 决策记录

> 格式:决策 + 理由 + 被否决的选项。**只记「不记下来下个会话会做错」的取舍。**
> 新条目放最前面(倒序),带锚点方便 `DECISIONS.md#xxx` 引用。

---

## <a id="plant-cells"></a>Basic_Plants.png 的格子含义是「按像素分析定的」,不是猜的

**背景**:素材包没有配图集说明,`Basic_Plants.png`(96x32,6x2 格)到底是什么作物、
哪一列是哪个生长阶段,只能自己看。

**怎么定的**:用 Python + Pillow 把每格 16x16 的主色/不透明度粗采样了一遍,再用
「按调色板量化成字符画」的方式把它打印成文本图,肉眼读出来的:

| 列 | 行 0(由绿转黄) | 行 1(常绿叶菜) |
|---|---|---|
| c0 | 土堆(只有土色,透明外框) | 小土堆 |
| c1 | 幼苗,矮 | 小苗,矮 |
| c2 | 中等 | 中等 |
| c3 | 高,已偏黄 | 高 |
| c4 | 高,最黄(成熟) | 高,顶端有穗 |
| c5 | 石头(不是作物,与 r0 相同) | 石头 |

**决策**:`wheat` = 行 0 的 c1..c4,`greens` = 行 1 的 c1..c4,各 4 个生长阶段。
**理由**:两行的色相差异(黄化 vs 常绿)正好对应两种作物,4 个尺寸就是 4 个阶段。
**风险**:这是**像素级推断**,不是官方说明。若日后发现错位,只需改
`scripts/farm/crop_db.gd` 里的 `stage_cells` 坐标,逻辑层不用动。

---

## <a id="cell-sprites"></a>农田逐格用 Sprite2D,不用 TileMapLayer

**决策**:每一格农田是一个 `FarmCell`(Node2D + 2 个 Sprite2D),由 `FarmPlot` 用代码生成。

**理由**:素材里**没有**湿土贴图,湿/干必须靠逐格 `self_modulate` 区分;
`TileMapLayer` 的 modulate 是整层级的,做不到逐格染色。逐格节点还让「土壤 + 作物」
两层叠加、成熟高亮都变成一行属性赋值。

**被否决**:TileMapLayer 画土 + 另一层画作物 —— 湿土染色无解,得自己复制一套调色后的贴图。

**代价**:格子多时节点数 = 列 x 行 x 2(现在是 84x2)。当前规模无所谓;
真要上千格再考虑换 `MultiMeshInstance2D` 或烘焙贴图。

---

## <a id="auto-walls"></a>水的碰撞墙在运行时按水格自动生成

**决策**:`scripts/world/farm_map.gd` 在 `_ready()` 里读 `water` 层的坐标,剔除被 `grass`
盖住的格子,再**按行合并成长条**生成 `StaticBody2D` + `RectangleShape2D`。

**理由**:原项目 TileSet 完全没有物理层(栅栏、房子、水都不是障碍),但农场游戏又必须
「走不出岛」。手刷物理层是不可见的重复劳动;按层数据生成是确定性的、跟地图编辑同步、
零手工维护。实测 41 个碰撞形状。

**被否决**:
- 给 TileSet 手刷 physics layer —— 每次改地图都要重刷,容易漏。
- 用 `Terrain` 的 peering bits 做水岸碰撞 —— 那套是给地形自动拼接用的,和碰撞无关。

**注**:合并成行是 41 个形状而不是 480 个,是因为逐格一个碰撞体在角色移动时
数理化代价明显,而这一层不会有半格高度的形态。

---

## <a id="no-daynight"></a>只推进「天」,不做昼夜光照

**决策**:`TimeManager` 只管日期与进度(45 秒一天,按 T 立刻过一天),不做画面变暗/灯。

**理由**:昼夜光照需要 CanvasModulate 曲线、灯光层、以及「晚上还干活吗」的一堆规则,
而当前要验证的是种植循环本身。日期已经是循环的驱动(浇水→过天→生长),光照纯装饰。

**被否决**:先做昼夜再补种植 —— 装饰先于玩法,容易把时间预算烧在调色上。

---

## <a id="ascii-ui"></a>所有 UI 文案用 ASCII

**决策**:HUD、提示、控制台输出一律英文 ASCII。

**理由**:Godot 内置默认字体不含 CJK 字形,中文会渲染成豆腐块,除非额外塞一个中文字体
(几百 KB 且要配主题)。这个项目本来就非商业个人玩,英文文案零成本。

**被否决**:引入中文字体 —— 现在不值得;真要本地化再说(那也是一次性替换主题字体)。

---

## <a id="deferred-on-enter"></a>状态机的 `on_enter()` 必须延迟调用

**决策**:`NodeFiniteStateMachine._ready()` 里用 `current_state.on_enter.call_deferred()`。

**理由**:`_ready()` 是自下而上执行的 —— 状态机子节点先于父节点 `Player` 就绪,
所以进入初始状态时 `Player` 的 `@onready var animated_sprite` 还是 `null`,
`on_enter()` 里 `play_anim()` 直接崩(`Invalid access to property 'animation' on Nil`)。
延迟到本帧末,父节点的 ready 已经完成。

**被否决**:在每个状态的 `on_enter()` 里自己判断 `if sprite == null` —— 把坑分散到所有状态里。

---

## <a id="signal-param"></a>`NodeState.transition` 信号必须带参数

**决策**:`signal transition(state_name: String)`,配套 `@warning_ignore("unused_signal")`。

**理由**:原代码是 `signal transition`(无参)却到处 `transition.emit("walk")`。
Godot 4 只在**真的发出信号时**才检查参数个数,所以平时不报错,
一按方向键就 `Error calling from signal ... too many arguments`,直接卡死。
自检里的 `transition signal carries the state name` 就是这条的回归测试。

**被否决**:保留无参信号、改用「自己找目标状态」的写法 —— 状态之间会耦合成网状。

---

## <a id="autoload-not-static"></a>`GameState` / `TimeManager` 的方法不写成 static

**决策**:autoload 脚本里的公开函数都是普通实例方法,靠 autoload 单例名调用。

**理由**:`seed_item_id()` 一开始写成 `static func`,F5 一跑引擎就报
`The function "seed_item_id()" is a static function but was called from an instance`。
在验证脚本里 `static` 是必需的(代码不在场景树里),但这里 autoload 已经提供了单例,
再叠 `static` 只会两边都别扭。

---

## <a id="class-name-cache"></a>新增 `class_name` 脚本后必须让编辑器重扫一次

**决策/流程**:每次**新增**带 `class_name` 的脚本后,用 MCP `launch_editor` 打开一次项目
(等 15~20 秒让编辑器建 `.godot/global_script_class_cache.cfg`),再关掉、再 `run_project`。

**理由**:`run_project`(godot -d)启动时**不会**重建全局类名缓存。新加的 `class_name`
在缓存里查不到,就变成 `Parser Error: Identifier "CropDB" not declared in the current scope`,
而且报错位置指向**使用方**(`game_state.gd`)而不是新文件,很容易被带偏。

**被否决**:手写 `.godot/global_script_class_cache.cfg` —— 那是缓存,格式随版本变,
而且 `run_project` 也不接受 `--import`。

---

## <a id="rename-scene-structure"></a>目录重命名:`sence` → `scenes`,`script` → `scripts`

**决策**:顺手把原项目拼错的目录名改掉了(`sence/`→`scenes/`、`script/`→`scripts/`、
`state_machiine/`→`state_machine/`),并删除 `sence/test/` 里的旧测试场景
(内容已并入 `scenes/world/farm_map.tscn`)。

**理由**:趁项目只有几屏代码的时候改,代价最低;拼错的目录名会一路带到 CI、文档、别人的 fork 里。

**被否决**:不动 —— 会一直膈应,而且越晚改越贵。

**注意**:`game_source/` 里素材文件名(含 `Charakter` 拼写、空格)属于第三方包,**不要改**。
