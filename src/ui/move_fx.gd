extends Control
## Hiệu ứng booster +Move: nút nảy và nhóm sáng, rồi mỗi lượt là một dấu "+" kẹo vàng bay ra thành hình quạt, kéo vệt
## xanh-vàng và bụi sao, hội tụ về chip lượt trên thanh trên. Mỗi dấu chạm chip thì loé sáng, nổ sao, chip nảy dẻo và gọi
## `on_tick(phần)` để số lượt tăng dần; dấu cuối kèm tia toả, hai vòng sóng, loé toàn màn và chữ "+N" bật lên.
## Nằm trên lớp phủ toàn màn (`top_level`, toạ độ canvas), không bắt chạm, tự xoá khi xong.

const BoardFx := preload("res://src/ui/board_fx.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")

const CHARGE := 0.14  # nút nảy, sao nhóm lên trước khi dấu đầu bay
const FLY := 0.58
const GAP := 0.11  # dấu sau rời nút trễ hơn dấu trước
const TAIL_CATCH := 0.16  # đuôi rút vào chip sau khi dấu chạm
const AFTER := 0.8  # tia, vòng sóng, chữ "+N" tắt dần sau dấu cuối
const TRAIL := 0.3  # đuôi dài chừng này phần đường bay
const SEGMENTS := 26
const MAX_COMETS := 5
const FAN := 0.3  # độ xoè quạt, theo phần quãng đường
const RAYS := 14
const EDGE := 36.0  # điểm điều khiển không ra sát mép màn hơn chừng này
const GOLD := Color("FFD54A")
const BLUE := Color("4FC3FF")
const CORE := Color("FFF8E1")
const PLUS_FILL := Color("FFC21A")
const PLUS_SHINE := Color("FFEB8F")
const PLUS_EDGE := Color("B4560A")

var on_tick: Callable = Callable()
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _chip: Control = null
## Mỗi dấu: p (4 điểm Bézier, toạ độ canvas), start (giây), share (số lượt mang theo), landed, at (lúc chạm), dust, spin.
var _comets: Array[Dictionary] = []
var _total: int = 0
var _t: float = 0.0
var _last_hit: float = -1.0  # lúc dấu cuối chạm; < 0 là chưa
var _hit_age: float = 99.0  # giây kể từ dấu gần nhất chạm, cho quầng ở chip
var _punch_tw: Tween = null
var _hits: int = 0  # lần nảy, để chip lắc đổi chiều
var _solid: Control = null  # dấu "+" vẽ màu đặc (không cộng sáng), nằm trên vệt
var _tex: Texture2D = null


func _init() -> void:
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	_tex = BoardFx.sparkle_texture()
	_solid = Control.new()
	_solid.name = "Plus"
	_solid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_solid.draw.connect(_draw_solid)
	add_child(_solid)


## `button` là nút booster (nảy lúc bắn), `chip` là ô đếm lượt. `amount` lượt chia đều cho tối đa MAX_COMETS dấu.
## Gọi sau khi đã add_child.
func start(button: Control, chip: Control, amount: int, tick: Callable = Callable()) -> void:
	on_tick = tick
	global_position = Vector2.ZERO
	_from = button.get_global_rect().get_center()
	_chip = chip
	_to = chip.get_global_rect().get_center()
	_total = amount
	var vp := get_viewport_rect()
	var d := _to - _from
	var dist := d.length()
	var perp := Vector2(-d.y, d.x).normalized()
	var n := clampi(amount, 1, MAX_COMETS)
	var left := amount
	for i in n:
		var share := int(float(left) / float(n - i))
		left -= share
		var s := 0.0 if n == 1 else lerpf(-1.0, 1.0, float(i) / float(n - 1))
		var p1 := _from + d * 0.15 + perp * (s * FAN * 1.25 + 0.06) * dist
		var p2 := _from + d * 0.75 + perp * (s * FAN * 0.5 + 0.1) * dist
		p1.x = clampf(p1.x, vp.position.x + EDGE, vp.end.x - EDGE)
		p2.x = clampf(p2.x, vp.position.x + EDGE, vp.end.x - EDGE)
		var dust := _make_dust()
		add_child(dust)
		dust.position = _from
		_comets.append({"p": [_from, p1, p2, _to] as Array[Vector2], "start": CHARGE + GAP * i, "share": share,
			"landed": false, "at": 0.0, "dust": dust, "spin": randf() * TAU})
	_punch(button, 0.82)
	BoardFx.impact_flash(self, _from, BLUE, 240.0, 0.32, 0.8)


