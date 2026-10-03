class_name ItemIcon
extends TextureRect

## 一个 16x16 的物品图标:居中显示、不缩放、NEAREST 过滤(像素画放大就糊了)。
## 工具条 / 背包格都用它。图标表在 scripts/ui/tool_icons.gd。

const SIZE := 16

## 图标 id。留着是为了刷新时知道该换成哪张图 —— 收获图标会跟着当前作物变。
var icon_id: String = ""
## "harvest" 图标画哪个作物(由 HUD 在切换作物时设置)
var crop_id: String = "wheat"


static func create(id: String) -> ItemIcon:
	var node := ItemIcon.new()
	node.custom_minimum_size = Vector2(SIZE, SIZE)
	node.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.apply_icon(id)
	return node


## 按图标 id 换图。"harvest" 用当前记着的作物。
func apply_icon(id: String) -> void:
	icon_id = id
	texture = ToolIcons.make_harvest_texture(crop_id) if id == "harvest" else ToolIcons.make_texture(id)


func set_harvest_crop(new_crop_id: String) -> void:
	crop_id = new_crop_id
	if icon_id == "harvest":
		texture = ToolIcons.make_harvest_texture(crop_id)
