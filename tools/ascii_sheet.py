#!/usr/bin/env python3
"""把精灵图集打成**字符画**,用来人肉(和 AI)确认「这一格到底是什么」。

## 为什么需要
像素画有时候真的只能看形状:这次的教训是「荷叶被当成灌木撒在草地上」「某几棵树
看上去是倒下的」—— 颜色家族能分出 kind,但分不出「这是树还是倒木」「这是荷叶还是
灌木」。而 `docs/art/*_sheet.png` 那种标注图必须有人看,脚本自己看不见。
1:1 的字符画是本仓库里唯一「脚本也能读形状」的办法:一个像素一个字母,
按调色板家族上色,坦克一样平的地方一眼就能看出剪影。

## 用法(项目根目录)
    # 打整张图(或用 x y w h 只打一块)
    python tools/ascii_sheet.py biome
    python tools/ascii_sheet.py biome 0 48 32 16

    # 按名字筛 prop_db.gd 里的条目,一条一条打出来(看形状对不对)
    python tools/ascii_sheet.py --props tree bush swallow
    python tools/ascii_sheet.py --props            # 全部

字母表:`G` 绿(草/叶) `B` 木色 `S` 灰白(石头) `P` 粉/紫/蓝(花)
`Y` 黄 `w` 白/奶白 `k` 深色描边 `,` 半透明阴影/淡像素 `.` 透明 `?` 认不出的颜色
"""
import os
import re
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SHEETS = {
    "biome": "game_source/Objects/Basic_Grass_Biom_things.png",
    "materials": "game_source/Objects/Basic_tools_and_meterials.png",
    "fence": "game_source/Tilesets/Fences.png",
    "house": "game_source/Objects/Free_Chicken_House.png",
    "plants": "game_source/Objects/Basic_Plants.png",
    "grass": "game_source/Tilesets/Grass.png",
    "water": "game_source/Tilesets/Water.png",
    "paths": "game_source/Objects/Paths.png",
    "tools": "game_source/Characters/Tools.png",
    "chicken": "game_source/Characters/Free Chicken Sprites.png",
    "cow": "game_source/Characters/Free Cow Sprites.png",
    "egg_nest": "game_source/Characters/Egg_And_Nest.png",
    "egg_item": "game_source/Objects/Egg_item.png",
    "milk": "game_source/Objects/Simple_Milk_and_grass_item.png",
    "chest": "game_source/Objects/Chest.png",
    "bridge": "game_source/Objects/Wood_Bridge.png",
    "furniture": "game_source/Objects/Basic_Furniture.png",
}

# 颜色家族(和 check_props.py 的调色板统计同一份)
FAMILIES = {
    "G": [(151, 187, 142), (110, 150, 124), (174, 212, 153), (95, 122, 121),
          (103, 131, 92), (194, 224, 154), (141, 177, 93), (192, 212, 112),
          (120, 161, 88), (130, 168, 132), (107, 116, 112), (86, 101, 96)],
    "B": [(196, 154, 108), (182, 137, 98), (170, 121, 89), (144, 98, 93),
          (220, 185, 138), (149, 122, 75), (232, 207, 166), (117, 76, 96)],
    "S": [(129, 139, 131), (193, 200, 185), (157, 168, 154), (176, 185, 171),
          (84, 89, 89), (84, 87, 94), (243, 244, 231), (243, 216, 197)],
    "P": [(138, 74, 112), (189, 117, 126), (175, 103, 118), (163, 91, 112),
          (217, 154, 154), (232, 181, 172), (105, 74, 135), (144, 104, 159),
          (167, 123, 179), (88, 63, 131), (113, 57, 112), (85, 87, 147),
          (95, 105, 156), (113, 128, 177), (80, 94, 119), (146, 178, 212),
          (203, 224, 222)],
    "Y": [(234, 225, 120), (176, 150, 67), (212, 193, 105), (191, 169, 84),
          (238, 238, 155), (244, 244, 160)],
}
SHADOW = (80, 64, 134)


def classify(pixel):
    r, g, b, a = pixel
    if a < 40:
        return "."
    if a < 160:
        return ","
    if abs(r - SHADOW[0]) < 12 and abs(g - SHADOW[1]) < 12 and abs(b - SHADOW[2]) < 12:
        return ","
    if r > 230 and g > 225 and b > 225:
        return "w"
    if max(r, g, b) < 70:
        return "k"
    for letter, colors in FAMILIES.items():
        if (r, g, b) in colors:
            return letter
    return "?"


def dump_region(path, x0=0, y0=0, width=None, height=None):
    image = Image.open(path).convert("RGBA")
    pixels = image.load()
    width = image.size[0] - x0 if width is None else width
    height = image.size[1] - y0 if height is None else height
    print("### %s  (%dx%d)  region x%d..%d y%d..%d"
          % (path, image.size[0], image.size[1], x0, x0 + width, y0, y0 + height))
    print("    " + "".join(str((x0 + x) // 10 % 10) for x in range(width)))
    print("    " + "".join(str((x0 + x) % 10) for x in range(width)))
    for y in range(y0, y0 + height):
        print("%3d %s" % (y, "".join(classify(pixels[x, y]) for x in range(x0, x0 + width))))


def prop_entries():
    """把 prop_db.gd 里的 PROPS 表读出来(不跑引擎)。"""
    source = open(os.path.join(ROOT, "scripts/world/prop_db.gd"), encoding="utf-8").read()
    pattern = (r'"([^"]+)":\s*\{\s*"sheet":\s*"([^"]+)"\s*,'
               r'\s*"rect":\s*Rect2\(\s*(-?\d+),\s*(-?\d+),\s*(-?\d+),\s*(-?\d+)\s*\)')
    out = []
    for match in re.finditer(pattern, source, re.S):
        name, sheet, x, y, w, h = match.groups()
        out.append((name, sheet, int(x), int(y), int(w), int(h)))
    return out


def sheet_path(key):
    if key in SHEETS:
        return os.path.join(ROOT, SHEETS[key])
    return key


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        print("sheets: " + ", ".join(sorted(SHEETS)))
        return 1
    if args[0] == "--props":
        wanted = args[1:]
        found = 0
        for name, sheet, x, y, w, h in prop_entries():
            if wanted and not any(word in name for word in wanted):
                continue
            found += 1
            print("\n[%s]  sheet=%s rect=(%d,%d,%d,%d)" % (name, sheet, x, y, w, h))
            dump_region(sheet_path(sheet), x, y, w, h)
        if not wanted:
            print("\n-- %d entries" % found)
        return 0
    numbers = [int(value) for value in args[1:]]
    dump_region(sheet_path(args[0]), *numbers)
    return 0


if __name__ == "__main__":
    sys.exit(main())
