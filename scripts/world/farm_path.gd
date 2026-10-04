extends TileMapLayer

## 农场小路:把 `Tilesets/Tilled_Dirt_Wide.png` 那张图里的 **dirt 地形**
## (`tile_set` 里 terrain_set 0 / terrain 1)沿一条折线铺成一格一格的地面。
##
## ## 为什么改掉原来的「贴花」写法(2026-10-05)
##
## 第一版是用 `Objects/Paths.png` 里 3 像素宽的土黄细条沿折线首尾拼出来的贴花:
## 几何上没错(自检也过),但画面上就是**一条细线**,不像「一条路」。
## 用户一眼就看出不对:「小路生成有问题,它应该也有 tile」。
##
## 确实 —— 项目里的 TileSet(`tilesets/test_tilemap.tres`)本来就带着
## `terrain_1 = "dirt"`(dirt 地形,外加一圈带草边的过渡块,由 Tilled_Dirt_Wide.png
## 提供),只是一直没人用。改成 TileMapLayer 之后:
##   - 路是**一格一块 tile**,和草地、水面一样是地形,不再是飘在上面的贴花;
##   - 拐角、端口、草边交给 TileSet 自己接(`set_cells_terrain_connect`),
##     不用手算像素、不会漏缝;
##   - 可以直接在编辑器里用 terrain 笔刷接着画。
##
## ## 和别的东西的关系
##
## - 画在**草皮之上、农田和道具之下**:`farm_map.tscn` 里的顺序是
##   `water -> grass -> Nature -> Path`,然后才是 `FarmPlot` 和 `Props`。
## - 路占的格子会**从撒树的候选里排除**(`FarmProps` 建图前问 `cells()`),
##   不然树会长在路中间。
## - 不生成碰撞体:路是地面,不该挡人,也不该挡道具。
## - **不动地形**:草地层一个字节都没改,小路的格子仍然算「草地」
##   (所以也不需要重跑 retile)。

## TileMapLayer 的格和本项目的「道具格」是同一套坐标:layer 不设 position 偏移,
## 格 (cx,cy) 就画在 (cx*16, cy*16),和 `FarmProps` 的换算对得上(见 #cell-offsets)。
const CELL := 16
## TileSet 里的地形编号:见 `tilesets/test_tilemap.tres` 的
## `terrain_set_0/terrain_1/name = "dirt"`。
const TERRAIN_SET := 0
const DIRT_TERRAIN := 1

## 路线:每一项是一段(起点格, 终点格),只能是横的或竖的。
##
## 特意走「农田南边那条街」(第 15 行):玩家出生点就在 (25,15),一出场脚底下
## 就是路;往东到牧场西边留的那个口(进牧场),往西拐一下到池塘边,
## 中间往北岔一条进鸡圈。格子坐标和 `FarmProps` 是同一套。
const RUNS := [
	{"from": Vector2i(4, 15), "to": Vector2i(32, 15)},
	{"from": Vector2i(4, 15), "to": Vector2i(4, 12)},
	{"from": Vector2i(4, 12), "to": Vector2i(2, 12)},
	{"from": Vector2i(32, 15), "to": Vector2i(32, 7)},
	{"from": Vector2i(32, 7), "to": Vector2i(34, 7)},
	{"from": Vector2i(32, 15), "to": Vector2i(35, 15)},
]

var _cells := {}


func _ready() -> void:
	_build()


## 路占了哪些格(格坐标,和 `farm_props.gd` 同一套)。
func cells() -> Array:
	return _cells.keys()


## 路一共铺了多少块 tile(自检用:能发现「一段路一块都没铺」)。
func piece_count() -> int:
	return get_used_cells().size()


func _build() -> void:
	var route := _route_cells()
	if route.is_empty():
		return
	for cell in route:
		_cells[cell] = true
	set_cells_terrain_connect(route, TERRAIN_SET, DIRT_TERRAIN)


## 折线 -> 格子列表(去重)。铺 tile 和 `cells()` 用的是同一份数据。
func _route_cells() -> Array[Vector2i]:
	var seen := {}
	var out: Array[Vector2i] = []
	for run in RUNS:
		var a: Vector2i = run["from"]
		var b: Vector2i = run["to"]
		if a.y == b.y:
			for cx in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
				_append_cell(out, seen, Vector2i(cx, a.y))
		elif a.x == b.x:
			for cy in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
				_append_cell(out, seen, Vector2i(a.x, cy))
		else:
			push_error("FarmPath: 这一段既不是横的也不是竖的: %s -> %s" % [a, b])
	return out


func _append_cell(out: Array[Vector2i], seen: Dictionary, cell: Vector2i) -> void:
	if seen.has(cell):
		return
	seen[cell] = true
	out.append(cell)
