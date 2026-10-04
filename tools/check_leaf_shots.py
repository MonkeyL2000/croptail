#!/usr/bin/env python3
"""核对截图里的荷叶是不是真的画在**水面上**。

引擎里的自检只能证明「节点摆在了水格的坐标上」;这张图证明的是「像素真的画出来了,
而且四周是水色」(用户报过的 bug 是荷叶长在草地上)。

用法:
    python tools/check_leaf_shots.py C:/ct_out/leaf.log
其中 leaf.log 是 `scenes/dev/screenshot.tscn` 打印的 `[leaf]` 行
(每片荷叶一行,带屏幕矩形)。
"""
import collections
import os
import re
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEET = os.path.join(ROOT, "game_source/Objects/Basic_Grass_Biom_things.png")
SHOTS = os.path.join(ROOT, "screenshots")
# 荷叶三张的调色板直接从图集上取,不手抄
TUFTS = [(97, 18, 8, 5), (84, 23, 8, 5), (102, 25, 8, 5)]
WATER = {(155, 212, 195), (177, 224, 190)}
# HUD 五块面板的几何(docs 里写死的那套):压在面板底下的东西本来就看不见
HUD = [(0, 0, 640, 22), (112, 310, 416, 20), (0, 330, 166, 30),
       (524, 330, 54, 30), (582, 330, 54, 30)]
LINE = re.compile(r"\[leaf\] shot (\d+) (\S+) world \[P: \((-?\d+), (-?\d+)\)[^\]]*\]"
                  r" screen \[P: \((-?\d+), (-?\d+)\)")


def palette(image):
    out = set()
    for x, y, w, h in TUFTS:
        for px in image.crop((x, y, x + w, y + h)).getdata():
            if px[3] > 200:
                out.add(px[:3])
    return out


def in_hud(x, y, w, h):
    for hx, hy, hw, hh in HUD:
        if x < hx + hw and hx < x + w and y < hy + hh and hy < y + h:
            return True
    return False


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    colors = palette(Image.open(SHEET).convert("RGBA"))
    leaves = collections.defaultdict(list)
    for line in open(argv[0], encoding="utf-8", errors="replace"):
        found = LINE.search(line)
        if found:
            leaves[int(found.group(1))].append(
                (found.group(2), int(found.group(5)), int(found.group(6))))
    drawn = hidden = off = bad = 0
    for shot in sorted(leaves):
        image = Image.open(os.path.join(SHOTS, "shot_%d.png" % (shot + 1))).convert("RGB")
        for name, sx, sy in leaves[shot]:
            if not (0 <= sx and sx + 8 <= image.width and 0 <= sy and sy + 5 <= image.height):
                off += 1
                continue
            if in_hud(sx, sy, 8, 5):
                hidden += 1
                continue
            hit = sum(1 for px in image.crop((sx, sy, sx + 8, sy + 5)).getdata()
                      if px in colors)
            cell = image.crop((sx - 4, sy - 6, sx + 12, sy + 10))
            water = sum(1 for px in cell.getdata() if px in WATER)
            okay = hit >= 25 and water >= 150
            if not okay:
                bad += 1
            print("   shot_%d %-18s (%3d,%3d) leaf px %2d/40  16x16 water %3d/256 %s"
                  % (shot + 1, name, sx, sy, hit, water, "" if okay else "<-- problem"))
            drawn += 1
    print("== visible lily pads %d: drawn %d, behind the HUD %d, off screen %d, bad %d"
          % (drawn + hidden + off, drawn, hidden, off, bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
