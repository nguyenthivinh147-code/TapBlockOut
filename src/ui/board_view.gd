extends Control
## Vẽ bàn cờ: lưới, cổng liền bốn cạnh theo màu, đá, khối bo góc; nhận chạm; chạy hoạt ảnh kết quả.
## Dùng: setup(board) rồi nối block_tapped; level gọi board.tap(id) và đưa kết quả vào apply_result().
## Tự co theo `size` của chính nó (hoặc setup(board, area)); đổi size thì tự xếp lại.

const BoardState := preload("res://src/core/board_state.gd")
const BoardFx := preload("res://src/ui/board_fx.gd")
const LevelData := preload("res://src/core/level_data.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")

## Khối chạm vào (đã là ô của khối, không phải đá hay ô trống).
signal block_tapped(id: String)
## Mọi hoạt ảnh đang chạy đã xong.
signal animation_done

const MAX_CELL := 150.0
const GATE_RATIO := 0.3
## Bàn tham chiếu (lớn nhất trong 100 level): kích thước ô tính theo bàn này để mọi level dùng cùng một cỡ ô.
const REF_COLS := 8
const REF_ROWS := 11
const SLIDE_TIME := 0.30
const GATE_TIME := 0.22
const GHOST_NAME := "Ghost"
const SIDE_OF_DIR := {"up": Vector2(0, -1), "left": Vector2(-1, 0), "right": Vector2(1, 0), "down": Vector2(0, 1)}
const SIDE_COLOR := {"up": "yellow", "left": "green", "right": "blue", "down": "purple"}


## Một khối trên bàn: Control vẽ bằng BoardFx.draw_block, toạ độ ô tính từ góc trên trái của khối.
class BlockNode extends Control:
	const BoardFx := preload("res://src/ui/board_fx.gd")
	var id: String = ""
	var cells: Array = []  # ô theo toạ độ bàn
	var origin_cell: Vector2i = Vector2i.ZERO  # ô nhỏ nhất của khối
	var cell_size: float = 64.0
	var view: Dictionary = {}
	var show_arrow: bool = true
	var glow: float = 0.0
	var busy: bool = false

	var _body: Control = null

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
		BoardFx.Pudding.update_body(_body, lc, cell_size, BoardFx.block_base_color(view))
		BoardFx.draw_block(self, lc, cell_size, view, show_arrow)
		if glow > 0.0:
			for c in lc:
				draw_rect(Rect2(c.x * cell_size + 3, c.y * cell_size + 3, cell_size - 6, cell_size - 6), Color(1, 1, 1, 0.28 * glow))


var arrows_enabled: bool = true
var input_enabled: bool = true

var _board: BoardState = null
var _cell: float = 64.0
var _origin: Vector2 = Vector2.ZERO
var _inner: Rect2 = Rect2()  # vùng trong khung cổng (cố định), lưới level nằm giữa vùng này
var _nodes: Dictionary = {}  # id -> BlockNode
var _owner: Dictionary = {}  # Vector2i -> id
var _vacated: Dictionary = {}  # Vector2i -> true: ô của khối đã đi, không vẽ nền nữa
var _gate_state: Dictionary = {}  # cạnh -> đang mở?
var _gate_prog: Dictionary = {}  # cạnh -> 0 (đóng) .. 1 (mở), đang chạy hoạt ảnh
var _gate_tws: Dictionary = {}  # cạnh -> Tween
var _gate_sfx: bool = true
var _gate_flash: float = 0.0
var _gate_flash_tw: Tween = null
var _blocks_root: Control = null
var _links: Control = null
var _fx_root: Control = null
var _pending: int = 0
var _hl_id: String = ""
var _hl_tween: Tween = null
var _shake_tw: Tween = null


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
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
	_vacated.clear()
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
	_blocks_root.add_child(n)
	_nodes[id] = n


