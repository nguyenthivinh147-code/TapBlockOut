extends Control
## Vẽ bàn cờ: lưới, đá, khối bo góc, khung cổng (`CandyFrame`); nhận chạm; chạy hoạt ảnh kết quả.
## Dùng: setup(board) rồi nối block_tapped; level gọi board.tap(id) và đưa kết quả vào apply_result().
## Tự co theo `size` của chính nó (hoặc setup(board, area)); đổi size thì tự xếp lại.

const BoardState := preload("res://src/core/board_state.gd")
const BoardFx := preload("res://src/ui/board_fx.gd")
const LevelData := preload("res://src/core/level_data.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const CandyFrame := preload("res://src/ui/candy_frame.gd")
const CandyShards := preload("res://src/ui/candy_shards.gd")

## Khối chạm vào (đã là ô của khối, không phải đá hay ô trống).
signal block_tapped(id: String)
## Mọi hoạt ảnh đang chạy đã xong.
signal animation_done

const MAX_CELL := 150.0
## Bàn tham chiếu (lớn nhất trong 300 level): kích thước ô tính theo bàn này để mọi level dùng cùng một cỡ ô.
const REF_COLS := 8
const REF_ROWS := 11
const SLIDE_TIME := 0.30  # lâu nhất của một lần khối lao tới thanh
const SLIDE_MIN := 0.14  # đường ngắn nhất vẫn đủ thấy khối lấy đà
const SLIDE_PER_CELL := 0.022
const SLIDE_STRETCH := 0.09  # khối dài ra theo hướng lao, hẹp lại phía ngang
const BOUNCE_BACK := 0.24
const WOBBLE_TIME := 0.46
const WOBBLE_SELF := 0.15  # độ nhún của khối đi va
const WOBBLE_BLOCKER := 0.1  # độ nhún của khối bị va
const JOLT := 0.1  # khối bị va lùi chừng này ô
const RIPPLE_DEPTH := 2  # dư chấn lan sang thêm chừng này khối phía sau
const RIPPLE_DELAY := 0.05
const RIPPLE_FADE := 0.5
const CHIPS_BUMP := 7  # số vụn kẹo mỗi khối lúc va chạm
const FLASH_SHATTER := 4.8  # cỡ loé sáng, theo ô
const FLASH_BUMP := 2.6
const SPARKS_SHATTER := 18
const SPARKS_BUMP := 7
const GATE_TIME := 0.22
const GHOST_NAME := "Ghost"
const SIDE_OF_DIR := {"up": Vector2(0, -1), "left": Vector2(-1, 0), "right": Vector2(1, 0), "down": Vector2(0, 1)}


## Bóng đổ của một khối: ở lớp riêng dưới mọi khối nên không đổ lên khối bên cạnh; bám theo khối mỗi khung, xoá theo khối.
class ShadowNode extends Control:
	const BoardFx := preload("res://src/ui/board_fx.gd")
	var source: Control = null
	var body: Control = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		body = BoardFx.Pudding.make_shadow()
		add_child(body)

	func _process(_delta: float) -> void:
		if not is_instance_valid(source) or source.is_queued_for_deletion():
			queue_free()
			return
		position = source.position + source.get_parent().position
		pivot_offset = source.pivot_offset
		scale = source.scale
		rotation = source.rotation
		modulate = source.modulate


## Một khối trên bàn: Control vẽ bằng BoardFx.draw_block, toạ độ ô tính từ góc trên trái của khối.
class BlockNode extends Control:
	const BoardFx := preload("res://src/ui/board_fx.gd")
	const ThemeKit := preload("res://src/ui/theme_kit.gd")
	var id: String = ""
	var cells: Array = []  # ô theo toạ độ bàn
	var origin_cell: Vector2i = Vector2i.ZERO  # ô nhỏ nhất của khối
	var cell_size: float = 64.0
	var view: Dictionary = {}
	var show_arrow: bool = true
	var glow: float = 0.0
	var busy: bool = false

	var shadow: ShadowNode = null  # null với khối "bóng" trong hiệu ứng
	var _body: Control = null
	var _inner: Array[Control] = []  # viên trong của khối hai lớp, mỗi ô một viên
	var _wobble_tw: Tween = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body = BoardFx.Pudding.make_body()
		add_child(_body)

	func local_cells() -> Array:
		var out: Array = []
		for c in cells:
			out.append(c - origin_cell)
		return out

	func _draw() -> void:
		var lc := local_cells()
		var ramp := BoardFx.block_ramp(view)
		BoardFx.Pudding.update_body(_body, lc, cell_size, ramp, BoardFx.block_overlay(view), glow)
		if shadow != null:
			BoardFx.Pudding.update_body(shadow.body, lc, cell_size, ramp)
		_update_inner(lc)
		BoardFx.draw_block(self, lc, cell_size, view, show_arrow)

	## Nhún như thạch theo trục `axis` (dao động tắt dần), `amp` là độ nén lớn nhất. Khối hẹp trục kia nở ra bù.
	func wobble(axis: Vector2, amp: float, dur: float) -> void:
		if _wobble_tw != null:
			_wobble_tw.kill()
		_wobble_tw = create_tween()
		_wobble_tw.tween_method(_set_wobble.bind(axis, amp), 0.0, 1.0, dur)
		_wobble_tw.tween_callback(func() -> void: scale = Vector2.ONE)

	func _set_wobble(t: float, axis: Vector2, amp: float) -> void:
		var f := amp * exp(-5.5 * t) * cos(t * TAU * 2.4)
		scale = Vector2.ONE - axis * f + Vector2(axis.y, axis.x) * f * 0.65

	func _update_inner(lc: Array) -> void:
		var inner_color := str(view.get("inner_color", ""))
		var want := lc.size() if inner_color != "" and not bool(view.get("is_fog_hidden", false)) else 0
		while _inner.size() < want:
			var b := BoardFx.Pudding.make_inner()
			add_child(b)
			_inner.append(b)
		while _inner.size() > want:
			_inner.pop_back().queue_free()
		for i in want:
			var r := BoardFx.inner_rect(lc[i], cell_size)
			BoardFx.Pudding.update_body(_inner[i], [Vector2i.ZERO], r.size.x, ThemeKit.block_ramp(inner_color), Color(0, 0, 0, 0), glow, r.position)


var arrows_enabled: bool = true
var input_enabled: bool = true

var _board: BoardState = null
var _cell: float = 64.0
var _origin: Vector2 = Vector2.ZERO
var _nodes: Dictionary = {}  # id -> BlockNode
var _owner: Dictionary = {}  # Vector2i -> id
var _gate_state: Dictionary = {}  # cạnh -> đang mở?
var _gate_prog: Dictionary = {}  # cạnh -> 0 (đóng) .. 1 (mở), đang chạy hoạt ảnh
var _gate_tws: Dictionary = {}  # cạnh -> Tween
var _gate_sfx: bool = true
var _gate_flash_tw: Tween = null
var _frame: CandyFrame = null
var _shadow_root: Control = null
var _blocks_root: Control = null
var _links: Control = null
var _fx_root: Control = null
var _pending: int = 0
var _hl_id: String = ""
var _hl_tween: Tween = null
var _shake_tw: Tween = null
var _rng := RandomNumberGenerator.new()

static var _fx_prewarmed: bool = false


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_frame = CandyFrame.new()
	add_child(_frame)
	_shadow_root = _make_layer("Shadows")
	_blocks_root = _make_layer("Blocks")
	_links = _make_layer("Links")
	_links.draw.connect(_draw_links)
	_fx_root = _make_layer("Fx")
	resized.connect(_layout)


func _make_layer(layer_name: String) -> Control:
	var c := Control.new()
	c.name = layer_name
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


## `area` khác 0 thì đặt luôn kích thước vùng vẽ; bàn tự co vừa vùng đó. Không đặt custom_minimum_size để không phình quá vùng chứa.
func setup(board: BoardState, area: Vector2 = Vector2.ZERO) -> void:
	_board = board
	_clear()
	if area != Vector2.ZERO:
		_set_fixed_size(area)
	arrows_enabled = _arrows_setting()
	for id in board.block_ids():
		_add_block(id)
	_gate_state = board.gates()
	_set_gate_progress_now()
	_refresh_keys()
	_layout()
	queue_redraw()
	_prewarm_fx()


## Mỗi phiên chạy một lần: shader hiệu ứng biên dịch lúc vào màn chứ không phải giữa lúc chơi.
func _prewarm_fx() -> void:
	if _fx_prewarmed:
		return
	_fx_prewarmed = true
	CandyShards.prewarm(_fx_root, _cell, ThemeKit.block_ramp("yellow"))
	BoardFx.prewarm_flash(_fx_root)


func fit_to(area: Vector2) -> void:
	_set_fixed_size(area)
	_layout()


## Kích thước cố định: bỏ neo kéo giãn (nếu có) để đặt size không bị ghi đè.
func _set_fixed_size(area: Vector2) -> void:
	if anchor_right != anchor_left or anchor_bottom != anchor_top:
		set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	size = area


func set_arrows(on: bool) -> void:
	arrows_enabled = on
	for id in _nodes:
		_nodes[id].show_arrow = on
		_nodes[id].queue_redraw()


## Đọc lại trạng thái từ board (sau khi cộng MOVES, phá khối, v.v.) không chạy hoạt ảnh.
func refresh() -> void:
	if _board == null:
		return
	_sync_states(false)
	_update_gates(false)


func cell_size() -> float:
	return _cell


## Hình chữ nhật của bàn (không tính khung cổng), toạ độ cục bộ.
func board_rect() -> Rect2:
	if _board == null:
		return Rect2()
	return Rect2(_origin, Vector2(_board.width(), _board.height()) * _cell)


## Trọn khung cổng quanh bàn, toạ độ cục bộ.
func frame_rect() -> Rect2:
	return CandyFrame.outer_rect(board_rect(), _cell)


func cell_center(c: Vector2i) -> Vector2:
	return _origin + (Vector2(c) + Vector2(0.5, 0.5)) * _cell


func block_node(id: String) -> Control:
	return _nodes.get(id, null)


func block_count() -> int:
	return _nodes.size()


## Khối đang chiếm ô tại điểm `pos` (toạ độ cục bộ), "" nếu là ô trống, đá hoặc ngoài bàn.
func block_at(pos: Vector2) -> String:
	if _board == null or _cell <= 0.0:
		return ""
	var rel := (pos - _origin) / _cell
	var c := Vector2i(floori(rel.x), floori(rel.y))
	return str(_owner.get(c, ""))


func is_animating() -> bool:
	return _pending > 0


## Cổng nhịp của cạnh này đang mở (theo board, không chờ hoạt ảnh)?
func gate_is_open(side: String) -> bool:
	return bool(_gate_state.get(side, true))


## Tiến độ hình vẽ của cổng: 0 đóng, 1 mở. Hoạt ảnh xong thì khớp gate_is_open.
func gate_progress(side: String) -> float:
	return float(_gate_prog.get(side, 1.0))


## Các khối đang là chìa của khối bị xích (hiện huy hiệu chìa).
func key_ids() -> Array[String]:
	var out: Array[String] = []
	for id in _nodes:
		if bool(_nodes[id].view.get("is_key", false)):
			out.append(id)
	return out


## Mũi tên hỗ trợ của khối đang hiện? Ẩn khi tắt cài đặt hoặc khi còn trong sương mù.
func arrow_visible(id: String) -> bool:
	var n: BlockNode = _nodes.get(id, null)
	return n != null and BoardFx.arrow_shown(n.view, n.show_arrow)


## Số lớp hiệu ứng "bóng" (băng vỡ, vỏ bóc, sương tan, xích rơi) đang mờ dần.
func ghost_count() -> int:
	var k := 0
	for ch in _fx_root.get_children():
		if ch.name.begins_with(GHOST_NAME) and not ch.is_queued_for_deletion():
			k += 1
	return k


func _arrows_setting() -> bool:
	var st: Variant = Game.s.get("settings", {})
	return bool(st.get("arrows", true)) if st is Dictionary else true


func _clear() -> void:
	clear_highlight()
	for id in _nodes:
		_nodes[id].queue_free()
	_nodes.clear()
	_owner.clear()
	for ch in _shadow_root.get_children():
		ch.queue_free()
	_pending = 0
	for side in _gate_tws:
		var gtw: Tween = _gate_tws[side]
		if gtw != null and gtw.is_valid():
			gtw.kill()
	_gate_tws.clear()
	_gate_prog.clear()
	_gate_state.clear()
	for ch in _fx_root.get_children():
		ch.queue_free()
	_blocks_root.position = Vector2.ZERO


func _add_block(id: String) -> void:
	var v := _board.block_view(id)
	if v.is_empty():
		return
	var n := BlockNode.new()
	n.id = id
	n.cells = v["cells"]
	var mn := Vector2i(1 << 20, 1 << 20)
	for c in n.cells:
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
		_owner[c] = id
	n.origin_cell = mn
	n.view = v
	n.show_arrow = arrows_enabled
	var sh := ShadowNode.new()
	sh.source = n
	n.shadow = sh
	_shadow_root.add_child(sh)
	_blocks_root.add_child(n)
	_nodes[id] = n


func _unmap(id: String) -> void:
	var n: BlockNode = _nodes.get(id, null)
	if n == null:
		return
	for c in n.cells:
		if _owner.get(c, "") == id:
			_owner.erase(c)


func _layout() -> void:
	if _board == null:
		return
	var w := _board.width()
	var h := _board.height()
	if w <= 0 or h <= 0:
		return
	var avail := size
	if avail.x <= 1.0 or avail.y <= 1.0:
		_cell = 64.0
	else:
		# Ô cố định theo bàn tham chiếu; chỉ co thêm khi bàn lớn hơn tham chiếu (không bao giờ phóng to để lấp đầy).
		var m := CandyFrame.margin()
		var ref_cell := minf(avail.x / (REF_COLS + 2.0 * m.x), avail.y / (REF_ROWS + 2.0 * m.y))
		var fit_cell := minf(avail.x / (w + 2.0 * m.x), avail.y / (h + 2.0 * m.y))
		# Làm tròn xuống số nguyên để các ô trong cùng khối khớp pixel, không lộ đường nối.
		_cell = floorf(clampf(minf(ref_cell, fit_cell), 8.0, MAX_CELL))
	_origin = ((avail - Vector2(w, h) * _cell) * 0.5).floor()
	for id in _nodes:
		var n: BlockNode = _nodes[id]
		if n.busy:
			continue
		n.cell_size = _cell
		var bb_max := Vector2i(-(1 << 20), -(1 << 20))
		for c in n.cells:
			bb_max = Vector2i(maxi(bb_max.x, c.x), maxi(bb_max.y, c.y))
		n.size = Vector2(bb_max - n.origin_cell + Vector2i.ONE) * _cell
		n.position = _origin + Vector2(n.origin_cell) * _cell
		n.pivot_offset = n.size * 0.5
		n.queue_redraw()
	_frame.layout(board_rect(), _cell)
	queue_redraw()
	_links.queue_redraw()


# --- vẽ ---

func _draw() -> void:
	if _board == null:
		return
	var br := board_rect()
	# nền bàn: tới đường giữa các thanh khung
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("151A28")
	bg.set_corner_radius_all(int(CandyFrame.TUBE_R * _cell))
	bg.anti_aliasing = true
	draw_style_box(bg, CandyFrame.panel_rect(br, _cell))
	for y in _board.height():
		for x in _board.width():
			var shade := 0.05 if (x + y) % 2 == 0 else 0.09
			draw_rect(Rect2(br.position + Vector2(x, y) * _cell + Vector2(1, 1), Vector2(_cell - 2, _cell - 2)), Color(1, 1, 1, shade))
	# đá
	for s in _board.stones():
		_draw_stone(s)


func _draw_stone(c: Vector2i) -> void:
	var m := _cell * 0.07
	var r := Rect2(_origin + Vector2(c) * _cell + Vector2(m, m), Vector2(_cell - 2 * m, _cell - 2 * m))
	BoardFx.draw_stone(self, r, _cell)


func _draw_links() -> void:
	for id in _nodes:
		var n: BlockNode = _nodes[id]
		var key := str(n.view.get("chained_by", ""))
		if key == "" or not _nodes.has(key) or bool(n.view.get("is_fog_hidden", false)):
			continue
		var k: BlockNode = _nodes[key]
		if bool(k.view.get("is_fog_hidden", false)):
			continue
		var a := cell_center(BoardFx.anchor_cell(n.cells))
		var b := cell_center(BoardFx.anchor_cell(k.cells))
		_links.draw_dashed_line(a, b, Color(1, 1, 1, 0.55), maxf(2.0, _cell * 0.04), _cell * 0.14)
		_links.draw_circle(b, _cell * 0.07, Color(1, 1, 1, 0.8))


# --- chạm ---

func _gui_input(event: InputEvent) -> void:
	if not input_enabled or _board == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := block_at(event.position)
		if id == "":
			return
		accept_event()
		Sfx.play("tap")
		block_tapped.emit(id)


# --- hoạt ảnh ---

func _begin() -> void:
	_pending += 1


func _end() -> void:
	_pending = maxi(0, _pending - 1)
	_check_done()


func _check_done() -> void:
	if _pending == 0:
		animation_done.emit()


## Chạy hoạt ảnh cho kết quả `BoardState.tap`. Board phải đã được cập nhật (tap xong rồi mới gọi).
func apply_result(result: Dictionary) -> void:
	var kind := str(result.get("kind", "rejected"))
	var id := str(result.get("id", ""))
	clear_highlight()
	_gate_sfx = kind != "gate_closed"
	if kind == "rejected" or not _nodes.has(id):
		_after_result(kind != "rejected")
		_check_done.call_deferred()
		return
	var node: BlockNode = _nodes[id]
	var dir: Vector2 = Vector2(LevelData.dir_of(str(node.view.get("color", ""))))
	var dist := int(result.get("distance", 0))
	match kind:
		"exit":
			_anim_exit(node, dir)
		"blocked":
			_anim_bounce(node, dir, float(dist), dist, str(result.get("blocker", "")), "")
		"gate_closed":
			var gate_side := LevelData.side_of(str(node.view.get("color", "")))
			_anim_bounce(node, dir, float(dist) + CandyFrame.gap(gate_side), dist, "", gate_side)
		"chained":
			Sfx.play("chain")
			_anim_chained(node, str(result.get("blocker", "")))
		"crack":
			Sfx.play("ice")
			_anim_pop(node, Color(0.75, 0.92, 1.0), 12)
		"peel":
			Sfx.play("layer")
			_anim_pop(node, ThemeKit.block_color(str(node.view.get("color", ""))), 14)
	_after_result(true)


func _after_result(valid: bool) -> void:
	if not valid or _board == null:
		return
	_sync_states(true)
	_update_gates(true)


## Khối lao nhanh dần tới mặt trong của thanh cùng màu rồi vỡ. Cắt mảnh ngay lúc chạm để lúc vỡ không bị khựng.
func _anim_exit(node: BlockNode, dir: Vector2) -> void:
	_unmap(node.id)
	_nodes.erase(node.id)
	node.busy = true
	_begin()
	var side := LevelData.side_of(str(node.view.get("color", "")))
	var steps := _steps_to_edge(node, dir)
	var travel := (float(steps) + CandyFrame.gap(side)) * _cell
	var time := clampf(SLIDE_MIN + SLIDE_PER_CELL * float(steps), SLIDE_MIN, SLIDE_TIME)
	var polys := CandyShards.fracture(node.local_cells(), dir, _rng)
	var axis := Vector2(absf(dir.x), absf(dir.y))
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "position", node.position + dir * travel, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(node, "scale", Vector2.ONE + axis * SLIDE_STRETCH - Vector2(axis.y, axis.x) * SLIDE_STRETCH * 0.5, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.finished.connect(_shatter.bind(node, dir, side, polys))
	_links.queue_redraw()


## Số ô khối đi được tới khi mép trước chạm mép bàn.
func _steps_to_edge(node: BlockNode, dir: Vector2) -> int:
	var d := Vector2i(dir)
	var steps := 1 << 20
	for c: Vector2i in node.cells:
		if d.x != 0:
			steps = mini(steps, (_board.width() - 1 - c.x) if d.x > 0 else c.x)
		else:
			steps = mini(steps, (_board.height() - 1 - c.y) if d.y > 0 else c.y)
	return steps


## Giữa mép trước của khối theo hướng `dir`, px theo toạ độ của khối.
func _leading_point(lc: Array, dir: Vector2) -> Vector2:
	var best := -INF
	var sum := Vector2.ZERO
	var n := 0
	for c: Vector2i in lc:
		var edge := Vector2(c) + Vector2(0.5, 0.5) + dir * 0.5
		var v := edge.dot(dir)
		if v > best + 0.01:
			best = v
			sum = edge
			n = 1
		elif v > best - 0.01:
			sum += edge
			n += 1
	return sum / float(n) * _cell


func _shatter(node: BlockNode, dir: Vector2, side: String, polys: Array[PackedVector2Array]) -> void:
	var ramp := ThemeKit.block_ramp(str(node.view.get("color", "")))
	var lc := node.local_cells()
	var xf := node.get_global_transform()
	var impact := xf * _leading_point(lc, dir)
	var burst := CandyShards.shatter(_fx_root, polys, lc, _cell, ramp, xf, dir, impact, _rng)
	burst.settled.connect(_end, CONNECT_ONE_SHOT)
	BoardFx.impact_flash(_fx_root, impact, ramp["stripe"], _cell * FLASH_SHATTER)
	BoardFx.sparkles(_fx_root, impact, ramp, dir, _cell / 60.0, SPARKS_SHATTER)
	_frame.hit(side, get_global_transform().affine_inverse() * impact)
	Sfx.play_or("shatter", "exit")
	_shake_root(Vector2(absf(dir.x), absf(dir.y)))
	# khối giữ thêm một khung vì mảnh chỉ hiện từ khung sau; hai lớp trùng khít nên không lộ, còn bóng đổ thì bỏ ngay
	node.shadow.hide()
	get_tree().process_frame.connect(node.queue_free, CONNECT_ONE_SHOT)
	_links.queue_redraw()


func _finish_exit(node: BlockNode) -> void:
	node.queue_free()
	_end()


## Lao nhanh dần tới vật cản, va, bật về chỗ cũ. Rung nhẹ cả bàn; không màn đỏ.
func _anim_bounce(node: BlockNode, dir: Vector2, cells_to_go: float, steps: int, blocker: String, gate_side: String) -> void:
	var home := node.position
	var travel := maxf(cells_to_go, 0.0) * _cell
	if cells_to_go < 0.5:
		travel = _cell * 0.12
	var go_time := clampf(0.05 + 0.03 * cells_to_go, 0.07, 0.22)
	node.busy = true
	_begin()
	var tw := node.create_tween()
	tw.tween_property(node, "position", home + dir * travel, go_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_impact.bind(node, dir, steps, blocker, gate_side))
	# không dùng TRANS_BACK: đà vượt quá chỗ cũ sẽ đè lên khối phía sau, độ nảy đã có wobble lo
	tw.tween_property(node, "position", home, BOUNCE_BACK).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.finished.connect(_finish_busy.bind(node))


func _finish_busy(node: BlockNode) -> void:
	if is_instance_valid(node):
		node.busy = false
		node.pivot_offset = node.size * 0.5
	_end()


## Điểm chạm theo toạ độ ô của khối (lúc còn ở chỗ cũ): giữa các mép trước đang đụng vật cản.
func _contact_local(node: BlockNode, steps: int, dir: Vector2, blocker: String) -> Vector2:
	if blocker != "":
		var d := Vector2i(dir)
		var stones := _board.stones()
		var sum := Vector2.ZERO
		var n := 0
		for c: Vector2i in node.cells:
			var next := c + d * (steps + 1)
			var hit: bool = stones.has(next) if blocker == LevelData.STONE else str(_owner.get(next, "")) == blocker
			if hit:
				sum += Vector2(c - node.origin_cell) + Vector2(0.5, 0.5) + dir * 0.5
				n += 1
		if n > 0:
			return sum / float(n)
	return _leading_point(node.local_cells(), dir) / _cell


## Khoảnh khắc va chạm: khối nhún ép vào vật cản, vụn kẹo và sao văng ra ở điểm chạm, khối bị va giật lùi và nhún theo.
func _impact(node: BlockNode, dir: Vector2, steps: int, blocker: String, gate_side: String) -> void:
	var axis := Vector2(absf(dir.x), absf(dir.y))
	_shake_root(axis)
	var ramp := BoardFx.block_ramp(node.view)
	var at := _contact_local(node, steps, dir, blocker)
	var xf := node.get_global_transform()
	var world := xf * (at * _cell)
	CandyShards.chips(_fx_root, node.local_cells(), _cell, ramp, xf, at, dir, CHIPS_BUMP, _rng)
	BoardFx.impact_flash(_fx_root, world, ramp["stripe"], _cell * FLASH_BUMP, 0.26, 0.55)
	BoardFx.sparkles(_fx_root, world, ramp, -dir, _cell / 95.0, SPARKS_BUMP)
	node.pivot_offset = at * _cell
	node.wobble(axis, WOBBLE_SELF, WOBBLE_TIME)
	if gate_side != "":
		Sfx.play("gate")
		_frame.hit(gate_side, get_global_transform().affine_inverse() * world, 0.7)
		_flash_gates()
	elif blocker == LevelData.STONE:
		Sfx.play("stone")
	else:
		Sfx.play_or("bump", "blocked")
		if _nodes.has(blocker):
			var b: BlockNode = _nodes[blocker]
			var bxf := b.get_global_transform()
			CandyShards.chips(_fx_root, b.local_cells(), _cell, BoardFx.block_ramp(b.view), bxf, bxf.affine_inverse() * world / _cell, -dir, CHIPS_BUMP, _rng)
			_jolt(b, dir, 1.0, 0.0)
			_ripple(b, dir)


## Khối bị va giật lùi rồi về đúng ô của nó và nhún theo; `power` giảm dần khi lan ra xa.
func _jolt(b: BlockNode, dir: Vector2, power: float, delay: float) -> void:
	if b.busy:
		return
	var home := _origin + Vector2(b.origin_cell) * _cell
	var tw := b.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_callback(b.wobble.bind(Vector2(absf(dir.x), absf(dir.y)), WOBBLE_BLOCKER * power, WOBBLE_TIME))
	tw.tween_property(b, "position", home + dir * _cell * JOLT * power, 0.05)
	tw.tween_property(b, "position", home, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Dư chấn lan sang các khối nằm ngay sau khối bị va, theo đúng hướng va.
func _ripple(start: BlockNode, dir: Vector2) -> void:
	var d := Vector2i(dir)
	var seen := {start.id: true}
	var front: Array = start.cells
	var power := RIPPLE_FADE
	for depth in RIPPLE_DEPTH:
		var next_id := ""
		for c: Vector2i in front:
			var o := str(_owner.get(c + d, ""))
			if o != "" and not seen.has(o):
				next_id = o
				break
		if next_id == "":
			return
		seen[next_id] = true
		var n: BlockNode = _nodes[next_id]
		_jolt(n, dir, power, RIPPLE_DELAY * float(depth + 1))
		front = n.cells
		power *= RIPPLE_FADE


func _shake_root(axis: Vector2) -> void:
	if _shake_tw != null:
		_shake_tw.kill()
	_blocks_root.position = Vector2.ZERO
	_shake_tw = BoardFx.shake(_blocks_root, maxf(3.0, _cell * 0.05), 0.14, axis)


func _anim_chained(node: BlockNode, key_id: String) -> void:
	node.busy = true
	_begin()
	var home := node.position
	var tw := node.create_tween()
	for s in [1.0, -1.0, 0.6, -0.6]:
		tw.tween_property(node, "position", home + Vector2(_cell * 0.07 * s, 0), 0.04)
	tw.tween_property(node, "position", home, 0.04)
	tw.finished.connect(_finish_busy.bind(node))
	# chỉ khối chìa để người chơi thấy cần mở cái nào
	if _nodes.has(key_id):
		var k: BlockNode = _nodes[key_id]
		if not k.busy:
			k.pivot_offset = k.size * 0.5
			var kt := k.create_tween()
			kt.tween_property(k, "scale", Vector2(1.1, 1.1), 0.12).set_trans(Tween.TRANS_SINE)
			kt.tween_property(k, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE)


## Nảy to rồi về, kèm hạt: băng nứt, bóc lớp.
func _anim_pop(node: BlockNode, col: Color, amount: int) -> void:
	node.busy = true
	node.pivot_offset = node.size * 0.5
	_begin()
	node.glow = 1.0
	node.queue_redraw()
	BoardFx.burst(_fx_root, node.position + node.size * 0.5, col, Vector2.ZERO, _cell / 110.0, amount)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(1.12, 1.12), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.finished.connect(_finish_pop.bind(node))


func _finish_pop(node: BlockNode) -> void:
	if is_instance_valid(node):
		node.glow = 0.0
		node.queue_redraw()
	_finish_busy(node)


## Đọc lại màu, băng, xích, sương mù từ board; khối nào đổi thì vẽ lại và có hiệu ứng nhẹ.
func _sync_states(animate: bool) -> void:
	for id in _nodes.keys():
		var n: BlockNode = _nodes[id]
		var v := _board.block_view(id)
		if v.is_empty():
			continue
		var old := n.view
		var changed := false
		for k in ["color", "ice", "chained", "inner_color", "is_fog_hidden"]:
			if old.get(k) != v.get(k):
				changed = true
		if not changed:
			continue
		n.view = v
		n.queue_redraw()
		if not animate:
			continue
		if bool(old.get("is_fog_hidden", false)) and not bool(v.get("is_fog_hidden", false)):
			Sfx.play("fog")
			_reveal_pop(n)
			_spawn_ghost(n, old, 1.0, 0.35)
		if bool(old.get("chained", false)) and not bool(v.get("chained", false)):
			Sfx.play("chain")
			BoardFx.burst(_fx_root, cell_center(BoardFx.anchor_cell(n.cells)), Color(0.85, 0.88, 0.95), Vector2.ZERO, _cell / 120.0, 10)
			_spawn_ghost(n, old, 1.0, 0.3)
		if int(old.get("ice", 0)) > int(v.get("ice", 0)):
			BoardFx.burst(_fx_root, n.position + n.size * 0.5, Color(0.8, 0.94, 1.0), Vector2.ZERO, _cell / 100.0, 16)
			_spawn_ghost(n, old, 1.06, 0.3)
		if str(old.get("inner_color", "")) != "" and str(v.get("inner_color", "")) == "":
			var shell := old.duplicate()
			shell["inner_color"] = ""
			_spawn_ghost(n, shell, 1.3, 0.3)
	_refresh_keys()
	_links.queue_redraw()


## Bản sao khối ở trạng thái cũ, mờ dần (và to ra) phía trên: băng vỡ, vỏ bóc, sương tan, xích rơi.
func _spawn_ghost(n: BlockNode, old_view: Dictionary, grow: float, dur: float) -> void:
	var g := BlockNode.new()
	g.name = GHOST_NAME
	g.cells = n.cells
	g.origin_cell = n.origin_cell
	g.cell_size = _cell
	g.view = old_view
	g.show_arrow = n.show_arrow
	g.size = n.size
	g.position = n.position
	g.pivot_offset = n.size * 0.5
	_fx_root.add_child(g)
	_begin()
	var tw := g.create_tween().set_parallel(true)
	tw.tween_property(g, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if grow > 1.0:
		tw.tween_property(g, "scale", Vector2(grow, grow), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.finished.connect(_finish_exit.bind(g))


## Đánh dấu khối nào đang là chìa của một khối còn bị xích.
func _refresh_keys() -> void:
	var keys := {}
	for id in _nodes:
		var v: Dictionary = _nodes[id].view
		if bool(v.get("chained", false)):
			keys[str(v.get("chained_by", ""))] = true
	for id in _nodes:
		var n: BlockNode = _nodes[id]
		var want: bool = keys.has(id)
		if bool(n.view.get("is_key", false)) != want:
			n.view["is_key"] = want
			n.queue_redraw()


func _reveal_pop(n: BlockNode) -> void:
	n.pivot_offset = n.size * 0.5
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2(1.08, 1.08), 0.1)
	tw.tween_property(n, "scale", Vector2.ONE, 0.12)


func _set_gate_progress_now() -> void:
	for side in CandyFrame.SIDES:
		_gate_prog[side] = 1.0 if bool(_gate_state.get(side, true)) else 0.0
		_frame.set_gate(side, _gate_prog[side])


func _update_gates(animate: bool) -> void:
	var now := _board.gates()
	var changed := false
	for side in now:
		if _gate_state.get(side, true) != now[side]:
			changed = true
			_tween_gate(str(side), bool(now[side]), animate)
	_gate_state = now
	if not animate:
		_set_gate_progress_now()
	elif changed:
		_flash_gates()
		if _gate_sfx and is_inside_tree():
			get_tree().create_timer(0.1).timeout.connect(Sfx.play.bind("gate"))


func _tween_gate(side: String, open: bool, animate: bool) -> void:
	var old_tw: Tween = _gate_tws.get(side, null)
	if old_tw != null and old_tw.is_valid() and old_tw.is_running():
		old_tw.kill()
		_end()
	var to := 1.0 if open else 0.0
	if not animate:
		_gate_prog[side] = to
		_frame.set_gate(side, to)
		return
	_begin()
	var tw := create_tween()
	_gate_tws[side] = tw
	tw.tween_method(_set_gate_prog.bind(side), float(_gate_prog.get(side, 1.0 - to)), to, GATE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.finished.connect(_end)


func _set_gate_prog(v: float, side: String) -> void:
	_gate_prog[side] = v
	_frame.set_gate(side, v)


func _flash_gates() -> void:
	if _gate_flash_tw != null:
		_gate_flash_tw.kill()
	_frame.set_flash(1.0)
	_gate_flash_tw = create_tween()
	_gate_flash_tw.tween_method(_frame.set_flash, 1.0, 0.0, 0.25)


## Làm khối nhấp nháy (Gợi ý) cho tới lần chạm kế tiếp hoặc clear_highlight().
func highlight(id: String) -> void:
	clear_highlight()
	if not _nodes.has(id):
		return
	var n: BlockNode = _nodes[id]
	_hl_id = id
	n.glow = 1.0
	n.queue_redraw()
	_hl_tween = BoardFx.pulse(n)
	Sfx.play("hint")


func highlighted_id() -> String:
	return _hl_id


func clear_highlight() -> void:
	if _hl_tween != null:
		_hl_tween.kill()
		_hl_tween = null
	if _hl_id != "" and _nodes.has(_hl_id):
		var n: BlockNode = _nodes[_hl_id]
		n.scale = Vector2.ONE
		n.glow = 0.0
		n.queue_redraw()
	_hl_id = ""


## Phá khối: thu nhỏ, xoay, nổ hạt rồi biến mất. Gọi sau (hoặc trước) board.smash(id).
func smash_anim(id: String) -> void:
	if not _nodes.has(id):
		_check_done.call_deferred()
		return
	if _hl_id == id:
		clear_highlight()
	var n: BlockNode = _nodes[id]
	var col := ThemeKit.block_color(str(n.view.get("color", "")))
	var center := n.position + n.size * 0.5
	_unmap(id)
	_nodes.erase(id)
	n.busy = true
	n.pivot_offset = n.size * 0.5
	_begin()
	Sfx.play("smash")
	_shake_root(Vector2(1, 1))
	BoardFx.burst(_fx_root, center, col, Vector2.ZERO, _cell / 80.0, 24)
	var tw := n.create_tween().set_parallel(true)
	tw.tween_property(n, "scale", Vector2(0.1, 0.1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(n, "rotation", 0.6, 0.3)
	tw.tween_property(n, "modulate:a", 0.0, 0.2).set_delay(0.1)
	tw.finished.connect(_finish_exit.bind(n))
	if _board != null:
		_sync_states(true)
	_links.queue_redraw()
