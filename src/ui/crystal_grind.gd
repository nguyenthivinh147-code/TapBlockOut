extends Control
## Prism light while a crystal block grinds through its bar. Compact: it stays within about two cells of the cut and is
## gone GLITTER_LIFE seconds after the block's tail passes the bar.
## - Prism sparks: rainbow sparks streak out of the block's two side edges along the bar's inner face, leaning a little
##   into the board, like an angle grinder biting crystal. Always on screen, whatever side the block leaves by.
##   A hot white star flickers where each spray leaves the block, popping a little bigger as the block touches the bar.
## - Cut flare: an anamorphic lens streak on the inner face (white core, rainbow glow running red to violet across the
##   block) a little longer than the block is wide, flickering, with tiny stars twinkling along it.
## - Prism fan: rainbow rays (red to violet across the block width) fan out of the bar's outer face along the travel
##   direction; they flicker and sway while the block passes, then shoot out and fade. Rainbow glitter sprays with them.
## - Finale when the tail passes: a big four-point star flares and spins at the outer face, a rainbow shock arc bursts
##   outward and a pinch of glitter pops.
## Rainbow and ice colours blend normally so they read on the light board and screen; only white cores add light.
## Top-level, canvas coordinates. Spawn it before the grind bits: top-level items draw in the order they enter the tree,
## so the candy bits fly over the light.

const BoardFx := preload("res://src/ui/board_fx.gd")
const CrystalFly := preload("res://src/ui/crystal_fly.gd")

const GROW := 0.08  # s: flare and fan light up after the block touches the bar
const FADE := 0.24  # s after the tail passes: flare and fan fade out
const FLARE_EXT := 0.5  # cells: the lens streak's glow runs past each side of the block
const FLARE_CORE_EXT := 0.8  # cells: its white core runs further
const FLARE_W := 0.16  # cells, glow width
const FLARE_CORE_W := 0.05
const FLARE_ALPHA := 0.75
const FLARE_SAT := 0.6
const SEAM_STARS := 3  # twinkle slots along the cut, each twinkles once per STAR_CYCLE
const STAR_CYCLE := 0.15  # s
const STAR_PX := 0.5  # twinkle size, cells
const SPARKS := 26  # per side, per SPARK_LIFE seconds of grinding
const SPARK_LIFE := 0.24
const SPARK_V := Vector2(4.0, 9.0)  # cells/s
const SPARK_DAMP := Vector2(8.0, 14.0)  # cells/s²
const SPARK_TILT := 0.3  # rad: sparks lean off the bar into the board
const SPARK_SPREAD := 18.0  # degrees
const SPARK_LEN := Vector2(0.3, 0.6)  # cells, spark streak length
const EDGE_PX := 0.6  # cells, hot star where the sparks leave the block
const EDGE_POP := 0.8  # the hot stars start this much bigger, settling over EDGE_POP_TIME
const EDGE_POP_TIME := 0.15
const RAYS := 9
const FAN := 0.5  # rad, half opening of the fan
const SWAY := 0.07  # rad, the fan sways this much while the block passes
const RAY_LEN := Vector2(0.75, 1.45)  # cells: short (odd) and long (even) rays
const RAY_W := 0.14  # half width of a ray at the bar, cells
const RAY_SAT := 0.85
const RAY_ALPHA := 0.7
const SHOOT := 0.4  # rays grow this much longer while fading out
const PRISM_SAT := 0.8  # sparks and glitter
const FLARE_PX := 1.7  # finale star, cells
const FLARE_TIME := 0.3
const ARC_REACH := 1.0  # finale shock arc grows this many cells
const ARC_TIME := 0.32
const ARC_OPEN := 2.0  # rad, half opening of the shock arc around the travel direction
const ARC_W := 0.13  # cells
const GLITTER := 16  # per GLITTER_LIFE seconds of grinding
const GLITTER_LIFE := 0.45
const GLITTER_V := Vector2(2.5, 6.0)  # cells/s
const GLITTER_SPREAD := 55.0  # degrees
const POP_GLITTER := 10  # finale

