extends Control
## Praise burst for the "Nice one!" caption (design.md section 3: a long think, then a right move). This node covers
## the board holder and draws the halo: a soft glow, slowly turning rays and a shock ring. The level puts it behind the
## board, so the frame hides the halo's lower part and only light rising above the frame shows. A sibling layer just
## behind the caption (in front of the board) draws a burst of candy stars with sparks and a shower of confetti, and a
## child of the caption adds twinkles over the letters. The caption springs up with an overshoot and a tilt, flashes
## white, gets a light sweep, breathes, then floats up and fades. Its bottom centre is the pivot, so the pop grows
## upward and sideways and never reaches the frame below it.
## Ignores input. At the end it hides the caption, puts back the nodes it dimmed and frees itself and its layers.

const SHADER := preload("res://src/ui/praise_text.gdshader")

## Caption look (the scene's Label keeps only its text and font): white face that praise_text.gdshader colors.
const FONT_SIZE := 96
const OUTLINE := Color("6E1F55")
const OUTLINE_PX := 16
const SHADOW := Color("3D0A33")
const SHADOW_Y := 8
## The caption shrinks to fit its room but not below this (a broken layout must not flip or hide it).
const MIN_FIT := 0.25

## Timeline (s). The caption grows FROM -> PEAK by POP, dips to DIP by SETTLE, rests at 1 by REST, breathes until
## LEAVE, then rises RISE px while fading out by END.
const POP := 0.14
const SETTLE := 0.3
const REST := 0.42
const LEAVE := 1.15
const END := 1.6
const FROM := 0.25
const PEAK := 1.3
const DIP := 0.93
const TILT := [-8.0, 3.0, -1.5]  # degrees at 0, POP, SETTLE; 0 at REST
const BREATHE := 0.035  # scale swing while resting
const BREATHE_HZ := 1.6
const RISE := 40.0
const FLASH := 0.9  # face mixed toward white at the pop, gone by FLASH_SEC
const FLASH_SEC := 0.45
const SHINE_AT := 0.34
const SHINE_SEC := 0.45

## Glow and rays behind the caption, as shares of its width; rays are squashed to RAYS_FLAT of their reach upright.
const GLOW_W := 0.7
const GLOW_FLAT := 0.5
const GLOW := Color(1.0, 0.8, 0.3, 0.8)
const RAYS := 14
const RAYS_W := 1.0
const RAYS_FLAT := 0.55
const RAYS_SPIN := 0.5  # rad/s
const RAY := Color(1.0, 0.86, 0.4, 0.6)
## Shock ring at the pop: grows from RING_FROM to RING_TO of the caption width (squashed like the rays) in RING_SEC,
## RING_W px thick at the standard screen, thinning and fading as it goes.
const RING_SEC := 0.4
const RING_FROM := 0.3
const RING_TO := 0.95
const RING_W := 12.0
const RING := Color(1.0, 0.98, 0.9, 0.9)

## Burst at BURST_AT: STARS candy stars and SPARKS dots fly out of the caption, slow down and drop.
## Speeds px/s, sizes px at the standard screen (scaled by the board's scale `s`).
const BURST_AT := 0.06
const STARS := 16
const STAR_SPEED := Vector2(520.0, 1100.0)
const STAR_SIZE := Vector2(20.0, 40.0)
const STAR_LIFE := Vector2(0.6, 0.95)
const SPARKS := 10
const SPARK_SPEED := Vector2(700.0, 1400.0)
const SPARK_SIZE := Vector2(3.0, 6.0)
const SPARK_LIFE := Vector2(0.3, 0.5)
const DRAG := 3.5
const GRAVITY := 900.0
const STAR_INNER := 0.46
const CANDY: Array[Color] = [Color("FFC23A"), Color("FF6FB8"), Color("B57BFF"), Color("4FDDA8"), Color("5EC2FF"),
	Color("FF8A3D")]

## Confetti at CONFETTI_AT: thrown up from across the caption, flipping as it falls.
const CONFETTI_AT := 0.08
const CONFETTI := 22
const CONFETTI_UP := Vector2(600.0, 1150.0)
const CONFETTI_SIDE := 520.0
const CONFETTI_SIZE := Vector2(14.0, 24.0)
const CONFETTI_GRAVITY := 1500.0
const CONFETTI_DRAG := 2.2

## Twinkles over the letters: TWINKLES four-point stars, each flaring for TWINKLE_SEC at a random moment and spot.
const TWINKLES := 6
const TWINKLE_FROM := 0.25
const TWINKLE_TO := 1.05
const TWINKLE_SEC := 0.32
const TWINKLE_SIZE := Vector2(44.0, 64.0)  # px in the caption's own space, tip to tip
const TWINKLE_EDGE := Color("FFC23A")

