extends Control
## Đồng gold bay trên thẻ thắng: gold MOVES thừa từ chip lượt trên HUD vào ô gold của thẻ, và gold x2 từ ô gold của thẻ
## lên chip gold của thanh trên. Đồng nở ra ở nguồn, vừa lật vừa bay vồng, kéo vệt vàng và bụi sao, rơi vào đích. Mỗi đồng
## mang một phần số lượt và một phần gold: rời nguồn thì gọi `on_launch(lượt)`, chạm đích thì loé sáng, nổ sao và gọi
## `on_land(gold, last)`; đồng cuối kèm loé lớn và hai vòng sóng. Nằm trên lớp phủ (`top_level`, toạ độ canvas), không
## bắt chạm, tự xoá khi xong. Bên gọi muốn bỏ qua thì tự cộng nốt phần còn lại rồi queue_free().

const BoardFx := preload("res://src/ui/board_fx.gd")

## The last coin landed (also when the effect leaves the tree before that).
signal arrived

const POP := 0.1  # đồng nở ra ở chip trước khi bay
const FLY := 0.55
const GAP := 0.075  # đồng sau rời chip trễ hơn đồng trước
const AFTER := 0.7  # loé và vòng sóng tắt dần sau đồng cuối
const TRAIL := 0.22  # vệt dài chừng này phần đường bay
const SEGMENTS := 14
const MAX_COINS := 10
const FAN := 0.22  # độ xoè, theo phần quãng đường
const LIFT := 0.18  # đường bay vồng sang một bên trước khi rơi vào ô
const EDGE := 30.0  # điểm điều khiển không ra sát mép màn hơn chừng này
const SIZE_FROM := 0.5  # cỡ đồng so với icon gold của thẻ, lúc rời chip và lúc tới ô
const SIZE_TO := 0.8
const GOLD := Color("FFD54A")
const CORE := Color("FFF8E1")
const AMBER := Color("FF9F1A")

var on_launch: Callable = Callable()
var on_land: Callable = Callable()
## Size of the last landing's flash, glow and two rings, as a part of the default (ItemFx lands smaller).
var finale_k := 1.0
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _size := 64.0  # cạnh icon gold của thẻ (toạ độ canvas)
var _tex: Texture2D = null
var _star: Texture2D = null
## Mỗi đồng: p (4 điểm Bézier, toạ độ canvas), start (giây), moves, gold (phần mang theo), launched, landed, dust, spin.
var _coins: Array[Dictionary] = []
var _t: float = 0.0
var _last_hit: float = -1.0  # lúc đồng cuối chạm; < 0 là chưa
var _hit_age: float = 99.0  # giây kể từ đồng gần nhất chạm, cho quầng ở ô gold
var _solid: Control = null  # đồng gold vẽ màu đặc (không cộng sáng), nằm trên vệt
var _arrived := false


func _init() -> void:
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	_star = BoardFx.sparkle_texture()
	_solid = Control.new()
	_solid.name = "Coins"
	_solid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_solid.draw.connect(_draw_solid)
	add_child(_solid)


## `from` là nguồn (chip lượt, hoặc icon gold của thẻ; Control, hoặc Rect2 toạ độ canvas), `to` là đích (icon gold của
## thẻ, hoặc của thanh trên), `tex` là hình đồng gold (null thì vẽ đồng tròn). `moves` lượt và `gold` gold chia đều cho
## tối đa MAX_COINS đồng (không gắn với lượt thì truyền MAX_COINS làm `moves`). Cỡ đồng theo icon đích. Gọi sau khi
## đã add_child.
func start(from: Variant, to: Control, tex: Texture2D, moves: int, gold: int, launch: Callable = Callable(),
		land: Callable = Callable()) -> void:
	on_launch = launch
	on_land = land
	global_position = Vector2.ZERO
	_tex = tex
	var src: Rect2 = from if from is Rect2 else (from as Control).get_global_rect()
	_from = src.get_center()
	var dest := to.get_global_rect()
	_to = dest.get_center()
	_size = minf(dest.size.x, dest.size.y)
	var vp := get_viewport_rect()
	var d := _to - _from
	var dist := d.length()
	var side := Vector2(d.y, -d.x).normalized()
	var n := clampi(moves, 1, MAX_COINS)
	var moves_left := moves
	var gold_left := gold
	for i in n:
		var m := int(float(moves_left) / float(n - i))
		var g := int(float(gold_left) / float(n - i))
		moves_left -= m
		gold_left -= g
		var s := 0.0 if n == 1 else lerpf(-1.0, 1.0, float(i) / float(n - 1))
		var p1 := _from + d * 0.12 + side * (LIFT + s * FAN + randf_range(-0.03, 0.03)) * dist
		var p2 := _from + d * 0.72 + side * (LIFT * 0.6 + s * FAN * 0.35) * dist
		var dust := _make_dust()
		add_child(dust)
		dust.position = _from
		_coins.append({"p": [_from, _inside(p1, vp), _inside(p2, vp), _to] as Array[Vector2], "start": GAP * i,
			"moves": m, "gold": g, "launched": false, "landed": false, "dust": dust, "spin": randf() * TAU})


