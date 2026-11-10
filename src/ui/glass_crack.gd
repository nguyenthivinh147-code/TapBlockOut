extends Control
## Cracked screen glass when a Special Bomb explodes (design.md section 7 "Màn đặc biệt"): white cracks run from the
## blast out past the screen edges, ring pieces join neighbouring cracks into a web, some cells of the web are loose
## shards (they show the screen below shifted and lightened, glass_shard.gdshader) and the impact spot is crushed.
## The cracks spread in SPREAD_SEC, stay until `hold` seconds after the blast, fade in FADE_SEC and the node frees
## itself. It sits in the screen's overlay, so it does not shake with the board, and it never takes input.
##
## Use: var g := GlassCrack.new(); g.setup(overlay.size, point_in_overlay, hold); overlay.add_child(g)

const SHARD_SHADER := preload("res://src/ui/glass_shard.gdshader")

## Lengths are px at the design width and scale with the real width.
const DESIGN_W := 886.0
const RAYS_MIN := 15
const RAYS_MAX := 19
const RAY_JITTER := 0.35  # share of the gap between rays that a ray may turn off its even angle
const RAY_SEGS_MAX := 160  # safety cap per ray
const SEG_MIN := 30.0
const SEG_MAX := 80.0
const SEG_GROW := 1.6  # segments are this much longer at the far end: cracks straighten out
const SEG_TURN := 0.2  # radians a segment may lean off its ray
const FORK_CHANCE := 0.16  # per ray segment past the first ring
const FORK_TURN_MIN := 0.3
const FORK_TURN_MAX := 0.7
const FORK_SEGS_MIN := 2
const FORK_SEGS_MAX := 4
const RINGS: Array[float] = [72.0, 135.0, 215.0, 325.0, 475.0, 680.0]
const RING_CHANCE: Array[float] = [1.0, 0.9, 0.75, 0.6, 0.45, 0.35]
const RING_WOBBLE := 0.12  # each end of a ring piece sits this share off the ring radius
const RING_SAG := 0.08  # ring pieces bow toward the centre by up to this share of their length
const SHARD_CHANCE := 0.5  # web cell between two ring pieces that becomes a loose shard
const SHARD_SHIFT := 12.0
const SHARD_SHEEN_MIN := 0.1
const SHARD_SHEEN_MAX := 0.34
const SHARD_SHEEN_SLOPE := 0.16  # lighter toward LIGHT_DIR across a shard
const LIGHT_DIR := Vector2(-0.6, -0.8)
const CORE_R := 44.0
const CORE_CRACKS := 28
const CORE_RIM := 18
const CORE_IN := Color(1.0, 1.0, 1.0, 0.95)
const CORE_OUT := Color(1.0, 1.0, 1.0, 0.3)
const HAZE_R := 150.0  # soft white haze of powdered glass around the impact
const HAZE_IN := Color(1.0, 1.0, 1.0, 0.5)
const HAZE_SIDES := 28
const LINE_W := 6.0  # crack width at the centre ...
const LINE_W_FAR := 2.4  # ... and from LINE_TAPER px out
const LINE_TAPER := 700.0
const LINE_COLOR := Color(1.0, 1.0, 1.0, 0.95)
const EDGE_COLOR := Color(0.16, 0.14, 0.3, 0.42)  # dark rim under each crack so it reads on light backgrounds
const EDGE_OFFSET := Vector2(1.0, 1.5)
const GLOW_COLOR := Color(1.0, 1.0, 1.0, 0.25)
const GLOW_FROM_W := 3.0  # cracks at least this wide (design px) get a soft glow
const SPREAD_SEC := 0.12
const FADE_SEC := 0.45

var hold: float = 1.0
var center: Vector2 = Vector2.ZERO
## Cracks as [a, b, width, ra, rb]; ra, rb = distance of a, b from the centre.
var segments: Array = []
## Loose shards: {points, colors, indices, r}; r = farthest point from the centre.
var shards: Array = []

