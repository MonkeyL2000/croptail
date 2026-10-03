extends Node2D

## 主场景装配:把地图 / 农田 / 玩家 / HUD 接起来,并把「过一天」广播给农田。
##
## 接线放在代码里而不是 .tscn 的 @export 节点路径:跨场景实例的 NodePath 在场景被
## 单独打开时会解析失败,而且这里的耦合关系一眼就能看全。

@onready var farm_plot: FarmPlot = $FarmPlot
@onready var player: Player = $Player
@onready var hud := $HUD


func _ready() -> void:
	player.farm_plot = farm_plot
	player.action_message.connect(hud.show_message)
	TimeManager.day_changed.connect(_on_day_changed)
	hud.show_message("Hoe (1) -> Seeds (3) -> Water (2) -> Harvest (4).")


func _on_day_changed(_day: int) -> void:
	farm_plot.advance_day()
