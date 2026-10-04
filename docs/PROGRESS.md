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
| 素材对照图 | `python tools/annotate_objects.py` → `docs/art/tools_objects.png`(把代码认定的名字写在斧/镐/围栏/鸡舍的放大图上,人工核对用) |
| **道具对照图** | `python tools/annotate_props.py` → `docs/art/props_sheet.png`(`prop_db.gd` 里每条 rect 描边 + 编号 + 名字/kind/占地;怀疑「素材放错了」时看这张) |
| 道具表体检 | `python tools/check_props.py`(每条 rect 是不是**只有一个精灵** + kind 和调色板对不对,退出码 0 = 全过) |
| 动作版式图 | `python tools/annotate_actions.py` → `docs/art/actions_groups.png`(3 个动作组 x 4 个朝向,人工核对用) |
| 地形图块重算 | `res://scenes/dev/retile.tscn`(改了地图形状后要跑;先自校验参考图) |
| 地图速览 | `res://scenes/dev/map_dump.tscn`(打 ASCII 地图) |
| autoload | `GameState`=`res://scripts/core/game_state.gd`,`TimeManager`=`res://scripts/core/time_manager.gd` |
| 地图 | `res://scenes/world/farm_map.tscn`(1764 格草 + 3312 格水,72x46 格;草地层被 `tools/carve_ponds.py` 挖了 3 个池塘 = 174 格)。改完形状要重跑 `res://scenes/dev/retile.tscn`,否则新格子的图块是错的 |
| 池塘 | 3 个椭圆(带 sin 抖动边),**水是露出来的**:删掉草地格就见到下面的水层,岸边不用过渡素材;塘口自动被水墙围上(见 `docs/DECISIONS.md#ponds`) |
| 地标 | 围栏圈 + 鸡舍 + 2 只鸡,`farm_props.gd::_place_landmarks()` 手摆(`PEN_RECT`/`HOUSE_RECT`),手摆的格子在撒道具前就写进 `reserved` |
| 道具 | `FarmMap/Props`(`scripts/world/farm_props.gd` + 表 `prop_db.gd`),~350 个随机道具 + 18 段围栏 + 1 鸡舍,碰撞从贴图 alpha 现算。表里 **47 条**:树 3 / 石头 6 / 木头(含树桩)7 / 花草灌木 26 / 围栏 4 / 鸡舍 1。斧/镐能敲掉它们(tree → +2 木,wood → +1 木,rock → +1 石)。**一条 rect = 一个精灵**,图集里挨着的邻居不许被圈进来(见 `docs/DECISIONS.md#prop-art-rects`) |
| 工具 | 6 把:锄/水壶/种子/收获(作用在农田)+ 斧/镐(作用在地面物件)。斧/镐的名字是**像素推断**的,见 `docs/DECISIONS.md#gather-tools` 和 `docs/art/tools_objects.png` |
| TileSet | `res://tilesets/test_tilemap.tres`(旧名沿用;水墙碰撞由 `farm_map.gd` 运行时生成) |
| 玩家 | `res://scenes/characters/player.tscn`(32 个动画 = idle/walk x 4 朝向 + 6 把工具 x 4 朝向;由 `tools/gen_player_scene.py` 生成) |
| 宠物 | 一只狗 `Dog`(`scripts/world/dog.gd`,挂在 `main.tscn` 的 `Player` 后面),跟在玩家屁股后面(每隔 6px 记一个脚印、重走脚印 —— 直线追会顶在树上)。素材是用户另外给的**外部素材**:白底原图 `game_source/Pets/lilpuddinpuggums.png` 经 `tools/pack_dog.py` 抠底+缩一半成 `pug_walk.png`(48x96 = 3x4 格 16x24) |
| 宠物对照图 | `python tools/pack_dog.py`(顺带写 `docs/art/pug_sheet.png`:源图带格线 + 成品放大 8 倍 + 方向标注调色板) |
| HUD | `res://scenes/ui/hud.tscn` + `scripts/ui/hud.gd`(字体由 `tools/gen_pixel_font.py` 生成):顶栏 + 左下工具条(6 格)+ 右下背包 + 材料格(木/石) |
| 目标格指示框 | `scripts/farm/target_indicator.gd`(挂在 `main.tscn` 的 `TargetIndicator`,画在**所有东西之上**) |
| 截图前的准备 | 截图工具默认把整块农田锄一遍(`till_plot`),好核对「土块有没有和格子对齐」 |
| 导出 preset | **无**(还没建) |

