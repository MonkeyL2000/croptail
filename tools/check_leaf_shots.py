#!/usr/bin/env python3
"""核对截图里的荷叶是不是真的画在**水面上**。

引擎里的自检只能证明「节点摆在了水格的坐标上」;这张图证明的是「像素真的画出来了,
而且四周是水色」(用户报过的 bug 是荷叶长在草地上)。

用法:
    python tools/check_leaf_shots.py C:/ct_out/leaf.log
其中 leaf.log 是 `scenes/dev/screenshot.tscn` 打印的 `[leaf]` 行
(每片荷叶一行,带屏幕矩形)。

荷叶现在有 4 个变体(`bush_leafy` 是用户点名的那张白边大叶子 + 三张小叶子),
大小不一样,所以调色板**按名字从 `prop_db.gd` 里查出 rect 再取**,
不写死尺寸:日志里的名字是 `<prop>_<x>_<y>`,取最长匹配的那条。
"""
import collections
import os
import re
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEETS = {
    "biome": os.path.join(ROOT, "game_source/Objects/Basic_Grass_Biom_things.png"),
    "materials": os.path.join(ROOT, "game_source/Objects/Basic_tools_and_meterials.png"),
    "fence": os.path.join(ROOT, "game_source/Tilesets/Fences.png"),
    "house": os.path.join(ROOT, "game_source/Objects/Free_Chicken_House.png"),
}
WATER = {(155, 212, 195), (177, 224, 190)}
## 水面格满打满算是 256 像素:叶子本身、水面色阶、岸边阴影都会占掉一些,
## 所以水色只要「明显占多数」就算对(叶子长在草地上时这里会接近 0)。
WATER_MIN = 100
# HUD 五块面板的几何(docs 里写死的那套):压在面板底下的东西本来就看不见
HUD = [(0, 0, 640, 22), (112, 310, 416, 20), (0, 330, 166, 30),
       (524, 330, 54, 30), (582, 330, 54, 30)]
LINE = re.compile(r"\[leaf\] shot (\d+) (\S+) world \[P: \((-?\d+), (-?\d+)\)[^\]]*\]"
                  r" screen \[P: \((-?\d+), (-?\d+)\)")
PROP = re.compile(r'"(\w+)":\s*\{"sheet":\s*"(\w+)",\s*"rect":\s*Rect2\((\d+), (\d+), (\d+), (\d+)\)')


def props():
    """prop_db.gd 里登记的精灵名字 -> (sheet, rect)。"""
    text = open(os.path.join(ROOT, "scripts/world/prop_db.gd"), encoding="utf-8").read()
    out = {}
    for name, sheet, x, y, w, h in PROP.findall(text):
        out[name] = (sheet, (int(x), int(y), int(w), int(h)))
    return out


def lookup(name, table):
    """日志里的 `<prop>_<x>_<y>` -> (prop 名, sheet, rect)。名字取最长匹配。"""
    best = None
    for prop_name in table:
        if name == prop_name or name.startswith(prop_name + "_"):
            if best is None or len(prop_name) > len(best):
                best = prop_name
    if best is None:
        return None
    sheet, rect = table[best]
    return best, sheet, rect


def in_hud(x, y, w, h):
    for hx, hy, hw, hh in HUD:
        if x < hx + hw and hx < x + w and y < hy + hh and hy < y + h:
            return True
    return False


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    table = props()
    sheets = {}

    def sheet_image(sheet_name):
        if sheet_name not in sheets:
            sheets[sheet_name] = Image.open(SHEETS[sheet_name]).convert("RGBA")
        return sheets[sheet_name]

    def sprite(name):
        """(调色板, 不透明像素数, 宽, 高)"""
        found = lookup(name, table)
        if found is None:
            return None
        _, sheet_name, rect = found
        image = sheet_image(sheet_name).crop(
            (rect[0], rect[1], rect[0] + rect[2], rect[1] + rect[3]))
        colors, opaque = set(), 0
        for px in image.getdata():
            if px[3] > 200:
                colors.add(px[:3])
                opaque += 1
        return colors, opaque, rect[2], rect[3]

    leaves = collections.defaultdict(list)
    for line in open(argv[0], encoding="utf-8", errors="replace"):
        found = LINE.search(line)
        if found:
            leaves[int(found.group(1))].append(
                (found.group(2), int(found.group(5)), int(found.group(6))))
    visible = hidden = off = bad = unknown = 0
    for shot in sorted(leaves):
        image = Image.open(os.path.join(ROOT, "screenshots/shot_%d.png" % (shot + 1))).convert("RGB")
        for name, sx, sy in leaves[shot]:
            art = sprite(name)
            if art is None:
                print("   %-20s <-- not in prop_db.gd" % name)
                unknown += 1
                continue
            colors, opaque, w, h = art
            if not (0 <= sx and sx + w <= image.width and 0 <= sy and sy + h <= image.height):
                off += 1
                continue
            if in_hud(sx, sy, w, h):
                hidden += 1
                continue
            hit = sum(1 for px in image.crop((sx, sy, sx + w, sy + h)).getdata() if px in colors)
            cx, cy = sx + w // 2, sy + h // 2
            cell = image.crop((cx - 8, cy - 8, cx + 8, cy + 8))
            water = sum(1 for px in cell.getdata() if px in WATER)
            okay = hit >= max(8, opaque // 2) and water >= WATER_MIN
            if not okay:
                bad += 1
            print("   shot_%d %-20s (%3d,%3d) %2dx%-2d leaf px %3d/%-3d water %3d/256 %s"
                  % (shot + 1, name, sx, sy, w, h, hit, opaque, water,
                     "" if okay else "<-- problem"))
            visible += 1
    print("== lily pads %d: drawn %d, behind the HUD %d, off screen %d, unknown %d, bad %d"
          % (visible + hidden + off + unknown, visible, hidden, off, unknown, bad))
    return 1 if bad or unknown else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