var _seam := Vector2.ZERO  # centre of the block's span on the bar's inner face, canvas
var _mouth := Vector2.ZERO  # the same point on the bar's outer face
var _dir := Vector2.RIGHT  # travel direction
var _half := 21.0  # half the block width, px
var _cell: float = 42.0
var _hold: float = 0.3  # s until the tail passes the inner face
var _age: float = 0.0
var _star: Texture2D = null
static var _spark_tex: Texture2D = null
var _glow: Control = null
var _streams: Array[CPUParticles2D] = []  # sparks (both sides) and glitter: emit while the block passes
var _popped: bool = false


## `seam`, `mouth` in canvas coordinates; `half_span` and `cell` in px; `hold` is how long the block takes to pass.
static func spawn(parent: Node, seam: Vector2, mouth: Vector2, dir: Vector2, half_span: float, cell: float, hold: float) -> Control:
	var w: Control = load("res://src/ui/crystal_grind.gd").new()
	w._seam = seam
	w._mouth = mouth
	w._dir = dir
	w._half = half_span
	w._cell = cell
	w._hold = maxf(hold, 0.05)
	w._build()
	parent.add_child(w)
	w.global_position = Vector2.ZERO
	for p in w._streams:
		p.emitting = true
	return w


## Seconds from spawn until the node frees itself.
func life() -> float:
	return _hold + GLITTER_LIFE


## Particle streams that run while the block passes (sparks on both sides, glitter).
func streams() -> Array[CPUParticles2D]:
	return _streams


func _build() -> void:
	name = "CrystalGrind"
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_star = BoardFx.sparkle_texture()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow = Control.new()
	_glow.name = "Glow"
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.material = add
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	for s: float in [1.0, -1.0]:
		_streams.append(_make_sparks(s))
	_streams.append(_make_glitter(GLITTER, GLITTER_SPREAD, 1.0))
	for p in _streams:
		add_child(p)


func _process(delta: float) -> void:
	_age += delta
	if _age >= life():
		queue_free()
		return
	if _age >= _hold and not _popped:
		_popped = true
		for p in _streams:
			p.emitting = false
		var pop := _make_glitter(POP_GLITTER, 110.0, 1.2)
		pop.one_shot = true
		pop.explosiveness = 0.9
		add_child(pop)
		pop.emitting = true
	queue_redraw()
	_glow.queue_redraw()


## 0 when the block touches the bar, 1 after GROW seconds, back to 0 FADE seconds after the tail passes.
func _env() -> float:
	return smoothstep(0.0, GROW, _age) * (1.0 - _out())


## 0 while the block passes, up to 1 over FADE seconds after the tail passes.
func _out() -> float:
	return smoothstep(_hold, _hold + FADE, _age)


func _perp() -> Vector2:
	return Vector2(-_dir.y, _dir.x)


static func _prism(k: float, sat: float, a: float) -> Color:
	return Color.from_hsv(fposmod(k, 1.0), sat, 1.0, a)


# --- normal blend: fan, flare glow, twinkles, finale under-star and arc ---

func _draw() -> void:
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var e := _env()
	if e > 0.005:
		_add_rays(verts, cols, idx, e)
		_add_lens(verts, cols, idx, FLARE_W, FLARE_EXT, FLARE_ALPHA * e * _flicker(), FLARE_SAT)
	if not idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, verts, cols)
	if e > 0.005:
		_draw_twinkles(e)
		_draw_edges(self, e, 1.3, Color(CrystalFly.ICE_DEEP, 0.7))
	var q := (_age - _hold) / FLARE_TIME
	if q > 0.0 and q < 1.0:
		_star_at(self, _mouth, _flare_px(q) * 1.25, q * 1.2, Color(CrystalFly.ICE_DEEP, 0.75))
	_draw_arc()


