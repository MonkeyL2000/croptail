class_name ToolIcons
extends RefCounted

## 工具 / 种子 / 收获物 / 硬币的图标。
##
## ## 素材:Tools.png 不是「6 种工具」,是「3 种工具 x 6 个朝向」
##
## `Characters/Tools.png` 是 96x96 = 6x6 格、每格 16x16,**36 格全有内容**。
## 用连通域 + 调色板把它读出来(同款做法见 `tools/extract_props.py`):
##
##   - 行 0/1 = 工具 A,行 2/3 = 工具 B,行 4/5 = 工具 C。
##     同一行的 6 格是**同一个工具的 6 个绘制朝向**(不是 6 把工具)。
##   - 每组下面那一行是「正在使用」状态:多出几撮紫色 + 米白的像素。
##   - 三组靠调色板区分得清清楚楚:
##       工具 A = 纯金属灰,一丝木色都没有
##                (84,89,89) (107,116,112) (129,139,131) (157,168,154)
##       工具 B / C = 金属 + 木柄
##                (129,129,129) (183,183,183) + (144,98,93) (170,121,89)
##
## **这就是之前那个 bug 的根**:以前的图标表全从行 2/3 挑,于是 4 个工具里
## 有 3 个画的是同一把工具的不同朝向 —— 看起来就像「全都用同一种素材」。
## 现在一个工具取一组,三张图各不同;第 4 个(收获)干脆取**成熟作物的贴图**,
## 语义上正好是「你要收的东西」,而且一定和前三张不像。
##
## 哪组是锄头、哪组是洒水壶没有官方图例,按「纯金属那组 = 洒水壶」定。
## 想换只改下面这张 ICONS 表。

const SHEET := "res://game_source/Characters/Tools.png"
const PLANTS_SHEET := "res://game_source/Objects/Basic_Plants.png"
const CELL := 16

## 图标 id -> {"sheet": 图集路径, "rect": 源图集里的像素矩形}
const ICONS := {
	# 工具 A(纯金属那组)第 0 行第 0 格 —— 洒水壶
	"watering_can": {"sheet": SHEET, "rect": Rect2(0, 0, 16, 16)},
	# 工具 B(金属 + 木柄)第 0 行第 0 格 —— 锄头
	"hoe": {"sheet": SHEET, "rect": Rect2(0, 32, 16, 16)},
	# 工具 C 第 0 行第 0 格 —— 当种子袋
	"seed_bag": {"sheet": SHEET, "rect": Rect2(0, 64, 16, 16)},
	# 硬币:同一个图集里的圆片
	"coin": {"sheet": SHEET, "rect": Rect2(0, 80, 16, 16)},
}

## 收获物图标 = 该作物最后一个生长阶段的贴图(Basic_Plants.png 的第 4 列)
## 行:0 = wheat,1 = greens —— 和 CropDB 里的 stage_cells 同源
const HARVEST_ROW := {"wheat": 0, "greens": 1}
const HARVEST_COLUMN := 4


static func icon_rect(id: String) -> Rect2:
	var entry: Dictionary = ICONS.get(id, {})
	if entry.is_empty():
		push_warning("ToolIcons: 未知图标 '%s'" % id)
		return Rect2(0, 0, CELL, CELL)
	return entry["rect"]


static func icon_sheet(id: String) -> String:
	var entry: Dictionary = ICONS.get(id, {})
	return entry.get("sheet", SHEET)


## 收获图标:收获物 = 成熟作物。没有对应作物时退回硬币,免得画出空白格。
static func harvest_rect(crop_id: String) -> Rect2:
	if not HARVEST_ROW.has(crop_id):
		return icon_rect("coin")
	return Rect2(HARVEST_COLUMN * CELL, HARVEST_ROW[crop_id] * CELL, CELL, CELL)


static func make_texture(id: String) -> AtlasTexture:
	return _atlas(icon_sheet(id), icon_rect(id))


static func make_harvest_texture(crop_id: String) -> AtlasTexture:
	return _atlas(PLANTS_SHEET, harvest_rect(crop_id))


## 工具 id(GameState.Tool)→ 图标 id。收获没有固定格,由调用方换成当前作物。
static func icon_id_for_tool(tool: int) -> String:
	match tool:
		GameState.Tool.HOE:
			return "hoe"
		GameState.Tool.WATERING_CAN:
			return "watering_can"
		GameState.Tool.SEED:
			return "seed_bag"
		GameState.Tool.HAND:
			return "harvest"
	return "hoe"


static func _atlas(sheet: String, rect: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(sheet)
	atlas.region = rect
	return atlas
