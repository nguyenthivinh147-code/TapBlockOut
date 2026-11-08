extends Control
## Loading curtain on the way into a level from Home's Play and after a refill on No Lives (main.gd go_curtain):
## candies of one kind, picked at random each time, fall one by one from above the screen and pile up from the
## bottom, each landing with a small squash, until they fill the screen like a jar. Main swaps the screen while it is
## full and then calls open(): the pile drops out through the bottom, the lowest rows first, so the level shows from
## the top down. A backing in the candy's tone fills the pile from the bottom up to the highest row at rest (every row
## below it at rest too), so no gap between two candies shows what is behind. Blocks input for its whole life.
## Same interface as level_curtain.gd: close() returns once the screen is covered, open() frees the node at the end.
## Rows overlap like a hex grid; a candy draws in front of the ones that landed before it.

const Config := preload("res://src/config.gd")
## Candy sprites, ComfyUI art in the style of the loading art's candy pile (art/manifest.json, candy_drop_*), and the
## backing under each: a darker tone of the candy, so the gaps read as shade between candies.
const CANDY_TEX: Array[String] = [
	"res://assets/ui/candy_drop/candy_drop_00.png",
	"res://assets/ui/candy_drop/candy_drop_01.png",
	"res://assets/ui/candy_drop/candy_drop_02.png",
	"res://assets/ui/candy_drop/candy_drop_03.png",
	"res://assets/ui/candy_drop/candy_drop_04.png",
	"res://assets/ui/candy_drop/candy_drop_05.png",
	"res://assets/ui/candy_drop/candy_drop_06.png",
	"res://assets/ui/candy_drop/candy_drop_07.png",
]
const BACKING: Array[Color] = [
	Color("e98d94"), Color("8cc8ea"), Color("f0a050"), Color("e27aa6"),
	Color("e9c22c"), Color("7cc23a"), Color("9a66d6"), Color("4aa8e0"),
]
## Bottom row's centre above the bottom edge, in row gaps; rows go up until one has its centre at or above the top.
const FIRST_ROW := 0.3
## A column is kept while its centre is within this fraction of the column gap outside the screen.
const EDGE := 0.25
## Resting tilt, starting tilt around it, size spread and sideways drift of a falling candy (radians, fractions of
## the candy size).
const REST_TILT := 0.35
const FALL_SPIN := 0.8
const SIZE_SPREAD := 0.08
const FALL_DRIFT := 0.08
## A candy starts this fraction of the screen height above the top edge (plus half a candy and up to FALL_SPREAD
## candy sizes more), so it is already falling fast when it comes into view instead of hanging at the top.
const FALL_FROM := 0.35
const FALL_SPREAD := 0.3
## Landing: squashed to LAND_SQUASH, back with an overshoot over LAND_SEC.
const LAND_SQUASH := Vector2(1.14, 0.84)
const LAND_SEC := 0.16
## Leaving: spin on the way out.
const OUT_SPIN := 1.0
## A candy is at rest within this fraction of the row gap from its slot.
const AT_REST := 0.25

## Kind of the last curtain, so the next one picks another.
static var _last_kind := -1

## Candy kind (index in CANDY_TEX); -1 picks one at random, never the last curtain's. Set before adding to the tree.
var kind := -1
var _rng := RandomNumberGenerator.new()
var _backing: ColorRect = null
## Rows from the bottom; each an Array of {node, slot (centre), scale, tilt}, in landing order.
var _rows: Array = []
var _slot_y: Array[float] = []
var _candy := 0.0
var _row_gap := 0.0
var _screen := Vector2.ZERO
## While close() runs, _process keeps the backing on the rows at rest.
var _filling := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	# The full-rect anchors size it on the next layout pass; the parent (Main) already has the screen's size.
	var parent := get_parent() as Control
	_screen = parent.size if parent != null and parent.size != Vector2.ZERO else get_viewport_rect().size
	if kind < 0 or kind >= CANDY_TEX.size():
		kind = _rng.randi_range(0, CANDY_TEX.size() - 1)
		if kind == _last_kind:
			kind = (kind + _rng.randi_range(1, CANDY_TEX.size() - 1)) % CANDY_TEX.size()
	_last_kind = kind
	_backing = ColorRect.new()
	_backing.name = "Backing"
	_backing.color = BACKING[kind]
	_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backing.position = Vector2(0.0, _screen.y)
	_backing.size = Vector2(_screen.x, 0.0)
	add_child(_backing)
	_build()


