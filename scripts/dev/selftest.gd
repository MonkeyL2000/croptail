extends Node2D

## 开发用自检场景(**不是主场景**)。
##
## 为什么要它:状态切换、工具规则这些逻辑靠「人按键盘」验证不了,而 run_project 不能替人按键。
## 这里用 Input.action_press() 和直接调 API 的方式把核心规则跑一遍,结果打到控制台,
## 于是「逻辑对不对」也能通过 get_debug_output 检查。
##
## 跑法:run_project {scene: "res://scenes/dev/selftest.tscn"}

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
	for i in 6:
		await get_tree().physics_frame
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
	check("there are 4 tools", tool_ids.size() == 4)

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
	check("16 use animations exist (4 tools x 4 directions)", missing.is_empty())
	check("use animations are distinct per tool",
		frames.get_frame_texture("use_1_front", 0) != frames.get_frame_texture("use_2_front", 0))
	check("use animations are distinct per direction",
		frames.get_frame_texture("use_1_front", 0) != frames.get_frame_texture("use_1_left", 0))
	check("each use animation has 4 frames",
		frames.get_frame_count("use_1_front") == 4 and frames.get_frame_count("use_3_left") == 4)
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

	# HUD 用的位图字体能在运行时加载
	check("HUD has the pixelfont resource", load("res://game_source/font/sprout_ui.fnt") != null)


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
	GameState.select_tool(GameState.Tool.HOE)
	main_player.use_current_tool()
	check("hoe tills the faced cell in the real scene", main_plot.get_cell(Vector2i(0, 0)).is_tilled())

	# 走到草岛的左边往水里推,应该被正好在岸边的水墙挡住。
	#
	# **出发格不能写死坐标,也不能只看「左边连着几格是空地」**:道具是按格子随机
	# 撒的,写死的点随时可能落进某棵树里;而只看「连着几格空」也不够 ——
	# 那几格尽头可能是棵树,量到的就成了树的位置,不是墙的位置(两种都踩过)。
	#
	# 所以要找这样的**一行**:从岛的最左一格开始往右,连着好几格都空而且走得到。
	# 这样玩家一路往左,左边除了水墙再没有别的东西挡他。
	var grass_layer: TileMapLayer = map.get_node("GameTilemap/grass")
	var leftmost_of_row := {}
	for cell in grass_layer.get_used_cells():
		leftmost_of_row[cell.y] = mini(int(leftmost_of_row.get(cell.y, 1 << 30)), cell.x)

	var start_cell := Vector2i(-999, -999)
	for y in leftmost_of_row:
		var run := 0
		while walkable.has(Vector2i(int(leftmost_of_row[y]) + run, int(y))):
			run += 1
		if run >= 5:
			start_cell = Vector2i(int(leftmost_of_row[y]) + 2, int(y))
			break
	check("found a shore run with no props blocking it", start_cell.x != -999)

	main_player.global_position = main_props.cell_center(start_cell)
	var start_x := main_player.global_position.x
	Input.action_press("walk_left")
	for i in 90:
		await get_tree().physics_frame
	Input.action_release("walk_left")
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

	for panel_path in ["TopBar", "BottomBar"]:
		var panel: Control = hud.get_node(panel_path)
		var rect := panel.get_global_rect()
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
	check("the four tool icons are not all the same tool", _distinct_icon_count(icons) == 4)


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
	print("      玩家停在格 %s (x=%.1f y=%.1f)" % [cell, walker.global_position.x, walker.global_position.y])
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
