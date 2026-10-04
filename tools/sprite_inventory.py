"""Sprite inventory: 把一张素材图里**每一个连通块**列出来。

为什么要这个工具:`prop_db.gd` 里的 rect 曾经是从 flood-fill 抄出来的,
所以会把**相邻的两个精灵粘在一起**(两个绿色精灵粘一起时调色板检查发现不了)。
反过来,如果某个 rect 是空的、或者某个连通块没被任何 rect 覆盖,
也就说明有素材没被用上(或者用错了)。

输出:
  每个连通块: bbox / 像素数 / 主要颜色族 / 缩略 ASCII 图
  以及每个族(rect)覆盖了几个连通块 —— 应该**正好 1 个**。

用法:
  python tools/sprite_inventory.py biome            # 列出 biome 表所有连通块
  python tools/sprite_inventory.py materials --rects # 带 prop_db.gd 交叉核对
  python tools/sprite_inventory.py biome 100 40 44 40  # 只列某区域
"""

from __future__ import annotations

import re
import sys
from collections import Counter, deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SHEETS = {
    "biome": "game_source/Objects/Basic_Grass_Biom_things.png",
    "materials": "game_source/Objects/Basic_tools_and_meterials.png",
    "tools": "game_source/Objects/Tools.png",
    "plants": "game_source/Objects/Basic_Plants.png",
    "grass": "game_source/Tilesets/Grass.png",
    "water": "game_source/Tilesets/Water.png",
    "paths": "game_source/Objects/Paths.png",
    "bridge": "game_source/Objects/Wood_Bridge.png",
    "chest": "game_source/Objects/Chest.png",
    "fence": "game_source/Objects/Fences.png",
    "house": "game_source/Objects/Free_Chicken_House.png",
    "chicken": "game_source/Characters/Free Chicken Sprites.png",
    "cow": "game_source/Characters/Free Cow Sprites.png",
    "egg_nest": "game_source/Objects/Egg_And_Nest.png",
    "egg_item": "game_source/Objects/Egg_item.png",
    "milk": "game_source/Objects/Simple_Milk_and_grass_item.png",
    "furniture": "game_source/Objects/Basic_Furniture.png",
}

# 颜色族(和 tools/check_props.py 的 FAMILIES 保持一致,少一个 shadow)
FAMILIES = {
    "green": [(151, 187, 142), (110, 150, 124), (174, 212, 153), (95, 122, 121),
              (103, 131, 92), (194, 224, 154), (141, 177, 93), (192, 212, 112),
              (120, 161, 88), (130, 168, 132), (107, 116, 112), (86, 101, 96),
              (164, 194, 99)],
    "wood": [(196, 154, 108), (182, 137, 98), (170, 121, 89), (144, 98, 93),
             (220, 185, 138), (149, 122, 75), (232, 207, 166), (117, 76, 96)],
    "stone": [(129, 139, 131), (193, 200, 185), (157, 168, 154), (176, 185, 171),
              (84, 89, 89), (84, 87, 94), (243, 244, 231), (243, 216, 197)],
    "pink": [(138, 74, 112), (189, 117, 126), (175, 103, 118), (163, 91, 112),
             (217, 154, 154), (232, 181, 172), (105, 74, 135), (144, 104, 159),
             (167, 123, 179), (88, 63, 131), (113, 57, 112), (85, 87, 147),
             (95, 105, 156), (113, 128, 177), (80, 94, 119), (146, 178, 212),
             (203, 224, 222)],
    "yellow": [(234, 225, 120), (176, 150, 67), (212, 193, 105), (191, 169, 84),
               (238, 238, 155), (244, 244, 160)],
}
LETTER = {"green": "G", "wood": "B", "stone": "S", "pink": "P", "yellow": "Y"}


def family_of(rgb):
    for name, colours in FAMILIES.items():
        if rgb in colours:
            return name
    r, g, b = rgb
    if r > 200 and g > 200 and b > 200:
        return "white"
    if r < 60 and g < 60 and b < 60:
        return "dark"
    return "?"


