extends Node

## 开发工具:把草地层的图块按 TileSet 的 terrain(peering)重新指派。
##
## **为什么要它**:地图形状是用脚本刷出来的,刷的时候每一格都写了同一个 atlas 坐标。
## 但「这一格该画哪一块」不是固定的 —— 草地内部要用四面都连着的整块,靠边的那一列
## 要用只有一边连着的边块,四个角又是另外四块。这套规则写在 TileSet 的 peering bits 里
## (`terrain_set_0` mode 0 = Match Corners and Sides,terrain 0 = grass)。我第一版
## 把「左上角」那一块刷满了整片草坪,于是看上去全是重复的角,边缘反倒没有边块。
##
## 这里**不自己实现 peering**,直接调引擎的 `set_cells_terrain_connect()` ——
## 引擎的表总比我手抄的 8 位掩码对。
##
## 算完把 `tile_map_data` 写进 `_retile.bin`,再用 `tools/retile_grass.py` 贴回 .tscn。
## **不能用 ResourceSaver 存整个场景** —— 场景里 `FarmProps` 一进树就生成几百个道具
## 子节点,一存就把它们烤进文件里了。
##
## 自校验:`grass_terrain_ref.tscn` 是**旧地图(263 格)的快照**,它那些坐标是原作者
## 在编辑器里用地形笔刷点出来的 —— 也就是标准答案。工具先拿它跑一遍,断言「算出来的
## 结果和存着的一模一样」。这条不过,说明方法错了,后面那张大地图的结果也不能信。

const TERRAIN_SET := 0
const TERRAIN := 0
const LAYER_PATH := "GameTilemap/grass"

const REFERENCE := "res://scenes/dev/grass_terrain_ref.tscn"
const TARGETS := ["res://scenes/world/farm_map.tscn"]
const OUT_PATTERN := "res://_retile_%d.bin"
const REPORT := "res://_retile_report.txt"

var _report: Array[String] = []


func _ready() -> void:
	var reference_ok := _verify_reference()
	for index in TARGETS.size():
		_retile(OUT_PATTERN % index, TARGETS[index])
	_report.append("REFERENCE CHECK: %s" % ("PASS" if reference_ok else "FAIL"))
	var out := FileAccess.open(REPORT, FileAccess.WRITE)
	if out != null:
		out.store_string("\n".join(_report))
		out.close()
	print("[retile] REFERENCE CHECK: %s" % ("PASS" if reference_ok else "FAIL"))
	get_tree().quit(0 if reference_ok else 1)


## 拿已知正确的那张旧地图当标准答案跑一遍
func _verify_reference() -> bool:
	var layer := _load_grass_layer(REFERENCE)
	if layer == null:
		return false
	var cells := layer.get_used_cells()
	var expected := _atlas_table(layer)
	layer.clear()
	layer.set_cells_terrain_connect(cells, TERRAIN_SET, TERRAIN, false)
	var computed := _atlas_table(layer)
	var same := expected == computed
	_report.append("reference %s: %d cells, expected %s" % [REFERENCE, cells.size(), expected])
	_report.append("reference %s: computed %s" % [REFERENCE, computed])
	_report.append("reference differences: %d" % _diff_count(expected, computed))
	layer.get_parent().free()
	return same


func _retile(out_path: String, path: String) -> void:
	var layer := _load_grass_layer(path)
	if layer == null:
		return
	var cells := layer.get_used_cells()
	_report.append("")
	_report.append("%s: %d cells" % [path, cells.size()])
	_report.append("  before: %s" % _atlas_table(layer))
	layer.clear()
	layer.set_cells_terrain_connect(cells, TERRAIN_SET, TERRAIN, false)
	_report.append("  after : %s" % _atlas_table(layer))

	var out := FileAccess.open(out_path, FileAccess.WRITE)
	if out == null:
		_report.append("  ERROR: cannot write %s" % out_path)
	else:
		out.store_buffer(layer.tile_map_data)
		out.close()
		_report.append("  wrote %d bytes to %s" % [layer.tile_map_data.size(), out_path])
	layer.get_parent().free()


func _load_grass_layer(path: String) -> TileMapLayer:
	var packed: PackedScene = load(path)
	if packed == null:
		_report.append("ERROR: cannot load %s" % path)
		return null
	var root: Node = packed.instantiate()
	var layer: TileMapLayer = root.get_node_or_null(LAYER_PATH)
	if layer == null:
		_report.append("ERROR: %s has no %s" % [path, LAYER_PATH])
		root.free()
		return null
	return layer


## {"source:ax,ay": count}
func _atlas_table(layer: TileMapLayer) -> Dictionary:
	var out := {}
	for cell in layer.get_used_cells():
		var atlas := layer.get_cell_atlas_coords(cell)
		var key := "%d:%d,%d" % [layer.get_cell_source_id(cell), atlas.x, atlas.y]
		out[key] = int(out.get(key, 0)) + 1
	return out


func _diff_count(a: Dictionary, b: Dictionary) -> int:
	var total := 0
	for key in a:
		if int(a[key]) != int(b.get(key, 0)):
			total += absi(int(a[key]) - int(b.get(key, 0)))
	for key in b:
		if not a.has(key):
			total += int(b[key])
	return total
