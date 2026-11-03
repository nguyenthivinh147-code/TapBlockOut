extends Control
## Hiệu ứng booster Gợi ý: sao nhóm sáng ở nút booster, bay theo đường cong tới khối được gợi ý, kéo vệt sáng thon,
## bụi sao và ba sao nhỏ xoay quanh; tới nơi thì loé sáng, toả tia, hai vòng sóng, nổ sao rồi gọi `on_arrive`.
## Nằm trên lớp phủ toàn màn (`top_level`, toạ độ canvas), không bắt chạm, tự xoá khi xong.

const BoardFx := preload("res://src/ui/board_fx.gd")

const CHARGE := 0.16  # sao nhóm lên ở nút trước khi bay
const FLY := 0.62
const TAIL_CATCH := 0.2  # đuôi rút vào khối sau khi sao chạm
const AFTER := 0.8  # tia và vòng sóng tắt dần sau khi chạm
const TRAIL := 0.45  # đuôi dài chừng này phần đường bay
const SEGMENTS := 30
const RAYS := 12
const SATELLITES := 3
const TRAIL_STARS := 8  # sao nhỏ lấp lánh dọc đuôi
const REF_CELL := 42.0  # cỡ ô ở 720×1280; mọi kích thước tính theo tỉ lệ ô / số này
const GOLD := Color("FFD54A")
const PINK := Color("FF7AC8")
const TRAIL_HEAD := Color("FFA41B")  # đuôi trộn màu thường (không cộng sáng) nên giữ được màu đậm
const TRAIL_TAIL := Color("F0288C")
const TRAIL_CORE := Color("FFE45C")
const CORE := Color("FFF8E1")

var on_arrive: Callable = Callable()
var _p: Array[Vector2] = []  # 4 điểm điều khiển Bézier, toạ độ canvas
var _unit: float = 1.0
var _t: float = 0.0
var _arrived: bool = false
var _spin: float = 0.0
var _dust: CPUParticles2D = null
var _tex: Texture2D = null
var _trail: Control = null  # lớp đuôi, vẽ sau đầu sao


func _init() -> void:
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	_tex = BoardFx.sparkle_texture()
	_trail = Control.new()
	_trail.name = "Trail"
	_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trail.show_behind_parent = true
	_trail.draw.connect(_draw_trails)
	add_child(_trail)


## `from`, `to` là toạ độ canvas (tâm nút, tâm khối); `cell` là cỡ ô của bàn. Gọi sau khi đã add_child.
func start(from: Vector2, to: Vector2, cell: float, arrive: Callable = Callable()) -> void:
	on_arrive = arrive
	_unit = cell / REF_CELL
	global_position = Vector2.ZERO
	var d := to - from
	var dist := d.length()
	var side := -1.0 if to.x >= from.x else 1.0  # vòng ra phía ngược hướng đích rồi lượn vào
	var perp := Vector2(-d.y, d.x).normalized() * side
	_p = [from, from + d * 0.18 + perp * dist * 0.2, from + d * 0.78 + perp * dist * 0.1, to]
	_spin = randf() * TAU
	BoardFx.impact_flash(self, from, GOLD, 260.0 * _unit, 0.32, 0.8)
	_dust = _make_dust()
	add_child(_dust)
	_dust.position = from


func _process(delta: float) -> void:
	if _p.is_empty():
		return
	_t += delta
	var f := _t - CHARGE
	if f >= 0.0 and not _arrived:
		_dust.emitting = true
		_dust.position = _head_pos()
		if f >= FLY:
			_arrive()
	if _t > CHARGE + FLY + maxf(AFTER, _dust.lifetime):
		queue_free()
	queue_redraw()
	_trail.queue_redraw()


func _arrive() -> void:
	_arrived = true
	_dust.emitting = false
	var to := _p[3]
	BoardFx.impact_flash(self, to, GOLD, 400.0 * _unit, 0.55, 1.0)
	add_child(_make_burst(to))
	if on_arrive.is_valid():
		on_arrive.call()


## Tiến độ bay đã nắn: rời nút gọn, lao nhanh, hãm nhẹ khi gần tới.
func _fly_s() -> float:
	var u := clampf((_t - CHARGE) / FLY, 0.0, 1.0)
	return lerpf(u, u * u * (3.0 - 2.0 * u), 0.6)


func _bez(s: float) -> Vector2:
	var m := 1.0 - s
	return _p[0] * m * m * m + _p[1] * 3.0 * m * m * s + _p[2] * 3.0 * m * s * s + _p[3] * s * s * s


func _head_pos() -> Vector2:
	return _bez(_fly_s())


func _draw() -> void:
	if _p.is_empty():
		return
	var f := _t - CHARGE
	if f < 0.0:
		_draw_charge(_t / CHARGE)
		return
	var after := f - FLY
	if after >= 0.0:
		_draw_impact(after)
	var span := _trail_span()
	if span.y - span.x > 0.002:
		_draw_trail_stars(span.x, span.y)
	if after < 0.0:
		_draw_head(_bez(span.y), 1.0, f)


