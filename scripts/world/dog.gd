extends CharacterBody2D

## 跟着玩家跑的宠物狗(素材 `game_source/Pets/lilpuddinpuggums.png`,用户提供)。
##
## **为什么是「重走玩家的脚印」而不是「朝玩家直线冲」**:树、石头是实心的,
## 直线追会在树干上顶死 —— 玩家绕过去了,狗卡在树后面。这里改成记路线:
## 玩家每走 TRAIL_STEP 像素就记一个路点,狗按顺序一个个走过去。
## 玩家能过的地方狗一定能过(它走的正是同一条路),不用写寻路。
## 卡住也会自救(见 _physics_process 里的 _stuck):真顶住了就丢掉那个路点。
##
## **图集是处理过的**:源图是白底的 96x192,由 `tools/pack_dog.py` 抠白底 +
## 按行居中 + 2:1 取样成 48x96(3 列 x 4 行,每格 16x24,带 alpha)。
## 直接引源图的话狗屁股后面会跟着一个白方块。见 docs/DECISIONS.md#dog-pet。
##
## 和鸡(chicken.gd)不一样:鸡不走物理(围栏拦玩家、鸡在圈里随便逛),
## 狗要跟着玩家满地图跑,得真的和水的碰撞墙 / 树打交道,所以是 CharacterBody2D。
## 它的 collision_layer 是 2 —— 没人拿 2 当 mask,所以狗不会把玩家顶开。

const SHEET := "res://game_source/Pets/pug_walk.png"
## 成品图集的一格(和 tools/pack_dog.py 里的 CELL 一致)
const CELL := Vector2i(16, 24)
## 行 -> 朝向名。和 player.gd 的 dir_suffix() 同一套:front / back / left / right
const DIR_ROWS := {"front": 0, "left": 1, "right": 2, "back": 3}
## 一行 3 帧(走路循环:左前腿 / 换腿 / 右前腿)
const WALK_FRAMES := 3
const FPS := 6.0
## 比玩家(60)慢一点,不然狗会一直贴着人腿
const SPEED := 46.0
## 走到离路点这么近就算到了
const ARRIVE := 3.0
## 玩家每走这么远记一个路点
const TRAIL_STEP := 6.0
## 路点最多留这么多(走太久不清会把数组撑大)
const TRAIL_MAX := 96
## 沿着路线离玩家这么近就停下(不然会踩到玩家身上)
const FOLLOW_GAP := 20.0
## 卡住判定:这么久了还没挪动就丢掉当前路点
const STUCK_TIME := 0.35
## 脚下的小碰撞圆(玩家是 5,狗小一点)
const BODY_RADIUS := 4.0

## 由 main.gd 注入
var player: Player
var facing := Vector2.DOWN

var _sprite: AnimatedSprite2D
## 玩家的脚印,队首 = 狗现在要去的点
var _trail := PackedVector2Array()
var _moving := false
var _stuck := 0.0


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = _build_frames()
	# 图格里狗贴在最下面几行,而 AnimatedSprite2D 默认把「格子的中心」当原点。
	# 往上挪半格,原点就落到了狗的**脚下** —— 位置可以直接当成地面上的落点用。
	# 符号别写反:offset.y 是往下移,所以要负的(写正的话整只狗会挂到地底下)。
	_sprite.offset = Vector2(0, -CELL.y * 0.5)
	_sprite.play("idle_front")
	add_child(_sprite)

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = BODY_RADIUS
	shape.shape = circle
	add_child(shape)

	# 层 2:没人把 2 当 mask,所以狗挡不住玩家 / 道具的碰撞体
	collision_layer = 2
	collision_mask = 1


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_record_trail()
	_drop_reached()
	if _remaining_path_length() <= FOLLOW_GAP:
		# 已经跟上了:清掉脚印,免得玩家绕一圈回到原地后狗又照着圆圈跑一遍
		_trail.clear()
		_face_towards(player.global_position)
		_stop()
		return

	var aim := _trail[0]
	var before := global_position
	var to_aim := aim - global_position
	if to_aim.length() < ARRIVE:
		velocity = Vector2.ZERO
	else:
		velocity = to_aim.normalized() * SPEED
		set_facing(velocity)
	move_and_slide()
	_set_moving(velocity != Vector2.ZERO)

	# 顶在树上顶久了就把这个路点丢掉(玩家绕过去的时候会有这种情况)
	if global_position.distance_to(before) < SPEED * delta * 0.25:
		_stuck += delta
		if _stuck >= STUCK_TIME and not _trail.is_empty():
			_trail.remove_at(0)
			_stuck = 0.0
	else:
		_stuck = 0.0


