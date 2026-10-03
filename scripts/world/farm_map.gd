extends Node2D

## 地图场景(由原 sence/test/test_tilemap.tscn 改造而来)。
##
## 启动时按「水格 - 草格」自动生成 StaticBody2D 碰撞墙:
## 玩家因此走不出小岛,而且完全不用给 TileSet 刷物理层 / 手画碰撞多边形。
## 见 docs/DECISIONS.md#auto-walls

const CELL_SIZE := 16

## 十字方向的四个邻居,用来找岛的边;以及墙往外铺几格
const NEIGHBOURS := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
const WALL_THICKNESS := 4

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


## 顺着小岛的外沿生成一圈碰撞墙:玩家因此走不出草地,而且完全不用给 TileSet
## 刷物理层 / 手画碰撞多边形。见 docs/DECISIONS.md#auto-walls
##
## **不要拿「水格减草格」来算。** `water` 层挂在 (0,0)、`grass` 层挂在 (-8,-5),
## 两层的格坐标根本不是一回事(差半格)—— 用整数格坐标相减,算出来的墙会
## 整体横移一格:左边多出一堵玩家看得见草地却过不去的隐形墙,右边漏出一条
## 能走到水面上的缝。靠「把水格中心换算成世界坐标再回问草地层」也能算对,
## 但那仍然是在借水层的网格去描述岛的形状。
##
## 现在只用草地层:对每一格草,看四个邻居里哪些不是草,就在**那个邻居格**上
## 记一笔墙 —— 墙铺在草地外面,玩家才能一直走到岸边。同一行的墙合并成长条。
func _build_water_walls() -> void:
	var grass_cells := {}
	for cell in grass.get_used_cells():
		grass_cells[cell] = true

	var rows := {}
	for cell in grass.get_used_cells():
		for step in NEIGHBOURS:
			if grass_cells.has(cell + step):
				continue
			# 往外铺几格:万一以后有东西把玩家丢到离岛的地方,他也不至于在水面上跑
			for distance in range(1, WALL_THICKNESS + 1):
				var target: Vector2i = cell + step * distance
				if grass_cells.has(target):
					break
				if not rows.has(target.y):
					rows[target.y] = {}
				rows[target.y][target.x] = true

	var body := StaticBody2D.new()
	body.name = "WaterWalls"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)

	var shapes := 0
	for y in rows:
		var xs: Array = rows[y].keys()
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
	# map_to_local 给的是格子中心;一排 L 格的中心要再往右挪 (L-1)/2 格。
	# 位置按**草地层**算:墙的位置就是岛的边,草格才是它的原生网格。
	var local_center: Vector2 = grass.map_to_local(Vector2i(x_start, y)) + Vector2((length - 1) * CELL_SIZE * 0.5, 0)
	collision.position = grass.to_global(local_center)
	body.add_child(collision)
