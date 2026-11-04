extends Control
## Mảnh crystal bay về chip đếm mảnh: icon khối crystal (`lb_piece`) bật ra ở tâm khối vừa rời bàn, loé trắng, tia bảy
## sắc xoay, vòng sóng, sao bốn cánh lớn loé ở góc, kim tuyến và mảnh kính nổ; đứng một nhịp rồi bay vòng cung về icon
## chip, kéo đuôi lăng kính và kim tuyến rơi. Chạm chip thì icon chip nảy dẻo và loé, sao bốn cánh lớn quay, hai vòng
## sóng, tia bảy sắc toả, kim tuyến nổ, rồi gọi `on_land` để số trên chip tăng.
## Gọn: icon tới chip sau 0,7 giây, tắt hẳn sau 1,2 giây, chỉ sáng quanh hai đầu đường bay.
## Hai lớp: màu đậm vẽ trộn thường (nổi trên nền sáng của thanh trên), quầng và sao vẽ cộng sáng (rực trên bàn tối).
## Nằm trên lớp phủ (`top_level`, toạ độ canvas), không bắt chạm, tự xoá khi xong.

const BoardFx := preload("res://src/ui/board_fx.gd")
const ObstacleFx := preload("res://src/ui/obstacle_fx.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")

const POP := 0.18  # icon bật từ 0 lên cỡ to nhất
const HOLD := 0.08  # đứng lắc nhẹ cho người chơi kịp thấy
const FLY := 0.44
const AFTER := 0.5  # tia, vòng sóng ở chip tắt dần sau khi chạm
const ICON_PX := 72.0  # cỡ icon lúc bật ra
const SPIN_IN := 0.7  # rad, icon xoay về thẳng lúc bật ra
const TRAIL := 0.34  # đuôi dài chừng này phần đường bay
const SEGMENTS := 22
const RAYS := 12
const EDGE := 40.0  # điểm điều khiển đường bay không ra sát mép màn hơn chừng này
const CORE := Color("F4FDFF")
const ICE := Color("7FE6FF")
const ICE_DEEP := Color("1FA8FF")
const PINK := Color("FF9BE8")
const MAGENTA := Color("F23FC0")
const PRISM_GLOW := 0.42  # độ đậm bảy sắc ở lớp cộng sáng
const PRISM_TINT := 0.78  # độ đậm bảy sắc ở lớp màu đậm

var on_land: Callable = Callable()
## Gọi một lần lúc icon rời chỗ bật ra để bay (tiếng chuông nhặt lên dần, đỉnh rơi đúng lúc chạm chip).
var on_launch: Callable = Callable()
var _tex: Texture2D = null
var _star: Texture2D = null
var _add: CanvasItemMaterial = null
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _target: Control = null
var _p: Array[Vector2] = []  # 4 điểm Bézier của đường bay
var _t: float = 0.0
var _launched: bool = false
var _landed_at: float = -1.0  # < 0 là chưa chạm chip
var _end_px: float = 40.0  # cỡ icon chip
var _glow: Control = null  # quầng, tia trắng, sao: cộng sáng, nằm trên lớp màu đậm của chính node này
var _dust: CPUParticles2D = null
var _solid: Control = null  # icon màu thường
var _shine: Control = null  # loé trắng cộng sáng đè lên icon


func _init() -> void:
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add = CanvasItemMaterial.new()
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_tex = ThemeKit.icon("lb_piece")
	_star = BoardFx.sparkle_texture()
	_glow = _layer("Glow", _draw_glow, _add)
	_dust = _make_dust()
	add_child(_dust)
	_solid = _layer("Icon", _draw_icon, null)
	_shine = _layer("Shine", _draw_shine, _add)


func _layer(layer_name: String, draw_fn: Callable, mat: Material) -> Control:
	var c := Control.new()
	c.name = layer_name
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.material = mat
	c.draw.connect(draw_fn)
	add_child(c)
	return c