var _rng := RandomNumberGenerator.new()
var _u: float = 1.0
var _reach: float = 0.0
var _reveal: float = 0.0
var _core_pts := PackedVector2Array()
var _core_cols := PackedColorArray()
var _core_idx := PackedInt32Array()
var _shard_layer: Control = null


## Builds the web for an overlay of size `area` around `at` (overlay px). `hold_sec` from the blast to the fade.
## `seed_value` 0 picks a random web.
func setup(area: Vector2, at: Vector2, hold_sec: float, seed_value: int = 0) -> void:
	name = "GlassCrack"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = area
	center = at
	hold = hold_sec
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	_u = maxf(area.x, 1.0) / DESIGN_W
	_reach = 0.0
	for corner: Vector2 in [Vector2.ZERO, Vector2(area.x, 0.0), Vector2(0.0, area.y), area]:
		_reach = maxf(_reach, at.distance_to(corner))
	_reach += SEG_MAX * _u * SEG_GROW
	segments.clear()
	shards.clear()
	var rays := _build_rays(Rect2(Vector2.ZERO, area).grow(24.0 * _u))
	_build_web(rays)
	_build_core()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shard_layer = Control.new()
	_shard_layer.name = "Shards"
	_shard_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shard_layer.show_behind_parent = true
	_shard_layer.size = size
	var m := ShaderMaterial.new()
	m.shader = SHARD_SHADER
	var vp := get_viewport_rect().size
	m.set_shader_parameter("max_shift", Vector2(SHARD_SHIFT * _u / maxf(vp.x, 1.0), SHARD_SHIFT * _u / maxf(vp.y, 1.0)))
	_shard_layer.material = m
	_shard_layer.draw.connect(_draw_shards)
	add_child(_shard_layer)
	var tw := create_tween()
	tw.tween_method(_set_reveal, 0.0, 1.0, SPREAD_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(hold - SPREAD_SEC, 0.0))
	tw.tween_property(self, "modulate:a", 0.0, FADE_SEC)
	tw.tween_callback(queue_free)


## Share of the web shown, 0..1 (the cracks reach this share of the farthest corner).
func reveal() -> float:
	return _reveal / maxf(_reach, 1.0)


func _set_reveal(k: float) -> void:
	_reveal = _reach * k
	queue_redraw()
	if _shard_layer != null:
		_shard_layer.queue_redraw()


# --- geometry ---

## Cracks from the centre outward, one per even angle, until each leaves `bounds`. Returns their points.
func _build_rays(bounds: Rect2) -> Array:
	var n := _rng.randi_range(RAYS_MIN, RAYS_MAX)
	var gap := TAU / n
	var turn0 := _rng.randf() * TAU
	var rays: Array = []
	for i in n:
		var ang := turn0 + gap * (i + _rng.randf_range(-RAY_JITTER, RAY_JITTER))
		var dir := Vector2.from_angle(ang)
		var side := dir.orthogonal()
		var p := center + dir * CORE_R * _u * _rng.randf_range(0.5, 0.9)
		var pts := PackedVector2Array([p])
		for _k in RAY_SEGS_MAX:
			if not bounds.has_point(p):
				break
			var r := p.distance_to(center)
			var seg := _rng.randf_range(SEG_MIN, SEG_MAX) * _u * lerpf(1.0, SEG_GROW, minf(r / _reach, 1.0))
			# Zigzag, pulled back toward the ray's straight line so neighbours never cross.
			var off := (p - center).dot(side)
			var lean := _rng.randf_range(-SEG_TURN, SEG_TURN) - clampf(off / (seg * 3.0), -SEG_TURN, SEG_TURN)
			var q := p + Vector2.from_angle(ang + lean) * seg
			_add_segment(p, q, 1.0)
			if r > RINGS[0] * _u and _rng.randf() < FORK_CHANCE:
				_add_fork(q, ang + lean, bounds)
			p = q
			pts.append(p)
		rays.append(pts)
	return rays


