extends CanvasLayer
## Tap feedback (design.md section 2): every touch grows a thin, faint ring at the touch point and sends a few small,
## faint 5-point stars outward; all fade out together. Sits above every screen, popup and the level curtain (below the
## mock ad overlay), never takes or blocks input, and redraws only while an effect runs.
## Timing and sizes: Config.CONTENT.tap_fx_*.

const Config := preload("res://src/config.gd")

const LAYER := 120  # above the game UI, below MockAds' overlay (128) that stands in for a full-screen ad
const MAX_TAPS := 8  # rapid taps drop the oldest effect
const SEGMENTS := 32
## Ring: radius grows from RING_FROM of tap_fx_ring_px to all of it, ease-out. The band is RING_W px wide, RING at its
## middle line and fading to nothing at its inner and outer edges.
const RING_FROM := 0.3
const RING_W := 4.0
const RING := Color(1.0, 0.94, 0.97, 0.55)
## Stars: tap_fx_stars evenly around the point with a random turn, each angle shifted by up to STAR_JITTER of the gap;
## they start at STAR_FROM of tap_fx_star_px from the point and shrink from STAR_R_FROM to STAR_R_TO px.
const STAR_FROM := 0.35
const STAR_JITTER := 0.25
const STAR_R_FROM := 4.0
const STAR_R_TO := 2.0
const STAR_INNER := 0.45
const STAR_SPIN := 2.0  # max turn (rad) over the effect
const STAR_A := 0.4
const STAR_FADE_FROM := 0.4  # stars keep STAR_A for this part, then fade out
const STAR_COLORS: Array[Color] = [Color("FFE27A"), Color("FFA6CF"), Color("D2B6FF")]

## Each tap: pos (canvas), age (s), stars [{angle, spin}].
var _taps: Array[Dictionary] = []
var _canvas: Node2D = null


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Node2D.new()
	_canvas.name = "Canvas"
	_canvas.draw.connect(_draw_taps)
	add_child(_canvas)


func _ready() -> void:
	set_process(not _taps.is_empty())


## Seen before the GUI and never marked handled, so buttons and the board still get the touch.
func _input(event: InputEvent) -> void:
	var at: Variant = tap_point(event)
	if at != null:
		spawn(at)


## Where a new touch lands, or null. A touch reports both a screen touch and an emulated mouse click (and a desktop
## click may report an emulated touch); emulated events are skipped so each touch counts once.
static func tap_point(event: InputEvent) -> Variant:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return null
	var st := event as InputEventScreenTouch
	if st != null:
		return st.position if st.pressed else null
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		return mb.position
	return null


## Starts one effect at `at` (root viewport coordinates, as in _input).
func spawn(at: Vector2) -> void:
	if _taps.size() >= MAX_TAPS:
		_taps.pop_front()
	var n := maxi(int(Config.CONTENT.tap_fx_stars), 0)
	var gap := TAU / float(maxi(n, 1))
	var turn := randf() * gap
	var stars: Array[Dictionary] = []
	for i in n:
		stars.append({
			"angle": turn + gap * (float(i) + randf_range(-STAR_JITTER, STAR_JITTER)),
			"spin": randf_range(-STAR_SPIN, STAR_SPIN),
		})
	_taps.append({"pos": at, "age": 0.0, "stars": stars})
	set_process(true)
	_canvas.queue_redraw()


func active_count() -> int:
	return _taps.size()


func _process(delta: float) -> void:
	var life := float(Config.CONTENT.tap_fx_sec)
	for i in range(_taps.size() - 1, -1, -1):
		_taps[i].age = float(_taps[i].age) + delta
		if float(_taps[i].age) >= life:
			_taps.remove_at(i)
	if _taps.is_empty():
		set_process(false)
	_canvas.queue_redraw()


func _draw_taps() -> void:
	var c: Dictionary = Config.CONTENT
	var life := maxf(float(c.tap_fx_sec), 0.01)
	var ring_px := float(c.tap_fx_ring_px)
	var star_px := float(c.tap_fx_star_px)
	for tap in _taps:
		var k := clampf(float(tap.age) / life, 0.0, 1.0)
		var out := 1.0 - pow(1.0 - k, 3.0)
		var p: Vector2 = tap.pos
		_draw_soft_ring(p, ring_px * lerpf(RING_FROM, 1.0, out), RING_W, Color(RING, RING.a * (1.0 - k * k)))
		var a := STAR_A * clampf((1.0 - k) / (1.0 - STAR_FADE_FROM), 0.0, 1.0)
		var d := star_px * lerpf(STAR_FROM, 1.0, out)
		var sr := lerpf(STAR_R_FROM, STAR_R_TO, k)
		var stars: Array = tap.stars
		for i in stars.size():
			var s: Dictionary = stars[i]
			var at := p + Vector2.from_angle(float(s.angle)) * d
			var col: Color = STAR_COLORS[i % STAR_COLORS.size()]
			_canvas.draw_colored_polygon(_star(at, sr, float(s.angle) + float(s.spin) * out), Color(col, a))


## Ring band `w` px wide around radius `r`: `col` on the middle line, fading linearly to clear at both edges. Two
## triangle strips (inner half, outer half) in one call.
func _draw_soft_ring(p: Vector2, r: float, w: float, col: Color) -> void:
	var r_in := maxf(r - w * 0.5, 0.0)
	var r_out := r + w * 0.5
	var clear := Color(col, 0.0)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in SEGMENTS:
		var d := Vector2.from_angle(TAU * float(i) / float(SEGMENTS))
		pts.append(p + d * r_in)
		pts.append(p + d * r)
		pts.append(p + d * r_out)
		cols.append(clear)
		cols.append(col)
		cols.append(clear)
	var idx := PackedInt32Array()
	for i in SEGMENTS:
		var a := i * 3
		var b := ((i + 1) % SEGMENTS) * 3
		for j in 2:
			idx.append_array(PackedInt32Array([a + j, b + j, b + j + 1, a + j, b + j + 1, a + j + 1]))
	RenderingServer.canvas_item_add_triangle_array(_canvas.get_canvas_item(), idx, pts, cols)


## 5-point star of outer radius `r`, one point along `rot`.
static func _star(c: Vector2, r: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := rot + i * PI / 5.0
		pts.append(c + Vector2.from_angle(a) * (r if i % 2 == 0 else r * STAR_INNER))
	return pts