## `from` là tâm khối (toạ độ canvas), `target` là icon trên chip đếm. Gọi sau khi đã add_child.
func start(from: Vector2, target: Control, land: Callable = Callable()) -> void:
	on_land = land
	global_position = Vector2.ZERO
	_from = from
	_target = target
	var r := target.get_global_rect()
	_to = r.get_center()
	if r.size.x > 4.0:
		_end_px = r.size.x
	var vp := get_viewport_rect()
	var d := _to - _from
	# vọt lên, ngả ra xa chip một chút rồi lượn vào chip từ phía dưới
	var p1 := _from + Vector2(-d.x * 0.35, -minf(140.0, absf(d.y) * 0.3 + 60.0))
	var p2 := _to + Vector2(-d.x * 0.12, clampf(-d.y * 0.4, 60.0, 260.0))
	p1.x = clampf(p1.x, vp.position.x + EDGE, vp.end.x - EDGE)
	p2.x = clampf(p2.x, vp.position.x + EDGE, vp.end.x - EDGE)
	_p = [_from, p1, p2, _to]
	_dust.position = _from
	add_child(_make_burst(_from, 16, 0.75, _star, null))
	add_child(_make_burst(_from, 8, 0.6, ObstacleFx.texture("gem"), _add))
	BoardFx.impact_flash(self, _from, ICE, 230.0, 0.34, 1.0)


func _process(delta: float) -> void:
	if _p.is_empty():
		return
	_t += delta
	var f := _t - POP - HOLD
	if _landed_at < 0.0:
		if f >= 0.0:
			if not _launched:
				_launched = true
				_dust.emitting = true
				if on_launch.is_valid():
					on_launch.call()
			_dust.position = _bez(_fly_s(f))
		if f >= FLY:
			_land()
	elif _t > _landed_at + AFTER:
		queue_free()
	queue_redraw()
	_glow.queue_redraw()
	_solid.queue_redraw()
	_shine.queue_redraw()


func _land() -> void:
	_landed_at = _t
	_dust.emitting = false
	BoardFx.impact_flash(self, _to, ICE, 280.0, 0.42, 1.0)
	add_child(_make_burst(_to, 26, 1.0, _star, null))
	add_child(_make_burst(_to, 10, 0.8, ObstacleFx.texture("gem"), _add))
	_punch(_target)
	if on_land.is_valid():
		on_land.call()


## Icon chip nảy dẻo, nghiêng, loé sáng rồi về như cũ.
func _punch(node: Control) -> void:
	if not is_instance_valid(node):
		return
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(1.6, 1.6)
	node.rotation = -0.22
	node.modulate = Color(2.2, 2.2, 2.2)
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate", Color.WHITE, 0.35)


## Icon đang ở đâu, to bao nhiêu (px), xoay bao nhiêu, loé trắng bao nhiêu (0..1). Đã chạm chip thì cỡ 0.
func _icon_state() -> Dictionary:
	if _landed_at >= 0.0:
		return {"at": _to, "px": 0.0, "rot": 0.0, "flash": 0.0}
	if _t < POP:
		var u := _t / POP
		return {"at": _from, "px": ICON_PX * _back(u), "rot": -SPIN_IN * (1.0 - u) * (1.0 - u), "flash": 1.0 - 0.4 * u}
	var f := _t - POP - HOLD
	if f < 0.0:
		var h := (_t - POP) / HOLD
		return {"at": _from, "px": ICON_PX * (1.0 + 0.05 * sin(h * PI)), "rot": 0.08 * sin(h * TAU), "flash": 0.6 * (1.0 - h)}
	var s := _fly_s(f)
	return {"at": _bez(s), "px": lerpf(ICON_PX, _end_px, s * s), "rot": 0.3 * sin(f * 16.0) * (1.0 - s), "flash": 0.0}


## Nở quá đà rồi về (ease out back).
func _back(u: float) -> float:
	var v := u - 1.0
	return 1.0 + 2.70158 * v * v * v + 1.70158 * v * v


## Tiến độ bay đã nắn: rời chỗ êm, tăng tốc rồi lao vào chip.
func _fly_s(f: float) -> float:
	var u := clampf(f / FLY, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u) * 0.4 + u * u * 0.6


