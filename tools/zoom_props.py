#!/usr/bin/env python3
"""把 `prop_db.gd` 里的道具放大拼成一张**带编号的小图**,用来**问人 / 认素材**。

`docs/art/props_sheet.png` 是整张图集的对照图(45 条,信息全但密);
这个工具是它的「放大镜」:只挑要看的几条(或 `--all` 全部),8 倍放大,
左上角印一个**大编号**,底下写名字和 kind —— 用户看到画面上哪个东西不对,
报个号就行(`python tools/zoom_props.py --all` → `docs/art/props_numbered.png`)。

用法(项目根目录):
    python tools/zoom_props.py --all --out docs/art/props_numbered.png
    python tools/zoom_props.py tuft_a wood_log --out docs/art/x.png
    python tools/zoom_props.py --list          # 列出所有道具名
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from check_props import SHEET_FILES, load_props  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCALE = 8
PAD = 12
LABEL_H = 40
KIND_ORDER = ["tree", "rock", "wood", "pond", "deco", "fence", "house"]
BG = (32, 32, 40)
FG = (235, 235, 235)
MUTED = (150, 150, 160)
NUMBER = (255, 210, 90)
KIND_COLOR = {
    "tree": (120, 220, 120),
    "rock": (200, 200, 200),
    "wood": (220, 170, 110),
    "pond": (110, 200, 240),
    "deco": (220, 130, 200),
    "fence": (150, 190, 255),
    "house": (255, 220, 130),
}


def font(size=14):
    return ImageFont.load_default(size=size)


def ordering(name, props):
    kind = props[name]["kind"]
    return (KIND_ORDER.index(kind) if kind in KIND_ORDER else 99, kind, name)


def main(argv):
    props = load_props()
    if "--list" in argv:
        for name in sorted(props, key=lambda n: ordering(n, props)):
            print("%-16s %-5s %s" % (name, props[name]["kind"], props[name]["rect"]))
        return 0
    out_path = "docs/art/zoom.png"
    if "--out" in argv:
        out_path = argv[argv.index("--out") + 1]
    names = [a for a in argv if not a.startswith("--") and a != out_path]
    if "--all" in argv:
        names = sorted(props, key=lambda n: ordering(n, props))
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

    cols = 6 if len(names) > 16 else min(8, len(names))
    # 编号用**全局序号**(按 kind + 名字排),不是这张图里的第几个 ——
    # 这样同一张道具在 `--all` 和随手挑几张的图里号是一样的,用户报号不会歧义。
    every = sorted(props, key=lambda n: ordering(n, props))
    cell_w = max(props[n]["rect"][2] for n in names) * SCALE + PAD * 2
    cell_h = max(props[n]["rect"][3] for n in names) * SCALE + PAD * 2 + LABEL_H
    rows = (len(names) + cols - 1) // cols
    width = cell_w * min(cols, len(names))
    height = cell_h * rows + 34
    canvas = Image.new("RGB", (width, height), BG)
    draw = ImageDraw.Draw(canvas)
    draw.text((PAD, 8), "prop_db.gd  x%d   (kind = box colour; report the number)" % SCALE,
              fill=FG, font=font(18))

    kinds = {}
    for index, name in enumerate(names):
        entry = props[name]
        image = images[entry["sheet"]]
        x, y, w, h = entry["rect"]
        sprite = image.crop((x, y, x + w, y + h))
        big = sprite.resize((w * SCALE, h * SCALE), Image.NEAREST)
        cx = (index % cols) * cell_w
        cy = (index // cols) * cell_h + 34
        canvas.paste(big, (cx + PAD, cy + PAD + 18), big)
        color = KIND_COLOR.get(entry["kind"], FG)
        draw.rectangle([cx + PAD - 1, cy + PAD + 17, cx + PAD + w * SCALE, cy + PAD + h * SCALE + 18],
                       outline=color)
        # 大编号:用户只要报这个号就行
        draw.text((cx + PAD, cy + 2), "#%d" % (every.index(name) + 1), fill=NUMBER, font=font(26))
        draw.text((cx + PAD + 58, cy + 8), name, fill=color, font=font(16))
        draw.text((cx + PAD, cy + PAD + h * SCALE + 22),
                  "%s  %dx%d @%d,%d" % (entry["kind"], w, h, x, y), fill=MUTED, font=font(13))
        kinds[entry["kind"]] = kinds.get(entry["kind"], 0) + 1

    full = os.path.join(ROOT, out_path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    canvas.save(full)
    print("[zoom_props] %d props -> %s (%dx%d)" % (len(names), out_path, width, height))
    print("  kinds: %s" % ", ".join("%s %d" % kv for kv in sorted(kinds.items())))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
