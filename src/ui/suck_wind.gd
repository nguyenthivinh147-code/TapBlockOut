extends Control
## Vệt gió hút vào thanh khi khối thoát sắp chạm thanh và lúc đang bị nghiền: vệt mảnh có quầng mờ, dài ngắn khác nhau,
## hiện sát mặt trong của thanh, chạy nhanh dần vào thanh, chạm thanh thì bị nuốt vào. Vệt rải trong đúng bề ngang
## khối, chỗ miệng thanh trước khối sáng lên một quầng cùng bề ngang. Cả cụm gió rõ dần từ trong suốt trong FADE_IN
## giây đầu, mỗi vệt cũng rõ dần lúc mới hiện. Không vẽ lên thanh; tự xoá khi vệt cuối hết.
## Dùng: spawn(...) đặt vào lớp trên các khối để vệt chạy đè lên khối đang bị hút.

const STREAKS_PER_CELL := 5.0  # số vệt mỗi ô bề ngang khối
const STREAKS_MIN := 4
const FROM_MIN := 0.1  # đầu vệt lúc hiện cách mặt trong của thanh, theo ô
const FROM_MAX := 0.8
const LEN_MIN := 0.3  # dài vệt, theo ô
const LEN_MAX := 1.4
const LIFE_MIN := 0.16  # giây từ lúc hiện tới lúc bị nuốt hết
const LIFE_MAX := 0.24
const WIDTH := 0.035  # lõi vệt, theo ô
const ALPHA := 0.8
const GLOW_WIDTH := 0.28  # quầng quanh vệt, theo ô; mờ dần ra hai mép
const GLOW_ALPHA := 0.3
const MOUTH_DEPTH := 0.6  # quầng ở miệng thanh lan vào bàn chừng này ô
const MOUTH_SOFT := 0.2  # hai đầu quầng miệng mờ dần trong chừng này ô
const MOUTH_ALPHA := 0.3
const FADE_IN := 0.18  # giây từ lúc vệt đầu hiện: cả cụm gió (vệt, quầng vệt, quầng miệng) rõ dần từ trong suốt tới đậm đủ
const STREAK_IN := 0.4  # mỗi vệt rõ dần trong phần đầu này của đời vệt
const MOUTH_OUT := 0.12  # giây quầng miệng tắt dần sau khi vệt cuối hết

var _mouth := Vector2.ZERO  # tâm đoạn khối sắp phủ, trên mặt trong của thanh
var _dir := Vector2.RIGHT  # hướng khối đi, cũng là hướng gió
var _half := 21.0  # nửa bề ngang khối, px
var _cell: float = 42.0
var _color := Color.WHITE
var _streaks: Array[Dictionary] = []  # {"u", "from", "len", "delay", "life"}, khoảng cách theo px
var _first: float = 0.0  # giây vệt đầu hiện
var _last: float = 0.0  # giây vệt cuối hết
var _age: float = 0.0


## `mouth`, `half_span` theo toạ độ của `parent`. Vệt hiện rải đều trong `window` giây, bắt đầu sau `delay` giây.
static func spawn(parent: Node, mouth: Vector2, dir: Vector2, half_span: float, cell: float, color: Color, delay: float, window: float, rng: RandomNumberGenerator) -> Control:
	var w: Control = load("res://src/ui/suck_wind.gd").new()
	w.name = "SuckWind"
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# cộng sáng để vệt và quầng rực lên cả trên nền bàn sáng lẫn trên khối cùng màu thanh
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	w.material = mat
	w._mouth = mouth
	w._dir = dir
	w._half = half_span
	w._cell = cell
	w._color = color
	var n := maxi(STREAKS_MIN, roundi(2.0 * half_span / cell * STREAKS_PER_CELL))
	# thứ tự hiện xáo trộn để vệt kề nhau không hiện liền nhau
	var order: Array = range(n)
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: int = order[i]
		order[i] = order[j]
		order[j] = tmp
	w._first = INF
	for i in n:
		# chia đều theo bề ngang và theo thời gian rồi xê dịch chút để không thành hàng
		var u := lerpf(-half_span, half_span, (float(i) + rng.randf_range(0.2, 0.8)) / float(n))
		var at := delay + window * (float(order[i]) + rng.randf()) / float(n)
		var life := rng.randf_range(LIFE_MIN, LIFE_MAX)
		w._streaks.append({"u": u, "from": rng.randf_range(FROM_MIN, FROM_MAX) * cell, "len": rng.randf_range(LEN_MIN, LEN_MAX) * cell,
			"delay": at, "life": life})
		w._first = minf(w._first, at)
		w._last = maxf(w._last, at + life)
	parent.add_child(w)
	return w