## (đuôi, đầu) của vệt theo tiến độ đường bay; sau khi chạm thì đuôi rút vào khối.
func _trail_span() -> Vector2:
	var head := _fly_s()
	var after := _t - CHARGE - FLY
	if after >= 0.0:
		return Vector2(lerpf(1.0 - TRAIL, 1.0, clampf(after / TAIL_CATCH, 0.0, 1.0)), head)
	return Vector2(maxf(0.0, head - TRAIL), head)


func _draw_trails() -> void:
	if _p.is_empty() or _t < CHARGE:
		return
	var span := _trail_span()
	if span.y - span.x > 0.002:
		_draw_trail(span.x, span.y, 28.0 * _unit, TRAIL_HEAD, TRAIL_TAIL)
		_draw_trail(span.x, span.y, 8.0 * _unit, TRAIL_CORE, TRAIL_HEAD)


## Sao nở ra ở nút booster, xoay, kèm vòng sáng thu vào.
func _draw_charge(k: float) -> void:
	var at := _p[0]
	var grow := sin(k * PI * 0.5)
	var ring := (1.0 - k) * 90.0 * _unit + 24.0 * _unit
	draw_arc(at, ring, 0.0, TAU, 40, Color(GOLD, 0.8 * k), 5.0 * _unit)
	_draw_head(at, grow * 1.25, _t)


func _draw_head(at: Vector2, k: float, time: float) -> void:
	if k <= 0.0:
		return
	var u := _unit * k
	draw_circle(at, 60.0 * u, Color(GOLD, 0.08))
	draw_circle(at, 30.0 * u, Color(GOLD, 0.2))
	draw_circle(at, 12.0 * u, Color(CORE, 0.95))
	var twinkle := 1.0 + 0.18 * sin(time * 38.0)
	_spikes(at, 78.0 * u * twinkle, 5.0 * u, _spin + time * 2.0, CORE)
	_spikes(at, 44.0 * u, 4.0 * u, _spin + PI * 0.25 + time * 2.0, GOLD)
	_star(at, 170.0 * u * twinkle, _spin + time * 4.0, CORE)
	_star(at, 110.0 * u, _spin + PI * 0.25 - time * 3.0, GOLD)
	_star(at, 64.0 * u, _spin + time * 7.0, PINK)
	for i in SATELLITES:
		var a := time * TAU * 1.6 + TAU * i / SATELLITES
		var off := Vector2(cos(a), sin(a) * 0.62) * 50.0 * u
		_star(at + off, 38.0 * u * (0.8 + 0.2 * sin(time * 30.0 + i)), -time * 6.0, GOLD if i % 2 == 0 else PINK)


## Bốn cánh loé thon nhọn (dài `reach`, gốc rộng `width`) quanh `at`.
func _spikes(at: Vector2, reach: float, width: float, rot: float, col: Color) -> void:
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for i in 4:
		var dir := Vector2.from_angle(rot + PI * 0.5 * i)
		var side := Vector2(-dir.y, dir.x) * width
		var b := verts.size()
		verts.append_array(PackedVector2Array([at - side, at + side, at + dir * reach]))
		cols.append_array(PackedColorArray([col, col, Color(col, 0.0)]))
		idx.append_array(PackedInt32Array([b, b + 1, b + 2]))
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, verts, cols)


