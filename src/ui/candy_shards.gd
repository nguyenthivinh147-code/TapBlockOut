extends Control
## Mảnh kẹo: miếng nhỏ có bề dày, tô đúng chất liệu của khối bằng `candy_shard.gdshader`,
## mô phỏng trên CPU và vẽ chung một lệnh. Nằm trên mọi thứ (`top_level`) nên mảnh bay được ra ngoài bàn cờ.
## Dùng grinder() + bit() cho khối bị nghiền khi trôi qua thanh, chips() cho vụn văng ra lúc va chạm. Toạ độ vẽ là toạ độ canvas.

const SHADER := preload("res://src/ui/candy_shard.gdshader")
const Pudding := preload("res://src/ui/pudding.gd")

const GRAVITY := 26.0  # ô/giây², vụn va chạm
const DRAG := 3.0  # mỗi giây
const CHIP_SPEED := Vector2(2.0, 5.0)  # ô/giây
const CHIP_LIFE := Vector2(0.3, 0.5)
const CHIP_SIZE := Vector2(0.06, 0.13)  # bán kính vụn, theo ô
const BIT_SIZE := Vector2(0.11, 0.17)  # nửa đường chéo khối vuông nhỏ bị nghiền, theo ô
const BIT_SPEED := Vector2(3.5, 9.0)  # ô/giây, phun ra khỏi thanh
const BIT_SPREAD := 1.0  # tốc độ ngang tối đa, theo tốc độ phun
const BIT_LIFE := Vector2(0.75, 1.15)
const BIT_DRAG := 1.8  # mỗi giây, hãm nhẹ hơn vụn va chạm để bay xa khoảng 1,5–4,5 ô
const BIT_GRAVITY := 3.0  # ô/giây², trôi nhẹ chứ không rơi
const BIT_DEPTH := 0.8  # bề dày theo bán kính, gần như khối lập phương
const BIT_SPIN := Vector2(3.0, 9.0)  # rad/giây
const DEPTH := 0.16  # bề dày mảnh tối đa, theo ô
const DEPTH_RATIO := 0.55  # mảnh nhỏ thì mỏng theo: bề dày tối đa bằng chừng này lần bán kính mảnh
const DEPTH_GROW := 0.08  # giây, bề dày hiện dần khi mảnh vừa ra
const SIDE_UV := 4.0  # mặt bên có UV.x lệch chừng này, khớp SIDE_FLAG trong candy_shard.gdshader
const SHADE_DIR := Vector2(0.6, 0.8)  # mặt bên quay về phía này tối nhất, ánh sáng từ trên trái


class Shard extends RefCounted:
	var ring: PackedVector2Array  # các đỉnh tính từ tâm mảnh, px
	var pos: Vector2
	var vel: Vector2
	var rot: float = 0.0
	var spin: float = 0.0
	var phase: float = 0.0
	var life: float = 1.0
	var born: float = 0.0  # giây, tính từ lúc tạo node
	var depth: float = 0.0  # px
	var first: int = 0  # chỉ số đỉnh tâm trong mảng đỉnh
	var side_first: int = 0  # đỉnh đầu của các mặt bên, 4 đỉnh mỗi cạnh


var _shards: Array[Shard] = []
var _points := PackedVector2Array()
var _colors := PackedColorArray()
var _uvs := PackedVector2Array()
var _indices := PackedInt32Array()
var _cell: float = 64.0
var _age: float = 0.0
var _longest: float = 0.0
var _gravity: float = GRAVITY
var _drag: float = DRAG
var _open: bool = false  # còn nhận mảnh mới thì chưa tự xoá
var _invisible: bool = false
var _dims := Vector2.ONE


func _init() -> void:
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name = "Shards"


static func _centroid(poly: PackedVector2Array) -> Vector2:
	var s := Vector2.ZERO
	for p in poly:
		s += p
	return s / float(poly.size())


## Nơi chứa khối vuông nhỏ của một khối đang bị nghiền: thêm dần bằng bit(), gọi close() khi khối đã qua hết thanh.
static func grinder(parent: Node, cells: Array, cell: float, ramp: Dictionary) -> Control:
	var node: Control = new()
	node._setup_material(cells, cell, ramp)
	node._gravity = BIT_GRAVITY
	node._drag = BIT_DRAG
	node._open = true
	parent.add_child(node)
	return node


