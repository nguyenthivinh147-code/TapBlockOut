extends SceneTree
## Builds every launcher icon from one full-bleed square source (art/images/icon_app_candy.png):
##   icon_app.png (512) and icon_main_192.png: the source, opaque, square (the launcher or store applies the mask).
##   icon_adaptive_bg_432.png: the source's background as a vertical gradient (each row = mean of the source's
##     left and right edge pixels), stretched to line up with the foreground placement.
##   icon_adaptive_fg_432.png: the whole source scaled to --fg px, centred (+ --dy), edges feathered to transparent
##     so it melts into the bg layer; --fg 272 keeps the subject inside the circle mask (72 dp viewport).
##   --mono: icon_adaptive_mono_432.png, a flat L tetromino with candy stripes and speed streaks (Android 13 themed
##     icon, alpha only), drawn by SDF inside the 66 dp safe zone.
##   --crop=x,y,size: cut that square out of the source first (zooms the subject in every output).
## Run: tools/godot.sh --headless --path . -s res://tools/make_app_icon.gd -- <src.png> [--out=res://assets]
##      [--crop=x,y,size] [--fg=272] [--dy=0] [--feather-x=0.1] [--feather-y=0.035] [--mono]

const ADAPTIVE := 432
const EDGE_W := 16


func _initialize() -> void:
	var src_path := ""
	var out_dir := "res://assets"
	var crop := PackedInt32Array()
	var fg_size := 272
	var dy := 0
	var feather_x := 0.1
	var feather_y := 0.035
	var mono := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--crop="):
			crop = PackedInt32Array(Array(a.substr(7).split(",")).map(func(s: String) -> int: return int(s)))
		elif a.begins_with("--fg="):
			fg_size = int(a.substr(5))
		elif a.begins_with("--dy="):
			dy = int(a.substr(5))
		elif a.begins_with("--feather-x="):
			feather_x = float(a.substr(12))
		elif a.begins_with("--feather-y="):
			feather_y = float(a.substr(12))
		elif a == "--mono":
			mono = true
		else:
			src_path = a
	var src := Image.load_from_file(_abs(src_path))
	if src == null or src.is_empty() or src.get_width() != src.get_height():
		push_error("Need a square source PNG: " + src_path)
		quit(1)
		return
	if not crop.is_empty():
		var rect := Rect2i(crop[0], crop[1], crop[2], crop[2]) if crop.size() == 3 else Rect2i()
		if rect.size.x <= 0 or not Rect2i(Vector2i.ZERO, src.get_size()).encloses(rect):
			push_error("--crop=x,y,size must lie inside the %dx%d source" % [src.get_width(), src.get_height()])
			quit(1)
			return
		src = src.get_region(rect)
	src.convert(Image.FORMAT_RGB8)
	var ok := true
	ok = ok and _save(_scaled(src, 512), out_dir.path_join("icon_app.png"))
	ok = ok and _save(_scaled(src, 192), out_dir.path_join("icon_main_192.png"))
	var top := (ADAPTIVE - fg_size) / 2 + dy
	ok = ok and _save(_background(src, fg_size, top), out_dir.path_join("icon_adaptive_bg_432.png"))
	ok = ok and _save(_foreground(src, fg_size, top, feather_x, feather_y), out_dir.path_join("icon_adaptive_fg_432.png"))
	if mono:
		ok = ok and _save(_mono(), out_dir.path_join("icon_adaptive_mono_432.png"))
	quit(0 if ok else 1)


func _scaled(src: Image, size: int) -> Image:
	var img: Image = src.duplicate()
	img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	return img


func _background(src: Image, fg_size: int, top: int) -> Image:
	var n := src.get_height()
	var w := src.get_width()
	var rows: Array[Color] = []
	for y in n:
		var sum := Color(0, 0, 0, 0)
		for x in EDGE_W:
			sum += src.get_pixel(x, y)
			sum += src.get_pixel(w - 1 - x, y)
		rows.append(sum / float(EDGE_W * 2))
	var bg := Image.create_empty(ADAPTIVE, ADAPTIVE, false, Image.FORMAT_RGB8)
	for y in ADAPTIVE:
		var v := clampf((y + 0.5 - top) / float(fg_size), 0.0, 1.0) * (n - 1)
		var i := int(v)
		var c := rows[i].lerp(rows[mini(i + 1, n - 1)], v - i)
		c.a = 1.0
		bg.fill_rect(Rect2i(0, y, ADAPTIVE, 1), c)
	return bg


