extends Node

## autoload: GameState —— 全局玩法状态(工具选择 / 金币 / 物品栏)。
## 纯逻辑,不碰节点树,方便单测(见 scripts/dev/selftest.gd)。
##
## 文案一律 ASCII:Godot 默认字体不含 CJK 字形,中文会渲染成方块。

## 顺序就是工具条上的顺序,也就是键盘 1..6(见 player.gd 的 tool_slot_N)。
## AXE / PICKAXE 排在最后:1..4 是原来就有的四个键位,加了斧镐也不动它们。
enum Tool { HOE, WATERING_CAN, SEED, HAND, AXE, PICKAXE }

const TOOL_ORDER: Array[int] = [
	Tool.HOE, Tool.WATERING_CAN, Tool.SEED, Tool.HAND, Tool.AXE, Tool.PICKAXE,
]

const TOOL_LABELS := {
	Tool.HOE: "Hoe",
	Tool.WATERING_CAN: "Watering Can",
	Tool.SEED: "Seeds",
	Tool.HAND: "Harvest",
	Tool.AXE: "Axe",
	Tool.PICKAXE: "Pickaxe",
}

## 砍树/挖石得到的材料。HUD 右下角的「材料」面板按这张表的顺序铺格子。
## 见 scripts/ui/hud.gd 的 _build_materials()。
const MATERIAL_ORDER: Array[String] = ["wood", "stone"]
const MATERIAL_LABELS := {"wood": "Wood", "stone": "Stone"}

## 初始种子:每种作物给几颗,让开局立刻能种
const STARTING_SEEDS := {"wheat": 4, "greens": 4}
const STARTING_COINS := 10

signal tool_changed(tool_id: int)
signal inventory_changed()
signal coins_changed(coins: int)
## 选中的作物变了。和 inventory_changed 分开:背包刷新关心数量,
## 而 HUD 的「收获图标」只关心当前是哪一种作物。
signal crop_changed(crop_id: String)

var current_tool: int = Tool.HOE
var selected_crop: String = "wheat"
var coins: int = STARTING_COINS
var inventory: Dictionary = {}


func _ready() -> void:
	for crop_id in STARTING_SEEDS:
		inventory[seed_item_id(crop_id)] = STARTING_SEEDS[crop_id]


## 「种子」在物品栏里的 id。作物本身的 id 用于收获物,两者分开以免混淆。
## 故意不是 static:GameState 是 autoload 实例,从实例上调用 static 函数引擎会报错。
func seed_item_id(crop_id: String) -> String:
	return "seed_" + crop_id


func tool_label() -> String:
	return TOOL_LABELS.get(current_tool, "?")


func material_label(item_id: String) -> String:
	return MATERIAL_LABELS.get(item_id, item_id)


## 这个工具是「对地面上的物件动手」的那一类(斧/镐),而不是对农田格子动手。
## player.gd 靠它决定把动作交给 FarmProps 还是 FarmPlot。
func tool_works_on_props(tool_id: int) -> bool:
	return tool_id == Tool.AXE or tool_id == Tool.PICKAXE


func select_tool(tool_id: int) -> void:
	if tool_id == current_tool:
		return
	current_tool = tool_id
	tool_changed.emit(current_tool)


## 在工具条上循环移动(step 为 +1 / -1)
func cycle_tool(step: int) -> void:
	var count := TOOL_ORDER.size()
	var index := TOOL_ORDER.find(current_tool)
	if index < 0:
		index = 0
	select_tool(TOOL_ORDER[(index + step + count) % count])


func select_crop(crop_id: String) -> void:
	if selected_crop == crop_id:
		return
	selected_crop = crop_id
	crop_changed.emit(selected_crop)
	inventory_changed.emit()


func cycle_crop(step: int) -> void:
	var ids := CropDB.all_ids()
	if ids.is_empty():
		return
	var index := ids.find(selected_crop)
	if index < 0:
		index = 0
	select_crop(ids[(index + step + ids.size()) % ids.size()])


func item_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))


func add_item(item_id: String, amount: int = 1) -> void:
	var total := item_count(item_id) + amount
	inventory[item_id] = maxi(total, 0)
	inventory_changed.emit()


func add_coins(amount: int) -> void:
	coins = maxi(coins + amount, 0)
	coins_changed.emit(coins)