## Rainbow rays fanning out of the outer face: ray `i` sits at its share of the block width, tilts outward with it
## and takes its colour from red (one side) to violet (the other), like light split by a prism.
func _add_rays(verts: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array, e: float) -> void:
	var perp := _perp()
	var grow := 1.0 - pow(1.0 - smoothstep(0.0, GROW, _age), 2.0)
	var shoot := 1.0 + SHOOT * _out()
	var thin := 1.0 - 0.5 * _out()
	for i in RAYS:
		var k := float(i) / float(RAYS - 1)
		var s := k * 2.0 - 1.0
		var ray := _dir.rotated(s * FAN + sin(_age * 7.0) * SWAY)
		var side := Vector2(-ray.y, ray.x) * RAY_W * _cell * thin
		var base := _mouth + perp * s * _half * 0.8
		var flick := 0.8 + 0.2 * sin(_age * 31.0 + float(i) * 2.3)
		var length := (RAY_LEN.y if i % 2 == 0 else RAY_LEN.x) * _cell * grow * shoot * flick
		var c := _prism(k * 0.78, RAY_SAT, RAY_ALPHA * e * (0.85 + 0.15 * sin(_age * 23.0 + float(i))))
		var clear := Color(c, 0.0)
		var b := verts.size()
		verts.append_array(PackedVector2Array([base - side, base, base + side, base + ray * length]))
		cols.append_array(PackedColorArray([clear, c, clear, clear]))
		idx.append_array(PackedInt32Array([b, b + 1, b + 3, b + 1, b + 2, b + 3]))


## Anamorphic lens streak on the inner face, just off the bar on the block side: soft across its width, full strength
## over the block's span and tapering to nothing `ext` cells past each side. `sat` > 0 runs a rainbow along it (red to
## violet across the block, like the fan), 0 draws it white.
func _add_lens(verts: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array, width: float, ext: float, alpha: float, sat: float) -> void:
	var perp := _perp()
	var at := _seam - _dir * 0.03 * _cell
	var reach := _half + ext * _cell
	var n := 12
	var b := verts.size()
	for i in n + 1:
		var u := lerpf(-reach, reach, float(i) / float(n))
		var taper := clampf((reach - absf(u)) / (ext * _cell), 0.0, 1.0)
		taper = taper * taper * (3.0 - 2.0 * taper)
		var hw := _dir * width * 0.5 * _cell * (0.35 + 0.65 * taper)
		var p := at + perp * u
		verts.append_array(PackedVector2Array([p - hw, p, p + hw]))
		var c := _prism(clampf(0.5 + u / (2.0 * _half), 0.0, 1.0) * 0.78, sat, alpha * taper) if sat > 0.0 else Color(CrystalFly.CORE, alpha * taper)
		cols.append_array(PackedColorArray([Color(c, 0.0), c, Color(c, 0.0)]))
		if i < n:
			var o := b + i * 3
			for s in 2:
				idx.append_array(PackedInt32Array([o + s, o + s + 1, o + s + 3, o + s + 1, o + s + 4, o + s + 3]))


func _flicker() -> float:
	return 0.82 + 0.18 * sin(_age * 47.0) * sin(_age * 19.0 + 1.3)


## Tiny stars twinkling at random spots along the cut, one per slot per STAR_CYCLE.
func _draw_twinkles(e: float) -> void:
	var perp := _perp()
	for j in SEAM_STARS:
		var phase := _age / STAR_CYCLE + float(j) / float(SEAM_STARS)
		var cycle := floorf(phase)
		var f := phase - cycle
		var r := fposmod(sin(cycle * 12.9898 + float(j) * 78.233) * 43758.5453, 1.0)
		var px := STAR_PX * _cell * pow(sin(f * PI), 2.0) * e
		_star_at(self, _seam + perp * (r * 2.0 - 1.0) * _half - _dir * 0.04 * _cell, px, cycle * 0.7, CrystalFly.CORE)


