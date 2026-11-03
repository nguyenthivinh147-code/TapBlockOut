extends Control
## Overlay tutorial kiểu spotlight cho Weekly Pass: dim nền, chừa một lỗ quanh target, viền sáng nhấp nháy
## và bong bóng thoại có mũi tên. Chạm bất kỳ đâu để sang bước kế; hết bước cuối thì phát finished(true).
## setup(steps): mỗi bước {target: Control, text: String}. Target mất (layer dựng lại) thì finished(false).
## Overlay tự free sau khi phát finished.

signal finished(completed: bool)

const ThemeKit := preload("res://src/ui/theme_kit.gd")

const DIM := Color(0, 0, 0, 0.72)
const PAD := 10.0  # lỗ rộng hơn target bấy nhiêu
const BUBBLE_W := 540.0
const BUBBLE_MARGIN_X := 26
const BUBBLE_MARGIN_Y := 16
const BORDER := 4
const ARROW := 22.0
const GAP := ARROW + 6.0  # từ mép bong bóng tới mép lỗ
const EDGE := 16.0  # lề tối thiểu so với mép màn
const UPPER_FRAC := 0.25  # lỗ nằm hết trong phần trên này của màn thì bong bóng đặt bên dưới
const FILL := Color("8F96D6")
const EDGE_COLOR := Color("F4F6FB")
const TEXT_OUTLINE := Color("2A2F66")
const FS_BUBBLE := 28

var steps: Array = []
var index: int = -1
var busy: bool = false  # đang chuyển bước: chạm bị bỏ qua
var bubble: PanelContainer = null
var label: Label = null
var highlight: Panel = null
var arrow: Control = null

var _target: Control = null
var _hole: Rect2 = Rect2()
var _done: bool = false
var _arrow_down: bool = true


