extends Node2D

## 开发用自检场景(**不是主场景**)。
##
## 为什么要它:状态切换、工具规则这些逻辑靠「人按键盘」验证不了,而 run_project 不能替人按键。
## 这里用 Input.action_press() 和直接调 API 的方式把核心规则跑一遍,结果打到控制台,
## 于是「逻辑对不对」也能通过 get_debug_output 检查。
##
## 跑法:run_project {scene: "res://scenes/dev/selftest.tscn"}

## 道具素材的调色板分家族(和离线工具 `tools/check_props.py` 用的是同一张表)。
##
## 为什么要在引擎里再存一份:图集里**有些精灵是紧挨着摆的**(灌木右边挨着一截
## 树桩、麦穗长在叶子上),拿连通域自动量包围盒就会把邻居圈进来。这种错**不会
## 报任何错**,只是画面上凭空多出一截木头 —— 逻辑测试全绿也照样错。
## 所以这里把「一条 rect 里只能有它自己那一族颜色」变成断言,改坏就红。
## 所有精灵脚下那团半透明阴影:(80, 64, 134, a=30)。它单独一族,不参与判断。
const SHADOW_TINT := Color8(80, 64, 134, 30)

const PROP_PALETTE := {
	"green": [
		Color8(151, 187, 142), Color8(110, 150, 124), Color8(174, 212, 153), Color8(95, 122, 121),
		Color8(103, 131, 92), Color8(194, 224, 154), Color8(141, 177, 93), Color8(192, 212, 112),
		Color8(120, 161, 88), Color8(130, 168, 132), Color8(107, 116, 112), Color8(86, 101, 96)
	],
	"wood": [
		Color8(196, 154, 108), Color8(182, 137, 98), Color8(170, 121, 89), Color8(144, 98, 93),
		Color8(220, 185, 138), Color8(149, 122, 75), Color8(232, 207, 166), Color8(117, 76, 96)
	],
	"stone": [
		Color8(129, 139, 131), Color8(193, 200, 185), Color8(157, 168, 154), Color8(176, 185, 171),
		Color8(84, 89, 89), Color8(84, 87, 94), Color8(243, 244, 231), Color8(243, 216, 197)
	],
	"pink": [
		Color8(138, 74, 112), Color8(189, 117, 126), Color8(175, 103, 118), Color8(163, 91, 112),
		Color8(217, 154, 154), Color8(232, 181, 172), Color8(105, 74, 135), Color8(144, 104, 159),
		Color8(167, 123, 179), Color8(88, 63, 131), Color8(113, 57, 112), Color8(85, 87, 147),
		Color8(95, 105, 156), Color8(113, 128, 177), Color8(80, 94, 119), Color8(146, 178, 212),
		Color8(203, 224, 222)
	],
	"yellow": [
		Color8(234, 225, 120), Color8(176, 150, 67), Color8(212, 193, 105), Color8(191, 169, 84),
		Color8(238, 238, 155), Color8(244, 244, 160)
	],
}

## 宠物狗的脚本。和图里那些动物一样**不用 class_name** —— `preload` 拿它的常量和
## 静态函数就够了(和 farm_props.gd 引 chicken.gd 一个路子)。
const DogScript := preload("res://scripts/world/dog.gd")

var _checks: int = 0
var _failures: int = 0

@onready var plot: FarmPlot = $FarmPlot
@onready var player: Player = $Player


func _ready() -> void:
	# 关掉自动过天,保证测试里的日期推进是可数的
	TimeManager.auto_advance = false
	player.farm_plot = plot
	TimeManager.day_changed.connect(_on_day_changed)

	await get_tree().process_frame
	print("=== SELFTEST BEGIN ===")
	_test_grid()
	_test_soil_rules()
	_test_growth_cycle()
	_test_sprites()
	_test_targeting()
	_test_state_machine()
	_test_tool_art()
	await _test_movement()
	await _test_main_scene()
	print("=== SELFTEST END: %d checks, %d failed ===" % [_checks, _failures])


func _on_day_changed(_day: int) -> void:
	plot.advance_day()


func check(label: String, condition: bool) -> void:
	_checks += 1
	if condition:
		print("  PASS  %s" % label)
	else:
		_failures += 1
		print("  FAIL  %s" % label)


func _test_grid() -> void:
	print("-- grid")
	check("plot is 12x7", plot.cells.size() == 84)
	check("has_cell(0,0)", plot.has_cell(Vector2i(0, 0)))
	check("has_cell(11,6)", plot.has_cell(Vector2i(11, 6)))
	check("no cell (12,0)", not plot.has_cell(Vector2i(12, 0)))
	check("half-cell rounds down", plot.world_to_cell(plot.to_global(Vector2(15.5, 0.5))) == Vector2i(0, 0))
	check("next tile maps to cell 1", plot.world_to_cell(plot.to_global(Vector2(16.5, 0.5))) == Vector2i(1, 0))
	check("outside plot is ignored", plot.use_tool(GameState.Tool.HOE, Vector2i(99, 99), "wheat") == "")


func _test_soil_rules() -> void:
	print("-- soil rules")
	var cell := Vector2i(0, 0)
	check("water before tilling refused",
		plot.use_tool(GameState.Tool.WATERING_CAN, cell, "wheat") == "Till the soil first.")
	check("plant before tilling refused",
		plot.use_tool(GameState.Tool.SEED, cell, "wheat") == "Till the soil first.")
	check("harvest on bare soil refused",
		plot.use_tool(GameState.Tool.HAND, cell, "wheat") == "Nothing to harvest.")
	check("tilling works", plot.use_tool(GameState.Tool.HOE, cell, "wheat") == "Tilled the soil.")
	check("tilling twice refused", plot.use_tool(GameState.Tool.HOE, cell, "wheat") == "Already tilled.")
	check("watering works", plot.use_tool(GameState.Tool.WATERING_CAN, cell, "wheat") == "Watered.")
	check("watering twice refused",
		plot.use_tool(GameState.Tool.WATERING_CAN, cell, "wheat") == "Already watered today.")


func _test_growth_cycle() -> void:
	print("-- growth cycle")
	var cell := Vector2i(1, 0)
	plot.use_tool(GameState.Tool.HOE, cell, "wheat")
	GameState.add_item(GameState.seed_item_id("wheat"), 6)
	var seeds_before := GameState.item_count("seed_wheat")

	check("planting works", plot.use_tool(GameState.Tool.SEED, cell, "wheat") == "Planted Wheat.")
	check("seed consumed", GameState.item_count("seed_wheat") == seeds_before - 1)
	check("planting on occupied cell refused",
		plot.use_tool(GameState.Tool.SEED, cell, "wheat") == "Something is already growing here.")

	var planted := plot.get_cell(cell)
	check("starts at stage 0", planted.display_stage() == 0)
	check("not mature at stage 0", not planted.is_mature())

	TimeManager.advance_day()
	check("unwatered crop does not grow", planted.growth == 0)

	plot.use_tool(GameState.Tool.WATERING_CAN, cell, "wheat")
	TimeManager.advance_day()
	check("watered crop grows one level", planted.growth == 1)
	check("water dries up after a day", not planted.watered)
	check("stage advanced to 1", planted.display_stage() == 1)

	var guard := 0
	while not planted.is_mature() and guard < 20:
		plot.use_tool(GameState.Tool.WATERING_CAN, cell, "wheat")
		TimeManager.advance_day()
		guard += 1
	check("matures after 4 watered days", planted.is_mature())
	check("growth equals growth_to_mature", planted.growth == CropDB.get_crop("wheat").growth_to_mature())
	check("count_mature is 1", plot.count_mature() == 1)

	var coins_before := GameState.coins
	check("harvest works",
		plot.use_tool(GameState.Tool.HAND, cell, "wheat") == "Harvested wheat (+16 coins).")
	check("coins increased by sell price", GameState.coins == coins_before + 16)
	check("wheat in inventory", GameState.item_count("wheat") == 1)
	check("cell emptied", plot.get_cell(cell).is_empty())
	check("soil stays tilled after harvest", plot.get_cell(cell).is_tilled())
	check("harvesting again refused",
		plot.use_tool(GameState.Tool.HAND, cell, "wheat") == "Nothing to harvest.")

	# 欠种子时应该给出可执行的提示,而不是静默失败
	var other := Vector2i(2, 0)
	plot.use_tool(GameState.Tool.HOE, other, "greens")
	GameState.select_crop("greens")
	while GameState.item_count(GameState.seed_item_id("greens")) > 0:
		GameState.add_item(GameState.seed_item_id("greens"), -1)
	check("planting without seeds reports it",
		plot.use_tool(GameState.Tool.SEED, other, "greens") == "Out of Greens seeds (press B to buy).")


func _test_sprites() -> void:
	print("-- sprites")
	var wheat := CropDB.get_crop("wheat")
	check("wheat has 4 stages", wheat.stage_count() == 4)
	check("wheat stage 0 region", wheat.region_for_stage(0) == Rect2(16, 0, 16, 16))
	check("wheat stage 3 region", wheat.region_for_stage(3) == Rect2(64, 0, 16, 16))
	check("greens stage 0 region is row 1", CropDB.get_crop("greens").region_for_stage(0) == Rect2(16, 16, 16, 16))
	check("stage index clamps", wheat.region_for_stage(9) == wheat.region_for_stage(3))
	check("crop texture loads", load(wheat.texture_path) != null)
	check("soil texture loads", load("res://game_source/Tilesets/Tilled_Dirt_Wide.png") != null)
	var soil_sprite := plot.get_cell(Vector2i(0, 0)).get_node("SoilSprite") as Sprite2D
	check("soil sprite has atlas texture", soil_sprite.texture is AtlasTexture)
	check("soil sprite is (16,16)", (soil_sprite.texture as AtlasTexture).region == Rect2(16, 16, 16, 16))

	# 土块/作物的贴图必须**正好盖住自己那一格**。
	#
	# 这条抓的是 Sprite2D 默认 `centered = true` 的坑:格子的原点在左上角,
	# 不把精灵摆到格子中心的话,16x16 的贴图会以左上角为圆心画、整块偏左上 8px ——
	# 玩家看到的就是「锄到的格子和指示框不是同一格」(用户报过)。
	var probe_cell := FarmCell.new()
	probe_cell.position = Vector2(320, 96)
	add_child(probe_cell)
	probe_cell.configure(Vector2i(0, 0))
	probe_cell.till()
	var probe_soil := probe_cell.get_node("SoilSprite") as Sprite2D
	check("a tilled cell shows its soil", probe_soil.visible)
	check("the soil sprite covers exactly its own cell", _covers_cell(probe_soil, probe_cell))
	probe_cell.plant(CropDB.get_crop("wheat"))
	var probe_crop := probe_cell.get_node("CropSprite") as Sprite2D
	check("a planted cell shows its crop", probe_crop.visible)
	check("the crop sprite covers exactly its own cell", _covers_cell(probe_crop, probe_cell))
	probe_cell.queue_free()


