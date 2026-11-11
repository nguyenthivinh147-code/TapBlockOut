#!/usr/bin/env python3
"""Build the red Hard difficulty pill assets/ui/hud/hud_pill_hard.png from the purple one (hud_pill.png).

The level HUD pill follows the difficulty tier like Home and the warning banner: Hard is strawberry red, Very Hard
keeps the grape purple of hud_pill.png. The red pill is the purple art with its hue turned by HARD_HUE_SHIFT
(purple body ~284 deg -> ~352 deg, between the Home Play button red and the Hard warning banner), saturation and
value nudged up because the turned red reads duller than the purple. Same size and 9-slice margins as hud_pill.png.

Run from anywhere: python3 tools/make_hud_pill_hard.py [--preview=out.png]
Dev tool only, needs Pillow.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "ui", "hud", "hud_pill.png")
OUT = os.path.join(ROOT, "assets", "ui", "hud", "hud_pill_hard.png")

# Hue turn (0..255 = 0..360 deg) from grape purple to strawberry red.
HARD_HUE_SHIFT = 48
HARD_SAT = 1.08
HARD_VAL = 1.0


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
    src = Image.open(SRC).convert("RGBA")
    hard = to_hard(src)
    hard.save(OUT, optimize=True)
    print("%s %dx%d" % (os.path.basename(OUT), hard.width, hard.height))
    if preview:
        scale = 4
        sheet = Image.new("RGBA", (src.width * scale * 2 + 30, src.height * scale + 20), (235, 230, 240, 255))
        for i, im in enumerate((hard, src)):
            big = im.resize((im.width * scale, im.height * scale), Image.LANCZOS)
            sheet.alpha_composite(big, (10 + i * (big.width + 10), 10))
        sheet.save(preview)


if __name__ == "__main__":
    main()
