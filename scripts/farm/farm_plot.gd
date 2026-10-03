class_name FarmPlot
extends Node2D

## 一块农田:columns x rows 个 FarmCell,自己是网格的左上角原点。
## 所有「用工具」的规则都集中在 use_tool(),方便单测,也避免规则散在状态里。

const CELL_SIZE := 16

@export var columns: int = 12
@export var rows: int = 7
## 是否开局就把所有格子锄好(调试用)
@export var pre_tilled: bool = false

var cells: Dictionary = {}


func _ready() -> void:
	build()


func build() -> void:
	if not cells.is_empty():
		return
	for row in rows:
		for column in columns:
			var grid_pos := Vector2i(column, row)
			var cell := FarmCell.new()
			cell.name = "Cell_%d_%d" % [column, row]
			cell.position = Vector2(grid_pos * CELL_SIZE)
			add_child(cell)
			cell.configure(grid_pos)
			if pre_tilled:
				cell.till()
			cells[grid_pos] = cell


func has_cell(cell: Vector2i) -> bool:
	return cells.has(cell)


func get_cell(cell: Vector2i) -> FarmCell:
	return cells.get(cell)


## 世界坐标 → 格子坐标(允许越界,越界时 use_tool 会返回空串)
func world_to_cell(world_position: Vector2) -> Vector2i:
	var local := to_local(world_position)
	return Vector2i(floori(local.x / CELL_SIZE), floori(local.y / CELL_SIZE))


func cell_center(cell: Vector2i) -> Vector2:
	return to_global(Vector2(cell.x * CELL_SIZE + CELL_SIZE * 0.5, cell.y * CELL_SIZE + CELL_SIZE * 0.5))


## 用某个工具作用于一格。返回一句给玩家看的结果(空串 = 这格不归我管)。
## 这是玩法规则唯一的入口 —— HUD 提示、单测都走这里。
func use_tool(tool_id: int, cell: Vector2i, crop_id: String) -> String:
	var target: FarmCell = cells.get(cell)
	if target == null:
		return ""

	match tool_id:
		GameState.Tool.HOE:
			if target.till():
				return "Tilled the soil."
			return "Already tilled."

		GameState.Tool.WATERING_CAN:
			if target.water():
				return "Watered."
			if not target.is_tilled():
				return "Till the soil first."
			return "Already watered today."

		GameState.Tool.SEED:
			var data := CropDB.get_crop(crop_id)
			if data == null:
				return "No seed selected."
			if not target.is_tilled():
				return "Till the soil first."
			if not target.is_empty():
				return "Something is already growing here."
			var seed_id := GameState.seed_item_id(data.id)
			if GameState.item_count(seed_id) <= 0:
				return "Out of %s seeds (press B to buy)." % data.display_name
			if target.plant(data):
				GameState.add_item(seed_id, -1)
				return "Planted %s." % data.display_name
			return "Cannot plant here."

		GameState.Tool.HAND:
			if target.is_mature():
				var result := target.harvest()
				GameState.add_item(String(result["item"]), 1)
				GameState.add_coins(int(result["sell_price"]))
				return "Harvested %s (+%d coins)." % [String(result["item"]), int(result["sell_price"])]
			if not target.is_empty():
				return "Not ready yet."
			return "Nothing to harvest."

	return ""


## 天数推进时由 main.gd 调用
func advance_day() -> void:
	for cell in cells.values():
		(cell as FarmCell).advance_day()


func count_tilled() -> int:
	var total := 0
	for cell in cells.values():
		if (cell as FarmCell).is_tilled():
			total += 1
	return total


func count_mature() -> int:
	var total := 0
	for cell in cells.values():
		if (cell as FarmCell).is_mature():
			total += 1
	return total


func first_mature_cell() -> Vector2i:
	for key in cells:
		if (cells[key] as FarmCell).is_mature():
			return key
	return Vector2i(-1, -1)
