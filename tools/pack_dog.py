#!/usr/bin/env python3
"""把用户给的小狗素材整理成游戏能直接用的规则图集。

源图 `game_source/Pets/lilpuddinpuggums.png` 是 96x192 的 **RGB**(没有 alpha,
白底),里面是 3 列 x 4 行的狗,每格 32x48。它不能直接丢进游戏,有三个问题:

1. **白底不是透明的** —— 不处理的话游戏里狗屁股后面会跟着一个白方块。
   (先确认过:全图 12668 个白像素**全部**和画布边缘连通 = 纯背景,
   没有一处「被围住的白色」,所以可以放心抠。)
2. **每一行的横向位置没对齐**:正/背视的狗在 x2..27,侧视在 x0..27,
   它的镜像在 x4..31 —— 都是 32 宽的格子,但内容一个偏左一个偏右。
   直接用的话,狗转身时会**横着跳 3px**。这里按「每行一个偏移」居中对齐
   (行内三帧的相对位置不动,免得走起来左右抽)。纵向**不动**:源图里各帧的
   上下浮动(2px 一档)就是走路的起伏,是作者画的,保留。
3. **太大**:狗 26x24,而游戏里的农夫只有 14x16、鸡 11x12。源图的线宽基本是 2px
   (每两行/两列完全相同,只有舌头和脚上有 1px 的细节),按 2:1 取样正好回到
   13x12,和鸡一样大 —— 所以这里是**整数 2:1 降采样**,不是插值缩放。

产物:
    game_source/Pets/pug_walk.png   48x96 = 3 列 x 4 行,每格 16x24,RGBA
    docs/art/pug_sheet.png          人工核对图(源图 + 成品,带格线和方向标注)

用法(项目根目录):
    python tools/pack_dog.py            # 出图
    python tools/pack_dog.py --preview  # 额外把成品用 ASCII 打到终端
"""
import os
import sys

from PIL import Image, ImageDraw

SRC = "game_source/Pets/lilpuddinpuggums.png"
DST = "game_source/Pets/pug_walk.png"
PREVIEW = "docs/art/pug_sheet.png"

