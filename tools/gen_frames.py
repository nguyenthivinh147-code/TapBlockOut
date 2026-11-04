"""Draw the avatar frames frame_00..frame_12 as candy rounded squares, after the Figma Home avatar frame.

Reference: assets/ui/figma/ava_frame.png (124x124): a rounded square filling the canvas, corner radius 24, band 8,
transparent inside, flat 3-tone bevel lit from above (light on the outer top and inner bottom edge, dark on the outer
bottom and inner top edge, 2 px each). frame_00 redraws that frame; frame_01..12 keep its outline, radius and bevel on
a band of 10 (its inner edge meets the avatar, inset 8% by Profile.make_avatar) with candy patterns and decorations,
plain to rich in catalog order.
Drawn at 1024 (units of 1/124 of the side, like the reference), then shrunk to 256.
Output: art/images/frame_XX_candy.png (1024, source) and assets/frames/frame_XX.png (256).
Run: python3 tools/gen_frames.py [--sheet=<png>]   (--sheet also writes a preview over the avatars)
"""
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC_DIR = os.path.join(ROOT, "art", "images")
OUT_DIR = os.path.join(ROOT, "assets", "frames")
AVATAR_DIR = os.path.join(ROOT, "assets", "avatars")
SS = 1024  # drawing size
OUT = 256  # shipped size
U = SS / 124.0  # one reference pixel
RADIUS = 24 * U  # outer corner radius
BAND = 10 * U  # band of frame_01..12 (the reference has 8)
BEVEL = 2.5 * U  # light and dark edge width on the band
DECO_BEVEL = 1.6 * U  # same on decorations
LIGHT = 0.7  # white over the light edge (reference: FFEFA7 -> FFFBE7)
DARK = 0.25  # black over the dark edge (reference: FFEFA7 -> BFB37D)
OUTLINE = 1.1 * U  # decorations get a darker rim so they read over the band
AVATAR_PAD = 0.08  # Profile.make_avatar


def mask_new() -> Image.Image:
	return Image.new("L", (SS, SS), 0)


def rounded(inset: float, radius: float) -> Image.Image:
	m = mask_new()
	ImageDraw.Draw(m).rounded_rectangle([inset, inset, SS - 1 - inset, SS - 1 - inset], radius=int(radius), fill=255)
	return m


def ring(band: float) -> Image.Image:
	return ImageChops.subtract(rounded(0, RADIUS), rounded(band, RADIUS - band))


def shifted(m: Image.Image, dy: int) -> Image.Image:
	out = mask_new()
	out.paste(m, (0, dy))
	return out


def fill(img: Image.Image, mask: Image.Image, color, alpha: float = 1.0) -> None:
	layer = Image.new("RGBA", img.size, color)
	layer.putalpha(mask if alpha >= 1.0 else mask.point(lambda v: int(v * alpha)))
	img.alpha_composite(layer)


## Light where the pixel `d` above is outside the mask, dark where the pixel `d` below is: a tube lit from above.
def bevel(img: Image.Image, mask: Image.Image, d: float) -> None:
	d = int(round(d))
	fill(img, ImageChops.subtract(mask, shifted(mask, d)), "#FFFFFF", LIGHT)
	fill(img, ImageChops.subtract(mask, shifted(mask, -d)), "#000000", DARK)


def mix(color: str, other: str, t: float) -> str:
	a = [int(color[i:i + 2], 16) for i in (1, 3, 5)]
	b = [int(other[i:i + 2], 16) for i in (1, 3, 5)]
	return "#" + "".join("%02X" % round(x + (y - x) * t) for x, y in zip(a, b))


