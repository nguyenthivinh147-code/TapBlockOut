"""Deterministic recolour of UI art into a theme (docs/UI_THEME_PASTEL.md).

  uv run --no-project --with numpy --with pillow python -I tools/theme_recolor.py tools/theme_pastel.json [--only substr]

Reads each source under assets/, writes the twin under assets/themes/<theme>/<same path> with the same size and
alpha, and copies the source .import (same compression and size limit; uid and cache path dropped so Godot gives
the twin its own). A file rule is either whole-file ("map") or per region ("regions": [[x, y, w, h, map], ...]);
pixels outside every region stay as they are. Hand-made art enters through two more keys (paths from the repo root,
made by tools such as make_pastel_home.py): "source" replaces the whole image before any map (same size), and
"overlays": [[x, y, w, h, path], ...] replaces a region (colour and alpha, image exactly w x h) after the maps.

A map sends source hue families to target families. For a pixel of family F with target T:
  hue  -> T.hue (plus the pixel's offset from F's centre times T.keep_hue),
  sat  -> min(sat * T.sat, T.sat_max),
  val  -> 1 - (1 - val) * T.lift   (lifts shadows toward pastel while keeping the shading order).
The result blends with the source by a weight that fades at family edges and at low saturation, so outlines,
whites and creams keep their colour and no seam appears between families. The special map "icon" only softens
saturation above icon_sat_cap (item icons keep their real colours, concept A rule).

  ... tools/theme_recolor.py tools/theme_pastel.json --code [--dry]

Code colours: "code_colors" {from_hex: to_hex} rewritten in data/ui_unity/*.json (hex "rrggbbaa"), scenes (Color(...)
and PackedColorArray floats, matched to the nearest 8-bit value) and src/ scripts (Color("rrggbb"), "rrggbbaa").
Alpha is kept. Idempotent: a second run finds nothing to change.
"""
import glob
import json
import os
import re
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def rgb_to_hsv(rgb):
	r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
	mx = rgb.max(-1)
	mn = rgb.min(-1)
	d = mx - mn
	h = np.zeros_like(mx)
	nz = d > 1e-6
	rc = np.where(nz, (mx - r) / np.where(nz, d, 1), 0)
	gc = np.where(nz, (mx - g) / np.where(nz, d, 1), 0)
	bc = np.where(nz, (mx - b) / np.where(nz, d, 1), 0)
	h = np.where(r == mx, bc - gc, np.where(g == mx, 2.0 + rc - bc, 4.0 + gc - rc))
	h = np.where(nz, (h / 6.0) % 1.0, 0.0)
	s = np.where(mx > 1e-6, d / np.where(mx > 1e-6, mx, 1), 0)
	return h * 360.0, s, mx


def hsv_to_rgb(h, s, v):
	h = (h % 360.0) / 60.0
	i = np.floor(h).astype(int) % 6
	f = h - np.floor(h)
	p = v * (1 - s)
	q = v * (1 - s * f)
	t = v * (1 - s * (1 - f))
	choices = [(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)]
	out = np.zeros(h.shape + (3,))
	for k, (a, b, c) in enumerate(choices):
		m = i == k
		out[..., 0] = np.where(m, a, out[..., 0])
		out[..., 1] = np.where(m, b, out[..., 1])
		out[..., 2] = np.where(m, c, out[..., 2])
	return out


def hue_dist(h, centre):
	return np.abs((h - centre + 180.0) % 360.0 - 180.0)