## 源图版式:3 列 x 4 行,每格 32x48
SRC_CELL = (32, 48)
COLS = 3
## 行 -> 朝向名(和 player.gd 的 DIR_ROW 同一套:front/left/right/back)
## 源图的第 1 行是**朝左**的侧视(鼻子/眼睛在左端,身子尾巴在右端),第 2 行是它的镜像。
ROW_DIRS = ["front", "left", "right", "back"]
## 每行取样时 x 方向的起始相位。镜像轴落在**半像素**上(第 1 行 x0..27,第 2 行 x4..31),
## 2:1 取样会把相位翻过去 —— 左行取到偶数像素、右行也取偶数像素的话,
## 左右两帧就差半个源像素,转身时会闪一下。让右行从奇数像素开始取,
## 左右两帧就是**逐像素精确**的镜像(自检里有一条断言钉着)。
PHASE_X = {"right": 1}
## 降采样倍数(2:1)
DIV = 2
CELL = (SRC_CELL[0] // DIV, SRC_CELL[1] // DIV)  # 16x24
BG = (255, 255, 255)

## 图例(源图里出现的全部 11 种颜色,给校对图上的色卡用)
PALETTE = [
    ((196, 98, 0), "body"),
    ((255, 168, 92), "body light"),
    ((52, 36, 36), "shade"),
    ((0, 0, 0), "outline"),
    ((255, 34, 0), "mouth"),
    ((199, 0, 40), "mouth dark"),
    ((235, 47, 181), "tongue"),
    ((255, 69, 243), "tongue light"),
    ((255, 246, 0), "collar"),
    ((221, 221, 221), "tag"),
]


def load_cells(img):
    """切成 4 行 x 3 格,白底 -> 透明,返回 [[RGBA cell, ...] x 4]"""
    cells = []
    for r in range(len(ROW_DIRS)):
        row = []
        for c in range(COLS):
            box = (c * SRC_CELL[0], r * SRC_CELL[1],
                   c * SRC_CELL[0] + SRC_CELL[0], r * SRC_CELL[1] + SRC_CELL[1])
            cell = img.crop(box).convert("RGBA")
            px = cell.load()
            for y in range(SRC_CELL[1]):
                for x in range(SRC_CELL[0]):
                    if px[x, y][:3] == BG:
                        px[x, y] = (0, 0, 0, 0)
            row.append(cell)
        cells.append(row)
    return cells


def opaque_bbox(cell):
    """整格不透明像素的包围盒(空格子返回 None)"""
    px = cell.load()
    xs = []
    ys = []
    for y in range(cell.height):
        for x in range(cell.width):
            if px[x, y][3] > 0:
                xs.append(x)
                ys.append(y)
    if not xs:
        return None
    return (min(xs), min(ys), max(xs) + 1, max(ys) + 1)


def downsample(cell, phase_x=0):
    """按 2:1 取样(不插值 —— 像素画只能这么缩),phase_x 是 x 方向的起始相位。
    平移**放到小图空间里**做:源图里内容的横向偏移常常是奇数(26 宽的狗居中
    到 32 宽的格子里,左边缘就在 x2/x0/x4),在源坐标里平移会打乱 2:1 的像素对,
    先取样再平移就没有这个问题。"""
    small = Image.new("RGBA", CELL, (0, 0, 0, 0))
    sp = small.load()
    px = cell.load()
    for y in range(CELL[1]):
        for x in range(CELL[0]):
            sx, sy = x * DIV + phase_x, y * DIV
            if 0 <= sx < SRC_CELL[0] and 0 <= sy < SRC_CELL[1]:
                sp[x, y] = px[sx, sy]
    return small


def build(cells):
    """拼成 3 列 x 4 行 x 16x24 的成品,返回 (图, 每行用了多少偏移)"""
    sheet = Image.new("RGBA", (CELL[0] * COLS, CELL[1] * len(ROW_DIRS)), (0, 0, 0, 0))
    offsets = []
    for r, row in enumerate(cells):
        for c, cell in enumerate(row):
            b = opaque_bbox(cell)
            if b and (b[0] % DIV or b[1] % DIV):
                print("[pack_dog] WARN row %d frame %d: content starts at %s, not on the 2:1 grid"
                      % (r, c, b[:2]))
        phase = PHASE_X.get(ROW_DIRS[r], 0)
        smalls = [downsample(cell, phase) for cell in row]
        boxes = [opaque_bbox(s) for s in smalls]
        min_x = min(b[0] for b in boxes)
        max_x = max(b[2] for b in boxes)
        off = (CELL[0] - (max_x - min_x)) // 2 - min_x
        offsets.append(off)
        for c, small in enumerate(smalls):
            sheet.paste(small, (c * CELL[0] + off, r * CELL[1]))
    return sheet, offsets


def ascii_preview(sheet):
    """把成品打到终端(只能看个大概,但不用开图片查看器就能发现「变成了白方块」)"""
    chars = {(196, 98, 0): "O", (255, 168, 92): "o", (52, 36, 36): "D", (0, 0, 0): "K",
             (255, 34, 0): "R", (199, 0, 40): "r", (235, 47, 181): "M", (255, 69, 243): "m",
             (255, 246, 0): "Y", (221, 221, 221): "G"}
    px = sheet.load()
    for r, name in enumerate(ROW_DIRS):
        print("--- %s  (y %d..%d)" % (name, r * CELL[1], (r + 1) * CELL[1] - 1))
        for y in range(r * CELL[1], (r + 1) * CELL[1]):
            line = ""
            for c in range(COLS):
                for x in range(CELL[0]):
                    p = px[c * CELL[0] + x, y]
                    line += "." if p[3] == 0 else chars.get(p[:3], "?")
                line += "|"
            print("%3d %s" % (y, line))


def review_sheet(img, cells, packed, offsets):
    """人工核对图:左=源图(带格线、行标注),右=成品放大"""
    scale_a, scale_b = 4, 8
    big_a = img.convert("RGBA").resize((img.width * scale_a, img.height * scale_a), Image.NEAREST)
    big_b = packed.resize((packed.width * scale_b, packed.height * scale_b), Image.NEAREST)
    left_w = big_a.width + 24
    legend_h = 24 * len(PALETTE) + 40
    canvas = Image.new("RGBA", (left_w + big_b.width + 24, max(big_a.height, big_b.height) + legend_h + 60),
                       (28, 26, 34, 255))
    d = ImageDraw.Draw(canvas)
    d.text((12, 8), "SOURCE  game_source/Pets/lilpuddinpuggums.png  (96x192, RGB, white bg)", fill=(255, 235, 170))
    canvas.paste(big_a, (12, 28))
    for r, name in enumerate(ROW_DIRS):
        y0 = 28 + r * SRC_CELL[1] * scale_a
        d.line([(12, y0), (12 + big_a.width, y0)], fill=(255, 120, 120, 200))
        d.text((14, y0 + 2), "row %d = %s" % (r, name), fill=(255, 160, 160))
    for c in range(1, COLS):
        x0 = 12 + c * SRC_CELL[0] * scale_a
        d.line([(x0, 28), (x0, 28 + big_a.height)], fill=(255, 120, 120, 200))
    x2 = left_w
    d.text((x2, 8), "PACKED  game_source/Pets/pug_walk.png  (48x96, 3x4 of 16x24)", fill=(150, 255, 180))
    canvas.paste(big_b, (x2, 28))
    for r, name in enumerate(ROW_DIRS):
        y0 = 28 + r * CELL[1] * scale_b
        d.line([(x2, y0), (x2 + big_b.width, y0)], fill=(120, 255, 120, 200))
        d.text((x2 + 2, y0 + 2), "%s (row shifted %d)" % (name, offsets[r]), fill=(180, 255, 180))
    for c in range(1, COLS):
        x0 = x2 + c * CELL[0] * scale_b
        d.line([(x0, 28), (x0, 28 + big_b.height)], fill=(120, 255, 120, 200))
    y = max(big_a.height, big_b.height) + 44
    d.text((12, y), "palette of the source (11 colours, alpha keyed out):", fill=(255, 235, 170))
    for i, (col, name) in enumerate(PALETTE):
        yy = y + 20 + i * 24
        d.rectangle([12, yy, 30, yy + 16], fill=col + (255,), outline=(255, 255, 255, 255))
        d.text((36, yy + 2), "%s  rgb%s" % (name, str(col)), fill=(230, 230, 230))
    canvas.save(PREVIEW)
    return canvas


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(root)
    img = Image.open(SRC)
    print("[pack_dog] src %s  %s %s" % (SRC, img.size, img.mode))
    cells = load_cells(img)
    packed, offsets = build(cells)
    packed.save(DST)
    print("[pack_dog] -> %s  %s  (rows front/left/right/back, %d frames of %dx%d)"
          % (DST, packed.size, COLS, CELL[0], CELL[1]))
    for r, (name, off) in enumerate(zip(ROW_DIRS, offsets)):
        for c in range(COLS):
            b = opaque_bbox(packed.crop((c * CELL[0], r * CELL[1], (c + 1) * CELL[0], (r + 1) * CELL[1])))
            print("    %-5s frame %d  content %s" % (name, c, b))
    os.makedirs("docs/art", exist_ok=True)
    review_sheet(img, cells, packed, offsets).save(PREVIEW)
    print("[pack_dog] -> %s (human review)" % PREVIEW)
    if "--preview" in sys.argv:
        ascii_preview(packed)


if __name__ == "__main__":
    main()
