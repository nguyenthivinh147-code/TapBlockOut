extends Control
## Vệt gió hút vào thanh khi khối thoát sắp chạm thanh và lúc đang bị nghiền: vệt thon dài ngắn khác nhau hiện sát
## mặt trong của thanh, chạy nhanh dần vào thanh, chụm dần về đoạn khối phủ như phễu, chạm thanh thì bị nuốt vào.
## Không vẽ lên thanh; tự xoá khi vệt cuối hết.
## Dùng: spawn(...) đặt vào lớp dưới các khối nên khối đang lao che phần vệt trùng làn của nó.

const STREAKS := 14
const FROM_MIN := 0.1  # đầu vệt lúc hiện cách mặt trong của thanh, theo ô
const FROM_MAX := 0.8
const SPREAD := 0.9  # vệt toả ra ngoài hai đầu đoạn chừng này ô
const LEN_MIN := 0.3  # dài vệt, theo ô
const LEN_MAX := 1.4
const LIFE_MIN := 0.16  # giây từ lúc hiện tới lúc bị nuốt hết
const LIFE_MAX := 0.24
const WIDTH := 0.07  # theo ô
const ALPHA := 0.7
const FUNNEL := 0.7  # sát thanh thì độ lệch ngang còn chừng này
const FUNNEL_REACH := FROM_MAX + LEN_MAX  # xa thanh chừng này ô thì chưa chụm
const POINTS := 5  # số điểm mỗi vệt, đủ cong theo phễu

var _mouth := Vector2.ZERO  # tâm đoạn khối sắp phủ, trên mặt trong của thanh
var _dir := Vector2.RIGHT  # hướng khối đi, cũng là hướng gió
var _cell: float = 42.0
var _color := Color.WHITE
var _streaks: Array[Dictionary] = []  # {"u", "from", "len", "delay", "life"}, khoảng cách theo px
var _age: float = 0.0


## `mouth`, `half_span` theo toạ độ của `parent`. Vệt hiện rải đều trong `window` giây, bắt đầu sau `delay` giây.
static func spawn(parent: Node, mouth: Vector2, dir: Vector2, half_span: float, cell: float, color: Color, delay: float, window: float, rng: RandomNumberGenerator) -> Control:
	var w: Control = load("res://src/ui/suck_wind.gd").new()
	w.name = "SuckWind"
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w._mouth = mouth
	w._dir = dir
	w._cell = cell
	w._color = color
	var wide := half_span + SPREAD * cell
	# thứ tự hiện xáo trộn để vệt kề nhau không hiện liền nhau
	var order: Array = range(STREAKS)
	for i in range(STREAKS - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: int = order[i]
		order[i] = order[j]
		order[j] = tmp
	for i in STREAKS:
		# chia đều theo bề ngang và theo thời gian rồi xê dịch chút để không thành hàng
		var u := lerpf(-wide, wide, (float(i) + rng.randf_range(0.2, 0.8)) / float(STREAKS))
		var at := delay + window * (float(order[i]) + rng.randf()) / float(STREAKS)
		w._streaks.append({"u": u, "from": rng.randf_range(FROM_MIN, FROM_MAX) * cell, "len": rng.randf_range(LEN_MIN, LEN_MAX) * cell,
			"delay": at, "life": rng.randf_range(LIFE_MIN, LIFE_MAX)})
	parent.add_child(w)
	return w


func _process(delta: float) -> void:
	_age += delta
	var done := true
	for s in _streaks:
		if _age < float(s["delay"]) + float(s["life"]):
			done = false
	if done:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var perp := Vector2(-_dir.y, _dir.x)
	var reach := FUNNEL_REACH * _cell
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
		var fade := minf(t / 0.2, 1.0)
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for k in POINTS:
			var x := lerpf(far, near, float(k) / float(POINTS - 1))
			var u := float(s["u"]) * lerpf(FUNNEL, 1.0, clampf(x / reach, 0.0, 1.0))
			pts.append(_mouth - _dir * x + perp * u)
			# đuôi trong suốt, đậm dần về đầu
			var c := _color
			c.a = ALPHA * fade * (float(k) / float(POINTS - 1))
			cols.append(c)
		draw_polyline_colors(pts, cols, WIDTH * _cell, true)
