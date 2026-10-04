#!/usr/bin/env python3
"""`prop_db.gd` 里那张道具表(rect)的体检。

## 为什么需要
`PROPS` 的 rect 是从 PNG 里量出来的包围盒。图集里**有些精灵是紧挨着摆的**
(灌木右边挨着一截树桩、麦穗长在叶子上),自动涨水会把两块连成一块,矩形里
就塞进了邻居 —— 画到游戏里就是「灌木旁边凭空戳出一截木头」「一株麦子被当成
挡路的树」。这个脚本把这些都挑出来。

## 判据(不看形状,只看调色板)
1. **干净**:把矩形里的像素按颜色家族分类,取**主色家族 ∪ 半透明阴影**的包围盒;
   它应当正好覆盖整条矩形(允许 ±1px,像素画描边常有半个像素的出入)。
   比矩形小 -> 矩形里混了别人的东西。
2. **分类对得上**:粉色 = 花(只能 deco)、灰白 = 石头(不能挂 tree/wood)、
   木色 = 木头、绿色 = 草。
3. **不重不漏**:两条 rect 完全一样 -> 错;大段重叠 -> 警告;
   图集里没被任何 rect 覆盖的精灵 -> 列出来(可能是漏登记的好素材)。

用法(项目根目录):
    python tools/check_props.py            # 体检并打印报告
    python tools/check_props.py --ascii    # 额外把每条 rect 画成字符画

退出码 0 = 全过。
"""
import os
import re
import sys
from collections import Counter, deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEET_FILES = {
    "biome": "game_source/Objects/Basic_Grass_Biom_things.png",
    "materials": "game_source/Objects/Basic_tools_and_meterials.png",
    "fence": "game_source/Tilesets/Fences.png",
    "house": "game_source/Objects/Free_Chicken_House.png",
}
# 拼图块 / 整张图不参与「一条 rect = 一个精灵」的判据
TILING_SHEETS = ("fence", "house")
# 图集里**不当道具用**的精灵:materials 那两格手持工具是 HUD 的斧 / 镐图标
# (见 tool_icons.gd 的 ICONS),它们不该出现在 PROPS 里。
NON_PROP_SPRITES = {(18, 0, 13, 16), (34, 0, 13, 15)}

