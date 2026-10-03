class_name FarmCell
extends Node2D

## 一格农田:土壤状态 + 一格作物。
##
## 视觉做成逐格 Sprite2D(不是 TileMapLayer),原因:
## 素材里没有独立的「湿土」贴图,湿/干必须靠逐格调色区分,而 TileMapLayer 不支持
## 逐格 modulate。详见 docs/DECISIONS.md#cell-sprites

enum Soil { UNTILLED, TILLED }

const CELL_SIZE := 16
## Tilled_Dirt_Wide.png 的 1:1 是纯色平板土块(逐格分析确认全格不透明、单色)
const SOIL_CELL := Vector2i(1, 1)
## 湿土整体压暗(基准土色 232,207,166 → 偏深的湿褐色)
const WATERED_TINT := Color(0.70, 0.62, 0.55)
## 成熟提示:整体提亮
const MATURE_TINT := Color(1.35, 1.35, 1.25)
## 精灵摆到**格子的中心**。Sprite2D 默认 `centered = true`,而格子的原点在**左上角** ——
## 不自己挑位置的话,那块 16x16 的贴图会以左上角为圆心画,整块偏左上 8px:
## 玩家看到的就是「锄到的格子和指示框不是同一格」(用户报过,见 DECISIONS#cell-sprites)
const SPRITE_OFFSET := Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)

static var _soil_texture: Texture2D
static var _crop_texture: Texture2D

var grid_pos: Vector2i = Vector2i.ZERO
var soil: int = Soil.UNTILLED
var watered: bool = false
var crop: CropData = null
var growth: int = 0

var _soil_sprite: Sprite2D
var _crop_sprite: Sprite2D
var _crop_frames: Dictionary = {}


static func _ensure_textures() -> void:
	if _soil_texture == null:
		_soil_texture = load("res://game_source/Tilesets/Tilled_Dirt_Wide.png")
	if _crop_texture == null:
		_crop_texture = load("res://game_source/Objects/Basic_Plants.png")


func _init() -> void:
	_ensure_textures()
	_soil_sprite = Sprite2D.new()
	_soil_sprite.name = "SoilSprite"
	_soil_sprite.position = SPRITE_OFFSET
	_soil_sprite.visible = false
	_soil_sprite.z_index = 0
	add_child(_soil_sprite)

	_crop_sprite = Sprite2D.new()
	_crop_sprite.name = "CropSprite"
	_crop_sprite.position = SPRITE_OFFSET
	_crop_sprite.visible = false
	_crop_sprite.z_index = 1
	add_child(_crop_sprite)

	_refresh()


func configure(pos: Vector2i) -> void:
	grid_pos = pos
	_refresh()


## --- 状态查询 -------------------------------------------------------------

func is_tilled() -> bool:
	return soil == Soil.TILLED


func is_empty() -> bool:
	return crop == null


## 显示的阶段序号(0 基),封顶在最后一格
func display_stage() -> int:
	if crop == null:
		return 0
	var days := maxi(crop.days_per_stage, 1)
	var stage := floori(growth / float(days))
	return mini(stage, crop.stage_count() - 1)


func is_mature() -> bool:
	return crop != null and growth >= crop.growth_to_mature()


## --- 动作 -----------------------------------------------------------------

func till() -> bool:
	if is_tilled():
		return false
	soil = Soil.TILLED
	_refresh()
	return true


func water() -> bool:
	if not is_tilled() or watered:
		return false
	watered = true
	_refresh()
	return true


func plant(data: CropData) -> bool:
	if not is_tilled() or crop != null or data == null:
		return false
	crop = data
	growth = 0
	_refresh()
	return true


## 过一天:浇过水的作物长一级,水变干(所以每天都要浇)
func advance_day() -> void:
	if crop != null and watered and not is_mature():
		growth += 1
	watered = false
	_refresh()


## 收获。返回 {item, sell_price};没成熟就返回空字典。
func harvest() -> Dictionary:
	if not is_mature():
		return {}
	var result := {"item": crop.id, "sell_price": crop.sell_price}
	crop = null
	growth = 0
	watered = false
	_refresh()
	return result


## --- 视觉 -----------------------------------------------------------------

func _refresh() -> void:
	if _soil_sprite == null:
		return
	_soil_sprite.visible = is_tilled()
	if is_tilled():
		if _soil_sprite.texture == null:
			_soil_sprite.texture = _atlas(
				_soil_texture,
				Rect2(SOIL_CELL.x * CELL_SIZE, SOIL_CELL.y * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			)
		_soil_sprite.self_modulate = WATERED_TINT if watered else Color.WHITE

	_crop_sprite.visible = crop != null
	if crop == null:
		return
	var stage := display_stage()
	if not _crop_frames.has(stage):
		_crop_frames[stage] = _atlas(_crop_texture, crop.region_for_stage(stage))
	_crop_sprite.texture = _crop_frames[stage]
	_crop_sprite.self_modulate = MATURE_TINT if is_mature() else Color.WHITE


func _atlas(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	return atlas


func debug_line() -> String:
	return "cell%s soil=%s watered=%s crop=%s growth=%d mature=%s" % [
		str(grid_pos),
		"tilled" if is_tilled() else "untilled",
		str(watered),
		crop.id if crop != null else "-",
		growth,
		str(is_mature()),
	]
