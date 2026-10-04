extends Node2D

## 牧场里的一头牛(由 FarmProps 在牧场里生成,脚本用 preload 引用,没有 class_name)。
##
## 和鸡一模一样**不走物理**:围栏已经把玩家挡在外面,牛也不该把玩家顶开。
## 所以它只是在 FarmProps 给的那块矩形里随机游荡:挑个点 -> 走过去 -> 停一会儿。
## 会动的东西只有 position。
##
## 图集 `Free Cow Sprites.png` 是 96x64 = **3 列 x 2 行,每格 32x32**,
## 而且**第 2 行的第 3 格是全透明的** —— 所以两行帧数不一样,别当成规则网格放
## (按 3 帧播走路会闪一下空白)。
##
## 哪一行是哪个动作是逐像素量出来的(见 DECISIONS#cow-art):
##   行 0 = 眨眼(帧间差只有 4~12px,且全在眼睛 x19..25,y17..18 和尾巴尖上),
##   行 1 = 走路(帧间差 135px,从犄角到蹄子都在动)。
## 牛是**侧身**的、头朝右(眼睛和犄角在右边,尾巴在左边),往左走就水平翻一下。

const SHEET := "res://game_source/Characters/Free Cow Sprites.png"
const CELL := 32
## 动画名 -> 图集里的行 + 这一行有几帧(见上面那段:两行帧数不一样)
const ROWS := {"idle": {"row": 0, "frames": 3}, "walk": {"row": 1, "frames": 2}}
const FPS := {"idle": 1.5, "walk": 3.0}

## 牛走得不快:身体一格多一点,20px/s 差不多一格一秒多
const SPEED := 20.0
## 贴图里最下面一行不透明像素在格子的第 29 行(软阴影的底边)。32 格居中意味着
## 它画在 position 下方 13px —— offset 往上挪 13px,原点就落在**牛脚**上,
## position 可以直接当地面落点用。符号写反整头牛会浮空/钻地,而且**不报错**,
## 所以自检里直接量了「最低一行不透明像素离原点多远」。
const FEET_ROW := 29

## 活动范围(本地像素矩形,由 FarmProps 注入 —— 所以不用 @export)
var roam_area: Rect2 = Rect2()
## 每头牛的随机种子。同一个种子走法一样,出问题能复现
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
	# 原点落到牛脚下(见 FEET_ROW)
	_sprite.offset = Vector2(0, -(FEET_ROW - CELL * 0.5))
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
		# 牛比鸡闲:站着的時間长一些
		_wait = _rng.randf_range(1.5, 5.0)
		return
	_play("walk")
	position += to_target.normalized() * minf(SPEED * delta, to_target.length())
	# 图集里的牛是侧身、头朝右的:往左走水平翻一下
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
		push_error("Cow: 加载不到 " + SHEET)
		return frames
	frames.remove_animation("default")
	for anim_name in ROWS:
		var row: int = ROWS[anim_name]["row"]
		var count: int = ROWS[anim_name]["frames"]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, FPS[anim_name])
		frames.set_animation_loop(anim_name, true)
		for index in count:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(index * CELL, row * CELL, CELL, CELL)
			frames.add_frame(anim_name, atlas)
	return frames
