extends SceneTree
## Recolours the booster outlines in an offer art (assets/ui/art_level_pack*.png) to the pack's own outline colour,
## so boosters drawn in the sticker style (black / dark green / maroon lines) match the coins and the box.
## In each rect, a pixel that passes its kind's colour gate is blended toward --color by its darkness: weight 1 at
## luminance <= L0, 0 at >= L1. The outline core takes the colour; lighter anti-aliased edges and fills stay.
## Gates skip the pack's brown outlines, the blue box and the purple bag. Rects may overlap: run hammer first.
## Run after tools/fit_icon.gd (rects are in the fitted image's pixels):
## tools/godot.sh --headless --path . -s res://tools/recolor_outline.gd -- <in.png> <out.png> [--color=5a2a0a] kind:x,y,w,h ...
## kind: bulb (black outline), plus3 (dark green), hammer (maroon).

const LUM := {"bulb": [0.10, 0.30], "plus3": [0.25, 0.38], "hammer": [0.17, 0.27]}


func _initialize() -> void:
	var paths: Array[String] = []
	var specs: Array[String] = []
	var target := Color("5a2a0a")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--color="):
			target = Color(a.substr(8))
		elif a.contains(":") and LUM.has(a.get_slice(":", 0)):
			specs.append(a)
		else:
			paths.append(a)
	if paths.size() != 2 or specs.is_empty():
		push_error("Cần <in.png> <out.png> kind:x,y,w,h ...")
		quit(1)
		return
	var img := Image.load_from_file(_abs(paths[0]))
	if img == null or img.is_empty():
		push_error("Không đọc được " + paths[0])
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	var changed := 0
	for spec in specs:
		var kind := spec.get_slice(":", 0)
		var v := spec.get_slice(":", 1).split(",")
		var r := Rect2i(int(v[0]), int(v[1]), int(v[2]), int(v[3])).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var l0: float = LUM[kind][0]
		var l1: float = LUM[kind][1]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := img.get_pixel(x, y)
				if c.a < 0.05 or not _gate(kind, c):
					continue
				var w := clampf((l1 - c.get_luminance()) / (l1 - l0), 0.0, 1.0)
				if w <= 0.0:
					continue
				var n := c.lerp(target, w)
				n.a = c.a
				img.set_pixel(x, y, n)
				changed += 1
	img.save_png(_abs(paths[1]))
	print("%s <- %s: %d px recoloured to #%s" % [paths[1], paths[0], changed, target.to_html(false)])
	quit(0)


func _gate(kind: String, c: Color) -> bool:
	match kind:
		"hammer":
			return c.r > c.g + 0.1 and c.b > c.g and c.r > c.b
		"plus3":
			return c.g > c.r + 0.05 and c.g > c.b + 0.05
		"bulb":
			if c.r > 1.7 * c.g and c.r - c.b > 0.12:
				return false  # the pack's brown outline
			return c.b <= c.r + 0.1  # not the blue box / purple bag
	return false


func _abs(p: String) -> String:
	return ProjectSettings.globalize_path(p) if p.begins_with("res://") else p
