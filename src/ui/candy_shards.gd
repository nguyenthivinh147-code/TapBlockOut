extends Control
## Mảnh kẹo: cắt khối thành mảnh lồi Voronoi, tô đúng chất liệu của khối bằng `candy_shard.gdshader`,
## mô phỏng trên CPU và vẽ chung một lệnh. Nằm trên mọi thứ (`top_level`) nên mảnh bay được ra ngoài bàn cờ.
## Dùng shatter() khi khối vỡ, chips() cho vụn văng ra lúc va chạm. Toạ độ vẽ là toạ độ canvas.

const SHADER := preload("res://src/ui/candy_shard.gdshader")
const Pudding := preload("res://src/ui/pudding.gd")

signal settled

const SHARD_BUDGET := 20  # mảnh lớn cho cả khối, để mỗi mảnh đủ to mà thấy sọc và mép kẹo
const CRUMBS_BASE := 8  # vụn nhỏ thêm vào cho dày
const CRUMBS_PER_CELL := 2
const HOLD := 0.05  # giây, mảnh còn nguyên chỗ để vết nứt loé trắng trước khi nổ
const SETTLE := 0.55  # giây sau khi vỡ thì báo xong; mảnh còn lại vẫn rơi tiếp
const GRAVITY := 26.0  # ô/giây²
const DRAG := 2.4  # mỗi giây
const SHATTER_SPEED := Vector2(7.0, 19.0)  # ô/giây
const SHATTER_LIFE := Vector2(0.6, 1.05)
const CHIP_SPEED := Vector2(2.5, 7.0)
const CHIP_LIFE := Vector2(0.35, 0.65)
const CHIP_SIZE := Vector2(0.06, 0.13)  # bán kính vụn, theo ô


class Shard extends RefCounted:
	var ring: PackedVector2Array  # các đỉnh tính từ tâm mảnh, px
	var pos: Vector2
	var vel: Vector2
	var rot: float = 0.0
	var spin: float = 0.0
	var phase: float = 0.0
	var life: float = 1.0
	var delay: float = 0.0
	var first: int = 0  # chỉ số đỉnh tâm trong mảng đỉnh


var _shards: Array[Shard] = []
var _points := PackedVector2Array()
var _colors := PackedColorArray()
var _uvs := PackedVector2Array()
var _indices := PackedInt32Array()
var _cell: float = 64.0
var _age: float = 0.0
var _hold: float = 0.0
var _settle_at: float = -1.0
var _longest: float = 0.0
var _invisible: bool = false
var _dims := Vector2.ONE


func _init() -> void:
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name = "Shards"


## Cắt các ô thành mảnh lồi (toạ độ ô). Ô ở phía `toward` có thêm mảnh để chỗ va chạm vỡ vụn hơn.
static func fracture(cells: Array, toward: Vector2, rng: RandomNumberGenerator) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var per_cell := clampi(roundi(float(SHARD_BUDGET) / float(cells.size())), 2, 6)
	var center := Vector2.ZERO
	for c: Vector2i in cells:
		center += Vector2(c) + Vector2(0.5, 0.5)
	center /= float(cells.size())
	for c: Vector2i in cells:
		var o := Vector2(c)
		var front := (o + Vector2(0.5, 0.5) - center).dot(toward) > 0.01
		var seeds := PackedVector2Array()
		for i in per_cell + (1 if front or cells.size() == 1 else 0):
			seeds.append(o + Vector2(rng.randf(), rng.randf()))
		for i in seeds.size():
			var poly := PackedVector2Array([o, o + Vector2(1, 0), o + Vector2(1, 1), o + Vector2(0, 1)])
			for j in seeds.size():
				if i != j and poly.size() >= 3:
					poly = _clip_half(poly, (seeds[i] + seeds[j]) * 0.5, seeds[i] - seeds[j])
			if poly.size() >= 3 and absf(_area(poly)) > 0.001:
				out.append(poly)
	return out


