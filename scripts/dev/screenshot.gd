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
## 截图前把整块农田锄一遍。土块是纯色平板,锄满之后整块农田 = 一个 192x112 的色块,
## 边界正好压在农田外框上 —— 「土块贴图有没有偏移」一眼就能看出来。
@export var till_plot: bool = true
## 每个位置朝哪边(和 spots 一一对应,不够长就沿用上一个)。
## 朝向决定「面前那一格」的指示框画在哪 —— 截图想拍指示框就必须能指定朝向。
@export var facings: Array[Vector2] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	var main: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame

	if till_plot:
		_till_plot(main)
	_dump_hud_geometry(main)
	var player: Player = main.get_node("Player")
	var dog := main.get_node_or_null("Dog")
	for i in shots:
		if i < spots.size():
			player.global_position = spots[i]
			player.camera.reset_smoothing()
		# 狗是靠「重走玩家的脚印」跟的,截图里直接把它挪到旁边 —— 挪位置等于瞬移,
		# 它的脚印会清空,不用等它跑过来(几个 spots 之间相距几百像素)
		if dog != null:
			dog.teleport_to(player.global_position + Vector2(-10, -18))
			dog.set_facing(Vector2.DOWN)
		if i < facings.size():
			player.set_facing(facings[i])
		for j in frames_between:
			await get_tree().process_frame
		# 等画面稳下来再读:指示框在自己的 _process 里更新,刚传完坐标时读到的还是上一帧
		_dump_indicator(main, player, i)
		_dump_cows(main, i)
		_dump_pond_leaves(main, i)
		await _shoot("shot_%d" % (i + 1))
	print("[screenshot] done -> res://screenshots/")


## 把农田每一格锄一遍(用游戏自己的规则入口,不直接改状态)
func _till_plot(main: Node) -> void:
	var plot: FarmPlot = main.get_node("FarmMap/FarmPlot")
	var count := 0
	for x in range(plot.columns):
		for y in range(plot.rows):
			if plot.use_tool(GameState.Tool.HOE, Vector2i(x, y), "") != "":
				count += 1
	print("[screenshot] tilled %d/%d cells (soil boundary should sit exactly on the plot outline)" % [
		count, plot.columns * plot.rows])


## 指示框的状态:截图里看不见它的时候,靠这行判断是「没画」还是「画到画面外了」
func _dump_indicator(main: Node, player: Player, spot: int) -> void:
	var box: Node2D = main.get_node("TargetIndicator")
	var cell: Vector2i = box.call("target_cell")
	var plot: FarmPlot = main.get_node("FarmMap/FarmPlot")
	print("[indicator] spot %d player=%s facing=%s cell=%s in_plot=%s visible=%s in_tree=%s processing=%s" % [
		spot, player.global_position, player.facing, cell, plot.has_cell(cell),
		box.visible, box.is_visible_in_tree(), box.is_processing()])


## 牧场里每头牛画在哪:世界坐标 + 对应的屏幕矩形。
## 牛会自己游荡,截图里它到底在画面的哪一块只能靠这行 —— 事后拿它去图上数像素,
## 就能确认「牛真的画在牧场里面」而不是跑到围栏外边去了。
func _dump_cows(main: Node, shot: int) -> void:
	var props := main.get_node_or_null("FarmMap/Props")
	if props == null or props.get_node_or_null("Props") == null:
		return
	var xform := get_viewport().get_canvas_transform()
	for child in props.get_node("Props").get_children():
		if not String(child.name).begins_with("Cow_"):
			continue
		var body := child as Node2D
		var sprite := body.get_node_or_null("Sprite") as AnimatedSprite2D
		if sprite == null:
			continue
		# 贴图是 32x32 的格子、居中画在 position + offset 上
		var centre := body.global_position + sprite.offset
		var top_left := xform * (centre + Vector2(-16, -16))
		var bottom_right := xform * (centre + Vector2(16, 16))
		print("[cow] shot %d %s world=(%.1f,%.1f) sprite_centre_screen=(%.1f,%.1f) box %s anim=%s flip=%s roam=%s" % [
			shot, body.name, body.global_position.x, body.global_position.y,
			xform.origin.x + centre.x, xform.origin.y + centre.y,
			Rect2(top_left, bottom_right - top_left), sprite.animation, sprite.flip_h,
			body.get("roam_area")])


## 荷叶是静态的,但「它到底画在水上还是草地上」只能靠这行去图上数像素:
## 每片叶子一行,给的是**屏幕矩形**,拿去裁图看里面的颜色,外面一圈应该是水色。
func _dump_pond_leaves(main: Node, shot: int) -> void:
	var props := main.get_node_or_null("FarmMap/Props")
	if props == null or props.get_node_or_null("Props") == null:
		return
	var xform := get_viewport().get_canvas_transform()
	for child in props.get_node("Props").get_children():
		if not String(child.name).begins_with("tuft_"):
			continue
		var node := child as Node2D
		var sprite := node.get_node_or_null("Sprite") as Sprite2D
		if sprite == null:
			continue
		var local: Rect2 = sprite.get_rect()
		var matrix: Transform2D = sprite.get_global_transform()
		var top_left: Vector2 = matrix * local.position
		var bottom_right: Vector2 = matrix * local.end
		var world := Rect2(top_left, bottom_right - top_left)
		var screen_top_left: Vector2 = xform * top_left
		var screen_bottom_right: Vector2 = xform * bottom_right
		print("[leaf] shot %d %s world %s screen %s" % [
			shot, child.name, world,
			Rect2(screen_top_left, screen_bottom_right - screen_top_left)])


## 把 HUD 各控件的实际矩形和字体度量打出来。
## 截图只能看出「字被裁了」,看不出为什么 —— 这张表能。
func _dump_hud_geometry(main: Node) -> void:
	var hud: CanvasLayer = main.get_node("HUD")
	for path in ["TopBar", "TopBar/Margin/Row/DayLabel", "BottomBar", "BottomBar/Message",
			"ToolBar", "ToolBar/Slots", "Materials", "Backpack"]:
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
	print("[screenshot] canvas xform %s  viewport %s" % [
		get_viewport().get_canvas_transform(), get_viewport().get_visible_rect().size])
	var path := "res://screenshots/%s.png" % shot_name
	var error := image.save_png(path)
	print("[screenshot] %s -> %s (err %d)" % [shot_name, path, error])