## Một khối vuông nhỏ phun ra ở `pos` (toạ độ canvas) theo hướng `dir`; màu lấy ở điểm `at` (toạ độ ô của khối).
func bit(at: Vector2, pos: Vector2, dir: Vector2, rng: RandomNumberGenerator) -> void:
	var r := rng.randf_range(BIT_SIZE.x, BIT_SIZE.y)
	var poly := PackedVector2Array()
	var start := rng.randf() * TAU
	for k in 4:
		var ang := start + TAU * float(k) / 4.0 + rng.randf_range(-0.12, 0.12)
		poly.append(at + Vector2(cos(ang), sin(ang)) * r)
	var perp := Vector2(-dir.y, dir.x)
	var speed := rng.randf_range(BIT_SPEED.x, BIT_SPEED.y) * _cell
	var vel := dir * speed + perp * speed * rng.randf_range(-BIT_SPREAD, BIT_SPREAD)
	var xf := Transform2D(0.0, pos - _centroid(poly) * _cell)
	_add_shard(poly, _cell, xf, vel, rng.randf_range(BIT_LIFE.x, BIT_LIFE.y), rng)
	var s := _shards[-1]
	s.depth = r * _cell * BIT_DEPTH
	s.spin = rng.randf_range(BIT_SPIN.x, BIT_SPIN.y) * signf(s.spin)
	_step(0.0)
	queue_redraw()


func close() -> void:
	_open = false


## Vụn văng ra từ khối đang còn nguyên, gần điểm `at` (toạ độ ô của khối), bắn ngược lại hướng `dir` và toả sang hai bên.
static func chips(parent: Node, cells: Array, cell: float, ramp: Dictionary, xf: Transform2D, at: Vector2, dir: Vector2, amount: int, rng: RandomNumberGenerator) -> Control:
	var node: Control = new()
	node._setup_material(cells, cell, ramp)
	var perp := Vector2(-dir.y, dir.x)
	for i in amount:
		var pos := at - dir * rng.randf_range(0.04, 0.18) + perp * rng.randf_range(-0.22, 0.22)
		var poly := _chip_poly(pos, rng.randf_range(CHIP_SIZE.x, CHIP_SIZE.y), rng)
		var speed := rng.randf_range(CHIP_SPEED.x, CHIP_SPEED.y) * cell
		var vel := -dir * speed * rng.randf_range(0.25, 0.7) + perp * speed * rng.randf_range(-0.7, 0.7) + Vector2.UP * cell * rng.randf_range(0.4, 1.6)
		node._add_shard(poly, cell, xf, vel, rng.randf_range(CHIP_LIFE.x, CHIP_LIFE.y), rng)
	node._commit()
	parent.add_child(node)
	return node


## Vẽ một lần vô hình để shader được biên dịch sẵn, tránh khung hình trống và giật ở lần đầu tiên.
static func prewarm(parent: Node, cell: float, ramp: Dictionary) -> void:
	var node: Control = new()
	var cells := [Vector2i.ZERO]
	node._setup_material(cells, cell, ramp)
	node._add_shard(PackedVector2Array([Vector2.ZERO, Vector2(1, 0), Vector2(0, 1)]), cell, Transform2D.IDENTITY, Vector2.ZERO, 0.05, RandomNumberGenerator.new())
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


func _setup_material(cells: Array, cell: float, ramp: Dictionary) -> void:
	_cell = cell
	var m := ShaderMaterial.new()
	m.shader = SHADER
	var entry := Pudding.sdf_for(cells)
	_dims = entry["dims"]
	Pudding.apply_material(m, entry, cell, ramp)
	material = m