func _process(delta: float) -> void:
	if _comets.is_empty():
		return
	_t += delta
	_hit_age += delta
	for c in _comets:
		var f := _t - float(c.start)
		if f < 0.0 or bool(c.landed):
			continue
		var dust := c.dust as CPUParticles2D
		dust.emitting = true
		dust.position = _bez(c.p, _fly_s(f))
		if f >= FLY:
			_land(c)
	if _last_hit >= 0.0 and _t > _last_hit + AFTER:
		queue_free()
	queue_redraw()
	_solid.queue_redraw()


func _land(c: Dictionary) -> void:
	c.landed = true
	c.at = _t
	(c.dust as CPUParticles2D).emitting = false
	_hit_age = 0.0
	var last := _comets.all(func(o: Dictionary) -> bool: return bool(o.landed))
	if last:
		_last_hit = _t
		BoardFx.impact_flash(self, _to, GOLD, 340.0, 0.5, 1.0)
		add_child(_make_burst(_to, 36, 1.0))
		_punch(_chip, 1.34)
		_pop_text()
	else:
		BoardFx.impact_flash(self, _to, BLUE, 200.0, 0.3, 0.6)
		add_child(_make_burst(_to, 14, 0.6))
		_punch(_chip, 1.18)
	if on_tick.is_valid():
		on_tick.call(int(c.share))


## Nảy dẻo quanh tâm: phóng lên `k` lần, lắc nhẹ, loé sáng rồi về như cũ.
func _punch(node: Control, k: float) -> void:
	if node == null:
		return
	if _punch_tw != null and _punch_tw.is_valid() and node == _chip:
		_punch_tw.kill()
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(k, k)
	_hits += 1
	node.rotation = 0.0 if k < 1.0 else (0.08 if _hits % 2 == 0 else -0.08)
	node.modulate = Color(1.7, 1.6, 1.25) if k > 1.0 else Color(1.4, 1.5, 1.7)
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "rotation", 0.0, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate", Color.WHITE, 0.3)
	if node == _chip:
		_punch_tw = tw


## Chữ "+N" vàng bật ra dưới-phải chip (chỗ trống cạnh chip mảnh, không đè tên level), đứng một nhịp rồi bay lên và mờ đi.
func _pop_text() -> void:
	var l := ThemeKit.gold_label("+%d" % _total, ThemeKit.FS_TITLE)
	l.name = "MovePlusText"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.reset_size()
	l.pivot_offset = l.size * 0.5
	l.position = _to + Vector2(_chip.size.x * 0.5 + 34.0, 70.0) - l.size * 0.5
	l.scale = Vector2(0.2, 0.2)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2(1.3, 1.3), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.18)
	tw.tween_property(l, "position:y", l.position.y - 34.0, 0.32).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.32).set_ease(Tween.EASE_IN)


## Tiến độ bay đã nắn: bật ra nhanh khỏi nút, lượn, rồi lao vào chip.
func _fly_s(f: float) -> float:
	var u := clampf(f / FLY, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u) * 0.35 + u * u * 0.65


func _bez(p: Array, s: float) -> Vector2:
	var m := 1.0 - s
	return p[0] * m * m * m + p[1] * 3.0 * m * m * s + p[2] * 3.0 * m * s * s + p[3] * s * s * s


# --- vẽ cộng sáng: quầng, vệt, tia, vòng sóng ---