func _foreground(src: Image, fg_size: int, top: int, feather_x: float, feather_y: float) -> Image:
	var img := _scaled(src, fg_size)
	img.convert(Image.FORMAT_RGBA8)
	var fx := maxf(feather_x * fg_size, 1.0)
	var fy := maxf(feather_y * fg_size, 1.0)
	for y in fg_size:
		var ay := smoothstep(0.0, fy, mini(y, fg_size - 1 - y) + 0.5)
		for x in fg_size:
			var ax := smoothstep(0.0, fx, mini(x, fg_size - 1 - x) + 0.5)
			var c := img.get_pixel(x, y)
			c.a = ax * ay
			img.set_pixel(x, y, c)
	var fg := Image.create_empty(ADAPTIVE, ADAPTIVE, false, Image.FORMAT_RGBA8)
	fg.blit_rect(img, Rect2i(0, 0, fg_size, fg_size), Vector2i((ADAPTIVE - fg_size) / 2, top))
	return fg


## Flat L tetromino (column of 3 cells, foot cell to the right at the bottom), two diagonal candy stripes at lower
## alpha, three speed streaks under it fading downward. Sized for the 66 dp safe circle (radius 132 px).
func _mono() -> Image:
	var cell := 56.0
	var radius := 14.0
	var gap := 10.0
	var streak_len: Array[float] = [40.0, 28.0, 34.0]
	var height := cell * 3.0 + gap + 40.0
	var origin := Vector2((ADAPTIVE - cell * 2.0) * 0.5, (ADAPTIVE - height) * 0.5)
	var bar := Rect2(origin, Vector2(cell, cell * 3.0))
	# Bottom row spans both cells so the bottom edge stays straight (two rounded cells would leave a notch).
	var foot := Rect2(origin + Vector2(0.0, cell * 2.0), Vector2(cell * 2.0, cell))
	var img := Image.create_empty(ADAPTIVE, ADAPTIVE, false, Image.FORMAT_RGBA8)
	for y in ADAPTIVE:
		for x in ADAPTIVE:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := minf(_sd_rect(p, bar, radius), _sd_rect(p, foot, radius)) - radius
			var a := clampf(0.5 - d, 0.0, 1.0)
			# Round the inner (concave) corner where the column meets the bottom row.
			var inner := Vector2(bar.end.x, foot.position.y)
			if p.x >= inner.x and p.x <= inner.x + radius and p.y >= inner.y - radius and p.y <= inner.y:
				var arc := (p - inner - Vector2(radius, -radius)).length() - radius
				a = maxf(a, clampf(arc + 0.5, 0.0, 1.0))
			if a > 0.0:
				# Diagonal stripes (rising to the right) across the block face, like the candy stripes.
				var s := fposmod((p.x - origin.x) + (p.y - origin.y) * 1.0, cell * 1.25)
				if s > cell * 0.55 and s < cell * 0.8:
					a *= 0.55
			for i in 3:
				var sx := origin.x + cell * 2.0 * (0.25 + 0.25 * i)
				var sy0 := origin.y + cell * 3.0 + gap
				var t := (p.y - sy0) / streak_len[i]
				if t >= 0.0 and t <= 1.0:
					var w := clampf(4.5 - absf(p.x - sx), 0.0, 1.0)
					a = maxf(a, w * (1.0 - t) * 0.9)
			if a > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, a))
	return img


func _sd_rect(p: Vector2, r: Rect2, inset: float) -> float:
	var c := r.get_center()
	var half := r.size * 0.5 - Vector2(inset, inset)
	var q := (p - c).abs() - half
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)


func _save(img: Image, path: String) -> bool:
	if img.save_png(_abs(path)) != OK:
		push_error("Cannot write " + path)
		return false
	print("%s %dx%d" % [path, img.get_width(), img.get_height()])
	return true


func _abs(p: String) -> String:
	return ProjectSettings.globalize_path(p) if p.begins_with("res://") else p