## Thêm một mảnh: quạt tam giác quanh tâm, UV lấy đúng chỗ của mảnh trên khối nên giữ nguyên sọc và mép.
## Mỗi cạnh có thêm một mặt bên (tứ giác đùn xuống) vẽ trước mặt trên, để mảnh có bề dày.
func _add_shard(poly: PackedVector2Array, cell: float, xf: Transform2D, vel: Vector2, life: float, rng: RandomNumberGenerator) -> void:
	var center := _centroid(poly)
	var s := Shard.new()
	s.pos = xf * (center * cell)
	s.vel = vel
	s.spin = rng.randf_range(5.0, 17.0) * (1.0 if rng.randf() < 0.5 else -1.0)
	s.rot = rng.randf() * TAU
	s.phase = rng.randf() * TAU
	s.life = life
	s.born = _age
	s.first = _points.size()
	_points.append(s.pos)
	_colors.append(Color(1, 0, 0, 1))
	_uvs.append((center + Vector2.ONE * Pudding.PAD) / _dims)
	var n := poly.size()
	var uv := PackedVector2Array()
	var radius := 0.0
	for i in n:
		s.ring.append(xf.basis_xform((poly[i] - center) * cell))
		uv.append((poly[i] + Vector2.ONE * Pudding.PAD) / _dims)
		radius = maxf(radius, s.ring[i].length())
		_points.append(s.pos + s.ring[i])
		_colors.append(Color(0, 0, 0, 1))
		_uvs.append(uv[i])
	s.depth = minf(DEPTH * cell, radius * DEPTH_RATIO)
	s.side_first = _points.size()
	for i in n:
		var j := (i + 1) % n
		for v: Vector2 in [uv[i], uv[j], uv[j], uv[i]]:
			_points.append(s.pos)
			_colors.append(Color(0, 0, 0, 0))
			_uvs.append(v + Vector2(SIDE_UV, 0.0))
		var b := s.side_first + i * 4
		_indices.append_array(PackedInt32Array([b, b + 1, b + 2, b, b + 2, b + 3]))
	for i in n:
		_indices.append_array(PackedInt32Array([s.first, s.first + 1 + i, s.first + 1 + (i + 1) % n]))
	_shards.append(s)
	_longest = maxf(_longest, s.born + life)


func _commit() -> void:
	_step(0.0)
	queue_redraw()


func shard_count() -> int:
	return _shards.size()


func _process(delta: float) -> void:
	_step(delta)
	queue_redraw()
	if not _open and _age >= _longest:
		queue_free()


func _step(delta: float) -> void:
	_age += delta
	var gravity := Vector2(0.0, _gravity * _cell)
	var drag := exp(-_drag * delta)
	for s: Shard in _shards:
		var live := _age - s.born
		if delta > 0.0:
			s.vel = s.vel * drag + gravity * delta
			s.pos += s.vel * delta
			s.rot += s.spin * delta
		var k := clampf(live / s.life, 0.0, 1.0)
		var alpha := 0.0 if _invisible else 1.0 - smoothstep(0.62, 1.0, k)
		var grow := clampf(live / DEPTH_GROW, 0.0, 1.0)
		var size := 1.0 - 0.45 * smoothstep(0.55, 1.0, k)
		var glint := pow(maxf(0.0, sin(s.rot * 1.3 + s.phase)), 16.0)
		var cs := cos(s.rot) * size
		var sn := sin(s.rot) * size
		_points[s.first] = s.pos
		_colors[s.first] = Color(1.0, glint, 0.0, alpha)
		var n := s.ring.size()
		for i in n:
			var r := s.ring[i]
			_points[s.first + 1 + i] = s.pos + Vector2(r.x * cs - r.y * sn, r.x * sn + r.y * cs)
			_colors[s.first + 1 + i] = Color(0.0, glint, 0.0, alpha)
		# bề dày đùn xuống dưới, nghiêng và co giãn theo vòng xoay cho cảm giác mảnh lật trong không gian
		var tip := 0.6 * sin(s.rot * 0.5 + s.phase)
		var off := Vector2(sin(tip), cos(tip)) * s.depth * size * grow * (0.7 + 0.3 * cos(s.rot * 0.9 + s.phase))
		for i in n:
			var a := _points[s.first + 1 + i]
			var b := _points[s.first + 1 + (i + 1) % n]
			var nor := Vector2(b.y - a.y, a.x - b.x).normalized()
			if nor.dot((a + b) * 0.5 - s.pos) < 0.0:
				nor = -nor
			# chỉ mặt bên quay về phía đùn mới thấy; mặt quay vào trong nằm khuất sau mặt trên
			var side_a := alpha if nor.dot(off) > 0.0 else 0.0
			var shade := clampf(0.5 + 0.5 * nor.dot(SHADE_DIR), 0.0, 1.0)
			var q := s.side_first + i * 4
			_points[q] = a
			_points[q + 1] = b
			_points[q + 2] = b + off
			_points[q + 3] = a + off
			_colors[q] = Color(0.0, shade, 0.0, side_a)
			_colors[q + 1] = _colors[q]
			_colors[q + 2] = Color(1.0, shade, 0.0, side_a)
			_colors[q + 3] = _colors[q + 2]


func _draw() -> void:
	if _indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _indices, _points, _colors, _uvs)
