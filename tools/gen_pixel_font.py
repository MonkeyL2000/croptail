"""生成 HUD 用的像素字体:`.fnt`(BMFont 文本格式)+ `.png` 单页图。

## 为什么要自己生成

Sprout Lands 那个素材包里**一个字体文件都没有**,而 Godot 的默认字体是
抗锯齿的矢量字,放在像素画面里像贴了一层灰边。所以按「用系统字体渲染 ->
硬阈值二值化」的路子做一个 1-bit 点阵字,和素材的像素风一致。

## 许可

字体用 **Noto Sans SC**(`C:/Windows/Fonts/NotoSansSC-VF.ttf`)。
Noto 系列是 **SIL Open Font License 1.1** —— 允许再分发、允许嵌入、允许改,
所以生成的 `game_source/font/*` 可以随这个公开仓库一起发。见 `ASSET_CREDITS.md`。

> 最初的版本是用 Windows 的 **Consolas** 渲的。Consolas 是微软字体,
> **不许随项目再分发**,摆在公开仓库里是许可问题,所以换掉了。
> NotoSansSC 是可变字体,默认实例是 Thin(100) —— 直接渲出来笔画只有
> 一个像素、断成虚线。下面 `set_variation_by_axes([400])` 把它拧到 Regular,
> 才得到连续的实心笔画。

## 输出

- `game_source/font/sprout_ui.png` —— 白字 + alpha 掩码,一行排开
- `game_source/font/sprout_ui.fnt` —— BMFont 文本格式,Godot 直接认

改字号的步骤:调 `SIZE`,跑一遍本脚本,然后**看一眼**
`docs/art/font_preview.png`(脚本会顺手存一张放大 6 倍的预览),
确认没有糊成一团的字再进游戏。用法(项目根目录):

    python tools/gen_pixel_font.py
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

FONT_PATH = "C:/Windows/Fonts/NotoSansSC-VF.ttf"
FONT_WEIGHT = 400          # 可变字体的 Weight 轴;100 = Thin 会断线
SIZE = 12
THRESHOLD = 110            # 硬阈值:>110 算实心,得到的才是 1-bit 边缘

## .fnt 里的 yoffset 相对谁 —— **实测,不是照抄 BMFont 文档**。
##
## 实测(Godot 4.3):
##
##     字形顶 = Label 顶端 + yoffset        (base 不参与绘制)
##
## 证据:探针 Label 放在 y=204,而 yoffset=-9 的 'D' 实际画在 y=195..203。
## 断言在 scripts/dev/selftest.gd 的 `_measure_font_baseline()` 里,
## 每次跑自检都会重新量一遍像素,不靠这段注释。
##
## 注意这和 BMFont 文档说的不一样。文档的语义是
## 「字形顶 = 基线 + yoffset,基线 = 顶端 + base」,
## 按文档写(yoffset = 字形顶到 ascender 顶的距离 - base)整行字会**上移一个 base**:
## 12px 字体就上移 12px,顶栏里只剩字的下半截,顶被裁掉,而引擎一声不吭。
## 最坑的是 get_ascent()/get_height() 这些度量**全都是对的** ——
## 从度量接口根本查不出来,只能真去量像素。
##
## 所以这里存「字形顶到 ascender 顶的距离」,也就是 BMFont 的 yoffset + base。
YOFFSET_IS_FROM_LINE_TOP = TrueKEEP_YOFFSET_FROM_LINE_TOP = True
FACE_NAME = "SproutUI-12"  # 只影响 .fnt 里的名字,随便起
PAD = 8                    # 渲染留白,免得 bbox 贴边被裁

CHARS = (
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "abcdefghijklmnopqrstuvwxyz"
    "0123456789 .,:;!?|/+-()[]<>%'\"#*=&$_@"
)

OUT_DIR = "game_source/font"
PREVIEW_PATH = "docs/art/font_preview.png"


def load_font():
    font = ImageFont.truetype(FONT_PATH, SIZE)
    axes = font.get_variation_axes()
    if axes:
        # 轴可能有多个,只改名字是 Weight 的那个,其余保持默认
        values = [axis["default"] for axis in axes]
        for index, axis in enumerate(axes):
            if axis["name"] == b"Weight":
                values[index] = FONT_WEIGHT
        font.set_variation_by_axes(values)
    return font


def render(font, ch):
    """把单个字符渲染成 0/255 的 1-bit 数组。"""
    canvas = Image.new("L", (SIZE * 3, SIZE * 3), 0)
    ImageDraw.Draw(canvas).text((PAD, PAD), ch, fill=255, font=font)
    return np.where(np.array(canvas) > THRESHOLD, 255, 0).astype(np.uint8)


def main():
    font = load_font()
    ascent, descent = font.getmetrics()

    glyphs = []
    for ch in CHARS:
        mask = render(font, ch)
        rows, cols = np.where(mask > 0)
        if len(cols):
            x0, y0 = int(cols.min()), int(rows.min())
            x1, y1 = int(cols.max()) + 1, int(rows.max()) + 1
            sub = mask[y0:y1, x0:x1]
            # 见上面 YOFFSET_IS_FROM_LINE_TOP 那段
            xoff = x0 - PAD
            yoff = (y0 - PAD) if YOFFSET_IS_FROM_LINE_TOP else (y0 - PAD) - ascent
        else:
            sub = np.zeros((1, 1), np.uint8)
            xoff, yoff = 0, 0
        # 空格给个下限:Noto 的空格步进只有 3px,12px 字号下挤得看不清
        advance = max(int(round(font.getlength(ch))), 4 if ch == " " else 1)
        glyphs.append({"char": ch, "mask": sub, "xoff": xoff, "yoff": yoff, "advance": advance})

    line_height = ascent + descent
    page_h = max(g["mask"].shape[0] for g in glyphs)
    page_w = sum(g["mask"].shape[1] + 1 for g in glyphs)
    page = np.zeros((page_h, page_w), np.uint8)

    cursor = 0
    for glyph in glyphs:
        mask = glyph["mask"]
        height, width = mask.shape
        page[0:height, cursor:cursor + width] = mask
        glyph["x"] = cursor
        glyph["width"] = width
        glyph["height"] = height
        cursor += width + 1

    os.makedirs(OUT_DIR, exist_ok=True)
    rgba = np.zeros((page_h, page_w, 4), np.uint8)
    rgba[:, :, 0:3] = 255          # 白字,染色交给 Label 的 font_color
    rgba[:, :, 3] = page
    Image.fromarray(rgba, "RGBA").save(os.path.join(OUT_DIR, "sprout_ui.png"))

    lines = [
        'info face="%s" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100'
        ' smooth=0 aa=0 padding=0,0,0,0 spacing=1,1' % (FACE_NAME, SIZE),
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0"
        % (line_height, ascent, page_w, page_h),
        'page id=0 file="sprout_ui.png"',
        "chars count=%d" % len(glyphs),
    ]
    for g in glyphs:
        if len(g["char"]) > 1:            # 非 BMP,CropDB 里没有
            continue
        lines.append(
            "char id=%d x=%d y=0 width=%d height=%d xoffset=%d yoffset=%d xadvance=%d page=0 chnl=15"
            % (ord(g["char"]), g["x"], g["width"], g["height"], g["xoff"], g["yoff"], g["advance"])
        )
    lines.append("kernings count=0")
    with open(os.path.join(OUT_DIR, "sprout_ui.fnt"), "w", newline="\n") as handle:
        handle.write("\n".join(lines) + "\n")

    # 预览图:放大 6 倍,顺手把「有没有糊字」这件事变成一眼可见
    preview = Image.fromarray(rgba, "RGBA").resize(
        (page_w * 6, page_h * 6), Image.NEAREST)
    background = Image.new("RGBA", (preview.width + 16, preview.height + 16), (26, 26, 32, 255))
    background.paste(preview, (8, 8), preview)
    os.makedirs(os.path.dirname(PREVIEW_PATH), exist_ok=True)
    background.save(PREVIEW_PATH)

    print("%s: %dx%d, %d glyphs, base=%d lineHeight=%d"
          % (FACE_NAME, page_w, page_h, len(glyphs), ascent, line_height))
    print("preview -> " + PREVIEW_PATH)


if __name__ == "__main__":
    main()
