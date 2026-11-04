"""Generate the tileable candy watermark for the Home background.

Output: assets/ui/figma/home_candy_pattern.png, white shapes on transparent (tinted in home.gd).
Run: python3 tools/gen_home_candy_pattern.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

TILE = 512
SS = 4  # supersampling factor
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "figma", "home_candy_pattern.png")
WHITE = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)


def canvas(size: int) -> tuple:
	im = Image.new("RGBA", (size * SS, size * SS), CLEAR)
	return im, ImageDraw.Draw(im)


def s(v: float) -> int:
	return int(round(v * SS))


def wrapped_candy() -> Image.Image:
	im, d = canvas(120)
	d.ellipse([s(34), s(42), s(86), s(78)], fill=WHITE)
	d.polygon([(s(38), s(60)), (s(8), s(38)), (s(14), s(60)), (s(8), s(82))], fill=WHITE)
	d.polygon([(s(82), s(60)), (s(112), s(38)), (s(106), s(60)), (s(112), s(82))], fill=WHITE)
	for x in (48, 60, 72):
		d.line([(s(x - 6), s(78)), (s(x + 6), s(42))], fill=CLEAR, width=s(3.5))
	return im


def lollipop() -> Image.Image:
	im, d = canvas(120)
	d.rounded_rectangle([s(56), s(58), s(64), s(114)], radius=s(4), fill=WHITE)
	d.ellipse([s(28), s(8), s(92), s(72)], fill=WHITE)
	pts = []
	for i in range(220):
		t = i / 219.0 * math.pi * 5.0
		r = 2.0 + t * 1.65
		pts.append((s(60 + r * math.cos(t)), s(40 + r * math.sin(t))))
	d.line(pts, fill=CLEAR, width=s(3.5), joint="curve")
	return im


def heart() -> Image.Image:
	im, d = canvas(100)
	pts = []
	for i in range(120):
		t = i / 120.0 * math.tau
		x = 16 * math.sin(t) ** 3
		y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
		pts.append((s(50 + x * 2.6), s(46 - y * 2.6)))
	d.polygon(pts, fill=WHITE)
	d.arc([s(26), s(24), s(48), s(46)], 190, 260, fill=CLEAR, width=s(4))
	return im


def star() -> Image.Image:
	im, d = canvas(100)
	pts = []
	for i in range(10):
		a = -math.pi / 2 + i * math.pi / 5
		r = 44 if i % 2 == 0 else 20
		pts.append((s(50 + r * math.cos(a)), s(54 + r * math.sin(a))))
	d.polygon(pts, fill=WHITE)
	d.line([(s(40), s(36)), (s(46), s(30))], fill=CLEAR, width=s(4))
	return im


def mint() -> Image.Image:
	im, d = canvas(90)
	d.ellipse([s(8), s(8), s(82), s(82)], fill=WHITE)
	for k in range(6):
		a0 = k * 60
		d.pieslice([s(16), s(16), s(74), s(74)], a0, a0 + 22, fill=CLEAR)
	d.ellipse([s(37), s(37), s(53), s(53)], fill=WHITE)
	return im


def cane() -> Image.Image:
	im, d = canvas(120)
	w = 13
	d.arc([s(30), s(8), s(76), s(54)], 180, 360, fill=WHITE, width=s(w))
	d.line([(s(36.5), s(31)), (s(36.5), s(110))], fill=WHITE, width=s(w))
	d.ellipse([s(30), s(104), s(43), s(117)], fill=WHITE)
	d.ellipse([s(63), s(25), s(76), s(38)], fill=WHITE)
	for y in range(40, 108, 14):
		d.line([(s(28), s(y + 6)), (s(46), s(y - 4))], fill=CLEAR, width=s(3.5))
	for a in (200, 240, 280, 320):
		r = math.radians(a)
		cx, cy, rr = 53, 31, 23
		d.line([(s(cx + (rr - 8) * math.cos(r)), s(cy + (rr - 8) * math.sin(r))),
			(s(cx + (rr + 8) * math.cos(r + 0.25)), s(cy + (rr + 8) * math.sin(r + 0.25)))], fill=CLEAR, width=s(3.5))
	return im


def _paste_clipped(tile: Image.Image, shp: Image.Image, x: int, y: int) -> None:
	size = tile.width
	sx0 = max(0, -x)
	sy0 = max(0, -y)
	sx1 = min(shp.width, size - x)
	sy1 = min(shp.height, size - y)
	if sx1 <= sx0 or sy1 <= sy0:
		return
	tile.alpha_composite(shp.crop((sx0, sy0, sx1, sy1)), (x + sx0, y + sy0))


def main() -> None:
	tile = Image.new("RGBA", (TILE * SS, TILE * SS), CLEAR)
	# Five shapes, at least 181 px apart across tile edges, so the watermark stays sparse.
	layout = [
		(wrapped_candy, 80, 70, 25, 1.0),
		(star, 300, 50, -12, 0.75),
		(mint, 60, 270, 0, 0.85),
		(cane, 330, 290, 18, 0.9),
		(heart, 470, 420, -18, 0.6),
	]
	size = TILE * SS
	for fn, cx, cy, angle, scale in layout:
		shp = fn().rotate(angle, resample=Image.BICUBIC, expand=True)
		w = int(shp.width * scale)
		h = int(shp.height * scale)
		shp = shp.resize((w, h), Image.LANCZOS)
		x0 = int(cx * SS - w / 2)
		y0 = int(cy * SS - h / 2)
		for ox in (-size, 0, size):
			for oy in (-size, 0, size):
				_paste_clipped(tile, shp, x0 + ox, y0 + oy)
	tile = tile.resize((TILE, TILE), Image.LANCZOS)
	tile = tile.filter(ImageFilter.GaussianBlur(0.6))
	tile.save(OUT)
	print("wrote", os.path.normpath(OUT))


if __name__ == "__main__":
	main()
