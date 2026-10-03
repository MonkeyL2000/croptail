"""把 `retile.bin`(引擎重算出来的 `tile_map_data`)贴回地图场景的草地层。

流程是分工的:

1. `scenes/dev/retile.tscn` 在 Godot 里跑 —— 只有引擎知道 peering 该怎么算,
   它重算完把草地层的 `tile_map_data` 原样写进 `_retile_0.bin`;
2. 这个脚本做**外科手术式的替换**:只换 `scenes/world/farm_map.tscn` 里 grass 节点
   的那一行 `tile_map_data`,其余一个字节都不动。

**为什么不直接在 Godot 里 `ResourceSaver.save()` 存整个场景**:场景里 `FarmProps`
一进树就会生成几百个道具子节点,存下去等于把运行时状态烤进场景文件。
而这里只换一行,`git diff` 也看得清清楚楚。

用法(项目根目录,先跑过 `retile.tscn`):

    python tools/retile_grass.py                # 用 _retile_0.bin
    python tools/retile_grass.py other.bin      # 或指定别的输入
"""

import base64
import io
import os
import re
import sys

SCENE = "scenes/world/farm_map.tscn"
LAYER = "grass"
DEFAULT_INPUT = "_retile_0.bin"

PATTERN = (
    r'(\[node name="' + LAYER + r'" type="TileMapLayer"[^\]]*\]\n'
    r'position = Vector2\([^)]*\)\n'
    r'tile_map_data = PackedByteArray\(")([^"]*)("\))'
)


def main(input_path=DEFAULT_INPUT):
    if not os.path.exists(input_path):
        raise SystemExit(f"{input_path} 不存在 —— 先在 Godot 里跑 scenes/dev/retile.tscn")

    raw = io.open(input_path, "rb").read()
    if (len(raw) - 2) % 12 != 0:
        raise SystemExit(f"{input_path} 不是 tile_map_data({len(raw)} 字节,期望 2 + n*12)")

    text = io.open(SCENE, encoding="utf-8").read()
    match = re.search(PATTERN, text, re.S)
    if match is None:
        raise SystemExit(f"{SCENE} 里找不到 {LAYER} 层的 tile_map_data")

    before = match.group(2)
    after = base64.b64encode(raw).decode()
    if before == after:
        print(f"{SCENE}: {LAYER} 层已经是最新的({len(raw)} 字节),没改动")
        return

    io.open(SCENE, "w", encoding="utf-8", newline="\n").write(
        text[: match.start(2)] + after + text[match.end(2) :]
    )
    print(f"{SCENE}: {LAYER} 层已更新({len(raw)} 字节,{base64.b64decode(before).__len__() if before else 0} -> {len(raw)})")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else DEFAULT_INPUT)