func _draw() -> void:
	if _comets.is_empty():
		return
	var pending := _comets.any(func(c: Dictionary) -> bool: return _t < float(c.start))
	if pending:
		_draw_charge(clampf(_t / CHARGE, 0.0, 1.0))
	for c in _comets:
		var f := _t - float(c.start)
		if f < 0.0:
			continue
		var head := _fly_s(f)
		var tail := maxf(0.0, head - TRAIL)
		if bool(c.landed):
			tail = lerpf(1.0 - TRAIL, 1.0, clampf((_t - float(c.at)) / TAIL_CATCH, 0.0, 1.0))
			head = 1.0
		if head - tail > 0.002:
			_draw_trail(c.p, tail, head, 44.0, Color(BLUE, 0.6), Color(GOLD, 0.0))
			_draw_trail(c.p, tail, head, 13.0, Color(CORE, 0.95), GOLD)
		if not bool(c.landed):
			_draw_glow(_bez(c.p, head), 1.0, f)
	if _hit_age < 0.35:
		var k := _hit_age / 0.35
		draw_circle(_to, 40.0 + 50.0 * k, Color(GOLD, 0.4 * (1.0 - k) * (1.0 - k)))
	if _last_hit >= 0.0:
		_draw_finale(_t - _last_hit)


## Vòng sáng thu vào nút booster, quầng nở ra chờ dấu bay.
func _draw_charge(k: float) -> void:
	var ring := (1.0 - k) * 80.0 + 26.0
	draw_arc(_from, ring, 0.0, TAU, 44, Color(BLUE, 0.75 * k), 5.0, true)
	_draw_glow(_from, sin(k * PI * 0.5) * 1.2, _t)


func _draw_glow(at: Vector2, k: float, time: float) -> void:
	if k <= 0.0:
		return
	draw_circle(at, 50.0 * k, Color(BLUE, 0.14))
	draw_circle(at, 28.0 * k, Color(GOLD, 0.3))
	_star(at, 96.0 * k * (1.0 + 0.18 * sin(time * 40.0)), time * 4.0, CORE)
	_star(at, 60.0 * k, PI * 0.25 - time * 3.0, Color(BLUE, 0.8))


func _star(at: Vector2, px: float, rot: float, col: Color) -> void:
	draw_set_transform(at, rot, Vector2.ONE)
	draw_texture_rect(_tex, Rect2(Vector2(-px, -px) * 0.5, Vector2(px, px)), false, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Dải sáng thon từ `s0` (đuôi, mờ, nhỏ) tới `s1` (đầu, rộng `width`); mép ngoài mờ về 0.
func _draw_trail(p: Array, s0: float, s1: float, width: float, head_col: Color, tail_col: Color) -> void:
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var pts: Array[Vector2] = []
	for i in SEGMENTS + 1:
		pts.append(_bez(p, lerpf(s0, s1, float(i) / SEGMENTS)))
	for i in SEGMENTS + 1:
		var k := float(i) / SEGMENTS
		var tan := (pts[mini(i + 1, SEGMENTS)] - pts[maxi(i - 1, 0)]).normalized()
		var nor := Vector2(-tan.y, tan.x)
		var w := width * 0.5 * pow(k, 1.3)
		var c := tail_col.lerp(head_col, k)
		c.a = head_col.a * pow(k, 0.8)
		verts.append_array(PackedVector2Array([pts[i] - nor * w, pts[i], pts[i] + nor * w]))
		cols.append_array(PackedColorArray([Color(c, 0.0), c, Color(c, 0.0)]))
		if i < SEGMENTS:
			var b := i * 3
			for s in 2:
				idx.append_array(PackedInt32Array([b + s, b + s + 1, b + s + 3, b + s + 1, b + s + 4, b + s + 3]))
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, verts, cols)


