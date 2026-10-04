extends Node2D

## 农场小路:用 `Objects/Paths.png` 里的横条/竖条拼出来的土黄色小径。
##
## ## 为什么不建 TileMapLayer
##
## 那张图里的路**不是按 16x16 格子画的**:横条 3 像素高、宽度有 5/8/9/10/11 五种,
## 竖条 3 像素宽、长度 5~11;它们在图集里的位置也不是格子对齐的(全部 28 块见
## `python tools/sprite_inventory.py paths`)。硬按格子切,一条路会变成一串
## 互不相连的碎片。
##
## 所以这里当**贴花**用:每条路是一段折线,沿折线把横条(竖条)首尾接起来 ——
## 接口处让最后一块**贴住终点**,和前一块重叠几个像素。同一颜色、同样高度的
## 细条,重叠看不出来,而留缝一眼就是断的。
##
## ## 和别的东西的关系
##
## - 画在**草皮之上、农田和道具之下**:`farm_map.tscn` 里的顺序就是
##   `GameTilemap(water -> grass -> Nature -> Path) -> FarmPlot -> Props`。
## - 路占的格子会**从撒树的候选里排除**(`FarmProps` 建图前问 `cells()`),
##   不然树会长在路中间。
## - 不生成任何碰撞体:路是地上的花纹,不该挡人,也不该挡道具。
## - **不动地形**:路只是画上去的贴花,水塘、草坪那一套完全没变
##   (所以也不需要在改完之后重跑 retile)。

const CELL := 16
const SHEET := "res://game_source/Objects/Paths.png"
## 图集里最长的那根横条(11x3)和竖条(3x11):长一点接缝少一点。
const PIECE_H := Rect2(3, 20, 11, 3)
const PIECE_V := Rect2(36, 50, 3, 11)
## 每一段的两头各往外多画几个像素:拐角处两条的端头互相补上,不留缺口。
## 4 像素只有四分之一格,不会戳到隔壁格上去。
const EXTEND := 4.0

## 路线:每一项是一段(起点格, 终点格),只能是横的或竖的。
##
## 特意走「农田南边那条街」(第 15 行):玩家出生点就在 (25,15),一出场脚底下
## 就是路;往东到牧场西边留的那个口(进牧场),往西拐一下到池塘边,
## 中间往北岔一条进鸡圈。格子坐标和 `FarmProps` 是同一套(见 #cell-offsets)。
const RUNS := [
	{"from": Vector2i(4, 15), "to": Vector2i(32, 15)},
	{"from": Vector2i(4, 15), "to": Vector2i(4, 12)},
	{"from": Vector2i(4, 12), "to": Vector2i(2, 12)},
	{"from": Vector2i(32, 15), "to": Vector2i(32, 7)},
	{"from": Vector2i(32, 7), "to": Vector2i(34, 7)},
	{"from": Vector2i(32, 15), "to": Vector2i(35, 15)},
]

var _cells := {}
var _sheets := {}


func _ready() -> void:
	_build()


## 路占了哪些格(格坐标,和 `farm_props.gd` 同一套)。
func cells() -> Array:
	return _cells.keys()


## 路一共铺了多少块料(自检用:能发现「一段路一块都没铺」)。
func piece_count() -> int:
	return get_child_count()


func _build() -> void:
	for run in RUNS:
		var a: Vector2i = run["from"]
		var b: Vector2i = run["to"]
		if a.y == b.y:
			_run_h(mini(a.x, b.x), maxi(a.x, b.x), a.y)
		elif a.x == b.x:
			_run_v(a.x, mini(a.y, b.y), maxi(a.y, b.y))
		else:
			push_error("FarmPath: 这一段既不是横的也不是竖的: %s -> %s" % [a, b])


## 横着的一段:从格 x0 的中心画到格 x1 的中心。
func _run_h(x0: int, x1: int, y: int) -> void:
	var start := x0 * CELL + CELL * 0.5 - EXTEND
	var end := x1 * CELL + CELL * 0.5 + EXTEND
	var top := y * CELL + _center_inset(PIECE_H.size.y)
	var x := start
	while x + PIECE_H.size.x <= end:
		_add_piece(PIECE_H, Vector2(x, top))
		x += PIECE_H.size.x
	if x < end:
		_add_piece(PIECE_H, Vector2(end - PIECE_H.size.x, top))
	for cx in range(x0, x1 + 1):
		_cells[Vector2i(cx, y)] = true


## 竖着的一段:从格 y0 的中心画到格 y1 的中心。
func _run_v(x: int, y0: int, y1: int) -> void:
	var start := y0 * CELL + CELL * 0.5 - EXTEND
	var end := y1 * CELL + CELL * 0.5 + EXTEND
	var left := x * CELL + _center_inset(PIECE_V.size.x)
	var y := start
	while y + PIECE_V.size.y <= end:
		_add_piece(PIECE_V, Vector2(left, y))
		y += PIECE_V.size.y
	if y < end:
		_add_piece(PIECE_V, Vector2(left, end - PIECE_V.size.y))
	for cy in range(y0, y1 + 1):
		_cells[Vector2i(x, cy)] = true


## 3 像素宽的条要摆在格子正中:16-3=13,一半是 6.5 —— 取整到 7,
## 这样它盖住格子的第 7/8/9 行,四舍五入之后依然是正中对齐的,
## 而且坐标是整数(小数坐标会让像素画糊掉)。
func _center_inset(piece: float) -> int:
	return int((CELL - piece) * 0.5 + 0.5)


func _add_piece(region: Rect2, at: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = _piece_texture(region)
	sprite.position = at
	add_child(sprite)


func _piece_texture(region: Rect2) -> AtlasTexture:
	if not _sheets.has("path"):
		_sheets["path"] = load(SHEET) as Texture2D
	if not _sheets.has(region):
		var atlas := AtlasTexture.new()
		atlas.atlas = _sheets["path"]
		atlas.region = region
		_sheets[region] = atlas
	return _sheets[region]
