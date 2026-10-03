"""把 `Basic Charakter Actions.png` 的版式画出来,给人一眼核。

输出 `docs/art/actions_groups.png`:整张图放大 3 倍,框出 3 个动作组(每组 4 行),
每行标出朝向(front/back/left/right),右侧写明这一组手里那件东西是什么工具、
以及这个结论的证据(见 docs/DECISIONS.md#action-blocks)。

为什么需要它:这张图没有官方图例,「哪一行是哪个朝向」是从像素推的,
所以必须留一张**人能自己看**的对照图,而不是只留一句断言。
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEET = os.path.join(ROOT, "game_source/Characters/Basic Charakter Actions.png")
OUT = os.path.join(ROOT, "docs/art/actions_groups.png")

CELL = 48
SCALE = 3
DIRS = ["front", "back", "left", "right"]
# 组起始行 -> (名字, 证据摘要)
GROUPS = [
    (0, "A  hoe", "metal 92px / wood 56px; long handle, swings down from OVERHEAD"),
    (4, "B  sickle/harvest", "metal 134px / wood 55px; sweeps down from the SIDE"),
    (8, "C  watering can", "metal 432px / wood 0px; big pure-metal, tips low in FRONT"),
]
COLORS = [(255, 80, 80), (80, 200, 120), (90, 160, 255)]


def main() -> None:
    sheet = Image.open(SHEET).convert("RGBA")
    width, height = sheet.size
    assert (width, height) == (2 * CELL, 12 * CELL), sheet.size

    pad_left, pad_right, pad_top = 8, 330, 26
    canvas = Image.new("RGB", (width * SCALE + pad_left + pad_right,
                               height * SCALE + pad_top + 8), (30, 30, 36))
    canvas.paste(sheet.resize((width * SCALE, height * SCALE), Image.NEAREST),
                 (pad_left, pad_top))
    draw = ImageDraw.Draw(canvas)

    # 每一格画细框 + 标帧号
    for col in range(2):
        for row in range(12):
            x0 = pad_left + col * CELL * SCALE
            y0 = pad_top + row * CELL * SCALE
            draw.rectangle([x0, y0, x0 + CELL * SCALE - 1, y0 + CELL * SCALE - 1],
                           outline=(70, 70, 80))

    # 每个动作组画粗框 + 行标签
    for index, (base, name, evidence) in enumerate(GROUPS):
        color = COLORS[index]
        x0 = pad_left - 3
        y0 = pad_top + base * CELL * SCALE - 3
        x1 = pad_left + width * SCALE + 2
        y1 = pad_top + (base + 4) * CELL * SCALE + 2
        draw.rectangle([x0, y0, x1, y1], outline=color, width=3)
        for offset, direction in enumerate(DIRS):
            row = base + offset
            cy = pad_top + (row * CELL + CELL // 2) * SCALE
            draw.text((pad_left + width * SCALE + 14, cy - 6),
                      "row %2d  %s" % (row, direction), fill=color)
        draw.text((x1 + 8, y0 + 4), name, fill=(255, 255, 255))
        draw.text((pad_left + 6, y0 - 18), "group %d = %s" % (index, name), fill=color)
        draw.text((x1 + 8, y0 + 22), evidence, fill=(190, 190, 200))

    draw.text((pad_left, 8),
              "2 columns = the 2 frames of ONE action   |   12 rows = 3 actions x 4 directions",
              fill=(255, 255, 255))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    canvas.save(OUT)
    print("-> %s  (%dx%d)" % (os.path.relpath(OUT, ROOT), canvas.width, canvas.height))


if __name__ == "__main__":
    main()
