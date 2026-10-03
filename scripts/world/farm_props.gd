class_name FarmProps
extends Node2D

## 往草地上撒装饰物(树 / 石头 / 木头 / 灌木花丛),并给会挡路的东西上碰撞体。
##
## 三件事各自的办法:
##
## 1. **撒在哪** —— 用格子决定,不用世界像素。父节点 FarmMap 的 water / grass 两个
##    TileMapLayer 的 `get_used_cells()` 是「哪是水、哪是草」的权威答案;
##    排除农田和玩家出生点周围的通道后,用 `placement_seed` 决定的 RNG 逐格掷骰子。
##    同一个 seed 每次生成的森林完全一样 —— 出问题能复现,自检也能断言。
##
## 2. **碰撞体** —— 从贴图的 alpha 通道现场量。先按行算出每行的不透明跨度,
##    再把「跨度相同」的相邻行并成一个个矩形。一棵 24x30 的树会得到 5~7 个矩形,
##    拼出来就是树干和树冠的真实轮廓。见 docs/DECISIONS.md#prop-collision。
##
## 3. **遮挡** —— 绘制层开 y_sort,玩家走到树后面会被树冠盖住下半身。

const CELL_SIZE := 16
## 把相邻行并成一个碰撞矩形时允许的跨度差(像素)。太小 => 一堆碎片碰撞体,
## 太大 => 把树叶的缝隙糊成实心。1px 是实测手感最好的值。
const COLLISION_MERGE_TOLERANCE := 1
## 小于这个宽度(像素)的行不生成碰撞矩形:树冠边缘那 1px 的尖角没必要挡人
const COLLISION_MIN_WIDTH := 2

@export var map_path: NodePath = ^".."
@export var plot_path: NodePath = ^"../FarmPlot"
var plot: FarmPlot
var player: Node2D

## 撒点的随机种子。固定值 => 每次进游戏森林长得一模一样。
@export var placement_seed: int = 20261003
## 每种「占一格的使用权」有多大比例长出对应种类(加起来别超过 1)
@export_range(0.0, 1.0) var tree_share: float = 0.075
@export_range(0.0, 1.0) var rock_share: float = 0.03
@export_range(0.0, 1.0) var wood_share: float = 0.018
@export_range(0.0, 1.0) var deco_share: float = 0.14
## 玩家出生点周围干净的半径(格)
@export var spawn_clear_cells: int = 3
## 农田外围留空的格数
@export var plot_margin: int = 1

var placed: Array[Dictionary] = []
## 已被占用的格 -> true。占地看的是**包围盒**(一棵树 2x2 格),
## 不是树干的像素形状:视觉上重叠的树会很难看,宁可多留空。
var blocked: Dictionary = {}
## 所有草地格(含被占的)。生成时填好,给 BFS / 自检查询用。
var grass_cells: Dictionary = {}
## 真正挡路的格子(只算实心物件)。灌木花丛虽然也占 `blocked`,但玩家可以踩过去,
## 所以连通性判断必须用它而不是 `blocked`,否则会把能走通的路误判成死角。
var solid_cells: Dictionary = {}

var _rng: RandomNumberGenerator
var _root: Node2D
## 物件名 -> 已算好的碰撞矩形数组。同一棵树会出现几十次,算一次就够。
var _collision_cache: Dictionary = {}
## 图集路径 -> 贴图 / Image
var _texture_cache: Dictionary = {}
var _image_cache: Dictionary = {}


func _ready() -> void:
	plot = get_node_or_null(plot_path) as FarmPlot
	rebuild()


## 清掉上一次撒的东西重新撒一遍,种子相同 => 结果完全相同。
##
## 为什么需要这一步:主场景里玩家是后接上来的(它不由 FarmMap 拥有),
## 而「出生点周围要空开」必须知道玩家在哪。所以这里允许被调两次 ——
## 见 docs/DECISIONS.md#props-rebuild。
func rebuild() -> void:
	if _root != null and is_instance_valid(_root):
		remove_child(_root)
		_root.queue_free()
	_root = null
	placed.clear()
	blocked.clear()
	solid_cells.clear()
	grass_cells.clear()
	_generate()


