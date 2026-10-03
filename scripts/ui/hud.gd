extends CanvasLayer

## HUD:顶部状态条 + 左下工具条 + 右下背包格 + 底部提示行。
##
## 设计取舍:
##   - **底板而不是文字描边**。Godot 的 Label outline 会给每条边各画一圈,
##     小字号下糊成一团。改成整条铺一块半透明底板,可读性稳,也省得逐条调色。
##   - **图标不是文字**。工具/种子的图来自 `scripts/ui/tool_icons.gd` 的表,
##     四个工具有四张不同的图(以前是同一把工具转四个角度,见那个文件的说明)。
##   - **收获图标跟着当前作物走**:显示的永远是「你现在收得到什么」。
##
## 见 docs/DECISIONS.md#hud-panels。

const MESSAGE_TIME := 3.0
## 格子边长。16px 的图标 + 右下角一位数字的种子数,26 刚好不打架。
const SLOT_SIZE := 26
const SLOT_GAP := 2
## 位图字体只有一个真实字号,见 tools/gen_pixel_font.py
const FONT_PATH := "res://game_source/font/sprout_ui.fnt"
const FONT_SIZE := 12
## 要挂 theme 的面板(Label 从祖先继承,包括代码新建的那些)
const PANELS: Array[String] = ["TopBar", "ToolBar", "Backpack", "Materials", "BottomBar"]

@onready var _day_label: Label = $TopBar/Margin/Row/DayLabel
@onready var _coins_label: Label = $TopBar/Margin/Row/CoinsLabel
@onready var _tool_label: Label = $TopBar/Margin/Row/ToolLabel
@onready var _seed_label: Label = $TopBar/Margin/Row/SeedLabel
@onready var _tool_slots: HBoxContainer = $ToolBar/Slots
@onready var _backpack: HBoxContainer = $Backpack/Slots
@onready var _materials: HBoxContainer = $Materials/Slots
@onready var _message: Label = $BottomBar/Message

var _tool_entries: Array[Dictionary] = []
var _backpack_entries: Array[Dictionary] = []
## 材料格:木头 / 石头。砍树挖石头得到的东西总得看得到,不然按下去像没反应
var _material_entries: Array[Dictionary] = []
var _message_left := 0.0


func _ready() -> void:
	_apply_theme()
	GameState.tool_changed.connect(func(_tool: int) -> void: _refresh())
	GameState.inventory_changed.connect(_refresh)
	GameState.coins_changed.connect(func(_coins: int) -> void: _refresh())
	GameState.crop_changed.connect(func(_crop: String) -> void: _refresh())
	TimeManager.day_changed.connect(func(_day: int) -> void: _refresh())
	_build_tool_bar()
	_build_backpack()
	_build_materials()
	_message.text = ""
	_refresh()


func _process(delta: float) -> void:
	# 天数进度自己在走,所以每帧刷;提示行只在还有时间的时候刷
	_refresh_day()
	if _message_left <= 0.0:
		return
	_message_left -= delta
	if _message_left <= 0.0:
		_message.text = ""


func show_message(text: String) -> void:
	if text == "":
		return
	_message.text = text
	_message_left = MESSAGE_TIME


## 统一字体。
##
## **必须显式给 "Label" 类型挂字体**,不能只写 `theme.default_font` ——
## 那样 `get_theme_font("font")` 会回退到 Godot 内置的 Open Sans(实测),
## 位图字根本没被用上。
##
## 另一件必须钉死的是 font_size。点阵字体只有一个真实尺寸(12px),
## 而 Label 从默认主题拿到的是 16 —— Godot 会把 12px 的点阵按 16/12 放大,
## 行高从 15 变 20,字顶直接顶出顶栏被裁掉。截图里只能看到「字少了一半」,
## 完全看不出原因,所以 selftest 里有专门一条断言钉着。
func _apply_theme() -> void:
	var font: Font = load(FONT_PATH)
	if font == null:
		push_error("HUD: 加载不到位图字体 " + FONT_PATH)
		return
	var hud_theme := Theme.new()
	hud_theme.default_font = font
	hud_theme.default_font_size = FONT_SIZE
	hud_theme.set_font("Label", "font", font)
	hud_theme.set_font_size("Label", "font_size", FONT_SIZE)
	for panel_path in PANELS:
		(get_node(panel_path) as Control).theme = hud_theme


