class_name CropDB
extends RefCounted

## 作物表。
##
## 用代码建 Resource(不写 .tres):字段少、要反复调平衡,手写资源文件反而难维护。
## 格子坐标来自对 Basic_Plants.png 的逐格分析(见 docs/DECISIONS.md#plant-cells):
##   第 0 行 = 由绿转黄的作物 → wheat;第 1 行 = 常绿叶菜 → greens。
##   每行第 1..4 列 = 由小到大的 4 个生长阶段;第 0 列是土堆、第 5 列是石头,不使用。

const IDS: Array[String] = ["wheat", "greens"]

static var _crops: Dictionary = {}


static func _ensure_built() -> void:
	if not _crops.is_empty():
		return

	var wheat_stages: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)
	]
	var wheat := CropData.new()
	wheat.id = "wheat"
	wheat.display_name = "Wheat"
	wheat.seed_cost = 5
	wheat.sell_price = 16
	wheat.days_per_stage = 1
	wheat.stage_cells = wheat_stages

	var green_stages: Array[Vector2i] = [
		Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)
	]
	var greens := CropData.new()
	greens.id = "greens"
	greens.display_name = "Greens"
	greens.seed_cost = 3
	greens.sell_price = 9
	greens.days_per_stage = 1
	greens.stage_cells = green_stages

	_crops[wheat.id] = wheat
	_crops[greens.id] = greens


static func get_crop(crop_id: String) -> CropData:
	_ensure_built()
	return _crops.get(crop_id)


static func all_ids() -> Array[String]:
	_ensure_built()
	return IDS