## A decoration piece: darker rim, flat colour, bevel, optional gloss dot at the top left.
def deco(img: Image.Image, mask: Image.Image, color: str, gloss: float = 0.0) -> None:
	k = int(OUTLINE) * 2 + 1
	fill(img, mask.filter(ImageFilter.MaxFilter(k)), mix(color, "#000000", 0.4))
	fill(img, mask, color)
	bevel(img, mask, DECO_BEVEL)
	if gloss > 0.0:
		box = mask.getbbox()
		if box:
			x = box[0] + (box[2] - box[0]) * 0.3
			y = box[1] + (box[3] - box[1]) * 0.3
			g = mask_new()
			ImageDraw.Draw(g).ellipse([x - gloss, y - gloss * 0.7, x + gloss, y + gloss * 0.7], fill=255)
			fill(img, ImageChops.multiply(g, mask), "#FFFFFF", 0.85)


def shape(draw_fn) -> Image.Image:
	m = mask_new()
	draw_fn(ImageDraw.Draw(m))
	return m


## Centre line of a band: a rounded square, measured clockwise from the top centre.
class Path:
	def __init__(self, band: float):
		self.a = band * 0.5
		self.b = SS - 1 - band * 0.5
		self.r = RADIUS - band * 0.5
		self.side = self.b - self.a - 2.0 * self.r
		self.arc = math.pi * self.r * 0.5
		self.length = 4.0 * (self.side + self.arc)

	## (x, y, tx, ty, nx, ny): point, tangent, outward normal.
	def at(self, s: float) -> tuple:
		a, b, r = self.a, self.b, self.r
		lines = [((a + r, a), (1, 0)), ((b, a + r), (0, 1)), ((b - r, b), (-1, 0)), ((a, b - r), (0, -1))]
		arcs = [((b - r, a + r), -90), ((b - r, b - r), 0), ((a + r, b - r), 90), ((a + r, a + r), 180)]
		s = (s + self.side * 0.5) % self.length
		for (p, t), (c, deg) in zip(lines, arcs):
			if s <= self.side:
				x, y, tx, ty = p[0] + t[0] * s, p[1] + t[1] * s, t[0], t[1]
				return x, y, tx, ty, ty, -tx
			s -= self.side
			if s <= self.arc:
				th = math.radians(deg) + s / r
				tx, ty = -math.sin(th), math.cos(th)
				return c[0] + r * math.cos(th), c[1] + r * math.sin(th), tx, ty, ty, -tx
			s -= self.arc
		return self.at(0.0)

	def place(self, s: float, across: float) -> tuple:
		x, y, _tx, _ty, nx, ny = self.at(s)
		return x + nx * across, y + ny * across


def corner_points(band: float) -> list:
	p = Path(band)
	c = math.cos(math.radians(45)) * p.r
	return [(p.a + p.r - c, p.a + p.r - c), (p.b - p.r + c, p.a + p.r - c), (p.b - p.r + c, p.b - p.r + c),
		(p.a + p.r - c, p.b - p.r + c)]


def ellipse_pts(cx: float, cy: float, rx: float, ry: float, ang: float, n: int = 40) -> list:
	ca, sa = math.cos(ang), math.sin(ang)
	pts = []
	for i in range(n):
		t = 2.0 * math.pi * i / n
		x, y = rx * math.cos(t), ry * math.sin(t)
		pts.append((cx + x * ca - y * sa, cy + x * sa + y * ca))
	return pts


def heart_pts(cx: float, cy: float, size: float, n: int = 48) -> list:
	k = size / 32.0
	pts = []
	for i in range(n):
		t = 2.0 * math.pi * i / n
		x = 16 * math.sin(t) ** 3
		y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
		pts.append((cx + x * k, cy - y * k - 1.5 * k))
	return pts


def star_pts(cx: float, cy: float, r: float, inner: float = 0.32) -> list:
	pts = []
	for i in range(8):
		rr = r if i % 2 == 0 else r * inner
		t = math.pi * 0.25 * i - math.pi * 0.5
		pts.append((cx + rr * math.cos(t), cy + rr * math.sin(t)))
	return pts


