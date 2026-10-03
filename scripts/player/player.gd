class_name Player
extends CharacterBody2D

## 玩家:四方向走位 + 朝向 + 对「朝向的那一格」使用当前工具。
##
## 朝向(facing)是实例变量(原来是 static var player_direction,多角色会互相串,
## 而且 Godot 4.4 起禁止通过实例访问静态变量)。
## 移动用 CharacterBody2D.move_and_slide():水的碰撞墙由 farm_map.gd 自动生成。

signal action_message(text: String)

const SPEED := 60.0

## 由 main.gd 注入(不放 @export,避免跨场景的 NodePath 解析问题)
var farm_plot: FarmPlot
var facing: Vector2 = Vector2.DOWN

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tool_slot_1"):
		GameState.select_tool(GameState.Tool.HOE)
	elif event.is_action_pressed("tool_slot_2"):
		GameState.select_tool(GameState.Tool.WATERING_CAN)
	elif event.is_action_pressed("tool_slot_3"):
		GameState.select_tool(GameState.Tool.SEED)
	elif event.is_action_pressed("tool_slot_4"):
		GameState.select_tool(GameState.Tool.HAND)
	elif event.is_action_pressed("prev_tool"):
		GameState.cycle_tool(-1)
	elif event.is_action_pressed("next_tool"):
		GameState.cycle_tool(1)
	elif event.is_action_pressed("cycle_seed"):
		GameState.cycle_crop(1)
	elif event.is_action_pressed("buy_seed"):
		buy_seed()
	elif event.is_action_pressed("end_day"):
		TimeManager.advance_day()


func set_facing(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		facing = direction


## 朝向 → 动画后缀。SpriteFrames 里的动画名是 idle_front / walk_back 这种。
func dir_suffix() -> String:
	if facing == Vector2.UP:
		return "back"
	if facing == Vector2.DOWN:
		return "front"
	if facing == Vector2.LEFT:
		return "left"
	return "right"


## 播放 "<prefix>_<dir>"。只在动画真的换了才 play(),否则每帧 play() 会把动画重置。
func play_anim(prefix: String) -> void:
	if animated_sprite == null:
		return
	var animation := "%s_%s" % [prefix, dir_suffix()]
	if animated_sprite.animation != animation or not animated_sprite.is_playing():
		animated_sprite.play(animation)


## 按工具播放使用动作。
##
## 动作图集里每个工具有一套独立的挥舞动作。以前四个工具都放同一套
## (而且帧坐标还越界了),现在按 GameState.current_tool 选。
## 帧怎么切、哪个工具用哪个动作块,见 `tools/gen_player_scene.py` 里的注释。
func play_use_anim(tool_id: int) -> void:
	if animated_sprite == null:
		return
	var action := "front"
	if facing == Vector2.UP:
		action = "back"
	elif facing == Vector2.LEFT:
		action = "left"
	elif facing == Vector2.RIGHT:
		action = "right"
	var animation := "use_%d_%s" % [tool_id + 1, action]
	if animated_sprite.sprite_frames.has_animation(animation):
		animated_sprite.play(animation)
	else:
		play_anim("idle")


## 玩家面前的那一格(以玩家身体为基准,往前一格)
func target_cell() -> Vector2i:
	if farm_plot == null:
		return Vector2i(-9999, -9999)
	return farm_plot.world_to_cell(global_position + facing * FarmPlot.CELL_SIZE)


## 用当前工具作用于面前那一格,并把结果广播给 HUD
func use_current_tool() -> void:
	if farm_plot == null:
		action_message.emit("Nothing here.")
		return
	var message := farm_plot.use_tool(GameState.current_tool, target_cell(), GameState.selected_crop)
	if message != "":
		action_message.emit(message)


func buy_seed() -> void:
	var data := CropDB.get_crop(GameState.selected_crop)
	if data == null:
		return
	if GameState.coins < data.seed_cost:
		action_message.emit("Not enough coins for %s seeds." % data.display_name)
		return
	GameState.add_coins(-data.seed_cost)
	GameState.add_item(GameState.seed_item_id(data.id), 1)
	action_message.emit("Bought 1 %s seed (-%d coins)." % [data.display_name, data.seed_cost])