## Finale shock arc: bursts outward from the outer face when the tail passes, thins and fades as it grows.
func _draw_arc() -> void:
	var q := (_age - _hold) / ARC_TIME
	if q <= 0.0 or q >= 1.0:
		return
	var rad := (0.15 + ARC_REACH * (1.0 - pow(1.0 - q, 2.5))) * _cell
	var n := 32
	var pts := PackedVector2Array()
	var cs := PackedColorArray()
	var base := _dir.angle()
	for i in n + 1:
		var k := float(i) / float(n)
		var ends := smoothstep(0.0, 0.2, k) * smoothstep(1.0, 0.8, k)
		pts.append(_mouth + Vector2.from_angle(base + (k * 2.0 - 1.0) * ARC_OPEN) * rad)
		cs.append(_prism(k * 0.78 + _age, RAY_SAT, 0.9 * (1.0 - q) * ends))
	draw_polyline_colors(pts, cs, maxf(1.0, ARC_W * _cell * (1.0 - q)), true)


# --- add light: white cores ---

func _draw_glow() -> void:
	var e := _env()
	if e > 0.005:
		var verts := PackedVector2Array()
		var cols := PackedColorArray()
		var idx := PackedInt32Array()
		_add_lens(verts, cols, idx, FLARE_CORE_W, FLARE_CORE_EXT, e * _flicker(), 0.0)
		RenderingServer.canvas_item_add_triangle_array(_glow.get_canvas_item(), idx, verts, cols)
		_draw_edges(_glow, e, 1.0, CrystalFly.CORE)
	var q := (_age - _hold) / FLARE_TIME
	if q > 0.0 and q < 1.0:
		_star_at(_glow, _mouth, _flare_px(q), q * 1.2, CrystalFly.CORE)
		_star_at(_glow, _mouth, _flare_px(q) * 0.6, PI * 0.25 - q, Color(CrystalFly.PINK, 0.8))


## Hot stars where the sparks leave the block's two side edges, flickering; `grow` scales them, `col` tints them.
func _draw_edges(ci: CanvasItem, e: float, grow: float, col: Color) -> void:
	var pop := 1.0 + EDGE_POP * (1.0 - smoothstep(0.0, EDGE_POP_TIME, _age))
	for s: float in [1.0, -1.0]:
		var at := _seam + _perp() * s * _half - _dir * 0.04 * _cell
		var px := EDGE_PX * _cell * e * pop * grow * (0.75 + 0.25 * sin(_age * 41.0 + s * 1.7))
		_star_at(ci, at, px, _age * 4.0 * s, col)


## Finale star size: up fast, then shrinks away.
func _flare_px(q: float) -> float:
	return FLARE_PX * _cell * sin(PI * sqrt(q))


