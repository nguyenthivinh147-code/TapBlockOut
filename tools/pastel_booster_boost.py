"""Brighten the Claymorphism booster icons for the pastel theme (art/themes/pastel/booster_*.png).

Saturation s' = 1 - (1 - s)^gamma, weighted by smoothstep(0.22, 0.42, s) so cream and white stay put; value unchanged.
--pink-only limits the boost to the red/pink family (hue -40..25); --pink-shift=D moves that family's hue by D degrees
(the smash hammer's coral 355 -> strawberry ~341). tools/theme_recolor.py then applies the theme's icon cap.

Run (input = output of tools/fit_icon.gd --size=256 --margin=0.06 --floor=12 on art/images/booster_<n>_clay_ai.png):
  uv run --no-project --with numpy --with pillow python -I tools/pastel_booster_boost.py <fit.png> art/themes/pastel/booster_hint.png 1.5
  uv run --no-project --with numpy --with pillow python -I tools/pastel_booster_boost.py <fit.png> art/themes/pastel/booster_move.png 1.5
  uv run --no-project --with numpy --with pillow python -I tools/pastel_booster_boost.py <fit.png> art/themes/pastel/booster_smash.png 1.5 --pink-only --pink-shift=-14
"""
import sys

import numpy as np
from PIL import Image


def smooth(e0, e1, x):
	t = np.clip((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)


def rgb2hsv(rgb):
	mx = rgb.max(-1)
	mn = rgb.min(-1)
	d = mx - mn
	s = np.where(mx > 0, d / np.maximum(mx, 1e-9), 0)
	r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
	dd = np.maximum(d, 1e-9)
	h = np.where(mx == r, ((g - b) / dd) % 6, np.where(mx == g, (b - r) / dd + 2, (r - g) / dd + 4)) * 60
	return np.where(d > 0, h, 0), s, mx


def hsv2rgb(h, s, v):
	h = (h % 360) / 60
	i = np.floor(h).astype(int) % 6
	f = h - np.floor(h)
	p = v * (1 - s)
	q = v * (1 - s * f)
	t = v * (1 - s * (1 - f))
	r = np.choose(i, [v, q, p, p, t, v])
	g = np.choose(i, [t, v, v, q, p, p])
	b = np.choose(i, [p, p, t, v, v, q])
	return np.stack([r, g, b], -1)


def main():
	args = sys.argv[1:]
	src, dst, gamma = args[0], args[1], float(args[2])
	pink_only = "--pink-only" in args
	shift = float(next((a.split("=")[1] for a in args if a.startswith("--pink-shift=")), 0))
	a = np.asarray(Image.open(src).convert("RGBA")).astype(np.float64) / 255.0
	h, s, v = rgb2hsv(a[..., :3])
	hw = (h + 60) % 360 - 60  # -60..300 so the red/pink family is contiguous
	pink = smooth(-40, -28, hw) * (1 - smooth(14, 26, hw))
	w = smooth(0.22, 0.42, s) * (pink if pink_only else 1)
	s2 = s + (1 - (1 - s) ** gamma - s) * w
	h2 = h + shift * pink * smooth(0.2, 0.35, s)
	a[..., :3] = np.clip(hsv2rgb(h2, s2, v), 0, 1)
	Image.fromarray((a * 255 + 0.5).astype(np.uint8), "RGBA").save(dst, optimize=True)


if __name__ == "__main__":
	main()
