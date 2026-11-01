#!/usr/bin/env python3
"""Thu nho hinh goc (art/images/) thanh file dung trong game (assets/).

Chay: python3 tools/resize_images.py [ten ...]   (khong tham so = lam het)
Chi la cong cu dev, can Pillow. Ban goc khong bi sua.

Quy tac:
  ui_*        cat vien trong, dua vao khung vuong (le 6%), 128 px
  art_*       cat vien trong, dua vao khung vuong (le 4%), 512 px
  avatar_NN   cat vien trong, dua vao khung vuong (le 4%), 256 px
  frame_NN    vong ngoai dai 82% khung, tam o giua khung, ruot trong suot, 256 px
  bg_*        rong 720, giu ti le, RGB
  block_surface  lay van muc cao (bo dai chuyen sang), nen xam sang #EBEBEB (de nhan voi mau khoi), 128 px, RGB
  icon_app    cat sat vao trong o vuong bo goc de nen dac, 512 px, RGB
"""
import os
import sys

from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art", "images")
ASSETS = os.path.join(ROOT, "assets")

# ten -> (file nguon trong art/images, thu muc dich trong assets, ten file dich)
SOURCE_OVERRIDE = {
    "block_surface": "block_surface_v2.png",
    "art_no_lives": "art_no_lives_v2.png",
}

ICON_NAMES = [
    "ui_gold", "ui_heart", "ui_hint", "ui_moves", "ui_smash", "ui_shop",
    "ui_settings", "ui_lock", "ui_restart", "ui_video", "ui_gift",
    "ui_profile", "ui_sound", "ui_music", "ui_home",
]
ART_NAMES = ["art_win", "art_lose", "art_no_lives"]
AVATARS = ["avatar_%02d" % i for i in range(13)]
FRAMES = ["frame_%02d" % i for i in range(13)]

FRAME_RING_FRACTION = 0.82
MAX_SMALL_BYTES = 40 * 1024


def src_path(name):
    return os.path.join(SRC, SOURCE_OVERRIDE.get(name, name + ".png"))


def dst_path(name):
    if name.startswith("bg_"):
        return os.path.join(ASSETS, "bg", name + ".png")
    if name.startswith("avatar_"):
        return os.path.join(ASSETS, "avatars", name + ".png")
    if name.startswith("frame_"):
        return os.path.join(ASSETS, "frames", name + ".png")
    if name == "icon_app":
        return os.path.join(ASSETS, "icon_app.png")
    return os.path.join(ASSETS, "ui", name + ".png")  # ui_*, art_*, block_surface


def save_png(im, path, quantize_if_over=0):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, optimize=True)
    if quantize_if_over and os.path.getsize(path) > quantize_if_over and im.mode == "RGBA":
        q = im.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
        q.save(path, optimize=True)