## Giữ phần đa giác nằm cùng phía `normal` so với đường qua `mid` (Sutherland-Hodgman).
static func _clip_half(poly: PackedVector2Array, mid: Vector2, normal: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var da := (a - mid).dot(normal)
		var db := (b - mid).dot(normal)
		if da >= 0.0:
			out.append(a)
		if (da >= 0.0) != (db >= 0.0):
			out.append(a.lerp(b, da / (da - db)))
	return out


static func _area(poly: PackedVector2Array) -> float:
	var s := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		s += a.x * b.y - b.x * a.y
	return s * 0.5


static func _centroid(poly: PackedVector2Array) -> Vector2:
	var s := Vector2.ZERO
	for p in poly:
		s += p
	return s / float(poly.size())


## Khối vỡ. `xf` là biến đổi toàn cục của khối, `impact` là điểm va (toạ độ canvas), `dir` là hướng lao tới.
## Trả về node đã thêm vào `parent`; `settled` báo khi phần chính đã xong.
static func shatter(parent: Node, polys: Array[PackedVector2Array], cells: Array, cell: float, ramp: Dictionary, xf: Transform2D, dir: Vector2, impact: Vector2, rng: RandomNumberGenerator) -> Control:
	var node: Control = new()
	node._setup_material(cells, cell, ramp)
	node._hold = HOLD
	node._settle_at = HOLD + SETTLE
	var perp := Vector2(-dir.y, dir.x)
	var center := xf * (_cells_center(cells) * cell)
	var reach := maxf(cell, (impact - center).length() * 2.0)
	for poly in polys:
		var world := xf * (_centroid(poly) * cell)
		# mảnh gần điểm va bay trước và nhanh hơn, tạo cảm giác vết vỡ lan ra từ chỗ đập
		var near := 1.0 - clampf((world - impact).length() / reach, 0.0, 1.0)
		var speed := rng.randf_range(SHATTER_SPEED.x, SHATTER_SPEED.y) * lerpf(0.75, 1.2, near) * cell
		var outward := (world - center).normalized() if world != center else dir
		var vel := dir * speed + outward * speed * 0.35 + perp * rng.randf_range(-0.42, 0.42) * speed
		var life := rng.randf_range(SHATTER_LIFE.x, SHATTER_LIFE.y)
		node._add_shard(poly, cell, xf, vel, life, (1.0 - near) * 0.05, rng)
	var at := xf.affine_inverse() * impact / cell
	for i in CRUMBS_BASE + CRUMBS_PER_CELL * cells.size():
		var poly := _chip_poly(at - dir * rng.randf_range(0.04, 0.5) + perp * rng.randf_range(-0.7, 0.7), rng.randf_range(CHIP_SIZE.x, CHIP_SIZE.y), rng)
		var speed := rng.randf_range(SHATTER_SPEED.x, SHATTER_SPEED.y) * 1.25 * cell
		var vel := dir * speed + perp * rng.randf_range(-0.6, 0.6) * speed
		node._add_shard(poly, cell, xf, vel, rng.randf_range(CHIP_LIFE.x, SHATTER_LIFE.x + 0.1), 0.0, rng)
	node._commit()
	parent.add_child(node)
	return node


## Vụn văng ra từ khối đang còn nguyên, gần điểm `at` (toạ độ ô của khối), bắn ngược lại hướng `dir` và toả sang hai bên.
static func chips(parent: Node, cells: Array, cell: float, ramp: Dictionary, xf: Transform2D, at: Vector2, dir: Vector2, amount: int, rng: RandomNumberGenerator) -> Control:
	var node: Control = new()
	node._setup_material(cells, cell, ramp)
	var perp := Vector2(-dir.y, dir.x)
	for i in amount:
		var pos := at - dir * rng.randf_range(0.04, 0.22) + perp * rng.randf_range(-0.3, 0.3)
		var poly := _chip_poly(pos, rng.randf_range(CHIP_SIZE.x, CHIP_SIZE.y), rng)
		var speed := rng.randf_range(CHIP_SPEED.x, CHIP_SPEED.y) * cell
		var vel := -dir * speed * rng.randf_range(0.25, 0.8) + perp * speed * rng.randf_range(-1.0, 1.0) + Vector2.UP * cell * rng.randf_range(0.5, 2.5)
		node._add_shard(poly, cell, xf, vel, rng.randf_range(CHIP_LIFE.x, CHIP_LIFE.y), 0.0, rng)
	node._commit()
	parent.add_child(node)
	return node


## Vẽ một lần vô hình để shader được biên dịch sẵn, tránh khung hình trống và giật ở lần vỡ đầu tiên.
static func prewarm(parent: Node, cell: float, ramp: Dictionary) -> void:
	var node: Control = new()
	var cells := [Vector2i.ZERO]
	node._setup_material(cells, cell, ramp)
	node._add_shard(PackedVector2Array([Vector2.ZERO, Vector2(1, 0), Vector2(0, 1)]), cell, Transform2D.IDENTITY, Vector2.ZERO, 0.05, 0.0, RandomNumberGenerator.new())
	node._invisible = true
	node._commit()
	parent.add_child(node)


## Miếng vụn lồi quanh `pos`, bán kính `r` (theo ô).
static func _chip_poly(pos: Vector2, r: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var poly := PackedVector2Array()
	var sides := rng.randi_range(3, 5)
	var start := rng.randf() * TAU
	for k in sides:
		var ang := start + TAU * float(k) / float(sides) + rng.randf_range(-0.3, 0.3)
		poly.append(pos + Vector2(cos(ang), sin(ang)) * r * rng.randf_range(0.7, 1.2))
	return poly


static func _cells_center(cells: Array) -> Vector2:
	var s := Vector2.ZERO
	for c: Vector2i in cells:
		s += Vector2(c) + Vector2(0.5, 0.5)
	return s / float(cells.size())


func _setup_material(cells: Array, cell: float, ramp: Dictionary) -> void:
	_cell = cell
	var m := ShaderMaterial.new()
	m.shader = SHADER
	var entry := Pudding.sdf_for(cells)
	_dims = entry["dims"]
	Pudding.apply_material(m, entry, cell, ramp)
	material = m


## Thêm một mảnh: quạt tam giác quanh tâm, UV lấy đúng chỗ của mảnh trên khối nên giữ nguyên sọc và mép.
func _add_shard(poly: PackedVector2Array, cell: float, xf: Transform2D, vel: Vector2, life: float, delay: float, rng: RandomNumberGenerator) -> void:
	var center := _centroid(poly)
	var s := Shard.new()
	s.pos = xf * (center * cell)
	s.vel = vel
	s.spin = rng.randf_range(5.0, 17.0) * (1.0 if rng.randf() < 0.5 else -1.0)
	s.phase = rng.randf() * TAU
	s.life = life
	s.delay = delay
	s.first = _points.size()
	_points.append(s.pos)
	_colors.append(Color(1, 0, 0, 1))
	_uvs.append((center + Vector2.ONE * Pudding.PAD) / _dims)
	var n := poly.size()
	for i in n:
		s.ring.append(xf.basis_xform((poly[i] - center) * cell))
		_points.append(s.pos + s.ring[i])
		_colors.append(Color(0, 0, 0, 1))
		_uvs.append((poly[i] + Vector2.ONE * Pudding.PAD) / _dims)
		_indices.append_array(PackedInt32Array([s.first, s.first + 1 + i, s.first + 1 + (i + 1) % n]))
	_shards.append(s)
	_longest = maxf(_longest, delay + life)


func _commit() -> void:
	_step(0.0)
	queue_redraw()


func shard_count() -> int:
	return _shards.size()


func _process(delta: float) -> void:
	_step(delta)
	queue_redraw()
	if _settle_at >= 0.0 and _age >= _settle_at:
		_settle_at = -1.0
		settled.emit()
	if _age >= _hold + _longest:
		queue_free()


func _step(delta: float) -> void:
	_age += delta
	var flash := 1.0 - clampf(_age / maxf(_hold, 0.001), 0.0, 1.0) if _hold > 0.0 else 0.0
	var live := _age - _hold
	var gravity := Vector2(0.0, GRAVITY * _cell)
	var drag := exp(-DRAG * delta)
	for s: Shard in _shards:
		var t := (live - s.delay) / s.life
		var moving := t > 0.0
		if moving and delta > 0.0:
			s.vel = s.vel * drag + gravity * delta
			s.pos += s.vel * delta
			s.rot += s.spin * delta
		var k := clampf(t, 0.0, 1.0)
		var alpha := 0.0 if _invisible else 1.0 - smoothstep(0.62, 1.0, k)
		var size := 1.0 - 0.45 * smoothstep(0.55, 1.0, k)
		var glint := pow(maxf(0.0, sin(s.rot * 1.3 + s.phase)), 16.0) if moving else 0.0
		var cs := cos(s.rot) * size
		var sn := sin(s.rot) * size
		# mảnh chưa bay thì vết nứt vẫn sáng, không hở nền ra giữa các mảnh còn khít nhau
		var crack := flash if moving else maxf(flash, 0.3)
		_points[s.first] = s.pos
		_colors[s.first] = Color(1.0, glint, crack, alpha)
		for i in s.ring.size():
			var r := s.ring[i]
			_points[s.first + 1 + i] = s.pos + Vector2(r.x * cs - r.y * sn, r.x * sn + r.y * cs)
			_colors[s.first + 1 + i] = Color(0.0, glint, crack, alpha)


func _draw() -> void:
	if _indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _indices, _points, _colors, _uvs)
