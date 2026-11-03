extends Control
## Hiệu ứng booster Phá khối: búa kẹo mút bật ra giữa màn hình trên nền tia sáng xoay, đứng lấp lánh một nhịp,
## thu nhỏ bay tới khối đã chọn và nhấc lên, rồi vung xuống gõ (vệt quét và bóng mờ theo cán). Lúc gõ gọi `on_hit()`
## để bàn cho khối vỡ; kèm loé trắng toàn màn, quầng hồng, tia toả, hai vòng sóng, sao nổ và vòng sao choáng váng xoay
## trên chỗ gõ. Búa nảy ngược rồi mờ đi. Nằm trên lớp phủ toàn màn (`top_level`, toạ độ canvas), không bắt chạm, tự xoá.

const BoardFx := preload("res://src/ui/board_fx.gd")

const HAMMER_TEX := preload("res://assets/ui/fx_lollipop_hammer.png")
## Các điểm trên ảnh búa, theo phần cạnh ảnh: chỗ cầm (tâm xoay), tâm đầu búa, tâm mặt kẹo dưới-trái (mặt gõ).
const GRIP := Vector2(0.82, 0.82)
const HEAD := Vector2(0.375, 0.36)
const FACE := Vector2(0.19, 0.48)

const APPEAR := 0.24  # búa bật ra giữa màn
const HOLD := 0.12  # đứng lấp lánh
const FLY := 0.24  # thu nhỏ bay tới khối, nhấc búa
const SWING := 0.09  # vung xuống
const RECOIL := 0.34  # nảy ngược, mờ đi
const AFTER := 0.85  # vòng sóng, sao choáng váng tắt dần sau cú gõ
const CENTER_PX := 300.0  # cạnh ảnh búa lúc ở giữa màn (màn 720 px rộng)
const STRIKE_CELLS := 3.4  # cạnh ảnh búa lúc gõ, theo ô
const LIFT := 0.8  # rad, búa nhấc lên (đầu búa chỉ thẳng lên) trước khi vung
const STRIKE := -1.0  # rad, mặt kẹo chúc thẳng xuống khối
const GHOSTS := 3  # bóng mờ theo cú vung
const RAYS := 16
const DIZZY := 5  # sao vàng xoay vòng quanh chỗ gõ
const REF_CELL := 42.0
const PINK := Color("FF4FB2")
const GOLD := Color("FFD54A")
const CORE := Color("FFF4FB")
const STAR_FILL := Color("FFE04A")
const STAR_EDGE := Color("D9731A")

var on_hit: Callable = Callable()
var _center := Vector2.ZERO
var _target := Vector2.ZERO
var _unit: float = 1.0
var _strike_px: float = 140.0
var _t: float = 0.0
var _hit: bool = false
var _started: bool = false
var _tex: Texture2D = null
var _dust: CPUParticles2D = null
var _solid: Control = null  # búa và sao choáng váng vẽ màu đặc, nằm trên lớp cộng sáng


func _init() -> void:
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	_tex = BoardFx.sparkle_texture()
	_solid = Control.new()
	_solid.name = "Hammer"
	_solid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_solid.draw.connect(_draw_solid)
	add_child(_solid)


## `target` là điểm gõ (toạ độ canvas, tâm một ô của khối), `cell` là cỡ ô của bàn. Gọi sau khi đã add_child.
func start(target: Vector2, cell: float, hit: Callable = Callable()) -> void:
	on_hit = hit
	global_position = Vector2.ZERO
	_target = target
	_unit = cell / REF_CELL
	_strike_px = cell * STRIKE_CELLS
	var vp := get_viewport_rect()
	_center = vp.get_center()
	_started = true
	BoardFx.impact_flash(self, _center, PINK, CENTER_PX * 1.4, 0.4, 0.9)
	add_child(_make_burst(_center, 26, 1.0))
	_dust = _make_dust()
	add_child(_dust)


func _process(delta: float) -> void:
	if not _started:
		return
	_t += delta
	var fly0 := APPEAR + HOLD
	if _t >= fly0 and _t < _hit_at():
		_dust.emitting = true
		_dust.position = _head_pos()
	if _t >= _hit_at() and not _hit:
		_strike()
	if _t > _hit_at() + AFTER:
		queue_free()
	queue_redraw()
	_solid.queue_redraw()


func _hit_at() -> float:
	return APPEAR + HOLD + FLY + SWING


