extends Node2D

## 主场景装配:农场场景自带农田和装饰物,这里只把它们和玩家 / HUD 接起来。
##
## 接线放在代码里而不是 .tscn 的 @export 节点路径:跨场景实例的 NodePath 在场景被
## 单独打开时会解析失败,而且这里的耦合关系一眼就能看全。

@onready var farm_plot: FarmPlot = $FarmMap/FarmPlot
@onready var farm_props: FarmProps = $FarmMap/Props
@onready var farm_map: Node2D = $FarmMap
@onready var player: Player = $Player
## 面前那一格的指示框。它在 main.tscn 里摆在 FarmMap / Player **之后**,
## 也就是盖在最上层 —— 角色精灵 48px 比一格还大,画在地面层时面朝上会把框整个挡住
## (拿真实截图的像素量出来的)。不用 z_index:负 z 会被父节点的 z 抵消下场,连底板都盖不住。
@onready var target_indicator := $TargetIndicator
@onready var hud := $HUD


func _ready() -> void:
	# Props 在它自己的 _ready() 里就撒好了,这里只补上「谁不能挡」这两条
	farm_props.plot = farm_plot
	farm_props.player = player
	farm_props.rebuild()

	player.farm_plot = farm_plot
	player.farm_props = farm_props
	player.action_message.connect(hud.show_message)
	target_indicator.setup(player, farm_plot)
	TimeManager.day_changed.connect(_on_day_changed)
	_apply_camera_limits()
	hud.show_message("Hoe(1) Seeds(3) Water(2) | Axe(5) Pickaxe(6) | Space: use in front")


## 把相机卡在草岛范围内。限制值从 TileMapLayer 现场算(见 farm_map.gd),
## 写死数字的话改地图就得同步改代码。
func _apply_camera_limits() -> void:
	var bounds: Rect2 = farm_map.playable_rect()
	if bounds.size == Vector2.ZERO:
		return
	player.camera.limit_left = roundi(bounds.position.x)
	player.camera.limit_top = roundi(bounds.position.y)
	player.camera.limit_right = roundi(bounds.end.x)
	player.camera.limit_bottom = roundi(bounds.end.y)
	player.camera.reset_smoothing()


func _on_day_changed(_day: int) -> void:
	farm_plot.advance_day()
