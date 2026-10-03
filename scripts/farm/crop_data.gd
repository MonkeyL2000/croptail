class_name CropData
extends Resource

## 一种作物的定义。
##
## 生长用 growth(浇水天数计)表示,显示的阶段 = growth / days_per_stage,封顶到最后一格。
## 阶段图来自 Basic_Plants.png 的 16x16 格子,坐标见 docs/DECISIONS.md#plant-cells。

const CELL_SIZE := 16

@export var id: String = ""
@export var display_name: String = ""
@export var seed_cost: int = 5
@export var sell_price: int = 12
## 每个生长阶段需要「浇过水的天数」
@export var days_per_stage: int = 1
@export var stage_cells: Array[Vector2i] = []
@export var texture_path: String = "res://game_source/Objects/Basic_Plants.png"


func stage_count() -> int:
	return stage_cells.size()


## 完全成熟所需的总 growth
func growth_to_mature() -> int:
	return stage_count() * days_per_stage


func region_for_stage(stage: int) -> Rect2:
	if stage_cells.is_empty():
		return Rect2(0, 0, CELL_SIZE, CELL_SIZE)
	var index := clampi(stage, 0, stage_cells.size() - 1)
	var cell := stage_cells[index]
	return Rect2(cell.x * CELL_SIZE, cell.y * CELL_SIZE, CELL_SIZE, CELL_SIZE)