## 目标格:必须 = **脚下**那格 + 朝向偏移。
##
## 用户反馈「不知道会锄哪块地,而且锄的地有点歪,不是正前方那块」。
## 玩家是自由走位的(没做格对齐),而且「脚」和身体中心差 6px
## (player.tscn 里 CollisionShape2D 在 (0,6))。老写法拿**身体中心**当锤点:
## `world_to_cell(position + facing * 16)` —— 上下朝向会差**一整格**,
## 而且目标格会随「站在格里的哪个位置」跳。这里把它钉死。
func _test_targeting() -> void:
	print("-- tool targeting")
	var home := plot.cell_center(Vector2i(4, 3))
	var expected := {
		Vector2.UP: Vector2i(4, 2),
		Vector2.DOWN: Vector2i(4, 4),
		Vector2.LEFT: Vector2i(3, 3),
		Vector2.RIGHT: Vector2i(5, 3),
	}
	for facing: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		player.global_position = home
		player.set_facing(facing)
		check("target = the cell you stand in + one step (%s)" % _facing_name(facing),
			player.standing_cell() == Vector2i(4, 3) and player.target_cell() == expected[facing])

	# 在格子里挪来挪去(±5px)不能换格 —— 「歪」的另一半原因
	var seen := {}
	for offset: Vector2 in [Vector2(-5, -1), Vector2(5, 1), Vector2(2, -1), Vector2(-2, 1)]:
		player.global_position = home + offset
		player.set_facing(Vector2.RIGHT)
		seen[player.target_cell()] = true
	check("small steps inside the cell keep the same target", seen.size() == 1)
	check("...and it is still the right neighbour", seen.has(Vector2i(5, 3)))

	# 回归:身体中心在格子边界上方 2px、脚已经在下一格时,面朝下必须锄**脚下那格的下方**。
	# 老写法在这里得到的是 (4,4) —— 正好是玩家站着的那格(这就是「锄歪了」)。
	player.global_position = Vector2(home.x, 62.0)
	player.set_facing(Vector2.DOWN)
	check("the cell you stand in is the one under your feet",
		player.standing_cell() == Vector2i(4, 4))
	check("facing down from there targets the next row, not your own",
		player.target_cell() == Vector2i(4, 5))

	# 站在农田下沿外面往上锄:得够得到最下面那排,不然贴边一排种不了
	player.global_position = Vector2(home.x, 120.0)
	player.set_facing(Vector2.UP)
	check("you can till the bottom row from outside the plot",
		player.target_cell() == Vector2i(4, 6) and plot.has_cell(player.target_cell()))


func _facing_name(facing: Vector2) -> String:
	if facing == Vector2.UP:
		return "up"
	if facing == Vector2.DOWN:
		return "down"
	if facing == Vector2.LEFT:
		return "left"
	return "right"


func _test_state_machine() -> void:
	print("-- state machine")
	var machine: NodeFiniteStateMachine = player.get_node("StateMachine")
	check("state machine exists", machine != null)
	check("initial state is idle", machine.current_state_name == "idle")
	check("idle/walk/use all registered",
		machine.states.has("idle") and machine.states.has("walk") and machine.states.has("use"))

	machine.on_state_transition("walk")
	check("switch to walk", machine.current_state_name == "walk")

	# 关键回归测试:老代码是 signal transition(无参)+ transition.emit("idle"),
	# 一旦真的切状态就会报 "too many arguments"。这里走的就是那条路径。
	var walk_state: NodeState = machine.states["walk"]
	walk_state.transition.emit("idle")
	check("transition signal carries the state name", machine.current_state_name == "idle")

	machine.on_state_transition("nonexistent")
	check("unknown state is ignored", machine.current_state_name == "idle")


func _test_movement() -> void:
	print("-- movement")
	var start := player.global_position
	Input.action_press("walk_left")
	# 等到真的动了为止(最多 60 物理帧)。合成按键不保证当帧生效 —— 实测有过整只
	# 玩家一步不动的情况,原来写死等 6 帧就报 FAIL。等条件而不是等帧数。
	var waited := 0
	while player.global_position.x >= start.x and waited < 60:
		await get_tree().physics_frame
		waited += 1
	check("player moved left", player.global_position.x < start.x)
	check("facing is left", player.facing == Vector2.LEFT)
	check("walk state active while pressed",
		(player.get_node("StateMachine") as NodeFiniteStateMachine).current_state_name == "walk")

	Input.action_release("walk_left")
	for i in 3:
		await get_tree().physics_frame
	check("back to idle when released",
		(player.get_node("StateMachine") as NodeFiniteStateMachine).current_state_name == "idle")
	check("velocity zeroed in idle", player.velocity == Vector2.ZERO)


## 指示框有没有真的画出像素。
##
## 只比「框内 vs 框外」不够 —— 旁边那格地面本来就可能是别的颜色(草 vs 泥土)。
## 所以读同一格两次:一次框开着、一次把框藏起来,亮度必须有差别。
## 这样测的只是「框产生了像素」,与底下是什么地形无关。
## 锄一格,然后逐像素比较前后两帧:变化的像素必须**全部**落在那格的屏幕矩形里。
##
## 用户报「指示器的格子和实际作用的格子不是一个格子」,根因就是土块贴图偏移了 8px
## (见 _covers_cell 的注释)。逻辑层的断言查不出这种偏 —— 只有真看画面才知道
## 「变色的那块地」在哪。
func _check_soil_lands_on_its_cell(walker: Player, farm: FarmPlot) -> void:
	var cell := Vector2i(2, 3)
	var target := farm.get_cell(cell)
	check("the pixel test starts from an untilled cell",
		target != null and not target.is_tilled())
	if target == null or target.is_tilled():
		return

	# 让相机正对这一格(相机挂在玩家上方,减掉它的局部位置就是「玩家站哪能看到这格」),
	# 再把角色藏起来:48px 的精灵会盖住格子,而且 idle 动画自己在动。
	walker.global_position = farm.cell_center(cell) - walker.camera.position
	walker.camera.make_current()
	# 相机开了平滑:传送完不 reset 的话画面还在滑,「什么都不做」的对照帧也会有差异
	walker.camera.reset_smoothing()
	var walker_was_visible := walker.visible
	walker.visible = false
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var inside := _cell_screen_rect(farm, cell)
	var area := inside.grow(24)
	var view := Rect2i(Vector2i.ZERO, Vector2i(get_viewport().get_visible_rect().size))
	var on_screen := view.encloses(area)
	check("the pixel test cell is fully on screen", on_screen)
	if not on_screen:
		walker.visible = walker_was_visible
		return

	var before := get_viewport().get_texture().get_image()
	# 对照:什么都不做时这一块画面必须是静止的(水面的动画图块落在里面就会露馅)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var idle := get_viewport().get_texture().get_image()
	check("the pixel test area is static while nothing happens",
		_diff_count(idle, before, area) == 0)

	farm.use_tool(GameState.Tool.HOE, cell, "")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var after := get_viewport().get_texture().get_image()
	walker.visible = walker_was_visible

	var changed_inside := _diff_count(after, idle, inside)
	var changed_area := _diff_count(after, idle, area)
	print("      soil pixel test: %d/%d px changed inside cell %s, %d changed in the 64x64 area" % [
		changed_inside, inside.get_area(), cell, changed_area])
	check("tilling repaints every pixel of that cell", changed_inside == inside.get_area())
	check("tilling repaints nothing outside that cell", changed_area == changed_inside)


func _check_indicator_ink(indicator: Node2D, walker: Player, farm: FarmPlot) -> void:
	if indicator == null:
		check("the indicator draws pixels (skipped: no indicator)", true)
		return
	# 站在最下面那排的**正下方一格**、面朝上:目标 = 最下面那排,
	# 且落在画面中间,不会被上下两条 HUD 栏盖住。
	var cell := Vector2i(4, 6)
	walker.global_position = farm.cell_center(cell) + Vector2(0, FarmPlot.CELL_SIZE)
	walker.set_facing(Vector2.UP)
	# 自检场景里自己那个玩家也带着相机,不抢当前活动相机的话读到的画面是另一个视角
	walker.camera.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	check("the indicator targets the bottom row while standing below it",
		indicator.call("target_cell") == cell)

	# 角色精灵是 48px、比一格(16px)还大,站着时会把面前那格盖掉 ——
	# 量像素之前先把它藏起来,不然测的是「角色的腿有没有变化」。
	var walker_was_visible := walker.visible
	walker.visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var lit := _indicator_luma(farm, cell)
	indicator.visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var dark := _indicator_luma(farm, cell)
	indicator.visible = true
	walker.visible = walker_was_visible
	print("      indicator ink: luma %.3f with the box, %.3f without" % [lit, dark])
	check("the indicator samples landed on screen", lit >= 0.0 and dark >= 0.0)
	check("the indicator really draws pixels", lit - dark > 0.01)


## 取农田某格 25 个采样点(含边框线)的平均亮度。
## 世界 -> 屏幕用视口自己的 canvas_transform —— 和渲染用的同一套变换,
## 所以不用假设相机 zoom / 位置 / 边界夹紧。返回 -1 表示采样点全在画面外。
func _indicator_luma(farm: FarmPlot, cell: Vector2i) -> float:
	var image := get_viewport().get_texture().get_image()
	var corner := get_viewport().get_canvas_transform() * farm.to_global(Vector2(cell) * FarmPlot.CELL_SIZE)
	var total := 0.0
	var samples := 0
	for offset: int in [1, 4, 8, 11, 14]:
		for other: int in [1, 4, 8, 11, 14]:
			var px := floori(corner.x) + offset
			var py := floori(corner.y) + other
			if px < 0 or py < 0 or px >= image.get_width() or py >= image.get_height():
				continue
			total += image.get_pixel(px, py).get_luminance()
			samples += 1
	return total / float(samples) if samples > 0 else -1.0


## 精灵画出来的矩形(世界坐标)是不是正好等于它所在那一格的矩形。
## 用精灵自己的 global transform —— 自己手算 `get_rect() + position` 很容易漏一项
## (第一次写这个 helper 就漏了 sprite.position,反过来冤枉了正确的代码)。
func _covers_cell(sprite: Sprite2D, cell: FarmCell) -> bool:
	var xform := sprite.get_global_transform()
	var rect := sprite.get_rect()
	var top_left: Vector2 = xform * rect.position
	var bottom_right: Vector2 = xform * rect.end
	var expected := Rect2(cell.global_position,
		Vector2(FarmCell.CELL_SIZE, FarmCell.CELL_SIZE))
	var actual := Rect2(top_left, bottom_right - top_left)
	if actual != expected:
		print("        精灵 %s 盖的是 %s,格子的矩形是 %s" % [sprite.name, actual, expected])
	return actual == expected and rect.size == expected.size


## 某个农田格在屏幕上占的矩形(用渲染用的 canvas_transform,不猜相机位置)
func _cell_screen_rect(farm: FarmPlot, cell: Vector2i) -> Rect2i:
	var corner: Vector2 = get_viewport().get_canvas_transform() 		* farm.to_global(Vector2(cell) * FarmPlot.CELL_SIZE)
	return Rect2i(Vector2i(floori(corner.x), floori(corner.y)),
		Vector2i(FarmPlot.CELL_SIZE, FarmPlot.CELL_SIZE))


## 两张画面在某个矩形里有多少像素不同
func _diff_count(a: Image, b: Image, rect: Rect2i) -> int:
	var count := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				count += 1
	return count


func _props_avoid_plot(props: FarmProps, farm: FarmPlot) -> bool:
	var origin := props.to_local(farm.global_position)
	for x in range(farm.columns):
		for y in range(farm.rows):
			var cell := Vector2i(floori(origin.x / 16.0) + x, floori(origin.y / 16.0) + y)
			if props.blocked.has(cell):
				return false
	return true


func _spawn_is_clear(props: FarmProps, spawner: Node2D, radius: int) -> bool:
	var origin := props.to_local(spawner.global_position)
	var center := Vector2i(floori(origin.x / 16.0), floori(origin.y / 16.0))
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if props.blocked.has(center + Vector2i(dx, dy)):
				return false
	return true