var _label: Label = null
var _front: Control = null
var _burst_layer: Control = null
var _mat: ShaderMaterial = null
var _dim: Array[CanvasItem] = []
var _foot := Vector2.ZERO
var _fit := 1.0
var _s := 1.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()
## Particles: {pos, vel, rot, spin, size, life, age, col} (+ "flip", "flip_speed" for confetti).
var _stars: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _confetti: Array[Dictionary] = []
var _burst_done := false
var _confetti_done := false
## {at, pos (caption local), size, rot}
var _twinkles: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Plays on `label` (already holding its text, a sibling of this node, drawn after it). Its bottom centre sits on `foot` (parent
## coordinates); at rest it is no wider than `max_w` and no taller than `max_h`. `s` scales the particle px given at
## the standard screen. `dim` fade out while the caption shows and come back at the end.
func start(label: Label, foot: Vector2, max_w: float, max_h: float, s: float = 1.0,
		dim: Array[CanvasItem] = []) -> void:
	_label = label
	_foot = foot
	_s = s
	_dim = dim
	_rng.randomize()
	style(label)
	label.reset_size()
	var sz := label.get_combined_minimum_size()
	label.size = sz
	_fit = clampf(minf(max_w / maxf(sz.x, 1.0), max_h / maxf(sz.y, 1.0)), MIN_FIT, 1.0)
	label.pivot_offset = Vector2(sz.x * 0.5, sz.y)
	_mat.set_shader_parameter("box_size", sz)
	label.visible = true
	_front = Control.new()
	_front.name = "PraiseTwinkles"
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.draw.connect(_draw_twinkles)
	label.add_child(_front, true)  # a previous effect's layers may still be queued for deletion
	_burst_layer = Control.new()
	_burst_layer.name = "PraiseBurst"
	_burst_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burst_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_burst_layer.draw.connect(_draw_burst)
	var holder := label.get_parent()
	holder.add_child(_burst_layer, true)
	holder.move_child(_burst_layer, label.get_index())
	for i in TWINKLES:
		_twinkles.append({
			"at": lerpf(TWINKLE_FROM, TWINKLE_TO, (float(i) + _rng.randf()) / TWINKLES),
			"pos": Vector2(_rng.randf_range(0.1, 0.9) * sz.x, _rng.randf_range(0.3, 0.72) * sz.y),
			"size": _rng.randf_range(TWINKLE_SIZE.x, TWINKLE_SIZE.y),
			"rot": _rng.randf_range(-0.3, 0.3),
		})
	_t = 0.0
	_apply()
	set_process(true)


## Gives `label` the praise look: white face for the gradient shader, thick plum outline and drop shadow.
func style(label: Label) -> void:
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_color_override("font_shadow_color", SHADOW)
	label.add_theme_constant_override("outline_size", OUTLINE_PX)
	label.add_theme_constant_override("shadow_outline_size", OUTLINE_PX)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", SHADOW_Y)
	_mat = label.material as ShaderMaterial
	if _mat == null or _mat.shader != SHADER:
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER
		label.material = _mat


## Caption scale at rest (1 unless it had to shrink to fit).
func fit_scale() -> float:
	return _fit


func elapsed() -> float:
	return _t


func _process(delta: float) -> void:
	_t += delta
	if _t >= END:
		_finish()
		return
	if not _burst_done and _t >= BURST_AT:
		_burst_done = true
		_burst()
	if not _confetti_done and _t >= CONFETTI_AT:
		_confetti_done = true
		_throw_confetti()
	_step(_stars, delta, DRAG, GRAVITY)
	_step(_sparks, delta, DRAG, GRAVITY)
	_step(_confetti, delta, CONFETTI_DRAG, CONFETTI_GRAVITY)
	for c in _confetti:
		c.flip = float(c.flip) + float(c.flip_speed) * delta
	_apply()


func _exit_tree() -> void:
	_restore()


func _finish() -> void:
	set_process(false)
	_restore()
	if is_instance_valid(_label):
		_label.visible = false
	queue_free()


## Puts the caption back at rest and the dimmed nodes back to full; safe to call twice.
func _restore() -> void:
	for n in _dim:
		if is_instance_valid(n):
			n.modulate.a = 1.0
	_dim = []
	for n: Control in [_front, _burst_layer]:
		if is_instance_valid(n):
			n.queue_free()
	_front = null
	_burst_layer = null
	if is_instance_valid(_label):
		_label.scale = Vector2.ONE
		_label.rotation = 0.0
		_label.modulate.a = 1.0
		if _mat != null:
			_mat.set_shader_parameter("flash", 0.0)
			_mat.set_shader_parameter("shine", -1.0)


func _apply() -> void:
	if is_instance_valid(_label):
		var c := caption_at(_t)
		var sz := _label.size
		_label.scale = Vector2.ONE * float(c.scale) * _fit
		_label.rotation = deg_to_rad(float(c.tilt))
		_label.position = _foot - Vector2(sz.x * 0.5, sz.y + float(c.rise) * _s)
		_label.modulate.a = float(c.alpha)
		_mat.set_shader_parameter("flash", FLASH * clampf(1.0 - (_t - POP) / (FLASH_SEC - POP), 0.0, 1.0))
		var sh := (_t - SHINE_AT) / SHINE_SEC
		_mat.set_shader_parameter("shine", sh if sh >= 0.0 and sh <= 1.0 else -1.0)
	var dim_a := 1.0 - clampf(_t / 0.12, 0.0, 1.0) * clampf((END - _t) / 0.25, 0.0, 1.0)
	for n in _dim:
		if is_instance_valid(n):
			n.modulate.a = dim_a
	queue_redraw()
	for n: Control in [_front, _burst_layer]:
		if is_instance_valid(n):
			n.queue_redraw()


## Caption pose at time `t`: {scale, tilt (degrees), rise (px at the standard screen), alpha}.
static func caption_at(t: float) -> Dictionary:
	var sc := 1.0
	var tilt := 0.0
	var rise := 0.0
	var a := 1.0
	if t < POP:
		var k := t / POP
		sc = lerpf(FROM, PEAK, 1.0 - pow(1.0 - k, 3.0))
		tilt = lerpf(float(TILT[0]), float(TILT[1]), k)
		a = clampf(k * 2.5, 0.0, 1.0)
	elif t < SETTLE:
		var k := _smooth((t - POP) / (SETTLE - POP))
		sc = lerpf(PEAK, DIP, k)
		tilt = lerpf(float(TILT[1]), float(TILT[2]), k)
	elif t < REST:
		var k := _smooth((t - SETTLE) / (REST - SETTLE))
		sc = lerpf(DIP, 1.0, k)
		tilt = lerpf(float(TILT[2]), 0.0, k)
	elif t < LEAVE:
		sc = 1.0 + BREATHE * sin((t - REST) * TAU * BREATHE_HZ)
	else:
		var k := clampf((t - LEAVE) / (END - LEAVE), 0.0, 1.0)
		sc = 1.0 + BREATHE * sin((LEAVE - REST) * TAU * BREATHE_HZ) * (1.0 - k) + 0.08 * k
		rise = RISE * (1.0 - pow(1.0 - k, 2.0))
		a = 1.0 - k * k
	return {"scale": sc, "tilt": tilt, "rise": rise, "alpha": a}


static func _smooth(k: float) -> float:
	return 0.5 - 0.5 * cos(PI * clampf(k, 0.0, 1.0))


## Where the glow, rays and burst centre: the middle of the letters (a little above the line box centre).
func _core() -> Vector2:
	if not is_instance_valid(_label):
		return _foot
	var sz := _label.size * _label.scale
	return _foot + Vector2(0.0, -sz.y * 0.55 - float(caption_at(_t).rise) * _s)


func _caption_w() -> float:
	return _label.size.x * _fit if is_instance_valid(_label) else 300.0


func _burst() -> void:
	var c := _core()
	var w := _caption_w()
	for i in STARS:
		var ang := TAU * (float(i) + _rng.randf_range(-0.35, 0.35)) / STARS
		var dir := Vector2.from_angle(ang)
		_stars.append({
			"pos": c + dir * Vector2(w * 0.32, w * 0.1),
			"vel": dir * _rng.randf_range(STAR_SPEED.x, STAR_SPEED.y) * _s,
			"rot": _rng.randf() * TAU, "spin": _rng.randf_range(-7.0, 7.0),
			"size": _rng.randf_range(STAR_SIZE.x, STAR_SIZE.y) * _s,
			"life": _rng.randf_range(STAR_LIFE.x, STAR_LIFE.y), "age": 0.0,
			"col": CANDY[i % CANDY.size()],
		})
	for i in SPARKS:
		var dir := Vector2.from_angle(_rng.randf() * TAU)
		_sparks.append({
			"pos": c + dir * Vector2(w * 0.2, w * 0.06),
			"vel": dir * _rng.randf_range(SPARK_SPEED.x, SPARK_SPEED.y) * _s,
			"rot": 0.0, "spin": 0.0,
			"size": _rng.randf_range(SPARK_SIZE.x, SPARK_SIZE.y) * _s,
			"life": _rng.randf_range(SPARK_LIFE.x, SPARK_LIFE.y), "age": 0.0,
			"col": Color(1.0, 0.97, 0.85) if i % 2 == 0 else Color("FFD54A"),
		})


func _throw_confetti() -> void:
	var c := _core()
	var w := _caption_w()
	for i in CONFETTI:
		var x := _rng.randf_range(-0.45, 0.45) * w
		_confetti.append({
			"pos": c + Vector2(x, _rng.randf_range(-0.1, 0.1) * w),
			"vel": Vector2(x / (w * 0.45) * CONFETTI_SIDE * _rng.randf_range(0.4, 1.0),
				-_rng.randf_range(CONFETTI_UP.x, CONFETTI_UP.y)) * _s,
			"rot": _rng.randf() * TAU, "spin": _rng.randf_range(-6.0, 6.0),
			"size": _rng.randf_range(CONFETTI_SIZE.x, CONFETTI_SIZE.y) * _s,
			"life": END - CONFETTI_AT, "age": 0.0,
			"col": CANDY[i % CANDY.size()],
			"flip": _rng.randf() * TAU, "flip_speed": _rng.randf_range(8.0, 16.0),
		})


func _step(list: Array[Dictionary], delta: float, drag: float, gravity: float) -> void:
	var keep := exp(-drag * delta)
	for i in range(list.size() - 1, -1, -1):
		var p := list[i]
		p.age = float(p.age) + delta
		if float(p.age) >= float(p.life):
			list.remove_at(i)
			continue
		var v: Vector2 = p.vel
		v = v * keep + Vector2(0.0, gravity * _s * delta)
		p.vel = v
		p.pos = (p.pos as Vector2) + v * delta
		p.rot = float(p.rot) + float(p.spin) * delta


## Envelope of the glow and rays: up by 0.12 s, out from LEAVE to END.
func _halo_alpha() -> float:
	return clampf(_t / 0.12, 0.0, 1.0) * clampf((END - _t) / (END - LEAVE), 0.0, 1.0)


func _draw() -> void:
	if not is_instance_valid(_label):
		return
	var c := _core()
	var w := _caption_w()
	var ha := _halo_alpha()
	if ha > 0.0:
		var grow := 1.0 - pow(1.0 - clampf(_t / 0.3, 0.0, 1.0), 3.0)
		var reach := w * RAYS_W * lerpf(0.3, 1.0, grow)
		_draw_rays(c, reach, reach * RAYS_FLAT, _t * RAYS_SPIN, Color(RAY, RAY.a * ha))
		var gr := w * GLOW_W * lerpf(0.6, 1.0, grow) * (1.0 + 0.04 * sin(_t * 9.0))
		_draw_glow(c, gr, gr * GLOW_FLAT, Color(GLOW, GLOW.a * ha))
	var rk := _t / RING_SEC
	if rk < 1.0:
		var out := 1.0 - pow(1.0 - rk, 2.0)
		var rr := w * lerpf(RING_FROM, RING_TO, out)
		_draw_ring(c, rr, rr * RAYS_FLAT, RING_W * _s * (1.0 - 0.7 * rk), Color(RING, RING.a * (1.0 - rk * rk)))


func _draw_burst() -> void:
	var b := _burst_layer
	var end_a := clampf((END - _t) / 0.3, 0.0, 1.0)
	for p in _confetti:
		var k := float(p.age) / float(p.life)
		var a := clampf((1.0 - k) / 0.25, 0.0, 1.0) * end_a
		var sz := float(p.size)
		var half := Vector2(sz * 0.32 * absf(cos(float(p.flip))) + 0.5, sz * 0.5)
		var col: Color = p.col
		col = col.darkened(0.25 * (1.0 - absf(cos(float(p.flip)))))
		b.draw_colored_polygon(_box(p.pos, half, float(p.rot)), Color(col, a))
	for p in _stars:
		var k := float(p.age) / float(p.life)
		var a := clampf((1.0 - k) / 0.45, 0.0, 1.0)
		var r := float(p.size) * 0.5 * clampf(float(p.age) / 0.08, 0.0, 1.0) * lerpf(1.0, 0.6, k)
		if r < 1.0:
			continue
		var col: Color = p.col
		b.draw_colored_polygon(_star(p.pos, r, float(p.rot)), Color(col, a))
		b.draw_colored_polygon(_star((p.pos as Vector2) + Vector2(-0.12, -0.12) * r, r * 0.45, float(p.rot)),
			Color(1.0, 1.0, 1.0, a * 0.8))
	for p in _sparks:
		var k := float(p.age) / float(p.life)
		b.draw_circle(p.pos, float(p.size) * (1.0 - k * 0.5), Color(p.col as Color, 1.0 - k))


func _draw_twinkles() -> void:
	for tw in _twinkles:
		var k := (_t - float(tw.at)) / TWINKLE_SEC
		if k <= 0.0 or k >= 1.0:
			continue
		var f := sin(PI * k)
		var r := float(tw.size) * 0.5 * f
		if r < 1.0:
			continue  # a tiny polygon fails to triangulate
		var rot := float(tw.rot) + k * 1.2
		_front.draw_colored_polygon(_sparkle(tw.pos, r * 1.35, rot), Color(TWINKLE_EDGE, 0.8 * f))
		_front.draw_colored_polygon(_sparkle(tw.pos, r, rot), Color(1.0, 1.0, 0.96, f))


## Wedges from `c` out to an ellipse (`rx`, `ry`), every other one a gap; each fades to clear at its tip.
func _draw_rays(c: Vector2, rx: float, ry: float, turn: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var clear := Color(col, 0.0)
	var step := TAU / float(RAYS * 2)
	for i in RAYS:
		var a0 := turn + step * 2.0 * float(i)
		var a1 := a0 + step * (0.7 if i % 2 == 0 else 1.15)
		var b := pts.size()
		pts.append(c)
		pts.append(c + Vector2(cos(a0) * rx, sin(a0) * ry))
		pts.append(c + Vector2(cos(a1) * rx, sin(a1) * ry))
		cols.append(col)
		cols.append(clear)
		cols.append(clear)
		idx.append_array(PackedInt32Array([b, b + 1, b + 2]))
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)


## Soft ellipse: `col` at the centre fading to clear at the rim.
func _draw_glow(c: Vector2, rx: float, ry: float, col: Color) -> void:
	const SEG := 40
	var pts := PackedVector2Array([c])
	var cols := PackedColorArray([col])
	var idx := PackedInt32Array()
	var mid := Color(col, col.a * 0.45)
	var clear := Color(col, 0.0)
	for i in SEG:
		var d := Vector2.from_angle(TAU * float(i) / SEG)
		pts.append(c + d * Vector2(rx, ry) * 0.55)
		pts.append(c + d * Vector2(rx, ry))
		cols.append(mid)
		cols.append(clear)
	for i in SEG:
		var a := 1 + i * 2
		var b := 1 + ((i + 1) % SEG) * 2
		idx.append_array(PackedInt32Array([0, a, b, a, a + 1, b + 1, a, b + 1, b]))
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)