func _strike() -> void:
	_hit = true
	_dust.emitting = false
	BoardFx.impact_flash(self, _target, PINK, 420.0 * _unit, 0.5, 1.0)
	BoardFx.impact_flash(self, _target, GOLD, 220.0 * _unit, 0.3, 0.6)
	add_child(_make_burst(_target, 34, _unit))
	if on_hit.is_valid():
		on_hit.call()


# --- dáng búa theo thời gian ---

## Chỗ cầm (toạ độ canvas), góc xoay, cạnh ảnh (px) và độ sáng thêm ở thời điểm `t`.
func _pose(t: float) -> Dictionary:
	var big_grip := _center + (GRIP - Vector2(0.5, 0.5)) * CENTER_PX
	var lift_grip := _strike_grip()
	if t < APPEAR:
		var u := t / APPEAR
		var s := _back_out(u)
		return {"grip": _center + (big_grip - _center) * s, "rot": -0.7 * (1.0 - u) * (1.0 - u),
			"px": CENTER_PX * s, "glow": 0.9 * (1.0 - u) + 0.4}
	t -= APPEAR
	if t < HOLD:
		return {"grip": big_grip, "rot": 0.06 * sin(t * 40.0), "px": CENTER_PX, "glow": 0.4 * (1.0 - t / HOLD)}
	t -= HOLD
	if t < FLY:
		var u := t / FLY
		var e := u * u * (3.0 - 2.0 * u)
		var arc := Vector2(0.0, -90.0 * _unit * sin(u * PI))  # vồng lên khi bay
		return {"grip": big_grip.lerp(lift_grip, e) + arc, "rot": LIFT * e, "px": lerpf(CENTER_PX, _strike_px, e), "glow": 0.0}
	t -= FLY
	if t < SWING:
		var u := t / SWING
		return {"grip": lift_grip, "rot": lerpf(LIFT, STRIKE, u * u), "px": _strike_px, "glow": 0.0}
	t -= SWING
	var u := clampf(t / RECOIL, 0.0, 1.0)
	var bounce := sin(u * PI) * 0.35 * (1.0 - u)  # nảy ngược khỏi khối
	return {"grip": lift_grip + Vector2(0.0, -16.0 * _unit * sin(u * PI)), "rot": STRIKE + bounce,
		"px": _strike_px * (1.0 + 0.12 * sin(minf(u * 3.0, 1.0) * PI) - 0.35 * u * u), "glow": 0.8 * (1.0 - u)}


## Chỗ cầm sao cho lúc gõ, mặt kẹo nằm ngay trên tâm điểm gõ.
func _strike_grip() -> Vector2:
	var face := ((FACE - GRIP) * _strike_px).rotated(STRIKE)
	return _target - face - Vector2(0.0, 0.08 * _strike_px)


func _head_pos() -> Vector2:
	var p := _pose(_t)
	return p.grip + ((HEAD - GRIP) * float(p.px)).rotated(float(p.rot))


func _back_out(u: float) -> float:
	var c := 2.2
	var v := u - 1.0
	return 1.0 + (c + 1.0) * v * v * v + c * v * v


# --- vẽ cộng sáng: tia, quầng, vệt vung, vòng sóng ---

func _draw() -> void:
	if not _started:
		return
	var fly0 := APPEAR + HOLD
	if _t < fly0 + FLY * 0.6:
		var k := clampf(_t / APPEAR, 0.0, 1.0)
		var fade := 1.0 - clampf((_t - fly0) / (FLY * 0.6), 0.0, 1.0)
		var reach := CENTER_PX * (0.35 + 0.55 * sin(k * PI * 0.5)) * fade
		draw_circle(_center, CENTER_PX * 0.42 * k * fade, Color(PINK, 0.22 * fade))
		draw_circle(_center, CENTER_PX * 0.26 * k * fade, Color(CORE, 0.18 * fade))
		_rays(_center, reach, _t * 1.6, 0.7 * fade * k, 9.0)
		if _t < fly0:
			_twinkles(k)
	if _t >= fly0 and _t < _hit_at():
		var p := _pose(_t)
		draw_circle(_head_pos(), float(p.px) * 0.3, Color(PINK, 0.2))
	var swing0 := fly0 + FLY
	if _t >= swing0 and _t < _hit_at() + 0.12:
		_swoosh(clampf((_t - swing0) / SWING, 0.0, 1.0), 1.0 - clampf((_t - _hit_at()) / 0.12, 0.0, 1.0))
	if _hit:
		_draw_impact(_t - _hit_at())