func _bez(s: float) -> Vector2:
	var m := 1.0 - s
	return _p[0] * m * m * m + _p[1] * 3.0 * m * m * s + _p[2] * 3.0 * m * s * s + _p[3] * s * s * s


static func _prism(k: float, sat: float, a: float) -> Color:
	return Color.from_hsv(fposmod(k, 1.0), sat, 1.0, a)


# --- lớp màu đậm (trộn thường): tia bảy sắc, vòng sóng, đuôi lăng kính ---

func _draw() -> void:
	if _p.is_empty():
		return
	var lead := _t - POP - HOLD
	if lead < 0.25:
		var grow := clampf(_t / POP, 0.0, 1.0)
		var fade := clampf(1.0 - (_t - POP) / (HOLD + 0.25), 0.0, 1.0)
		_draw_rays(self, _from, ICON_PX * 0.4, ICON_PX * (0.6 + 1.5 * grow), 5.0, -_t * 1.8, PRISM_TINT, 0.6 * fade, _t)
		_draw_ring(_from, clampf(_t / 0.36, 0.0, 1.0), 16.0, 100.0, ICE_DEEP, 6.0)
	if lead >= 0.0 and _landed_at < 0.0:
		var head := _fly_s(lead)
		var tail := maxf(0.0, head - TRAIL)
		if head - tail > 0.002:
			_draw_trail(self, tail, head, 30.0, PRISM_TINT, 0.7)
	if _landed_at >= 0.0:
		var a := _t - _landed_at
		var p := clampf(a / AFTER, 0.0, 1.0)
		var grow := 1.0 - pow(1.0 - p, 3.0)
		_draw_rays(self, _to, 18.0, 46.0 + 130.0 * grow, 5.0, -a * 1.2, PRISM_TINT, 0.75 * (1.0 - p) * (1.0 - p), a)
		for r in 2:
			_draw_ring(_to, clampf((a - r * 0.09) / (AFTER * 0.7), 0.0, 1.0), 18.0, 120.0, ICE_DEEP if r == 0 else MAGENTA, 7.0)


## Vòng sóng nở từ `at`: `q` 0..1, bán kính từ `r0` tới `r0 + reach`, mảnh dần và mờ dần.
func _draw_ring(at: Vector2, q: float, r0: float, reach: float, col: Color, width: float) -> void:
	if q <= 0.0 or q >= 1.0:
		return
	var rad := r0 + reach * (1.0 - pow(1.0 - q, 2.5))
	draw_arc(at, rad, 0.0, TAU, 56, Color(col, 0.9 * (1.0 - q)), maxf(1.0, width * (1.0 - q)), true)


# --- lớp cộng sáng: quầng, tia trắng, đuôi lõi, sao bốn cánh ---