## Band in one colour, pattern drawn over it and clipped to the band, then the reference bevel.
def band_frame(base: str, pattern=None, mask: Image.Image | None = None) -> Image.Image:
	mask = mask if mask is not None else ring(BAND)
	layer = Image.new("RGBA", (SS, SS), base)
	if pattern is not None:
		pattern(ImageDraw.Draw(layer))
	layer.putalpha(mask)
	img = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))
	img.alpha_composite(layer)
	bevel(img, mask, BEVEL)
	return img


def spaced(path: Path, count: int, phase: float = 0.0) -> list:
	return [path.length * (i + phase) / count for i in range(count)]


def f00() -> Image.Image:
	mask = ring(8 * U)
	img = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))
	fill(img, mask, "#FFEFA7")
	bevel(img, mask, 2 * U)
	return img


def f01() -> Image.Image:  # bubblegum: plain pink
	return band_frame("#FF9CC8")


def f02() -> Image.Image:  # mint chocolate chip
	p = Path(BAND)
	rng = random.Random(2)

	def chips(d: ImageDraw.ImageDraw) -> None:
		for s in spaced(p, 30, 0.25):
			cx, cy = p.place(s + rng.uniform(-3, 3) * U, rng.uniform(-2.2, 2.2) * U)
			r = rng.uniform(1.3, 1.9) * U
			a0 = rng.uniform(0, math.pi)
			pts = [(cx + r * rng.uniform(0.7, 1.15) * math.cos(a0 + i * math.pi / 3),
				cy + r * rng.uniform(0.7, 1.15) * math.sin(a0 + i * math.pi / 3)) for i in range(6)]
			d.polygon(pts, fill="#6B4024")

	return band_frame("#8EE8C4", chips)


def f03() -> Image.Image:  # blueberry sugar: sparkles and sugar grains
	p = Path(BAND)
	rng = random.Random(3)

	def sugar(d: ImageDraw.ImageDraw) -> None:
		for i, s in enumerate(spaced(p, 44)):
			x, y = p.place(s, rng.uniform(-2.8, 2.8) * U)
			r = 0.7 * U
			d.ellipse([x - r, y - r, x + r, y + r], fill="#D8F0FF")
		for s in spaced(p, 12, 0.5):
			x, y = p.place(s, 0.0)
			d.polygon(star_pts(x, y, 3.6 * U), fill="#FFFFFF")

	return band_frame("#4FA6FF", sugar)


def stripes(p: Path, count: int, width: float, slant: float, color: str):
	def draw(d: ImageDraw.ImageDraw) -> None:
		h = BAND
		for s in spaced(p, count):
			x, y, tx, ty, nx, ny = p.at(s)
			pts = []
			for n, w in ((h, width), (h, -width), (-h, -width), (-h, width)):
				o = n * slant + w * 0.5
				pts.append((x + nx * n + tx * o, y + ny * n + ty * o))
			d.polygon(pts, fill=color)
	return draw


def f04() -> Image.Image:  # candy cane
	p = Path(BAND)
	return band_frame("#FFFFFF", stripes(p, 28, 6.0 * U, 0.9, "#F2394B"))


def f05() -> Image.Image:  # strawberry icing with rainbow sprinkles
	p = Path(BAND)
	rng = random.Random(5)
	colors = ["#FFFFFF", "#FFD640", "#56D66B", "#3FA9FF", "#A46BFF", "#FF7A2F"]

	def sprinkles(d: ImageDraw.ImageDraw) -> None:
		for i, s in enumerate(spaced(p, 46)):
			x, y = p.place(s + rng.uniform(-1.5, 1.5) * U, rng.uniform(-2.4, 2.4) * U)
			a = rng.uniform(0, math.pi)
			l = 1.7 * U
			x0, y0, x1, y1 = x - l * math.cos(a), y - l * math.sin(a), x + l * math.cos(a), y + l * math.sin(a)
			c = colors[i % len(colors)]
			w = 1.3 * U
			d.line([x0, y0, x1, y1], fill=c, width=int(w * 2))
			d.ellipse([x0 - w, y0 - w, x0 + w, y0 + w], fill=c)
			d.ellipse([x1 - w, y1 - w, x1 + w, y1 + w], fill=c)

	return band_frame("#FF7FB0", sprinkles)