## Lays the candies out on the grid, above the screen; close() drops them in.
func _build() -> void:
	var c: Dictionary = Config.CONTENT
	var tex: Texture2D = load(CANDY_TEX[kind]) if ResourceLoader.exists(CANDY_TEX[kind]) else null
	var cols := maxi(int(c.candy_curtain_cols), 1)
	var dx := _screen.x / cols
	var dy := dx * float(c.candy_curtain_row_gap)
	_row_gap = dy
	_candy = dx * float(c.candy_curtain_size)
	var y := _screen.y - dy * FIRST_ROW
	var r := 0
	while true:
		_slot_y.append(y)
		var row: Array = []
		var offset := 0.5 if r % 2 == 1 else 0.0
		for col in range(-1, cols + 1):
			var x := (col + 0.5 + offset) * dx
			if x < -dx * EDGE or x > _screen.x + dx * EDGE:
				continue
			row.append({"slot": Vector2(x, y), "scale": 1.0 + _rng.randf_range(-SIZE_SPREAD, SIZE_SPREAD),
				"tilt": _rng.randf_range(-REST_TILT, REST_TILT)})
		row.shuffle()
		for e: Dictionary in row:
			var n := TextureRect.new()
			n.name = "Candy%d_%d" % [r, _candy_count()]
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
			n.texture = tex
			n.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			n.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			n.size = Vector2(_candy, _candy)
			n.pivot_offset = n.size * 0.5
			n.position = Vector2(e.slot.x, -_candy * 2.0) - n.pivot_offset
			add_child(n)
			e["node"] = n
		_rows.append(row)
		if y <= 0.0:
			break
		y -= dy
		r += 1


func _candy_count() -> int:
	return get_child_count() - 1


## Fall time over `dist`: like gravity, `full` over the screen height and the square root of the fraction otherwise.
func _fall_time(dist: float, full: float) -> float:
	return full * sqrt(clampf(dist / _screen.y, 0.01, 4.0))


func _process(_delta: float) -> void:
	if _filling:
		_fit_backing()


## Backing from the bottom edge up to the centre of the highest row at rest, counting from the bottom until a row has
## a candy still falling in.
func _fit_backing() -> void:
	var top := _screen.y
	for r in _rows.size():
		var at_rest := true
		for e: Dictionary in _rows[r]:
			var n: TextureRect = e.node
			if absf(n.position.y + n.pivot_offset.y - float(e.slot.y)) > _row_gap * AT_REST:
				at_rest = false
				break
		if not at_rest:
			break
		top = _slot_y[r]
	_backing.position.y = top
	_backing.size.y = _screen.y - top + 2.0


## Drops the candies in one by one, bottom row first: one lands every candy_curtain_drop_sec. Returns when the screen
## is covered.
func close() -> void:
	var c: Dictionary = Config.CONTENT
	var full := float(c.candy_curtain_fall_sec)
	var drop := float(c.candy_curtain_drop_sec)
	var jitter := float(c.candy_curtain_jitter_sec)
	var top := -_screen.y * FALL_FROM - _candy * 0.5
	var order: Array[Dictionary] = []
	for row: Array in _rows:
		for e: Dictionary in row:
			order.append(e)
	# Candy i lands at t0 + i * drop; t0 leaves room for the longest fall to start at 0.
	var t0 := 0.0
	for i in order.size():
		t0 = maxf(t0, _fall_time(float(order[i].slot.y) - top + _candy * FALL_SPREAD, full) - i * drop)
	var tw := create_tween().set_parallel(true)
	for i in order.size():
		var e: Dictionary = order[i]
		var n: TextureRect = e.node
		var from := Vector2(e.slot.x + _rng.randf_range(-FALL_DRIFT, FALL_DRIFT) * _candy,
			top - _rng.randf() * _candy * FALL_SPREAD)
		var dur := _fall_time(e.slot.y - from.y, full)
		var at := maxf(t0 + i * drop + _rng.randf() * jitter - dur, 0.0)
		var rest := Vector2.ONE * float(e.scale)
		n.position = from - n.pivot_offset
		n.scale = rest
		n.rotation = float(e.tilt) + _rng.randf_range(-FALL_SPIN, FALL_SPIN)
		tw.tween_property(n, "position", e.slot - n.pivot_offset, dur).set_delay(at) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(n, "rotation", float(e.tilt), dur).set_delay(at) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "scale", rest * LAND_SQUASH, LAND_SEC * 0.35).set_delay(at + dur) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "scale", rest, LAND_SEC * 0.65).set_delay(at + dur + LAND_SEC * 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_filling = true
	await tw.finished
	_filling = false
	# Every row at rest: the backing reaches the top row's centre, at or above the top edge.
	_fit_backing()


## After candy_curtain_hold_sec, the pile drops out through the bottom like free fall, each row
## candy_curtain_out_row_sec after the one below, then frees itself. Every candy falls the same distance (the screen
## and one candy), so the pile keeps its shape and the top clears first; the backing falls with the top row.
func open() -> void:
	var c: Dictionary = Config.CONTENT
	var hold := float(c.candy_curtain_hold_sec)
	var row_sec := float(c.candy_curtain_out_row_sec)
	var full := float(c.candy_curtain_out_fall_sec)
	var jitter := float(c.candy_curtain_jitter_sec)
	var drop := _screen.y + _candy
	var tw := create_tween().set_parallel(true)
	for r in _rows.size():
		for e: Dictionary in _rows[r]:
			var n: TextureRect = e.node
			var at := hold + r * row_sec + _rng.randf() * jitter
			tw.tween_property(n, "position:y", n.position.y + drop, full).set_delay(at) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(n, "rotation", float(e.tilt) + _rng.randf_range(-OUT_SPIN, OUT_SPIN), full) \
				.set_delay(at).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_backing, "position:y", _backing.position.y + drop, full) \
		.set_delay(hold + (_rows.size() - 1) * row_sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	queue_free()
