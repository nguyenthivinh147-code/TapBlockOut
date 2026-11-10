extends Control
## Socola phủ một thanh cổng (design.md mục 4, "Socola"; concept A socola sữa ở art/concepts/concept_choco_v1.png).
## Lớp socola sữa phủ phần trong của thanh (phần ngoài vẫn lộ màu thanh), dày dần theo số lớp, giọt chảy vào trong bàn
## (tối đa khoảng 0,35 ô ở 4 lớp); vẽ bằng `choco_cover.gdshader` trên một ColorRect xoay theo thanh. Huy hiệu tròn ghi
## số lớp còn lại nằm ở chỗ mũi tên của thanh, vẽ bằng lệnh canvas trên node con riêng (trên lớp socola).
## BoardView tạo một node cho mỗi thanh còn socola, đặt làm con của khung (`CandyFrame`), gọi layout() khi xếp lại.
## Node nằm ở (0, 0) của khung nên toạ độ trùng toạ độ khung.

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const CandyFrame := preload("res://src/ui/candy_frame.gd")
const SHADER := preload("res://src/ui/choco_cover.gdshader")

## Hướng ra ngoài bàn của mỗi thanh.
const OUT := {"up": Vector2(0, -1), "left": Vector2(-1, 0), "right": Vector2(1, 0), "down": Vector2(0, 1)}
## Góc xoay từ khung chuẩn (thanh nằm ngang theo x, ngoài là -y, giọt chảy theo +y) sang từng thanh.
const TURN := {"up": 0.0, "left": -PI / 2.0, "right": PI / 2.0, "down": PI}
const BODY := Color("7B4A2A")  # socola sữa
const DEEP := Color("452613")
const EDGE := Color("321A0A")
const SHINE := Color("D9A67F")
const BADGE := Color("3B2112")
const RIM := Color("FFE6C2")
## Màu vụn socola cho CandyShards (cùng khoá với ThemeKit.block_ramp).
const RAMP := {"deep": Color("3A1F0E"), "side": Color("5E361C"), "face": BODY, "stripe": SHINE}
const LIGHT := Vector3(-0.45, -0.7, 0.55)  # ánh sáng trên màn: từ trên trái
const SHADOW := Vector2(0.04, 0.08)  # bóng đổ lệch trên màn, theo đơn vị khung
const KEEP := 0.26  # phần ngoài của bề dày thanh không bị phủ, để còn thấy màu thanh
const BULGE := 0.09  # mỗi lớp socola dày thêm chừng này đơn vị khung về phía trong
const MAX_DRIPS := 24  # khớp drips[24] trong shader
const DRIP_STEP := 1.2  # ô giữa hai giọt dọc thanh
const DRIP_BASE := 0.06  # giọt dài DRIP_BASE + DRIP_PER_LAYER * số lớp ô (nhân thêm 0,45..1 ngẫu nhiên)
const DRIP_PER_LAYER := 0.075
const DRIP_W := Vector2(0.26, 0.42)  # bề ngang thân giọt, ô
const BULB := 1.15  # đầu giọt to hơn nửa bề ngang thân chừng này lần
const BEVEL := 0.35  # mép bo tròn của lớp socola, theo bề dày lớp
const PAD := 0.12  # lề vùng vẽ quanh socola (bóng đổ, khử răng cưa), đơn vị khung
const BADGE_R := 0.34  # bán kính huy hiệu số, đơn vị khung
const POKE_SQUASH := 0.18  # khối hướng về thanh bị chạm: socola nhún chừng này theo bề dày
const POKE_TIME := 0.45
const POP_TIME := 0.35
const MELT_TIME := 0.32

var side: String = "up"
var layers: int = 0

var _bar: Rect2 = Rect2()  # thân thanh, toạ độ của khung
var _unit: float = 42.0  # đơn vị khung
var _cell: float = 64.0  # cỡ ô khối
var _badge_k: float = 1.0
var _squash: float = 0.0
var _poke_tw: Tween = null
var _pop_tw: Tween = null
var _drips: Array = []  # [vị trí dọc thanh 0..1, bề ngang 0..1, độ dài 0..1]
var _body: ColorRect = null
var _badge: Control = null


