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
## ## 为什么每条 rect 都要「一像素不多」
##
## 图集里**有些精灵是紧挨着摆的**(灌木右边挨着一截树桩、麦穗长在叶子上面),
## 自动涨水会把它们连成一块,于是矩形里塞进了邻居 —— 画到游戏里就是「灌木旁边
## 莫名其妙戳出来一截木头」。所以现在用 `tools/check_props.py` 体检每一条:
## 拿**主色类 ∪ 阴影**的包围盒去比,比矩形小就说明矩形里混了别人的东西。
## 改完表一定要跑一遍,再对 `tools/annotate_props.py` 生成的
## `docs/art/props_sheet.png` 看一眼(人肉复核用的对照图)。
##
## ## 分类
##
## 靠**调色板**判断,不是靠形状猜(见 docs/DECISIONS.md#prop-art-classification):
##   - 绿色占多数 -> 灌木 / 草簇 / 花(花有绿茎,所以粉 + 绿 = 花)
##   - 灰白(石色)占多数 -> 石头(挡路,镐头能挖)
##   - 褐色(木色)占多数 -> 木头 / 树桩(挡路,斧头能砍)
##
## 注意:**粉色是花,不是石头**。之前的表把 `(82,2)` `(33,33)` `(64,49)` 三朵
## 大粉花当成了石头(还标了 solid),玩家会撞在花上 —— 现在它们都归 deco。

## 每一行的格式:名字 -> { sheet: 图集路径 key, rect: Rect2, kind: 种类, solid: 是否挡路 }
## rect 是**源图集里的像素矩形**,不是格子。
const SHEETS := {
	"biome": "res://game_source/Objects/Basic_Grass_Biom_things.png",
	"materials": "res://game_source/Objects/Basic_tools_and_meterials.png",
	"fence": "res://game_source/Tilesets/Fences.png",
	"house": "res://game_source/Objects/Free_Chicken_House.png",
}