func _star(at: Vector2, px: float, rot: float, col: Color) -> void:
	draw_set_transform(at, rot, Vector2.ONE)
	draw_texture_rect(_tex, Rect2(Vector2(-px, -px) * 0.5, Vector2(px, px)), false, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Sao nhỏ lấp lánh lượn hai bên đuôi, to dần về phía đầu.
func _draw_trail_stars(s0: float, s1: float) -> void:
	for j in TRAIL_STARS:
		var k := (float(j) + 0.5) / TRAIL_STARS
		var u := lerpf(s0, s1, k)
		var t := (_bez(minf(u + 0.01, 1.0)) - _bez(maxf(u - 0.01, 0.0))).normalized()
		var off := Vector2(-t.y, t.x) * sin(float(j) * 2.3 + _t * 14.0) * 12.0 * _unit * k
		var blink := 0.55 + 0.45 * sin(_t * 32.0 + float(j) * 1.7)
		_star(_bez(u) + off, (8.0 + 16.0 * k) * _unit * blink, _t * 7.0 + j, GOLD if j % 2 == 0 else PINK)


## Dải sáng thon từ `s0` (đuôi, mờ, nhỏ) tới `s1` (đầu, rộng `width`); mép ngoài mờ về 0.
func _draw_trail(s0: float, s1: float, width: float, head_col: Color, tail_col: Color) -> void:
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var pts: Array[Vector2] = []
	for i in SEGMENTS + 1:
		pts.append(_bez(lerpf(s0, s1, float(i) / SEGMENTS)))
	for i in SEGMENTS + 1:
		var k := float(i) / SEGMENTS
		var t := (pts[mini(i + 1, SEGMENTS)] - pts[maxi(i - 1, 0)]).normalized()
		var nor := Vector2(-t.y, t.x)
		var w := width * 0.5 * pow(k, 1.1)
		var c := tail_col.lerp(head_col, k)
		c.a = head_col.a * pow(k, 0.5)
		verts.append_array(PackedVector2Array([pts[i] - nor * w, pts[i], pts[i] + nor * w]))
		cols.append_array(PackedColorArray([Color(c, 0.0), c, Color(c, 0.0)]))
		if i < SEGMENTS:
			var b := i * 3
			for s in 2:
				idx.append_array(PackedInt32Array([b + s, b + s + 1, b + s + 3, b + s + 1, b + s + 4, b + s + 3]))
	RenderingServer.canvas_item_add_triangle_array(_trail.get_canvas_item(), idx, verts, cols)


## Tại khối: quầng sáng, tia toả xoay chậm, hai vòng sóng nở ra.
func _draw_impact(a: float) -> void:
	var p := clampf(a / AFTER, 0.0, 1.0)
	var fade := (1.0 - p) * (1.0 - p)
	var grow := 1.0 - pow(1.0 - p, 3.0)
	var at := _p[3]
	draw_circle(at, (40.0 + 60.0 * grow) * _unit, Color(CORE, 0.45 * fade))
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for i in RAYS:
		var ang := _spin + TAU * i / RAYS + a * 0.9
		var dir := Vector2(cos(ang), sin(ang))
		var side := Vector2(-dir.y, dir.x) * 11.0 * _unit
		var reach := (60.0 + 220.0 * grow) * _unit * (1.0 if i % 2 == 0 else 0.62)
		var base := at + dir * 10.0 * _unit
		var b := verts.size()
		verts.append_array(PackedVector2Array([base - side, base + side, at + dir * reach]))
		var c := Color(GOLD if i % 2 == 0 else PINK, 0.75 * fade)
		cols.append_array(PackedColorArray([c, c, Color(c, 0.0)]))
		idx.append_array(PackedInt32Array([b, b + 1, b + 2]))
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, verts, cols)
	for r in 2:
		var q := clampf((a - r * 0.09) / (AFTER * 0.6), 0.0, 1.0)
		if q <= 0.0 or q >= 1.0:
			continue
		var rad := (20.0 + 170.0 * (1.0 - pow(1.0 - q, 2.5))) * _unit
		draw_arc(at, rad, 0.0, TAU, 56, Color(GOLD if r == 0 else PINK, 0.9 * (1.0 - q)), maxf(1.0, 12.0 * _unit * (1.0 - q)), true)


## Bụi sao rơi lại dọc đường bay.
func _make_dust() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "HintDust"
	p.emitting = false
	p.amount = 72
	p.lifetime = 0.65
	p.randomness = 0.5
	p.texture = _tex
	p.direction = Vector2.DOWN
	p.spread = 180.0
	p.gravity = Vector2(0.0, 220.0 * _unit)
	p.initial_velocity_min = 20.0 * _unit
	p.initial_velocity_max = 130.0 * _unit
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 0.3 * _unit
	p.scale_amount_max = 0.8 * _unit
	p.scale_amount_curve = _twinkle_curve()
	p.color_ramp = _ramp()
	p.material = material
	return p


## Sao nổ tròn quanh khối lúc chạm.
func _make_burst(at: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "HintBurst"
	p.one_shot = true
	p.amount = 44
	p.lifetime = 0.8
	p.explosiveness = 0.95
	p.randomness = 0.4
	p.texture = _tex
	p.spread = 180.0
	p.gravity = Vector2(0.0, 380.0 * _unit)
	p.initial_velocity_min = 180.0 * _unit
	p.initial_velocity_max = 680.0 * _unit
	p.damping_min = 240.0 * _unit
	p.damping_max = 520.0 * _unit
	p.angular_velocity_min = -480.0
	p.angular_velocity_max = 480.0
	p.scale_amount_min = 0.45 * _unit
	p.scale_amount_max = 1.2 * _unit
	p.scale_amount_curve = _twinkle_curve()
	p.color_ramp = _ramp()
	p.material = material
	p.position = at
	p.emitting = true
	return p


func _ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, CORE)
	g.set_color(1, Color(PINK, 0.0))
	g.add_point(0.4, GOLD)
	return g


## Nở nhanh, nhấp nháy một nhịp rồi tắt.
func _twinkle_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.3))
	c.add_point(Vector2(0.12, 1.0))
	c.add_point(Vector2(0.4, 0.55))
	c.add_point(Vector2(0.6, 0.85))
	c.add_point(Vector2(1.0, 0.0))
	return c