## 操作

| 键 | 作用 |
|---|---|
| WASD / 方向键 | 四方向移动(相机跟随) |
| Space | 用当前工具作用在**面前那一格** —— 那一格地上有指示框(先按方向键定朝向) |
| 1 / 2 / 3 / 4 | 锄头 / 水壶 / 种子 / 收获 |
| 5 / 6 | 斧头(砍树、砍木料)/ 镐头(敲石头)—— 面前那一格上有树或石头时,指示框会点亮 |
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
- [x] **2026-10-03 修复「指示器的格子和实际作用的格子不是一格」** —— 用户第二次指出来的
  - **根因不在指示框**,在土块/作物贴图:`FarmCell` 里那两个 `Sprite2D` 是 `Sprite2D.new()`
    出来的,**从来没设过 position**。而格子的原点在**左上角**、`Sprite2D` 默认
    `centered = true` —— 于是 16x16 的贴图以左上角为圆心画,整块**偏左上 8px**。
    逻辑层全绿(region 是对的),只有看画面才知道。
  - 修法:`FarmCell.SPRITE_OFFSET = CELL_SIZE * 0.5`,土块和作物都摆到格子中心。
  - **回归 1(纯逻辑)**:精灵自己的 `global_transform` 算出的矩形必须逐像素等于
    它那一格的矩形。复现 bug 时报出 `[P: (312,88)] vs 格子的 [P: (320,96)]`。
  - **回归 2(端到端像素)**:相机对准一格、藏起角色,锄它,逐像素比较前后两帧
    (含先量一次「什么都不做」的对照,防止水面动画混进来)。变化必须全在那格的
    16x16 里。好版本 `256/256 inside, 256 in the area`;把偏移改回 0 复现时是
    `64/256 inside, 256 in the area` —— 四分之三的土块落到左上那格,和用户看到的一致。
  - 截图复核:锄满整块农田后,土块包围盒 `x 304..495, y 66..177`(192x112)
    正好等于农田外框,四条边界外一圈全是草像素。
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
- [x] **2026-10-03 加斧头/镐头 + 池塘 + 围栏鸡舍**,用户提的三件事(「是不是应该有镐头、斧头?
      加一点池塘,看看还有什么其他素材,增加一点」)
  - **斧 / 镐**:免费包没有斧镐、也没有「砍」的动作(付费包才有),这两格是从
    `Objects/Basic_tools_and_meterials.png` 里**捡**的(6 格里 4 格已用,剩两格是
    手持工具:不透明像素 100/85,而 `Tools.png` 里三把只有 21~33)。先用旋转不变的
    形状 IoU 证明它们和三把都不一样(交叉 IoU ~0.1),再按金属像素占比分斧/镐。
    **这两格的名字是没有官方图例的推断值** —— 人肉对照图 `docs/art/tools_objects.png`。
    规则:`GameState.tool_works_on_props()` + `FarmProps.can_use()/use_tool()/remove_at()`;
    树种 kind=tree/wood,石头 kind=rock。斧 = +2 木,砍木料 = +1 木,镐 = +1 石。
    敲完要**同时**腾 `blocked`/`solid_cells`/节点(`#prop-gather`),而且得先把节点
    摘下来再 `queue_free()`(否则帧末前一瞬间碰撞数会多算)。
    妥协:斧/镐复用锄头的过顶挥砍动作(免费包没别的可借),自检里有一条断言钉住它。
  - **池塘**:`tools/carve_ponds.py` —— 3 个椭圆(带 sin 抖动边)把**草地格删掉**,
    下面的水层就露出来了(所以岸边不需要过渡素材、塘口自动被水墙围上)。
    1938 → 1764 格(挖掉 9%)。已跑 `retile` + `tools/retile_grass.py` 重算图块
    (参考图校验仍然 PASS)。自检:岛内非草格 174 > 100、塘不穿农田、
    从岸边推进塘里停在「塘口 + 半径」**0.0px** 误差。
  - **围栏圈 + 鸡舍 + 鸡**:`farm_props.gd::_place_landmarks()` 手摆(不随机撒,否则
    围栏会断成一截截);`Fences.png` 是「十字路口」写法,只有横向横杆,所以只能拼横排;
    `scripts/world/chicken.gd` 现造 `SpriteFrames`(row0=idle/row1=walk,各 2 帧),
    在围栏内随机游荡 —— **故意不加 `class_name`**、用 `preload`,免得要重导一次。
    地标占的格子在撒道具前写进 `reserved`,所以圈里不长树。
  - **HUD 加了材料格**(木/石,右下角,带数量):砍完树看不到成果的话就像没反应。
    工具条从 4 格变 6 格:面板宽 110 → 166(`PanelContainer` 自己长大),
    自检新增「面板装得下内容」一条(工具多两把时真会溢到底色外面)。
  - **自检 163 → 223 项**,新增 `-- landmarks`(7)/`-- axe / pickaxe`(21)/`-- ponds`(5)
    和「只侜斧镐能对道具动手」等。踩过的坑:摆玩家验「面朝树」时直接拿 props 格中心摆人,
    结果差**一整格**(两套格坐标偏移不是整格 + 脚下圆比身体中心低 6px),
    得从 `props_cell_of(Vector2i.ZERO)` 问出偏移;比 `AtlasTexture` 用 `==` 会报假 FAIL,
    得逐像素比。都记在 `DECISIONS.md#test-placement-frames`。
