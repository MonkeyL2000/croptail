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

	var main_player := main.get_node("Player") as Player
	var main_plot := main.get_node("FarmPlot") as FarmPlot
	var map := main.get_node("FarmMap")
	check("main.gd injected the farm plot", main_player.farm_plot == main_plot)
	check("map built water walls", map.get_node("WaterWalls").get_child_count() > 0)
	check("HUD is present", main.get_node("HUD") != null)

	# 站在农田左下方,面朝上 -> 目标是 (0,0) 格
	main_player.global_position = Vector2(320, 131)
	main_player.set_facing(Vector2.UP)
	check("target cell inside the plot", main_plot.has_cell(main_player.target_cell()))
	check("target cell is (0,0)", main_player.target_cell() == Vector2i(0, 0))
	GameState.select_tool(GameState.Tool.HOE)
	main_player.use_current_tool()
	check("hoe tills the faced cell in the real scene", main_plot.get_cell(Vector2i(0, 0)).is_tilled())

	# 走到草岛左边界往水里推,应该被自动生成的水墙挡住
	main_player.global_position = Vector2(150, 250)
	Input.action_press("walk_left")
	for i in 40:
		await get_tree().physics_frame
	Input.action_release("walk_left")
	check("player moved towards the shore", main_player.global_position.x < 150)
	check("water wall blocked the player", main_player.global_position.x > 120)
