extends NodeState

## 使用工具:播 use_<dir> 动作动画(Basic Charakter Actions 那套),结束后回 idle。
## 实际效果在 on_enter() 立刻结算,不等动画 —— 手感优先,动画只是表现。

const USE_TIME := 0.45

@export var player: Player

var _elapsed: float = 0.0


func on_enter() -> void:
	_elapsed = 0.0
	player.velocity = Vector2.ZERO
	player.play_anim("use")
	player.use_current_tool()


func on_physics_process(delta: float) -> void:
	_elapsed += delta
	player.velocity = Vector2.ZERO


func on_next_transitions() -> void:
	if _elapsed >= USE_TIME:
		transition.emit("idle")