## Tia toả xoay quanh `at`, xen kẽ hồng và vàng.
func _rays(at: Vector2, reach: float, spin: float, alpha: float, half_w: float) -> void:
	if alpha <= 0.0 or reach <= 1.0:
		return
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for i in RAYS:
		var ang := TAU * i / RAYS + spin
		var dir := Vector2(cos(ang), sin(ang))
		var side := Vector2(-dir.y, dir.x) * half_w * _unit
		var ray_len := reach * (1.0 if i % 2 == 0 else 0.65)
		var b := verts.size()
		verts.append_array(PackedVector2Array([at - side, at + side, at + dir * ray_len]))
		var c := Color(GOLD if i % 2 == 0 else PINK, alpha)
		cols.append_array(PackedColorArray([c, c, Color(c, 0.0)]))
		idx.append_array(PackedInt32Array([b, b + 1, b + 2]))
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, verts, cols)


## Sao lấp lánh nhấp nháy quanh búa lúc đứng giữa màn.
func _twinkles(k: float) -> void:
	for i in 6:
		var ang := TAU * i / 6.0 + 0.4
		var at := _center + Vector2(cos(ang), sin(ang)) * CENTER_PX * (0.44 + 0.08 * (i % 2))
		var tw := maxf(0.0, sin(_t * 26.0 + i * 1.7))
		_star(at, 44.0 * k * (0.4 + 0.8 * tw), _t * 3.0 + i, CORE)


## Vệt quét theo đường đầu búa trong lúc vung, sáng nhất ở đầu.
func _swoosh(u: float, fade: float) -> void:
	var p := _pose(minf(_t, _hit_at() - 0.0001))
	var grip: Vector2 = p.grip
	var radius := ((HEAD - GRIP) * _strike_px).length()
	var head0 := (HEAD - GRIP).angle() + LIFT
	var head1 := (HEAD - GRIP).angle() + lerpf(LIFT, STRIKE, u * u)
	if absf(head1 - head0) < 0.01:
		return
	var steps := 16
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var w := 0.32 * _strike_px
	for i in steps + 1:
		var k := float(i) / steps
		var ang := lerpf(head0, head1, k)
		var dir := Vector2(cos(ang), sin(ang))
		var c := Color(CORE.lerp(PINK, 1.0 - k), 0.75 * k * fade)
		verts.append_array(PackedVector2Array([grip + dir * (radius - w * k), grip + dir * (radius + w * 0.6 * k)]))
		cols.append_array(PackedColorArray([Color(c, 0.0), c]))
		if i < steps:
			var b := i * 2
			idx.append_array(PackedInt32Array([b, b + 1, b + 3, b, b + 3, b + 2]))
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, verts, cols)


## Sau cú gõ: loé trắng toàn màn, quầng, tia toả, hai vòng sóng.
func _draw_impact(a: float) -> void:
	var p := clampf(a / AFTER, 0.0, 1.0)
	var fade := (1.0 - p) * (1.0 - p)
	var grow := 1.0 - pow(1.0 - p, 3.0)
	if a < 0.14:
		draw_rect(get_viewport_rect(), Color(CORE, 0.38 * (1.0 - a / 0.14)))
	draw_circle(_target, (30.0 + 40.0 * grow) * _unit, Color(CORE, 0.45 * fade))
	_rays(_target, (60.0 + 200.0 * grow) * _unit, a * 1.4, 0.8 * fade, 7.0)
	for r in 2:
		var q := clampf((a - r * 0.08) / (AFTER * 0.55), 0.0, 1.0)
		if q <= 0.0 or q >= 1.0:
			continue
		var rad := (24.0 + 170.0 * (1.0 - pow(1.0 - q, 2.5))) * _unit
		draw_arc(_target, rad, 0.0, TAU, 56, Color(PINK if r == 0 else GOLD, 0.9 * (1.0 - q)), maxf(1.0, 12.0 * (1.0 - q) * _unit), true)