func _process(delta: float) -> void:
	_age += delta
	if _age >= _last + MOUTH_OUT:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var perp := Vector2(-_dir.y, _dir.x)
	var ramp := _ramp_in()
	# quầng (miệng thanh, quanh từng vệt) vẽ trước trong một lô, lõi vệt vẽ đè lên
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	_add_mouth(verts, cols, idx, perp, ramp)
	var cores: Array[PackedVector2Array] = []
	var core_cols: Array[PackedColorArray] = []
	for s in _streaks:
		var t := (_age - float(s["delay"])) / float(s["life"])
		if t <= 0.0 or t >= 1.0:
			continue
		var length: float = s["len"]
		# đầu vệt nhanh dần từ `from` tới quá mặt trong một đoạn bằng chiều dài vệt; phần đã qua bị nuốt
		var head := float(s["from"]) - (float(s["from"]) + length) * pow(t, 1.6)
		var near := maxf(head, 0.0)
		var far := head + length
		if far <= near:
			continue
		var fade := smoothstep(0.0, STREAK_IN, t) * ramp
		var side := perp * float(s["u"])
		var tail_at := _mouth - _dir * far + side
		var head_at := _mouth - _dir * near + side
		_add_glow(verts, cols, idx, tail_at, head_at, perp, near, Color(_color, GLOW_ALPHA * fade))
		# đuôi trong suốt, đậm dần về đầu
		cores.append(PackedVector2Array([tail_at, head_at]))
		core_cols.append(PackedColorArray([Color(_color, 0.0), Color(_color, ALPHA * fade)]))
	if not idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, verts, cols)
	for i in cores.size():
		draw_polyline_colors(cores[i], core_cols[i], WIDTH * _cell, true)


## Độ rõ của cả cụm gió: 0 lúc vệt đầu hiện, lên 1 sau FADE_IN giây, êm ở hai đầu.
func _ramp_in() -> float:
	return smoothstep(0.0, FADE_IN, _age - _first)


## Quầng ở miệng thanh: rộng đúng bề ngang khối, đậm nhất sát mặt trong, mờ dần vào bàn và ra hai đầu.
func _add_mouth(verts: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array, perp: Vector2, ramp: float) -> void:
	var k := ramp * clampf(1.0 - (_age - _last) / MOUTH_OUT, 0.0, 1.0)
	if k <= 0.0:
		return
	var soft := minf(MOUTH_SOFT * _cell, _half)
	var c := Color(_color, MOUTH_ALPHA * k)
	var b := verts.size()
	for u: float in [-_half, soft - _half, _half - soft, _half]:
		verts.append(_mouth + perp * u)
		verts.append(_mouth + perp * u - _dir * MOUTH_DEPTH * _cell)
	for a: float in [0.0, c.a, c.a, 0.0]:
		cols.append(Color(c, a))
		cols.append(Color(c, 0.0))
	for q in 3:
		var o := b + q * 2
		idx.append_array(PackedInt32Array([o, o + 2, o + 1, o + 1, o + 2, o + 3]))


## Quầng quanh một vệt từ `tail` tới `head`: mờ dần ra hai mép và về đuôi, đầu bo mờ dài tới `room` px.
func _add_glow(verts: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array, tail: Vector2, head: Vector2, perp: Vector2, room: float, c: Color) -> void:
	var hw := perp * GLOW_WIDTH * 0.5 * _cell
	var cap := minf(GLOW_WIDTH * 0.5 * _cell, room)
	var clear := Color(c, 0.0)
	var b := verts.size()
	verts.append_array(PackedVector2Array([tail - hw, tail, tail + hw, head - hw, head, head + hw, head + _dir * cap]))
	cols.append_array(PackedColorArray([clear, clear, clear, clear, c, clear, clear]))
	idx.append_array(PackedInt32Array([b, b + 1, b + 4, b, b + 4, b + 3, b + 1, b + 2, b + 5, b + 1, b + 5, b + 4, b + 3, b + 4, b + 6, b + 4, b + 5, b + 6]))
