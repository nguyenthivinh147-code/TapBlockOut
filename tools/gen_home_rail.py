"""Straighten the curved candy rail of the Home screen and tone down its glare.

Input:  assets/ui/figma/home_rail.png (Figma "Progress line" 71:367, 306x2008, S-curve).
Output: assets/ui/figma/home_rail_straight.png (vertical rail, WIDTH x HEIGHT).
The curve is unrolled along its centre line (sampling across the normal at each arc-length step), so the stripes and
edge shading stay as drawn. Stripes on a bend come out skewed, so one stripe period is taken from the straightest
stretch (TILE_FROM..TILE_TO source rows) and repeated down the rail; RGB is then scaled by BRIGHTNESS.
Run: python3 tools/gen_home_rail.py
"""
import math
import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "figma")
SRC = os.path.join(ROOT, "home_rail.png")
OUT = os.path.join(ROOT, "home_rail_straight.png")
WIDTH = 64  # rail is ~54 px across; leaves room for the anti-aliased edges
HEIGHT = 2008
SMOOTH = 15  # rows averaged on each side when smoothing the centre line
TILE_FROM = 800  # source rows where the curve is nearly straight
TILE_TO = 1000
BRIGHTNESS = 0.85


def centre_line(im: Image.Image) -> list:
	w, h = im.size
	a = im.getchannel("A").load()
	mid = []
	for y in range(h):
		xs = [x for x in range(w) if a[x, y] > 128]
		mid.append((xs[0] + xs[-1]) * 0.5)
	out = []
	for y in range(h):
		lo, hi = max(0, y - SMOOTH), min(h, y + SMOOTH + 1)
		out.append(sum(mid[lo:hi]) / (hi - lo))
	return out


def sample(px, w: int, h: int, x: float, y: float) -> tuple:
	# bilinear on premultiplied colour
	x0, y0 = math.floor(x), math.floor(y)
	fx, fy = x - x0, y - y0
	acc = [0.0, 0.0, 0.0, 0.0]
	for dx, dy, k in ((0, 0, (1 - fx) * (1 - fy)), (1, 0, fx * (1 - fy)), (0, 1, (1 - fx) * fy), (1, 1, fx * fy)):
		xi, yi = x0 + dx, y0 + dy
		if k == 0.0 or xi < 0 or yi < 0 or xi >= w or yi >= h:
			continue
		r, g, b, al = px[xi, yi]
		f = k * al / 255.0
		acc[0] += r * f
		acc[1] += g * f
		acc[2] += b * f
		acc[3] += k * al
	if acc[3] <= 0.0:
		return (0, 0, 0, 0)
	n = acc[3] / 255.0
	return tuple(int(round(min(255.0, c / n * BRIGHTNESS))) for c in acc[:3]) + (int(round(acc[3])),)


def main() -> None:
	src = Image.open(SRC).convert("RGBA")
	w, h = src.size
	px = src.load()
	mid = centre_line(src)
	# arc length at each source row
	arc = [0.0]
	for y in range(1, h):
		arc.append(arc[-1] + math.hypot(mid[y] - mid[y - 1], 1.0))
	start = arc[TILE_FROM]
	rows = int(arc[TILE_TO] - start)
	strip = Image.new("RGBA", (WIDTH, rows))
	op = strip.load()
	y = 0
	for j in range(rows):
		s = start + j + 0.5
		while y < h - 2 and arc[y + 1] < s:
			y += 1
		t = (s - arc[y]) / (arc[y + 1] - arc[y])
		cy = y + t
		cx = mid[y] + (mid[y + 1] - mid[y]) * t
		dx = mid[y + 1] - mid[y]
		ln = math.hypot(dx, 1.0)
		nx, ny = 1.0 / ln, -dx / ln  # normal pointing to the rail's right
		for i in range(WIDTH):
			u = i + 0.5 - WIDTH * 0.5
			op[i, j] = sample(px, w, h, cx + u * nx - 0.5, cy + u * ny - 0.5)
	a, period = seamless_period(strip)
	tile = strip.crop((0, a, WIDTH, a + period))
	out = Image.new("RGBA", (WIDTH, HEIGHT))
	for j in range(0, HEIGHT, period):
		out.paste(tile, (0, j))
	out.save(OUT)


def seamless_period(strip: Image.Image) -> tuple:
	# (first row, length) of the stripe period whose top and bottom rows match best
	sp = strip.load()
	w, h = strip.size

	def diff(r0: int, r1: int) -> int:
		return sum(abs(sp[x, r0][c] - sp[x, r1][c]) for x in range(w) for c in range(4))

	best = None
	for period in range(60, 120):
		for a in range(0, h - period - 2):
			cost = diff(a, a + period) + diff(a + 1, a + period + 1)
			if best is None or cost < best[0]:
				best = (cost, a, period)
	return best[1], best[2]


if __name__ == "__main__":
	main()