## Holds the first coin at its source for `sec` s (RewardFly staggers the parts of one reward). Call after start().
func wait(sec: float) -> void:
	_t = -maxf(sec, 0.0)


func _inside(p: Vector2, vp: Rect2) -> Vector2:
	return Vector2(clampf(p.x, vp.position.x + EDGE, vp.end.x - EDGE), clampf(p.y, vp.position.y + EDGE, vp.end.y - EDGE))


func _process(delta: float) -> void:
	if _coins.is_empty():
		return
	_t += delta
	_hit_age += delta
	for c in _coins:
		var f := _t - float(c.start)
		if f < 0.0 or bool(c.landed):
			continue
		if not bool(c.launched):
			_launch(c)
		var dust := c.dust as CPUParticles2D
		dust.emitting = f > POP
		dust.position = _pos(c, f)
		if f >= POP + FLY:
			_land(c)
	if _last_hit >= 0.0 and _t > _last_hit + AFTER:
		queue_free()
	queue_redraw()
	_solid.queue_redraw()


func _launch(c: Dictionary) -> void:
	c.launched = true
	BoardFx.impact_flash(self, _from, GOLD, _size * 1.5, 0.25, 0.5)
	if on_launch.is_valid():
		on_launch.call(int(c.moves))


func _land(c: Dictionary) -> void:
	c.landed = true
	(c.dust as CPUParticles2D).emitting = false
	_hit_age = 0.0
	var last := _coins.all(func(o: Dictionary) -> bool: return bool(o.landed))
	if last:
		_last_hit = _t
		BoardFx.impact_flash(self, _to, GOLD, _size * 3.4 * finale_k, 0.5, 1.0)
		add_child(_make_burst(_to, 30, 1.0))
	else:
		BoardFx.impact_flash(self, _to, GOLD, _size * 2.0, 0.3, 0.6)
		add_child(_make_burst(_to, 10, 0.6))
	if on_land.is_valid():
		on_land.call(int(c.gold), last)
	if last:
		_arrive()


func _exit_tree() -> void:
	_arrive()


func _arrive() -> void:
	if not _arrived:
		_arrived = true
		arrived.emit()


## Vị trí đồng `f` giây sau lúc rời chip: đứng ở chip lúc nở, rồi theo đường bay.
func _pos(c: Dictionary, f: float) -> Vector2:
	return _bez(c.p, _fly_s(f - POP))


## Tiến độ bay đã nắn: bật khỏi chip, lượn, rồi lao vào ô gold.
func _fly_s(f: float) -> float:
	var u := clampf(f / FLY, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u) * 0.4 + u * u * 0.6


func _bez(p: Array, s: float) -> Vector2:
	var m := 1.0 - s
	return p[0] * m * m * m + p[1] * 3.0 * m * m * s + p[2] * 3.0 * m * s * s + p[3] * s * s * s


# --- vẽ cộng sáng: vệt, quầng, vòng sóng ---

func _draw() -> void:
	for c in _coins:
		var f := _t - float(c.start)
		if f < POP or bool(c.landed):
			continue
		var head := _fly_s(f - POP)
		var tail := maxf(0.0, head - TRAIL)
		if head - tail > 0.002:
			_draw_trail(c.p, tail, head, _size * 0.32, Color(AMBER, 0.45))
			_draw_trail(c.p, tail, head, _size * 0.1, Color(CORE, 0.9))
		var at := _bez(c.p, head)
		draw_circle(at, _size * 0.42, Color(GOLD, 0.16))
		_draw_star(at, _size * (0.9 + 0.15 * sin(f * 40.0)), f * 4.0, CORE)
	if _hit_age < 0.3:
		var k := _hit_age / 0.3
		draw_circle(_to, _size * (0.45 + 0.4 * k), Color(GOLD, 0.4 * (1.0 - k) * (1.0 - k)))
	if _last_hit >= 0.0:
		_draw_finale(_t - _last_hit)