func _unmap(id: String) -> void:
	var n: BlockNode = _nodes.get(id, null)
	if n == null:
		return
	for c in n.cells:
		if _owner.get(c, "") == id:
			_owner.erase(c)
			_vacated[c] = true
	queue_redraw()


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
		var ref_cell := minf(avail.x / (REF_COLS + 2.0 * GATE_RATIO), avail.y / (REF_ROWS + 2.0 * GATE_RATIO))
		var fit_cell := minf(avail.x / (w + 2.0 * GATE_RATIO), avail.y / (h + 2.0 * GATE_RATIO))
		# Làm tròn xuống số nguyên để các ô trong cùng khối khớp pixel, không lộ đường nối.
		_cell = floorf(clampf(minf(ref_cell, fit_cell), 8.0, MAX_CELL))
	# Khung cố định theo bàn tham chiếu (chỉ nở ra khi bàn lớn hơn), căn giữa vùng; lưới level căn giữa trong khung.
	var frame_cells := Vector2(maxi(w, REF_COLS), maxi(h, REF_ROWS))
	var frame_px := frame_cells * _cell
	_inner = Rect2(((avail - frame_px) * 0.5).floor(), frame_px)
	_origin = (_inner.position + (frame_px - Vector2(w, h) * _cell) * 0.5).floor()
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
	queue_redraw()
	_links.queue_redraw()


# --- vẽ ---

func _draw() -> void:
	if _board == null:
		return
	var cells_rect := board_rect()
	var br := _inner
	var g := _cell * GATE_RATIO
	var outer := br.grow(g)
	# nền bàn
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("151A28")
	bg.set_corner_radius_all(int(g * 0.5))
	draw_style_box(bg, outer)
	for y in _board.height():
		for x in _board.width():
			if _vacated.has(Vector2i(x, y)):
				continue
			var shade := 0.05 if (x + y) % 2 == 0 else 0.09
			draw_rect(Rect2(cells_rect.position + Vector2(x, y) * _cell + Vector2(1, 1), Vector2(_cell - 2, _cell - 2)), Color(1, 1, 1, shade))
	# đá
	for s in _board.stones():
		_draw_stone(s)
	# khung: bốn cạnh, mỗi cạnh một màu, vát chéo ở góc
	var o_tl := outer.position
	var o_tr := Vector2(outer.end.x, outer.position.y)
	var o_bl := Vector2(outer.position.x, outer.end.y)
	var o_br := outer.end
	var i_tl := br.position
	var i_tr := Vector2(br.end.x, br.position.y)
	var i_bl := Vector2(br.position.x, br.end.y)
	var i_br := br.end
	_draw_gate("up", PackedVector2Array([o_tl, o_tr, i_tr, i_tl]), br, g)
	_draw_gate("left", PackedVector2Array([o_tl, i_tl, i_bl, o_bl]), br, g)
	_draw_gate("right", PackedVector2Array([o_tr, o_br, i_br, i_tr]), br, g)
	_draw_gate("down", PackedVector2Array([o_bl, i_bl, i_br, o_br]), br, g)


func _draw_stone(c: Vector2i) -> void:
	var m := _cell * 0.07
	var r := Rect2(_origin + Vector2(c) * _cell + Vector2(m, m), Vector2(_cell - 2 * m, _cell - 2 * m))
	BoardFx.draw_stone(self, r, _cell)


func _draw_gate(side: String, poly: PackedVector2Array, br: Rect2, g: float) -> void:
	var prog := gate_progress(side)
	var col := ThemeKit.block_color(SIDE_COLOR[side]).darkened(0.55 * (1.0 - prog))
	draw_colored_polygon(poly, col)
	var mid_a := Vector2.ZERO
	var mid_b := Vector2.ZERO
	match side:
		"up":
			mid_a = Vector2(br.position.x, br.position.y - g * 0.5)
			mid_b = Vector2(br.end.x, br.position.y - g * 0.5)
		"down":
			mid_a = Vector2(br.position.x, br.end.y + g * 0.5)
			mid_b = Vector2(br.end.x, br.end.y + g * 0.5)
		"left":
			mid_a = Vector2(br.position.x - g * 0.5, br.position.y)
			mid_b = Vector2(br.position.x - g * 0.5, br.end.y)
		_:
			mid_a = Vector2(br.end.x + g * 0.5, br.position.y)
			mid_b = Vector2(br.end.x + g * 0.5, br.end.y)
	BoardFx.draw_gate_mark(self, side, mid_a, mid_b, g, col, prog)
	if _gate_flash > 0.0:
		draw_colored_polygon(poly, Color(1, 1, 1, 0.55 * _gate_flash))


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
			_anim_exit(node, dir, maxi(dist, 1))
		"blocked":
			var blocker := str(result.get("blocker", ""))
			Sfx.play("stone" if blocker == LevelData.STONE else "blocked")
			_anim_bounce(node, dir, float(dist), blocker, "")
		"gate_closed":
			Sfx.play("gate")
			_anim_bounce(node, dir, float(dist), "", LevelData.side_of(str(node.view.get("color", ""))))
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


