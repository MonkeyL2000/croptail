#!/usr/bin/env python3
"""从图集里量出每个装饰物的包围盒。

素材包把对象**紧挨着**摆在一起(不留缝),所以不能按 16x16 网格切 ——
网格是一切,但每一格只是对象的一小块。这里用连通域(flood fill)把
"连在一起的不透明像素"归成一个对象,输出它的像素矩形。

顺便按调色板给一个**分类建议**(绿色=灌木 / 灰白=石头 / 褐色=木头),
同时打印 fill(不透明像素占包围盒的比例)。

注意:自动分类只是**建议**,不是答案。Sprout Lands 的石头本身就带灰绿色,
光看色相和草丛分不开,所以最终归类看的是 fill + 人眼复核。结果手抄进
`scripts/world/prop_db.gd` 的 `PROPS` 表 —— 那张表才是唯一权威。

用法(在项目根目录):
    python tools/extract_props.py game_source/Objects/Basic_Grass_Biom_things.png
"""
import sys
from collections import Counter, deque

import numpy as np
from PIL import Image


def components(path):
	"""返回 [(x, y, w, h, [(px, py), ...]), ...],按 y 再按 x 排序。"""
	alpha = np.array(Image.open(path).convert("RGBA"))
	mask = alpha[:, :, 3] > 100
	height, width = mask.shape
	labels = -np.ones((height, width), dtype=int)
	found = []
	label = 0

	for sy in range(height):
		for sx in range(width):
			if not mask[sy, sx] or labels[sy, sx] >= 0:
				continue
			queue = deque([(sx, sy)])
			labels[sy, sx] = label
			pixels = []
			while queue:
				x, y = queue.popleft()
				pixels.append((x, y))
				for dy in (-1, 0, 1):
					for dx in (-1, 0, 1):
						nx, ny = x + dx, y + dy
						if 0 <= nx < width and 0 <= ny < height and mask[ny, nx] and labels[ny, nx] < 0:
							labels[ny, nx] = label
							queue.append((nx, ny))
			xs = [p[0] for p in pixels]
			ys = [p[1] for p in pixels]
			found.append((min(xs), min(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1, pixels))
			label += 1

	found.sort(key=lambda c: (c[1], c[0]))
	return alpha, found


def classify(alpha, pixels):
	"""按颜色给个种类建议。cream(米白)是描边色,单独统计不打分。"""
	score = Counter()
	for x, y in pixels:
		r, g, b = (int(v) for v in alpha[y, x, :3])
		if r > 235 and g > 235:
			continue
		if g >= r and g > b - 5:
			score["deco"] += 1          # 绿 -> 灌木 / 草
		elif r > g > b:
			score["wood"] += 1          # 褐 -> 木头
		elif abs(r - g) < 25 and abs(g - b) < 25:
			score["rock"] += 1          # 灰 -> 石头
	if not score:
		return "deco", score
	return score.most_common(1)[0][0], score

def main(path):
	alpha, found = components(path)
	image = Image.open(path)
	print("# %s  %dx%d  %d objects" % (path, image.size[0], image.size[1], len(found)))
	for x, y, w, h, pixels in found:
		kind, score = classify(alpha, pixels)
		tall = "tree candidate" if h >= 20 else ""
		# fill = 不透明像素占包围盒的比例。石头/灌木是实心块(接近 1),
		# 草簇/花丛是稀疏的(0.2~0.4)—— 这是区分两者最靠谱的指标,
		# 因为 Sprout Lands 的石头本身就带灰绿色,光看色相分不出来。
		fill = len(pixels) / float(w * h)
		print("Rect2(%3d, %2d, %3d, %2d)  %-4s fill=%.2f %-14s %s" % (
			x, y, w, h, kind, fill, tall, dict(score)))


if __name__ == "__main__":
	if len(sys.argv) < 2:
		print(__doc__)
		sys.exit(1)
	for argument in sys.argv[1:]:
		main(argument)
