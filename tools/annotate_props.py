#!/usr/bin/env python3
"""把人肉对照图生成出来:把 `prop_db.gd` 里每条 rect 画到图集上并编号。

这张图是给**人**看的 —— 助手看不到图像,所有图形判断都得先落到数字上;
这张图把「表里第 N 条 = 图集上哪一块」摊开来,人可以一眼指出「第 7 条不对」。

输出:`docs/art/props_sheet.png`
    - 上半张 = `Basic_Grass_Biom_things.png` 放大 6 倍,每条 rect 描边 + 编号
    - 中间   = `Basic_tools_and_meterials.png` 同样处理
    - 下半张 = 编号 -> 名字 / kind / rect / 占地几格 / 是否挡路

颜色按 kind 分:树=绿,石头=灰,木头=棕,装饰=洋红,围栏=橙,房子=蓝。

用法(项目根目录):
    python tools/annotate_props.py
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from check_props import NON_PROP_SPRITES, ROOT, SHEET_FILES, TILING_SHEETS, load_props  # noqa: E402

SCALE = 6
KIND_COLORS = {
    "tree": (0, 220, 0),
    "rock": (200, 200, 200),
    "wood": (230, 140, 60),
    "deco": (255, 0, 255),
    "fence": (255, 170, 0),
    "house": (80, 140, 255),
}
ORDER = ["tree", "rock", "wood", "deco", "fence", "house", "?"]
FONT_SIZE = 18


def font(size=FONT_SIZE):
    return ImageFont.load_default(size=size)


def footprints(rect):
    return (max(1, -(-rect[2] // 16)), max(1, -(-rect[3] // 16)))


def draw_sheet(image, entries, offset_y, out, draw, number_of):
    """把一张图集放大画上去,给每条 rect 描边并写编号。返回这张图占的高度。"""
    big = image.resize((image.size[0] * SCALE, image.size[1] * SCALE), Image.NEAREST)
    out.paste(big, (40, offset_y))
    for name, entry in entries:
        x, y, w, h = entry["rect"]
        color = KIND_COLORS.get(entry["kind"], (255, 255, 0))
        box = [40 + x * SCALE, offset_y + y * SCALE,
               40 + (x + w) * SCALE - 1, offset_y + (y + h) * SCALE - 1]
        draw.rectangle(box, outline=color, width=2)
        label = str(number_of[name])
        draw.rectangle([box[0], box[1], box[0] + 7 * len(label) + 3, box[1] + 17],
                       fill=(0, 0, 0))
        draw.text((box[0] + 2, box[1] + 1), label, fill=color, font=font(15))
    # 图集里不当道具用的精灵:画个红框标出来,免得下次又把它当漏登记
    for box in NON_PROP_SPRITES:
        if box[0] * SCALE >= big.size[0]:
            continue
        x, y, w, h = box
        draw.rectangle([40 + x * SCALE, offset_y + y * SCALE,
                        40 + (x + w) * SCALE - 1, offset_y + (y + h) * SCALE - 1],
                       outline=(255, 0, 0), width=1)
        draw.text((40 + x * SCALE, offset_y + y * SCALE - 16), "not a prop: tool icon",
                  fill=(255, 80, 80), font=font(13))
    return big.size[1]


def main():
    props = load_props()
    sheet_names = [s for s in ("biome", "materials") if any(
        e["sheet"] == s for e in props.values())]
    images = {s: Image.open(os.path.join(ROOT, SHEET_FILES[s])).convert("RGBA")
              for s in sheet_names}

    # 编号:按 kind 排序,一张图一条编号(跨图集也连续)
    ordered = sorted(props.items(), key=lambda kv: (ORDER.index(kv[1]["kind"]), kv[0]))
    number_of = {name: i + 1 for i, (name, _) in enumerate(ordered)}

    rows = len(ordered)
    legend_h = 30 + ((rows + 2) // 3) * 24
    width = 40 * 2 + max(images[s].size[0] * SCALE for s in sheet_names) + 360
    height = 60 + sum(images[s].size[1] * SCALE + 70 for s in sheet_names) + legend_h
    out = Image.new("RGB", (width, height), (24, 24, 32))
    draw = ImageDraw.Draw(out)
    draw.text((40, 20), "croptail props contact sheet  (rects come from scripts/world/prop_db.gd)",
              fill=(255, 255, 255), font=font(22))

    y = 60
    for sheet in sheet_names:
        entries = [(n, e) for n, e in ordered if e["sheet"] == sheet]
        draw.text((40, y - 18), "%s  %s  (%d props)" % (SHEET_FILES[sheet], images[sheet].size, len(entries)),
                  fill=(180, 220, 255), font=font(16))
        y += 8
        y += draw_sheet(images[sheet], entries, y, out, draw, number_of) + 40

    y += 10
    draw.text((40, y), "legend  (rectangle colour = kind, number = prop id)", fill=(255, 255, 255), font=font(18))
    y += 26
    x0 = 40
    for kind in ORDER:
        draw.rectangle([x0, y + 4, x0 + 14, y + 18], outline=KIND_COLORS.get(kind, (255, 255, 0)), width=2)
        draw.text((x0 + 20, y), kind, fill=(230, 230, 230), font=font(16))
        x0 += 110
    draw.rectangle([x0, y + 4, x0 + 14, y + 18], outline=(255, 0, 0), width=1)
    draw.text((x0 + 20, y), "not a prop", fill=(230, 230, 230), font=font(16))
    y += 30

    columns = 3
    per_column = (rows + columns - 1) // columns
    for index, (name, entry) in enumerate(ordered):
        column = index // per_column
        line = index % per_column
        x = 40 + column * ((width - 80) // columns)
        yy = y + line * 24
        color = KIND_COLORS.get(entry["kind"], (255, 255, 0))
        cells = footprints(entry["rect"])
        draw.text((x, yy), "%3d %-15s %-5s %-18s %dx%d cell %s" % (
            number_of[name], name, entry["kind"], str(entry["rect"]),
            cells[0], cells[1], "solid" if entry.get("solid", True) else ""),
            fill=color, font=font(16))

    out_path = os.path.join(ROOT, "docs/art/props_sheet.png")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    out.save(out_path)
    print("[annotate_props] %d props -> %s (%dx%d)" % (len(ordered), out_path, width, height))


if __name__ == "__main__":
    main()