func _add_fork(from: Vector2, heading: float, bounds: Rect2) -> void:
	var turn := _rng.randf_range(FORK_TURN_MIN, FORK_TURN_MAX)
	var dir := heading + (turn if _rng.randf() < 0.5 else -turn)
	var p := from
	for _k in _rng.randi_range(FORK_SEGS_MIN, FORK_SEGS_MAX):
		if not bounds.has_point(p):
			return
		var seg_len := _rng.randf_range(SEG_MIN, SEG_MAX) * _u * 0.8
		var q := p + Vector2.from_angle(dir + _rng.randf_range(-SEG_TURN, SEG_TURN)) * seg_len
		_add_segment(p, q, 0.7)
		p = q


## Ring pieces between neighbouring rays, then loose shards in some cells closed by two ring pieces.
func _build_web(rays: Array) -> void:
	var n := rays.size()
	var pieces: Array = []  # [ring][gap] -> {a: cut on ray i, b: cut on ray i + 1, mid} or null
	for j in RINGS.size():
		var row: Array = []
		for i in n:
			var piece: Variant = null
			if _rng.randf() < RING_CHANCE[j]:
				var ring := RINGS[j] * _u
				var ca := _cut(rays[i], ring * (1.0 + _rng.randf_range(-RING_WOBBLE, RING_WOBBLE)))
				var cb := _cut(rays[(i + 1) % n], ring * (1.0 + _rng.randf_range(-RING_WOBBLE, RING_WOBBLE)))
				if not ca.is_empty() and not cb.is_empty():
					var a: Vector2 = ca[0]
					var b: Vector2 = cb[0]
					var mid := (a + b) * 0.5
					mid += (center - mid).normalized() * a.distance_to(b) * _rng.randf_range(0.0, RING_SAG)
					_add_segment(a, mid, 0.85)
					_add_segment(mid, b, 0.85)
					piece = {"a": ca, "b": cb, "mid": mid}
			row.append(piece)
		pieces.append(row)
	for j in RINGS.size() - 1:
		for i in n:
			var inner: Variant = pieces[j][i]
			var outer: Variant = pieces[j + 1][i]
			if inner == null or outer == null or _rng.randf() >= SHARD_CHANCE:
				continue
			_add_shard(rays[i], rays[(i + 1) % n], inner, outer)


## Where `ray` first reaches `radius` from the centre: [point, index of the first ray point past it], or [] if the
## ray leaves the screen first.
func _cut(ray: PackedVector2Array, radius: float) -> Array:
	for i in range(1, ray.size()):
		var r0 := ray[i - 1].distance_to(center)
		var r1 := ray[i].distance_to(center)
		if r0 <= radius and r1 >= radius:
			return [ray[i - 1].lerp(ray[i], (radius - r0) / maxf(r1 - r0, 0.001)), i]
	return []


func _add_shard(ray_a: PackedVector2Array, ray_b: PackedVector2Array, inner: Dictionary, outer: Dictionary) -> void:
	var in_a: Vector2 = inner.a[0]
	var out_a: Vector2 = outer.a[0]
	var pts := PackedVector2Array()
	pts.append(in_a)
	pts.append(inner.mid)
	pts.append(inner.b[0])
	for k in range(int(inner.b[1]), int(outer.b[1])):
		pts.append(ray_b[k])
	pts.append(outer.b[0])
	pts.append(outer.mid)
	pts.append(out_a)
	for k in range(int(outer.a[1]) - 1, int(inner.a[1]) - 1, -1):
		pts.append(ray_a[k])
	var idx := Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		return
	var mid := Vector2.ZERO
	var r := 0.0
	for p in pts:
		mid += p
		r = maxf(r, p.distance_to(center))
	mid /= pts.size()
	var span := maxf(r - in_a.distance_to(center), 1.0)
	var shift := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.4, 1.0)
	var sheen := _rng.randf_range(SHARD_SHEEN_MIN, SHARD_SHEEN_MAX)
	var light := LIGHT_DIR.normalized()
	var cols := PackedColorArray()
	for p in pts:
		var s := clampf(sheen + SHARD_SHEEN_SLOPE * (p - mid).dot(light) / span, 0.0, 0.5)
		cols.append(Color(0.5 + 0.5 * shift.x, 0.5 + 0.5 * shift.y, s, 1.0))
	shards.append({"points": pts, "colors": cols, "indices": idx, "r": r})