def f06() -> Image.Image:  # grape band with jelly beans
	p = Path(BAND)
	colors = ["#FF5C7A", "#FFD23F", "#6EE06A", "#FFFFFF", "#FF9A3C", "#5CC8FF"]
	img = band_frame("#9C5BE6")
	for i, s in enumerate(spaced(p, 16, 0.5)):
		x, y, tx, ty, _nx, _ny = p.at(s)
		ang = math.atan2(ty, tx) + (0.35 if i % 2 else -0.35)
		pts = ellipse_pts(x, y, 4.3 * U, 2.7 * U, ang)
		deco(img, shape(lambda d, pts=pts: d.polygon(pts, fill=255)), colors[i % len(colors)], 1.0 * U)
	return img


def f07() -> Image.Image:  # chocolate with caramel drizzle and white pearls
	p = Path(BAND)

	def drizzle(d: ImageDraw.ImageDraw) -> None:
		n = 400
		waves = 26
		pts = [p.place(p.length * i / n, 2.6 * U * math.sin(2 * math.pi * waves * i / n)) for i in range(n + 1)]
		d.line(pts, fill="#F6B04A", width=int(1.8 * U), joint="curve")
		for i in range(waves):
			x, y = p.place(p.length * (i + 0.5) / waves, 0.0)
			r = 1.15 * U
			d.ellipse([x - r, y - r, x + r, y + r], fill="#FFF6E8")

	return band_frame("#7A4A2E", drizzle)


def gumdrop(cx: float, cy: float, w: float, h: float):
	def draw(d: ImageDraw.ImageDraw) -> None:
		d.ellipse([cx - w, cy - h, cx + w, cy + h * 0.9], fill=255)
		d.rounded_rectangle([cx - w, cy, cx + w, cy + h * 0.55], radius=int(h * 0.25), fill=255)
	return draw


def f08() -> Image.Image:  # teal jelly with gumdrops at the corners
	p = Path(BAND)
	rng = random.Random(8)

	def dots(d: ImageDraw.ImageDraw) -> None:
		for s in spaced(p, 40):
			x, y = p.place(s, rng.uniform(-2.6, 2.6) * U)
			r = 0.65 * U
			d.ellipse([x - r, y - r, x + r, y + r], fill="#D9FFF6")

	img = band_frame("#2CC7B0", dots)
	for (x, y), c in zip(corner_points(BAND), ["#FF4F6D", "#FFC93C", "#A65BFF", "#FF8A2B"]):
		m = shape(gumdrop(x, y + 0.5 * U, 8.6 * U, 9.0 * U))
		deco(img, m, c, 1.8 * U)
		sugar = mask_new()
		sd = ImageDraw.Draw(sugar)
		for dx, dy in ((-3.8, 0.8), (0.4, -3.0), (3.4, 2.2), (-0.8, 3.6), (4.6, -1.4), (-2.0, -1.6)):
			r = 0.7 * U
			sd.ellipse([x + dx * U - r, y + dy * U - r, x + dx * U + r, y + dy * U + r], fill=255)
		fill(img, ImageChops.multiply(sugar, m), "#FFFFFF", 0.8)
	return img


def f09() -> Image.Image:  # rainbow candy belt
	p = Path(BAND)
	colors = ["#FF4D5E", "#FF9A2E", "#FFD93B", "#5BD65E", "#33B4FF", "#7A6CFF", "#D45CF2"]
	count = 21

	def belt(d: ImageDraw.ImageDraw) -> None:
		steps = 600
		h = BAND
		for i in range(steps):
			s0, s1 = p.length * i / steps, p.length * (i + 1.5) / steps
			c = colors[int(count * (i + 0.5) / steps) % len(colors)]
			x0, y0, _a, _b, nx0, ny0 = p.at(s0)
			x1, y1, _c, _d, nx1, ny1 = p.at(s1)
			d.polygon([(x0 + nx0 * h, y0 + ny0 * h), (x1 + nx1 * h, y1 + ny1 * h), (x1 - nx1 * h, y1 - ny1 * h),
				(x0 - nx0 * h, y0 - ny0 * h)], fill=c)

	return band_frame("#FFFFFF", belt)


