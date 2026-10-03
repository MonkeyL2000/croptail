extends NodeState

## 站立:循环播 idle_<dir>。
## 切换:按使用键 → use;有方向输入 → walk。

@export var player: Player

func on_enter() -> void:
	player.play_anim("idle")


func on_physics_process(_delta: float) -> void:
	player.velocity = Vector2.ZERO
	player.play_anim("idle")


func on_next_transitions() -> void:
	if GameInputEvents.is_use_pressed():
		transition.emit("use")
		return
	if GameInputEvents.is_movement_input():
		transition.emit("walk")