## --- 构建 ---------------------------------------------------------------

func _build_tool_bar() -> void:
	for tool in GameState.TOOL_ORDER:
		var icon := ItemIcon.create(ToolIcons.icon_id_for_tool(tool))
		var panel := _make_slot(icon)
		_tool_slots.add_child(panel)
		_tool_entries.append({"tool": tool, "panel": panel, "icon": icon})


func _build_backpack() -> void:
	for crop_id in CropDB.all_ids():
		# 用「成熟作物」而不是统一的种子袋:两个格子才看得出哪个是小麦哪个是叶菜
		var icon := ItemIcon.create("harvest")
		icon.set_harvest_crop(crop_id)
		var panel := _make_slot(icon)
		_backpack.add_child(panel)
		panel.add_child(_make_count_label())
		_backpack_entries.append({"crop": crop_id, "panel": panel, "count": panel.get_node("Count"), "icon": icon})


## 木头 / 石头的数量格。图标表在 ToolIcons.ICONS(wood / stone)
func _build_materials() -> void:
	for item_id in GameState.MATERIAL_ORDER:
		var icon := ItemIcon.create(item_id)
		var panel := _make_slot(icon)
		_materials.add_child(panel)
		panel.add_child(_make_count_label())
		_material_entries.append({"item": item_id, "panel": panel, "count": panel.get_node("Count")})


## 格子右下角那位数字。背包和材料格共用。
func _make_count_label() -> Label:
	var count := Label.new()
	count.name = "Count"
	count.add_theme_color_override("font_color", Color(1, 1, 1))
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	count.add_theme_font_size_override("font_size", FONT_SIZE)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return count


func _make_slot(icon: ItemIcon) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	# 图标靠左上,右下角留给种子数
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = SLOT_BG
	style.border_color = SLOT_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(icon)
	return panel


## --- 刷新 ---------------------------------------------------------------

const SLOT_BG := Color(0.08, 0.09, 0.12, 0.55)
const SLOT_BG_SELECTED := Color(0.24, 0.2, 0.08, 0.8)
const SLOT_BORDER := Color(0.55, 0.55, 0.6, 0.6)
const SLOT_BORDER_SELECTED := Color(1.0, 0.9, 0.45)


func _refresh() -> void:
	_refresh_day()
	_coins_label.text = "%d" % GameState.coins
	_tool_label.text = GameState.tool_label()
	_seed_label.text = CropDB.get_crop(GameState.selected_crop).display_name \
		if CropDB.get_crop(GameState.selected_crop) != null else "-"

	for entry in _tool_entries:
		var selected: bool = entry["tool"] == GameState.current_tool
		_set_slot_selected(entry["panel"], selected)
		# 收获图标跟着当前作物变:选 Greens 时那把「镰刀」画的就是 Greens
		(entry["icon"] as ItemIcon).set_harvest_crop(GameState.selected_crop)

	for entry in _backpack_entries:
		var crop_id: String = entry["crop"]
		var seeds := GameState.item_count(GameState.seed_item_id(crop_id))
		var harvested := GameState.item_count(crop_id)
		var crop: CropData = CropDB.get_crop(crop_id)
		_set_slot_selected(entry["panel"], crop_id == GameState.selected_crop)
		(entry["count"] as Label).text = str(seeds) if seeds > 0 else ""
		(entry["icon"] as ItemIcon).tooltip_text = \
			"%s seeds x%d  harvested x%d  (sell %d)" % [crop.display_name, seeds, harvested, crop.sell_price]
		(entry["panel"] as Control).tooltip_text = (entry["icon"] as ItemIcon).tooltip_text

	for entry in _material_entries:
		var item_id: String = entry["item"]
		var amount := GameState.item_count(item_id)
		# 0 就不写数字,格子看着干净
		(entry["count"] as Label).text = str(amount) if amount > 0 else ""
		(entry["panel"] as Control).tooltip_text = "%s x%d" % [GameState.material_label(item_id), amount]


func _set_slot_selected(panel: Control, selected: bool) -> void:
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = SLOT_BORDER_SELECTED if selected else SLOT_BORDER
	style.bg_color = SLOT_BG_SELECTED if selected else SLOT_BG


func _refresh_day() -> void:
	_day_label.text = "Day %d  %d%%" % [TimeManager.day, roundi(TimeManager.day_fraction() * 100.0)]
