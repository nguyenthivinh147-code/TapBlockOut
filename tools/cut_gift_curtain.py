#!/usr/bin/env python3
"""Cat anh hop qua AI (art/images/gift_curtain/box_c_tall_s7321.png, 896x1920) thanh hai manh cho man chuyen canh
Road Trip (src/ui/gift_curtain.gd): nap (gom mep nap) va than hop.

Chay: python3 tools/cut_gift_curtain.py
Chi la cong cu dev, can Pillow. Ban goc khong bi sua.

- Bo vien trang hai ben (x < 16, x >= 880) va goc bo tren, duoi: hai manh phu kin mep, khong con nen trang.
- Nap: y 56..847, cat ngay duoi mep nap (mep thang).
- Than: y 866..1880, bo dai bong do cua mep nap tren than (y 848..865); bong do ve bang code, di theo nap.
Noi gift_bow.png lam bang tools/fit_icon.gd (xem art/manifest.json, muc gift_curtain_bow).
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art", "images", "gift_curtain", "box_c_tall_s7321.png")
OUT = os.path.join(ROOT, "assets", "ui", "gift_curtain")

X0, X1 = 16, 880
LID = (56, 848)
BODY = (866, 1880)


def main() -> None:
	im = Image.open(SRC).convert("RGB")
	assert im.size == (896, 1920), im.size
	os.makedirs(OUT, exist_ok=True)
	for name, (y0, y1) in (("gift_lid", LID), ("gift_body", BODY)):
		piece = im.crop((X0, y0, X1, y1))
		path = os.path.join(OUT, name + ".png")
		piece.save(path, optimize=True)
		print(path, piece.size)


if __name__ == "__main__":
	main()
