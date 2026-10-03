#!/usr/bin/env python3
"""把「代码认为这一格是什么」直接写在素材上,存成 `docs/art/tools_objects.png`。

为什么要它:斧头和镐头**素材包里没有图例**,名字是从像素形状推出来的
(金属头 + 木柄、比 Tools.png 那三把大得多),而只有人能一眼看出
「这是斧头还是镰刀」。这张图把代码里的用法和原始像素摆在一起,
不对就直接说「(1,0) 那把是镰刀」,改一个 Rect2 就行。

用法(项目根目录):
    python tools/annotate_objects.py
"""
import os

from PIL import Image, ImageDraw

SCALE = 8
PAD = 8
LABEL_W = 150

## (小标题, 图集相对路径, 一组 (源图矩形, 代码里的名字, 备注))
SECTIONS = [
    ("Objects/Basic_tools_and_meterials.png  (48x32)",
     "game_source/Objects/Basic_tools_and_meterials.png", [
         ((0, 0, 16, 16), "rock_low", "灰石头"),
         ((16, 0, 16, 16), "axe  <== 新增", "金属头 + 长木柄"),
         ((32, 0, 16, 16), "pickaxe <== 新增", "头更宽、柄更短"),
         ((0, 16, 16, 16), "rock_round", "圆石头"),
         ((16, 16, 16, 16), "wood_log", "一截木料"),
         ((32, 16, 16, 16), "wood_log_big", "一截木料"),
     ]),
    ("Objects/Basic_Plants.png  (96x32)  收获图标取第 4 列",
     "game_source/Objects/Basic_Plants.png", [
         ((64, 0, 16, 16), "harvest/wheat", "小麦成熟态"),
         ((64, 16, 16, 16), "harvest/greens", "青菜成熟态"),
     ]),
    ("Tilesets/Fences.png  (64x64)  围栏只用 row 1",
     "game_source/Tilesets/Fences.png", [
         ((16, 16, 16, 16), "fence_end_left", "左端"),
         ((32, 16, 16, 16), "fence_mid", "中段"),
         ((48, 16, 16, 16), "fence_end_right", "右端"),
         ((0, 16, 16, 16), "fence_post", "只有柱子"),
     ]),
    ("Objects/Free_Chicken_House.png  (48x48)",
     "game_source/Objects/Free_Chicken_House.png", [
         ((0, 0, 48, 48), "chicken_house", "3x3 格的鸡舍"),
     ]),
    ("Characters/Free Chicken Sprites.png  (64x32)  row0=idle row1=walk",
     "game_source/Characters/Free Chicken Sprites.png", [
         ((0, 0, 32, 16), "chicken idle", "2 帧"),
         ((0, 16, 32, 16), "chicken walk", "2 帧"),
     ]),
]


def draw_section(canvas, draw, y, title, sheet_path, entries, root):
    big_size = 48 * SCALE
    title_h = 22
    draw.text((PAD, y + 4), title, fill=(255, 235, 170, 255))
    y += title_h

    image = Image.open(os.path.join(root, sheet_path)).convert("RGBA")
    x = PAD
    for rect, name, note in entries:
        crop = image.crop((rect[0], rect[1], rect[0] + rect[2], rect[1] + rect[3]))
        scaled = crop.resize((crop.width * SCALE, crop.height * SCALE), Image.NEAREST)
        cell_w = max(scaled.width, LABEL_W)
        # 棋盘底:好看清哪些像素其实是透明的
        checker = Image.new("RGBA", (cell_w, big_size), (60, 60, 70, 255))
        cd = ImageDraw.Draw(checker)
        for cy in range(0, big_size, 16):
            for cx in range(0, cell_w, 16):
                if (cx // 16 + cy // 16) % 2 == 0:
                    cd.rectangle([cx, cy, cx + 15, cy + 15], fill=(78, 78, 90, 255))
        checker.paste(scaled, (0, 0), scaled)
        canvas.paste(checker, (x, y), checker)
        draw.text((x + 2, y + big_size + 2), name, fill=(190, 235, 255, 255))
        draw.text((x + 2, y + big_size + 14), note, fill=(160, 160, 170, 255))
        x += cell_w + PAD
    return y + big_size + 30


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    canvas = Image.new("RGBA", (900, 1200), (26, 26, 32, 255))
    draw = ImageDraw.Draw(canvas)
    draw.text((PAD, 6), "croptail: what the code thinks each sprite is (from tool_icons.gd / prop_db.gd)",
              fill=(255, 255, 255, 255))
    y = 26
    for title, path, entries in SECTIONS:
        if not os.path.exists(os.path.join(root, path)):
            draw.text((PAD, y), "missing: " + path, fill=(255, 120, 120, 255))
            y += 20
            continue
        y = draw_section(canvas, draw, y, title, path, entries, root)
    canvas = canvas.crop((0, 0, canvas.width, y))
    out = os.path.join(root, "docs/art/tools_objects.png")
    canvas.save(out)
    print("docs/art/tools_objects.png  %dx%d" % canvas.size)


if __name__ == "__main__":
    main()
