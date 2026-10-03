"""在草岛上挖几个池塘:把池塘范围内的草地格从 `grass` 层的数据里删掉。

## 为什么「删草地格」就等于「出现池塘」

`farm_map.tscn` 里水层(water,挂在 (0,0))是一整块铺满整个地图的蓝色底图,
草层(grass,挂在 (-8,-5))才是岛的**形状** —— 草画在水上面。所以把某几格草删掉,
底下的水就露出来了,塘口和草地格**天然对齐**(两层各画各的网格,不会错半格)。
水层是一整块纯色动画格,不需要挖洞、也不需要「岸边过渡图」——这点和岛的
外海岸是同一套写法。

挖完必须接着跑:

    # 1. 引擎重算草地地形(peering)
    在 Godot 里跑 scenes/dev/retile.tscn
    # 2. 把重算结果贴回场景
    python tools/retile_grass.py

不然塘边那一圈草还是旧的地形图块(peering 没跟着变)。

## 池塘形状

三个椭圆 + 一层平滑的角度扰动。扰动用 sin 而不是逐格哈希:逐格哈希会在塘边
长出 1 格宽的锯齿刺,sin 出来的是圆润的凹凸,像真的水塘。
种子写死在 PONDS 里,所以每次挖出来的形状完全一样(可复现、能断言)。

用法(项目根目录):

    python tools/carve_ponds.py            # 挖(幂等:已经挖过就什么都不做)
    python tools/carve_ponds.py --dry-run  # 只打印会挖掉哪些格,不写文件
"""

import base64
import io
import math
import os
import re
import sys

SCENE = "scenes/world/farm_map.tscn"
LAYER = "grass"

# 草地层的 position。格坐标 -> 世界坐标要用它。
GRASS_ORIGIN = (-8.0, -5.0)
CELL = 16.0

# 农田 / 出生点:池塘不许碰(它们周围还要留通道)。
# 世界坐标矩形,来自 scenes/world/farm_map.tscn 的 FarmPlot + main.tscn 的玩家出生点。
KEEP_RECTS = [
    (300.0, 95.0, 516.0, 231.0),   # 农田(12x7 格)+ 一圈余量
    (368.0, 218.0, 432.0, 282.0),  # 玩家出生点 + 一圈余量
]

# 中心是**格坐标**(草地层那套),radius 单位是格。seed 决定塘边凹凸。
PONDS = [
    {"center": (-5, 6), "radius": (6.5, 4.5), "seed": 11.0},   # 岛左上的大塘
    {"center": (-9, 22), "radius": (4.5, 3.0), "seed": 22.0},  # 左下的小塘
    {"center": (33, 24), "radius": (4.0, 3.0), "seed": 33.0},  # 右下的小塘
]

RECORD = 12
PATTERN = (
    r'(\[node name="' + LAYER + r'" type="TileMapLayer"[^\]]*\]\n'
    r'position = Vector2\([^)]*\)\n'
    r'tile_map_data = PackedByteArray\(")([^"]*)("\))'
)


def pond_mask(cell, pond):
    """这一格在池塘里吗?椭圆 + 两层 sin 扰动。"""
    cx, cy = pond["center"]
    rx, ry = pond["radius"]
    seed = pond["seed"]
    dx = (cell[0] - cx) / rx
    dy = (cell[1] - cy) / ry
    distance = math.hypot(dx, dy)
    if distance > 1.6:            # 早退,不影响形状
        return False
    angle = math.atan2(dy, dx)
    wobble = 0.16 * math.sin(angle * 3.0 + seed) + 0.09 * math.sin(angle * 7.0 + seed * 2.0)
    return distance <= 1.0 + wobble


def pond_at(cell):
    for pond in PONDS:
        if pond_mask(cell, pond):
            return pond
    return None


def in_keep_rect(cell):
    """格坐标 -> 世界坐标(格中心),看是否落在必须留空的矩形里。"""
    world_x = GRASS_ORIGIN[0] + cell[0] * CELL + CELL * 0.5
    world_y = GRASS_ORIGIN[1] + cell[1] * CELL + CELL * 0.5
    for (x0, y0, x1, y1) in KEEP_RECTS:
        if x0 <= world_x <= x1 and y0 <= world_y <= y1:
            return True
    return False


def decode(blob):
    """tile_map_data -> 记录列表。前 2 字节是格式前缀(实测 00 00)。"""
    if (len(blob) - 2) % RECORD != 0:
        raise SystemExit("tile_map_data 长度不对:%d(期望 2 + n*12)" % len(blob))
    out = []
    for offset in range(2, len(blob), RECORD):
        chunk = blob[offset:offset + RECORD]
        x, y, source, atlas_x, atlas_y, alt = (
            int.from_bytes(chunk[i:i + 2], "little", signed=True) for i in range(0, 12, 2)
        )
        out.append((x, y, source, atlas_x, atlas_y, alt))
    return out


def encode(records):
    blob = bytearray(b"\x00\x00")
    for record in records:
        for value in record:
            blob += int(value).to_bytes(2, "little", signed=True)
    return bytes(blob)


def main(dry_run=False):
    text = io.open(SCENE, encoding="utf-8").read()
    match = re.search(PATTERN, text, re.S)
    if match is None:
        raise SystemExit("%s 里找不到 %s 层的 tile_map_data" % (SCENE, LAYER))

    records = decode(base64.b64decode(match.group(2)))
    kept, carved, skipped = [], [], []
    for record in records:
        cell = (record[0], record[1])
        if pond_at(cell) is not None and not in_keep_rect(cell):
            carved.append(cell)
        else:
            kept.append(record)
            if pond_at(cell) is not None:
                skipped.append(cell)

    for pond in PONDS:
        mine = [c for c in carved if pond_at(c) is pond]
        if mine:
            xs = [c[0] for c in mine]
            ys = [c[1] for c in mine]
            print("池塘 中心%-9s 挖掉 %3d 格  x %d..%d  y %d..%d" % (
                str(pond["center"]), len(mine), min(xs), max(xs), min(ys), max(ys)))

    if not carved:
        print("%s: %s 层没有可挖的格(已经挖过了)" % (SCENE, LAYER, ))
        return

    if skipped:
        # 池塘和农田/出生点重叠 = 设计撞车,必须让人看见
        print("!! 有 %d 格池塘落在农田/出生点的保留区里,已跳过:%s" % (
            len(skipped), skipped[:12]))
    print("草地 %d -> %d 格(挖掉 %d 格 = 全岛的 %.1f%%)" % (
        len(records), len(kept), len(carved), 100.0 * len(carved) / len(records)))

    if dry_run:
        print("--dry-run:没写文件")
        return

    blob = encode(kept)
    after = base64.b64encode(blob).decode()
    io.open(SCENE, "w", encoding="utf-8", newline="\n").write(
        text[: match.start(2)] + after + text[match.end(2):])
    print("%s: %s 层已更新(%d 字节)。" % (SCENE, LAYER, len(blob)))
    print("接着跑:Godot 里 scenes/dev/retile.tscn -> python tools/retile_grass.py")


if __name__ == "__main__":
    main(dry_run="--dry-run" in sys.argv)