## Dải sáng từ `s0` (đuôi, trong suốt) tới `s1` (đầu, màu `col`).
func _draw_trail(p: Array, s0: float, s1: float, width: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in SEGMENTS + 1:
		var k := float(i) / SEGMENTS
		pts.append(_bez(p, lerpf(s0, s1, k)))
		cols.append(Color(col, col.a * k * k))
	draw_polyline_colors(pts, cols, width, true)


func _draw_star(at: Vector2, px: float, rot: float, col: Color) -> void:
	draw_set_transform(at, rot, Vector2.ONE)
	draw_texture_rect(_star, Rect2(Vector2(-px, -px) * 0.5, Vector2(px, px)), false, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Sau đồng cuối: quầng sáng và hai vòng sóng nở từ ô gold.
func _draw_finale(a: float) -> void:
	var p := clampf(a / AFTER, 0.0, 1.0)
	var fade := (1.0 - p) * (1.0 - p)
	draw_circle(_to, _size * finale_k * (0.4 + 0.5 * (1.0 - pow(1.0 - p, 3.0))), Color(CORE, 0.35 * fade))
	for r in 2:
		var q := clampf((a - r * 0.1) / (AFTER * 0.6), 0.0, 1.0)
		if q <= 0.0 or q >= 1.0:
			continue
		var rad := _size * finale_k * (0.3 + 1.3 * (1.0 - pow(1.0 - q, 2.5)))
		draw_arc(_to, rad, 0.0, TAU, 56, Color(GOLD if r == 0 else AMBER, 0.85 * (1.0 - q)), maxf(1.0, 10.0 * (1.0 - q)), true)


# --- vẽ màu đặc: đồng gold lật ---

func _draw_solid() -> void:
	for c in _coins:
		var f := _t - float(c.start)
		if f < 0.0 or bool(c.landed):
			continue
		var u := clampf((f - POP) / FLY, 0.0, 1.0)
		var pop := clampf(f / POP, 0.0, 1.0)
		var px := _size * lerpf(SIZE_FROM, SIZE_TO, u) * (0.3 + 0.7 * sin(pop * PI * 0.5))
		var flip := maxf(0.2, absf(cos(float(c.spin) + f * 11.0)))
		_solid.draw_set_transform(_pos(c, f), sin(f * 6.0) * 0.2, Vector2(flip, 1.0))
		if _tex != null:
			_solid.draw_texture_rect(_tex, Rect2(Vector2(-px, -px) * 0.5, Vector2(px, px)), false)
		else:
			_solid.draw_circle(Vector2.ZERO, px * 0.5, AMBER)
			_solid.draw_circle(Vector2.ZERO, px * 0.4, GOLD)
	_solid.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- hạt ---

## Bụi sao rơi lại dọc đường bay.
func _make_dust() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "CoinDust"
	p.emitting = false
	p.amount = 24
	p.lifetime = 0.45
	p.randomness = 0.5
	p.texture = _star
	p.direction = Vector2.DOWN
	p.spread = 180.0
	p.gravity = Vector2(0.0, 260.0)
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 110.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 0.2
	p.scale_amount_max = 0.55
	p.scale_amount_curve = BoardFx.shrink_curve()
	p.color_ramp = _ramp()
	p.material = material
	return p


## Sao nổ tròn quanh ô gold lúc đồng chạm.
func _make_burst(at: Vector2, amount: int, strength: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "CoinBurst"
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.6
	p.explosiveness = 0.95
	p.randomness = 0.4
	p.texture = _star
	p.spread = 180.0
	p.gravity = Vector2(0.0, 420.0)
	p.initial_velocity_min = 140.0 * strength
	p.initial_velocity_max = 480.0 * strength
	p.damping_min = 240.0
	p.damping_max = 520.0
	p.angular_velocity_min = -480.0
	p.angular_velocity_max = 480.0
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.8 * strength + 0.2
	p.scale_amount_curve = BoardFx.shrink_curve()
	p.color_ramp = _ramp()
	p.material = material
	p.position = at
	p.emitting = true
	return p


func _ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, CORE)
	g.set_color(1, Color(AMBER, 0.0))
	g.add_point(0.4, GOLD)
	return g