## 工具图标 / 使用动画:照着「工具各不相同」这条需求写的回归测试
func _test_tool_art() -> void:
	print("-- tool art")
	var tool_ids := GameState.TOOL_ORDER
	check("there are 6 tools (4 farm tools + axe + pickaxe)", tool_ids.size() == 6)

	# 四张图标必须真的不一样。最阴的错法是「同一把工具转四个角度」——
	# 四个 icon_id 不同,但取到的是同一片美术,所以这里比的是**像素**。
	var seen: Array[Texture2D] = []
	for tool in tool_ids:
		var icon_id := ToolIcons.icon_id_for_tool(tool)
		var texture := ToolIcons.make_harvest_texture("wheat") if icon_id == "harvest" \
			else ToolIcons.make_texture(icon_id)
		var reuse := false
		for other in seen:
			if _same_image(texture, other):
				reuse = true
		seen.append(texture)
		check("tool %d icon '%s' is its own art" % [tool, icon_id], not reuse)

	# 收获图标应该跟着作物变
	check("the harvest icon follows the selected crop",
		not _same_image(ToolIcons.make_harvest_texture("wheat"),
			ToolIcons.make_harvest_texture("greens")))

	var frames := player.animated_sprite.sprite_frames
	var missing: Array[String] = []
	for tool in tool_ids:
		for direction in ["front", "back", "left", "right"]:
			var anim_name := "use_%d_%s" % [tool + 1, direction]
			if not frames.has_animation(anim_name):
				missing.append(anim_name)
	check("24 use animations exist (6 tools x 4 directions)", missing.is_empty())
	check("use animations are distinct per tool",
		frames.get_frame_texture("use_1_front", 0) != frames.get_frame_texture("use_2_front", 0))
	check("use animations are distinct per direction",
		frames.get_frame_texture("use_1_front", 0) != frames.get_frame_texture("use_1_left", 0))
	check("each use animation has 2 frames (one atlas row = one direction)",
		frames.get_frame_count("use_1_front") == 2 and frames.get_frame_count("use_3_left") == 2)

	# 「挥到两边」那个 bug 的回归测试。动作图集一行 = 一个朝向的两帧;
	# 旧的错法把 2b、2b+1 两行当成「一个动作的 4 帧」,于是 use_*_left 和 use_*_right
	# 拿到同一对行 = 同一个动画,里左一帧右一帧交替。
	# 断言:①一个动画只能来自一行 ②同一工具的四个朝向必须落在四行不同的行上。
	var row_report: Array[String] = []
	for tool in tool_ids:
		var used_rows: Array[int] = []
		for direction in ["front", "back", "left", "right"]:
			var anim_name := "use_%d_%s" % [tool + 1, direction]
			var anim_rows: Array[int] = []
			for index in frames.get_frame_count(anim_name):
				var row := _atlas_row(frames.get_frame_texture(anim_name, index))
				if not anim_rows.has(row):
					anim_rows.append(row)
			if anim_rows.size() != 1:
				row_report.append("%s spans rows %s" % [anim_name, anim_rows])
			elif used_rows.has(anim_rows[0]):
				row_report.append("%s reuses row %d" % [anim_name, anim_rows[0]])
			else:
				used_rows.append(anim_rows[0])
	check("each direction of a tool uses its own atlas row", row_report.is_empty())
	for line in row_report:
		print("      ", line)

	# 图集里左/右两行本来就是精确镜像的一对,那就逐帧比像素 —— 只要动画里混了朝向,
	# 这里就不会全等。(比行号更直接:证明画出来的确实是同一个朝向。)
	var mirror_ok := true
	var mirrored_frames := 0
	for tool in tool_ids:
		var left := "use_%d_left" % [tool + 1]
		var right := "use_%d_right" % [tool + 1]
		for index in frames.get_frame_count(left):
			var a := _frame_image(frames.get_frame_texture(left, index))
			var b := _frame_image(frames.get_frame_texture(right, index))
			if a == null or b == null:
				mirror_ok = false
				continue
			mirrored_frames += 1
			if not _is_mirror(a, b):
				mirror_ok = false
				print("      %s frame %d is not the mirror of %s" % [left, index, right])
	check("left frames are the exact mirror of the right frames (%d frames)" % mirrored_frames,
		mirror_ok and mirrored_frames == 12)

	# 前/后不能接反:靠脸 —— 立绘表里只有前视图的头部有肤色像素(实测每行 5~8 颗,
	# 后视图 0 颗)。行 4a 应当是前、4a+1 应当是后。
	var front_skin := 0
	var back_skin := 0
	for tool in tool_ids:
		front_skin += _skin_pixels("use_%d_front" % [tool + 1])
		back_skin += _skin_pixels("use_%d_back" % [tool + 1])
	check("front action frames show the face, back frames do not",
		front_skin >= 12 and back_skin == 0)
	check("idle still has 2 frames", frames.get_frame_count("idle_front") == 2)

	# 这是曾经的真 bug:Actions 图集只有 96 宽,动画却去取 x=96/144 ——
	# 后两帧落在图外,画出来是空的。这里把每一帧的矩形都拿去和贴图尺寸比。
	check("every action frame is inside the texture", _frames_fit_texture(frames))

	# 按工具选动画:正对下用锄头时应该是 use_1_front
	player.set_facing(Vector2.DOWN)
	player.play_use_anim(GameState.Tool.HOE)
	check("hoe plays use_1_front", player.animated_sprite.animation == "use_1_front")
	player.play_use_anim(GameState.Tool.WATERING_CAN)
	check("watering can plays use_2_front", player.animated_sprite.animation == "use_2_front")
	player.play_use_anim(GameState.Tool.HAND)
	check("harvest plays use_4_front", player.animated_sprite.animation == "use_4_front")
	player.set_facing(Vector2.UP)
	player.play_use_anim(GameState.Tool.SEED)
	check("seeds facing up plays use_3_back", player.animated_sprite.animation == "use_3_back")

	# 斧 / 镐。图标是 materials 图集里两格没人用过的手持工具(见 tool_icons.gd 的说明)。
	# 两张必须互不相同 —— 不然又回到「同一把工具转个角度」那个老毛病。
	check("the axe and pickaxe icons are not the same art",
		not _same_image(ToolIcons.make_texture("axe"), ToolIcons.make_texture("pickaxe")))
	check("the wood and stone icons are not the same art",
		not _same_image(ToolIcons.make_texture("wood"), ToolIcons.make_texture("stone")))
	player.set_facing(Vector2.DOWN)
	player.play_use_anim(GameState.Tool.AXE)
	check("the axe plays use_5_front", player.animated_sprite.animation == "use_5_front")
	player.play_use_anim(GameState.Tool.PICKAXE)
	check("the pickaxe plays use_6_front", player.animated_sprite.animation == "use_6_front")
	# 免费素材包只有 3 套动作(锄/收割/浇水),没有「砍」的专用动作 ——
	# 斧和镐故意借用锄头那套过顶挥砍,这条把那个妥协钉在测试里(不是忘记改)。
	# 比**像素**而不是比资源对象:每一帧都是各自 new 出来的 AtlasTexture,
	# 指向同一块区域但对象不同(这里第一次就比错了,报了个假 FAIL)。
	check("the axe and pickaxe borrow the hoe's overhead swing",
		_same_image(frames.get_frame_texture("use_5_front", 0), frames.get_frame_texture("use_1_front", 0))
		and _same_image(frames.get_frame_texture("use_6_left", 0), frames.get_frame_texture("use_1_left", 0)))

	# 哪些工具是对「地面上的物件」动手的 —— player.gd 靠这个分派
	var gather: Array[int] = []
	for tool in tool_ids:
		if GameState.tool_works_on_props(tool):
			gather.append(tool)
	check("only the axe and the pickaxe work on props",
		gather == [GameState.Tool.AXE, GameState.Tool.PICKAXE])

	# HUD 用的位图字体能在运行时加载
	check("HUD has the pixelfont resource", load("res://game_source/font/sprout_ui.fnt") != null)


## 某一帧落在图集的第几行(格子是 48x48)
func _atlas_row(texture: Texture2D) -> int:
	var atlas := texture as AtlasTexture
	if atlas == null:
		return -1
	return floori(atlas.region.position.y / 48.0)


## 把一帧的像素从图集里裁出来(取不到就返回 null)
func _frame_image(texture: Texture2D) -> Image:
	var atlas := texture as AtlasTexture
	if atlas == null or atlas.atlas == null:
		return null
	var sheet := atlas.atlas.get_image()
	if sheet == null:
		return null
	if sheet.is_compressed():
		sheet.decompress()
	return sheet.get_region(Rect2i(atlas.region))


## a 与「左右翻转后的 b」是不是同一张图。
##
## 不能直接比 get_data():导入器开着 process/fix_alpha_border(见 .png.import),
## 它会把**全透明**像素的 RGB 抹成邻居颜色,免得缩放出黑边 —— 而那个抹痕对镜像
## 并不对称,比原始字节能比出假差异。(踩过:6 对帧实际 0 像素差异,却报了 3 个 FAIL。)
## 所以只比 alpha 蒙版 + **不透明**像素的颜色。
func _is_mirror(a: Image, b: Image) -> bool:
	if a.get_size() != b.get_size():
		return false
	var flipped: Image = b.duplicate()
	flipped.flip_x()
	for y in a.get_height():
		for x in a.get_width():
			var ca := a.get_pixel(x, y)
			var cb := flipped.get_pixel(x, y)
			var opacity := ca.a > 0.5
			if opacity != (cb.a > 0.5):
				return false
			if opacity and not ca.is_equal_approx(cb):
				return false
	return true


## 头部区域(x16..32, y13..24)里肤色像素的个数 = 「有没有脸」。
## 前视图 5~8 颗,后视图 0 颗;侧视图 4 颗(从实测得来,不是猜的)。
func _skin_pixels(anim_name: String) -> int:
	var frames := player.animated_sprite.sprite_frames
	var image := _frame_image(frames.get_frame_texture(anim_name, 0))
	if image == null:
		return -1
	var skin := Color8(232, 181, 172)
	var found := 0
	for y in range(13, 25):
		for x in range(16, 33):
			var c := image.get_pixel(x, y)
			if absf(c.r - skin.r) < 0.02 and absf(c.g - skin.g) < 0.02 and absf(c.b - skin.b) < 0.02:
				found += 1
	return found


## 两张图标贴图是不是同一片美术(比像素,不比资源对象)
func _same_image(a: Texture2D, b: Texture2D) -> bool:
	if a == null or b == null:
		return a == b
	var image_a := a.get_image()
	var image_b := b.get_image()
	if image_a == null or image_b == null:
		return a == b
	if image_a.get_size() != image_b.get_size():
		return false
	return image_a.get_data() == image_b.get_data()


## 所有 use_* 动画的帧矩形是否都落在图集内
func _frames_fit_texture(frames: SpriteFrames) -> bool:
	for anim_name in frames.get_animation_names():
		if not anim_name.begins_with("use_"):
			continue
		for index in frames.get_frame_count(anim_name):
			var texture := frames.get_frame_texture(anim_name, index)
			if texture == null:
				return false
			var atlas := texture as AtlasTexture
			if atlas == null or atlas.atlas == null:
				return false
			var sheet: Vector2 = atlas.atlas.get_size()
			var region: Rect2 = atlas.region
			if region.position.x < 0.0 or region.position.y < 0.0 \
					or region.end.x > sheet.x or region.end.y > sheet.y:
				print("      out of bounds: %s frame %d rect %s sheet %s" % [anim_name, index, region, sheet])
				return false
	return true