func _anim_exit(node: BlockNode, dir: Vector2, dist: int) -> void:
	Sfx.play("exit")
	var id := node.id
	var home_center := node.position + node.size * 0.5
	_unmap(id)
	_nodes.erase(id)
	node.busy = true
	_begin()
	var col := ThemeKit.block_color(str(node.view.get("color", "")))
	var target := node.position + dir * _cell * float(dist + 1)
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "position", target, SLIDE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 0.0, 0.14).set_delay(SLIDE_TIME - 0.14)
	tw.tween_callback(_burst_at_edge.bind(home_center, dir, col)).set_delay(0.08)
	tw.finished.connect(_finish_exit.bind(node))
	_links.queue_redraw()


func _finish_exit(node: BlockNode) -> void:
	node.queue_free()
	_end()


func _burst_at_edge(center: Vector2, dir: Vector2, col: Color) -> void:
	var r := _inner
	var p := center
	if dir.x > 0:
		p.x = r.end.x
	elif dir.x < 0:
		p.x = r.position.x
	elif dir.y > 0:
		p.y = r.end.y
	else:
		p.y = r.position.y
	BoardFx.burst(_fx_root, p, col, dir, _cell / 90.0)


## Trượt tới vật cản (dist ô), va, bật về chỗ cũ. Rung nhẹ cả bàn; không màn đỏ.
func _anim_bounce(node: BlockNode, dir: Vector2, dist: float, blocker: String, gate_side: String) -> void:
	var home := node.position
	var travel := maxf(dist, 0.0) * _cell
	if dist < 0.5:
		travel = _cell * 0.12
	var go_time := clampf(0.05 + 0.03 * dist, 0.07, 0.22)
	node.busy = true
	_begin()
	var tw := node.create_tween()
	tw.tween_property(node, "position", home + dir * travel, go_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_impact.bind(dir, blocker, gate_side))
	tw.tween_property(node, "position", home, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.finished.connect(_finish_busy.bind(node))


func _finish_busy(node: BlockNode) -> void:
	if is_instance_valid(node):
		node.busy = false
	_end()


func _impact(dir: Vector2, blocker: String, gate_side: String) -> void:
	_shake_root(Vector2(absf(dir.x), absf(dir.y)))
	if blocker != "" and _nodes.has(blocker):
		var b: BlockNode = _nodes[blocker]
		if not b.busy:
			var home := b.position
			var tw := b.create_tween()
			tw.tween_property(b, "position", home + dir * _cell * 0.1, 0.05)
			tw.tween_property(b, "position", home, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if gate_side != "":
		_flash_gates()


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
	for side in _gate_state:
		_gate_prog[side] = 1.0 if bool(_gate_state[side]) else 0.0


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
	queue_redraw()


func _tween_gate(side: String, open: bool, animate: bool) -> void:
	var old_tw: Tween = _gate_tws.get(side, null)
	if old_tw != null and old_tw.is_valid() and old_tw.is_running():
		old_tw.kill()
		_end()
	var to := 1.0 if open else 0.0
	if not animate:
		_gate_prog[side] = to
		return
	_begin()
	var tw := create_tween()
	_gate_tws[side] = tw
	tw.tween_method(_set_gate_prog.bind(side), float(_gate_prog.get(side, 1.0 - to)), to, GATE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.finished.connect(_end)


func _set_gate_prog(v: float, side: String) -> void:
	_gate_prog[side] = v
	queue_redraw()


func _flash_gates() -> void:
	if _gate_flash_tw != null:
		_gate_flash_tw.kill()
	_gate_flash = 1.0
	_gate_flash_tw = create_tween()
	_gate_flash_tw.tween_method(_set_gate_flash, 1.0, 0.0, 0.25)


func _set_gate_flash(v: float) -> void:
	_gate_flash = v
	queue_redraw()


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
