extends Node2D

## 地图场景(由原 sence/test/test_tilemap.tscn 改造而来)。
##
## 启动时按「水格 - 草格」自动生成 StaticBody2D 碰撞墙:
## 玩家因此走不出小岛,而且完全不用给 TileSet 刷物理层 / 手画碰撞多边形。
## 见 docs/DECISIONS.md#auto-walls

const CELL_SIZE := 16

@onready var water: TileMapLayer = $GameTilemap/water
@onready var grass: TileMapLayer = $GameTilemap/grass


func _ready() -> void:
	_build_water_walls()


## 草地的世界矩形(含草地本身在内的最小矩形)。
## 相机用它当移动范围:地图 57x34 格 = 912x544 像素,比 640x360 的视口大得多,
## 没有相机就只看得到岛的一角。
func playable_rect() -> Rect2:
	var cells := grass.get_used_cells()
	if cells.is_empty():
		return Rect2()
	var min_cell := cells[0]
	var max_cell := cells[0]
	for cell in cells:
		min_cell = Vector2i(mini(min_cell.x, cell.x), mini(min_cell.y, cell.y))
		max_cell = Vector2i(maxi(max_cell.x, cell.x), maxi(max_cell.y, cell.y))
	# map_to_local 给的是格子中心,向左上退半格才是格子外沿
	var top_left: Vector2 = grass.to_global(grass.map_to_local(min_cell)) - Vector2(CELL_SIZE, CELL_SIZE) * 0.5
	var bottom_right: Vector2 = grass.to_global(grass.map_to_local(max_cell)) + Vector2(CELL_SIZE, CELL_SIZE) * 0.5
	return Rect2(top_left, bottom_right - top_left)


## 被草地盖住的水格不算墙(玩家就站在草上),其余水格按行合并成矩形
func _build_water_walls() -> void:
	var grass_cells := {}
	for cell in grass.get_used_cells():
		grass_cells[cell] = true

	var rows := {}
	for cell in water.get_used_cells():
		if grass_cells.has(cell):
			continue
		if not rows.has(cell.y):
			rows[cell.y] = []
		rows[cell.y].append(cell.x)

	var body := StaticBody2D.new()
	body.name = "WaterWalls"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)

	var shapes := 0
	for y in rows:
		var xs: Array = rows[y]
		xs.sort()
		var run_start: int = xs[0]
		var run_end: int = xs[0]
		for i in range(1, xs.size()):
			if xs[i] == run_end + 1:
				run_end = xs[i]
				continue
			_add_wall(body, run_start, run_end, y)
			shapes += 1
			run_start = xs[i]
			run_end = xs[i]
		_add_wall(body, run_start, run_end, y)
		shapes += 1

	print("[farm_map] water walls: %d collision shapes" % shapes)


func _add_wall(body: StaticBody2D, x_start: int, x_end: int, y: int) -> void:
	var length := x_end - x_start + 1
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length * CELL_SIZE, CELL_SIZE)

	var collision := CollisionShape2D.new()
	collision.shape = rect
	# map_to_local 给的是格子中心;一排 L 格的中心要再往右挪 (L-1)/2 格
	var local_center: Vector2 = water.map_to_local(Vector2i(x_start, y)) + Vector2((length - 1) * CELL_SIZE * 0.5, 0)
	collision.position = water.to_global(local_center)
	body.add_child(collision)
