#!/usr/bin/env python3
"""把 `prop_db.gd` 里指定的几条道具放大拼成一张小图,用来**问人**。

`docs/art/props_sheet.png` 是整张图集的对照图(45 条,信息全但密);
这个工具是它的「放大镜」:只挑出可疑的那几条,8 倍放大 + 名字 + 编号,
让用户一眼就能指出「就是这个 / 不是这个」。

用法(项目根目录):
    python tools/zoom_props.py tuft_a tuft_b shrub --out docs/art/x.png
    python tools/zoom_props.py --list          # 列出所有道具名
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from check_props import KIND_RULES, SHEET_FILES, bbox, load_props, sprites_of  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCALE = 8
PAD = 10
LABEL_H = 22
COLS = 8
BG = (32, 32, 40)
FG = (235, 235, 235)
KIND_COLOR = {
    "tree": (120, 220, 120),
    "rock": (200, 200, 200),
    "wood": (220, 170, 110),
    "deco": (220, 130, 200),
    "fence": (150, 190, 255),
    "house": (255, 220, 130),
}


def font(size=14):
    return ImageFont.load_default(size=size)


def main(argv):
    props = load_props()
    if "--list" in argv:
        for name in sorted(props):
            print("%-16s %-5s %s" % (name, props[name]["kind"], props[name]["rect"]))
        return 0
    names = [a for a in argv if not a.startswith("--")]
    out_path = "docs/art/zoom.png"
    if "--out" in argv:
        out_path = argv[argv.index("--out") + 1]
        names = [n for n in names if n != out_path]
    unknown = [n for n in names if n not in props]
    if not names or unknown:
        print("unknown / missing prop names: %s" % (unknown or "none given"))
        print("用 --list 看全部名字")
        return 1

    images = {}
    for key, path in SHEET_FILES.items():
        full = os.path.join(ROOT, path)
        if os.path.exists(full):
            images[key] = Image.open(full).convert("RGBA")

    cell_w = max(props[n]["rect"][2] for n in names) * SCALE + PAD * 2
    cell_h = max(props[n]["rect"][3] for n in names) * SCALE + PAD * 2 + LABEL_H
    rows = (len(names) + COLS - 1) // COLS
    width = cell_w * min(COLS, len(names))
    height = cell_h * rows + 30
    canvas = Image.new("RGB", (width, height), BG)
    draw = ImageDraw.Draw(canvas)
    draw.text((PAD, 8), "zoom x%d  (kind = box colour)" % SCALE, fill=FG, font=font(16))

    counts = {}
    for index, name in enumerate(names):
        entry = props[name]
        image = images[entry["sheet"]]
        x, y, w, h = entry["rect"]
        sprite = image.crop((x, y, x + w, y + h))
        big = sprite.resize((w * SCALE, h * SCALE), Image.NEAREST)
        cx = (index % COLS) * cell_w
        cy = (index // COLS) * cell_h + 30
        # 内容盒(这个精灵自己画的像素范围)也标出来,方便和 rect 对
        box = bbox(next(pts for pts in sprites_of(image) if bbox(pts) == (x, y, w, h))) \
            if any(bbox(pts) == (x, y, w, h) for pts in sprites_of(image)) else None
        canvas.paste(big, (cx + PAD, cy + PAD), big)
        color = KIND_COLOR.get(entry["kind"], FG)
        draw.rectangle([cx + PAD - 1, cy + PAD - 1, cx + PAD + w * SCALE, cy + PAD + h * SCALE],
                       outline=color)
        label = "%d %s  %s" % (index + 1, name, entry["kind"])
        draw.text((cx + PAD, cy + PAD + h * SCALE + 2), label, fill=color, font=font(14))
        draw.text((cx + PAD, cy + PAD + h * SCALE + 2 + 13), "%dx%d @%d,%d" % (w, h, x, y),
                  fill=(150, 150, 160), font=font(12))
        counts[entry["kind"]] = counts.get(entry["kind"], 0) + 1
        if box and box != (x, y, w, h):
            print("  ! %s rect %s != component %s" % (name, (x, y, w, h), box))

    full = os.path.join(ROOT, out_path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    canvas.save(full)
    print("[zoom_props] %d props -> %s (%dx%d)" % (len(names), out_path, width, height))
    print("  kinds: %s" % ", ".join("%s %d" % kv for kv in sorted(counts.items())))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