func _star(at: Vector2, px: float, rot: float, col: Color) -> void:
	draw_set_transform(at, rot, Vector2.ONE)
	draw_texture_rect(_tex, Rect2(Vector2(-px, -px) * 0.5, Vector2(px, px)), false, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- vẽ màu đặc: búa, bóng mờ, sao choáng váng ---

func _draw_solid() -> void:
	if not _started:
		return
	var swing0 := APPEAR + HOLD + FLY
	var end := _hit_at() + RECOIL
	if _t < end:
		if _t >= swing0 and _t < _hit_at() + 0.06:
			for g in range(GHOSTS, 0, -1):
				var gt := maxf(swing0, _t - g * SWING * 0.3)
				_hammer(_pose(gt), 0.28 * (1.0 - float(g) / (GHOSTS + 1)))
		var alpha := 1.0 - clampf((_t - _hit_at() - RECOIL * 0.5) / (RECOIL * 0.5), 0.0, 1.0)
		_hammer(_pose(_t), alpha)
	if _hit:
		_dizzy(_t - _hit_at())


func _hammer(p: Dictionary, alpha: float) -> void:
	var px: float = p.px
	if px <= 1.0 or alpha <= 0.0:
		return
	var glow: float = p.glow
	var c := Color(1.0 + glow, 1.0 + glow, 1.0 + glow * 0.8, alpha)
	_solid.draw_set_transform(p.grip, float(p.rot), Vector2.ONE)
	_solid.draw_texture_rect(HAMMER_TEX, Rect2(-GRIP * px, Vector2(px, px)), false, c)
	_solid.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Vòng sao vàng xoay quanh trên chỗ gõ như nhân vật hoạt hình bị choáng: nở ra, xoay, thu lại rồi tắt.
func _dizzy(a: float) -> void:
	var p := clampf(a / AFTER, 0.0, 1.0)
	if p >= 1.0:
		return
	var grow := minf(1.0, p * 6.0)
	var shrink := 1.0 - smoothstep(0.6, 1.0, p)
	var rx := 46.0 * _unit * grow
	var ry := 14.0 * _unit * grow
	var mid := _target + Vector2(0.0, -22.0 * _unit)
	for i in DIZZY:
		var ang := TAU * i / DIZZY + a * 9.0
		var at := mid + Vector2(cos(ang) * rx, sin(ang) * ry)
		var depth := 0.75 + 0.25 * sin(ang)  # sao phía sau nhỏ hơn
		_solid_star(at, 11.5 * _unit * depth * shrink * (0.5 + 0.5 * grow), a * 6.0 + i)


func _solid_star(at: Vector2, r: float, rot: float) -> void:
	if r <= 0.3:
		return
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for k in 10:
		var ang := rot + TAU * k / 10.0 - PI * 0.5
		var rr := r if k % 2 == 0 else r * 0.48
		outer.append(at + Vector2(cos(ang), sin(ang)) * (rr + 2.2 * _unit))
		inner.append(at + Vector2(cos(ang), sin(ang)) * rr)
	_solid.draw_colored_polygon(outer, STAR_EDGE)
	_solid.draw_colored_polygon(inner, STAR_FILL)
	_solid.draw_circle(at + Vector2(-r * 0.2, -r * 0.25), r * 0.18, Color(1, 1, 1, 0.9))


# --- hạt ---

## Bụi sao rơi dọc đường búa bay.
func _make_dust() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "SmashDust"
	p.emitting = false
	p.amount = 32
	p.lifetime = 0.45
	p.randomness = 0.5
	p.texture = _tex
	p.direction = Vector2.DOWN
	p.spread = 180.0
	p.gravity = Vector2(0.0, 260.0)
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 110.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.7
	p.color_ramp = _ramp()
	p.material = material
	return p


## Sao nổ tròn: lúc búa bật ra và lúc gõ.
func _make_burst(at: Vector2, amount: int, strength: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "SmashBurst"
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.65
	p.explosiveness = 0.95
	p.randomness = 0.4
	p.texture = _tex
	p.spread = 180.0
	p.gravity = Vector2(0.0, 380.0 * strength)
	p.initial_velocity_min = 180.0 * strength
	p.initial_velocity_max = 620.0 * strength
	p.damping_min = 260.0 * strength
	p.damping_max = 560.0 * strength
	p.angular_velocity_min = -480.0
	p.angular_velocity_max = 480.0
	p.scale_amount_min = 0.35 * strength
	p.scale_amount_max = 1.1 * strength
	p.color_ramp = _ramp()
	p.material = material
	p.position = at
	p.emitting = true
	return p


func _ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, CORE)
	g.set_color(1, Color(PINK, 0.0))
	g.add_point(0.35, GOLD)
	return g