const PROPS := {
	# --- 树:斧头能砍,给 2 木材 ------------------------------------------
	# 图集里只有三棵树;它们都「站着」(矩形高 > 宽)。
	"tree_small": {"sheet": "biome", "rect": Rect2(1, 0, 14, 29), "kind": "tree", "solid": true},
	"tree_big": {"sheet": "biome", "rect": Rect2(20, 1, 24, 31), "kind": "tree", "solid": true},
	# 轮廓和 tree_big 一模一样,但树冠上点了粉花 —— 是**开花的树**,不是镜像贴图
	"tree_flower": {"sheet": "biome", "rect": Rect2(52, 1, 24, 31), "kind": "tree", "solid": true},

	# --- 石头:镐头能挖,给 1 石头 ----------------------------------------
	"rock_low": {"sheet": "materials", "rect": Rect2(0, 4, 16, 10), "kind": "rock", "solid": true},
	"rock_round": {"sheet": "materials", "rect": Rect2(1, 18, 14, 13), "kind": "rock", "solid": true},
	"rock_mossy": {"sheet": "biome", "rect": Rect2(128, 18, 16, 12), "kind": "rock", "solid": true},
	"rock_boulder": {"sheet": "biome", "rect": Rect2(80, 67, 16, 12), "kind": "rock", "solid": true},
	"rock_small": {"sheet": "biome", "rect": Rect2(99, 68, 10, 8), "kind": "rock", "solid": true},
	"rock_chip": {"sheet": "biome", "rect": Rect2(114, 18, 10, 8), "kind": "rock", "solid": true},

	# --- 木头 / 树桩:斧头能砍,给 1 木材 --------------------------------
	"wood_log": {"sheet": "materials", "rect": Rect2(17, 17, 13, 14), "kind": "wood", "solid": true},
	"wood_log_big": {"sheet": "materials", "rect": Rect2(33, 17, 14, 14), "kind": "wood", "solid": true},
	"wood_pile": {"sheet": "biome", "rect": Rect2(80, 35, 16, 10), "kind": "wood", "solid": true},
	"stump_round": {"sheet": "biome", "rect": Rect2(67, 36, 10, 10), "kind": "wood", "solid": true},
	"stump_small": {"sheet": "biome", "rect": Rect2(52, 36, 8, 10), "kind": "wood", "solid": true},
	"stump_log": {"sheet": "biome", "rect": Rect2(60, 68, 8, 9), "kind": "wood", "solid": true},
	"stump_tiny": {"sheet": "biome", "rect": Rect2(25, 71, 7, 7), "kind": "wood", "solid": true},

	# --- 灌木 / 草簇 / 麦子:不挡路,也不给东西 ---------------------------
	# 前两条的矩形右边被**切掉**过:原来把紧挨着的一截树桩也圈进来了,
	# 于是灌木右边凭空戳出一段木头(看着就像倒下的树)。那两截树桩现在
	# 单独成了 stump_log / stump_tiny,归木头那组。
	"bush_wide": {"sheet": "biome", "rect": Rect2(0, 48, 32, 16), "kind": "deco", "solid": false},
	"bush_wide_alt": {"sheet": "biome", "rect": Rect2(36, 64, 24, 16), "kind": "deco", "solid": false},
	"bush_low": {"sheet": "biome", "rect": Rect2(2, 68, 23, 12), "kind": "deco", "solid": false},
	"bush_leafy": {"sheet": "biome", "rect": Rect2(128, 64, 14, 11), "kind": "deco", "solid": false},
	"shrub": {"sheet": "biome", "rect": Rect2(112, 68, 13, 9), "kind": "deco", "solid": false},
	"sprig_b": {"sheet": "biome", "rect": Rect2(137, 74, 7, 5), "kind": "deco", "solid": false},
	"tuft_a": {"sheet": "biome", "rect": Rect2(97, 18, 8, 5), "kind": "deco", "solid": false},
	"tuft_b": {"sheet": "biome", "rect": Rect2(84, 23, 8, 5), "kind": "deco", "solid": false},
	"tuft_c": {"sheet": "biome", "rect": Rect2(102, 25, 8, 5), "kind": "deco", "solid": false},
	# 麦穗:一根高秆 + 顶上一颗金色的穗,底下是细叶(以前被当成「秋天的树」
	# 塞进了 tree 那组,还带 solid —— 玩家会撞在一株麦子上)
	"wheat_plant": {"sheet": "biome", "rect": Rect2(129, 34, 14, 29), "kind": "deco", "solid": false},

	# --- 花:全是粉色/黄色,不挡路 ---------------------------------------
	"flower_big": {"sheet": "biome", "rect": Rect2(33, 33, 13, 14), "kind": "deco", "solid": false},
	"flower_rose": {"sheet": "biome", "rect": Rect2(64, 49, 16, 14), "kind": "deco", "solid": false},
	"flower_pink": {"sheet": "biome", "rect": Rect2(82, 2, 13, 13), "kind": "deco", "solid": false},
	"flower_patch": {"sheet": "biome", "rect": Rect2(100, 4, 10, 11), "kind": "deco", "solid": false},
	"flower_green": {"sheet": "biome", "rect": Rect2(83, 50, 11, 12), "kind": "deco", "solid": false},
	"flower_pink_b": {"sheet": "biome", "rect": Rect2(114, 52, 11, 9), "kind": "deco", "solid": false},
	"flower_pink_c": {"sheet": "biome", "rect": Rect2(99, 54, 9, 6), "kind": "deco", "solid": false},
	"flower_pink_d": {"sheet": "biome", "rect": Rect2(20, 36, 7, 8), "kind": "deco", "solid": false},
	"flower_yellow": {"sheet": "biome", "rect": Rect2(114, 37, 11, 9), "kind": "deco", "solid": false},
	"flower_yellow_b": {"sheet": "biome", "rect": Rect2(99, 39, 9, 6), "kind": "deco", "solid": false},
	"flower_small_a": {"sheet": "biome", "rect": Rect2(115, 3, 7, 8), "kind": "deco", "solid": false},
	"flower_small_b": {"sheet": "biome", "rect": Rect2(136, 3, 7, 8), "kind": "deco", "solid": false},
	"flower_small_c": {"sheet": "biome", "rect": Rect2(129, 7, 7, 8), "kind": "deco", "solid": false},
	"flower_tiny_a": {"sheet": "biome", "rect": Rect2(4, 39, 7, 5), "kind": "deco", "solid": false},
	"flower_tiny_b": {"sheet": "biome", "rect": Rect2(53, 54, 6, 6), "kind": "deco", "solid": false},
	"flower_bud": {"sheet": "biome", "rect": Rect2(38, 56, 4, 4), "kind": "deco", "solid": false},

	# --- 围栏(Tilesets/Fences.png 是 4x4 个 16x16 格)------------------
	#
	# 那张图是「十字路口」的写法:每格都是一根柱子 + 往左右伸的横杆。
	#   col 0 = 只有柱子  col 1 = 柱 + 右横杆  col 2 = 柱 + 左右横杆  col 3 = 柱 + 左横杆
	#   row 0/3 = 柱子的顶/底段,row 1/2 = 中段(横杆在中段上,高度一样)
	# 所以**横排**围栏用 row 1:左端用 col 1、中间用 col 2、右端用 col 3。
	# 竖排只有柱子可拼 —— 这张图里根本没有竖向横杆,别凭空造。
	"fence_end_left": {"sheet": "fence", "rect": Rect2(16, 16, 16, 16), "kind": "fence", "solid": true},
	"fence_mid": {"sheet": "fence", "rect": Rect2(32, 16, 16, 16), "kind": "fence", "solid": true},
	"fence_end_right": {"sheet": "fence", "rect": Rect2(48, 16, 16, 16), "kind": "fence", "solid": true},
	"fence_post": {"sheet": "fence", "rect": Rect2(0, 16, 16, 16), "kind": "fence", "solid": true},

	# --- 鸡舍(3x3 格的一整栋房子)-----------------------------------------
	"chicken_house": {"sheet": "house", "rect": Rect2(0, 0, 48, 48), "kind": "house", "solid": true},
}

## 会被随机撒出去的种类。fence / house 不在里面:它们是手摆的位置
## (见 farm_props.gd 的 _place_landmarks),随机撒会撒出断头的围栏。
const SCATTER_KINDS := ["tree", "rock", "wood", "deco"]
## 所有种类:HUD 不算它,但统计输出要能列出围栏和鸡舍
const KINDS := ["tree", "rock", "wood", "deco", "fence", "house"]


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
