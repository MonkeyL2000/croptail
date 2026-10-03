"""把 farm_map.tscn 的地形层离线合成成一张 PNG(不带缩放)。

**为什么要它**:地图形状是脚本刷出来的,而「这一格画哪一块」又由 TileSet 的 peering
规则决定 —— 在编辑器/游戏里对着视口看,一次只能看到一小块,很容易得出「花花绿绿
的,应该没问题」的结论。整张图铺开看,草坪边缘接得对不对、有没有把角块刷满,
一眼就能看出来。

只画地形层(water / grass / Nature)。道具是 `FarmProps` 运行时撒的,不在场景文件里。

用法:

    python tools/render_map.py docs/art/map.png [缩放倍数]
"""

import base64
import io
import os
import re
import sys

from PIL import Image

CELL = 16
SCENE = "scenes/world/farm_map.tscn"
TILESET = "tilesets/test_tilemap.tres"


# ---------------------------------------------------------------- .tscn / .tres


def read(path):
    return io.open(path, encoding="utf-8").read()


def parse_layers(text):
    """按文件里的先后顺序返回 [(名字, 层偏移, [格子...])],格子是 (x, y, source, ax, ay)。"""
    layers = []
    for match in re.finditer(
        r'\[node name="(\w+)" type="TileMapLayer"[^\]]*\](.*?)(?=\n\[node|\Z)', text, re.S
    ):
        name, body = match.group(1), match.group(2)
        offset = re.search(r"position = Vector2\(([^)]*)\)", body)
        ox, oy = (0, 0) if not offset else [int(float(v)) for v in offset.group(1).split(",")]
        packed = re.search(r'tile_map_data = PackedByteArray\("([^"]*)"\)', body)
        if packed is None:
            layers.append((name, (ox, oy), []))
            continue
        # Godot 存 PackedByteArray 时两种写法都可能出现:逗号分隔的十进制,或者 base64
        raw = (
            bytes(int(v) for v in packed.group(1).split(","))
            if "," in packed.group(1)
            else base64.b64decode(packed.group(1))
        )
        cells = []
        for i in range((len(raw) - 2) // 12):
            record = raw[2 + i * 12 : 2 + i * 12 + 12]
            x, y, source, ax, ay, _alt = (
                int.from_bytes(record[j * 2 : j * 2 + 2], "little", signed=True) for j in range(6)
            )
            cells.append((x, y, source, ax, ay))
        layers.append((name, (ox, oy), cells))
    return layers


def parse_sources(tres_text, scene_text):
    """source id -> 贴图路径。TileSet 的 texture 是 ext_resource,要先解一层。"""
    ext = {}
    for match in re.finditer(r'\[ext_resource type="Texture2D"[^\]]*path="([^"]+)" id="([^"]+)"\]', tres_text):
        ext[match.group(2)] = match.group(1)

    subs = {}
    for match in re.finditer(
        r'\[sub_resource type="TileSetAtlasSource" id="([^"]+)"\]\n(.*?)(?=\n\[|\Z)', tres_text, re.S
    ):
        subs[match.group(1)] = match.group(2)

    sources = {}
    for match in re.finditer(r'sources/(\d+)\s*=\s*(?:SubResource|ExtResource)\("([^"]+)"\)', tres_text):
        body = subs.get(match.group(2))
        if body is None:
            continue
        texture = re.search(r'texture = ExtResource\("([^"]+)"\)', body)
        if texture:
            sources[int(match.group(1))] = ext[texture.group(1)]
    return sources


# ---------------------------------------------------------------------- render


def render(scene=SCENE, out="docs/art/map.png", scale=1):
    layers = parse_layers(read(scene))
    sources = parse_sources(read(TILESET), read(scene))

    sheets = {}
    for source, path in sources.items():
        # TileSet 里存的是 res:// 路径,脚本要在项目根目录下跑
        sheets[source] = Image.open(path.replace("res://", "")).convert("RGBA")

    # 世界坐标 -> 画布坐标:先把所有层的包围盒算出来
    min_x = min_y = 1 << 30
    max_x = max_y = -(1 << 30)
    for _name, (ox, oy), cells in layers:
        for x, y, _source, _ax, _ay in cells:
            min_x, min_y = min(min_x, ox + x * CELL), min(min_y, oy + y * CELL)
            max_x, max_y = max(max_x, ox + x * CELL + CELL), max(max_y, oy + y * CELL + CELL)
    if min_x > max_x:
        raise SystemExit("地图是空的")

    canvas = Image.new("RGBA", (max_x - min_x, max_y - min_y), (0, 0, 0, 255))
    for _name, (ox, oy), cells in layers:
        for x, y, source, ax, ay in cells:
            sheet = sheets.get(source)
            if sheet is None:
                continue
            tile = sheet.crop((ax * CELL, ay * CELL, ax * CELL + CELL, ay * CELL + CELL))
            canvas.alpha_composite(tile, (ox + x * CELL - min_x, oy + y * CELL - min_y))

    if scale != 1:
        canvas = canvas.resize((canvas.width * scale, canvas.height * scale), Image.NEAREST)

    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    canvas.save(out)
    print(f"wrote {out}  {canvas.width}x{canvas.height}  scale={scale}")
    print(f"world bounds: x {min_x}..{max_x}  y {min_y}..{max_y}")


if __name__ == "__main__":
    render(
        SCENE,
        sys.argv[1] if len(sys.argv) > 1 else "docs/art/map.png",
        int(sys.argv[2]) if len(sys.argv) > 2 else 1,
    )