## 玩家走远了就记一个路点
func _record_trail() -> void:
	var here := player.global_position
	if _trail.is_empty() or _trail[_trail.size() - 1].distance_to(here) >= TRAIL_STEP:
		_trail.append(here)
		while _trail.size() > TRAIL_MAX:
			_trail.remove_at(0)


## 走到过的那种路点就出队
func _drop_reached() -> void:
	while not _trail.is_empty() and global_position.distance_to(_trail[0]) < ARRIVE:
		_trail.remove_at(0)


## 狗 -> 剩下所有路点 -> 玩家,加起来的路程
func _remaining_path_length() -> float:
	if _trail.is_empty():
		return 0.0
	var total := global_position.distance_to(_trail[0])
	for i in range(_trail.size() - 1):
		total += _trail[i].distance_to(_trail[i + 1])
	total += _trail[_trail.size() - 1].distance_to(player.global_position)
	return total


func _face_towards(point: Vector2) -> void:
	set_facing(point - global_position)


func set_facing(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	# 只认主轴:斜着走的时候不要来回抖(和玩家一样)
	if absf(direction.x) > absf(direction.y):
		facing = Vector2.RIGHT if direction.x > 0.0 else Vector2.LEFT
	else:
		facing = Vector2.DOWN if direction.y > 0.0 else Vector2.UP
	if not _moving:
		play_anim("idle")


func dir_suffix() -> String:
	if facing == Vector2.UP:
		return "back"
	if facing == Vector2.DOWN:
		return "front"
	if facing == Vector2.LEFT:
		return "left"
	return "right"


func play_anim(prefix: String) -> void:
	if _sprite == null:
		return
	var animation := "%s_%s" % [prefix, dir_suffix()]
	if _sprite.animation != animation or not _sprite.is_playing():
		_sprite.play(animation)


func _set_moving(value: bool) -> void:
	if value == _moving:
		return
	_moving = value
	play_anim("walk" if _moving else "idle")


func _stop() -> void:
	velocity = Vector2.ZERO
	_set_moving(false)


## 把狗直接挪到某处(读档、测试用):位置和脚印一起清掉,不然它会回头去走旧路线
func teleport_to(point: Vector2) -> void:
	global_position = point
	velocity = Vector2.ZERO
	_trail.clear()
	_stuck = 0.0
	_set_moving(false)


## 图格里第 row 行第 col 帧的区域。测试用它和 CELL / DIR_ROWS 对照,
## 免得「动画名对了但切错行」这种错(玩家那边栽过一次)。
static func frame_rect(row: int, col: int) -> Rect2:
	return Rect2(col * CELL.x, row * CELL.y, CELL.x, CELL.y)


func _build_frames() -> SpriteFrames:
	var tex := load(SHEET) as Texture2D
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for dir_name in DIR_ROWS:
		var row: int = DIR_ROWS[dir_name]
		var walk := "walk_%s" % dir_name
		frames.add_animation(walk)
		frames.set_animation_speed(walk, FPS)
		frames.set_animation_loop(walk, true)
		for col in WALK_FRAMES:
			frames.add_frame(walk, _atlas(tex, row, col))
		# 没有单独的站立帧:站着就用走路的第一帧
		var idle := "idle_%s" % dir_name
		frames.add_animation(idle)
		frames.set_animation_speed(idle, 1.0)
		frames.set_animation_loop(idle, true)
		frames.add_frame(idle, _atlas(tex, row, 0))
	return frames


static func _atlas(tex: Texture2D, row: int, col: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = frame_rect(row, col)
	return at
