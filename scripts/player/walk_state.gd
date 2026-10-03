extends NodeState

## 行走:四方向位移 + walk_<dir> 动画。
## 切换:按使用键 → use;松开方向 → idle。

@export var player: Player

func on_enter() -> void:
	pass


func on_physics_process(_delta: float) -> void:
	var direction := GameInputEvents.movement_input()
	if direction != Vector2.ZERO:
		player.set_facing(direction)
		player.velocity = direction * Player.SPEED
	else:
		player.velocity = Vector2.ZERO
	player.move_and_slide()
	player.play_anim("walk")


func on_next_transitions() -> void:
	if GameInputEvents.is_use_pressed():
		transition.emit("use")
		return
	if not GameInputEvents.is_movement_input():
		transition.emit("idle")