def bow(img: Image.Image, cx: float, cy: float, size: float, color: str) -> None:
	knot = color
	loops = mask_new()
	d = ImageDraw.Draw(loops)
	for side in (-1, 1):
		d.polygon(ellipse_pts(cx + side * size * 0.52, cy - size * 0.05, size * 0.5, size * 0.3, side * -0.32), fill=255)
		d.polygon([(cx + side * size * 0.08, cy), (cx + side * size * 0.48, cy + size * 0.62),
			(cx + side * size * 0.22, cy + size * 0.58), (cx + side * size * 0.02, cy + size * 0.2)], fill=255)
	deco(img, loops, color)
	inner = mask_new()
	di = ImageDraw.Draw(inner)
	for side in (-1, 1):
		di.polygon(ellipse_pts(cx + side * size * 0.5, cy - size * 0.03, size * 0.24, size * 0.12, side * -0.32), fill=255)
	fill(img, inner, mix(color, "#000000", 0.3))
	k = size * 0.2
	deco(img, shape(lambda dd: dd.rounded_rectangle([cx - k, cy - k * 1.1, cx + k, cy + k * 1.1], radius=int(k * 0.6),
		fill=255)), mix(knot, "#FFFFFF", 0.15), 0.5 * U)


def f10() -> Image.Image:  # sweetheart: red band, white hearts, pink bow on top
	p = Path(BAND)

	def hearts(d: ImageDraw.ImageDraw) -> None:
		for s in spaced(p, 18, 0.5):
			x, y = p.place(s, 0.0)
			d.polygon(heart_pts(x, y, 5.2 * U), fill="#FFE3EE")

	img = band_frame("#F2425F", hearts)
	bow(img, SS * 0.5, 11.0 * U, 28 * U, "#FF8FC4")
	return img


def f11() -> Image.Image:  # cream frosting, piped edge, pastel dots, cherry on top
	bump = 3.6 * U
	inner = BAND + 1.0 * U
	base = ImageChops.subtract(rounded(bump, RADIUS - bump), rounded(inner, RADIUS - inner))
	edge = Path(bump * 2.0)
	scallop = mask_new()
	sd = ImageDraw.Draw(scallop)
	for s in spaced(edge, 44):
		x, y = edge.place(s, 0.0)
		sd.ellipse([x - bump, y - bump, x + bump, y + bump], fill=255)
	mask = ImageChops.lighter(base, ImageChops.multiply(scallop, rounded(0, RADIUS)))
	p = Path(BAND)
	colors = ["#FF8DBE", "#6FD9B6", "#7FC2FF", "#FFD45C", "#B98CFF"]

	def dots(d: ImageDraw.ImageDraw) -> None:
		for i, s in enumerate(spaced(p, 30, 0.5)):
			x, y = p.place(s, 0.3 * U * (1 if i % 2 else -1))
			r = 1.2 * U
			d.ellipse([x - r, y - r, x + r, y + r], fill=colors[i % len(colors)])

	img = band_frame("#FFF3E2", dots, mask)
	cx, cy = SS * 0.5, 12.0 * U
	stem = mask_new()
	ImageDraw.Draw(stem).line([(cx, cy - 5 * U), (cx + 2.5 * U, cy - 8.5 * U), (cx + 6 * U, cy - 10.2 * U)],
		fill=255, width=int(1.3 * U), joint="curve")
	deco(img, stem, "#5BA83A")
	leaf = ellipse_pts(cx + 8.0 * U, cy - 8.2 * U, 3.2 * U, 1.6 * U, -0.5)
	deco(img, shape(lambda d: d.polygon(leaf, fill=255)), "#6CCB45")
	deco(img, shape(lambda d: d.ellipse([cx - 7.0 * U, cy - 6.2 * U, cx + 7.0 * U, cy + 7.0 * U], fill=255)),
		"#E8213F", 2.0 * U)
	return img


