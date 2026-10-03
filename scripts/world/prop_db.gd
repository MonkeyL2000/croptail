class_name PropDB
extends RefCounted

## 装饰物(树 / 石头 / 木头 / 灌木)表。
##
## ## 为什么用 Rect2 而不是 16x16 格子
##
## 素材包里的对象**不是按 16 的倍数摆的**:`Basic_Grass_Biom_things.png` 是 144x80,
## 里面最大的一棵树是 24x30 像素,起点在 (20,1) —— 你把整张图按 9x5 的格子切开,
## 每格都是这棵树的**一个碎片**,拿任何一格单独当贴图都会缺一块。
##
## 所以这张表里的坐标是用连通域(flood fill)从 PNG 里**量**出来的真实包围盒,
## 生成脚本见 `tools/extract_props.py`。想换素材:重跑那个脚本,把输出的
## `PROPS` 表贴回来即可 —— 碰撞体也是同一份数据算出来的,不会对不上。
##
## ## 分类
##
## 靠**调色板**判断,不是靠形状猜(见 docs/DECISIONS.md#prop-art-classification):
##   - 绿色占多数 -> 灌木 / 草簇(不挡路)
##   - 灰白(石色)占多数 -> 石头(挡路)
##   - 褐色(木色)占多数 -> 木头 / 树枝(挡路)
## 这张表是「人肉复核过一遍」的结果:自动分类只在调色板明确时可信。

## 每一行的格式:名字 -> { sheet: 图集路径 key, rect: Rect2, kind: 种类, solid: 是否挡路 }
## rect 是**源图集里的像素矩形**,不是格子。
const SHEETS := {
	"biome": "res://game_source/Objects/Basic_Grass_Biom_things.png",
	"materials": "res://game_source/Objects/Basic_tools_and_meterials.png",
}

