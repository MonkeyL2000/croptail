extends CanvasLayer

## HUD:天数 / 金币 / 当前工具 / 各种子数量 / 临时提示。
## 文案全 ASCII —— Godot 默认字体没有 CJK 字形(见 docs/DECISIONS.md#ascii-ui)。

const MESSAGE_TIME := 3.0

@onready var day_label: Label = $DayLabel
@onready var coins_label: Label = $CoinsLabel
@onready var tool_label: Label = $ToolLabel
@onready var seed_label: Label = $SeedLabel
@onready var message_label: Label = $MessageLabel

var _message_left: float = 0.0


func _ready() -> void:
	GameState.tool_changed.connect(_on_tool_changed)
	GameState.inventory_changed.connect(_on_inventory_changed)
	GameState.coins_changed.connect(_on_coins_changed)
	TimeManager.day_changed.connect(_on_day_changed)
	message_label.text = ""
	_refresh()


func _process(delta: float) -> void:
	if _message_left <= 0.0:
		return
	_message_left -= delta
	# 天数百分比每帧都在变,顺手刷新
	_refresh_day()
	if _message_left <= 0.0:
		message_label.text = ""


func show_message(text: String) -> void:
	if text == "":
		return
	message_label.text = text
	_message_left = MESSAGE_TIME


func _on_tool_changed(_tool_id: int) -> void:
	_refresh()


func _on_inventory_changed() -> void:
	_refresh()


func _on_coins_changed(_coins: int) -> void:
	_refresh()


func _on_day_changed(_day: int) -> void:
	_refresh()


func _refresh() -> void:
	_refresh_day()
	coins_label.text = "Coins: %d" % GameState.coins
	tool_label.text = "Tool: %s" % GameState.tool_label()

	var parts: Array[String] = []
	for crop_id in CropDB.all_ids():
		var data := CropDB.get_crop(crop_id)
		var marker := ">" if crop_id == GameState.selected_crop else " "
		parts.append("%s%s x%d(seed %dc)" % [
			marker, data.display_name, GameState.item_count(GameState.seed_item_id(crop_id)), data.seed_cost
		])
	seed_label.text = "Seeds: " + "  ".join(parts)


func _refresh_day() -> void:
	day_label.text = "Day %d  (%d%%)" % [TimeManager.day, roundi(TimeManager.day_fraction() * 100.0)]
