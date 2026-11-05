extends SceneTree
## Splits the tear off the lose art so the lose card can run it down the cheek (UiMotion.TEAR).
## Sources: art/images/art_lose.png and art/images/art_lose_notear.png, the same picture with the tear painted out
## (ComfyUI edit, art/manifest.json). In the first, the tear is the light pixels (green above TEAR_G) inside
## TEAR_BOX. Around them (GROW px, fading out over FEATHER px more) the body takes the painted-out pixels; everywhere
## else it keeps the original. The tear layer is what the tear adds over the painted-out picture (its edge pixels as
## an alpha matte toward the nearest tear colour). Both are fitted like tools/resize_images.py fits art_* (trim to
## alpha > 8, square, 4% margin, 512 px), so the tear lands on the body where it was drawn.
## Writes assets/ui/art_lose.png (no tear) and assets/ui/art_lose_tear.png (the tear, cropped), and prints the tear's
## rect in the 512 px art, which scenes/lose_card.tscn uses to place the Tear node. Run it after
## `python3 tools/resize_images.py art_lose` (that puts the tear back):
## tools/godot.sh --headless --path . -s res://tools/split_tear.gd

const SRC := "res://art/images/art_lose.png"
const CLEAN := "res://art/images/art_lose_notear.png"
const OUT_BODY := "res://assets/ui/art_lose.png"
const OUT_TEAR := "res://assets/ui/art_lose_tear.png"
## Source px: the box holding the tear under the right eye, and the green level only the tear reaches there
## (jelly 0.55, blush 0.44, eye 0.2, tear 0.65-1.0).
const TEAR_BOX := Rect2i(572, 576, 41, 37)
const TEAR_G := 0.6
const GROW := 3
const FEATHER := 2
## Source px from the tear whose colour still mixes with what is under it (the anti-aliased rim).
const RIM := 1.5
## tools/resize_images.py, art_*.
const SIZE := 512
const MARGIN := 0.04
const ALPHA_CUT := 8
## Px of transparent border kept around the cropped tear.
const TEAR_PAD := 2


func _initialize() -> void:
	var src := _load(SRC)
	var clean := _load(CLEAN)
	if src == null or clean == null or src.get_size() != clean.get_size():
		push_error("split_tear: cần %s và %s cùng cỡ" % [SRC, CLEAN])
		quit(1)
		return
	var light := {}
	for y in range(TEAR_BOX.position.y, TEAR_BOX.end.y):
		for x in range(TEAR_BOX.position.x, TEAR_BOX.end.x):
			if src.get_pixel(x, y).g > TEAR_G:
				light[Vector2i(x, y)] = true
	var core := _largest_blob(light)

	var body := src.duplicate() as Image
	var tear := Image.create(src.get_width(), src.get_height(), false, Image.FORMAT_RGBAF)
	var reach := GROW + FEATHER
	var area := Rect2i(TEAR_BOX.position - Vector2i(reach, reach), TEAR_BOX.size + Vector2i(reach, reach) * 2)
	var ring := Color(0, 0, 0, 0)
	var ring_n := 0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var near := _nearest(core, Vector2i(x, y))
			var d := sqrt(float(near.x))
			var p := src.get_pixel(x, y)
			var bg := clean.get_pixel(x, y)
			var w := clampf(1.0 - (d - GROW) / FEATHER, 0.0, 1.0)
			body.set_pixel(x, y, Color(p.lerp(bg, w), p.a))
			if d > reach:
				ring += Color(absf(p.r - bg.r), absf(p.g - bg.g), absf(p.b - bg.b), 0)
				ring_n += 1
			if d > RIM:
				continue
			# Core pixels are the tear; rim pixels show how far it lifts the background toward the nearest tear colour.
			var c := src.get_pixel(core[near.y].x, core[near.y].y)
			var a := 1.0
			if d > 0.0:
				var cb := Vector3(c.r - bg.r, c.g - bg.g, c.b - bg.b)
				var pb := Vector3(p.r - bg.r, p.g - bg.g, p.b - bg.b)
				a = clampf(pb.dot(cb) / maxf(cb.length_squared(), 0.0001), 0.0, 1.0)
			if a > 0.0:
				tear.set_pixel(x, y, Color(c.r, c.g, c.b, a))

	var box := _alpha_box(body)
	var body_fit := _fit(body, box)
	var tear_fit := _fit(tear, box)
	var tear_rect := _alpha_box(tear_fit).grow(TEAR_PAD).intersection(Rect2i(0, 0, SIZE, SIZE))
	var tear_crop := tear_fit.get_region(tear_rect)
	body_fit.convert(Image.FORMAT_RGBA8)
	tear_crop.convert(Image.FORMAT_RGBA8)
	body_fit.save_png(ProjectSettings.globalize_path(OUT_BODY))
	tear_crop.save_png(ProjectSettings.globalize_path(OUT_TEAR))
	print("tear px %d; painted-out picture differs around the patch by %s (mean |rgb|)" % [core.size(), ring / maxi(ring_n, 1)])
	print("tear rect in the %d px art: %s" % [SIZE, tear_rect])
	quit(0)


