extends NodeState

## 使用工具:按当前工具播对应的挥舞动作(锄地 / 浇水 / 播种 / 收割),结束后回 idle。
## 效果在 on_enter() 立刻结算,不等动画 —— 手感优先,动画只是表现。

@export var player: Player

## 用动画自身的长度决定停多久,这样时长跟着素材走,不用手调一个魔数
var _elapsed := 0.0
var _duration := 0.45
## 记录进入时手上的工具:动画播到一半玩家切工具的话,动画不该跟着换
var _tool_id := 0


func on_enter() -> void:
	_elapsed = 0.0
	_tool_id = GameState.current_tool
	player.velocity = Vector2.ZERO
	player.play_use_anim(_tool_id)
	_duration = _anim_duration()
	player.use_current_tool()


func on_physics_process(delta: float) -> void:
	_elapsed += delta
	player.velocity = Vector2.ZERO


func on_next_transitions() -> void:
	if _elapsed >= _duration:
		transition.emit("idle")


func _anim_duration() -> float:
	var sprite := player.animated_sprite
	if sprite == null:
		return 0.45
	var frames := sprite.sprite_frames.get_frame_count(sprite.animation)
	var speed := sprite.sprite_frames.get_animation_speed(sprite.animation)
	if speed <= 0.0:
		return 0.45
	return float(frames) / speed
