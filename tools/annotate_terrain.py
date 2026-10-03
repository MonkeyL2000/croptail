#!/usr/bin/env python3
"""把 TileSet 的 terrain(peering)信息画到图集上,存成 `docs/art/terrain_<name>.png`。

**为什么要它**:Sprout Lands 的草地/泥地图集没有图例,「哪一格是内部整块、哪一格是
左上角」全靠读 peering 表 —— 而那张表在 .tres 里是一堆
`3:1/0/terrains_peering_bit/top_side = 0`,人眼根本看不出来。

这个脚本把每一格「八个方向的邻居里有哪几个是同一种地面」画成一个 3x3 小格:
填色的方块 = 那个方向是同类地面,空的 = 不是。
所以内部整块是**九宫格全填**,左边缘是**左中不填**,左上角是**左上三格不填**,
反过来「只差一个角」的内凹块一眼也能认出来。

用法(项目根目录):

    python tools/annotate_terrain.py
"""

import io
import os
import re

from PIL import Image, ImageDraw

TILESET = "tilesets/test_tilemap.tres"
OUT_DIR = "docs/art"

SCALE = 10
LABEL = 14
MARK = 9  # 3x3 小格里每一小格的边长(乘上 SCALE)

## 八向的规范顺序,以及它在 3x3 小格里的位置(列, 行)
BITS = [
    ("top_left_corner", 0, 0),
    ("top_side", 1, 0),
    ("top_right_corner", 2, 0),
    ("left_side", 0, 1),
    ("right_side", 2, 1),
    ("bottom_left_corner", 0, 2),
    ("bottom_side", 1, 2),
    ("bottom_right_corner", 2, 2),
]

FILL = (255, 220, 60, 255)
EMPTY = (40, 40, 40, 255)
FRAME = (255, 60, 60, 255)


def read(path):
    return io.open(path, encoding="utf-8").read()


def parse(text):
    """source id -> (贴图路径, {格子: {方向}})"""
    ext = {
        m.group(2): m.group(1)
        for m in re.finditer(r'\[ext_resource type="Texture2D"[^\]]*path="([^"]+)" id="([^"]+)"\]', text)
    }
    subs = {}
    for m in re.finditer(
        r'\[sub_resource type="TileSetAtlasSource" id="([^"]+)"\]\n(.*?)(?=\n\[|\Z)', text, re.S
    ):
        subs[m.group(1)] = m.group(2)

    out = {}
    for m in re.finditer(r'sources/(\d+)\s*=\s*(?:SubResource|ExtResource)\("([^"]+)"\)', text):
        body = subs.get(m.group(2))
        if body is None:
            continue
        texture = re.search(r'texture = ExtResource\("([^"]+)"\)', body)
        if texture is None:
            continue
        cells = {}
        for bit in re.finditer(r"(\d+):(\d+)/0/terrains_peering_bit/(\w+) = ", body):
            key = (int(bit.group(1)), int(bit.group(2)))
            cells.setdefault(key, set()).add(bit.group(3))
        # 只登记「有 terrain 定义」的格子
        terrain = {
            (int(t.group(1)), int(t.group(2)))
            for t in re.finditer(r"(\d+):(\d+)/0/terrain = ", body)
        }
        out[int(m.group(1))] = (ext[texture.group(1)], {c: cells.get(c, set()) for c in terrain})
    return out


def draw(source, path, cells, out_path):
    sheet = Image.open(path.replace("res://", "")).convert("RGBA")
    cols = sheet.width // 16
    rows = sheet.height // 16
    image = sheet.resize((sheet.width * SCALE, sheet.height * SCALE), Image.NEAREST)
    draw_ctx = ImageDraw.Draw(image)

    for y in range(rows):
        for x in range(cols):
            left, top = x * 16 * SCALE, y * 16 * SCALE
            draw_ctx.rectangle(
                [left, top, left + 16 * SCALE - 1, top + 16 * SCALE - 1],
                outline=(80, 80, 80, 255),
            )
            bits = cells.get((x, y))
            if bits is None:
                continue
            draw_ctx.rectangle(
                [left, top, left + 16 * SCALE - 1, top + 16 * SCALE - 1], outline=FRAME
            )
            # 八向的九宫格
            for name, mx, my in BITS:
                px = left + 3 + mx * MARK
                py = top + 3 + my * MARK
                draw_ctx.rectangle(
                    [px, py, px + MARK - 1, py + MARK - 1],
                    fill=FILL if name in bits else EMPTY,
                )
            draw_ctx.text((left + 3, top + 16 * SCALE - LABEL - 2), f"{x},{y}", fill=(255, 255, 255, 255))

    os.makedirs(OUT_DIR, exist_ok=True)
    image.save(out_path)
    print(f"wrote {out_path}  ({len(cells)} tiles with terrain data)")


if __name__ == "__main__":
    sources = parse(read(TILESET))
    names = {1: "grass", 3: "tilled_dirt"}
    for source, name in names.items():
        if source not in sources:
            continue
        path, cells = sources[source]
        draw(source, path, cells, f"{OUT_DIR}/terrain_{name}.png")
