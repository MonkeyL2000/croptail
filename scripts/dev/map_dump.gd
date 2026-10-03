extends Node2D

## 开发工具:把整张地图打成 ASCII 图,方便在**纯文本**里检查撒点结果。
##
## 为什么需要它:装饰物是随机撒的,肉眼看截图只能看到相机拍到的一小块,
## 而「有没有东西长在农田里 / 出生点周围空不空 / 树是不是挤成一坨」这类问题
## 得看全局。ASCII 图可以直接贴进对话或日志里对比,也方便回归。
##
## 图例(一格 = 16x16 像素):
##   `~` 水      `.` 空草地    `T` 树    `O` 石头    `=` 木头    `,` 灌木/花
##   `#` 农田    `@` 玩家出生点(以它为中心 P 格内被强制留空)
##
## 跑法:run_project {scene: "res://scenes/dev/map_dump.tscn"}

@export var mark_reserved: bool = true

func _ready() -> void:
	# 等一帧:main.tscn 里的 main.gd 要先把 player 喂给 Props 再 rebuild 一次
	await get_tree().process_frame
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main := main_scene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var map: Node2D = main.get_node("FarmMap")
	var props: FarmProps = main.get_node("FarmMap/Props")
	var plot: FarmPlot = main.get_node("FarmMap/FarmPlot")
	var player: Player = main.get_node("Player")

	# 建立 格 -> 符号 的查找表
	var grid := {}
	var water: TileMapLayer = map.get_node("GameTilemap/water")
	var grass: TileMapLayer = map.get_node("GameTilemap/grass")
	for cell in water.get_used_cells():
		grid[_world_cell(water, cell, props)] = "~"
	for cell in grass.get_used_cells():
		grid[_world_cell(grass, cell, props)] = "."
	for entry in props.placed:
		var symbol := _symbol_for(entry["kind"])
		var base: Vector2i = entry["cell"]
		var size: Vector2i = entry["size"]
		for dx in range(size.x):
			for dy in range(size.y):
				grid[base + Vector2i(dx, dy)] = symbol

	var plot_origin := props.to_local(plot.global_position)
	var plot_cell := Vector2i(floori(plot_origin.x / 16.0), floori(plot_origin.y / 16.0))
	for x in range(plot.columns):
		for y in range(plot.rows):
			grid[plot_cell + Vector2i(x, y)] = "#"

	if mark_reserved:
		var spawn := Vector2i(floori(props.to_local(player.global_position).x / 16.0),
			floori(props.to_local(player.global_position).y / 16.0))
		for dx in range(-props.spawn_clear_cells, props.spawn_clear_cells + 1):
			for dy in range(-props.spawn_clear_cells, props.spawn_clear_cells + 1):
				if not grid.has(spawn + Vector2i(dx, dy)) or grid[spawn + Vector2i(dx, dy)] == ".":
					grid[spawn + Vector2i(dx, dy)] = " "
		grid[spawn] = "@"

	var cells: Array = grid.keys()
	var min_x := 99999
	var max_x := -99999
	var min_y := 99999
	var max_y := -99999
	for cell in cells:
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)

	print("[mapdump] cells x %d..%d  y %d..%d  (%dx%d)" % [
		min_x, max_x, min_y, max_y, max_x - min_x + 1, max_y - min_y + 1])
	print("[mapdump] header = column x coordinate / 10 (mod 10)")
	var header := ""
	for x in range(min_x, max_x + 1):
		header += str(posmod(x, 10)) if posmod(x, 10) == 0 else "."
	print("[mapdump] " + header)
	for y in range(min_y, max_y + 1):
		var line := ""
		for x in range(min_x, max_x + 1):
			line += grid.get(Vector2i(x, y), "?")
		print("[mapdump] %s|%d" % [line, y])
	print("[mapdump] done")


## TileMapLayer 的 used_cells 是图层自己的坐标;要换成 props 节点空间里的格坐标
func _world_cell(layer: TileMapLayer, cell: Vector2i, reference: Node2D) -> Vector2i:
	var local: Vector2 = layer.to_global(layer.map_to_local(cell)) - reference.global_position
	return Vector2i(floori(local.x / 16.0), floori(local.y / 16.0))


func _symbol_for(kind: String) -> String:
	match kind:
		"tree":
			return "T"
		"rock":
			return "O"
		"wood":
			return "="
	return ","