## Elliptic band `w` px wide around radii (`rx`, `ry`): `col` on its middle line, clear at both edges.
func _draw_ring(c: Vector2, rx: float, ry: float, w: float, col: Color) -> void:
	const SEG := 48
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var clear := Color(col, 0.0)
	for i in SEG:
		var d := Vector2.from_angle(TAU * float(i) / SEG)
		for off: float in [-0.5, 0.0, 0.5]:
			pts.append(c + d * Vector2(rx, ry) + d * w * off)
			cols.append(col if off == 0.0 else clear)
	var idx := PackedInt32Array()
	for i in SEG:
		var a := i * 3
		var b := ((i + 1) % SEG) * 3
		for j in 2:
			idx.append_array(PackedInt32Array([a + j, b + j, b + j + 1, a + j, b + j + 1, a + j + 1]))
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)


## 5-point star of outer radius `r`, one point along `rot`.
static func _star(c: Vector2, r: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		pts.append(c + Vector2.from_angle(rot + i * PI / 5.0) * (r if i % 2 == 0 else r * STAR_INNER))
	return pts


## 4-point sparkle of reach `r` with thin waists.
static func _sparkle(c: Vector2, r: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(c + Vector2.from_angle(rot + i * PI / 4.0) * (r if i % 2 == 0 else r * 0.2))
	return pts


## Rectangle of half size `half` turned by `rot` around `c`.
static func _box(c: Vector2, half: Vector2, rot: float) -> PackedVector2Array:
	var x := Vector2.from_angle(rot)
	var y := Vector2(-x.y, x.x)
	return PackedVector2Array([c - x * half.x - y * half.y, c + x * half.x - y * half.y, c + x * half.x + y * half.y,
		c - x * half.x + y * half.y])
