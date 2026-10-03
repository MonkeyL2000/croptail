extends Node2D

## 开发工具:把游戏画面截下来存成 PNG,方便人肉检查美术/UI。
##
## 为什么需要:run_project 只能拿到控制台输出,看不到画面。想确认
## 「树的贴图有没有缺一块」「HUD 的图标对不对」的时候,就只能截图。
## 截图写到 `res://screenshots/`(用 run_project 跑的时候 res:// 是可写的;
## 导出版不行 —— 这个场景只在开发时用)。
##
## 跑法:run_project {scene: "res://scenes/dev/screenshot.tscn"}

## 截几张
@export var shots: int = 3
## 每张之间等几帧(等相机平滑追上、动画播起来)
@export var frames_between: int = 40
## 截图前把玩家搬到哪里;空数组 = 不动,用主场景里的出生点
@export var spots: Array[Vector2] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	var main: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame

	_dump_hud_geometry(main)
	var player: Player = main.get_node("Player")
	for i in shots:
		if i < spots.size():
			player.global_position = spots[i]
			player.camera.reset_smoothing()
		for j in frames_between:
			await get_tree().process_frame
		await _shoot("shot_%d" % (i + 1))
	print("[screenshot] done -> res://screenshots/")


## 把 HUD 各控件的实际矩形和字体度量打出来。
## 截图只能看出「字被裁了」,看不出为什么 —— 这张表能。
func _dump_hud_geometry(main: Node) -> void:
	var hud: CanvasLayer = main.get_node("HUD")
	for path in ["TopBar", "TopBar/Margin/Row/DayLabel", "BottomBar", "BottomBar/Message",
			"ToolBar", "ToolBar/Slots", "Backpack"]:
		var node: Control = hud.get_node(path)
		print("[hud] %-30s rect %s" % [path, node.get_global_rect()])
	var label: Label = hud.get_node("TopBar/Margin/Row/DayLabel")
	var font: Font = label.get_theme_font("font")
	print("[hud] font=%s height=%.1f ascent=%.1f descent=%.1f" % [
		font.get_font_name(), font.get_height(), font.get_ascent(), font.get_descent()])
	var font_size := label.get_theme_font_size("font_size")
	print("[hud] metrics@12: ascent=%.1f descent=%.1f height=%.1f" % [
		font.get_ascent(12), font.get_descent(12), font.get_height(12)])
	print("[hud] metrics@16: ascent=%.1f descent=%.1f height=%.1f (no-arg: %.1f/%.1f/%.1f)" % [
		font.get_ascent(16), font.get_descent(16), font.get_height(16),
		font.get_ascent(), font.get_descent(), font.get_height()])
	print("[hud] font_size=%d  text size=%s  min size=%s" % [
		font_size, font.get_string_size("Day 1", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size),
		label.get_combined_minimum_size()])


func _shoot(shot_name: String) -> void:
	# 等一帧再取,否则拿到的是本帧还没画完的纹理
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "res://screenshots/%s.png" % shot_name
	var error := image.save_png(path)
	print("[screenshot] %s -> %s (err %d)" % [shot_name, path, error])