const PROPS := {
	# --- 树(biome 图集里的三棵 + 一棵棕色树干)---------------------------
	"tree_small": {"sheet": "biome", "rect": Rect2(1, 0, 14, 28), "kind": "tree", "solid": true},
	"tree_big": {"sheet": "biome", "rect": Rect2(20, 1, 24, 30), "kind": "tree", "solid": true},
	"tree_big_mirror": {"sheet": "biome", "rect": Rect2(52, 1, 24, 30), "kind": "tree", "solid": true},
	"tree_autumn": {"sheet": "biome", "rect": Rect2(129, 34, 14, 28), "kind": "tree", "solid": true},

	# --- 石头(materials 图集里的两块灰石 + biome 图集里的石堆)-----------
	"rock_low": {"sheet": "materials", "rect": Rect2(0, 4, 16, 10), "kind": "rock", "solid": true},
	"rock_round": {"sheet": "materials", "rect": Rect2(1, 18, 14, 13), "kind": "rock", "solid": true},
	"rock_pile": {"sheet": "biome", "rect": Rect2(33, 33, 13, 14), "kind": "rock", "solid": true},
	"rock_wide": {"sheet": "biome", "rect": Rect2(64, 49, 16, 14), "kind": "rock", "solid": true},
	"rock_mossy": {"sheet": "biome", "rect": Rect2(82, 2, 13, 12), "kind": "rock", "solid": true},

	# --- 木头(materials 图集里的两截木料 + biome 图集里的树枝)----------
	"wood_log": {"sheet": "materials", "rect": Rect2(17, 17, 13, 14), "kind": "wood", "solid": true},
	"wood_log_big": {"sheet": "materials", "rect": Rect2(33, 17, 14, 14), "kind": "wood", "solid": true},
	"wood_branch": {"sheet": "biome", "rect": Rect2(67, 36, 10, 10), "kind": "wood", "solid": true},
	"wood_branch_small": {"sheet": "biome", "rect": Rect2(52, 36, 8, 10), "kind": "wood", "solid": true},
	"wood_pile": {"sheet": "biome", "rect": Rect2(80, 35, 16, 9), "kind": "wood", "solid": true},

	# --- 灌木 / 草丛 / 碎石:不挡路,只让地面不空 -------------------------
	"bush_wide": {"sheet": "biome", "rect": Rect2(0, 48, 32, 15), "kind": "deco", "solid": false},
	"bush_wide_alt": {"sheet": "biome", "rect": Rect2(36, 64, 32, 15), "kind": "deco", "solid": false},
	"bush_low": {"sheet": "biome", "rect": Rect2(2, 68, 30, 11), "kind": "deco", "solid": false},
	"bush_leafy": {"sheet": "biome", "rect": Rect2(128, 64, 16, 15), "kind": "deco", "solid": false},
	"bush_round": {"sheet": "biome", "rect": Rect2(80, 67, 16, 12), "kind": "deco", "solid": false},
	"bush_tall": {"sheet": "biome", "rect": Rect2(129, 18, 14, 11), "kind": "deco", "solid": false},
	"bush_small": {"sheet": "biome", "rect": Rect2(83, 50, 11, 11), "kind": "deco", "solid": false},
	"shrub": {"sheet": "biome", "rect": Rect2(112, 68, 13, 9), "kind": "deco", "solid": false},
	"flower_patch": {"sheet": "biome", "rect": Rect2(100, 4, 10, 10), "kind": "deco", "solid": false},
	"flower_pair": {"sheet": "biome", "rect": Rect2(115, 18, 8, 7), "kind": "deco", "solid": false},
	"tuft_a": {"sheet": "biome", "rect": Rect2(97, 18, 8, 5), "kind": "deco", "solid": false},
	"tuft_b": {"sheet": "biome", "rect": Rect2(84, 23, 8, 5), "kind": "deco", "solid": false},
	"tuft_c": {"sheet": "biome", "rect": Rect2(102, 25, 8, 5), "kind": "deco", "solid": false},
	"tuft_d": {"sheet": "biome", "rect": Rect2(99, 39, 9, 5), "kind": "deco", "solid": false},
	"tuft_e": {"sheet": "biome", "rect": Rect2(99, 54, 9, 5), "kind": "deco", "solid": false},
	"weed_a": {"sheet": "biome", "rect": Rect2(20, 36, 7, 8), "kind": "deco", "solid": false},
	"weed_b": {"sheet": "biome", "rect": Rect2(114, 37, 11, 8), "kind": "deco", "solid": false},
	"weed_c": {"sheet": "biome", "rect": Rect2(114, 52, 11, 8), "kind": "deco", "solid": false},
	"pebble_a": {"sheet": "biome", "rect": Rect2(4, 39, 7, 5), "kind": "deco", "solid": false},
	"pebble_b": {"sheet": "biome", "rect": Rect2(115, 3, 7, 7), "kind": "deco", "solid": false},
	"pebble_c": {"sheet": "biome", "rect": Rect2(136, 3, 7, 7), "kind": "deco", "solid": false},
	"pebble_d": {"sheet": "biome", "rect": Rect2(129, 7, 7, 7), "kind": "deco", "solid": false},
	"pebble_e": {"sheet": "biome", "rect": Rect2(53, 54, 6, 6), "kind": "deco", "solid": false},
	"pebble_f": {"sheet": "biome", "rect": Rect2(38, 56, 4, 4), "kind": "deco", "solid": false},
}

const KINDS := ["tree", "rock", "wood", "deco"]


static func names_of_kind(wanted: String) -> Array[String]:
	var out: Array[String] = []
	for name in PROPS:
		if PROPS[name]["kind"] == wanted:
			out.append(name)
	out.sort()
	return out


static func get_prop(name: String) -> Dictionary:
	return PROPS.get(name, {})


static func sheet_path(name: String) -> String:
	var entry := get_prop(name)
	if entry.is_empty():
		return ""
	return SHEETS[entry["sheet"]]


## 占地几格:对象的像素尺寸向上取整到 16 的倍数(一棵 24x30 的树 = 2x2 格)
static func footprint(name: String) -> Vector2i:
	var rect: Rect2 = get_prop(name)["rect"]
	return Vector2i(ceili(rect.size.x / 16.0), ceili(rect.size.y / 16.0))
