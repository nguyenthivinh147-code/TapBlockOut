#!/usr/bin/env python3
"""Build assets/ui/lb_promo_box.png, the 9-slice background of the Leaderboard popup's PromoBox and player card
(scenes/leaderboard.tscn, BoxBg), from the ComfyUI source art/images/lb_promo_box_c.png.

The source (2048x512, art/manifest.json entry lb_promo_box) is a glossy midnight-blue jelly panel in a caramel rim.
Steps: every pixel inside the silhouette turns opaque (the background removal leaves edge haze), the panel is trimmed
and scaled to H px tall, the jelly's fine mottling is smoothed with a blur that only averages jelly pixels (the gold
rim does not bleed in; the large glossy highlight and the jelly's inner edge stay), then the texture is rebuilt as two
end caps of CAP px from the art and a MID_W px middle made of the per-row median of the middle band, so stretching
it horizontally shows no seams or repeated grain.

Run from the project root: uv run -q --with pillow --with numpy python tools/make_lb_promo_box.py
Dev tool only. scenes/leaderboard.tscn's BoxBg border is (CAP, H/2 - 1, CAP, H/2 - 1); keep them equal.
"""
import os

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art", "images", "lb_promo_box_c.png")
OUT = os.path.join(ROOT, "assets", "ui", "lb_promo_box.png")

# Output height (px); the end caps are half of it, so the rounded corners fit whole.
H = 240
CAP = H // 2
MID_W = 8
# Caps blend into the median middle over this many px.
CAP_FADE = 24
# Silhouette: alpha below this is outside; pixels EDGE px inside it turn opaque.
OUTSIDE_ALPHA = 128
EDGE = 3
# Jelly = blue clearly above red (the rim is gold, its inner line light purple). Smoothing stays JELLY_INSET px away
# from the jelly's edge (feathered by JELLY_FEATHER) and averages over SMOOTH px.
JELLY_BLUE_OVER_RED = 30
JELLY_INSET = 8
JELLY_FEATHER = 4
SMOOTH = 10


def solid_inside(im: Image.Image) -> Image.Image:
    """Make every pixel enclosed by the silhouette opaque, keeping the anti-aliased rim."""
    a = im.getchannel("A")
    out = a.point(lambda v: 255 if v < OUTSIDE_ALPHA else 0)
    w, h = out.size
    border = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)]
    border += [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
    for p in border:
        if out.getpixel(p) == 255:
            ImageDraw.floodfill(out, p, 128)
    outside = out.point(lambda v: 255 if v == 128 else 0)
    inside = ImageChops.invert(outside.filter(ImageFilter.MaxFilter(EDGE * 2 + 1)))
    im = im.copy()
    im.putalpha(ImageChops.lighter(a, inside))
    return im


def trim(im: Image.Image, pad: int = 2) -> Image.Image:
    box = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    return im.crop((max(0, box[0] - pad), max(0, box[1] - pad), min(im.width, box[2] + pad), min(im.height, box[3] + pad)))


def blur(a: np.ndarray, sigma: float) -> np.ndarray:
    """Separable Gaussian blur of a float HxW or HxWxC array (edges extended)."""
    r = int(sigma * 3)
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    k /= k.sum()
    out = a.astype(np.float32)
    for axis in (0, 1):
        pad = [(0, 0)] * out.ndim
        pad[axis] = (r, r)
        p = np.pad(out, pad, mode="edge")
        acc = np.zeros_like(out)
        n = out.shape[axis]
        for i, wgt in enumerate(k):
            acc += wgt * np.take(p, range(i, i + n), axis=axis)
        out = acc
    return out


def smooth_jelly(a: np.ndarray) -> np.ndarray:
    rgb = a[..., :3]
    jelly = ((rgb[..., 2] - rgb[..., 0]) > JELLY_BLUE_OVER_RED) & (a[..., 3] > 250)
    m = Image.fromarray((jelly * 255).astype(np.uint8), "L")
    core = m.filter(ImageFilter.MinFilter(JELLY_INSET * 2 + 1)).filter(ImageFilter.GaussianBlur(JELLY_FEATHER))
    w = np.asarray(core).astype(np.float32)[..., None] / 255.0
    jm = jelly.astype(np.float32)
    num = blur(rgb * jm[..., None], SMOOTH)
    den = blur(jm, SMOOTH)[..., None]
    smooth = np.where(den > 1e-3, num / np.maximum(den, 1e-3), rgb)
    out = a.copy()
    out[..., :3] = rgb * (1.0 - w) + smooth * w
    return out


def main() -> None:
    im = trim(solid_inside(Image.open(SRC).convert("RGBA")))
    im = im.resize((round(im.width * H / im.height), H), Image.LANCZOS)
    a = smooth_jelly(np.asarray(im).astype(np.float32))
    w = a.shape[1]
    col = np.median(a[:, CAP:w - CAP], axis=1, keepdims=True)
    left = a[:, :CAP].copy()
    right = a[:, w - CAP:].copy()
    for i in range(CAP_FADE):
        t = (i + 1) / CAP_FADE
        left[:, CAP - CAP_FADE + i] = left[:, CAP - CAP_FADE + i] * (1 - t) + col[:, 0] * t
        right[:, CAP_FADE - 1 - i] = right[:, CAP_FADE - 1 - i] * (1 - t) + col[:, 0] * t
    out = np.concatenate([left, np.repeat(col, MID_W, axis=1), right], axis=1)
    Image.fromarray(np.clip(out + 0.5, 0, 255).astype(np.uint8), "RGBA").save(OUT)
    print("%s %dx%d, border (%d, %d, %d, %d)" % (OUT, out.shape[1], out.shape[0], CAP, H // 2 - 1, CAP, H // 2 - 1))


if __name__ == "__main__":
    main()
