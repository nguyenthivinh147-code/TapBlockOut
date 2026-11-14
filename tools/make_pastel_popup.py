"""Popup title plate of the pastel theme with the lip and drop shadow of the user's ref (2026-11-13, the Settings
popup redrawn: a darker rose band along the bottom of the pink plate and a soft rose shadow on the cream below).
docs/UI_THEME_PASTEL.md "Khung popup".

  uv run --no-project --with numpy --with pillow --with scipy python -I tools/make_pastel_popup.py [--sheet out.png]

The plate is the atlas region 384,1332 368x108 (UI_Maincenter_60 of Resources_moved_UI_Maincenter.png, used by every
Unity popup; label_purple of atlas_main.png, used by popup_kit.gd, 9-sliced there with bottom margin 22). The region is
filled by the plate, so the plate is squeezed by SHADOW_ROWS rows to make room for the shadow under it. Steps on each
atlas's own source region: recolour with the twin's map ("ribbon", via theme_recolor.py), squeeze, darken a band along
the bottom silhouette (the lip), put a blurred, shifted copy of the silhouette under it (the shadow). Writes
art/themes/pastel/popup_title_<atlas>.png, which tools/theme_pastel.json lays over the region ("overlays"); then run
theme_recolor.py to rebuild the twins.
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import theme_recolor  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPEC = os.path.join(ROOT, "tools/theme_pastel.json")
OUT = os.path.join(ROOT, "art/themes/pastel")
REGION = (384, 1332, 368, 108)
ATLASES = {
	"ui/cc/Resources_moved_UI_Maincenter.png": "popup_title_maincenter.png",
	"ui/figma/atlas_main.png": "popup_title_main.png",
}
MAP = "ribbon"
SHADOW_ROWS = 8  # region rows freed under the plate (the plate keeps 100 of 108)
SIDE_COLS = 4  # columns freed at each end, so the shadow under the round ends fades instead of being cut
LIP_ROWS = 16.0  # height of the dark band above the bottom silhouette
LIP_VALUE = 0.12  # value drop at the bottom edge (ref: about 0.09, plus the art's own darker rim)
LIP_SAT = 0.12  # saturation added at the bottom edge (ref: +0.05; pastel face is paler than the ref's)
SHADOW_RGB = (0.77, 0.32, 0.44)  # rose: over the cream it gives the ref's (232, 182, 170) just under the plate
SHADOW_ALPHA = 0.55
SHADOW_DY = 5.0
SHADOW_BLUR = 2.5


def smooth(e0, e1, x):
	t = np.clip((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)


def plate(atlas_rel, spec):
	x, y, w, h = REGION
	src = Image.open(os.path.join(ROOT, "assets", atlas_rel)).convert("RGBA").crop((x, y, x + w, y + h))
	arr = np.asarray(src).astype(np.float64) / 255.0
	arr[..., :3] = np.clip(theme_recolor.recolor(arr[..., :3], spec, MAP), 0, 1)
	img = Image.fromarray((arr * 255.0 + 0.5).astype(np.uint8), "RGBA")
	# Premultiplied resize: no dark fringe from the transparent pixels.
	ph = h - SHADOW_ROWS
	pw = w - 2 * SIDE_COLS
	img = img.convert("RGBa").resize((pw, ph), Image.LANCZOS).convert("RGBA")
	p = np.zeros((ph, w, 4))
	p[:, SIDE_COLS:SIDE_COLS + pw] = np.asarray(img).astype(np.float64) / 255.0

	# Lip: distance from each pixel down to the bottom silhouette of its column.
	alpha = p[..., 3]
	inside = alpha > 0.5
	rows = np.arange(ph)[:, None]
	bottom = np.where(inside.any(0), ph - 1 - np.argmax(inside[::-1], axis=0), -1)
	dist = (bottom[None, :] - rows).astype(np.float64)
	wl = (1.0 - smooth(0.0, LIP_ROWS, dist)) * (dist >= -1)
	hh, s, v = theme_recolor.rgb_to_hsv(p[..., :3])
	s = np.clip(s + LIP_SAT * wl, 0, 1)
	v = v * (1.0 - LIP_VALUE * wl)
	p[..., :3] = theme_recolor.hsv_to_rgb(hh, s, v)

	# Shadow: the silhouette shifted down and blurred, under the plate.
	mask = np.zeros((h, w))
	mask[:ph] = alpha
	mask = ndimage.shift(mask, (SHADOW_DY, 0), order=1, mode="constant")
	mask = ndimage.gaussian_filter(mask, SHADOW_BLUR)
	out = np.zeros((h, w, 4))
	out[..., :3] = SHADOW_RGB
	out[..., 3] = mask * SHADOW_ALPHA
	# Plate over shadow (straight alpha "over").
	top = np.zeros((h, w, 4))
	top[:ph] = p
	a_t = top[..., 3:4]
	a_b = out[..., 3:4]
	a_o = a_t + a_b * (1 - a_t)
	rgb = (top[..., :3] * a_t + out[..., :3] * a_b * (1 - a_t)) / np.where(a_o > 1e-6, a_o, 1)
	return np.concatenate([rgb, a_o], axis=-1)


def main():
	with open(SPEC, encoding="utf-8") as f:
		spec = json.load(f)
	os.makedirs(OUT, exist_ok=True)
	made = []
	for atlas_rel, name in ATLASES.items():
		arr = plate(atlas_rel, spec)
		im = Image.fromarray((np.clip(arr, 0, 1) * 255.0 + 0.5).astype(np.uint8), "RGBA")
		im.save(os.path.join(OUT, name), optimize=True)
		made.append(im)
		print("wrote", os.path.relpath(os.path.join(OUT, name), ROOT))
	if "--sheet" in sys.argv:
		sheet = Image.new("RGBA", (REGION[2] * 3 + 40, REGION[3] * 3 * len(made) + 20 * len(made)), (252, 247, 235, 255))
		for i, im in enumerate(made):
			big = im.resize((im.width * 3, im.height * 3), Image.NEAREST)
			sheet.alpha_composite(big, (20, i * (REGION[3] * 3 + 20) + 10))
		sheet.save(sys.argv[sys.argv.index("--sheet") + 1])


if __name__ == "__main__":
	main()