func _generate() -> void:
	var map := get_node_or_null(map_path)
	if map == null:
		push_warning("FarmProps: 找不到 FarmMap")
		return
	var water: TileMapLayer = map.get_node_or_null("GameTilemap/water")
	var grass: TileMapLayer = map.get_node_or_null("GameTilemap/grass")
	if water == null or grass == null:
		push_warning("FarmProps: FarmMap 里没有 water / grass 层")
		return

	# 统一到本节点自己的坐标空间:本节点挂在 FarmMap 下面,位置可能不为零
	var origin := global_position
	grass_cells = _layer_cells(grass, origin)

	var reserved := {}
	if player != null:
		var spawn := _to_cell(player.global_position - origin)
		for dx in range(-spawn_clear_cells, spawn_clear_cells + 1):
			for dy in range(-spawn_clear_cells, spawn_clear_cells + 1):
				reserved[spawn + Vector2i(dx, dy)] = true
	if plot != null:
		var plot_origin := _to_cell(plot.global_position - origin)
		for x in range(-plot_margin, plot.columns + plot_margin):
			for y in range(-plot_margin, plot.rows + plot_margin):
				reserved[plot_origin + Vector2i(x, y)] = true

	var candidates: Array[Vector2i] = []
	for cell in grass_cells:
		if reserved.has(cell):
			continue
		candidates.append(cell)
	candidates.sort_custom(_cell_sort)

	_rng = RandomNumberGenerator.new()
	_rng.seed = placement_seed

	_root = Node2D.new()
	_root.name = "Props"
	# 按 y 排序绘制:玩家走到树冠后面时会被树冠盖住下半身
	_root.y_sort_enabled = true
	add_child(_root)

	_place_all(candidates)

	var counts := []
	for kind in PropDB.KINDS:
		counts.append("%d %s" % [count_kind(kind), kind])
	print("[farm_props] %d props (%s) on %d open cells; %d collision boxes" % [
		placed.size(), " / ".join(counts), candidates.size(), _collision_count()
	])


## 把 TileMapLayer 的 used_cells 换算成本节点坐标空间里的格坐标。
## 注意不能直接用 map_to_local() 的返回值:那是 layer 自己坐标系里的像素,
## 而 layer 有 position 偏移(grass 是 (-8,-5)),必须先 to_global()。
func _layer_cells(layer: TileMapLayer, origin: Vector2) -> Dictionary:
	var out := {}
	for cell in layer.get_used_cells():
		var local: Vector2 = layer.to_global(layer.map_to_local(cell)) - origin
		out[_to_cell(local)] = true
	return out


