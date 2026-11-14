"""Home art of the pastel theme, matched to the Figma ref "2.1 Home" (node 106:385, saved as
art/concepts/ref_home_pastel_106_385.png, 886x1920 = design px on an 886-wide screen). docs/UI_THEME_PASTEL.md.

  uv run --no-project --with numpy --with pillow --with scipy python -I tools/make_pastel_home.py [--chip] [--sheet out.png]

--chip: only the chip (hub_chip.png).

Writes the inputs of tools/theme_recolor.py into art/themes/pastel/ (rules "overlays" and "source" in
tools/theme_pastel.json), then run theme_recolor.py to rebuild the twins:

- node_<atlas key>.png: level badges (six-petal candy flower), each the size of its atlas_main region. Sources are the
  ref badges cleaned by ComfyUI (art/images/pastel_node_src_n23/n22/n24.png: number, skull, check, padlock removed,
  flat navy background; inputs art/images/pastel_node_ref_*.png are the ref crops). n23 (pink) -> hex_red and,
  recoloured, hex_purple, hex_green, node_green; n24 (lavender) -> hex_gray, node_gray; n22 (mint) -> hex_blue.
  Each flower keeps its on-screen size in the ref, given how home.gd draws the region (current node 290 minus inset 6
  each side, other nodes 220 minus 5; node_green fills its 290 node).
- home_rail_straight.png: the candy rail (64x2008) tiled from one stripe period of the ref rail, which sits at the
  same x as RAIL_RECT (411..475).

Also writes assets/ui/figma/home_play_normal.png (a copy of the atlas pill_green: the Home PLAY at a normal level, whose
pastel twin is recoloured by theme_recolor.py with map "play_green", the same map as every other green button) and
assets/ui/figma/hub_chip.png (no twin: the lives and gold chips of src/ui/hub_top.gd were a code
StyleBoxFlat): the chip of the ref, a 3D pill drawn from the colour profile measured across the ref chip (thin light
lavender rim on top, white highlight, cream-peach body getting warmer downwards, tan-pink lip and dark lavender rim at the
bottom, soft lavender shadow below). CHIP_SCALE x design px; hub_top.gd scales it to the bar and 9-slices it across.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REF = os.path.join(ROOT, "art/concepts/ref_home_pastel_106_385.png")
OUT = os.path.join(ROOT, "art/themes/pastel")

# atlas key: (region x, y, w, h), source, (hue, saturation factor, value factor) of a recolour or None, on-screen sprite
# px of the node drawing this region. Normal tier green: dimmed a little (2026-11-13, "giảm nhẹ" of
# art/concepts/concept_home_normal_tier_v3.png).
REGIONS = {
	"hex_red": ((1645, 288, 200, 200), "n23", None, 278.0),
	"hex_purple": ((1847, 288, 201, 200), "n23", (276.0, 1.0, 1.0), 278.0),
	"hex_green": ((1040, 288, 201, 200), "n23", (100.0, 0.70, 0.95), 278.0),
	"node_green": ((1749, 1751, 282, 282), "n23", (100.0, 0.70, 0.95), 290.0),
	"hex_gray": ((1443, 288, 201, 200), "n24", None, 210.0),
	"node_gray": ((1511, 1831, 216, 216), "n24", None, 210.0),
	"hex_blue": ((1242, 288, 200, 200), "n22", None, 210.0),
}
# Rail: ref columns 411..475 (RAIL_RECT x), stripe rows sampled between the locked badge and the skull.
RAIL_X = 411
RAIL_W = 64
RAIL_H = 2008
RAIL_ROWS = (452, 600)


def smooth(e0, e1, x):
	t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def key_out(path):
	"""Flat-background AI render -> float RGBA cut-out (background = pixels near the border colour, connected to it)."""
	im = np.asarray(Image.open(path).convert("RGB")).astype(np.float64) / 255.0
	border = np.concatenate([im[0], im[-1], im[:, 0], im[:, -1]])
	bg = np.median(border, axis=0)
	dist = np.sqrt(((im - bg) ** 2).sum(-1))
	lo, hi = 0.06, 0.30
	cand = dist < hi
	lab, _n = ndimage.label(cand)
	edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
	outside = np.isin(lab, list(edge))
	alpha = np.where(outside, smooth(lo, hi, dist), 1.0)
	a = np.maximum(alpha, 1e-3)[..., None]
	rgb = np.clip((im - (1.0 - a) * bg) / a, 0.0, 1.0)
	rgba = np.concatenate([rgb, alpha[..., None]], -1)
	ys, xs = np.nonzero(alpha > 0.03)
	return rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def rgb_to_hsv(rgb):
	mx = rgb.max(-1)
	mn = rgb.min(-1)
	d = mx - mn
	r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
	nz = d > 1e-6
	dd = np.where(nz, d, 1.0)
	h = np.where(r == mx, (g - b) / dd, np.where(g == mx, 2.0 + (b - r) / dd, 4.0 + (r - g) / dd))
	h = np.where(nz, (h / 6.0) % 1.0, 0.0) * 360.0
	s = np.where(mx > 1e-6, d / np.where(mx > 1e-6, mx, 1.0), 0.0)
	return h, s, mx


def hsv_to_rgb(h, s, v):
	h = (h % 360.0) / 60.0
	i = np.floor(h).astype(int) % 6
	f = h - np.floor(h)
	p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
	out = np.zeros(h.shape + (3,))
	for k, (a, b, c) in enumerate([(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)]):
		m = i == k
		for ch, src in enumerate((a, b, c)):
			out[..., ch] = np.where(m, src, out[..., ch])
	return out


def shift_hue(rgba, recolour):
	"""Pink badge -> another hue: only saturated pink/red pixels move (the cream rim and white gloss stay)."""
	target, sat, val = recolour
	rgb = rgba[..., :3]
	h, s, v = rgb_to_hsv(rgb)
	dist = np.abs((h - 350.0 + 180.0) % 360.0 - 180.0)
	w = (1.0 - smooth(30.0, 42.0, dist)) * smooth(0.10, 0.22, s)
	new = hsv_to_rgb(h - 350.0 + target, s * sat, np.clip(v * val, 0.0, 1.0))
	out = rgba.copy()
	out[..., :3] = rgb * (1 - w[..., None]) + new * w[..., None]
	return out


def resize_rgba(rgba, size):
	"""Resize in premultiplied space so no dark fringe comes from the cut-out edge."""
	pre = rgba.copy()
	pre[..., :3] *= pre[..., 3:4]
	chans = [np.asarray(Image.fromarray((pre[..., c] * 65535).astype(np.uint16).astype(np.int32), "I").resize(size, Image.LANCZOS), dtype=np.float64) / 65535 for c in range(4)]
	out = np.clip(np.stack(chans, -1), 0.0, 1.0)
	a = np.maximum(out[..., 3:4], 1e-6)
	out[..., :3] = np.where(out[..., 3:4] > 1e-6, np.clip(out[..., :3] / a, 0, 1), 0)
	return out


def to_image(rgba):
	return Image.fromarray((np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


def badges():
	cuts = {}
	for name in ("n23", "n22", "n24"):
		src = os.path.join(ROOT, "art/images/pastel_node_src_%s.png" % name)
		ref = Image.open(os.path.join(ROOT, "art/images/pastel_node_ref_%s.png" % name))
		cut = key_out(src)
		scale = Image.open(src).size[0] / ref.size[0]
		# flower size in ref px (ref crop and render share the framing)
		cuts[name] = (cut, cut.shape[1] / scale, cut.shape[0] / scale)
		print("%s: flower %.1f x %.1f ref px" % (name, cuts[name][1], cuts[name][2]))
	out = {}
	for key, (rect, name, recolour, sprite_px) in REGIONS.items():
		cut, w_ref, h_ref = cuts[name]
		rw, rh = rect[2], rect[3]
		k = min(rw, rh) / sprite_px
		w, h = w_ref * k, h_ref * k
		fit = min(1.0, (rw - 2) / w, (rh - 2) / h)
		w, h = int(round(w * fit)), int(round(h * fit))
		art = shift_hue(cut, recolour) if recolour is not None else cut
		art = resize_rgba(art, (w, h))
		canvas = np.zeros((rh, rw, 4))
		x0, y0 = (rw - w) // 2, (rh - h) // 2
		canvas[y0:y0 + h, x0:x0 + w] = art
		path = os.path.join(OUT, "node_%s.png" % key)
		to_image(canvas).save(path, optimize=True)
		out[key] = path
		print("%-10s %dx%d flower %dx%d (fit %.3f) -> %s" % (key, rw, rh, w, h, fit, os.path.relpath(path, ROOT)))
	return out


def rail():
	ref = np.asarray(Image.open(REF).convert("RGB")).astype(np.float64) / 255.0
	strip = ref[RAIL_ROWS[0]:RAIL_ROWS[1], RAIL_X:RAIL_X + RAIL_W]
	# stripe period from the autocorrelation of the rail's middle columns
	col = strip[:, 20:44].mean(1).mean(-1)
	col = col - col.mean()
	n = len(col)
	best, period = -1e9, 0
	for p in range(40, n - 20):
		c = (col[:n - p] * col[p:]).sum() / (n - p)
		if c > best:
			best, period = c, p
	# start row whose row one period later matches best (seamless tile)
	err = [((strip[y] - strip[y + period]) ** 2).sum() for y in range(0, n - period)]
	y0 = int(np.argmin(err))
	tile = strip[y0:y0 + period]
	# columns of the rail: where the rail differs from the background beside it
	bg = np.concatenate([strip[:, :3], strip[:, -3:]], 1).mean(1, keepdims=True)
	diff = np.sqrt(((strip - bg) ** 2).sum(-1)).mean(0)
	inside = np.nonzero(diff > 0.05)[0]
	left, right = int(inside.min()), int(inside.max())
	alpha = np.zeros(RAIL_W)
	alpha[left:right + 1] = 1.0
	alpha[max(left - 1, 0)] = 0.5
	alpha[min(right + 1, RAIL_W - 1)] = 0.5
	reps = int(np.ceil(RAIL_H / period))
	rgb = np.tile(tile, (reps, 1, 1))[:RAIL_H]
	rgba = np.concatenate([rgb, np.broadcast_to(alpha[None, :, None], (RAIL_H, RAIL_W, 1))], -1)
	path = os.path.join(OUT, "home_rail_straight.png")
	to_image(rgba).save(path, optimize=True)
	print("rail: period %d px from ref row %d, columns %d..%d -> %s" % (period, RAIL_ROWS[0] + y0, left, right, os.path.relpath(path, ROOT)))
	return path


# Chip (design px; hub_top.gd: bar 250 x 70). Body = the bar rect, shadow hangs CHIP_SHADOW below it.
CHIP_SCALE = 3
CHIP_H = 70.0
CHIP_SHADOW = 8.0
CHIP_MID = 6.0  # stretchable middle between the two caps
CHIP_OUT = os.path.join(ROOT, "assets/ui/figma/hub_chip.png")
# vertical gradients (design y from the body top, colour), measured on the ref chip at x 590 (ref y 64..137)
CHIP_RIM = [(0.0, "C3ABE3"), (35.0, "B395D6"), (70.0, "8E72AF")]
CHIP_LIP = [(56.0, "F3DCCB"), (63.0, "E8C6B4"), (67.6, "E8B3C2")]
CHIP_FILL = [(2.0, "EFE1F7"), (4.0, "FFF7FC"), (7.0, "FFF4F2"), (10.0, "FEF0E8"), (35.0, "FFF1E6"), (58.0, "FDF0DF"),
	(64.6, "FCF6E4")]
CHIP_SHADOW_RGBA = ("B48BD0", 0.55)


def _hex(h):
	return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64) / 255.0


def _vgrad(stops, h_px, k):
	ys = np.arange(h_px) / k
	out = np.zeros((h_px, 3))
	for c in range(3):
		out[:, c] = np.interp(ys, [s[0] for s in stops], [_hex(s[1])[c] for s in stops])
	return out


def _pill_mask(w, h, box, k):
	"""Anti-aliased pill (radius = half height) for box (l, t, r, b) in design px, rendered at k px per design px."""
	m = Image.new("L", (w, h), 0)
	l, t, r, b = [v * k for v in box]
	ImageDraw.Draw(m).rounded_rectangle((l, t, r - 1, b - 1), radius=(b - t) * 0.5, fill=255)
	return np.asarray(m).astype(np.float64) / 255.0


def chip():
	ss = 4
	k = CHIP_SCALE * ss
	wd = CHIP_H + CHIP_MID  # design width: two caps of CHIP_H / 2 and the middle
	hd = CHIP_H + CHIP_SHADOW
	w, h = int(round(wd * k)), int(round(hd * k))
	rgb = np.zeros((h, w, 3))
	alpha = np.zeros((h, w))

	def layer(mask, colour):
		nonlocal rgb, alpha
		a = mask[..., None]
		rgb = colour * a + rgb * (1 - a)
		alpha = mask + alpha * (1 - mask)

	# soft lavender shadow under the body
	sh = Image.fromarray((_pill_mask(w, h, (0.5, 4.5, wd - 0.5, CHIP_H + 4.5), k) * 255).astype(np.uint8), "L")
	sh = np.asarray(sh.filter(ImageFilter.GaussianBlur(2.5 * k))).astype(np.float64) / 255.0
	sc, sa = CHIP_SHADOW_RGBA
	layer(sh * sa, np.broadcast_to(_hex(sc), (h, w, 3)))
	layer(_pill_mask(w, h, (0, 0, wd, CHIP_H), k), _vgrad(CHIP_RIM, h, k)[:, None, :])
	layer(_pill_mask(w, h, (2.2, 2.2, wd - 2.2, CHIP_H - 2.6), k), _vgrad(CHIP_LIP, h, k)[:, None, :])
	layer(_pill_mask(w, h, (2.2, 2.2, wd - 2.2, CHIP_H - 5.4), k), _vgrad(CHIP_FILL, h, k)[:, None, :])
	pre = np.concatenate([rgb * alpha[..., None], alpha[..., None]], -1)
	size = (int(round(wd * CHIP_SCALE)), int(round(hd * CHIP_SCALE)))
	small = np.stack([np.asarray(Image.fromarray((pre[..., c] * 65535).astype(np.int32), "I").resize(size, Image.BOX),
		dtype=np.float64) / 65535 for c in range(4)], -1)
	a = small[..., 3:4]
	small[..., :3] = np.where(a > 1e-6, small[..., :3] / np.maximum(a, 1e-6), 0)
	to_image(small).save(CHIP_OUT, optimize=True)
	print("chip: %dx%d (body %d px, shadow %d px, caps %d px) -> %s" % (size[0], size[1], CHIP_H * CHIP_SCALE,
		CHIP_SHADOW * CHIP_SCALE, CHIP_H * CHIP_SCALE / 2, os.path.relpath(CHIP_OUT, ROOT)))
	return CHIP_OUT


# Home PLAY at a normal level: its own copy of the atlas pill_green. Its pastel twin (map "play_green" in
# tools/theme_pastel.json, softer apple green with the same stripes and gloss) matches the other green buttons, which
# use the same map since 2026-11-13.
PLAY_SRC = os.path.join(ROOT, "assets/ui/figma/atlas_main.png")
PLAY_RECT = (0, 816, 380, 168)
PLAY_OUT = os.path.join(ROOT, "assets/ui/figma/home_play_normal.png")


def play_normal():
	x, y, w, h = PLAY_RECT
	Image.open(PLAY_SRC).convert("RGBA").crop((x, y, x + w, y + h)).save(PLAY_OUT, optimize=True)
	print("play: %s pill_green %s -> %s" % (os.path.relpath(PLAY_SRC, ROOT), PLAY_RECT, os.path.relpath(PLAY_OUT, ROOT)))
	return PLAY_OUT


def sheet(paths, dest):
	tiles = [Image.open(p).convert("RGBA") for p in paths]
	tiles = [t.crop((0, 0, t.size[0], min(t.size[1], 300))) for t in tiles]
	w = sum(t.size[0] for t in tiles) + 20 * (len(tiles) + 1)
	h = max(t.size[1] for t in tiles) + 40
	bg = Image.new("RGBA", (w, h), (244, 220, 246, 255))
	x = 20
	for t in tiles:
		bg.alpha_composite(t, (x, 20))
		x += t.size[0] + 20
	bg.save(dest)


def main():
	os.makedirs(OUT, exist_ok=True)
	only_chip = "--chip" in sys.argv
	paths = []
	if not only_chip:
		paths += list(badges().values())
		paths.append(rail())
		paths.append(play_normal())
	paths.append(chip())
	if "--sheet" in sys.argv:
		sheet(paths, sys.argv[sys.argv.index("--sheet") + 1])


if __name__ == "__main__":
	main()