# 颜色家族(取自 docs/DECISIONS.md#prop-art-classification 的调色板统计)
FAMILIES = {
    "green": [(151, 187, 142), (110, 150, 124), (174, 212, 153), (95, 122, 121),
              (103, 131, 92), (194, 224, 154), (141, 177, 93), (192, 212, 112),
              (120, 161, 88), (130, 168, 132), (107, 116, 112), (86, 101, 96)],
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
SHADOW = (80, 64, 134)
LOOKUP = {}
for _name, _colors in FAMILIES.items():
    for _c in _colors:
        LOOKUP.setdefault(_c, _name)

# 每种 kind 允许/禁止的颜色家族(占透明像素的比例)
# kind -> (必须占多数的家族, 最低占比, 禁止超过 20% 的家族)
KIND_RULES = {
    "tree": ("green", 0.30, ("pink",)),
    # 石头允许带苔(石头上的绿是正常的,rock_small 就有 21%)
    "rock": ("stone", 0.40, ("pink",)),
    "wood": ("wood", 0.50, ("pink", "green")),
    "deco": (None, 0.0, ()),
}
SHARE_LIMIT = 0.20  # 单一家族占比超过它就当「混进了别的东西」


def load_props():
    text = open(os.path.join(ROOT, "scripts/world/prop_db.gd"), encoding="utf-8").read()
    props = {}
    for name, sheet, x, y, w, h in re.findall(
            r'"([a-z_0-9]+)":\s*\{"sheet":\s*"([a-z]+)",\s*"rect":\s*'
            r'Rect2\((-?\d+),\s*(-?\d+),\s*(-?\d+),\s*(-?\d+)\)', text):
        props[name] = {"sheet": sheet, "rect": (int(x), int(y), int(w), int(h))}
    kinds = dict(re.findall(r'"([a-z_0-9]+)":\s*\{[^}]*?"kind":\s*"([a-z]+)"', text))
    for name in props:
        props[name]["kind"] = kinds.get(name, "?")
    return props


def classify(pixel):
    if pixel[3] <= 20:
        return None
    rgb = pixel[:3]
    if rgb == SHADOW:
        return "shadow"
    return LOOKUP.get(rgb, "other")


def analyse(image, rect):
    """返回 (家族计数, 主色家族 ∪ 阴影 的包围盒)。"""
    x, y, w, h = rect
    px = image.load()
    counts = Counter()
    keep = set()
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            family = classify(px[xx, yy])
            if family is None:
                continue
            counts[family] += 1
            keep.add((xx, yy))
    if not counts:
        return counts, None
    main = counts.most_common(1)[0][0]
    if main == "shadow":
        main = counts.most_common(2)[-1][0]
    mask = set()
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            family = classify(px[xx, yy])
            if family in (main, "shadow"):
                mask.add((xx, yy))
    xs = [p[0] for p in mask]
    ys = [p[1] for p in mask]
    return counts, (min(xs), min(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1)


def sprites_of(image, min_px=12):
    """图集里所有不透明像素的连通域(四邻域)—— 用来查「没登记」的精灵。"""
    w, h = image.size
    px = image.load()
    mask = [[px[x, y][3] > 20 for x in range(w)] for y in range(h)]
    seen = [[False] * w for _ in range(h)]
    out = []
    for y0 in range(h):
        for x0 in range(w):
            if not mask[y0][x0] or seen[y0][x0]:
                continue
            queue = deque([(x0, y0)])
            seen[y0][x0] = True
            pts = set()
            while queue:
                x, y = queue.popleft()
                pts.add((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and mask[ny][nx] and not seen[ny][nx]:
                        seen[ny][nx] = True
                        queue.append((nx, ny))
            if len(pts) >= min_px:
                out.append(pts)
    return out


def component_boxes(image):
    """图集里每个连通域的包围盒(小到 4 像素的碎点也算,免得漏掉细节)。"""
    return [bbox(pts) for pts in sprites_of(image, min_px=4)]


def label_map(image, min_px=4):
    """每个不透明像素属于第几个连通域(0 = 透明/太小不算)。"""
    w, h = image.size
    labels = [[0] * w for _ in range(h)]
    for index, pts in enumerate(sprites_of(image, min_px=min_px), start=1):
        for x, y in pts:
            labels[y][x] = index
    return labels


def inside_components(labels, rect):
    """rect 里出现过的连通域编号 -> 像素数。"""
    x, y, w, h = rect
    found = Counter()
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            if labels[yy][xx]:
                found[labels[yy][xx]] += 1
    return found


def component_issues(image, labels, boxes, rect, tolerance=1):
    """一条 rect 应当**正好**圈住一个连通域,而且几乎正好是它的包围盒。

    为什么不能用「包围盒相交」来判断:两个精灵的包围盒可以重叠,但像素并不挨着
    (`bush_leafy` 底下那株小草就是这种)。按像素数才准。

    两个判据(拼图块除外):
      A. rect 里的不透明像素**只属于一个**连通域 —— 否则就是把邻居圈进来了
         (两个精灵颜色一样时,老的调色板判据看不见这种情况)。
      B. 那个连通域的包围盒不能比 rect 大出超过 `tolerance` 像素 —— 否则说明
         rect 把精灵**切掉了一块**(老的 bush_low / bush_wide_alt 就是这样:
         灌木右边连着的树桩被切在矩形外面,画出来灌木是缺一块的)。
    """
    found = inside_components(labels, rect)
    issues = []
    if not found:
        issues.append("no opaque pixel inside this rect -> it is empty")
        return issues
    if len(found) > 1:
        detail = ", ".join("#%d(%dpx @%s)" % (i, n, boxes[i - 1]) for i, n in found.most_common())
        issues.append("holds %d sprites: %s -> a neighbour is glued in" % (len(found), detail))
        return issues
    index = next(iter(found))
    box = boxes[index - 1]
    outside = (box[0] < rect[0] - tolerance or box[1] < rect[1] - tolerance
               or box[0] + box[2] > rect[0] + rect[2] + tolerance
               or box[1] + box[3] > rect[1] + rect[3] + tolerance)
    if outside:
        issues.append("sprite #%d %s is cut off by this rect" % (index, box))
    return issues


def bbox(pts):
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return (min(xs), min(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1)


def main():
    props = load_props()
    images = {}
    for key, path in SHEET_FILES.items():
        full = os.path.join(ROOT, path)
        if os.path.exists(full):
            images[key] = Image.open(full).convert("RGBA")

    problems = []
    warnings = []
    boxes = {key: component_boxes(img) for key, img in images.items()}
    labels = {key: label_map(img) for key, img in images.items()}
    print("== prop art check: %d entries ==" % len(props))

    # --- 1/2: 每条 rect 干净 + 分类对得上 --------------------------------
    clean = 0
    for name in sorted(props):
        entry = props[name]
        sheet, rect, kind = entry["sheet"], entry["rect"], entry["kind"]
        image = images.get(sheet)
        if image is None:
            problems.append("%s: unknown sheet '%s'" % (name, sheet))
            continue
        x, y, w, h = rect
        if x < 0 or y < 0 or x + w > image.size[0] or y + h > image.size[1]:
            problems.append("%s: rect %s outside sheet %s" % (name, rect, image.size))
            continue
        counts, inner = analyse(image, rect)
        total = sum(counts.values())
        opaque_ratio = total / float(w * h)
        issues = []
        if opaque_ratio < 0.15:
            issues.append("almost empty (%.0f%% opaque)" % (opaque_ratio * 100))
        if sheet not in TILING_SHEETS and inner is not None:
            tolerance = 1
            if (inner[0] < x - tolerance or inner[1] < y - tolerance
                    or inner[2] > w + 2 * tolerance or inner[3] > h + 2 * tolerance):
                issues.append("rect is bigger than the art (main-colour bbox %s) -> "
                              "a neighbouring sprite is glued in" % (inner,))
        family, need, forbidden = KIND_RULES.get(kind, (None, 0.0, ()))
        shares = {k: v / float(total) for k, v in counts.items()}
        if family:
            if shares.get(family, 0.0) < need:
                issues.append("kind '%s' should be mostly %s but only %.0f%% is"
                              % (kind, family, shares.get(family, 0.0) * 100))
        for family in forbidden:
            if shares.get(family, 0.0) > SHARE_LIMIT:
                issues.append("kind '%s' contains %.0f%% %s" % (kind, shares[family] * 100, family))
        # 连通域判据:一条 rect = 一个精灵,而且正好是它的包围盒(拼图块除外)
        if sheet not in TILING_SHEETS and sheet in boxes:
            issues.extend(component_issues(image, labels[sheet], boxes[sheet], (x, y, w, h)))
        if issues:
            for issue in issues:
                problems.append("%-14s kind=%-5s rect=%-18s %s" % (name, kind, str(rect), issue))
        else:
            clean += 1
        print("    %-14s %-5s %-18s %s" % (name, kind, str(rect),
              " ".join("%s:%.0f%%" % (k, shares[k] * 100)
                       for k, _ in counts.most_common(4))))
    print("-- %d/%d entries look clean" % (clean, len(props)))

    # --- 3: 不重不漏 -----------------------------------------------------
    seen_rects = {}
    for name in sorted(props):
        entry = props[name]
        key = (entry["sheet"], entry["rect"])
        if key in seen_rects:
            problems.append("%s and %s share the same rect" % (seen_rects[key], name))
        seen_rects[key] = name
    by_sheet = {}
    for name, entry in props.items():
        by_sheet.setdefault(entry["sheet"], []).append((name, entry["rect"]))
    for sheet, entries in by_sheet.items():
        for i in range(len(entries)):
            for j in range(i + 1, len(entries)):
                a, ra = entries[i]
                b, rb = entries[j]
                ox = min(ra[0] + ra[2], rb[0] + rb[2]) - max(ra[0], rb[0])
                oy = min(ra[1] + ra[3], rb[1] + rb[3]) - max(ra[1], rb[1])
                if ox > 1 and oy > 1:
                    warnings.append("%s and %s overlap by %dx%d px" % (a, b, ox, oy))

    for sheet in ("biome", "materials"):
        image = images.get(sheet)
        if image is None:
            continue
        used = [entry["rect"] for entry in props.values() if entry["sheet"] == sheet]
        unused = []
        for pts in sprites_of(image):
            box = bbox(pts)
            if box in NON_PROP_SPRITES:
                continue
            covered = sum(1 for p in pts if any(
                rx <= p[0] < rx + rw and ry <= p[1] < ry + rh
                for (rx, ry, rw, rh) in used))
            if covered < 0.8 * len(pts):
                unused.append((box, len(pts)))
        if unused:
            print("-- %s: %d sprite(s) not registered as a prop:" % (sheet, len(unused)))
            for box, size in sorted(unused):
                print("     %-18s %d px" % (str(box), size))

    kinds = Counter(entry["kind"] for entry in props.values())
    print("-- kinds: %s" % ", ".join("%s %d" % (k, n) for k, n in sorted(kinds.items())))
    for warning in warnings:
        print("WARN %s" % warning)
    for problem in problems:
        print("FAIL %s" % problem)
    print("== %d problems, %d warnings ==" % (len(problems), len(warnings)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
