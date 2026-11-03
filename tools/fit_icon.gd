extends SceneTree
## Fits an AI icon (art/images, nền trong) into a square PNG for assets/ui/: background removal leaves alpha 1-4 haze
## over the whole frame and 251-254 inside the subject, so both snap to 0/255; then crops to the visible bounds,
## pads to a square with a margin, resizes with Lanczos.
## --solid=N: jelly-like subjects come out of background removal at alpha 230-245; alpha >= N becomes 255 and
## floor..N is stretched to 0..255 so the edge stays anti-aliased. --keep-aspect: pad by the margin only, no square;
## size is then the longer side.
## Run: tools/godot.sh --headless --path . -s res://tools/fit_icon.gd -- <src.png> <out.png> [--size=256] [--margin=0.06] [--floor=4] [--solid=200] [--keep-aspect]

func _initialize() -> void:
	var paths: Array[String] = []
	var size := 256
	var margin := 0.06
	var alpha_floor := 4
	var solid := 0
	var keep_aspect := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			size = int(a.substr(7))
		elif a.begins_with("--margin="):
			margin = float(a.substr(9))
		elif a.begins_with("--floor="):
			alpha_floor = int(a.substr(8))
		elif a.begins_with("--solid="):
			solid = int(a.substr(8))
		elif a == "--keep-aspect":
			keep_aspect = true
		else:
			paths.append(a)
	if paths.size() != 2:
		push_error("Cần <src.png> <out.png>")
		quit(1)
		return
	var img := Image.load_from_file(_abs(paths[0]))
	if img == null or img.is_empty():
		push_error("Không đọc được " + paths[0])
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var lo := Vector2i(w, h)
	var hi := Vector2i(-1, -1)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var a := roundi(c.a * 255.0)
			if a <= alpha_floor:
				img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))
				continue
			if solid > alpha_floor:
				img.set_pixel(x, y, Color(c.r, c.g, c.b, clampf(float(a - alpha_floor) / float(solid - alpha_floor), 0.0, 1.0)))
			elif a < 255 and a >= 255 - alpha_floor:
				img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
			lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
			hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	if hi.x < 0:
		push_error("Ảnh trong suốt hoàn toàn: " + paths[0])
		quit(1)
		return
	var crop := img.get_region(Rect2i(lo, hi - lo + Vector2i.ONE))
	var pad := int(ceil(maxi(crop.get_width(), crop.get_height()) * margin / (1.0 - 2.0 * margin)))
	var canvas := crop.get_size() + Vector2i(pad, pad) * 2
	if not keep_aspect:
		var side := maxi(canvas.x, canvas.y)
		canvas = Vector2i(side, side)
	var sq := Image.create_empty(canvas.x, canvas.y, false, Image.FORMAT_RGBA8)
	sq.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), (canvas - crop.get_size()) / 2)
	var k := float(size) / float(maxi(canvas.x, canvas.y))
	var out := Vector2i(roundi(canvas.x * k), roundi(canvas.y * k))
	sq.resize(out.x, out.y, Image.INTERPOLATE_LANCZOS)
	if sq.save_png(_abs(paths[1])) != OK:
		push_error("Không ghi được " + paths[1])
		quit(1)
		return
	print("%s <- %s crop %s canvas %s -> %s px" % [paths[1], paths[0], Rect2i(lo, hi - lo + Vector2i.ONE), canvas, out])
	quit(0)


func _abs(p: String) -> String:
	return ProjectSettings.globalize_path(p) if p.begins_with("res://") else p