- [x] **2026-10-03 修「有些树好像倒下了,素材放的不对,树应该可以被砍」**:
      根因是道具 rect 的**邻居被圈进来了**(连通域涨水会把挨着摆的两块精灵粘成一块),
      细节和规矩写在 `docs/DECISIONS.md#prop-art-rects`。具体:
  - `tree_autumn`(kind tree + solid,28px 高)其实是一株**麦子** —— 麦穗 + 叶子被糊成一条,
    撒到场上就是一坨倒在地上的东西还挡路;现在改名 `wheat_plant`(deco,不挡路)。
  - `bush_low` / `bush_wide_alt` 的右边**粘了一截树桩** —— 这就是画面上的「倒下的树」,
    而且灌木是 deco(敲它没反应)。两截树桩现在单独登记成 `stump_log` / `stump_tiny`
    (kind `wood`,斧头能砍),灌木矩形切到邻居之前。
  - 三朵**大粉花**被当成石头(`rock_mossy`/`rock_pile`/`rock_wide`,还标了 solid —— 
    玩家会撞在花上);反过来四块真灰石被标成了灌木。现在石头 6 种全是灰的,花 14 种全是 deco。
  - 22 条 rect 一律**少了最下面一行**(`max_y - min_y` 少加 1),树和灌木脚下的阴影被切掉。
  - 新增**离线体检** `tools/check_props.py` 和**人肉对照图** `docs/art/props_sheet.png`;
    引擎侧新增 `_test_prop_art()`(调色板判 kind + 「不许粘邻居」)
    和 `_test_every_wood_variant_is_choppable()`(按变体名把 10 种树/木头全砍一遍)。
  - **自检 223 → 231 项**,截图复核:地形/土块和改动前**逐像素一致**(156290 个地形像素里只有 77 个变),
    变化全在道具和 HUD 上 —— 说明改的只有素材。
