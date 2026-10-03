class_name Player
extends CharacterBody2D

## 玩家:四方向走位 + 朝向 + 对「朝向的那一格」使用当前工具。
##
## 朝向(facing)是实例变量(原来是 static var player_direction,多角色会互相串,
## 而且 Godot 4.4 起禁止通过实例访问静态变量)。
## 移动用 CharacterBody2D.move_and_slide():水的碰撞墙由 farm_map.gd 自动生成。

signal action_message(text: String)

const SPEED := 60.0
## 出界/没有农田时的哨兵格值(调用者用 has_cell() 判,不要拿它做坐标)
const INVALID_CELL := Vector2i(-9999, -9999)

## 由 main.gd 注入(不放 @export,避免跨场景的 NodePath 解析问题)
var farm_plot: FarmPlot
## 地面上的物件(树 / 石头 / 木料)。斧、镐作用于它,而不是农田格子
var farm_props: FarmProps
var facing: Vector2 = Vector2.DOWN

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
## 脚下那个小碰撞圆。它同时是**格子锚点** —— 见 cell_anchor_position()
@onready var body_shape: CollisionShape2D = $CollisionShape2D


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tool_slot_1"):
		GameState.select_tool(GameState.Tool.HOE)
	elif event.is_action_pressed("tool_slot_2"):
		GameState.select_tool(GameState.Tool.WATERING_CAN)
	elif event.is_action_pressed("tool_slot_3"):
		GameState.select_tool(GameState.Tool.SEED)
	elif event.is_action_pressed("tool_slot_4"):
		GameState.select_tool(GameState.Tool.HAND)
	elif event.is_action_pressed("tool_slot_5"):
		GameState.select_tool(GameState.Tool.AXE)
	elif event.is_action_pressed("tool_slot_6"):
		GameState.select_tool(GameState.Tool.PICKAXE)
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


## 玩家面前的那一格 = 脚下那一格 + 朝向偏移。
##
## 为什么不用「位置 + 朝向 * 16」:玩家的 `global_position` 是**身体中心**,
## 而脚下碰撞圆在 (0,6) —— 两者差 6px。拿身体中心当锤点,
## 上下朝向会差**一整格**,而且目标格会随「站在小格里的哪个位置」跳,
## 看起来就是「锄的地有点歪,不是正前方那块」。
## 改成「先算脚下那格,再加一格」后,站格内任何位置结果都一致。
func target_cell() -> Vector2i:
	if farm_plot == null:
		return INVALID_CELL
	return standing_cell() + facing_cell_offset()


## 格子锚点:脚下碰撞圆的圆心。从 CollisionShape2D 读偏移,不写死 6(免得改了碰撞形状忘了改这里)
func cell_anchor_position() -> Vector2:
	if body_shape == null:
		return global_position
	return global_position + body_shape.position


## 玩家脚下所在的那一格
func standing_cell() -> Vector2i:
	if farm_plot == null:
		return INVALID_CELL
	return farm_plot.world_to_cell(cell_anchor_position())


## 朝向 -> 相邻那一格的格偏移
func facing_cell_offset() -> Vector2i:
	if facing == Vector2.UP:
		return Vector2i(0, -1)
	if facing == Vector2.DOWN:
		return Vector2i(0, 1)
	if facing == Vector2.LEFT:
		return Vector2i(-1, 0)
	return Vector2i(1, 0)


## 用当前工具作用于面前那一格,并把结果广播给 HUD。
##
## 分两条路:斧/镐是对**地面上的物件**动手(树、石头),其余四个工具是对
## **农田格子**动手。两条路的规则各自集中在一个 use_tool() 里
## (FarmProps / FarmPlot),这里只负责分派与发提示。
func use_current_tool() -> void:
	var cell := target_cell()
	if GameState.tool_works_on_props(GameState.current_tool):
		if farm_props == null:
			action_message.emit("Nothing to work on here.")
			return
		var result := farm_props.use_tool(GameState.current_tool, props_cell_of(cell))
		var item := String(result.get("item", ""))
		if item != "":
			GameState.add_item(item, int(result.get("amount", 0)))
		var gather_message := String(result.get("message", ""))
		if gather_message != "":
			action_message.emit(gather_message)
		return

	if farm_plot == null:
		action_message.emit("Nothing here.")
		return
	var message := farm_plot.use_tool(GameState.current_tool, cell, GameState.selected_crop)
	if message != "":
		action_message.emit(message)


## 农田格坐标 -> FarmProps 那套格坐标。
##
## 两个网格的**点阵是一样的**(都是 16px,且农田格 (0,0) 正落在草地层 (20,7)),
## 但原点不同:player.target_cell() 给的是**农田自己**的格号,FarmProps 用的是
## 草地层那套。所以拿农田格中心的世界坐标回问 props,不写死 (20,7) 这个偏移 ——
## 农田一旦搬家,写死的数字会静静地错一整格。
func props_cell_of(cell: Vector2i) -> Vector2i:
	if farm_props == null or farm_plot == null:
		return cell
	return farm_props.to_local_cell(farm_plot.cell_center(cell))


## 面前那一格上,当前工具能不能真的动手(指示框高亮用)。
## 非斧/镐直接返回 false,连遍历道具表都省了。
func props_actionable(cell: Vector2i) -> bool:
	if farm_props == null or not GameState.tool_works_on_props(GameState.current_tool):
		return false
	return farm_props.can_use(GameState.current_tool, props_cell_of(cell))


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
