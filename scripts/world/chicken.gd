extends Node2D

## 院子里的一只鸡(由 FarmProps 在鸡圈里生成,脚本用 preload 引用,没有 class_name)。
##
## **不走物理**:圈里不需要碰撞 —— 围栏已经把玩家挡在外面,鸡也不该把玩家顶开。
## 所以它只是在 FarmProps 给的那一小块矩形里随机游荡:挑一个点 -> 走过去 ->
## 停一会儿 -> 再挑一个点。会动的东西只有 position。
##
## 为什么在代码里搭 AnimatedSprite2D 而不是写一个 .tscn:鸡的图在
## `Free Chicken Sprites.png` 里是 4 列 x 2 行、每格 16x16,在代码里切只要一张
## ROWS 表;写进 .tscn 就得再抄一遍图集坐标 —— 玩家那边正是这么栽过一次的
## (四把工具抄成同一把,见 tools/gen_player_scene.py 的注释)。
##
## 4 列里只有**前 2 格**有内容,后两格是全透明的:别按 4 帧放,会闪一下空白。

const SHEET := "res://game_source/Characters/Free Chicken Sprites.png"
const CELL := 16
## 动画名 -> 图集里的行。0 = 站着啄食,1 = 迈步
const ROWS := {"idle": 0, "walk": 1}
const FRAME_COUNT := 2
const FPS := 3.0
## 鸡走得很慢:一格 16px,14px/s 差不多一格一秒
const SPEED := 14.0

## 活动范围(本地像素矩形,由 FarmProps 注入 —— 所以不用 @export)
var roam_area: Rect2 = Rect2()
## 每只鸡的随机种子。同一个种子走法一样,出问题能复现
var rng_seed: int = 0

var _rng := RandomNumberGenerator.new()
var _sprite: AnimatedSprite2D
var _target := Vector2.ZERO
var _wait := 0.0


func _ready() -> void:
	_rng.seed = rng_seed
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = _build_frames()
	add_child(_sprite)
	_play("idle")
	_pick_target()


func _process(delta: float) -> void:
	if _sprite == null or roam_area.size.x <= 0.0:
		return
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_pick_target()
		return
	var to_target := _target - position
	if to_target.length() <= 1.0:
		_play("idle")
		_wait = _rng.randf_range(0.6, 2.2)
		return
	_play("walk")
	position += to_target.normalized() * minf(SPEED * delta, to_target.length())
	# 图集里的鸡是侧面的:往左走水平翻一下
	_sprite.flip_h = to_target.x < 0.0


func _pick_target() -> void:
	_target = Vector2(
		_rng.randf_range(roam_area.position.x, roam_area.end.x),
		_rng.randf_range(roam_area.position.y, roam_area.end.y))


func _play(animation: String) -> void:
	if _sprite.animation != animation or not _sprite.is_playing():
		_sprite.play(animation)


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	var sheet: Texture2D = load(SHEET)
	if sheet == null:
		push_error("Chicken: 加载不到 " + SHEET)
		return frames
	frames.remove_animation("default")
	for anim_name in ROWS:
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, FPS)
		frames.set_animation_loop(anim_name, true)
		for index in FRAME_COUNT:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(index * CELL, int(ROWS[anim_name]) * CELL, CELL, CELL)
			frames.add_frame(anim_name, atlas)
	return frames