## Crushed impact spot: a soft haze, a bright jagged patch and short cracks every way.
func _build_core() -> void:
	_core_pts = PackedVector2Array([center])
	_core_cols = PackedColorArray([HAZE_IN])
	_core_idx = PackedInt32Array()
	for k in HAZE_SIDES:
		_core_pts.append(center + Vector2.from_angle(TAU * k / HAZE_SIDES) * HAZE_R * _u)
		_core_cols.append(Color(HAZE_IN, 0.0))
		_core_idx.append(0)
		_core_idx.append(k + 1)
		_core_idx.append((k + 1) % HAZE_SIDES + 1)
	var base := _core_pts.size()
	_core_pts.append(center)
	_core_cols.append(CORE_IN)
	for k in CORE_RIM:
		var ang := TAU * (k + _rng.randf_range(-0.3, 0.3)) / CORE_RIM
		_core_pts.append(center + Vector2.from_angle(ang) * CORE_R * _u * _rng.randf_range(0.55, 1.05))
		_core_cols.append(CORE_OUT)
		_core_idx.append(base)
		_core_idx.append(base + k + 1)
		_core_idx.append(base + (k + 1) % CORE_RIM + 1)
	for k in CORE_CRACKS:
		var ang := _rng.randf() * TAU
		var p := center + Vector2.from_angle(ang) * CORE_R * _u * _rng.randf_range(0.0, 0.6)
		var q := p + Vector2.from_angle(ang + _rng.randf_range(-0.5, 0.5)) * CORE_R * _u * _rng.randf_range(0.5, 1.4)
		_add_segment(p, q, 0.55)


func _add_segment(a: Vector2, b: Vector2, k: float) -> void:
	var ra := a.distance_to(center)
	var rb := b.distance_to(center)
	var w := lerpf(LINE_W, LINE_W_FAR, minf(minf(ra, rb) / (LINE_TAPER * _u), 1.0)) * _u * k
	segments.append([a, b, maxf(w, 1.0), ra, rb])


# --- drawing ---

func _draw() -> void:
	if _reveal <= 0.0:
		return
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _core_idx, _core_pts, _core_cols)
	var shown: Array = []  # [a, b, width] cut to the reveal radius
	for s in segments:
		var ra: float = s[3]
		var rb: float = s[4]
		if _reveal <= minf(ra, rb):
			continue
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		if ra > rb:
			# Grow from the end nearer the centre.
			var far := a
			a = b
			b = far
			var far_r := ra
			ra = rb
			rb = far_r
		if _reveal < rb:
			b = a.lerp(b, (_reveal - ra) / maxf(rb - ra, 0.001))
		shown.append([a, b, float(s[2])])
	# One pass per layer, so every dark rim sits under every white line.
	var edge := EDGE_OFFSET * _u
	for s in shown:
		draw_line(s[0] + edge, s[1] + edge, EDGE_COLOR, float(s[2]) + 1.6 * _u, true)
	for s in shown:
		if float(s[2]) >= GLOW_FROM_W * _u:
			draw_line(s[0], s[1], GLOW_COLOR, float(s[2]) * 2.6, true)
	for s in shown:
		draw_line(s[0], s[1], LINE_COLOR, float(s[2]), true)


func _draw_shards() -> void:
	var item := _shard_layer.get_canvas_item()
	for s in shards:
		if _reveal >= float(s.r):
			RenderingServer.canvas_item_add_triangle_array(item, s.indices, s.points, s.colors)