def smooth(e0, e1, x):
	t = np.clip((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)


def recolor(rgb, spec, map_name):
	"""rgb float (h, w, 3) in 0..1 -> recoloured copy."""
	h, s, v = rgb_to_hsv(rgb)
	if map_name == "icon":
		cap = spec["icon_sat_cap"]
		s2 = np.where(s > cap, cap + (s - cap) * spec["icon_sat_keep"], s)
		return hsv_to_rgb(h, s2, v)
	fams = spec["families"]
	targets = spec["targets"]
	mapping = spec["maps"][map_name]
	out = rgb.copy()
	sat_w = smooth(spec["sat_floor"][0], spec["sat_floor"][1], s)
	for fam_name, tgt_name in mapping.items():
		fam = fams[fam_name]
		tgt = targets[tgt_name]
		dist = hue_dist(h, fam["centre"])
		w = (1.0 - smooth(fam["half"], fam["half"] + fam["feather"], dist)) * sat_w
		if not np.any(w > 0):
			continue
		off = ((h - fam["centre"] + 180.0) % 360.0 - 180.0) * tgt.get("keep_hue", 0.0)
		h2 = tgt["hue"] + off
		s2 = np.minimum(s * tgt["sat"], tgt["sat_max"])
		v2 = 1.0 - (1.0 - v) * tgt["lift"]
		new = hsv_to_rgb(h2, s2, v2)
		out = out * (1 - w[..., None]) + new * w[..., None]
	return out


def import_copy(src_import, dst_import):
	"""The source .import with the twin's own uid and cache paths: kept from the twin's existing .import (stable uid
	across runs; Godot re-imports on its own when the image changed), dropped for a new twin (Godot assigns them)."""
	keep = {}
	if os.path.exists(dst_import):
		section = ""
		with open(dst_import, encoding="utf-8") as f:
			for line in f:
				st = line.strip()
				if st.startswith("["):
					section = st
				for key in ("uid=", "path=", "source_file=", "dest_files="):
					if st.startswith(key) and section in ("[remap]", "[deps]"):
						keep[(section, key)] = line
	lines = []
	section = ""
	with open(src_import, encoding="utf-8") as f:
		for line in f:
			st = line.strip()
			if st.startswith("["):
				section = st
			dropped = False
			for key in ("uid=", "path=", "source_file=", "dest_files="):
				if st.startswith(key) and section in ("[remap]", "[deps]"):
					dropped = True
					if (section, key) in keep:
						lines.append(keep[(section, key)])
			if not dropped:
				lines.append(line)
	with open(dst_import, "w", encoding="utf-8", newline="\n") as f:
		f.writelines(lines)


def _hex(c):
	return "%02x%02x%02x" % tuple(c)


def _rgb(h):
	return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _floats_sub(text, table):
	"""Rewrites Color(r, g, b, a) and PackedColorArray quadruples whose 8-bit rgb is in table."""
	count = 0

	def fix_quads(nums):
		nonlocal count
		out = list(nums)
		for i in range(0, len(nums) - 3, 4):
			try:
				rgb = tuple(int(round(float(x) * 255)) for x in nums[i:i + 3])
			except ValueError:
				return nums
			key = _hex(rgb)
			if key in table:
				out[i:i + 3] = ["%.8g" % (v / 255.0) for v in _rgb(table[key])]
				count += 1
		return out

	def repl(m):
		nums = [x.strip() for x in m.group(2).split(",")]
		if len(nums) < 4 or len(nums) % 4:
			return m.group(0)
		return m.group(1) + "(" + ", ".join(fix_quads(nums)) + ")"

	text = re.sub(r"\b(Color|PackedColorArray)\(([^()]*)\)", repl, text)
	return text, count


def code_colors(spec, dry):
	table = {k.lower(): v.lower() for k, v in spec["code_colors"].items()}
	total = 0
	files = sorted(glob.glob(os.path.join(ROOT, "data/ui_unity/*.json")))
	files += sorted(glob.glob(os.path.join(ROOT, "scenes/**/*.tscn"), recursive=True))
	files += sorted(glob.glob(os.path.join(ROOT, "src/**/*.gd"), recursive=True))
	for f in files:
		with open(f, encoding="utf-8") as fh:
			text = fh.read()
		new, n = text, 0
		if f.endswith(".tscn"):
			new, n = _floats_sub(text, table)
		for src, dst in table.items():
			pat = re.compile(r'(?i)(["(])' + src + r'([0-9a-f]{2})?(["\)])')
			new, k = pat.subn(lambda m: m.group(1) + (dst.upper() if m.group(0)[1:7].isupper() else dst) + (m.group(2) or "") + m.group(3), new)
			n += k
		if n:
			total += n
			print("%4d  %s" % (n, os.path.relpath(f, ROOT)))
			if not dry:
				with open(f, "w", encoding="utf-8", newline="\n") as fh:
					fh.write(new)
	print("%s%d colour values" % ("would change " if dry else "changed ", total))


def main():
	spec_path = sys.argv[1]
	only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else ""
	with open(spec_path, encoding="utf-8") as f:
		spec = json.load(f)
	if "--code" in sys.argv:
		code_colors(spec, "--dry" in sys.argv)
		return
	out_root = os.path.join(ROOT, "assets", "themes", spec["theme"])
	done = 0
	for rel, rule in spec["files"].items():
		if only and only not in rel:
			continue
		src = os.path.join(ROOT, "assets", rel)
		dst = os.path.join(out_root, rel)
		im = Image.open(src).convert("RGBA")
		if "source" in rule:
			alt = Image.open(os.path.join(ROOT, rule["source"])).convert("RGBA")
			if alt.size != im.size:
				sys.exit("%s: source %s is %s, not %s" % (rel, rule["source"], alt.size, im.size))
			im = alt
		arr = np.asarray(im).astype(np.float64) / 255.0
		rgb = arr[..., :3].copy()
		if "map" in rule:
			rgb = recolor(rgb, spec, rule["map"])
		for x, y, w, h, m in rule.get("regions", []):
			x, y, w, h = int(x), int(y), int(w), int(h)
			rgb[y:y + h, x:x + w] = recolor(rgb[y:y + h, x:x + w], spec, m)
		arr[..., :3] = np.clip(rgb, 0, 1)
		for x, y, w, h, path in rule.get("overlays", []):
			x, y, w, h = int(x), int(y), int(w), int(h)
			ov = Image.open(os.path.join(ROOT, path)).convert("RGBA")
			if ov.size != (w, h):
				sys.exit("%s: overlay %s is %s, not %s" % (rel, path, ov.size, (w, h)))
			arr[y:y + h, x:x + w] = np.asarray(ov).astype(np.float64) / 255.0
		os.makedirs(os.path.dirname(dst), exist_ok=True)
		out = (arr * 255.0 + 0.5).astype(np.uint8)
		# Same pixels as the twin on disk: keep its bytes (another zlib/Pillow encodes differently, no git churn).
		same = os.path.exists(dst) and np.array_equal(np.asarray(Image.open(dst).convert("RGBA")), out)
		if not same:
			Image.fromarray(out, "RGBA").save(dst, optimize=True)
		if os.path.exists(src + ".import"):
			import_copy(src + ".import", dst + ".import")
		done += 1
	# Twins whose rule was removed from the spec.
	# normpath: rule keys use "/", os.walk gives "\" on Windows (otherwise every twin counts as removed)
	keep = {os.path.normcase(os.path.normpath(os.path.join(out_root, r))) for r in spec["files"]}
	for base, _dirs, files in os.walk(out_root):
		for fn in files:
			p = os.path.join(base, fn)
			if fn.endswith((".png", ".webp", ".jpg")) and os.path.normcase(os.path.normpath(p)) not in keep and not only:
				os.remove(p)
				for extra in (p + ".import",):
					if os.path.exists(extra):
						os.remove(extra)
	print("wrote %d twins into %s" % (done, os.path.relpath(out_root, ROOT)))


if __name__ == "__main__":
	main()
