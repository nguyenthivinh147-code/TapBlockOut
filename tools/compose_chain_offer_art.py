#!/usr/bin/env python3
"""Build assets/ui/art_chain_offer.png, the Chain Offer title art, with this game's boosters.

The prefab's chest (assets/ui/cc/ic_EndlessTreasure.png, left untouched) carries the Unity game's boosters
(magnet, up-arrow, block tile). art/images/chain_offer_erased_ai.png is a ComfyUI edit of it (flattened on white,
1024 px) with those three erased; see art/manifest.json, entry art_chain_offer. This script keeps the original
everywhere except the three booster areas, takes the AI fill there, and lays hint, move, smash on top.

Run from anywhere: python3 tools/compose_chain_offer_art.py [--preview=out.png]
Re-run after changing assets/ui/booster_*.png. Dev tool only, needs Pillow.
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ORIG = os.path.join(ROOT, "assets", "ui", "cc", "ic_EndlessTreasure.png")
ERASED = os.path.join(ROOT, "art", "images", "chain_offer_erased_ai.png")
OUT = os.path.join(ROOT, "assets", "ui", "art_chain_offer.png")
BOOSTER = os.path.join(ROOT, "assets", "ui", "booster_%s.png")

# Boxes around the three old boosters (512 px image): magnet, arrow on its pad, block tile.
BOXES = [(120, 228, 206, 314), (216, 256, 303, 344), (312, 226, 403, 326)]
# The AI image's background (off-white) and how far below it a pixel turns fully opaque.
BG = 251
BG_MARGIN = 8
BG_RAMP = 50.0
# The original's faint white glow around the chest: alpha range and blur radius used to rebuild it.
GLOW_MAX = 40
GLOW_BLUR = 14
# RewardText.BOOSTER_ORDER left to right: (name, centre x, centre y, height, rotation degrees).
PLACE = [
	("hint", 163, 271, 84, 12),
	("move", 262, 300, 76, -4),
	("smash", 358, 272, 90, -8),
]
SHADOW = (70, 25, 0)
SHADOW_ALPHA = 0.45
SHADOW_OFFSET = (3, 5)
SHADOW_BLUR = 3


def erased_mask(orig, rem, size):
	"""Where the AI result differs from the original flattened on white, inside BOXES, grown and feathered."""
	flat = Image.new("RGBA", size, (255, 255, 255, 255))
	flat.alpha_composite(orig)
	diff = ImageChops.difference(flat.convert("RGB"), rem).convert("L").point(lambda v: 255 if v > 40 else 0)
	boxes = Image.new("L", size, 0)
	d = ImageDraw.Draw(boxes)
	for b in BOXES:
		d.rectangle(b, fill=255)
	mask = ImageChops.multiply(diff, boxes)
	mask = mask.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(2))
	return ImageChops.multiply(mask, boxes.filter(ImageFilter.GaussianBlur(3)))


def uncomposite(rem, size):
	"""AI pixels back to RGBA: alpha from the distance to the off-white background, colour un-mixed from white."""
	w, h = size
	fill = Image.new("RGBA", size)
	src = rem.load()
	dst = fill.load()
	for y in range(h):
		for x in range(w):
			r, g, b = src[x, y]
			a = max(0.0, min(1.0, (BG - BG_MARGIN - min(r, g, b)) / BG_RAMP))
			if a <= 0:
				dst[x, y] = (0, 0, 0, 0)
				continue
			f = lambda c: int(max(0, min(255, (c - (1 - a) * 255) / a)))
			dst[x, y] = (f(r), f(g), f(b), int(a * 255))
	return fill


def glow_under(orig, mask, size):
	"""White layer whose alpha continues the original glow into the masked areas (normalised blur)."""
	w, h = size
	oa = orig.getchannel("A")
	outside = ImageChops.invert(mask.point(lambda v: 255 if v > 0 else 0))
	valid = ImageChops.multiply(outside, oa.point(lambda v: 255 if 0 < v < GLOW_MAX else 0))
	num = ImageChops.multiply(oa, valid).filter(ImageFilter.GaussianBlur(GLOW_BLUR))
	den = valid.filter(ImageFilter.GaussianBlur(GLOW_BLUR))
	na, da = num.load(), den.load()
	alpha = Image.new("L", size, 0)
	ga = alpha.load()
	for y in range(h):
		for x in range(w):
			if da[x, y] > 2:
				ga[x, y] = min(GLOW_MAX, round(na[x, y] * 255 / da[x, y]))
	glow = Image.new("RGBA", size, (255, 255, 255, 0))
	glow.putalpha(alpha)
	return glow


def place_boosters(base):
	for name, cx, cy, h, rot in PLACE:
		ic = Image.open(BOOSTER % name).convert("RGBA")
		ic = ic.crop(ic.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())
		w = round(ic.width * h / ic.height)
		ic = ic.resize((w, h), Image.LANCZOS).rotate(rot, Image.BICUBIC, expand=True)
		x, y = cx - ic.width // 2, cy - ic.height // 2
		sx, sy = x + SHADOW_OFFSET[0], y + SHADOW_OFFSET[1]
		# Contact shadow, only on the opaque chest and coins, never onto the transparent margin.
		sh = Image.new("RGBA", ic.size, SHADOW + (0,))
		sa = ic.getchannel("A").point(lambda v: v * SHADOW_ALPHA).filter(ImageFilter.GaussianBlur(SHADOW_BLUR))
		under = base.getchannel("A").crop((sx, sy, sx + ic.width, sy + ic.height))
		sh.putalpha(ImageChops.multiply(sa, under))
		base.alpha_composite(sh, (sx, sy))
		base.alpha_composite(ic, (x, y))


def main():
	orig = Image.open(ORIG).convert("RGBA")
	size = orig.size
	rem = Image.open(ERASED).convert("RGB").resize(size, Image.LANCZOS)
	mask = erased_mask(orig, rem, size)
	fill = glow_under(orig, mask, size)
	fill.alpha_composite(uncomposite(rem, size))
	base = Image.composite(fill, orig, mask)
	place_boosters(base)
	base.save(OUT, optimize=True)
	print("wrote", os.path.relpath(OUT, ROOT), base.size)
	for arg in sys.argv[1:]:
		if arg.startswith("--preview="):
			prev = Image.new("RGBA", (size[0] * 2 + 20, size[1]), (40, 40, 64, 255))
			prev.alpha_composite(orig, (0, 0))
			prev.alpha_composite(base, (size[0] + 20, 0))
			prev.save(arg.split("=", 1)[1])


if __name__ == "__main__":
	main()