func _draw_glow() -> void:
	if _p.is_empty():
		return
	var lead := _t - POP - HOLD
	if lead < 0.25:
		var grow := clampf(_t / POP, 0.0, 1.0)
		var fade := clampf(1.0 - (_t - POP) / (HOLD + 0.25), 0.0, 1.0)
		_glow.draw_circle(_from, ICON_PX * (0.6 + 0.5 * grow), Color(ICE, 0.22 * fade))
		_draw_rays(_glow, _from, ICON_PX * 0.3, ICON_PX * (0.5 + 1.2 * grow), 7.0, _t * 2.4, PRISM_GLOW, 0.8 * fade, _t)
		var q := clampf(_t / 0.36, 0.0, 1.0)
		if q < 1.0:
			_glow.draw_arc(_from, 16.0 + 90.0 * (1.0 - pow(1.0 - q, 2.5)), 0.0, TAU, 48, Color(CORE, 0.9 * (1.0 - q)), maxf(1.0, 8.0 * (1.0 - q)), true)
		var flare := clampf(1.0 - absf(_t - POP * 0.9) / 0.16, 0.0, 1.0)
		_draw_star(_glow, _from + Vector2(-ICON_PX, -ICON_PX) * 0.3, 130.0 * flare, _t * 3.0, CORE)
	if lead >= 0.0 and _landed_at < 0.0:
		var head := _fly_s(lead)
		var tail := maxf(0.0, head - TRAIL)
		if head - tail > 0.002:
			_draw_trail(_glow, tail, head, 12.0, 0.0, 0.95)
		var st := _icon_state()
		_glow.draw_circle(st.at, float(st.px) * 0.75, Color(ICE, 0.18))
		_draw_star(_glow, st.at, float(st.px) * (1.5 + 0.25 * sin(_t * 38.0)), _t * 5.0, CORE)
	if _landed_at >= 0.0:
		var a := _t - _landed_at
		var p := clampf(a / AFTER, 0.0, 1.0)
		var fade := (1.0 - p) * (1.0 - p)
		var grow := 1.0 - pow(1.0 - p, 3.0)
		_glow.draw_circle(_to, 30.0 + 40.0 * grow, Color(CORE, 0.45 * fade))
		_draw_rays(_glow, _to, 14.0, 40.0 + 110.0 * grow, 6.0, a * 1.4, PRISM_GLOW, 0.85 * fade, a + 0.5)
		_draw_star(_glow, _to, 190.0 * fade, -a * 4.0, CORE)
		_draw_star(_glow, _to, 120.0 * (1.0 - p), PI * 0.25 + a * 3.0, Color(PINK, 0.8))


## Tia nhọn toả quanh `at` từ bán kính `inner` tới `reach` (tia lẻ ngắn hơn), màu bảy sắc trôi theo `hue`.
func _draw_rays(ci: CanvasItem, at: Vector2, inner: float, reach: float, half_w: float, spin: float, sat: float, alpha: float, hue: float) -> void:
	if alpha <= 0.0:
		return
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for i in RAYS:
		var dir := Vector2.from_angle(TAU * i / RAYS + spin)
		var side := Vector2(-dir.y, dir.x) * half_w
		var base := at + dir * inner
		var c := _prism(float(i) / RAYS + hue * 0.5, sat, alpha)
		var b := verts.size()
		verts.append_array(PackedVector2Array([base - side, base + side, at + dir * reach * (1.0 if i % 2 == 0 else 0.62)]))
		cols.append_array(PackedColorArray([c, c, Color(c, 0.0)]))
		idx.append_array(PackedInt32Array([b, b + 1, b + 2]))
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, verts, cols)


## Đuôi thon từ `s0` (mờ, nhỏ) tới `s1` (rộng `width`); `sat` > 0 thì màu bảy sắc trôi dọc đuôi, 0 thì lõi trắng xanh.
func _draw_trail(ci: CanvasItem, s0: float, s1: float, width: float, sat: float, alpha: float) -> void:
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var pts: Array[Vector2] = []
	for i in SEGMENTS + 1:
		pts.append(_bez(lerpf(s0, s1, float(i) / SEGMENTS)))
	for i in SEGMENTS + 1:
		var k := float(i) / SEGMENTS
		var tan := (pts[mini(i + 1, SEGMENTS)] - pts[maxi(i - 1, 0)]).normalized()
		var nor := Vector2(-tan.y, tan.x)
		var w := width * 0.5 * pow(k, 1.2)
		var a := alpha * pow(k, 0.8)
		var c := _prism(k * 0.8 - _t * 1.5, sat, a) if sat > 0.0 else Color(ICE.lerp(CORE, k), a)
		verts.append_array(PackedVector2Array([pts[i] - nor * w, pts[i], pts[i] + nor * w]))
		cols.append_array(PackedColorArray([Color(c, 0.0), c, Color(c, 0.0)]))
		if i < SEGMENTS:
			var b := i * 3
			for s in 2:
				idx.append_array(PackedInt32Array([b + s, b + s + 1, b + s + 3, b + s + 1, b + s + 4, b + s + 3]))
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, verts, cols)


