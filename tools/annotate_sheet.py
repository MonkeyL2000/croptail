#!/usr/bin/env python3
"""给图集画上网格和坐标标签,存成 `docs/art/*.png`。

为什么要它:Sprout Lands 的图集**没有图例**,格子含义只能靠读像素猜。
猜测写在 `scripts/world/prop_db.gd` 和 `scripts/ui/tool_icons.gd` 两张表里,
而只有人能看着图确认「第 3 行第 0 格到底是不是锄头」。有了带坐标的放大图,
就可以直接说「不对,锄头在 (2,1)」,改一个数字就行,不用重新推理一遍。

用法(项目根目录):
    python tools/annotate_sheet.py
"""
import os

from PIL import Image, ImageDraw

## (图集路径, 单元格边长, 输出名)
SHEETS = [
    ("game_source/Characters/Tools.png", 16, "tools_sheet.png"),
    ("game_source/Characters/Basic Charakter Actions.png", 48, "actions_sheet.png"),
    ("game_source/Objects/Basic_Grass_Biom_things.png", 16, "biome_sheet.png"),
    ("game_source/Objects/Basic_tools_and_meterials.png", 16, "materials_sheet.png"),
    ("game_source/Objects/Basic_Plants.png", 16, "plants_sheet.png"),
]

SCALE = 8
MARGIN = 24
LABEL = 16


def annotate(path, cell, out_name, root):
    image = Image.open(path).convert("RGBA")
    width, height = image.size
    cols, rows = width // cell, height // cell
    big = image.resize((width * SCALE, height * SCALE), Image.NEAREST)

    canvas = Image.new("RGBA", (big.width + MARGIN + LABEL, big.height + MARGIN), (26, 26, 32, 255))
    canvas.paste(big, (MARGIN, LABEL + MARGIN // 2), big)
    draw = ImageDraw.Draw(canvas)
    origin_x, origin_y = MARGIN, LABEL + MARGIN // 2

    for col in range(cols + 1):
        x = origin_x + col * cell * SCALE
        draw.line([(x, origin_y), (x, origin_y + big.height)], fill=(255, 90, 90, 120))
        draw.text((x + 2, 2), str(col), fill=(255, 190, 190, 255))
    for row in range(rows + 1):
        y = origin_y + row * cell * SCALE
        draw.line([(origin_x, y), (origin_x + big.width, y)], fill=(255, 90, 90, 120))
        draw.text((2, y + 2), str(row), fill=(255, 190, 190, 255))

    out_dir = os.path.join(root, "docs/art")
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, out_name)
    canvas.save(out)
    print("%-42s cell %2dpx -> %2d x %2d cells -> %s" % (path, cell, cols, rows, out))


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    for path, cell, name in SHEETS:
        full = os.path.join(root, path)
        if not os.path.exists(full):
            print("skip (missing): " + path)
            continue
        annotate(full, cell, name, root)


if __name__ == "__main__":
    main()