def components(img, x0, y0, x1, y1, min_px=4):
    px = img.load()
    seen = set()
    out = []
    for y in range(y0, y1):
        for x in range(x0, x1):
            if (x, y) in seen or px[x, y][3] <= 0:
                continue
            q = deque([(x, y)])
            seen.add((x, y))
            pts = []
            while q:
                cx, cy = q.popleft()
                pts.append((cx, cy))
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if x0 <= nx < x1 and y0 <= ny < y1 and (nx, ny) not in seen and px[nx, ny][3] > 0:
                        seen.add((nx, ny))
                        q.append((nx, ny))
            if len(pts) >= min_px:
                out.append(pts)
    out.sort(key=lambda pts: (min(p[1] for p in pts), min(p[0] for p in pts)))
    return out


def thumb(pts, img):
    px = img.load()
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    bx, by = min(xs), min(ys)
    w, h = max(xs) - bx + 1, max(ys) - by + 1
    cell = set(pts)
    lines = []
    for y in range(h):
        row = []
        for x in range(w):
            if (bx + x, by + y) in cell:
                row.append(LETTER.get(family_of(px[bx + x, by + y][:3]), "?"))
            else:
                row.append(" ")
        lines.append("".join(row).rstrip())
    return bx, by, w, h, lines


def parse_rects():
    """从 prop_db.gd 里抠出每一条 PROPS 的 sheet / rect。"""
    src = (ROOT / "scripts/world/prop_db.gd").read_text(encoding="utf-8")
    out = []
    # 一次匹配 "name": { ... "sheet": "x", ... Rect2(a, b, c, d) ... }
    for m in re.finditer(r'"([a-z0-9_]+)"\s*:\s*\{(.*?)\}', src, re.S):
        name, body = m.group(1), m.group(2)
        sm = re.search(r'"sheet"\s*:\s*"([a-z_]+)"', body)
        rm = re.search(r'Rect2\(\s*(-?\d+)\s*,\s*(-?\d+)\s*,\s*(-?\d+)\s*,\s*(-?\d+)\s*\)', body)
        if sm and rm:
            out.append((name, sm.group(1), tuple(int(rm.group(i)) for i in range(1, 5))))
    return out


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        print("sheets:", ", ".join(SHEETS))
        return
    key = args[0]
    path = Path(key) if key.endswith(".png") else ROOT / SHEETS.get(key, "")
    if not path.exists():
        print("no such sheet:", key)
        return
    img = Image.open(path).convert("RGBA")
    show_rects = "--rects" in args
    args = [a for a in args if a != "--rects"]
    nums = [int(a) for a in args[1:5]]
    x0, y0 = (nums[0], nums[1]) if len(nums) >= 2 else (0, 0)
    w, h = (nums[2], nums[3]) if len(nums) >= 4 else (img.size[0] - x0, img.size[1] - y0)
    x1, y1 = x0 + w, y0 + h
    print("### %s  (%dx%d) region x%d..%d y%d..%d" % (path.relative_to(ROOT), img.size[0], img.size[1], x0, x1, y0, y1))

    comps = components(img, x0, y0, x1, y1)
    rects = [r for r in parse_rects() if r[1] == key]
    for i, pts in enumerate(comps):
        bx, by, bw, bh, lines = thumb(pts, img)
        cover = [n for n, _s, r in rects
                 if r[0] <= bx and r[1] <= by and bx + bw <= r[0] + r[2] and by + bh <= r[1] + r[3]]
        overlap = [n for n, _s, r in rects if not (bx >= r[0] + r[2] or bx + bw <= r[0] or by >= r[1] + r[3] or by + bh <= r[1])]
        tag = ""
        if show_rects:
            tag = "  covered_by=%s" % (cover or "NOTHING")
            if len(cover) != 1:
                tag += "  <-- 注意 (%d 条 rect 覆盖)" % len(cover)
            elif len(overlap) > 1:
                pass
        print("--- #%d  bbox=(%d,%d,%d,%d)  px=%d%s" % (i, bx, by, bw, bh, len(pts), tag))
        for line in lines:
            print("    " + line)
    if show_rects:
        print("=== rects on this sheet:")
        for name, _s, r in rects:
            inside = [i for i, pts in enumerate(comps)
                      if r[0] <= min(p[0] for p in pts) and r[1] <= min(p[1] for p in pts)
                      and max(p[0] for p in pts) < r[0] + r[2] and max(p[1] for p in pts) < r[1] + r[3]]
            if len(inside) != 1:
                print("  %-16s %-22s -> covers %d components %s  <-- 应该正好 1" % (name, r, len(inside), inside))
        print("  其余 rect 正常(各覆盖 1 个连通块)")


if __name__ == "__main__":
    main()