## Sau dấu cuối: loé toàn màn, tia vàng-xanh toả xoay, hai vòng sóng nở từ chip.
func _draw_finale(a: float) -> void:
	var p := clampf(a / AFTER, 0.0, 1.0)
	var fade := (1.0 - p) * (1.0 - p)
	var grow := 1.0 - pow(1.0 - p, 3.0)
	if a < 0.22:
		draw_rect(get_viewport_rect(), Color(GOLD, 0.2 * (1.0 - a / 0.22)))
	draw_circle(_to, 34.0 + 46.0 * grow, Color(CORE, 0.4 * fade))
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for i in RAYS:
		var ang := TAU * i / RAYS + a * 1.1
		var dir := Vector2(cos(ang), sin(ang))
		var side := Vector2(-dir.y, dir.x) * 8.0
		var reach := (50.0 + 190.0 * grow) * (1.0 if i % 2 == 0 else 0.6)
		var base := _to + dir * 12.0
		var b := verts.size()
		verts.append_array(PackedVector2Array([base - side, base + side, _to + dir * reach]))
		var c := Color(GOLD if i % 2 == 0 else BLUE, 0.75 * fade)
		cols.append_array(PackedColorArray([c, c, Color(c, 0.0)]))
		idx.append_array(PackedInt32Array([b, b + 1, b + 2]))
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, verts, cols)
	for r in 2:
		var q := clampf((a - r * 0.1) / (AFTER * 0.6), 0.0, 1.0)
		if q <= 0.0 or q >= 1.0:
			continue
		var rad := 20.0 + 150.0 * (1.0 - pow(1.0 - q, 2.5))
		draw_arc(_to, rad, 0.0, TAU, 56, Color(GOLD if r == 0 else BLUE, 0.85 * (1.0 - q)), maxf(1.0, 10.0 * (1.0 - q)), true)


# --- vẽ màu đặc: dấu "+" kẹo ---

func _draw_solid() -> void:
	for c in _comets:
		var f := _t - float(c.start)
		if f < 0.0 or bool(c.landed):
			continue
		var grow := clampf(f / 0.12, 0.0, 1.0)
		var k := (0.6 + 0.85 * sin(grow * PI * 0.5)) * lerpf(1.0, 0.75, _fly_s(f))
		_plus(_bez(c.p, _fly_s(f)), k, float(c.spin) + f * 9.0)


## Dấu cộng bo tròn: viền nâu, thân vàng, nửa trên sáng, chấm bóng.
func _plus(at: Vector2, k: float, rot: float) -> void:
	_solid.draw_set_transform(at, rot, Vector2(k, k))
	var arm := 21.0
	var half := 7.5
	_cross(arm + 3.5, half + 3.5, PLUS_EDGE)
	_cross(arm, half, PLUS_FILL)
	_solid.draw_rect(Rect2(-half, -arm, half * 2.0, arm - half * 0.3), PLUS_SHINE)
	_solid.draw_rect(Rect2(-arm, -half, arm * 2.0, half * 0.9), PLUS_SHINE)
	_solid.draw_circle(Vector2(-half * 0.4, -arm + half * 0.9), 3.0, Color(1, 1, 1, 0.9))
	_solid.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _cross(arm: float, half: float, col: Color) -> void:
	_solid.draw_rect(Rect2(-half, -arm, half * 2.0, arm * 2.0), col)
	_solid.draw_rect(Rect2(-arm, -half, arm * 2.0, half * 2.0), col)
	for e in [Vector2(0, -arm), Vector2(0, arm), Vector2(-arm, 0), Vector2(arm, 0)]:
		_solid.draw_circle(e, half, col)


# --- hạt ---

## Bụi sao rơi lại dọc đường bay.
func _make_dust() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "MoveDust"
	p.emitting = false
	p.amount = 40
	p.lifetime = 0.55
	p.randomness = 0.5
	p.texture = _tex
	p.direction = Vector2.DOWN
	p.spread = 180.0
	p.gravity = Vector2(0.0, 240.0)
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 120.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 0.2
	p.scale_amount_max = 0.6
	p.scale_amount_curve = _twinkle_curve()
	p.color_ramp = _ramp()
	p.material = material
	return p


## Sao nổ tròn quanh chip lúc dấu chạm.
func _make_burst(at: Vector2, amount: int, strength: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "MoveBurst"
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.7
	p.explosiveness = 0.95
	p.randomness = 0.4
	p.texture = _tex
	p.spread = 180.0
	p.gravity = Vector2(0.0, 420.0)
	p.initial_velocity_min = 160.0 * strength
	p.initial_velocity_max = 560.0 * strength
	p.damping_min = 240.0
	p.damping_max = 520.0
	p.angular_velocity_min = -480.0
	p.angular_velocity_max = 480.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.95 * strength + 0.2
	p.scale_amount_curve = _twinkle_curve()
	p.color_ramp = _ramp()
	p.material = material
	p.position = at
	p.emitting = true
	return p


func _ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, CORE)
	g.set_color(1, Color(BLUE, 0.0))
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