- [x] **2026-10-04 加宠物狗(用户给的外部素材)**:
      用户给了 `lilpuddinpuggums.png`(96x192、白底、3 列 x 4 行、每格 32x48),
      要求加进游戏。处理流程和坑全写在 `docs/DECISIONS.md#dog-pet`。要点:
  - 白底**全部和画布边缘连通**(没有一处被围住的白)→ 可以安全抠成透明。
  - 原图是 **2 倍整数放大**(18432 个像素里只有 152 对不同)→ 2:1 取样缩小,不插值;
    左右两行的**镜像轴落在半个源像素上**,朝右那行得从奇数 x 开始取样,否则左右帧
    不是精确镜像(转身会闪)。改完验过 0 个像素不同。
  - 撑到农场尺寸:0.5 倍后 11~12px 高,和鸡一个量级(农夫 14x16)。
  - 精灵 `offset = (0, -12)` 让**原点落在狗脚下**;自检直接量「最低一行不透明像素
    在原点下方多远」—— 符号写反会整只狗挂到地底下,而那种错**不报错**。
  - 跟随**不用直线追**(道具散在草地上,直线必顶树),而是**重走玩家的脚印**;
    跟上了就停下、面朝玩家;卡住 0.35s 就丢一个脚印点。
  - 图层 2/掩码 1:**狗不挡玩家**,自己也不穿水/树(自检双向断言)。
    撒道具时 `farm_props.keep_clear` 给每只动物留 3x3 格,免得树长在狗身上。
  - 截图工具会把狗挪到玩家旁边(共 3 张都验过:狗的调色板像素只出现在预测的那 13x12 框里)。
  - 顺手揪出一个**假失败**:`_test_ponds()` 内部有 60 帧推墙循环却没被 await,
    变成发射后不管的协程、和后面的测试**抢玩家位置**(见 `docs/DECISIONS.md#selftest-await`)。
  - **自检 231 → 260 项**。

## Next(按顺序做)

0. **(等用户回话)确认素材名字**:`docs/art/props_sheet.png`(道具 47 条)、
   `docs/art/tools_objects.png`(斧/镐)、`docs/art/plants_sheet.png`(作物)、
   `docs/art/tools_sheet.png`(工具图标)—— 名字都是像素推断的。
   用户说「反了/不是那个」就改 `scripts/world/prop_db.gd`(名字)或 `tool_icons.gd`(rect),
   改完跑 `python tools/check_props.py` + 自检;名字不影响玩法,kind 已有回归钉住。
1. **把 HUD 的「提示」用完**:斧/镐已经会发提示了(「Chopped a tree (+2 wood).」等),
   农田那四个工具的失败分支还是静默的。在 `farm_cell.gd` (已锄/已种/水够多)
   和 `player.gd` (手里没种子/没金币)的失败分支上 `GameState` 发消息。
2. **卖东西的经济闭环**:现在收获即加钱。改成把作物拿到 `Chest`/摊位卖,
   让 `GameState.add_coins` 只在一个地方被调用,方便以后加价格波动。
   素材:`game_source/Objects/Chest.png`(240x96,检视里切区域)。
3. **鸡舍产蛋**:鸡已经在围栏里游荡了(`scripts/world/chicken.gd`),但还不产蛋。
   新建 `scripts/farm/animal_pen.gd`:每天产 1 个蛋,玩家用收获工具走到旁边捡起。
   素材:`Characters/Egg_And_Nest.png`、`Objects/Egg_item.png`(16x16)。
4. **存档**:`user://save.json`,序列化 `GameState.inventory/coins/selected_crop`
   + `TimeManager.day` + 每个 `FarmCell` 的 (soil, watered, crop id, growth)
   + **已经敲掉的道具**(现在砍了就不会重生,不存会「读档后树全回来了」)。
   `FarmPlot` 已经有稳定的 `grid_pos` 键;`TimeManager.day_fraction()` 是派生值不用存。