func _star_at(ci: CanvasItem, at: Vector2, px: float, rot: float, col: Color) -> void:
	if px <= 0.5:
		return
	ci.draw_set_transform(at, rot, Vector2.ONE)
	ci.draw_texture_rect(_star, Rect2(Vector2(-px, -px) * 0.5, Vector2(px, px)), false, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- particles ---

## Rainbow sparks out of one side edge of the block (`sgn` picks the side), streaking along the inner face.
func _make_sparks(sgn: float) -> CPUParticles2D:
	var perp := _perp() * sgn
	var p := CPUParticles2D.new()
	p.name = "CrystalSparks"
	p.emitting = false
	p.amount = SPARKS
	p.lifetime = SPARK_LIFE
	p.randomness = 0.5
	p.texture = _spark_texture()
	# local x runs along the bar away from the block; local y = sgn * -dir, so the tilt into the board flips with the side
	p.position = _seam + perp * _half - _dir * 0.04 * _cell
	p.rotation = perp.angle()
	p.direction = Vector2.from_angle(SPARK_TILT * sgn)
	p.spread = SPARK_SPREAD
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(0.05, 0.06) * _cell
	p.initial_velocity_min = SPARK_V.x * _cell
	p.initial_velocity_max = SPARK_V.y * _cell
	p.damping_min = SPARK_DAMP.x * _cell
	p.damping_max = SPARK_DAMP.y * _cell
	p.particle_flag_align_y = true
	p.scale_amount_min = SPARK_LEN.x * _cell / float(_spark_texture().get_height())
	p.scale_amount_max = SPARK_LEN.y * _cell / float(_spark_texture().get_height())
	p.scale_amount_curve = BoardFx.shrink_curve()
	_color(p)
	return p


## Rainbow glitter from the outer face across the block width, tumbling and twinkling. `amount` per GLITTER_LIFE seconds.
func _make_glitter(amount: int, spread: float, power: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "CrystalGlitter"
	p.emitting = false
	p.amount = amount
	p.lifetime = GLITTER_LIFE
	p.randomness = 0.4
	p.texture = _star
	# local x is the travel direction, so the emission strip lies along the bar's outer face
	p.position = _mouth
	p.rotation = _dir.angle()
	p.direction = Vector2.RIGHT
	p.spread = spread
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(0.04 * _cell, maxf(1.0, _half * 0.85))
	p.initial_velocity_min = GLITTER_V.x * _cell * power
	p.initial_velocity_max = GLITTER_V.y * _cell * power
	p.damping_min = 3.0 * _cell
	p.damping_max = 6.0 * _cell
	p.gravity = Vector2(0.0, 2.0 * _cell)
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -420.0
	p.angular_velocity_max = 420.0
	p.scale_amount_min = 0.28 * _cell / 48.0
	p.scale_amount_max = 0.6 * _cell / 48.0
	p.scale_amount_curve = _twinkle_curve()
	_color(p)
	return p


## Each particle one rainbow colour; hot (paler) when it starts, then fading out.
static func _color(p: CPUParticles2D) -> void:
	var hue := Gradient.new()
	hue.set_color(0, _prism(0.0, PRISM_SAT, 1.0))
	hue.set_color(1, _prism(0.78, PRISM_SAT, 1.0))
	hue.add_point(0.25, _prism(0.14, PRISM_SAT, 1.0))
	hue.add_point(0.5, _prism(0.36, PRISM_SAT, 1.0))
	hue.add_point(0.75, _prism(0.55, PRISM_SAT, 1.0))
	p.color_initial_ramp = hue
	var fade := Gradient.new()
	fade.set_color(0, Color(1.6, 1.6, 1.6))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.4, Color.WHITE)
	p.color_ramp = fade


## Spark streak, white: a round head at the bottom (the texture's +y follows the velocity, so it leads) and a body
## tapering to a fine tail.
static func _spark_texture() -> Texture2D:
	if _spark_tex == null:
		var sz := Vector2i(9, 40)
		var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
		for y in sz.y:
			for x in sz.x:
				var u := (float(x) + 0.5) / float(sz.x) * 2.0 - 1.0
				var v := (float(y) + 0.5) / float(sz.y)  # 0 tail, 1 head
				var w := 0.2 + 0.6 * v
				var body := clampf(1.0 - absf(u) / w, 0.0, 1.0) * v
				var head := exp(-(u * u * 5.0 + pow((v - 0.84) * 6.0, 2.0)))
				img.set_pixel(x, y, Color(1, 1, 1, clampf(body + head, 0.0, 1.0)))
		_spark_tex = ImageTexture.create_from_image(img)
	return _spark_tex


## Pops in, twinkles once, shrinks away.
static func _twinkle_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.3))
	c.add_point(Vector2(0.12, 1.0))
	c.add_point(Vector2(0.4, 0.5))
	c.add_point(Vector2(0.6, 0.9))
	c.add_point(Vector2(1.0, 0.0))
	return c