func _draw_star(ci: CanvasItem, at: Vector2, px: float, rot: float, col: Color) -> void:
	if px <= 0.5:
		return
	ci.draw_set_transform(at, rot, Vector2.ONE)
	ci.draw_texture_rect(_star, Rect2(Vector2(-px, -px) * 0.5, Vector2(px, px)), false, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- icon ---

func _draw_icon() -> void:
	var st := _icon_state()
	var px := float(st.px)
	if px <= 0.5 or _tex == null:
		return
	_solid.draw_set_transform(st.at, float(st.rot), Vector2.ONE)
	_solid.draw_texture_rect(_tex, Rect2(Vector2(-px, -px) * 0.5, Vector2(px, px)), false)
	_solid.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Loé trắng đè lên icon lúc bật ra, và sao nhỏ nhấp nháy ở góc icon suốt lúc bay.
func _draw_shine() -> void:
	var st := _icon_state()
	var px := float(st.px)
	if px <= 0.5 or _tex == null:
		return
	var flash := float(st.flash)
	if flash > 0.0:
		_shine.draw_set_transform(st.at, float(st.rot), Vector2.ONE)
		_shine.draw_texture_rect(_tex, Rect2(Vector2(-px, -px) * 0.5, Vector2(px, px)), false, Color(1, 1, 1, flash))
		_shine.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var twinkle := pow(maxf(0.0, sin(_t * 22.0)), 3.0)
	_draw_star(_shine, st.at + Vector2(px * 0.24, -px * 0.26).rotated(float(st.rot)), px * 0.7 * twinkle, _t * 2.0, CORE)


# --- hạt ---

## Kim tuyến bảy sắc rơi lại dọc đường bay.
func _make_dust() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "CrystalDust"
	p.emitting = false
	p.amount = 36
	p.lifetime = 0.5
	p.randomness = 0.5
	p.texture = BoardFx.sparkle_texture()
	p.direction = Vector2.DOWN
	p.spread = 180.0
	p.gravity = Vector2(0.0, 260.0)
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 130.0
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.6
	p.scale_amount_curve = _twinkle_curve()
	_color(p, PRISM_TINT)
	return p


## Kim tuyến (sao bốn cánh) hoặc mảnh kính (`gem`) nổ tròn quanh `at`; `mat` null là trộn thường.
func _make_burst(at: Vector2, amount: int, strength: float, tex: Texture2D, mat: Material) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "CrystalBurst"
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.6
	p.explosiveness = 0.95
	p.randomness = 0.4
	p.texture = tex
	p.spread = 180.0
	p.gravity = Vector2(0.0, 520.0)
	p.initial_velocity_min = 150.0 * strength
	p.initial_velocity_max = 480.0 * strength
	p.damping_min = 260.0
	p.damping_max = 520.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -600.0
	p.angular_velocity_max = 600.0
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.8 * strength + 0.2
	p.scale_amount_curve = _twinkle_curve()
	_color(p, PRISM_GLOW if mat != null else PRISM_TINT)
	p.material = mat
	p.position = at
	p.finished.connect(p.queue_free)
	p.emitting = true
	return p


## Mỗi hạt một màu bảy sắc độ đậm `sat`, sáng lúc mới ra rồi mờ dần.
func _color(p: CPUParticles2D, sat: float) -> void:
	var hue := Gradient.new()
	hue.set_color(0, _prism(0.9, sat, 1.0))
	hue.set_color(1, _prism(0.52, sat, 1.0))
	hue.add_point(0.33, _prism(0.75, sat, 1.0))
	hue.add_point(0.66, _prism(0.15, sat, 1.0))
	p.color_initial_ramp = hue
	var life := Gradient.new()
	life.set_color(0, Color(1.5, 1.5, 1.5))
	life.set_color(1, Color(1, 1, 1, 0))
	life.add_point(0.4, Color.WHITE)
	p.color_ramp = life


## Nở nhanh, nhấp nháy một nhịp rồi tắt.
func _twinkle_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.3))
	c.add_point(Vector2(0.12, 1.0))
	c.add_point(Vector2(0.4, 0.5))
	c.add_point(Vector2(0.6, 0.9))
	c.add_point(Vector2(1.0, 0.0))
	return c