5. **背包格显示收获物数量**:`hud.gd::_build_backpack()` 里已经有 `harvested` 的数值,
   现在只画了种子数(右下角)。要同时显示就再加一个左下角的 Label。
6. **还没用上的素材**:`Wood_Bridge.png`(过池塘的桥 —— 现在塘是实心的,要造桥就得
   在塘上开一条通道并把水墙断开)、`Paths.png`(砌小径)、`Basic_Furniture.png`、
   `Free Cow Sprites.png` + `Simple_Milk_and_grass_item.png`(牛奶产线)。
7. **狗的后续**(可选):现在只会跟着走,不叫也不捡东西。要加「按 F 摸摸头 /
   它会去追鸡 / 存档里记住它」都是往 `dog.gd` 里加,不碰其他系统。
   另外它是**外部素材**,授权没确认前不要发 release(见下)。

## 卡点 / 风险

- **素材许可是非商业 + 禁止 AI 训练**,仓库是公开的 —— 改素材或加新素材前先读 `ASSET_CREDITS.md`。
  HUD 点阵字体来自 Noto Sans SC(SIL OFL 1.1,可再分发),**不要**换回 Consolas 之类的商用字体。
- `Basic_Plants.png` 的格子含义是像素级推断(见 `DECISIONS.md#plant-cells`),
  `Tools.png` 里「哪组是锄头」也是推断 —— 两处都有对照图可人工核对:
  `docs/art/plants_sheet.png`、`docs/art/tools_sheet.png`(`tools/annotate_sheet.py` 生成)。
- ⚠️ **待确认 1**:斧/镐用的是 `Basic_tools_and_meterials.png` 里两格没人用过的手持工具,
  **素材包里没有图例**,「哪格是斧、哪格是镐」是按金属头的宽窄/占比定的(见 `#gather-tools`)。
  对照图 `docs/art/tools_objects.png`;觉得反了就交换 `tool_icons.gd` 里两行 rect。
  另外「砍」的动作是付费包内容,斧/镐现在借锄头的挥砍动画。
- ⚠️ **待确认 2**:种子图标取的是 `Tools.png` 行 4,但按动作图集反推那一行很可能是**镰刀**
  (收割动作里举的就是它)。四个图标确实互不相同,需求已满足;
  有真正的种子袋素材时应该换过去。
- 杂草 / 石头会挡农田的格子 —— 现在 `FarmCell` 没有「障碍物」概念,以后加野草要顺手加这一位。
- 角色动画是一整块图集切出来的,没有图例。改 `tools/gen_player_scene.py` 之后
  **必须**跑一次 `launch_editor` 重新导入,否则看的是旧缓存(见 `DECISIONS.md#reimport`)。
- 自检里**合成按键不可靠**(会时灵时不灵),验物理的用例不要依赖它;
  另有「格坐标跨节点混用」的坑 —— 见 `DECISIONS.md#synthetic-input`、`#frame-mixing`、
  `#test-placement-frames`(摆玩家、比贴图都各踩过一次)。
- ⚠️ **待确认 3**:`prop_db.gd` 里那 47 条道具的**名字**是像素推断的(素材包没有图例)。
  最没把握的几条:`wheat_plant`(金黄色穗子 + 细叶,原名叫 tree_autumn)、`stump_log` /
  `stump_tiny`(全是木色,7x7 / 8x9)、`rock_mossy`(带苔的灰石)。
  对照图:`docs/art/props_sheet.png`(每条 rect 描边 + 编号,下面列出名字/kind/rect)。
  名字只影响可读性,**不影响玩法** —— kind 已经按调色板定过,自检会钉住。