def gem(img: Image.Image, cx: float, cy: float, r: float, color: str, diamond: bool) -> None:
	if diamond:
		outer = [(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)]
		k = r * 0.5
		inner = [(cx, cy - k), (cx + k, cy), (cx, cy + k), (cx - k, cy)]
		deco(img, shape(lambda d: d.polygon(outer, fill=255)), color)
		fill(img, shape(lambda d: d.polygon(inner, fill=255)), mix(color, "#FFFFFF", 0.4))
	else:
		deco(img, shape(lambda d: d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)), color)
		k = r * 0.55
		fill(img, shape(lambda d: d.ellipse([cx - k, cy - k, cx + k, cy + k], fill=255)), mix(color, "#FFFFFF", 0.35))
	g = r * 0.22
	gx, gy = cx - r * 0.3, cy - r * 0.35
	fill(img, shape(lambda d: d.ellipse([gx - g, gy - g, gx + g, gy + g], fill=255)), "#FFFFFF", 0.95)


def f12() -> Image.Image:  # golden caramel with candy gems
	p = Path(BAND)

	def studs(d: ImageDraw.ImageDraw) -> None:
		for s in spaced(p, 36, 0.5):
			x, y = p.place(s, 0.0)
			r = 1.0 * U
			d.ellipse([x - r, y - r, x + r, y + r], fill="#FFE58A")

	img = band_frame("#F2B92C", studs)
	for (x, y), c in zip(corner_points(BAND), ["#FF3D5A", "#3D8BFF", "#36C46A", "#A65BFF"]):
		gem(img, x, y, 7.6 * U, c, True)
	h = SS * 0.5
	for x, y in ((p.a, h), (p.b, h), (h, p.b)):
		gem(img, x, y, 4.4 * U, "#FF6FB5", False)
	gem(img, h, 9.4 * U, 7.8 * U, "#FF4FA0", False)
	return img


FRAMES = [f00, f01, f02, f03, f04, f05, f06, f07, f08, f09, f10, f11, f12]


def sheet(frames: list, path: str) -> None:
	cell = 140
	side = 124
	w = Image.new("RGBA", (cell * 7, cell * 4), (58, 52, 92, 255))
	for i, fr in enumerate(frames):
		for row, with_avatar in ((0, True), (1, False)):
			tile = Image.new("RGBA", (side, side), (0, 0, 0, 0))
			av_path = os.path.join(AVATAR_DIR, "avatar_%02d.png" % (i % 11))
			if with_avatar and os.path.exists(av_path):
				pad = int(side * AVATAR_PAD)
				av = Image.open(av_path).convert("RGBA").resize((side - 2 * pad, side - 2 * pad), Image.LANCZOS)
				tile.alpha_composite(av, (pad, pad))
			tile.alpha_composite(fr.resize((side, side), Image.LANCZOS))
			x = (i % 7) * cell + 8
			y = ((i // 7) * 2 + row) * cell + 8
			w.alpha_composite(tile, (x, y))
	w.save(path)


def main() -> None:
	sheet_path = ""
	for a in sys.argv[1:]:
		if a.startswith("--sheet="):
			sheet_path = a.split("=", 1)[1]
	out = []
	for i, fn in enumerate(FRAMES):
		img = fn()
		img.save(os.path.join(SRC_DIR, "frame_%02d_candy.png" % i))
		small = img.resize((OUT, OUT), Image.LANCZOS)
		small.save(os.path.join(OUT_DIR, "frame_%02d.png" % i))
		out.append(small)
		print("frame_%02d" % i)
	if sheet_path:
		sheet(out, sheet_path)


if __name__ == "__main__":
	main()