def trim_square(im, size, margin):
    """Cat theo vung alpha, dua vao khung vuong size x size, de le `margin`."""
    im = im.convert("RGBA")
    alpha = im.getchannel("A").point(lambda v: 255 if v > 8 else 0)
    box = alpha.getbbox()
    if box:
        im = im.crop(box)
    inner = int(round(size * (1.0 - 2.0 * margin)))
    scale = inner / max(im.width, im.height)
    im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(im, ((size - im.width) // 2, (size - im.height) // 2))
    return out


def make_frame(im, size):
    im = im.convert("RGBA")
    w, h = im.size
    a = im.getchannel("A").load()
    cy0 = h // 2
    xs = [x for x in range(w) if a[x, cy0] > 40]
    left, right = min(xs), max(xs)
    ring_r = (right - left) / 2.0
    cx = (left + right) / 2.0
    col = int(round(cx))
    ys = [y for y in range(h) if a[col, y] > 40]
    cy = max(ys) - ring_r  # day vong, khong co phu kien o duoi
    target_d = FRAME_RING_FRACTION * size
    scale = target_d / (2.0 * ring_r)
    nw, nh = round(w * scale), round(h * scale)
    big = im.resize((nw, nh), Image.LANCZOS)
    ox = round(size / 2.0 - cx * scale)
    oy = round(size / 2.0 - cy * scale)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(big, (ox, oy)) if ox >= 0 and oy >= 0 else _paste_clipped(out, big, ox, oy)
    # ruot trong suot hoan toan (chac chan cho avatar nam duoi khung)
    px = out.load()
    c = size / 2.0
    hole = 0.80 * (target_d / 2.0) - 0.0  # chi xoa trong ban kinh ruot an toan
    hole = 0.70 * (target_d / 2.0)
    for y in range(size):
        for x in range(size):
            if (x + 0.5 - c) ** 2 + (y + 0.5 - c) ** 2 < hole * hole:
                r, g, b, _ = px[x, y]
                px[x, y] = (r, g, b, 0)
    return out


def _paste_clipped(dst, src, ox, oy):
    x0, y0 = max(0, -ox), max(0, -oy)
    x1, y1 = min(src.width, dst.width - ox), min(src.height, dst.height - oy)
    if x1 > x0 and y1 > y0:
        dst.alpha_composite(src.crop((x0, y0, x1, y1)), (ox + x0, oy + y0))


def make_bg(im):
    im = im.convert("RGB")
    w = 720
    h = round(im.height * w / im.width)
    return im.resize((w, h), Image.LANCZOS)


def make_block_surface(im, size=128):
    """Bo dai chuyen sang (cao tan thap), giu van; lap lai khong lo duong ranh."""
    im = im.convert("L")
    w, h = im.size
    tiled = Image.new("L", (w * 3, h * 3))
    for ty in range(3):
        for tx in range(3):
            tiled.paste(im, (tx * w, ty * h))
    low = tiled.filter(ImageFilter.GaussianBlur(radius=w / 8.0)).crop((w, h, 2 * w, 2 * h))
    src = im.load()
    lo = low.load()
    out = Image.new("L", (w, h))
    px = out.load()
    base = 235
    for y in range(h):
        for x in range(w):
            v = base + 6.0 * (src[x, y] - lo[x, y])
            px[x, y] = max(0, min(255, int(round(v))))
    # lam lien mach: tron mep voi ban dich nua o giua (chi voi tinh nhe)
    shifted = Image.new("L", (w, h))
    shifted.paste(out, (w // 2, h // 2))
    shifted.paste(out, (w // 2 - w, h // 2))
    shifted.paste(out, (w // 2, h // 2 - h))
    shifted.paste(out, (w // 2 - w, h // 2 - h))
    mask = Image.new("L", (w, h), 0)
    mp = mask.load()
    for y in range(h):
        for x in range(w):
            dx = min(x, w - 1 - x) / (w / 2.0)  # 0 o mep, 1 o giua
            dy = min(y, h - 1 - y) / (h / 2.0)
            mp[x, y] = int(255 * (1.0 - min(1.0, min(dx, dy) * 4.0)))
    out = Image.composite(shifted, out, mask)
    return out.resize((size, size), Image.LANCZOS).convert("RGB")


def make_icon_app(im, size=512):
    """Cat sat vao trong vien bo goc cua o vuong (6.5% moi canh) de het vung trong suot."""
    im = im.convert("RGBA")
    alpha = im.getchannel("A").point(lambda v: 255 if v > 8 else 0)
    box = alpha.getbbox()
    if box:
        im = im.crop(box)
    w, h = im.size
    side = min(w, h)
    inset = int(round(side * 0.065))
    cx, cy = w // 2, h // 2
    half = side // 2 - inset
    im = im.crop((cx - half, cy - half, cx + half, cy + half))
    bad = sum(1 for v in im.getchannel("A").getdata() if v < 250)
    if bad:
        print("canh bao: icon_app con %d diem chua dac" % bad)
    return im.convert("RGB").resize((size, size), Image.LANCZOS)


def process(name):
    s = src_path(name)
    if not os.path.exists(s):
        print("thieu nguon:", s)
        return False
    im = Image.open(s)
    d = dst_path(name)
    if name.startswith("ui_"):
        save_png(trim_square(im, 128, 0.06), d)
    elif name.startswith("art_"):
        save_png(trim_square(im, 512, 0.04), d)
    elif name.startswith("avatar_"):
        save_png(trim_square(im, 256, 0.04), d, MAX_SMALL_BYTES)
    elif name.startswith("frame_"):
        save_png(make_frame(im, 256), d, MAX_SMALL_BYTES)
    elif name.startswith("bg_"):
        save_png(make_bg(im), d)
    elif name == "block_surface":
        save_png(make_block_surface(im), d)
    elif name == "icon_app":
        save_png(make_icon_app(im), d)
    else:
        print("ten la:", name)
        return False
    print("%-14s -> %s (%d B)" % (name, os.path.relpath(d, ROOT), os.path.getsize(d)))
    return True


def main():
    names = sys.argv[1:] or (
        ["icon_app", "bg_home", "bg_level", "block_surface"] + ICON_NAMES + ART_NAMES + AVATARS + FRAMES
    )
    ok = all([process(n) for n in names])
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
