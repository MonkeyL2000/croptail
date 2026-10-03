extends Node2D

## 面前那一格的**指示框**:把「工具会作用到哪一格」画在地上。
##
## 为什么需要它:玩家是自由走位的(没做格对齐),光看角色站位判断不出目标格;
## 而且「脚」和「身体中心」差 6px,朝向一歪就差一整格 —— 用户反馈过
## 「不知道会把哪块地处理好,而且锄的地有点歪」。
##
## 关键约定:它和 `use_current_tool()` 调的是**同一个** `Player.target_cell()`,
## 所以框画在哪、工具就一定作用在哪。自检里有一条断言钉着这件事
## (先读框的格子,再真按一次工具,比对锄过的那格)。
##
## 画在 Player 节点**之后**(树顺序),即压在角色上面。
##
## 一开始是画在角色底下(地面层)的,从真实截图里量出来不行:角色精灵是 48x48、
## 比一格(16px)大得多,面朝上时面前那格正好被头/身体盖住 —— 截图里整格都是角色的
## 像素,一条框线都看不见。所以改成当鼠标光标那样盖在最上面。
## (不要用 z_index=-1:负 z 会被父节点的 z 抵消下场,连农田底板都盖不住。)

## 由 main.gd 注入
var player: Player
var plot: FarmPlot

## 框在当前格上的两种状态:可操作(在农田里,或斧/镐对着一棵树)/ 不可操作(出界)
const ACTIONABLE_FILL := Color(1.0, 1.0, 1.0, 0.16)
const ACTIONABLE_LINE := Color(1.0, 0.96, 0.72, 0.85)
const IDLE_LINE := Color(0.55, 0.60, 0.62, 0.30)
## 框线往里收 0.5px。线宽 1 是压在矩形边上画的:收 0.5 恰好让它落在格子的
## 最外圈像素上(收 1 会窄一格像素,看着往左上偏)
const LINE_INSET := 0.5

var _cell := Player.INVALID_CELL
var _actionable := false


func _ready() -> void:
	set_process(false)   # 等 main.gd 接线好了再开始查


## main.gd 接线(和 player.farm_plot / farm_props.plot 一致的做法)
func setup(target_player: Player, farm: FarmPlot) -> void:
	player = target_player
	plot = farm
	_refresh()
	set_process(true)


## 当前框住的格子(自检用来比对「框 = 工具作用的那格」)
func target_cell() -> Vector2i:
	return _cell


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if player == null or plot == null:
		return
	var cell := player.target_cell()
	# 可操作 = 在农田里,或者手上是斧/镐且目标格上站着能砍/能挖的东西。
	# 后者问的是 Player(它才知道农田格算到场景格是第几格),
	# 且非斧/镐时直接短路,不会每帧遍历几百个道具。
	var actionable := plot.has_cell(cell) or player.props_actionable(cell)
	if cell == _cell and actionable == _actionable:
		return
	_cell = cell
	_actionable = actionable
	queue_redraw()


func _draw() -> void:
	if plot == null or _cell == Player.INVALID_CELL:
		return
	# 格子的世界矩形:农田的每格子节点就摆在 cell * CELL_SIZE 上
	var corner := plot.to_global(Vector2(_cell) * FarmPlot.CELL_SIZE) - global_position
	var box := Rect2(corner, Vector2.ONE * FarmPlot.CELL_SIZE)
	var line := box.grow(-LINE_INSET)
	if _actionable:
		draw_rect(box, ACTIONABLE_FILL)
		draw_rect(line, ACTIONABLE_LINE, false, 1.0)
	else:
		draw_rect(line, IDLE_LINE, false, 1.0)