static func _cell_sort(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


func _place_all(candidates: Array[Vector2i]) -> void:
	for cell in candidates:
		if blocked.has(cell):
			continue
		var kind := _roll_kind()
		if kind == "":
			continue
		_place(kind, cell, candidates)


## 掷骰子决定这一格长什么。区间是首尾相接的,所以总概率 = 四项之和,
## 剩下的比例就是「这一格空着」—— 森林才不会密不透风。
func _roll_kind() -> String:
	var roll := _rng.randf()
	var edge := tree_share
	if roll < edge:
		return "tree"
	edge += rock_share
	if roll < edge:
		return "rock"
	edge += wood_share
	if roll < edge:
		return "wood"
	edge += deco_share
	if roll < edge:
		return "deco"
	return ""


func _place(kind: String, cell: Vector2i, candidates: Array[Vector2i]) -> void:
	var options := PropDB.names_of_kind(kind)
	if options.is_empty():
		return
	var prop_name: String = options[_rng.randi_range(0, options.size() - 1)]
	var size := PropDB.footprint(prop_name)

	# 占地是包围盒:2x2 的树需要右边和下边都空着
	for dx in range(size.x):
		for dy in range(size.y):
			var occupied := cell + Vector2i(dx, dy)
			if blocked.has(occupied) or not candidates.has(occupied):
				return

	var node := _make_node(prop_name, cell, size)
	_root.add_child(node)
	var is_solid: bool = PropDB.get_prop(prop_name)["solid"]
	for dx in range(size.x):
		for dy in range(size.y):
			blocked[cell + Vector2i(dx, dy)] = true
			if is_solid:
				solid_cells[cell + Vector2i(dx, dy)] = true
	placed.append({"kind": kind, "name": prop_name, "cell": cell, "size": size,
		"solid": PropDB.get_prop(prop_name)["solid"]})


## 造节点。
##
## 关键:节点自身的原点放在**占地包围盒的底边**上,贴图往上长到负 y。
## y-sort 用的就是节点的 y —— 放在底边,排序结果才等于「谁的脚更靠下」,
## 玩家从树下走过时才会被树冠盖住下半身。
func _make_node(prop_name: String, cell: Vector2i, size: Vector2i) -> Node2D:
	var rect: Rect2 = PropDB.get_prop(prop_name)["rect"]
	var foot := Vector2(size) * CELL_SIZE
	# 贴图不一定正好填满占地包围盒(30 高的树只占 2 格 = 32px),
	# 水平居中、底部对齐,树根才不会浮在格子上面
	var offset := Vector2((foot.x - rect.size.x) * 0.5, -rect.size.y)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.centered = false
	sprite.texture = _atlas(prop_name)
	sprite.position = offset

	var node := Node2D.new()
	node.name = "%s_%d_%d" % [prop_name, cell.x, cell.y]
	node.position = Vector2(cell) * CELL_SIZE + Vector2(0, foot.y)
	node.add_child(sprite)

	if PropDB.get_prop(prop_name)["solid"]:
		node.add_child(_make_body(prop_name, offset))
	return node


## 按 alpha 轮廓生成一组矩形碰撞体。挂回节点的名字叫 "Body"。
## offset 是贴图左上角相对节点原点(底边中心那一行的左端)的位置。
func _make_body(prop_name: String, offset: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0

	for band in _collision_bands(prop_name):
		var shape := RectangleShape2D.new()
		shape.size = band.size
		var collision := CollisionShape2D.new()
		collision.position = offset + band.position + band.size * 0.5
		collision.shape = shape
		body.add_child(collision)
	return body


## 把贴图的 alpha 轮廓压成若干矩形:逐行取不透明跨度,跨度相近的相邻行并成一条。
## 一棵 24x30 的树会得到 5~7 条 —— 刚好把树干和树冠分开,不用手填任何尺寸表。
func _collision_bands(prop_name: String) -> Array[Rect2]:
	if _collision_cache.has(prop_name):
		return _collision_cache[prop_name]

	var bands: Array[Rect2] = []
	var rect: Rect2 = PropDB.get_prop(prop_name)["rect"]
	var image := _sheet_image(PropDB.sheet_path(prop_name))
	if image != null:
		var crop := image.get_region(Rect2i(rect))
		var width := crop.get_width()
		var height := crop.get_height()
		var run: Rect2 = Rect2()
		var running := false
		for y in height:
			var span := _row_span(crop, y, width)
			var blank: bool = span.x < 0.0
			var continues: bool = running and not blank \
				and absf(span.x - run.position.x) <= COLLISION_MERGE_TOLERANCE \
				and absf(span.y - run.size.x) <= COLLISION_MERGE_TOLERANCE
			if continues:
				run.size.y += 1.0
				continue
			if running:
				bands.append(run)
				running = false
			if not blank:
				run = Rect2(span.x, float(y), span.y, 1.0)
				running = true
		if running:
			bands.append(run)

	_collision_cache[prop_name] = bands
	return bands


## 图集的原始 Image。缓存住:一张图集要服务几十个物件。
func _sheet_image(path: String) -> Image:
	if not _image_cache.has(path):
		var texture: Texture2D = _texture_cache.get(path)
		if texture == null:
			texture = load(path)
			_texture_cache[path] = texture
		_image_cache[path] = texture.get_image() if texture != null else null
	return _image_cache[path]


## 第 y 行的不透明跨度,返回 (left, width);整行透明时 left = -1。
static func _row_span(image: Image, y: int, width: int) -> Vector2:
	var left := -1
	var right := -1
	for x in width:
		if image.get_pixel(x, y).a > 0.35:
			if left < 0:
				left = x
			right = x
	if left < 0 or right - left + 1 < COLLISION_MIN_WIDTH:
		return Vector2(-1.0, 0.0)
	return Vector2(float(left), float(right - left + 1))


func _atlas(prop_name: String) -> AtlasTexture:
	var path := PropDB.sheet_path(prop_name)
	if not _texture_cache.has(path):
		_texture_cache[path] = load(path)
	var atlas := AtlasTexture.new()
	atlas.atlas = _texture_cache[path]
	atlas.region = PropDB.get_prop(prop_name)["rect"]
	return atlas


func _to_cell(local_position: Vector2) -> Vector2i:
	return Vector2i(floori(local_position.x / CELL_SIZE), floori(local_position.y / CELL_SIZE))


## 世界坐标 -> 本节点的格坐标。公开版:`_to_cell()` 收的是已减掉自身偏移的局部坐标,
## 外部调用者手里通常是 global_position,容易搞错,所以留一个不会用错的入口。
func to_local_cell(global_point: Vector2) -> Vector2i:
	return _to_cell(to_local(global_point))


## 格坐标 -> 世界坐标(格中心)。和 `to_local_cell()` 互逆:
## 把玩家/物件放到「确定是空地」的那一格时用它,比写死坐标靠谱 ——
## 道具是随机撒的,写死的落点随时会落在某棵树里。
func cell_center(cell: Vector2i) -> Vector2:
	return to_global(Vector2(cell) * CELL_SIZE + Vector2.ONE * CELL_SIZE * 0.5)


func _collision_count() -> int:
	var total := 0
	for child in _root.get_children():
		var body := child.get_node_or_null("Body")
		if body != null:
			total += body.get_child_count()
	return total


## --- 给自检用的查询 -------------------------------------------------------

## 某个格坐标是否被实心物件占着
func has_solid_at(cell: Vector2i) -> bool:
	for entry in placed:
		if not entry["solid"]:
			continue
		var base: Vector2i = entry["cell"]
		var size: Vector2i = entry["size"]
		if cell.x >= base.x and cell.x < base.x + size.x \
				and cell.y >= base.y and cell.y < base.y + size.y:
			return true
	return false


func count_kind(kind: String) -> int:
	var total := 0
	for entry in placed:
		if entry["kind"] == kind:
			total += 1
	return total


## 从 origin 出发能走到的草地格(4 邻域,BFS,把被占用格当墙)。
##
## 为什么需要它:随机撒点有可能**把一块地完全封死**(四面都是树),那样玩家
## 就在自己农场里造了个孤岛。自检拿它断言「出生点能走到农田」和
## 「绝大多数可站立格都连通」。见 docs/DECISIONS.md#props-reachability。
func reachable_from(origin: Vector2i) -> Dictionary:
	var seen := {}
	if not grass_cells.has(origin) or solid_cells.has(origin):
		return seen
	var queue: Array[Vector2i] = [origin]
	seen[origin] = true
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + step
			if seen.has(next) or solid_cells.has(next) or not grass_cells.has(next):
				continue
			seen[next] = true
			queue.append(next)
	return seen


## 玩家真正能站上去的格子数(草地 - 实心物件)
func walkable_cell_count() -> int:
	var total := 0
	for cell in grass_cells:
		if not solid_cells.has(cell):
			total += 1
	return total


## 第一个实心物件的格子坐标;没有这种物件时返回 null。
## 不用 (-1,-1) 当哨兵值 —— 地图的格坐标本来就是负的(岛从 x=-16 开始),
## 哨兵值必须能和真实坐标区分开。
func first_solid_cell(kind: String) -> Variant:
	for entry in placed:
		if entry["kind"] == kind and entry["solid"]:
			var base: Vector2i = entry["cell"]
			# 占地包围盒的底行中部才是真的实体部分(树冠顶上没碰撞)
			return base + Vector2i(entry["size"].x / 2, entry["size"].y - 1)  # 整除:取占地中间那一列
	return null
