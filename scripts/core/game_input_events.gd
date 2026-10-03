class_name GameInputEvents
extends RefCounted

## 输入查询的唯一入口。
## 四方向、不处理斜向 —— 像素农场游戏的惯例,也避免斜向时的动画歧义。
## 只做「读」,不持有状态(direction 以前是 static var,那是全局可变状态,已去掉)。


static func movement_input() -> Vector2:
	if Input.is_action_pressed("walk_left"):
		return Vector2.LEFT
	if Input.is_action_pressed("walk_right"):
		return Vector2.RIGHT
	if Input.is_action_pressed("walk_up"):
		return Vector2.UP
	if Input.is_action_pressed("walk_down"):
		return Vector2.DOWN
	return Vector2.ZERO


static func is_movement_input() -> bool:
	return movement_input() != Vector2.ZERO


## 「用当前工具」按键。注意:这里用 just_pressed(边沿),状态机每物理帧查一次。
static func is_use_pressed() -> bool:
	return Input.is_action_just_pressed("use_tool")