func _ready() -> void:
	if bubble == null:
		_build()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	highlight = Panel.new()
	highlight.name = "Highlight"
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(0, 0, 0, 0)
	hs.set_border_width_all(5)
	hs.border_color = ThemeKit.GOLD
	hs.set_corner_radius_all(ThemeKit.RADIUS)
	highlight.add_theme_stylebox_override("panel", hs)
	highlight.visible = false
	add_child(highlight)
	var pulse := highlight.create_tween().set_loops()
	pulse.tween_property(highlight, "modulate:a", 0.55, 0.6)
	pulse.tween_property(highlight, "modulate:a", 1.0, 0.6)

	arrow = Control.new()
	arrow.name = "Arrow"
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.size = Vector2(ARROW * 2.0, ARROW + BORDER)
	arrow.visible = false
	arrow.draw.connect(_draw_arrow)
	add_child(arrow)

	bubble = PanelContainer.new()
	bubble.name = "Bubble"
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := StyleBoxFlat.new()
	bs.bg_color = FILL
	bs.border_color = EDGE_COLOR
	bs.set_border_width_all(BORDER)
	bs.set_corner_radius_all(22)
	bs.content_margin_left = BUBBLE_MARGIN_X
	bs.content_margin_right = BUBBLE_MARGIN_X
	bs.content_margin_top = BUBBLE_MARGIN_Y
	bs.content_margin_bottom = BUBBLE_MARGIN_Y
	bs.shadow_color = Color(0, 0, 0, 0.35)
	bs.shadow_size = 8
	bubble.add_theme_stylebox_override("panel", bs)
	bubble.visible = false
	add_child(bubble)

	label = ThemeKit.make_label("", FS_BUBBLE, Color.WHITE)
	label.name = "BubbleLabel"
	label.add_theme_color_override("font_outline_color", TEXT_OUTLINE)
	label.add_theme_constant_override("outline_size", 6)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(BUBBLE_W - BUBBLE_MARGIN_X * 2, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(label)


func setup(p_steps: Array) -> void:
	if bubble == null:
		_build()
	steps = p_steps
	_show_step(0)


## Hình chữ nhật của lỗ (toạ độ cục bộ của overlay), đã nới PAD.
func hole_rect() -> Rect2:
	return _hole


## Sang bước kế (hoặc kết thúc ở bước cuối). Bỏ qua khi đang chuyển bước.
func advance() -> void:
	if _done or busy:
		return
	if index + 1 < steps.size():
		_show_step(index + 1)
	else:
		_finish(true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		advance()


func _show_step(i: int) -> void:
	if _done:
		return
	index = i
	var step: Dictionary = steps[i]
	var t := step.get("target") as Control
	if t == null or not is_instance_valid(t):
		_finish(false)
		return
	busy = true
	if bubble.visible:
		var out := create_tween().set_parallel(true)
		out.tween_property(bubble, "scale", Vector2.ZERO, 0.12)
		out.tween_property(arrow, "modulate:a", 0.0, 0.12)
		await out.finished
		if _done:
			return
	_target = t
	label.text = str(step.get("text", ""))
	bubble.reset_size()
	await get_tree().process_frame  # chờ container tính lại cỡ bong bóng sau khi đổi chữ
	if _done:
		return
	if not _track():
		return
	_place_bubble()  # _track chỉ đặt lại khi lỗ đổi; cỡ bong bóng có thể đã đổi theo chữ mới
	highlight.visible = true
	bubble.visible = true
	arrow.visible = true
	bubble.pivot_offset = bubble.size * 0.5
	bubble.scale = Vector2.ZERO
	arrow.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(bubble, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(arrow, "modulate:a", 1.0, 0.2)
	await tw.finished
	busy = false


func _process(_delta: float) -> void:
	if _done or _target == null:
		return
	_track()


## Cập nhật lỗ theo target hiện tại; false (và kết thúc) nếu target đã mất.
func _track() -> bool:
	if _target == null or not is_instance_valid(_target) or not _target.is_inside_tree():
		_finish(false)
		return false
	var gr := _target.get_global_rect()
	var r := Rect2(gr.position - global_position, gr.size).grow(PAD)
	if r != _hole:
		_hole = r
		highlight.position = r.position
		highlight.size = r.size
		_place_bubble()
		queue_redraw()
	return true


func _place_bubble() -> void:
	var bs := bubble.size
	var fits_above := _hole.position.y - bs.y - GAP >= EDGE
	var fits_below := _hole.end.y + GAP + bs.y <= size.y - EDGE
	# Target sát đỉnh màn (thanh tiến độ) thì đặt bong bóng bên dưới để không che tiêu đề.
	var prefer_below := _hole.end.y < size.y * UPPER_FRAC
	var above := (fits_above and not (prefer_below and fits_below)) or not fits_below
	var y :=_hole.position.y - bs.y - GAP if above else _hole.end.y + GAP
	y = clampf(y, EDGE, maxf(size.y - bs.y - EDGE, EDGE))
	var cx := _hole.get_center().x
	var x := clampf(cx - bs.x * 0.5, EDGE, maxf(size.x - bs.x - EDGE, EDGE))
	bubble.position = Vector2(x, y)
	var ax := clampf(cx - ARROW, x + 28.0, x + bs.x - 28.0 - ARROW * 2.0)
	var ay := y + bs.y - BORDER if above else y - ARROW
	if above != _arrow_down:
		_arrow_down = above
		arrow.queue_redraw()
	arrow.position = Vector2(ax, ay)


func _draw() -> void:
	var full := Rect2(Vector2.ZERO, size)
	var h := _hole.intersection(full)
	if h.size.x <= 0.0 or h.size.y <= 0.0:
		draw_rect(full, DIM)
		return
	draw_rect(Rect2(0, 0, size.x, h.position.y), DIM)
	draw_rect(Rect2(0, h.end.y, size.x, size.y - h.end.y), DIM)
	draw_rect(Rect2(0, h.position.y, h.position.x, h.size.y), DIM)
	draw_rect(Rect2(h.end.x, h.position.y, size.x - h.end.x, h.size.y), DIM)
	# Bo góc lỗ theo viền sáng: phần góc vuông nằm ngoài cung tròn cũng phải tối.
	var r := minf(float(ThemeKit.RADIUS), minf(h.size.x, h.size.y) * 0.5)
	_dim_corner(h.position + Vector2(r, r), r, Vector2(-1, -1))
	_dim_corner(Vector2(h.end.x - r, h.position.y + r), r, Vector2(1, -1))
	_dim_corner(Vector2(h.end.x - r, h.end.y - r), r, Vector2(1, 1))
	_dim_corner(Vector2(h.position.x + r, h.end.y - r), r, Vector2(-1, 1))


## Phần của ô vuông r x r ở góc (hướng dir so với tâm cung) nằm ngoài cung tròn tâm `center`.
func _dim_corner(center: Vector2, r: float, dir: Vector2) -> void:
	var pts := PackedVector2Array([center + dir * r])
	var a0 := Vector2(dir.x, 0).angle()
	var sweep := fposmod(Vector2(0, dir.y).angle() - a0 + PI, TAU) - PI  # cung ngắn nhất (90 độ)
	var n := 8
	for i in n + 1:
		var a := a0 + sweep * float(i) / float(n)
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, DIM)


func _draw_arrow() -> void:
	var a := ARROW
	var b := float(BORDER)
	if _arrow_down:
		arrow.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(a * 2, 0), Vector2(a, a + b)]), EDGE_COLOR)
		arrow.draw_colored_polygon(PackedVector2Array([Vector2(b + 1, 0), Vector2(a * 2 - b - 1, 0), Vector2(a, a - 2)]), FILL)
	else:
		arrow.draw_colored_polygon(PackedVector2Array([Vector2(0, a + b), Vector2(a * 2, a + b), Vector2(a, 0)]), EDGE_COLOR)
		arrow.draw_colored_polygon(PackedVector2Array([Vector2(b + 1, a + b), Vector2(a * 2 - b - 1, a + b), Vector2(a, b + 2)]), FILL)


func _finish(completed: bool) -> void:
	if _done:
		return
	_done = true
	finished.emit(completed)
	queue_free()
