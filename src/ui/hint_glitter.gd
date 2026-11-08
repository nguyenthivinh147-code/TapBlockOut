extends Control
## Twinkling stars all over the block the Hint booster picked: every cell holds a few crisp four-point stars (white,
## edged gold or pink, with a small diagonal glint) that flare up and die at random spots inside the cell, each on its
## own beat, then reappear elsewhere in the cell. Lives in the board's Fx layer (above every block and the links) and
## follows the block's transform each frame, so it bounces and pulses with the highlight. Blends normally: added light
## washes out to white blobs on the pastel candy. Ignores input. `stop()` fades it out and frees it; it also frees itself
## when the block leaves the tree.

const PER_CELL := 3  # stars per cell
const PERIOD := Vector2(0.55, 1.05)  # s, one twinkle cycle of a star (random in this range)
const ON := 0.7  # a star shows for this part of its cycle, then rests until it moves
const SIZE := Vector2(0.4, 0.75)  # cells, tip to tip at full flare
const INSET := 0.2  # cells, star centres stay this far inside the cell edges
const SPIN := 1.2  # rad/s, max spin either way
const INNER := 0.16  # waist of a star point, part of its reach
const EDGE := 1.35  # the coloured edge star is this much bigger than the white one
const EDGE_A := 0.75
const GLINT := 0.45  # diagonal glint, part of the star size
const GROW := 0.3  # s: the stars light up over this long when the effect starts
const FADE := 0.15  # s: fade-out after stop()
const GOLD := Color("FFC23A")
const PINK := Color("FF6FB8")
const CORE := Color("FFFDF4")

var _block: Control = null
var _cell: float = 64.0
## One per star: {"cell": Vector2i, "period": s, "phase": 0..1, "cycle": int, "pos": Vector2 px, "px": float,
## "rot": rad, "spin": rad/s, "col": Color}. `pos` is in the block's local pixels.
var _stars: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _t: float = 0.0
var _fade: float = 1.0
var _stopping: bool = false


## Adds the stars over `block` under `parent` (the board's Fx layer). `cells` are the block's own cell coordinates
## (BlockNode.local_cells()), `cell` the cell size in px.
static func spawn(parent: Node, block: Control, cells: Array, cell: float) -> Control:
	var g: Control = load("res://src/ui/hint_glitter.gd").new()
	g.name = "HintGlitter"
	g._setup(block, cells, cell)
	parent.add_child(g, true)  # the previous one may still be fading out: keep a readable name (HintGlitter2)
	return g


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _setup(block: Control, cells: Array, cell: float) -> void:
	_block = block
	_cell = cell
	_rng.randomize()
	for c: Vector2i in cells:
		for i in PER_CELL:
			# the stars of one cell take turns, so no cell ever goes fully dark or flares all at once
			var st := {"cell": c, "period": _rng.randf_range(PERIOD.x, PERIOD.y),
				"phase": (float(i) + _rng.randf() * 0.6) / PER_CELL, "cycle": 0}
			_place(st)
			_stars.append(st)


func stop() -> void:
	_stopping = true


func star_count() -> int:
	return _stars.size()


func _process(delta: float) -> void:
	if not is_instance_valid(_block) or not _block.is_inside_tree() or _block.is_queued_for_deletion():
		queue_free()
		return
	_t += delta
	if _stopping:
		_fade -= delta / FADE
		if _fade <= 0.0:
			queue_free()
			return
	for st in _stars:
		var cycle := floori(_t / float(st.period) + float(st.phase))
		if cycle != int(st.cycle):
			st.cycle = cycle
			_place(st)
	queue_redraw()


## A fresh spot, size, spin and colour for the star's next twinkle.
func _place(st: Dictionary) -> void:
	var c: Vector2i = st.cell
	st.pos = (Vector2(c) + Vector2(_rng.randf_range(INSET, 1.0 - INSET), _rng.randf_range(INSET, 1.0 - INSET))) * _cell
	st.px = _rng.randf_range(SIZE.x, SIZE.y) * _cell
	st.rot = _rng.randf() * TAU
	st.spin = _rng.randf_range(-SPIN, SPIN)
	st.col = GOLD if _rng.randf() < 0.6 else PINK


func _draw() -> void:
	if not is_instance_valid(_block):
		return
	var env := clampf(_t / GROW, 0.0, 1.0) * clampf(_fade, 0.0, 1.0)
	if env <= 0.0:
		return
	# block-local pixels -> this node's space, so the stars ride the block's bounce, pulse and the board shake
	var to_local := get_global_transform().affine_inverse() * _block.get_global_transform()
	for st in _stars:
		var u := _t / float(st.period) + float(st.phase) - float(st.cycle)
		if u >= ON:
			continue
		var k := sin(u / ON * PI)
		k *= k
		var a := k * env
		if a < 0.02:
			continue
		var r: float = float(st.px) * 0.5 * (0.2 + 0.8 * k)
		var rot: float = float(st.rot) + float(st.spin) * u * float(st.period)
		draw_set_transform_matrix(to_local * Transform2D(rot, st.pos))
		draw_colored_polygon(_star(r * EDGE), Color(st.col, EDGE_A * a))
		draw_colored_polygon(_star(r), Color(CORE, a))
		draw_set_transform_matrix(to_local * Transform2D(rot + PI * 0.25, st.pos))
		draw_colored_polygon(_star(r * GLINT), Color(CORE, 0.85 * a))
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Four long points on the axes with a thin waist between them, centred on the origin.
func _star(reach: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 8:
		var ang := i * PI * 0.25
		pts.append(Vector2(cos(ang), sin(ang)) * (reach if i % 2 == 0 else reach * INNER))
	return pts