func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img != null:
		img.convert(Image.FORMAT_RGBAF)
	return img


## The largest 8-connected group of pixels: the tear, without stray light pixels of the eye's rim or the jelly.
func _largest_blob(px: Dictionary) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	var seen := {}
	for start: Vector2i in px:
		if seen.has(start):
			continue
		var blob: Array[Vector2i] = []
		var stack: Array[Vector2i] = [start]
		seen[start] = true
		while not stack.is_empty():
			var p: Vector2i = stack.pop_back()
			blob.append(p)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var q := p + Vector2i(dx, dy)
					if px.has(q) and not seen.has(q):
						seen[q] = true
						stack.append(q)
		if blob.size() > best.size():
			best = blob
	return best


## (squared distance, index) of the core pixel nearest to p.
func _nearest(core: Array[Vector2i], p: Vector2i) -> Vector2i:
	var best := Vector2i(1 << 30, -1)
	for i in core.size():
		var d := (core[i] - p).length_squared()
		if d < best.x:
			best = Vector2i(d, i)
	return best


## Bounds of alpha > ALPHA_CUT / 255 (Pillow's getbbox on the thresholded alpha).
func _alpha_box(img: Image) -> Rect2i:
	var x0 := img.get_width()
	var y0 := img.get_height()
	var x1 := -1
	var y1 := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a * 255.0 > ALPHA_CUT:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


## resize_images.py trim_square: crop to box, scale the longer side to SIZE * (1 - 2 * MARGIN), centre on SIZE x SIZE.
## Resampled premultiplied, like Pillow does RGBA, so transparent pixels do not bleed colour into the edge.
func _fit(img: Image, box: Rect2i) -> Image:
	var c := img.get_region(box)
	c.premultiply_alpha()
	var inner := roundi(SIZE * (1.0 - 2.0 * MARGIN))
	var k := float(inner) / maxi(box.size.x, box.size.y)
	var cw := maxi(1, roundi(box.size.x * k))
	var ch := maxi(1, roundi(box.size.y * k))
	c.resize(cw, ch, Image.INTERPOLATE_LANCZOS)
	for y in ch:
		for x in cw:
			var p := c.get_pixel(x, y)
			if p.a > 0.0:
				c.set_pixel(x, y, Color(p.r / p.a, p.g / p.a, p.b / p.a, clampf(p.a, 0.0, 1.0)).clamp())
			else:
				c.set_pixel(x, y, Color(0, 0, 0, 0))
	var out := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBAF)
	out.blit_rect(c, Rect2i(0, 0, cw, ch), Vector2i((SIZE - cw) / 2, (SIZE - ch) / 2))
	return out