func setup(bar_side: String, n: int) -> void:
	side = bar_side
	layers = n
	name = "Choco_" + bar_side
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	_body = ColorRect.new()
	_body.name = "Body"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = SHADER
	_body.material = m
	add_child(_body)
	_badge = Control.new()
	_badge.name = "Badge"
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.draw.connect(_draw_badge)
	add_child(_badge)


func layout(bar: Rect2, unit: float, cell: float) -> void:
	_bar = bar
	_unit = unit
	_cell = cell
	var length := _length()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(side)
	_drips.clear()
	var step := DRIP_STEP * cell
	var count := clampi(floori(length / step), 1, MAX_DRIPS)
	var lead := (length - float(count - 1) * step) * 0.5
	for i in count:
		var at := (lead + float(i) * step + rng.randf_range(-0.2, 0.2) * step) / length
		_drips.append([clampf(at, 0.06, 0.94), rng.randf(), rng.randf_range(0.45, 1.0)])
	_apply()


## Số lớp mới (còn > 0): socola mỏng đi, giọt ngắn lại, huy hiệu nảy.
func set_layers(n: int, animate: bool = true) -> void:
	layers = n
	_apply()
	if not animate:
		return
	if _pop_tw != null:
		_pop_tw.kill()
	_pop_tw = create_tween()
	_pop_tw.tween_method(_set_badge_k, 1.6, 1.0, POP_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Khối hướng về thanh này bị chạm: socola nhún như thạch.
func poke() -> void:
	if _poke_tw != null:
		_poke_tw.kill()
	_poke_tw = create_tween()
	_poke_tw.tween_method(_set_poke, 0.0, 1.0, POKE_TIME)


## Lớp cuối vỡ: socola mờ đi, huy hiệu phồng rồi tắt, xoá node, gọi `done` khi xong.
func melt_away(done: Callable) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, MELT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_method(_set_badge_k, 1.4, 0.2, MELT_TIME)
	tw.chain().tween_callback(func() -> void:
		done.call()
		queue_free())


## Điểm trên mép trong của lớp socola, `along` 0..1 dọc thanh; toạ độ của khung.
func inner_point(along: float = 0.5) -> Vector2:
	return _xf() * Vector2(_length() * along, _top() + _body_h())


## Hướng ra ngoài bàn của thanh (theo màn).
func out_dir() -> Vector2:
	return OUT[side]


## Mỗi đoạn lớp socola dài chừng `span` px dọc thanh: tâm của đoạn, toạ độ của khung (để vỡ thành vụn từng đoạn).
func body_points(span: float) -> Array[Vector2]:
	var length := _length() - 2.0 * _inset()
	var n := maxi(1, roundi(length / maxf(span, 1.0)))
	var out: Array[Vector2] = []
	for i in n:
		out.append(_xf() * Vector2(_inset() + length * (float(i) + 0.5) / float(n), _top() + _body_h() * 0.5))
	return out


func _set_badge_k(v: float) -> void:
	_badge_k = v
	if _badge != null:
		_badge.queue_redraw()


func _set_poke(t: float) -> void:
	_squash = POKE_SQUASH * exp(-5.0 * t) * sin(t * TAU * 2.2)
	_apply()


func _length() -> float:
	return _bar.size.y if side == "left" or side == "right" else _bar.size.x


func _thick() -> float:
	return _bar.size.x if side == "left" or side == "right" else _bar.size.y


func _top() -> float:
	return _thick() * KEEP


## Bề dày lớp socola theo số lớp và cú nhún hiện tại, px.
func _body_h() -> float:
	return (_thick() - _top() + BULGE * float(layers) * _unit) * (1.0 - _squash)


func _inset() -> float:
	return _body_h() * 0.3


## Khung chuẩn -> khung: gốc ở góc thanh nằm phía ngoài và đầu trục dọc thanh.
func _xf() -> Transform2D:
	var origin: Vector2
	match side:
		"up":
			origin = _bar.position
		"down":
			origin = _bar.end
		"left":
			origin = Vector2(_bar.position.x, _bar.end.y)
		_:
			origin = Vector2(_bar.end.x, _bar.position.y)
	return Transform2D(float(TURN[side]), origin)


## Đổ số liệu vào shader và đặt ColorRect theo thanh.
func _apply() -> void:
	if _body == null or _bar.size == Vector2.ZERO:
		return
	_body.visible = layers > 0
	if _badge != null:
		_badge.queue_redraw()
	if layers <= 0:
		return
	var length := _length()
	var body_h := _body_h()
	var k := 1.0 - _squash
	var drip_len := (DRIP_BASE + DRIP_PER_LAYER * float(layers)) * _cell * k
	var drips := PackedVector4Array()
	var deepest := 0.0
	for d: Array in _drips:
		var hw := lerpf(DRIP_W.x, DRIP_W.y, float(d[1])) * _cell * 0.5
		var len := drip_len * float(d[2])
		drips.append(Vector4(float(d[0]) * length, hw, len, hw * BULB))
		deepest = maxf(deepest, len + hw * BULB)
	while drips.size() < MAX_DRIPS:
		drips.append(Vector4.ZERO)
	var pad := PAD * _unit
	var size_px := Vector2(length + 2.0 * pad, _top() + body_h + deepest + 2.0 * pad)
	var turn := float(TURN[side])
	_body.size = size_px
	_body.rotation = turn
	_body.position = _xf() * Vector2(-pad, -pad)
	var screen_light := Vector2(LIGHT.x, LIGHT.y).rotated(-turn)
	var m := _body.material as ShaderMaterial
	m.set_shader_parameter("rect_px", size_px)
	m.set_shader_parameter("origin_px", Vector2(-pad, -pad))
	m.set_shader_parameter("bar_len", length)
	m.set_shader_parameter("top_px", _top())
	m.set_shader_parameter("body_h", body_h)
	m.set_shader_parameter("inset", _inset())
	m.set_shader_parameter("drip_count", _drips.size())
	m.set_shader_parameter("drips", drips)
	m.set_shader_parameter("light_dir", Vector3(screen_light.x, screen_light.y, LIGHT.z))
	m.set_shader_parameter("shadow_off", (SHADOW * _unit).rotated(-turn))
	m.set_shader_parameter("bevel", maxf(1.5, body_h * BEVEL))
	m.set_shader_parameter("col_body", BODY)
	m.set_shader_parameter("col_deep", DEEP)
	m.set_shader_parameter("col_edge", EDGE)
	m.set_shader_parameter("col_shine", SHINE)


func _draw_badge() -> void:
	if layers <= 0 or _bar.size == Vector2.ZERO:
		return
	var shift: Vector2 = CandyFrame.ARROWS[side]["shift"]
	var at := _bar.get_center() + shift * _unit
	var rad := BADGE_R * _unit * _badge_k
	if rad <= 0.5:
		return
	_badge.draw_circle(at + Vector2(0, rad * 0.12), rad + maxf(1.5, _unit * 0.05), Color(EDGE, 0.45))
	_badge.draw_circle(at, rad + maxf(1.5, _unit * 0.05), EDGE)
	_badge.draw_circle(at, rad, BADGE)
	_badge.draw_arc(at, rad * 0.82, 0.0, TAU, 32, Color(RIM, 0.9), maxf(1.0, rad * 0.12), true)
	var font: Font = ThemeKit.FONT
	var fs := maxi(8, roundi(rad * 1.3))
	var text := str(layers)
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	var base := at + Vector2(-size.x * 0.5, font.get_ascent(fs) * 0.5 - font.get_descent(fs) * 0.35)
	_badge.draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, roundi(fs * 0.18)), EDGE)
	_badge.draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
