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

---

## <a id="action-blocks"></a>`Basic Charakter Actions.png` 的一帧不是「一列」,是 2x2 块

**决策**:一个动作 = 图集里 `行 2b, 2b+1` × `列 0, 1` 的 2x2 块,四帧按阅读顺序取
`(0,0) (1,0) (0,1) (1,1)`。表在 `tools/gen_player_scene.py` 的 `TOOL_ACTION`。

**理由**:这张图是 **96x576 = 2 列 x 12 行**。原来按「每行一个动作、x 取 0/48/96/144」
去切,96 宽的图上 x=96/144 已经**出了图界**,于是每个 `use_*` 动画的第 3、4 帧是空的。
更隐蔽的是它不报错,画面也「有东西动」,只是动作永远播不全。

图里其实是 **3 个动作 x 2 个朝向分组**(偶数块朝前/后,奇数块朝左/右)。

**验证**:自检里有一条 `every action frame is inside the texture`,把每一帧的
`AtlasTexture.region` 拿去和原图尺寸比 —— 越界这种错只有真的量矩形才查得出来。

---

## <a id="tools-sheet"></a>`Tools.png` 不是「6 种工具」,是「3 种工具 x 6 个朝向」

**决策**:一个游戏工具占**一整组**(两行),不是某一格。表在 `scripts/ui/tool_icons.gd`。

**理由**:这是「工具的素材好像全都用的同一种」那个 bug 的根。96x96 有 36 个非空格子,
旧表从行 2/3 里挑了 3 格 —— 那是**同一把工具的 3 个朝向**,于是 4 个工具里 3 个长得一样。

三组靠调色板区分得清清楚楚:一组是纯金属灰、一点木色都没有(定为洒水壶),
另两组是金属 + 木柄(`(129,129,129) (183,183,183)` + `(144,98,93) (170,121,89)`)。
哪组是锄头没有官方图例,是推断 —— 想换只改那张表。

**第 4 个工具(收获)直接取成熟作物的贴图**(`Basic_Plants.png` 第 4 列),
语义上正好是「你要收的东西」,而且一定和前三张不像;它还会跟着当前选中的作物变。

**验证**:自检逐像素比较四张图标贴图,不是比重了算(`_distinct_icon_count`)——
图标 id 不同但取到同一片美术,是最容易犯又最容易漏的错。
最后还拿截图做了模板匹配,四个格子都是**逐像素 0 误差**命中各自的目标格。

---

## <a id="hud-panels"></a>HUD 用半透明底板,不用 Label 描边

**决策**:顶栏/底栏各铺一块半透明 `StyleBoxFlat`,文字直接画在上面。

**理由**:Godot 的 `Label` outline 是**逐边各画一圈**,小字号下糊成一团;
底板还能顺便把「文字压在花花绿绿的草地上」这个可读性问题一次解决。

---

## <a id="bitmap-font-yoffset"></a>BMFont 的 `yoffset`:Godot 不按文档来

**决策**:`tools/gen_pixel_font.py` 里存的是「字形顶到 ascender 顶的距离」,
即 BMFont 文档语义的 `yoffset + base`。

**理由**:实测(Godot 4.3)的规则是

    字形顶 = Label 顶端 + yoffset        (base 不参与绘制)

而 BMFont 文档说 `字形顶 = 基线 + yoffset`、`基线 = 顶端 + base`。按文档写,
整行字会**上移一个 base**:12px 字体就上移 12px,顶栏里只剩字的下半截、顶被裁掉。

**最坑的地方**:`get_ascent()` / `get_height()` 这些度量**全都是对的**,
从度量接口根本查不出来 —— 只能真的去量像素。
所以自检里有一个 `_measure_font_baseline()`:开一个探针 Label(黑底 + 已知坐标),
读一帧画面,量 'D' 的墨迹落在第几行,断言它正好是 `ascent - 大写高` 到 `ascent - 1`。

**证据**:探针 Label 放在 y=204、`yoffset=-9` 的 'D' 实际画在 y=195..203。

**教训**:遇到「文字/图形位置不对」,先造一个**背景干净、坐标已知**的探针去量,
不要在真实画面里靠数格子猜 —— 后者掺着相机变换、面板底色、窗口缩放,
量出来的东西不一定是你在找的那个。

---

## <a id="hud-theme"></a>HUD 的字体和字号必须在代码里显式设置

**决策**:`hud.gd::_apply_theme()` 建一个 `Theme`,**同时**设
`default_font` / `default_font_size` 和 `set_font("Label", ...)` / `set_font_size("Label", ...)`,
再挂到四个面板上。

**理由**:两个独立的静默坑。

1. **只设 `Theme.default_font` 不够**。实测 `Label.get_theme_font("font")` 会回退到
   Godot 内置的 Open Sans,位图字体根本没被用上 —— 不报错、不警告,
   只是字「看起来还行但不太对」。
2. **字号不钉死会放大点阵字**。位图字体只有一个真实尺寸(12px),
   而 `Label` 从默认主题拿到的是 16,Godot 于是按 16/12 缩放,
   行高从 15 变 20,字顶被顶出面板裁掉。

**被否决**:写在 `hud.tscn` 的 `Theme` 子资源里 —— 那样第 1 条就复现了,
而且在 .tscn 里没法断言。放代码里才能让自检真的查到。

**验证**:`_check_hud_layout()` 断言字体名是 `SproutUI-12`、字号是 12、行高是 15,
并且**读一帧真实画面**确认 DayLabel 的墨迹行完整落在自己的矩形里。

---

## <a id="reimport"></a>换了 `game_source/` 里的资源,必须 `launch_editor` 一次

**决策/流程**:改 `.png`/`.fnt` 等**被导入**的资源后,`launch_editor` 开一次项目、
等它重新导完、再关掉,然后才 `run_project`。新增 `class_name` 脚本同理。

**理由**:`run_project`(即 `godot -d`)**不会**重新导入资源。它拿的是
`.godot/imported/` 里的旧缓存,并且**一声不吭** —— 于是你会一直在量/看旧的东西,
还以为自己的改动没效果,顺着错误的方向查很久(这次就是:改了三版字形度量都没生效)。

**自查**:比对 `.godot/imported/<hash>.md5` 和源文件的 mtime,前者应该更新。

**教训**:「改了没反应」先怀疑**没重新导入**,再怀疑代码。