## 真实主场景的集成测试:把 main.tscn 实例进来,验证接线 / 坐标换算 / 水墙碰撞。
func _test_main_scene() -> void:
	print("-- main scene integration")
	var packed := load("res://scenes/main.tscn") as PackedScene
	check("main.tscn loads", packed != null)
	if packed == null:
		return

	var main := packed.instantiate()
	add_child(main)
	await get_tree().process_frame

	var map := main.get_node("FarmMap")
	var main_player := main.get_node("Player") as Player
	var main_plot := main.get_node("FarmMap/FarmPlot") as FarmPlot
	var main_props := main.get_node("FarmMap/Props") as FarmProps
	check("main.gd injected the farm plot", main_player.farm_plot == main_plot)
	check("map built water walls", map.get_node("WaterWalls").get_child_count() > 0)
	_test_grass_terrain(map)
	check("HUD is present", main.get_node("HUD") != null)
	await _measure_font_baseline()
	await _check_hud_layout(main.get_node("HUD"))
	check("props were scattered", main_props.placed.size() > 20)
	check("props have trees", main_props.count_kind("tree") > 5)
	check("props have rocks", main_props.count_kind("rock") > 0)
	check("props have wood", main_props.count_kind("wood") > 0)
	check("props have decor", main_props.count_kind("deco") > 0)
	check("props avoid the farm plot", _props_avoid_plot(main_props, main_plot))
	check("props keep clear of the spawn", _spawn_is_clear(main_props, main_player, 1))
	check("solid props have collision shapes", _solid_props_are_blocking(main_props))
	check("tree collision hugs the trunk (several bands)", _tree_collision_bands(main_props) > 2)

	# 随机撒点最大的风险是「把一块地彻底封死」。这里真的搜一遍:
	# 从出生点能走到农田吗?能走到的地占全部可站立地的多少?
	var spawn_cell: Vector2i = main_props.to_local_cell(main_player.global_position)
	var walkable := main_props.reachable_from(spawn_cell)
	var walkable_total := main_props.walkable_cell_count()
	check("spawn cell itself is walkable", walkable.has(spawn_cell))
	check("the farm plot is reachable from the spawn", _plot_is_reachable(main_props, main_plot, walkable))
	check("the island is not chopped into islands (90% connected)",
		walkable.size() * 10 >= walkable_total * 9)
	check("props left most of the grass walkable", walkable_total * 2 > main_props.grass_cells.size())

	# 站在农田左下方,面朝上 -> 目标是 (0,0) 格
	main_player.global_position = Vector2(320, 131)
	main_player.set_facing(Vector2.UP)
	check("target cell inside the plot", main_plot.has_cell(main_player.target_cell()))
	check("target cell is (0,0)", main_player.target_cell() == Vector2i(0, 0))

	# 指示框必须圈着**工具真正会作用的那格**。框和动作都走 Player.target_cell(),
	# 所以这里先读框、再真锄一次,比对锄过的那格 —— 框画错地方这条就挂。
	var indicator := main.get_node_or_null("TargetIndicator") as Node2D
	check("the main scene has a target indicator", indicator != null)
	if indicator != null:
		check("the indicator is wired to the player and the plot",
			indicator.get("player") == main_player and indicator.get("plot") == main_plot)
		# 必须画在所有东西**上面**(包括角色)。角色精灵 48px、比一格大得多,
		# 画在地面层时面朝上会把框整格挡住 —— 这是从真实截图的像素里量出来的,
		# 不是预估的。用 z_index = -1 也不行:负 z 会被父节点的 z 抵消下场。
		check("the indicator draws on top of the map and the player",
			indicator.get_index() > main.get_node("FarmMap").get_index()
			and indicator.get_index() > main_player.get_index())
		await RenderingServer.frame_post_draw
		check("the indicator follows the faced cell",
			indicator.call("target_cell") == Vector2i(0, 0))

	GameState.select_tool(GameState.Tool.HOE)
	main_player.use_current_tool()
	check("hoe tills the faced cell in the real scene", main_plot.get_cell(Vector2i(0, 0)).is_tilled())
	if indicator != null:
		check("the indicator pointed at the cell that got tilled",
			indicator.call("target_cell") == Vector2i(0, 0))

	# 「真的画出来了吗」只在逻辑层查不出来 —— 真读一帧画面量像素。
	await _check_indicator_ink(indicator, main_player, main_plot)

	# 「锄的格子」和「画面里变色的那块地」必须是同一格(用户第二次报的正是这个)
	await _check_soil_lands_on_its_cell(main_player, main_plot)

	# 走到草岛的左边往水里推,应该被正好在岸边的水墙挡住。
	#
	# 三个坑(都踩过):
	#  1. 出发格不能写死坐标 —— 道具按格子随机撒。
	#  2. 而且「左边连着几格空」必须用 **Props 自己的格坐标系**去问 walkable:
	#     grass 层有 (-8,-5) 的 position 偏移,同一组格号在两层里差半格,
	#     拿 grass 的格号查 Props 的格子集合 = 选到一格背后靠着树的位置,
	#     玩家一步都动不了(实测停在 x=-216 而不是期望的 -259)。
	#     游戏代码里 farm_props.gd::_layer_cells() 转过,这里也必须转。
	#  3. 走到停为止,别写死等几帧。
	var grass_layer: TileMapLayer = map.get_node("GameTilemap/grass")
	var leftmost_of_row := {}
	for cell in grass_layer.get_used_cells():
		var world: Vector2 = grass_layer.to_global(grass_layer.map_to_local(cell))
		var prop_cell := main_props.to_local_cell(world)
		leftmost_of_row[prop_cell.y] = mini(int(leftmost_of_row.get(prop_cell.y, 1 << 30)), prop_cell.x)

	# 行的顺序固定下来:字典遍历顺序会变,不然每次跑选到不同的一行,像偶发
	var rows: Array = leftmost_of_row.keys()
	rows.sort()
	var start_cell := Vector2i(-999, -999)
	for y in rows:
		var run := 0
		while walkable.has(Vector2i(int(leftmost_of_row[y]) + run, int(y))):
			run += 1
		if run >= 5:
			start_cell = Vector2i(int(leftmost_of_row[y]) + 2, int(y))
			break
	check("found a shore run with no props blocking it", start_cell.x != -999)

	main_player.global_position = main_props.cell_center(start_cell)
	var start_x := main_player.global_position.x

	# 这里验的是**水墙碰撞**,不是输入。所以直接每物理帧给一下速度 + move_and_slide,
	# 不靠 Input.action_press —— 合成按键在这个环境里时灵时不灵(实测偶尔整只
	# 玩家一步不动、状态还停在 idle),那就是「偶发 FAIL」的真正来源。
	# 输入→行走 由 _test_movement() 负责,两边各管一件事。
	(main_player.get_node("StateMachine") as NodeFiniteStateMachine).on_state_transition("idle")
	for i in 90:
		await get_tree().physics_frame
		main_player.velocity = Vector2.LEFT * Player.SPEED
		main_player.move_and_slide()
	main_player.velocity = Vector2.ZERO
	check("player moved towards the shore", main_player.global_position.x < start_x)

	# 水墙要**正好贴着**草地的左沿。玩家脚下是个半径 5 的碰撞圆(见
	# player.tscn 的 CircleShape2D_body),从右边撞一堵竖直的墙,圆心会停在
	# 「草地左沿 + 5」上 —— 两边都要卡住,因为这里有两个相反的错法:
	#
	#   * 墙往里缩 -> 玩家还好端端站在草地上就撞到看不见的东西(走不到岸边)
	#   * 墙往外扩 -> 玩家能走到水面上
	#
	# 而且只断言「没走进水里」也不够:第一种错法会通过。半径从场景里读,不写死,
	# 免得以后改了碰撞形状忘了改测试。
	var radius := ((main_player.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius
	var edge_x := _leftmost_grass_edge_x(main)
	var stopped_x := main_player.global_position.x
	print("      岸边: 草左沿 x=%.1f, 玩家停在 x=%.1f, 期望 %.1f (贴边 + 圆半径 %.0f)" % [edge_x, stopped_x, edge_x + radius, radius])
	var shoreline_ok := _failures
	check("water wall stopped the player at the shore", stopped_x > edge_x)
	check("water wall is flush with the shore (within 1px)", absf(stopped_x - (edge_x + radius)) <= 1.0)
	if _failures > shoreline_ok:
		# 只在挂了的时候打：每帧刷一屏道具/墙的信息会把控制台淹掉
		_dump_shore(main, main_props, main_player)

	await _test_tree_blocks_player(main_props, main_player)
	_test_landmarks(main_props)
	await _test_gather(main_props, main_player, indicator, main.get_node("HUD"))
	# 这里必须 await:它内部有 60 个物理帧的推墙循环。不 await 的话它会变成
	# 「发射后不管」的协程,和后面的测试**抢玩家位置** —— 后果是它读到的
	# 玩家位置是别的测试摆的(实测停在 416.8 而不是塘边的 -221)。
	await _test_ponds(map, main_player, main_plot)
	_test_prop_art()
	_test_every_wood_variant_is_choppable(main_props)
	await _test_dog(main, main_player)


## 宠物狗:用户给的素材(`game_source/Pets/lilpuddinpuggums.png`)经
## `tools/pack_dog.py` 处理成 `game_source/Pets/pug_walk.png`。
func _test_dog(main: Node2D, walker: Player) -> void:
	var dog := main.get_node_or_null("Dog")
	check("main scene has the pet dog", dog != null)
	if dog == null:
		return
	_test_dog_art(dog, main)
	check("the dog draws after the player (so it is visible while following)",
		dog.get_index() > walker.get_index())
	await _test_dog_follow(main, dog, walker)


## 狗的图集处理得对不对。三条都是**不报错**的错法,所以必须断言:
##   1. 白底没抠 -> 游戏里狗屁股后面跟着一个白方块;
##   2. 动画名和行对不上 -> 往右走却播朝左的帧(玩家那边栽过一次);
##   3. 忘了缩小 -> 源图 26x24 的狗比 14x16 的农夫还大。
func _test_dog_art(dog: Node2D, main: Node2D) -> void:
	print("-- pet dog art (keyed white background + packed sheet)")
	var sheet := load(DogScript.SHEET) as Texture2D
	check("the packed dog sheet is 48x96 (3 cols x 4 rows of 16x24)",
		sheet != null and sheet.get_size() == Vector2(DogScript.CELL.x * 3, DogScript.CELL.y * 4))

	var sprite := dog.get_node_or_null("Sprite") as AnimatedSprite2D
	check("the dog has a sprite", sprite != null)
	if sprite == null:
		return
	var frames := sprite.sprite_frames
	check("the dog has idle+walk for 4 directions (8 animations)",
		frames.get_animation_names().size() == 8)

	var rows_used := {}
	var mapping_ok := true
	for dir_name in DogScript.DIR_ROWS:
		var row: int = DogScript.DIR_ROWS[dir_name]
		rows_used[row] = true
		for prefix in ["idle", "walk"]:
			var anim := "%s_%s" % [prefix, dir_name]
			if not frames.has_animation(anim):
				mapping_ok = false
				continue
			var want := 1 if prefix == "idle" else DogScript.WALK_FRAMES
			if frames.get_frame_count(anim) != want:
				mapping_ok = false
			for index in frames.get_frame_count(anim):
				var atlas := frames.get_frame_texture(anim, index) as AtlasTexture
				if atlas == null or atlas.atlas != sheet \
						or atlas.region != DogScript.frame_rect(row, index):
					mapping_ok = false
	check("every dog animation takes its frames from its own row", mapping_ok)
	check("the four directions use four different rows", rows_used.size() == 4)

	# 逐像素过一遍每个走路帧
	var empty_frames := 0
	var ink_in_corner := 0
	var min_height := 999
	var max_height := 0
	var min_x := 999
	var max_x := -1
	var tongue_front := 0
	var tongue_back := 0
	for dir_name in DogScript.DIR_ROWS:
		for index in DogScript.WALK_FRAMES:
			var image := _frame_image(frames.get_frame_texture("walk_%s" % dir_name, index))
			if image == null:
				continue
			var box := _frame_bbox(image)
			if box.size == Vector2i.ZERO:
				empty_frames += 1
				continue
			min_height = mini(min_height, box.size.y)
			max_height = maxi(max_height, box.size.y)
			min_x = mini(min_x, box.position.x)
			max_x = maxi(max_x, box.position.x + box.size.x)
			if image.get_pixel(0, 0).a > 0.5:
				ink_in_corner += 1
			var tongue := _count_colours(image, [Color8(235, 47, 181), Color8(255, 69, 243)])
			if dir_name == "front":
				tongue_front += tongue
			elif dir_name == "back":
				tongue_back += tongue
	check("no dog frame is empty", empty_frames == 0)
	check("the white background is gone (frame corners are transparent)", ink_in_corner == 0)
	check("the dog is scaled to farm size (%d..%d px tall; the farmer is 16)"
		% [min_height, max_height], min_height >= 9 and max_height <= 14)
	check("the front view shows the tongue, the back view does not (%d / %d)"
		% [tongue_front, tongue_back], tongue_front > 0 and tongue_back == 0)
	check("every frame keeps its content inside its cell (x %d..%d of %d)"
		% [min_x, max_x, DogScript.CELL.x], min_x >= 0 and max_x <= DogScript.CELL.x)

	# 左右两帧必须**逐像素**是镜像:差半个源像素的话,狗转身时会闪一下
	var mirrored := 0
	for index in DogScript.WALK_FRAMES:
		var left := _frame_image(frames.get_frame_texture("walk_left", index))
		var right := _frame_image(frames.get_frame_texture("walk_right", index))
		if left != null and right != null and _is_mirror(left, right):
			mirrored += 1
	check("left frames are the exact mirror of right frames (%d)" % mirrored,
		mirrored == DogScript.WALK_FRAMES)

	# 原点当「地面上的落点」用,脚就必须落在原点上下 —— 偏了整只狗会浮在半空 /
	# 掉到地底下(格子贴图偏移那种不报错的错法,见 DECISIONS#cell-sprites)
	var feet := _dog_feet_offset(dog, sprite, frames)
	print("      脚: 最低一行不透明像素在原点下方 %.1f px(期望 -1.0 上下)" % feet)
	check("the dog's feet sit on its origin (within 2px)", absf(feet) <= 2.0)

	# 白底素材必须已经被 tools/pack_dog.py 处理过:源图也是导入好的贴图,
	# 直接引它一样能跑,只是游戏里会多一圈白 —— 所以比对像素而不是资源路径
	check("the frames come from the packed sheet, not the raw white-bg source",
		_frames_use_sheet(frames, sheet))


## 动画是不是都取自这张图集(而不是源图 / 别的贴图)
func _frames_use_sheet(frames: SpriteFrames, sheet: Texture2D) -> bool:
	for anim_name in frames.get_animation_names():
		for index in frames.get_frame_count(anim_name):
			var atlas := frames.get_frame_texture(anim_name, index) as AtlasTexture
			if atlas == null or atlas.atlas != sheet:
				return false
	return true


## 一张帧图里不透明像素的包围盒(全透明返回零矩形)
func _frame_bbox(image: Image) -> Rect2i:
	var min_x := 1 << 30
	var min_y := 1 << 30
	var max_x := -1
	var max_y := -1
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.5:
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2i(0, 0, 0, 0)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


## 图里这几种颜色各有多少个不透明像素(容差 0.02:导入后颜色是浮点)
func _count_colours(image: Image, colours: Array) -> int:
	var found := 0
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a <= 0.5:
				continue
			for want in colours:
				if absf(c.r - want.r) < 0.02 and absf(c.g - want.g) < 0.02 \
						and absf(c.b - want.b) < 0.02:
					found += 1
					break
	return found


## 帧里最低那行不透明像素,离狗自己的 position 有多远(世界 px,正 = 更低)。
## 走精灵自己的变换算:第 r 行的世界 y = position + offset - CELL.y/2 + r
## (centered = true,所以贴图中心在 position + offset)。
func _dog_feet_offset(dog: Node2D, sprite: AnimatedSprite2D, frames: SpriteFrames) -> float:
	var bottom := -1
	for anim_name in frames.get_animation_names():
		for index in frames.get_frame_count(anim_name):
			var image := _frame_image(frames.get_frame_texture(anim_name, index))
			if image == null:
				continue
			var box := _frame_bbox(image)
			if box.size.y > 0:
				bottom = maxi(bottom, box.position.y + box.size.y - 1)
	if bottom < 0:
		return 999.0
	return sprite.global_position.y + sprite.offset.y - DogScript.CELL.y * 0.5 \
		+ bottom - dog.global_position.y


## 跟随:狗靠「重走玩家的脚印」绕开实心物件,所以这里不但验它跟得上,
## 还真的造一堵墙让玩家绕过去 —— 直线追的实现会顶死在墙上,这一条会挂。
##
## 位置不写死随机地形:整段测试都在出生点周围 `spawn_clear_cells` 那 7x7 格里,
## 那几格是撒道具时就被保留的空地(见 farm_props.gd 的 keep_clear / reserved)。
func _test_dog_follow(main: Node2D, dog: Node2D, walker: Player) -> void:
	print("-- pet dog follows the player")
	check("the dog cannot push the player around (layer 2, mask 1)",
		dog.collision_layer == 2 and dog.collision_mask == 1
		and (walker.collision_mask & dog.collision_layer) == 0)

	var props := main.get_node("FarmMap/Props") as FarmProps
	var spawn_cell: Vector2i = props.to_local_cell(dog.global_position)
	check("the dog spawns on a walkable grass cell",
		props.grass_cells.has(spawn_cell) and not props.solid_cells.has(spawn_cell))
	check("nothing was scattered onto the dog's spawn", props.prop_at(spawn_cell).is_empty())

	# 让玩家自己的状态机安静下来:这段测试靠手推 velocity + move_and_slide,
	# 合成按键不可靠(见 DECISIONS#synthetic-input)
	(walker.get_node("StateMachine") as NodeFiniteStateMachine).on_state_transition("idle")
	var wall := _make_test_wall(Rect2(420, 238, 8, 56))
	add_child(wall)

	walker.global_position = Vector2(400, 250)
	dog.teleport_to(Vector2(368, 250))
	await _step_physics(4)
	var start_gap := dog.global_position.distance_to(walker.global_position)

	var path: Array[Vector2] = [Vector2(412, 225), Vector2(438, 225), Vector2(438, 250)]
	var dog_min_y := dog.global_position.y
	var frames_used := 0
	for point in path:
		while walker.global_position.distance_to(point) > 2.0 and frames_used < 400:
			walker.velocity = (point - walker.global_position).normalized() * Player.SPEED
			walker.move_and_slide()
			await get_tree().physics_frame
			frames_used += 1
			dog_min_y = minf(dog_min_y, dog.global_position.y)
	walker.velocity = Vector2.ZERO
	for i in 150:
		await get_tree().physics_frame
		dog_min_y = minf(dog_min_y, dog.global_position.y)

	var gap := dog.global_position.distance_to(walker.global_position)
	print("      跟随: 距离 %.1f -> %.1f px,狗最高走到 y=%.1f(墙顶 238)" % [start_gap, gap, dog_min_y])
	check("the dog caught up with the player (%.0f -> %.0f px)" % [start_gap, gap],
		gap <= DogScript.FOLLOW_GAP + 8.0)
	check("the dog walked around the wall instead of into it", dog_min_y < 238.0)
	check("the dog stopped short instead of standing on the player", gap > 1.0)
	var sprite := dog.get_node("Sprite") as AnimatedSprite2D
	check("the dog idles once it caught up (anim '%s')" % sprite.animation,
		sprite.animation.begins_with("idle_"))
	# 停下来要**面朝玩家**,不是面朝上一段路。规矩和 set_facing 一样:只认主轴。
	# (第一版这里写死 'right' 报错了 —— 狗绕完墙停在玩家上方,面朝下才是对的。)
	check("the dog faces the player once it stops (facing '%s')" % dog.dir_suffix(),
		dog.facing == _facing_towards(walker.global_position - dog.global_position))
	check("the dog ended up on grass, not in the water",
		props.grass_cells.has(props.to_local_cell(dog.global_position)))

	# 走起来要播走路动画,而且朝向跟着走的方向变。
	# 顺序要紧:先把玩家摆好并等两帧(脚印里会记下他当时的位置),
	# 再把狗放到玩家**右边** 40px 处并清空脚印 —— 不清脚印、不等这两帧的话,
	# 脚印里留着旧位置,狗会先往右跑一段,这个断言就测反了。
	walker.global_position = Vector2(360, 250)
	await _step_physics(2)
	dog.teleport_to(Vector2(400, 250))
	await _step_physics(2)
	walker.global_position = Vector2(330, 250)
	var walk_anim := ""
	var facing_while_walking := Vector2.ZERO
	for i in 40:
		await get_tree().physics_frame
		if dog.global_position.distance_to(walker.global_position) > DogScript.FOLLOW_GAP:
			walk_anim = sprite.animation
			facing_while_walking = dog.facing
	check("the dog plays the walk animation while moving ('%s')" % walk_anim,
		walk_anim.begins_with("walk_"))
	check("the dog faces left when the player is to its left ('%s')"
		% _facing_name(facing_while_walking), facing_while_walking == Vector2.LEFT)

	wall.queue_free()


## 朝向的规矩(和 dog.gd::set_facing 一致):只看主轴,斜着走不来回抽
func _facing_towards(offset: Vector2) -> Vector2:
	if absf(offset.x) > absf(offset.y):
		return Vector2.RIGHT if offset.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if offset.y > 0.0 else Vector2.UP


## 临时的一堵墙(层 1 = 和水墙同一层),用来验「狗是绕过去的」
func _make_test_wall(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "TestWall"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = rect.position + rect.size * 0.5
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	return body


## 等几个物理帧
func _step_physics(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


## 手摆地标:围栏圈 / 鸡舍 / 鸡。
##
## 这里最要紧的一条是「围栏到底站在哪个格上」:地标用的是**草地层**那套格坐标,
## 而道具占用簿(blocked / solid_cells)是 props 自己那套。两套差半格的话,
## 围栏会整排漂到水里(岛外面全是一片水,看起来还挺正常),而且
## 碰撞墙也跟着漂 —— 玩家会撞到看不见的东西。
func _test_landmarks(props: FarmProps) -> void:
	print("-- landmarks (fence pen / coop / chickens)")
	check("the pen is fenced", props.count_kind("fence") >= 14)
	check("there is a chicken house", props.count_kind("house") == 1)

	var off_grass := 0
	for entry in props.placed:
		if entry["kind"] != "fence":
			continue
		if not props.grass_cells.has(entry["cell"]):
			off_grass += 1
	check("every fence piece stands on a grass cell", off_grass == 0)

	# 鸡圈里不许长树:地标那几格在撒道具之前就被剔掉了
	var intruders := 0
	for entry in props.placed:
		var kind: String = entry["kind"]
		if kind == "fence" or kind == "house":
			continue
		if _rect_overlaps(entry["cell"], entry["size"], FarmProps.PEN_RECT) \
				or _rect_overlaps(entry["cell"], entry["size"], FarmProps.HOUSE_RECT):
			intruders += 1
	check("nothing grows inside the pen", intruders == 0)

	# 围栏必须真的挡人:每个围栏格都应该是实心的
	var not_solid := 0
	for entry in props.placed:
		if entry["kind"] != "fence":
			continue
		if not props.solid_cells.has(entry["cell"]):
			not_solid += 1
	check("the fence is solid", not_solid == 0)

	var chickens: Array[Node] = []
	for child in props.get_node("Props").get_children():
		if String(child.name).begins_with("Chicken_"):
			chickens.append(child)
	check("the pen has chickens", chickens.size() == FarmProps.CHICKEN_COUNT)
	var inside := 0
	var animating := 0
	var roam: Rect2 = props.call("_pen_interior_rect")
	for chicken in chickens:
		if roam.has_point(chicken.position):
			inside += 1
		var sprite := chicken.get_node_or_null("Sprite") as AnimatedSprite2D
		if sprite != null and sprite.sprite_frames.has_animation("walk") \
				and sprite.sprite_frames.get_frame_count("walk") == 2 and sprite.is_playing():
			animating += 1
	check("every chicken stays inside the pen", chickens.size() > 0 and inside == chickens.size())
	check("every chicken is animating from a 2-frame sheet", animating == chickens.size())


## 斧 / 镐:规则层(直接调 FarmProps)+ 玩家那条真实链路(选工具 -> 按使用)。
func _test_gather(props: FarmProps, walker: Player, indicator: Node2D, hud: CanvasLayer) -> void:
	print("-- axe / pickaxe")
	var found: Variant = props.first_solid_cell("tree")
	check("there is a tree to chop", found != null)
	if found == null:
		return
	var tree_cell: Vector2i = found
	var entry := props.prop_at(tree_cell)
	var tree_size: Vector2i = entry["size"]
	var walkable_before := props.walkable_cell_count()

	# 拿错工具应该什么都不发生
	var wrong := props.use_tool(GameState.Tool.PICKAXE, tree_cell)
	check("a pickaxe does not fell a tree",
		String(wrong["item"]) == "" and not props.prop_at(tree_cell).is_empty())
	check("the pickaxe reports that it is the wrong tool",
		String(wrong["message"]).contains("rock"))

	# 规则层:砍
	var result := props.use_tool(GameState.Tool.AXE, tree_cell)
	check("the axe gives wood", String(result["item"]) == "wood" and int(result["amount"]) == 2)
	check("the axe fells the whole tree, not just one cell", props.prop_at(tree_cell).is_empty())
	check("the felled tree leaves no collision behind",
		not props.solid_cells.has(tree_cell) and not props.blocked.has(tree_cell))
	check("the felled tree frees all its cells",
		props.walkable_cell_count() == walkable_before + tree_size.x * tree_size.y)

	# 空地上再敲
	var empty := props.use_tool(GameState.Tool.AXE, tree_cell)
	check("chopping empty ground gives nothing",
		String(empty["item"]) == "" and String(empty["message"]) != "")

	# 石头:镐
	var found_rock: Variant = props.first_solid_cell("rock")
	check("there is a rock to mine", found_rock != null)
	if found_rock != null:
		var rock_cell: Vector2i = found_rock
		check("the axe refuses to chop a rock", not props.can_use(GameState.Tool.AXE, rock_cell))
		check("the pickaxe accepts the rock", props.can_use(GameState.Tool.PICKAXE, rock_cell))
		var mined := props.use_tool(GameState.Tool.PICKAXE, rock_cell)
		check("the pickaxe gives stone",
			String(mined["item"]) == "stone" and int(mined["amount"]) == 1)
		check("the mined rock is gone", props.prop_at(rock_cell).is_empty())

	# 玩家那条链路:摆在树下面朝上,选斧头 -> 按一次使用
	var another: Variant = props.first_solid_cell("tree")
	check("there is still a tree for the player to chop", another != null)
	if another == null or indicator == null:
		return
	var target: Vector2i = another
	# 摆位必须从**农田那套格坐标**算,不能直接把身体放到「树下面那一格的中心」:
	# 目标格是用脚下那个碰撞圆(身上偏下 6px)算的,两套格坐标的偏移又不是整格,
	# 直接放会差出整整一格(第一次就是这么栽的:目标变成了树的**下面**一格)。
	# 所以:先把「农田 (0,0) 对应 props 哪一格」问出来,再推对面那一格。
	var plot_offset := walker.props_cell_of(Vector2i.ZERO)
	var standing_plot := target - plot_offset + Vector2i(0, 1)
	walker.global_position = walker.farm_plot.cell_center(standing_plot)
	walker.set_facing(Vector2.UP)
	var faced := walker.target_cell()
	check("the player faces the tree",
		String(props.prop_at(walker.props_cell_of(faced)).get("kind", "")) == "tree")

	GameState.select_tool(GameState.Tool.HOE)
	check("a hoe cannot work on a tree", not walker.props_actionable(faced))
	await get_tree().process_frame
	check("the indicator stays dim with a hoe", not bool(indicator.get("_actionable")))

	GameState.select_tool(GameState.Tool.AXE)
	check("the axe can work on the tree", walker.props_actionable(faced))
	await get_tree().process_frame
	check("the indicator points at the tree", indicator.call("target_cell") == faced)
	check("the indicator lights up on a choppable tree", bool(indicator.get("_actionable")))

	var wood_before := GameState.item_count("wood")
	walker.use_current_tool()
	check("chopping through the player adds wood to the inventory",
		GameState.item_count("wood") == wood_before + 2)
	check("the player's chop removed the tree from the map",
		props.prop_at(walker.props_cell_of(faced)).is_empty())

	# HUD 的材料格必须跟着显示出来
	var wood_label := hud.get_node("Materials/Slots").get_child(0).get_node("Count") as Label
	check("the HUD shows the chopped wood", wood_label.text == str(GameState.item_count("wood")))

	await get_tree().process_frame
	check("the indicator goes dim once the tree is gone", not bool(indicator.get("_actionable")))


## 把每一种树 / 木头都真的砍一遍。
##
## 用户报过「有些树好像倒下了,素材放的不对,树应该可以被砍」。只测
## `first_solid_cell("tree")` 那一种,漏掉的正是「某一个变体的 kind 写错了」
## (比如 `tree_autumn` 其实是一株麦子却挂着 tree + solid)。所以这里按
## **变体名**遍历:图集里每一棵树都必须能被斧头砍倒。
func _test_every_wood_variant_is_choppable(props: FarmProps) -> void:
	print("-- every tree / wood variant can be chopped")
	var tried := {}
	var chopped := 0
	var refused := 0
	for entry in props.placed.duplicate():
		var kind: String = entry["kind"]
		if kind != "tree" and kind != "wood":
			continue
		var prop_name: String = entry["name"]
		if tried.has(prop_name):
			continue
		tried[prop_name] = true
		var cell: Vector2i = entry["cell"]
		if not props.can_use(GameState.Tool.AXE, cell):
			refused += 1
			print("      %s refuses the axe at %s" % [prop_name, cell])
			continue
		var result := props.use_tool(GameState.Tool.AXE, cell)
		if String(result["item"]) != "wood":
			refused += 1
			print("      %s gave '%s' instead of wood" % [prop_name, result["item"]])
		else:
			chopped += 1

	var variants := PropDB.names_of_kind("tree").size() + PropDB.names_of_kind("wood").size()
	check("every tree / wood variant found in the world can be chopped (%d of %d variants, %d refused)"
		% [chopped, variants, refused], refused == 0 and chopped >= variants)


## 素材表的体检(引擎侧,和 `tools/check_props.py` 同一个判据)。
##
## 三条不变量:
##   1. 每条 rect 都在图集里;
##   2. rect 里**只有它自己那一族颜色** —— 把「主色族 + 半透明阴影」的包围盒
##      算出来,不该比 rect 还大(大了说明矩形把邻居精灵圈进来了);
##   3. kind 和调色板对得上:石头必须是灰的(不能是粉花)、木头必须是木色、
##      树必须有绿树冠 + 木树干。粉色只允许出现在 deco 上。
func _test_prop_art() -> void:
	print("-- prop art (one rect = one sprite)")
	var images := {}
	var glued := 0
	var mislabelled := 0
	var out_of_bounds := 0
	var seen := {}
	var checked := 0
	for prop_name in PropDB.PROPS:
		var entry: Dictionary = PropDB.PROPS[prop_name]
		var sheet_name: String = entry["sheet"]
		var path: String = PropDB.SHEETS[sheet_name]
		if not images.has(path):
			images[path] = (load(path) as Texture2D).get_image()
		var image: Image = images[path]
		var rect: Rect2 = entry["rect"]
		if rect.position.x < 0.0 or rect.position.y < 0.0 \
				or rect.end.x > image.get_width() or rect.end.y > image.get_height():
			out_of_bounds += 1
			print("      %s rect %s runs outside %s" % [prop_name, rect, path])
			continue
		var key := "%s:%s" % [sheet_name, rect]
		if seen.has(key):
			print("      %s and %s share rect %s" % [seen[key], prop_name, rect])
		seen[key] = prop_name
		checked += 1
		# 围栏是拼图块(横杆本来就伸到格子外),鸡舍是一整张图 —— 都不适用
		if sheet_name == "fence" or sheet_name == "house":
			continue
		var counts := _prop_family_counts(image, rect)
		var main := _prop_main_family(counts)
		if main == "":
			continue
		var own := _prop_family_bbox(image, rect, main)
		if own.position.x < rect.position.x - 1.0 or own.position.y < rect.position.y - 1.0 \
				or own.size.x > rect.size.x + 2.0 or own.size.y > rect.size.y + 2.0:
			glued += 1
			print("      %s rect %s holds a foreign sprite (own art is %s)"
				% [prop_name, rect, own])
		if not _prop_kind_matches_palette(entry["kind"], counts):
			mislabelled += 1
			print("      %s is kind '%s' but its palette looks like %s"
				% [prop_name, entry["kind"], _prop_shares(counts)])

	check("every prop rect is inside its sheet", out_of_bounds == 0)
	check("no prop rect has a neighbour glued in (%d rects)" % checked, glued == 0)
	check("no two props share a rect", seen.size() == checked)
	check("every prop kind matches its palette", mislabelled == 0)
	# 贴图不能比占地大:大了就会糊到隔壁格上(碰撞箱是按格算的,两边就对不上了)
	var oversize := 0
	var solid_deco := 0
	for prop_name in PropDB.PROPS:
		var entry: Dictionary = PropDB.PROPS[prop_name]
		var rect: Rect2 = entry["rect"]
		var cells := PropDB.footprint(prop_name)
		if rect.size.x > cells.x * 16 or rect.size.y > cells.y * 16:
			oversize += 1
			print("      %s is %s px but only %d cells" % [prop_name, rect.size, cells.x * cells.y])
		if entry["kind"] == "deco" and bool(entry["solid"]):
			solid_deco += 1
	check("no prop sprite is bigger than its footprint cells", oversize == 0)
	check("no decor prop is solid", solid_deco == 0)
	var thin: Array[String] = []
	for kind in PropDB.SCATTER_KINDS:
		if PropDB.names_of_kind(kind).size() < 2:
			thin.append(kind)
	check("every scattered kind has at least 2 variants", thin.is_empty())


## 只按颜色家族数一数(阴影单独一族;透明的不算)。
func _prop_family_counts(image: Image, rect: Rect2) -> Dictionary:
	var counts := {}
	for y in range(int(rect.position.y), int(rect.end.y)):
		for x in range(int(rect.position.x), int(rect.end.x)):
			var family := _prop_family(image.get_pixel(x, y))
			if family != "":
				counts[family] = int(counts.get(family, 0)) + 1
	return counts


## 主色族 = 数量最多的那一族(阴影不算,它在所有精灵脚下)。
func _prop_main_family(counts: Dictionary) -> String:
	var best := ""
	var best_count := 0
	for family in counts:
		if family == "shadow":
			continue
		if int(counts[family]) > best_count:
			best = family
			best_count = int(counts[family])
	return best


## 主色族(含阴影)在图集里占的包围盒 —— 应当就是这条 rect 本身。
func _prop_family_bbox(image: Image, rect: Rect2, family: String) -> Rect2:
	var low := Vector2i(1 << 30, 1 << 30)
	var high := Vector2i(-1, -1)
	for y in range(int(rect.position.y), int(rect.end.y)):
		for x in range(int(rect.position.x), int(rect.end.x)):
			var got := _prop_family(image.get_pixel(x, y))
			if got != family and got != "shadow":
				continue
			low = Vector2i(mini(low.x, x), mini(low.y, y))
			high = Vector2i(maxi(high.x, x), maxi(high.y, y))
	if high.x < low.x:
		return Rect2(rect.position, Vector2.ZERO)
	return Rect2(Vector2(low), Vector2(high - low + Vector2i.ONE))


func _prop_shares(counts: Dictionary) -> String:
	var total := 0
	for family in counts:
		total += int(counts[family])
	if total == 0:
		return "empty"
	var parts: Array[String] = []
	for family in counts:
		parts.append("%s:%d%%" % [family, roundi(float(counts[family]) / float(total) * 100.0)])
	parts.sort()
	return " ".join(parts)


func _prop_kind_matches_palette(kind: String, counts: Dictionary) -> bool:
	var total := 0
	for family in counts:
		total += int(counts[family])
	if total == 0:
		return false
	var share := func(family: String) -> float:
		return float(counts.get(family, 0)) / float(total)
	match kind:
		"tree":
			return share.call("green") >= 0.30 and share.call("wood") >= 0.02 \
				and share.call("pink") <= 0.20
		"rock":
			return share.call("stone") >= 0.40 and share.call("pink") <= 0.05
		"wood":
			return share.call("wood") >= 0.50 and share.call("pink") <= 0.05 \
				and share.call("green") <= 0.20
		_:
			return true  # deco 就是花花草草:粉的黄的绿的都算对


## 一个像素属于哪一族。空字符串 = 透明,不该参与判断。
func _prop_family(color: Color) -> String:
	if color.a < 0.12:
		return ""
	if color.is_equal_approx(SHADOW_TINT):
		return "shadow"
	for family in PROP_PALETTE:
		for swatch in PROP_PALETTE[family]:
			if color.is_equal_approx(swatch):
				return family
	return "other"


## 池塘:岛内「没有草」的那些格就是塘 —— 玩家不许走进去,而且要正好停在塘边。
func _test_ponds(map: Node, walker: Player, farm: FarmPlot) -> void:
	print("-- ponds")
	var grass_layer: TileMapLayer = map.get_node("GameTilemap/grass")
	var cells := grass_layer.get_used_cells()
	var low := cells[0]
	var high := cells[0]
	for cell in cells:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
	var grass := {}
	for cell in cells:
		grass[cell] = true

	# 岛本身是个规整矩形(岸的外圈不在这个矩形里),所以矩形内非草 = 池塘
	var holes: Array[Vector2i] = []
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			if not grass.has(Vector2i(x, y)):
				holes.append(Vector2i(x, y))
	check("the island has ponds carved into it", holes.size() > 100)

	var plot_rect := Rect2(farm.global_position, Vector2(farm.columns, farm.rows) * 16.0)
	var in_plot := 0
	for hole in holes:
		if plot_rect.has_point(grass_layer.to_global(grass_layer.map_to_local(hole))):
			in_plot += 1
	check("no pond runs through the farm plot", in_plot == 0)

	# 找一个「塘格 + 旁边的草格」的配对(优先左右向:玩家脚下那个碰撞圆在
	# 身上偏下 6px,竖直推的话两个轴的期望值算法不一样,左右向最干净)
	var pond_cell := Vector2i.ZERO
	var grass_cell := Vector2i.ZERO
	var push := Vector2.ZERO
	for side in [[Vector2i(1, 0), Vector2i(-1, 0)], [Vector2i(0, 1), Vector2i(0, -1)]]:
		for hole in holes:
			for step in side:
				if grass.has(hole + step):
					pond_cell = hole
					grass_cell = hole + step
					push = -Vector2(step)
					break
			if push != Vector2.ZERO:
				break
		if push != Vector2.ZERO:
			break
	check("found a pond edge to push against", push != Vector2.ZERO)
	if push == Vector2.ZERO:
		return

	var start: Vector2 = grass_layer.to_global(grass_layer.map_to_local(grass_cell))
	walker.global_position = start
	(walker.get_node("StateMachine") as NodeFiniteStateMachine).on_state_transition("idle")
	for i in 60:
		await get_tree().physics_frame
		walker.velocity = push * Player.SPEED
		walker.move_and_slide()
	walker.velocity = Vector2.ZERO

	# 比的是**脚下那个碰撞圆**的圆心(身上偏下 6px),不是身体中心 ——
	# 竖直推的时候这两个差 6px,拿身体中心比会差出一大截。
	var radius := ((walker.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius
	var pond_rect := Rect2(
		grass_layer.to_global(grass_layer.map_to_local(pond_cell)) - Vector2(8, 8), Vector2(16, 16))
	var stopped := walker.cell_anchor_position()
	# 圆不能和塘口重叠
	check("the pond water is solid", not pond_rect.grow(radius - 1.0).has_point(stopped))
	check("the player actually walked to the pond", stopped.distance_to(start) > 6.0)

	# 还要正好贴在塘边(不是被什么别的东西提前挡住)
	var along_x := push.x != 0.0
	var edge := 0.0
	if along_x:
		edge = pond_rect.end.x + radius if push.x < 0.0 else pond_rect.position.x - radius
	else:
		edge = pond_rect.end.y + radius if push.y < 0.0 else pond_rect.position.y - radius
	var actual := stopped.x if along_x else stopped.y
	print("      池塘: 塘格 %s, 从 %s 推 %s, 圆心停在 %.1f, 期望 %.1f, 差 %.1f" % [
		pond_cell, grass_cell, push, actual, edge, absf(actual - edge)])
	check("the pond wall is flush with the water edge (within 1.5px)", absf(actual - edge) <= 1.5)


## 两个格坐标矩形有重叠吗(左上角 + 尺寸那一套)
func _rect_overlaps(cell: Vector2i, size: Vector2i, rect: Rect2i) -> bool:
	return Rect2i(cell, size).intersects(rect)


## 直接量「字形到底画在哪一行」。
##
## 为什么不在截图里量:HUD 的截图里还掺着面板底色、窗口缩放、CanvasLayer 变换,
## 量出来的墨迹行不一定是字本身(踩过这个坑,来回折腾了好几轮)。
## 这里开一个干净的 SubViewport,里面只有一个 Label、位置 (0,0)、
## 垂直对齐 TOP、字体显式挂在 Label 上 —— 这时墨迹的 y 范围就**完全**等于
## 「字形顶相对 Label 顶端的距离」,没有任何别的解释空间。
##
## 期望值:base(=ascent)=12,大写字母高 9,所以基线在第 12 行,字形顶在第 3 行。
func _measure_font_baseline() -> void:
	print("-- font baseline")
	var font: Font = load("res://game_source/font/sprout_ui.fnt")
	const PROBE := Vector2(0, 200)
	const PAD := Vector2(4, 4)

	# 探针:一块纯黑背景 + 一个位置完全已知的 Label。
	# 黑底是为了让「有墨迹的像素」不可能来自游戏画面里的草地/物件。
	# **必须放进 CanvasLayer**:Control 如果在普通画布层里,会被玩家的 Camera2D
	# 一起变换 —— 于是它的 global_rect 和它实际出现在屏幕上的位置是两回事,
	# 量出来的行号就全是错的(这个坑第一次就踩了)。
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var background := ColorRect.new()
	background.color = Color.BLACK
	background.position = PROBE
	background.size = Vector2(80, 40)
	layer.add_child(background)

	var probe := Label.new()
	probe.add_theme_font_override("font", font)
	probe.add_theme_font_size_override("font_size", 12)
	probe.add_theme_color_override("font_color", Color.WHITE)
	probe.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	probe.text = "D"
	probe.position = PROBE + PAD
	probe.size = Vector2(72, 32)
	layer.add_child(probe)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var rect := probe.get_global_rect()
	var rows: Array[int] = []
	for y in range(int(rect.position.y), int(rect.position.y) + 24):
		var hit := false
		for x in range(int(rect.position.x), int(rect.position.x) + 12):
			if image.get_pixel(x, y).r > 0.5:
				hit = true
				break
		if hit:
			rows.append(y)
	layer.queue_free()

	var ascent := font.get_ascent(12)
	var first := rows[0] - int(rect.position.y) if not rows.is_empty() else -99
	var last := rows[rows.size() - 1] - int(rect.position.y) if not rows.is_empty() else -99
	print("      'D' 墨迹在 Label 内的行 %d..%d(base=ascent=%.0f, 大写高 9 -> 期望 3..11)"
		% [first, last, ascent])
	# 只在不对的时候把这块画面打成 ASCII —— 出问题时不用再写一遍探针。
	# (在引擎里看,不经过外部脚本,免得「量到的墨迹是字还是草地」再扯不清。)
	if first != 3:
		print("      probe rect %s" % rect)
		for y in range(int(PROBE.y), int(PROBE.y) + 22):
			var line := ""
			for x in range(0, 60):
				var color := image.get_pixel(x, y)
				line += "#" if color.r > 0.5 else ("+" if color.r > 0.15 else ".")
			print("      %3d %s" % [y, line])
	check("the probe draws ink at all", not rows.is_empty())
	check("glyph 'D' starts 3px below the label top (ascent - cap height)", first == 3)
	check("glyph 'D' sits on the baseline (top + 9 = ascent)", first + 9 == int(ascent))


## HUD 的排版回归测试。
##
## 这条是有血债的:位图字体(点阵)只有**一个真实字号**,而 Label 从默认主题
## 拿到的 font_size 是 16 —— Godot 于是把 12px 的点阵按 16/12 放大,
## 行高从 15 变成 20,字顶直接被顶出顶栏裁掉。截图里只看到「字少了一半」,
## 完全看不出原因。所以这里同时钉死两件事:字号必须是字体自己的 12,
## 且每个 Label 的矩形必须落在它所在面板里面。
func _check_hud_layout(hud: CanvasLayer) -> void:
	var label: Label = hud.get_node("TopBar/Margin/Row/DayLabel")
	var font: Font = label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	# 这两条对应两个真实踩过的坑:
	#   1) 只设 Theme.default_font 不设 Label 类型的字体时,get_theme_font 会
	#      回退到 Godot 内置的 Open Sans —— 位图字根本没被用上,还不报错;
	#   2) font_size 用默认的 16 时,12px 的点阵被放大 16/12,行高 15 -> 20,
	#      字顶顶出顶栏被裁掉。
	check("HUD really uses the pixelfont", font != null and font.get_font_name() == "SproutUI-12")
	check("HUD font_size matches the bitmap font (no rescaling)", size == 12)
	check("HUD line height is the font's own 15px", is_equal_approx(font.get_height(12), 15.0))

	# 端到端:真的读一帧画面,量文字墨迹落在哪几行。
	# 钉的是「BMFont 的 yoffset 被 Godot 当成相对行顶」那个坑(见
	# tools/gen_pixel_font.py):写错时整行字会往上跑、顶被裁掉,而引擎一声不吭,
	# 只设 get_ascent()/get_height() 这类度量是**查不出来**的。
	await RenderingServer.frame_post_draw
	var frame := get_viewport().get_texture().get_image()
	var label_rect := label.get_global_rect()
	var ink_rows := _ink_rows_in(frame, label_rect)
	check("the day label actually draws ink", not ink_rows.is_empty())
	if not ink_rows.is_empty():
		var first: int = ink_rows[0]
		var last: int = ink_rows[ink_rows.size() - 1]
		print("      DayLabel rect y %.0f..%.0f, ink rows %d..%d" % [
			label_rect.position.y, label_rect.end.y, first, last])
		check("the day label text is not clipped at the top", first > int(label_rect.position.y))
		check("the day label text fits inside its rect", last < int(label_rect.end.y))

	for panel_path in ["TopBar", "BottomBar", "ToolBar", "Materials", "Backpack"]:
		var panel: Control = hud.get_node(panel_path)
		var rect := panel.get_global_rect()
		# 面板必须真的装得下里面的东西。工具从 4 把变成 6 把以后,工具条比原来的面板宽
		# 66px —— PanelContainer 会自己长大,但长大的是**面板**还是被裁掉,不看不知道。
		if panel.get_child_count() > 0 and panel.get_child(0) is Control:
			check("%s contains its contents" % panel_path,
				rect.encloses((panel.get_child(0) as Control).get_global_rect()))
		for child in panel.find_children("*", "Label", true, false):
			var child_rect: Control = child
			check("%s/%s stays inside its panel" % [panel_path, child.name],
				rect.encloses(child_rect.get_global_rect()))

	var day_label: Label = hud.get_node("TopBar/Margin/Row/DayLabel")
	var text_width := font.get_string_size(day_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	check("the day label actually fits its own text", day_label.size.x >= text_width - 0.5)

	# 工具条:四个格子,每个都有图标,而且四张图不是同一张
	var slots := hud.get_node("ToolBar/Slots")
	check("tool bar has one slot per tool", slots.get_child_count() == GameState.TOOL_ORDER.size())
	var icons: Array[Texture2D] = []
	for slot in slots.get_children():
		var icons_in_slot: Array[ItemIcon] = []
		for child in slot.get_children():
			if child is ItemIcon:
				icons_in_slot.append(child)
		check("tool slot has an icon", icons_in_slot.size() == 1)
		if icons_in_slot.size() != 1:
			continue
		var icon: ItemIcon = icons_in_slot[0]
		check("tool slot icon has a texture", icon.texture != null)
		check("tool slot icon fits the slot", icon.size.x <= slot.size.x and icon.size.y <= slot.size.y)
		if icon.texture != null:
			icons.append(icon.texture)
	check("the tool icons are not all the same tool", _distinct_icon_count(icons) == 6)
	# 材料格(木头 / 石头):砍了树得看得到东西,不然按下去像没反应
	var material_slots := hud.get_node("Materials/Slots")
	check("the HUD has one material slot per material",
		material_slots.get_child_count() == GameState.MATERIAL_ORDER.size())
	var material_icons := 0
	for slot in material_slots.get_children():
		for child in slot.get_children():
			if child is ItemIcon and (child as ItemIcon).texture != null:
				material_icons += 1
	check("every material slot has an icon", material_icons == GameState.MATERIAL_ORDER.size())


## 在帧画面的某个矩形里,哪些行有「文字墨迹」(接近白色)。返回行号列表。
func _ink_rows_in(frame: Image, rect: Rect2) -> Array[int]:
	var rows: Array[int] = []
	var x0 := maxi(int(rect.position.x), 0)
	var x1 := mini(int(rect.end.x), frame.get_width())
	var y0 := maxi(int(rect.position.y), 0)
	var y1 := mini(int(rect.end.y), frame.get_height())
	for y in range(y0, y1):
		for x in range(x0, x1):
			var color := frame.get_pixel(x, y)
			if color.r > 0.75 and color.g > 0.75 and color.b > 0.75:
				rows.append(y)
				break
	return rows


func _distinct_icon_count(icons: Array[Texture2D]) -> int:
	var distinct: Array[Texture2D] = []
	for icon in icons:
		var seen := false
		for other in distinct:
			if _same_image(icon, other):
				seen = true
		if not seen:
			distinct.append(icon)
	return distinct.size()


## 找一棵树,把玩家放在它正上方往下走 —— 必须被挡住。
## 这是验证「树木有碰撞体积」这条需求的最直接办法:不是看有没有
## CollisionShape2D 节点,而是真的推一下。
func _test_tree_blocks_player(props: FarmProps, walker: Player) -> void:
	var found = props.first_solid_cell("tree")
	check("there is a solid tree to test", found != null)
	if found == null:
		return
	var tree_cell: Vector2i = found

	# props 的格坐标 -> 世界坐标(它是 FarmMap 的子节点,要经 to_global)
	var tree_bottom: Vector2 = props.to_global(Vector2(tree_cell) * 16.0 + Vector2(8, 16))
	walker.global_position = tree_bottom + Vector2(0, -48)
	var before := walker.global_position.y
	Input.action_press("walk_down")
	for i in 30:
		await get_tree().physics_frame
	Input.action_release("walk_down")
	check("the tree stopped the walker", walker.global_position.y - before < 45.0)
	check("the walker is still above the trunk", walker.global_position.y < tree_bottom.y - 4.0)


## 农田外围任意一格在可达集里,就算「玩家能走到农田」
func _plot_is_reachable(props: FarmProps, farm: FarmPlot, walkable: Dictionary) -> bool:
	var origin := props.to_local_cell(farm.global_position)
	for x in range(-1, farm.columns + 1):
		for y in range(-1, farm.rows + 1):
			if walkable.has(origin + Vector2i(x, y)):
				return true
	return false


## 每个标为实心的物件都得有一个带形状的 Body
func _solid_props_are_blocking(props: FarmProps) -> bool:
	var root := props.get_node("Props")
	var checked := 0
	for entry in props.placed:
		if not entry["solid"]:
			continue
		var cell: Vector2i = entry["cell"]
		var node := root.get_node_or_null("%s_%d_%d" % [entry["name"], cell.x, cell.y])
		if node == null:
			return false
		var body := node.get_node_or_null("Body") as StaticBody2D
		if body == null or body.get_child_count() == 0:
			return false
		checked += 1
	return checked >= props.count_kind("tree") + props.count_kind("rock") + props.count_kind("wood")


## 树的碰撞箱应该被拆成多段(树干 + 树冠),而不是一个大方块
func _tree_collision_bands(props: FarmProps) -> int:
	var root := props.get_node("Props")
	for entry in props.placed:
		if entry["kind"] != "tree":
			continue
		var cell: Vector2i = entry["cell"]
		var node := root.get_node_or_null("%s_%d_%d" % [entry["name"], cell.x, cell.y])
		if node != null:
			var body := node.get_node_or_null("Body")
			if body != null:
				return body.get_child_count()
	return 0


## 草地层的图块必须正好是「按 peering 算出来的」那一组。
##
## 这是「草坪全是错的」那个 bug 的回归测试。它**不自己实现 8 位掩码**,
## 而是拿同一个 TileSet 开一块临时 TileMapLayer、把同样的格子集合交给引擎的
## `set_cells_terrain_connect()` 跑一遍,再逐格对比 —— 让引擎当标准答案。
## 手抄那张 peering 表迟早就抄错,而错了也不会报错,只是画面不对。
##
## 另外单独断言「八邻全是草的那一格必须画 (1,1)」:这条是写给人看的,
## 把「内部整块 vs 边块」到底指什么说清楚。
func _test_grass_terrain(map: Node) -> void:
	var grass: TileMapLayer = map.get_node("GameTilemap/grass")
	var cells := grass.get_used_cells()
	check("grass layer is painted", cells.size() > 100)

	var scratch := TileMapLayer.new()
	scratch.tile_set = grass.tile_set
	scratch.set_cells_terrain_connect(cells, 0, 0, false)
	var mismatched := 0
	var distinct := {}
	for cell in cells:
		var atlas := grass.get_cell_atlas_coords(cell)
		distinct[atlas] = true
		if scratch.get_cell_atlas_coords(cell) != atlas:
			mismatched += 1
	check("grass tiles match the TileSet's own terrain peering", mismatched == 0)
	check("the grass uses both interior and edge tiles", distinct.size() > 4)

	var on_grass := {}
	for cell in cells:
		on_grass[cell] = true
	var interior := Vector2i(-999, -999)
	for cell in cells:
		var surrounded := true
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if not on_grass.has(cell + Vector2i(dx, dy)):
					surrounded = false
		if surrounded:
			interior = cell
			break
	check("the grass has a fully surrounded cell", interior.x != -999)
	check("a fully surrounded cell uses the interior tile",
		grass.get_cell_atlas_coords(interior) == Vector2i(1, 1))
	scratch.free()


## 玩家在草地上走着走着被挡住了 —— 到底是水墙还是道具?
## 两者的几何来源完全不同(水墙按水格算,道具碰撞按贴图 alpha 逐行算),
## 分不清就只能瞎改,所以直接把附近的都打出来。
func _dump_shore(main: Node, props: FarmProps, walker: Player) -> void:
	var cell: Vector2i = props.to_local_cell(walker.global_position)
	var machine := walker.get_node("StateMachine") as NodeFiniteStateMachine
	print("      玩家停在格 %s (x=%.1f y=%.1f) 状态=%s 速度=%s 动画=%s" % [cell,
		walker.global_position.x, walker.global_position.y, machine.current_state_name,
		walker.velocity, walker.animated_sprite.animation])
	# 停下来的原因:最后那次 move_and_slide 撞到了谁
	for i in walker.get_slide_collision_count():
		var hit := walker.get_slide_collision(i)
		var collider := hit.get_collider() as Node
		print("      撞到 %s 法线=%s" % [str(collider.get_path()) if collider != null else "(null)", hit.get_normal()])
	var walls := main.get_node_or_null("FarmMap/WaterWalls")
	if walls != null:
		for child in walls.get_children():
			var shape := child as CollisionShape2D
			var box := shape.shape as RectangleShape2D
			if absf(shape.global_position.y - walker.global_position.y) > 20.0:
				continue
			if absf(shape.global_position.x - walker.global_position.x) > 96.0:
				continue
			print("      水墙 x %.1f..%.1f  y=%.1f" % [shape.global_position.x - box.size.x * 0.5,
				shape.global_position.x + box.size.x * 0.5, shape.global_position.y])
	for entry in props.placed:
		var prop_cell: Vector2i = entry["cell"]
		if absi(prop_cell.x - cell.x) > 3 or absi(prop_cell.y - cell.y) > 3:
			continue
		print("      道具 %-4s %-14s 格 %s 占地 %s solid=%s" % [entry["kind"], entry["name"], prop_cell, entry["size"], entry["solid"]])
	# 逐格问一句：这格到底算不算能走?四个集合的含义不一样，对不上就是 bug 在的地方
	var walkable := props.reachable_from(cell)
	for offset in range(-4, 1):
		var probe := Vector2i(cell.x + offset, cell.y)
		print("      格 %s: walkable=%-5s solid=%-5s blocked=%-5s grass=%s" % [probe,
			walkable.has(probe), props.solid_cells.has(probe), props.blocked.has(probe),
			props.grass_cells.has(probe)])


## 当前这一行最左边的草格,它左边那条边所在的世界 x —— 也就是岸的位置
## (水墙的右沿应该和它重合)
func _leftmost_grass_edge_x(main: Node) -> float:
	var map := main.get_node("FarmMap")
	var grass: TileMapLayer = map.get_node("GameTilemap/grass")
	var target := main.get_node("Player") as Player
	var row := grass.local_to_map(grass.to_local(target.global_position)).y
	var leftmost := 1 << 30
	for cell in grass.get_used_cells():
		if cell.y == row and cell.x < leftmost:
			leftmost = cell.x
	var center: Vector2 = grass.to_global(grass.map_to_local(Vector2i(leftmost, row)))
	return center.x - 8.0   # map_to_local 给的是格子中心,减半格才是格子外沿
