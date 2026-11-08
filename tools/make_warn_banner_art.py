#!/usr/bin/env python3
"""Build the Hard / Very Hard warning banner sprites in assets/ui/warn_banner/ from the ComfyUI sources.

art/images/warn_banner/frame_purple_c.png (candy-cane rope frame, 2048x512) and badge_purple_a.png (candy-cane ring
badge, 1024x1024) are the Very Hard (grape purple) art; see art/manifest.json, entries warn_frame_*, warn_badge_*.
The background removal left the frame's inner panel partly see-through (alpha ~215) and the badge at 254, so every
pixel more than EDGE px inside the silhouette becomes opaque. The Hard (strawberry red) pair is the same art with
its hue turned by HARD_HUE_SHIFT; the white stripes keep their color.

Run from anywhere: python3 tools/make_warn_banner_art.py [--preview=out.png]
Dev tool only, needs Pillow. level.gd reads the frame's 9-slice border from FRAME_CAP below (keep them equal).
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art", "images", "warn_banner")
OUT = os.path.join(ROOT, "assets", "ui", "warn_banner")

FRAME_SRC = "frame_purple_c.png"
BADGE_SRC = "badge_purple_a.png"
# Output heights (px). The frame is 9-sliced horizontally, so only its height matters for sharpness.
FRAME_H = 288
BADGE_H = 288
# Alpha below this counts as outside when finding the silhouette; pixels EDGE px inside it turn opaque.
OUTSIDE_ALPHA = 128
EDGE = 3
# Hue turn (0..255 = 0..360 deg) from grape purple to strawberry red.
HARD_HUE_SHIFT = 60
# Extra saturation and value for the red pair, which reads duller than the purple after the turn.
HARD_SAT = 1.06
HARD_VAL = 1.04


def solid_inside(im: Image.Image) -> Image.Image:
    """Make every pixel enclosed by the silhouette opaque, keeping the anti-aliased rim."""
    a = im.getchannel("A")
    out = a.point(lambda v: 255 if v < OUTSIDE_ALPHA else 0)
    w, h = out.size
    draw = ImageDraw.Draw(out)
    border = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)]
    border += [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
    for p in border:
        if out.getpixel(p) == 255:
            ImageDraw.floodfill(out, p, 128)
    outside = out.point(lambda v: 255 if v == 128 else 0)
    near = outside.filter(ImageFilter.MaxFilter(EDGE * 2 + 1))
    inside = ImageChops.invert(near)
    im = im.copy()
    im.putalpha(ImageChops.lighter(a, inside))
    return im


def trim(im: Image.Image, pad: int = 2) -> Image.Image:
    box = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    box = (max(0, box[0] - pad), max(0, box[1] - pad), min(im.width, box[2] + pad), min(im.height, box[3] + pad))
    return im.crop(box)


def fit_h(im: Image.Image, h: int) -> Image.Image:
    w = round(im.width * h / im.height)
    return im.resize((w, h), Image.LANCZOS)


def to_hard(im: Image.Image) -> Image.Image:
    a = im.getchannel("A")
    hh, s, v = im.convert("RGB").convert("HSV").split()
    hh = hh.point(lambda x: (x + HARD_HUE_SHIFT) % 256)
    s = s.point(lambda x: min(255, round(x * HARD_SAT)))
    v = v.point(lambda x: min(255, round(x * HARD_VAL)))
    out = Image.merge("HSV", (hh, s, v)).convert("RGBA")
    out.putalpha(a)
    return out


def main() -> None:
    preview = ""
    for arg in sys.argv[1:]:
        if arg.startswith("--preview="):
            preview = arg.split("=", 1)[1]
    os.makedirs(OUT, exist_ok=True)
    frame = fit_h(trim(solid_inside(Image.open(os.path.join(SRC, FRAME_SRC)).convert("RGBA"))), FRAME_H)
    badge = fit_h(trim(solid_inside(Image.open(os.path.join(SRC, BADGE_SRC)).convert("RGBA"))), BADGE_H)
    made = {
        "warn_frame_very_hard.png": frame,
        "warn_frame_hard.png": to_hard(frame),
        "warn_badge_very_hard.png": badge,
        "warn_badge_hard.png": to_hard(badge),
    }
    for name, im in made.items():
        im.save(os.path.join(OUT, name), optimize=True)
        print("%s %dx%d" % (name, im.width, im.height))
    if preview:
        sheet = Image.new("RGBA", (frame.width + badge.width + 30, frame.height * 2 + 30), (40, 30, 50, 255))
        y = 10
        for kind in ("hard", "very_hard"):
            sheet.alpha_composite(made["warn_frame_%s.png" % kind], (10, y))
            sheet.alpha_composite(made["warn_badge_%s.png" % kind], (frame.width + 20, y))
            y += frame.height + 10
        sheet.save(preview)


if __name__ == "__main__":
    main()
