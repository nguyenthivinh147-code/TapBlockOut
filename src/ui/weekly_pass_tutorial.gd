extends Control
## Overlay tutorial kiểu spotlight cho Weekly Pass: dim nền, chừa một lỗ quanh target, viền sáng nhấp nháy,
## bàn tay chỉ vào target và bảng thoại. Chạm bất kỳ đâu để sang bước kế; hết bước cuối thì phát finished(true).
## setup(steps): mỗi bước {target: Control, text: String}. Target mất (layer dựng lại) thì finished(false).
## Overlay tự free sau khi phát finished.
## Art: MainTutorialLayer Step1 (hand with tap rings, animated by TutController_Step1, and the Popup2 text panel);
## the hole is outlined with the rounded frame Resources_UI_Maincenter:UI_Maincenter_23. Instance
## scenes/weekly_pass_tutorial.tscn, not this script.

signal finished(completed: bool)

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const LAYER := "MainTutorialLayer"
const STEP := "GameObject/Step1"
const DIM := Color(0, 0, 0, 0.72)
const PAD := 10.0  # lỗ rộng hơn target bấy nhiêu (px)
## Canvas units below.
const GAP := 28.0  # từ mép bảng thoại tới mép lỗ
const EDGE := 16.0  # lề tối thiểu so với mép màn
const UPPER_FRAC := 0.25  # lỗ nằm hết trong phần trên này của màn thì bảng thoại đặt bên dưới
const CORNER := 32.0  # left border of UI_Maincenter_23 = corner radius of the outline
## Hand/TapFx (where the tap rings play) relative to Hand, Unity units (y up): the fingertip.
const FINGER := Vector2(-32.9, 22)

var steps: Array = []
var index: int = -1
var busy: bool = false  # đang chuyển bước: chạm bị bỏ qua
## Text panel (Step1/Panel), its TMP text, the hole outline and the pointing hand (Step1/Hand).
var bubble: Control = null
var label: Label = null
var highlight: Control = null
var arrow: Control = null
var ui: RefCounted = null

var _target: Control = null
var _hole: Rect2 = Rect2()
var _done: bool = false


func _ready() -> void:
	if bubble == null:
		_build()


## MainTutorialLayer (Step2, TargetButton hidden, every node ignoring the mouse so taps reach the overlay) and the
## hole outline are nodes of scenes/weekly_pass_tutorial.tscn.
func _build() -> void:
	ui = UnityUI.build(self, LAYER, {"reveal": false})
	# MainTutStep enables the Animator of its step when it plays; the prefab keeps it off.
	var anim: Node = ui.animator(STEP)
	if anim != null:
		anim.enabled = true
	highlight = %Highlight
	var pulse := highlight.create_tween().set_loops()
	pulse.tween_property(highlight, "modulate:a", 0.55, 0.6)
	pulse.tween_property(highlight, "modulate:a", 1.0, 0.6)
	arrow = ui.node(STEP + "/Hand")
	arrow.name = "Arrow"
	bubble = ui.node(STEP + "/Panel")
	bubble.name = "Bubble"
	label = ui.label(STEP + "/Panel/Canvas/Text (TMP)")
	label.name = "BubbleLabel"


func setup(p_steps: Array) -> void:
	if bubble == null:
		_build()
	steps = p_steps
	_show_step(0)


## Hình chữ nhật của lỗ (toạ độ cục bộ của overlay, px), đã nới PAD.
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
	UnityUI.set_text(label, str(step.get("text", "")))
	await get_tree().process_frame  # một frame bố cục sau khi đổi chữ (auto size)
	if _done:
		return
	if not _track():
		return
	_place_bubble()  # _track chỉ đặt lại khi lỗ đổi
	highlight.visible = true
	bubble.visible = true
	arrow.visible = true
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
		var u := _units(r)
		UnityKit.place(highlight, u.grow(6.0))
		_place_bubble()
		queue_redraw()
	return true


## Canvas units per px is 1 / CustomCanvasScaler scale.
func _scale() -> float:
	var c: Control = ui.get("canvas")
	return c.scale.x if c != null and c.scale.x > 0.0 else 1.0


func _units(px: Rect2) -> Rect2:
	var s := _scale()
	return Rect2(px.position / s, px.size / s)


func _place_bubble() -> void:
	var view: Vector2 = (ui.get("canvas") as Control).size
	var h := _units(_hole)
	var bs: Vector2 = (bubble.get_meta("u_rect") as Dictionary).size
	var fits_above := h.position.y - bs.y - GAP >= EDGE
	var fits_below := h.end.y + GAP + bs.y <= view.y - EDGE
	# Target sát đỉnh màn (thanh tiến độ) thì đặt bảng thoại bên dưới để không che tiêu đề.
	var prefer_below := h.end.y < view.y * UPPER_FRAC
	var above := (fits_above and not (prefer_below and fits_below)) or not fits_below
	var y := h.position.y - bs.y - GAP if above else h.end.y + GAP
	y = clampf(y, EDGE, maxf(view.y - bs.y - EDGE, EDGE))
	var c := h.get_center()
	var x := clampf(c.x - bs.x * 0.5, EDGE, maxf(view.x - bs.x - EDGE, EDGE))
	UnityKit.place(bubble, Rect2(x, y, bs.x, bs.y))
	# Fingertip on the target centre.
	var hand: Vector2 = (arrow.get_meta("u_rect") as Dictionary).size
	var at := c - Vector2(FINGER.x, -FINGER.y)
	UnityKit.place(arrow, Rect2(at - hand * 0.5, hand))


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
	var r := minf(CORNER * _scale(), minf(h.size.x, h.size.y) * 0.5)
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


func _finish(completed: bool) -> void:
	if _done:
		return
	_done = true
	finished.emit(completed)
	queue_free()