- ⚠️ **待确认 4(等用户回话):宠物狗素材的来源 / 授权**。文件名
  `lilpuddinpuggums.png` 看着像某份第三方 itch.io 素材(或用户自己/委托画的),
  仓库是**公开**的,Sprout Lands 的「非商业 + 禁止 AI 训练」也不管不到它。
  需要问清:作者、链接、允许公开 / 商用 / 再分发吗。若不允许公开,
  就把 `game_source/Pets/` 加进 `.gitignore`(游戏照常能跑,只是别人 clone 后没这只狗)。
  对照图:`docs/art/pug_sheet.png`(建议让用户顺便看一眼形状/方向对不对)。
- 没有音频素材(原包里就没有)。

## 最近一次验证

- `run_project {scene: "res://scenes/dev/selftest.tscn"}` + `get_debug_output`
  → **`=== SELFTEST END: 260 checks, 0 failed ===`**,ERROR 区为空(只有一条已知无害的
  `NodeFiniteStateMachine: 未知状态 'nonexistent'` 警告)。本轮新增的关键几条:
  - `the white background is gone (frame corners are transparent)` —— 白底抠干净了
  - `the dog is scaled to farm size (11..12 px tall; the farmer is 16)`
  - `the front view shows the tongue, the back view does not (9 / 0)` —— 靠舌头色定正/反面
  - `left frames are the exact mirror of right frames (3)` —— 镜像相位对上了
  - `the dog's feet sit on its origin (within 2px)`(实测 -1.0)
  - `the dog walked around the wall instead of into it`(狗最高走到 y=225.5、墙顶 238)
  - `the dog caught up with the player (29 -> 19 px)` / `the dog faces the player once it stops`
  - 池塘回归恢复:落点 -221.0、期望 -221.0、差 **0.0**(之前那个假失败已修)
- 截图复核:`run_project {scene: "res://scenes/dev/screenshot.tscn"}` → `screenshots/shot_1..3.png`,
  三张里狗的调色板像素(`(196,98,0)` / `(255,168,92)` / `(52,36,36)` / 舌头粉)都**只出现在**
  「世界坐标 + canvas xform」算出来的那个 13x12 框里(shot_1 里全画面同色计数和框内计数相等,
  即这几颜色在画面里没有第二处来源)。
- 宠物狗图集:`python tools/pack_dog.py` → `game_source/Pets/pug_walk.png`(48x96),
  对照图 `docs/art/pug_sheet.png`;离线自验:每个帧的内容盒 11~12px 高、四角 alpha = 0、
  正面/侧面有舌头而背面 0 个、左右帧 0 个像素不同。
- `python tools/check_props.py` → **`0 problems, 0 warnings`**(47/47 干净)
- 主场景 `run_project {projectPath: "D:\\godot_projects\\croptail"}`:仅
  `[farm_props] 347 props (83 tree / 35 rock / 27 wood / 183 deco / 18 fence / 1 house) on 1587 open cells; 1587 collision boxes`
  + `[farm_map] water walls: 101 collision shapes`,**无 ERROR**
  (道具数量/空地数和加狗之前**一模一样** —— 狗出生点周围那 3x3 格本来就在保留区里)
- 上一轮那些回归依然全绿(道具 `_test_prop_art()`、`every tree / wood variant found in the world can be chopped (10 of 10)`、
  `the soil sprite covers exactly its own cell`、`tilling repaints nothing outside that cell` 256/256、
  `the pond wall is flush with the water edge` 差 0.0px、`water wall is flush with the shore` 草沿 -264/玩家 -259)
- `scripts/dev/retile.gd` → **`REFERENCE CHECK: PASS`**(263 格标准答案 0 差异;本轮没改地图形状)
- 离线工具:`python tools/render_map.py docs/art/map.png`(1152x736 整张地形图)、
  `python tools/check_props.py`、`python tools/annotate_props.py`(`docs/art/props_sheet.png`)
- 日期:2026-10-04


## 待补的记录

- 导出 preset 还没建(要发 itch.io 时再建 Windows/Linux 两个)
