extends Control
## Vẽ bàn cờ: nền trơn, thùng sắt, khối bo góc, khung cổng (`CandyFrame`); nhận chạm; chạy hoạt ảnh kết quả.
## Dùng: setup(board) rồi nối block_tapped; level gọi board.tap(id) và đưa kết quả vào apply_result().
## Khung cổng và các lớp (Shadows, Blocks, Fx) nằm sẵn trong scenes/board_view.tscn; khối, nền bàn, thùng sắt và hiệu ứng
## sinh hoặc vẽ lúc chạy theo bàn.
## Khung cổng cố định theo màn (Config.BOARD_AREA ở màn chuẩn), chỉ co khi vùng chứa (`size` hoặc setup(board, area)) nhỏ
## hơn khung; cỡ ô theo hình của level, to nhất Config.BOARD_CELL_MAX. Đổi size thì tự xếp lại.

const BoardState := preload("res://src/core/board_state.gd")
const BoardFx := preload("res://src/ui/board_fx.gd")
const LevelData := preload("res://src/core/level_data.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const CandyFrame := preload("res://src/ui/candy_frame.gd")
const CandyShards := preload("res://src/ui/candy_shards.gd")
const SuckWind := preload("res://src/ui/suck_wind.gd")
const ObstacleFx := preload("res://src/ui/obstacle_fx.gd")
const CrystalGrind := preload("res://src/ui/crystal_grind.gd")
const HintGlitter := preload("res://src/ui/hint_glitter.gd")
const Config := preload("res://src/config.gd")

## Khối chạm vào (đã là ô của khối, không phải đá hay ô trống).
signal block_tapped(id: String)
## Mọi hoạt ảnh đang chạy đã xong.
signal animation_done

const SLIDE_TIME := 0.35  # lâu nhất của một lần khối lao tới thanh
const SLIDE_MIN := 0.20  # đường ngắn nhất vẫn đủ thấy khối lấy đà
const SLIDE_PER_CELL := 0.026
const SLIDE_STRETCH := 0.09  # khối dài ra theo hướng lao, hẹp lại phía ngang
const EXIT_BRAKE := 0.3  # giây cuối trước khi chạm thanh: khối thoát chậm dần đều về GRIND_SPEED để trôi êm vào thanh; khối cuối trên bàn không hãm
const SUCK_WHITE := 0.4  # vệt gió hút: màu thanh pha trắng chừng này
const SUCK_LEAD := 0.2  # vệt gió hút bắt đầu chừng này giây trước khi khối chạm thanh, kéo dài tới lúc nghiền xong
const BOUNCE_BACK := 0.24
const WOBBLE_TIME := 0.46
const WOBBLE_SELF := 0.15  # độ nhún của khối đi va
const WOBBLE_BLOCKER := 0.1  # độ nhún của khối bị va
const JOLT := 0.1  # khối bị va lùi chừng này ô
const RIPPLE_DEPTH := 2  # dư chấn lan sang thêm chừng này khối phía sau
const RIPPLE_DELAY := 0.05
const RIPPLE_FADE := 0.5
const CHIPS_BUMP := 4  # số vụn kẹo mỗi khối lúc va chạm
const FLASH_BUMP := 1.8  # cỡ loé sáng, theo ô
const SPARKS_BUMP := 4
const SPARK_SCALE_BUMP := 115.0  # sao lấp lánh: độ mạnh = ô / số này (tầm bay và cỡ sao)
const GRIND_SPEED := 9.0  # ô/giây, khối trôi qua thanh để bị nghiền
const GRIND_BITS := 15  # mảnh to của khối rộng 1 ô (bề ngang = số cột ô khối phủ dọc thanh); khối dài hay ngắn theo hướng đi cũng vậy
const GRIND_SMALL := 10  # mảnh nhỏ của khối rộng 1 ô
const GRIND_BITS_EXTRA := 0.5  # mỗi ô bề ngang thêm ra thêm chừng này lần số mảnh to và nhỏ của khối rộng 1 ô: rộng 2 ô ra 23 to, 15 nhỏ
const GRIND_STAGGER := 0.4  # khối vuông ra lệch ra ngoài thanh ngẫu nhiên tới chừng này, theo ô, cho thưa
const GRIND_GOLDEN := 0.618034  # dãy tỉ lệ vàng: khối vuông kế tiếp lệch ngang chừng này phần bề ngang, rải đều không chụm
const GRIND_SPARKS := 6
const GRIND_SPARK_SCALE := 110.0
const GRIND_SETTLE := 0.25  # giây sau khi nghiền xong thì báo xong; vụn còn lại vẫn bay tiếp
const SHAKE_SMASH := 0.2  # bàn rung theo búa gõ, theo ô
const FLASH_SMASH := 3.0
const SPARKS_SMASH := 10
const SPARK_SCALE_SMASH := 90.0
const SMASH_SETTLE := 0.3  # giây sau cú gõ thì báo xong; mảnh vỡ còn bay tiếp
const CRYSTAL_STRUCK := 0.7  # khối crystal bị va: mảnh kính, loé, sao yếu hơn lúc chính nó va chừng này
const CRYSTAL_GRIND_GLINTS := 0.8  # mảnh kính lúc khối crystal bắt đầu qua thanh (theo lúc va)
const CRYSTAL_SMASH_GLINTS := 1.6  # mảnh kính toả tròn lúc khối crystal bị búa gõ
const GATE_TIME := 0.22
const CRATE_KNOCK := 0.42  # giây thùng sắt rung và loé khi bị gõ
const JELLY_JOLT := 2.2  # khối phủ pudding bị va nhún mạnh gấp chừng này khối thường
const FOG_LIFT_GROW := 1.15  # sương tan: lớp sương phồng ra chừng này lần trong lúc mờ đi
const FOG_LIFT_TIME := 0.45
const FOG_NUDGE := 0.05  # chạm khối còn trong sương: lắc ngang tại chỗ chừng này ô
const BOX_FLY_MIN := 0.22  # giây ngắn nhất hộp giấy bay tới thanh
const HINT_POP := 1.22  # khối được Gợi ý nảy to chừng này lúc sao chạm
const HINT_POP_GLOW := 3.0  # độ loé trắng lúc chạm, tắt dần về mức nhấp nháy (1)
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
	var id: String = ""
	var cells: Array = []  # ô theo toạ độ bàn
	var origin_cell: Vector2i = Vector2i.ZERO  # ô nhỏ nhất của khối
	var cell_size: float = 64.0
	var view: Dictionary = {}
	var glow: float = 0.0
	var busy: bool = false

	var shadow: ShadowNode = null  # null với khối "bóng" trong hiệu ứng
	var _body: Control = null
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

	## Khối "bóng" của hiệu ứng có thể chỉ vẽ một lớp: `jelly_only` (lớp pudding vỡ), `chain_only` (xích đứt),
	## `fog_only` (sương tan). Lớp sương phủ đặt theo ô gốc trên bàn nên sương liền qua các khối sương kề nhau.
	func _draw() -> void:
		var lc := local_cells()
		var ramp := BoardFx.block_ramp(view)
		var layers := BoardFx.block_layers(view)
		BoardFx.Pudding.update_body(_body, lc, cell_size, ramp, Color(0, 0, 0, 0), glow)
		var fog_only := bool(view.get("fog_only", false))
		var fogged := fog_only or bool(view.get("is_fog_hidden", false))
		BoardFx.set_fog(_body, 1.0 if fogged else 0.0, Vector2(origin_cell))
		if fog_only:
			BoardFx.Pudding.set_layers(_body, 0.0, 0.0, Vector2(-9, -9), 0.0)
			BoardFx.Pudding.set_crystal(_body, 0.0)
			return
		if bool(view.get("chain_only", false)):
			BoardFx.Pudding.set_layers(_body, 0.0, 0.0, Vector2(-9, -9), 0.0)
			BoardFx.draw_chain(self, lc, cell_size)
			BoardFx.draw_lock(self, BoardFx.chain_center(lc) * cell_size, cell_size)
			return
		var tape := BoardFx.tape_center(lc) if layers["paper"] > 0.0 else Vector2(-9, -9)
		var jelly_only := bool(view.get("jelly_only", false))
		BoardFx.Pudding.set_layers(_body, layers["jelly"], layers["paper"], tape, 0.0 if jelly_only else 1.0)
		BoardFx.Pudding.set_crystal(_body, layers["crystal"])
		if shadow != null:
			BoardFx.Pudding.update_body(shadow.body, lc, cell_size, ramp)
			BoardFx.Pudding.set_layers(shadow.body, layers["jelly"], 0.0)
		if not jelly_only:
			BoardFx.draw_block(self, lc, cell_size, view)

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


var input_enabled: bool = true

var _board: BoardState = null
var _cell: float = 64.0  # cỡ ô khối, theo hình của level
var _unit: float = Config.BOARD_FRAME_UNIT  # đơn vị đo khung cổng (CandyFrame), theo màn
var _area: Rect2 = Rect2()  # vùng khung cổng bao quanh, cố định theo màn; hình của level nằm giữa vùng này
var _origin: Vector2 = Vector2.ZERO  # góc ô (0, 0) của lưới level
var _box: Rect2i = Rect2i()  # ô bao hình của level (khối và thùng sắt) lúc setup
var _nodes: Dictionary = {}  # id -> BlockNode
var _owner: Dictionary = {}  # Vector2i -> id
var _vacated: Dictionary = {}  # Vector2i -> true: ô của khối đã đi, không vẽ nền nữa
var _gate_state: Dictionary = {}  # cạnh -> đang mở? theo board, đổi ngay lúc chạm
var _gate_shown: Dictionary = {}  # cạnh -> hình cổng đang mở? đổi khi hoạt ảnh của lượt chạm xong
var _gate_prog: Dictionary = {}  # cạnh -> 0 (đóng) .. 1 (mở), đang chạy hoạt ảnh
var _gate_tws: Dictionary = {}  # cạnh -> Tween
## Lượt chạm hợp lệ đánh số tăng dần, không đặt lại khi setup, để callback của bàn cũ không khớp lượt của bàn mới.
var _gate_seq: int = 0  # lượt gần nhất
var _gate_shown_seq: int = 0  # hình cổng đang theo board sau lượt này
## Lượt chưa hiện lên cổng -> {"gates": board.gates() sau lượt, "sfx": cổng đổi thì kêu, "left": số hoạt ảnh chưa xong}.
var _gate_moves: Dictionary = {}
var _gate_flash_tw: Tween = null
var _frame: CandyFrame = null
var _shadow_root: Control = null
var _blocks_root: Control = null
var _fx_root: Control = null
var _pending: int = 0
var _hl_id: String = ""
var _hl_tween: Tween = null
var _hl_glitter: Control = null  # sao lấp lánh phủ khối được Gợi ý bằng booster (HintGlitter)
var _shake_tw: Tween = null
var _rng := RandomNumberGenerator.new()
var _specials: Dictionary = {}  # id -> true: khối đặc biệt của leaderboard (vẽ bằng chất liệu crystal)
var _knocked: Dictionary = {}  # Vector2i -> true: ô thùng sắt đang rung (vẽ bằng node riêng)

static var _fx_prewarmed: bool = false


func _init() -> void:
	resized.connect(_layout)


func _ready() -> void:
	_bind()


## Frame and the Shadows, Blocks, Fx layers are nodes of scenes/board_view.tscn. Safe to call more than once.
## The scene's Links layer drew the dashed key line, now gone (a key block shows a big key instead); it stays empty.
func _bind() -> void:
	if _frame != null:
		return
	_frame = get_node("Frame") as CandyFrame
	_frame.bind()
	_shadow_root = get_node("Shadows")
	_blocks_root = get_node("Blocks")
	_fx_root = get_node("Fx")


## `area` khác 0 thì đặt luôn kích thước vùng vẽ; bàn tự co vừa vùng đó. Không đặt custom_minimum_size để không phình quá vùng chứa.
func setup(board: BoardState, area: Vector2 = Vector2.ZERO) -> void:
	_bind()
	_board = board
	_clear()
	if area != Vector2.ZERO:
		_set_fixed_size(area)
	for id in board.block_ids():
		_add_block(id)
	# Sương phủ lấn ra ngoài mép khối: khối còn trong sương vẽ sau mọi khối khác để phủ lên mép khối bên cạnh.
	for id in _nodes:
		if bool((_nodes[id] as BlockNode).view.get("is_fog_hidden", false)):
			_blocks_root.move_child(_nodes[id], -1)
	_box = _content_box()
	_gate_state = board.gates()
	_gate_shown = _gate_state.duplicate()
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


## Đọc lại trạng thái từ board (sau khi cộng MOVES, phá khối, v.v.) không chạy hoạt ảnh.
func refresh() -> void:
	if _board == null:
		return
	_sync_states(false)
	_sync_gates_now()


func cell_size() -> float:
	return _cell


## Đơn vị đo khung cổng (CandyFrame), px.
func frame_unit() -> float:
	return _unit


## Vùng khung cổng bao quanh (không tính khung), toạ độ cục bộ. Cố định theo màn, không đổi theo level.
func board_rect() -> Rect2:
	if _board == null:
		return Rect2()
	return _area


## Ô bao hình của level (khối và thùng sắt lúc setup), toạ độ ô.
func content_box() -> Rect2i:
	return _box


## Hình chữ nhật của các ô trong `content_box()`, toạ độ cục bộ.
func content_rect() -> Rect2:
	return Rect2(_origin + Vector2(_box.position) * _cell, Vector2(_box.size) * _cell)


## Trọn khung cổng quanh bàn, toạ độ cục bộ.
func frame_rect() -> Rect2:
	return CandyFrame.outer_rect(board_rect(), _unit)


func cell_center(c: Vector2i) -> Vector2:
	return _origin + (Vector2(c) + Vector2(0.5, 0.5)) * _cell


func block_node(id: String) -> Control:
	return _nodes.get(id, null)


## Đánh dấu khối đặc biệt (gọi sau setup; setup xoá danh sách cũ).
func set_specials(ids: Array) -> void:
	_specials.clear()
	for id in ids:
		_specials[str(id)] = true
	for id in _nodes:
		var n: BlockNode = _nodes[id]
		n.view["special"] = _specials.has(id)
		n.queue_redraw()


func is_special(id: String) -> bool:
	var n: BlockNode = _nodes.get(id, null)
	return n != null and bool(n.view.get("special", false))


func block_count() -> int:
	return _nodes.size()


## Khối đang chiếm ô tại điểm `pos` (toạ độ cục bộ), "" nếu là ô trống, đá hoặc ngoài bàn.
func block_at(pos: Vector2) -> String:
	if _board == null or _cell <= 0.0:
		return ""
	return str(_owner.get(_cell_at(pos), ""))


## Ô chứa điểm `pos` (toạ độ cục bộ), có thể nằm ngoài bàn.
func _cell_at(pos: Vector2) -> Vector2i:
	var rel := (pos - _origin) / _cell
	return Vector2i(floori(rel.x), floori(rel.y))


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


## Số lớp hiệu ứng "bóng" (băng vỡ, vỏ bóc, sương tan, xích rơi) đang mờ dần.
func ghost_count() -> int:
	var k := 0
	for ch in _fx_root.get_children():
		if ch.name.begins_with(GHOST_NAME) and not ch.is_queued_for_deletion():
			k += 1
	return k


func _clear() -> void:
	clear_highlight()
	_specials.clear()
	for id in _nodes:
		_nodes[id].queue_free()
	_nodes.clear()
	_owner.clear()
	for ch in _shadow_root.get_children():
		ch.queue_free()
	# khối đang bị nghiền dở: xoá cùng vụn của nó trong _fx_root bên dưới, hoạt ảnh nghiền dừng theo
	for ch in _blocks_root.get_children():
		if str(ch.name).begins_with("ExitClip"):
			ch.queue_free()
	_pending = 0
	for side in _gate_tws:
		var gtw: Tween = _gate_tws[side]
		if gtw != null and gtw.is_valid():
			gtw.kill()
	_gate_tws.clear()
	_gate_prog.clear()
	_gate_state.clear()
	_gate_shown.clear()
	_gate_moves.clear()
	_gate_shown_seq = _gate_seq
	_knocked.clear()
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
			_vacated[c] = true
	queue_redraw()


## Ô bao mọi khối và thùng sắt của bàn; bàn trống thì là cả lưới.
func _content_box() -> Rect2i:
	var mn := Vector2i(1 << 20, 1 << 20)
	var mx := Vector2i(-(1 << 20), -(1 << 20))
	var cells: Array[Vector2i] = _board.stones().duplicate()
	for id in _nodes:
		cells.append_array((_nodes[id] as BlockNode).cells)
	for c in cells:
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
		mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
	if cells.is_empty():
		return Rect2i(Vector2i.ZERO, Vector2i(_board.width(), _board.height()))
	return Rect2i(mn, mx - mn + Vector2i.ONE)


## Màn to hơn màn chuẩn Config.BOARD_SCREEN thì khung to theo: giữ tỉ lệ khung so với màn.
func _screen_scale() -> float:
	var screen := get_viewport_rect().size if is_inside_tree() else Config.BOARD_SCREEN
	return minf(screen.x / Config.BOARD_SCREEN.x, screen.y / Config.BOARD_SCREEN.y)


func _layout() -> void:
	if _board == null:
		return
	if _board.width() <= 0 or _board.height() <= 0:
		return
	var avail := size
	var s := _screen_scale()
	var m := CandyFrame.margin()
	var outer := Config.BOARD_AREA + 2.0 * m * Config.BOARD_FRAME_UNIT
	if avail.x > 1.0 and avail.y > 1.0:
		# khung chỉ co thêm khi vùng chứa nhỏ hơn khung
		s = minf(s, minf(avail.x / outer.x, avail.y / outer.y))
	_unit = Config.BOARD_FRAME_UNIT * s
	var area := Config.BOARD_AREA * s
	_area = Rect2(((avail - area) * 0.5).floor(), area)
	# Hình của level cộng một ô lề mỗi phía (tối đa cả lưới của level, ít nhất lưới chuẩn) vừa vùng khung, to nhất
	# BOARD_CELL_MAX. Level Road Trip có lưới cao hơn BOARD_H.
	var need := Vector2(mini(_box.size.x + 2, maxi(_board.width(), Config.BOARD_W)),
		mini(_box.size.y + 2, maxi(_board.height(), Config.BOARD_H)))
	var fit_cell := minf(area.x / need.x, area.y / need.y)
	# Làm tròn xuống số nguyên để các ô trong cùng khối khớp pixel, không lộ đường nối.
	_cell = floorf(clampf(fit_cell, 8.0, Config.BOARD_CELL_MAX * s))
	_origin = (_area.get_center() - (Vector2(_box.position) + Vector2(_box.size) * 0.5) * _cell).floor()
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
	_frame.layout(_area, _unit)
	_layout_gate_segments()
	queue_redraw()


## Level nhiều cổng (Road Trip): cổng của mỗi cạnh từ ô sang px của khung (cùng toạ độ với node này), để thanh chia
## đoạn màu đúng hàng/cột khối đi qua. Level thường: mỗi cạnh một màu.
func _layout_gate_segments() -> void:
	var gs: Dictionary = _board.gate_segments()
	for side in CandyFrame.SIDES:
		var out: Array = []
		var vertical: bool = side == "left" or side == "right"
		var base: float = _origin.y if vertical else _origin.x
		for s in gs.get(side, []):
			out.append([str(s[0]), base + float(s[1]) * _cell, base + float(s[2]) * _cell])
		_frame.set_segments(side, out)


# --- vẽ ---

func _draw() -> void:
	if _board == null:
		return
	# nền bàn: tới đường giữa các thanh khung
	var bg := StyleBoxFlat.new()
	bg.bg_color = ThemeKit.BOARD_BG
	bg.set_corner_radius_all(int(CandyFrame.TUBE_R * _unit))
	bg.anti_aliasing = true
	draw_style_box(bg, CandyFrame.panel_rect(_area, _unit))
	# thùng sắt (vật cản cố định, `stone` trong dữ liệu)
	for s in _board.stones():
		if not _knocked.has(s):
			BoardFx.draw_crate(self, _cell_rect(s), _cell)


func _cell_rect(c: Vector2i) -> Rect2:
	return Rect2(_origin + Vector2(c) * _cell, Vector2(_cell, _cell))


## Ô thùng sắt bị gõ theo `dir`: rung cứng và nhanh theo hướng gõ, nắp loé, vệt sáng quét qua làm đinh loé.
## Trong lúc rung ô vẽ bằng node riêng ở lớp hiệu ứng.
func _knock_crate(c: Vector2i, dir: Vector2) -> void:
	if _knocked.has(c):
		return
	_knocked[c] = true
	queue_redraw()
	var k := CrateKnock.new()
	k.cell = _cell
	k.axis = Vector2(absf(dir.x), absf(dir.y)) if dir != Vector2.ZERO else Vector2(0, 1)
	k.position = _cell_rect(c).position
	k.size = Vector2(_cell, _cell)
	_fx_root.add_child(k)
	var tw := k.create_tween()
	tw.tween_method(k.set_t, 0.0, 1.0, CRATE_KNOCK)
	tw.finished.connect(func() -> void:
		_knocked.erase(c)
		queue_redraw()
		k.queue_free())


## Ô thùng sắt đang rung: kim loại cứng nên ép ít, dao động nhanh tắt dần theo `axis`, nở bù theo trục kia; vẽ thêm loé.
class CrateKnock extends Control:
	const BoardFx := preload("res://src/ui/board_fx.gd")
	const SQUASH := 0.07  # thùng bị ép chừng này theo hướng va
	const RINGS := 3.5  # số nhịp rung trong cả lần gõ
	var cell: float = 42.0
	var axis: Vector2 = Vector2(0, 1)
	var _sq: Vector2 = Vector2.ONE
	var _t: float = 0.0

	func _init() -> void:
		name = "CrateKnock"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_t(t: float) -> void:
		_t = t
		var f := SQUASH * exp(-6.0 * t) * cos(t * TAU * RINGS)
		_sq = Vector2.ONE - axis * f + Vector2(axis.y, axis.x) * f * 0.5
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		BoardFx.draw_crate(self, r, cell, _sq)
		BoardFx.draw_crate_glint(self, r, cell, _t, _sq)


# --- chạm ---

func _gui_input(event: InputEvent) -> void:
	if not input_enabled or _board == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := block_at(event.position)
		if id == "":
			var c := _cell_at(event.position)
			if _board.stones().has(c):
				accept_event()
				Sfx.play("stone")
				_knock_crate(c, Vector2.DOWN)
				ObstacleFx.iron_hit(_fx_root, get_global_transform() * cell_center(c), Vector2.UP, _cell, 0.7)
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
## Board đổi cổng nhịp ngay lúc chạm, nhưng hình cổng chỉ đổi khi hoạt ảnh của lượt này xong (_gate_move()).
func apply_result(result: Dictionary) -> void:
	var kind := str(result.get("kind", "rejected"))
	var id := str(result.get("id", ""))
	clear_highlight()
	if kind == "rejected" or kind == "fog":
		if kind == "fog" and _nodes.has(id):
			_anim_fogged(_nodes[id])
		_check_done.call_deferred()
		return
	# chặn ở cổng thì tiếng cổng đã kêu lúc va, cổng mở ra sau đó không kêu lại
	var seq := _gate_move(kind != "gate_closed")
	if not _nodes.has(id):
		_after_result(seq)
		_move_end(seq)
		_check_done.call_deferred()
		return
	var node: BlockNode = _nodes[id]
	var dir: Vector2 = Vector2(LevelData.side_dir(LevelData.block_side(node.view)))
	var dist := int(result.get("distance", 0))
	match kind:
		"exit":
			_anim_exit(node, dir, seq)
		"blocked":
			_anim_bounce(node, dir, float(dist), dist, str(result.get("blocker", "")), "", seq)
		"gate_closed":
			var gate_side := LevelData.block_side(node.view)
			_anim_bounce(node, dir, _cells_to_bar(node, dir), dist, "", gate_side, seq)
		"chained":
			Sfx.play("chain")
			_anim_chained(node, str(result.get("blocker", "")), seq)
		"crack":
			Sfx.play("ice")
			_anim_pop(node, seq)
		"peel":
			Sfx.play("layer")
			_anim_pop(node, seq)
	_after_result(seq)
	_move_end(seq)


## Lớp pudding, xích, sương mù, hộp giấy đổi theo board ngay; hộp giấy bay về thanh thuộc lượt `seq`.
func _after_result(seq: int) -> void:
	if _board == null:
		return
	_sync_states(true, seq)


## Khối lao nhanh dần, gần tới thanh cùng màu thì chậm lại về tốc độ nghiền (trừ khối cuối trên bàn), chạm mặt trong
## của thanh rồi trôi qua thanh và bị nghiền thành khối vuông nhỏ.
func _anim_exit(node: BlockNode, dir: Vector2, seq: int) -> void:
	_unmap(node.id)
	_nodes.erase(node.id)
	node.busy = true
	_begin()
	_move_begin(seq)
	var side := LevelData.block_side(node.view)
	var steps := _cells_to_bar(node, dir)
	var travel := steps * _cell
	# khối cuối trên bàn không hãm: lao thẳng vào thanh như cú chốt ván
	var brake := 0.0 if _nodes.is_empty() else EXIT_BRAKE
	var plan := _exit_plan(travel, clampf(SLIDE_MIN + SLIDE_PER_CELL * steps, SLIDE_MIN, SLIDE_TIME), brake)
	var time: float = plan[0] + plan[1]
	var axis := Vector2(absf(dir.x), absf(dir.y))
	var stretch := axis * SLIDE_STRETCH - Vector2(axis.y, axis.x) * SLIDE_STRETCH * 0.5
	node.pivot_offset = node.size * 0.5
	_suck_wind(node, dir, side, time)
	var tw := node.create_tween()
	tw.tween_method(_exit_step.bind(node, node.position, dir, stretch, plan[0], plan[1], plan[2]), 0.0, time, time)
	tw.finished.connect(_grind.bind(node, dir, side, seq))


## Đường lao thoát dài `travel` px: nhanh dần đều trong `dash` giây tới tốc độ cao nhất, rồi chậm dần đều trong
## `brake` giây để chạm thanh đúng GRIND_SPEED; `brake` 0 thì nhanh dần tới tận thanh.
## Trả [giây nhanh dần, giây chậm dần, tốc độ cao nhất px/giây].
func _exit_plan(travel: float, dash: float, brake: float = EXIT_BRAKE) -> Array:
	var grind := GRIND_SPEED * _cell
	var peak := (2.0 * travel - grind * brake) / (dash + brake)
	if peak < grind:
		# sát thanh, không đủ đường để hãm: nhanh dần tới tốc độ nghiền rồi đi đều, hoặc chưa tới đã chạm thanh
		peak = minf(grind, 2.0 * travel / dash)
		brake = (travel - peak * dash * 0.5) / grind
	return [dash, brake, peak]


## Một bước lao thoát ở giây `t` theo _exit_plan(); khối dài ra theo bình phương phần tốc độ so với lúc nhanh nhất.
func _exit_step(t: float, node: BlockNode, start: Vector2, dir: Vector2, stretch: Vector2, dash: float, brake: float, peak: float) -> void:
	var a := minf(t, dash)
	var dist := 0.5 * peak * a * a / dash
	var speed := peak * a / dash
	if t > dash and brake > 0.0:
		var u := t - dash
		var slow := (peak - GRIND_SPEED * _cell) / brake
		dist += peak * u - 0.5 * slow * u * u
		speed = peak - slow * u
	node.position = start + dir * dist
	var k := speed / peak if peak > 0.0 else 0.0
	node.scale = Vector2.ONE + stretch * k * k


## Vệt gió hút về đoạn thanh khối sắp phủ, rộng đúng bề ngang khối, ở lớp Fx trên các khối; `time` là giây tới lúc
## khối chạm thanh. Vệt hiện từ lúc khối gần chạm cho tới khi khối trôi hết qua thanh.
func _suck_wind(node: BlockNode, dir: Vector2, side: String, time: float) -> void:
	var seg := _bar_segment(node, dir, false)
	var lo := INF
	var hi := -INF
	for c: Vector2i in node.local_cells():
		lo = minf(lo, Vector2(c).dot(dir))
		hi = maxf(hi, Vector2(c).dot(dir) + 1.0)
	var lead := minf(SUCK_LEAD, time)
	var inner := _bar_face(dir)
	var perp := Vector2(-dir.y, dir.x)
	var mouth := dir * inner + perp * (seg[0] as Vector2).dot(perp)
	# Level nhiều cổng: màu của cổng khối sắp vào, không phải màu cạnh.
	var at: Vector2 = seg[0]
	var gate := _frame.gate_color_at(side, at.y if side == "left" or side == "right" else at.x)
	var bar_col: Color = CandyFrame.color_end(gate) if gate != "" else CandyFrame.END_COLORS[side]
	var col: Color = bar_col.lerp(Color.WHITE, SUCK_WHITE)
	SuckWind.spawn(_fx_root, mouth, dir, float(seg[1]) * 0.5, _cell, col, time - lead, lead + (hi - lo) / GRIND_SPEED, _rng)


## Mặt trong của thanh phía `dir`, toạ độ cục bộ chiếu lên `dir`.
func _bar_face(dir: Vector2) -> float:
	var r := CandyFrame.inner_rect(_area, _unit)
	return r.get_center().dot(dir) + absf(r.size.dot(dir)) * 0.5


## Số ô (lẻ) khối đi được từ chỗ của nó tới khi mép trước chạm mặt trong của thanh phía `dir`.
func _cells_to_bar(node: BlockNode, dir: Vector2) -> float:
	var front := -INF
	for c: Vector2i in node.cells:
		front = maxf(front, (Vector2(c) + Vector2(0.5, 0.5) + dir * 0.5).dot(dir))
	return maxf(0.0, (_bar_face(dir) - _origin.dot(dir)) / _cell - front)


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


## Khối trôi đều qua thanh cùng màu: phần đã qua mặt trong của thanh bị cắt đi (lùa dưới thanh),
## đổi thành khối vuông nhỏ phun ra phía ngoài thanh, toả hình nón. Toạ độ theo dir tính trong toạ độ của BoardView.
func _grind(node: BlockNode, dir: Vector2, side: String, seq: int) -> void:
	_gate_reach(seq)
	var ramp := ThemeKit.block_ramp(str(node.view.get("color", "")))
	var lc := node.local_cells()
	var inner := _bar_face(dir)
	var outer := inner + float(CandyFrame.BARS[side]["thick"]) * _unit
	var clip := _exit_clip(dir, inner)
	node.reparent(clip)
	node.shadow.hide()
	var to_view := get_global_transform().affine_inverse() * node.get_global_transform()
	var trail := INF
	for c: Vector2i in lc:
		trail = minf(trail, (to_view * ((Vector2(c) + Vector2(0.5, 0.5) - dir * 0.5) * _cell)).dot(dir))
	var to_go := maxf(0.0, inner - trail) + 1.0
	var crystal := bool(node.view.get("special", false))
	if crystal:
		_crystal_grind(node, dir, inner, outer, to_go / (GRIND_SPEED * _cell))
	var bits := CandyShards.grinder(_fx_root, lc, _cell, ramp, crystal) as CandyShards
	var counts := _grind_counts(lc, dir)
	var state := {"done": 0.0, "passed": {}, "bits": counts.x, "small": counts.y, "spawned": 0, "spawned_small": 0, "phase": _rng.randf()}
	var tw := node.create_tween()
	tw.tween_method(_grind_step.bind(node, lc, dir, inner, outer, bits, node.position, state), 0.0, to_go, to_go / (GRIND_SPEED * _cell))
	tw.finished.connect(_end_grind.bind(clip, bits, seq))
	var mouth := get_global_transform() * (to_view * _leading_point(lc, dir) + dir * (outer - inner))
	BoardFx.sparkles(_fx_root, mouth, ramp, dir, _cell / GRIND_SPARK_SCALE, GRIND_SPARKS)
	if crystal:
		ObstacleFx.crystal_glints(_fx_root, mouth, dir, _cell, ramp, CRYSTAL_GRIND_GLINTS)
	_hit_bar(side, node, dir, false, 1.0, CandyFrame.SPIN_EXIT, to_go / (GRIND_SPEED * _cell))
	Sfx.play_or("shatter", "exit")


## Prism light of a crystal block grinding through its bar, over the bar span the block covers (`CrystalGrind`).
## Called before the grind bits exist so they fly over the light (top-level items draw in the order they enter the tree).
func _crystal_grind(node: BlockNode, dir: Vector2, inner: float, outer: float, hold: float) -> void:
	var seg := _bar_segment(node, dir, false)
	var perp := Vector2(-dir.y, dir.x)
	var seam := dir * inner + perp * (seg[0] as Vector2).dot(perp)
	var xf := get_global_transform()
	CrystalGrind.spawn(_fx_root, xf * seam, xf * (seam + dir * (outer - inner)), dir, float(seg[1]) * 0.5, _cell, hold)


## Vùng cắt cho khối đang qua thanh: mọi thứ phía trước đường `inner` (theo `dir`) bị giấu.
func _exit_clip(dir: Vector2, inner: float) -> Control:
	var r := Rect2(-size, size * 3.0)
	var line := dir * inner
	if dir.x > 0.0:
		r.size.x = line.x - r.position.x
	elif dir.x < 0.0:
		r = Rect2(Vector2(line.x, r.position.y), Vector2(r.end.x - line.x, r.size.y))
	if dir.y > 0.0:
		r.size.y = line.y - r.position.y
	elif dir.y < 0.0:
		r = Rect2(Vector2(r.position.x, line.y), Vector2(r.size.x, r.end.y - line.y))
	var clip := Control.new()
	clip.name = "ExitClip"
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.position = r.position
	clip.size = r.size
	_blocks_root.add_child(clip)
	return clip


## Số mảnh cả khối ra khi nghiền theo bề ngang khối (số cột ô khối phủ dọc thanh): khối rộng 1 ô ra GRIND_BITS mảnh to
## và GRIND_SMALL mảnh nhỏ, mỗi ô thêm ra thêm GRIND_BITS_EXTRA lần chừng ấy, làm tròn. Trả (mảnh to, mảnh nhỏ).
func _grind_counts(lc: Array, dir: Vector2) -> Vector2i:
	var along := Vector2(absf(dir.y), absf(dir.x))
	var cols := {}
	for c: Vector2i in lc:
		cols[roundi(Vector2(c).dot(along))] = true
	var k := 1.0 + GRIND_BITS_EXTRA * float(cols.size() - 1)
	return Vector2i(roundi(float(GRIND_BITS) * k), roundi(float(GRIND_SMALL) * k))


## Một bước nghiền: dời khối, rồi các ô vừa vắt qua mặt trong của thanh phun mảnh to và mảnh nhỏ.
## Cả khối ra state["bits"] mảnh to và state["small"] mảnh nhỏ (_grind_counts()): tới lúc này đã ra chừng ấy nhân phần
## diện tích khối đã qua thanh. Mảnh rải đều theo bề ngang các ô đang qua thanh bằng dãy tỉ lệ vàng, không chụm một chỗ.
func _grind_step(v: float, node: BlockNode, lc: Array, dir: Vector2, inner: float, outer: float, bits: CandyShards, start: Vector2, state: Dictionary) -> void:
	node.position = start + dir * v
	if v <= float(state["done"]):
		return
	state["done"] = v
	var passed: Dictionary = state["passed"]
	var to_view := get_global_transform().affine_inverse() * node.get_global_transform()
	var to_canvas := get_global_transform()
	var perp := Vector2(-dir.y, dir.x)
	var half := absf(to_view.basis_xform(dir * _cell * 0.5).dot(dir))
	var width := absf(to_view.basis_xform(perp * _cell).dot(perp))
	var crossing: Array = []  # [ô, tâm ô, along]
	var total := 0.0
	var lo := INF  # bề ngang các ô đang qua thanh, chiếu lên perp
	var hi := -INF
	for c: Vector2i in lc:
		var mid := to_view * ((Vector2(c) + Vector2(0.5, 0.5)) * _cell)
		var along := inner - mid.dot(dir)
		var before := float(passed.get(c, 0.0))
		var now := maxf(before, clampf(0.5 - along / (2.0 * half), 0.0, 1.0))
		passed[c] = now
		total += now
		if now > before:
			crossing.append([c, mid, along])
			lo = minf(lo, mid.dot(perp) - width * 0.5)
			hi = maxf(hi, mid.dot(perp) + width * 0.5)
	var frac := total / float(lc.size())
	var big := int(state["spawned"])
	var small := int(state["spawned_small"])
	var due := roundi(float(state["bits"]) * frac) - big
	var due_small := roundi(float(state["small"]) * frac) - small
	if due + due_small <= 0 or crossing.is_empty():
		return
	state["spawned"] = big + due
	state["spawned_small"] = small + due_small
	for i in due + due_small:
		var target := lo + (hi - lo) * fposmod(float(state["phase"]) + float(big + small + i) * GRIND_GOLDEN, 1.0)
		var pick: Array = crossing[0]
		for entry: Array in crossing:
			if absf((entry[1] as Vector2).dot(perp) - target) < absf((pick[1] as Vector2).dot(perp) - target):
				pick = entry
		var c: Vector2i = pick[0]
		var mid: Vector2 = pick[1]
		var along: float = clampf(pick[2], -half, half)
		var t := clampf((target - mid.dot(perp)) / width, -0.5, 0.5)
		# màu lấy ngay chỗ đang qua thanh, lùi vào trong ô để khối vuông không bị mép bo của khối cắt mất
		var at := Vector2(c) + Vector2(0.5, 0.5) + dir * (along / half * 0.5) + perp * t
		at = at.clamp(Vector2(c) + Vector2(0.3, 0.3), Vector2(c) + Vector2(0.7, 0.7))
		var pos := mid + dir * (along + (outer - inner) + _rng.randf_range(0.0, GRIND_STAGGER) * _cell) + perp * t * width
		bits.bit(at, to_canvas * pos, dir, _rng, i >= due)


## Khối đã qua hết thanh: giờ cổng mới đổi theo lượt này (cổng nhịp khoá lại sau khối).
func _end_grind(clip: Control, bits: CandyShards, seq: int) -> void:
	clip.queue_free()
	bits.close()
	# Bàn hết khối: báo xong ngay để thẻ thắng hiện liền, vụn vẫn bay tiếp dưới thẻ; cổng không đổi nữa.
	if _nodes.is_empty():
		_end()
	else:
		_move_end(seq)
		create_tween().tween_callback(_end).set_delay(GRIND_SETTLE)


## Thanh phía `side` bị va: đoạn thanh khối phủ lên (chiếu các ô của khối lên trục thanh) lăn tại chỗ.
## `leading` chỉ tính các ô ở mép trước, dùng khi khối dội lại thay vì đi xuyên qua; `hold` là giây khối còn đang qua thanh.
func _hit_bar(side: String, node: BlockNode, dir: Vector2, leading: bool, strength: float, turns: int, hold: float = 0.0) -> void:
	var seg := _bar_segment(node, dir, leading)
	_frame.hit(side, seg[0], seg[1], strength, turns, hold)


## Đoạn thanh khối phủ lên khi chạm thanh: [tâm theo toạ độ của khung, chiều dài px].
func _bar_segment(node: BlockNode, dir: Vector2, leading: bool) -> Array:
	var lc := node.local_cells()
	var along := Vector2(absf(dir.y), absf(dir.x))
	var front := -INF
	for c: Vector2i in lc:
		front = maxf(front, Vector2(c).dot(dir))
	var lo := INF
	var hi := -INF
	for c: Vector2i in lc:
		if leading and Vector2(c).dot(dir) < front - 0.01:
			continue
		var v := Vector2(c).dot(along)
		lo = minf(lo, v)
		hi = maxf(hi, v + 1.0)
	var lead := _leading_point(lc, dir) / _cell
	var mid := lead + along * ((lo + hi) * 0.5 - lead.dot(along))
	# khối có thể đang giãn theo hướng lao, nên đo chiều dài sau khi đổi toạ độ
	var xf := get_global_transform().affine_inverse() * node.get_global_transform()
	var a := xf * (mid * _cell)
	var b := xf * ((mid + along) * _cell)
	return [a, (hi - lo) * a.distance_to(b)]


func _finish_exit(node: BlockNode) -> void:
	node.queue_free()
	_end()


## Lao nhanh dần tới vật cản, va, bật về chỗ cũ. Rung nhẹ cả bàn; không màn đỏ. Khối về chỗ rồi cổng mới đổi theo
## lượt `seq` (cổng nhịp đang khoá thì mở ra sau cú dội).
func _anim_bounce(node: BlockNode, dir: Vector2, cells_to_go: float, steps: int, blocker: String, gate_side: String, seq: int) -> void:
	var home := node.position
	var travel := maxf(cells_to_go, 0.0) * _cell
	if cells_to_go < 0.5:
		travel = _cell * 0.12
	var go_time := clampf(0.05 + 0.03 * cells_to_go, 0.07, 0.22)
	node.busy = true
	_begin()
	_move_begin(seq)
	var tw := node.create_tween()
	tw.tween_property(node, "position", home + dir * travel, go_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_impact.bind(node, dir, steps, blocker, gate_side, seq))
	# không dùng TRANS_BACK: đà vượt quá chỗ cũ sẽ đè lên khối phía sau, độ nảy đã có wobble lo
	tw.tween_property(node, "position", home, BOUNCE_BACK).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.finished.connect(_finish_busy.bind(node, seq))


## Hoạt ảnh của khối xong; `seq` khác 0 thì đó là hoạt ảnh của lượt chạm `seq` (cổng có thể đổi theo lượt đó).
func _finish_busy(node: BlockNode, seq: int = 0) -> void:
	if is_instance_valid(node):
		node.busy = false
		node.pivot_offset = node.size * 0.5
	_move_end(seq)
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
func _impact(node: BlockNode, dir: Vector2, steps: int, blocker: String, gate_side: String, seq: int) -> void:
	var axis := Vector2(absf(dir.x), absf(dir.y))
	_shake_root(axis)
	var ramp := BoardFx.block_ramp(node.view)
	var at := _contact_local(node, steps, dir, blocker)
	var xf := node.get_global_transform()
	var world := xf * (at * _cell)
	var crystal := BoardFx.is_crystal(node.view)
	CandyShards.chips(_fx_root, node.local_cells(), _cell, ramp, xf, at, dir, CHIPS_BUMP, _rng, crystal)
	if crystal:
		Sfx.play("crystal")
		ObstacleFx.crystal_hit(_fx_root, world, -dir, _cell, ramp)
	else:
		BoardFx.impact_flash(_fx_root, world, ramp["stripe"], _cell * FLASH_BUMP, 0.26, 0.55)
		BoardFx.sparkles(_fx_root, world, ramp, -dir, _cell / SPARK_SCALE_BUMP, SPARKS_BUMP)
	node.pivot_offset = at * _cell
	node.wobble(axis, WOBBLE_SELF, WOBBLE_TIME)
	if gate_side != "":
		_gate_reach(seq)
		Sfx.play("gate")
		_hit_bar(gate_side, node, dir, true, 0.7, CandyFrame.SPIN_BUMP)
		_flash_gates()
	elif blocker == LevelData.STONE:
		Sfx.play("stone")
		for c in _hit_stones(node, steps, dir):
			_knock_crate(c, dir)
		ObstacleFx.iron_hit(_fx_root, world, -dir, _cell)
	else:
		Sfx.play_or("bump", "blocked")
		if _nodes.has(blocker):
			var b: BlockNode = _nodes[blocker]
			var bxf := b.get_global_transform()
			var jiggle := 1.0
			if int(b.view.get("ice", 0)) > 0:
				jiggle = JELLY_JOLT
				ObstacleFx.jelly_hit(_fx_root, world, -dir, _cell)
			elif str(b.view.get("inner_color", "")) != "":
				ObstacleFx.paper_hit(_fx_root, world, -dir, _cell, ThemeKit.block_color(str(b.view.get("color", ""))))
			else:
				var b_ramp := BoardFx.block_ramp(b.view)
				var b_crystal := BoardFx.is_crystal(b.view)
				CandyShards.chips(_fx_root, b.local_cells(), _cell, b_ramp, bxf, bxf.affine_inverse() * world / _cell, -dir, CHIPS_BUMP, _rng, b_crystal)
				if b_crystal:
					if not crystal:
						Sfx.play("crystal")
					ObstacleFx.crystal_hit(_fx_root, world, dir, _cell, b_ramp, CRYSTAL_STRUCK)
			if bool(b.view.get("chained", false)):
				Sfx.play("chain")
				ObstacleFx.chain_rattle(_fx_root, world, _cell)
			_jolt(b, dir, 1.0, 0.0, jiggle)
			_ripple(b, dir)


## Các ô thùng sắt mép trước của khối đang đụng vào.
func _hit_stones(node: BlockNode, steps: int, dir: Vector2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var stones := _board.stones()
	for c: Vector2i in node.cells:
		var next := c + Vector2i(dir) * (steps + 1)
		if stones.has(next) and not out.has(next):
			out.append(next)
	return out


## Khối bị va giật lùi rồi về đúng ô của nó và nhún theo; `power` giảm dần khi lan ra xa, `jiggle` nhân thêm độ nhún
## (pudding nhún mạnh hơn kẹo).
func _jolt(b: BlockNode, dir: Vector2, power: float, delay: float, jiggle: float = 1.0) -> void:
	if b.busy:
		return
	var home := _origin + Vector2(b.origin_cell) * _cell
	var tw := b.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_callback(b.wobble.bind(Vector2(absf(dir.x), absf(dir.y)), WOBBLE_BLOCKER * power * jiggle, WOBBLE_TIME * (1.0 + (jiggle - 1.0) * 0.4)))
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


func _shake_root(axis: Vector2, amplitude: float = 0.0) -> void:
	if _shake_tw != null:
		_shake_tw.kill()
	_blocks_root.position = Vector2.ZERO
	_shake_tw = BoardFx.shake(_blocks_root, maxf(3.0, amplitude if amplitude > 0.0 else _cell * 0.05), 0.14 if amplitude <= 0.0 else 0.22, axis)


func _anim_chained(node: BlockNode, key_id: String, seq: int) -> void:
	node.busy = true
	_begin()
	_move_begin(seq)
	var home := node.position
	var tw := node.create_tween()
	for s in [1.0, -1.0, 0.6, -0.6]:
		tw.tween_property(node, "position", home + Vector2(_cell * 0.07 * s, 0), 0.04)
	tw.tween_property(node, "position", home, 0.04)
	tw.finished.connect(_finish_busy.bind(node, seq))
	ObstacleFx.chain_rattle(_fx_root, node.get_global_transform() * (BoardFx.chain_center(node.local_cells()) * _cell), _cell)
	# chỉ khối chìa để người chơi thấy cần mở cái nào
	if _nodes.has(key_id):
		var k: BlockNode = _nodes[key_id]
		if not k.busy:
			k.pivot_offset = k.size * 0.5
			var kt := k.create_tween()
			kt.tween_property(k, "scale", Vector2(1.1, 1.1), 0.12).set_trans(Tween.TRANS_SINE)
			kt.tween_property(k, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE)


## Khối còn trong sương bị chạm: lắc ngang nhẹ tại chỗ như lắc đầu, không đi, không đổi gì trên bàn.
func _anim_fogged(node: BlockNode) -> void:
	if node.busy:
		return
	node.busy = true
	_begin()
	var home := _origin + Vector2(node.origin_cell) * _cell
	var tw := node.create_tween()
	for s in [1.0, -1.0, 0.5, -0.5]:
		tw.tween_property(node, "position", home + Vector2(_cell * FOG_NUDGE * s, 0), 0.04)
	tw.tween_property(node, "position", home, 0.04)
	tw.finished.connect(_finish_busy.bind(node))


## Nảy to rồi về, loé sáng: lớp pudding vỡ, hộp giấy bay đi lộ kẹo bên trong. Hạt do `_sync_states` lo theo chất liệu.
func _anim_pop(node: BlockNode, seq: int) -> void:
	node.busy = true
	node.pivot_offset = node.size * 0.5
	_begin()
	_move_begin(seq)
	node.glow = 1.0
	node.queue_redraw()
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(1.12, 1.12), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.finished.connect(_finish_pop.bind(node, seq))


func _finish_pop(node: BlockNode, seq: int) -> void:
	if is_instance_valid(node):
		node.glow = 0.0
		node.queue_redraw()
	_finish_busy(node, seq)


## Đọc lại màu, băng, xích, sương mù từ board; khối nào đổi thì vẽ lại và có hiệu ứng nhẹ. `seq`: lượt chạm gây ra
## thay đổi (hộp giấy bay về thanh thuộc lượt đó), 0 khi không do chạm.
func _sync_states(animate: bool, seq: int = 0) -> void:
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
		v["special"] = _specials.has(id)
		n.view = v
		n.queue_redraw()
		if not animate:
			continue
		if bool(old.get("is_fog_hidden", false)) and not bool(v.get("is_fog_hidden", false)):
			Sfx.play("fog")
			_reveal_pop(n)
			_spawn_ghost(n, {"fog_only": true}, FOG_LIFT_GROW, FOG_LIFT_TIME)
		var xf := n.get_global_transform()
		var mid := xf * (n.size * 0.5)
		var span := n.size * n.get_global_transform().get_scale()
		if bool(old.get("chained", false)) and not bool(v.get("chained", false)):
			Sfx.play("chain")
			ObstacleFx.chain_break(_fx_root, mid, _cell, span, xf * (BoardFx.chain_center(n.local_cells()) * _cell))
			_spawn_ghost(n, {"chain_only": true}, 1.15, 0.28)
			_reveal_pop(n)
		if int(old.get("ice", 0)) > int(v.get("ice", 0)):
			ObstacleFx.jelly_burst(_fx_root, mid, _cell, span)
			_spawn_ghost(n, {"ice": 1, "jelly_only": true, "color": old.get("color", "")}, 1.28, 0.3)
		if str(old.get("inner_color", "")) != "" and str(v.get("inner_color", "")) == "":
			_box_fly(n, old, seq)
			BoardFx.sparkles(_fx_root, mid, ThemeKit.block_ramp(str(v.get("color", ""))), Vector2.UP, _cell / 110.0, 6)
	_refresh_keys()


## Bản sao khối ở trạng thái cũ (hoặc chỉ một lớp, xem BlockNode._draw), nằm trên khối thật.
func _make_ghost(n: BlockNode, old_view: Dictionary) -> BlockNode:
	var g := BlockNode.new()
	g.name = GHOST_NAME
	g.cells = n.cells
	g.origin_cell = n.origin_cell
	g.cell_size = _cell
	g.view = old_view
	g.size = n.size
	g.position = n.position
	g.pivot_offset = n.size * 0.5
	_fx_root.add_child(g)
	return g


## Bóng mờ dần (và to ra): lớp pudding vỡ, sương tan, xích đứt.
func _spawn_ghost(n: BlockNode, old_view: Dictionary, grow: float, dur: float) -> void:
	var g := _make_ghost(n, old_view)
	_begin()
	var tw := g.create_tween().set_parallel(true)
	tw.tween_property(g, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if grow > 1.0:
		tw.tween_property(g, "scale", Vector2(grow, grow), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.finished.connect(_finish_exit.bind(g))


## Hộp giấy (lớp ngoài) lao về thanh cùng màu như khối thoát, tới thanh thì rách tung thành giấy vụn; kẹo bên trong ở lại.
## Hộp rách xong thì cổng mới đổi theo lượt `seq`, như khối nghiền qua thanh.
func _box_fly(n: BlockNode, old_view: Dictionary, seq: int = 0) -> void:
	var box := old_view.duplicate()
	box["is_key"] = false
	box["special"] = false
	var g := _make_ghost(n, box)
	var color := str(old_view.get("color", ""))
	var dir := Vector2(LevelData.dir_of(color))
	var side := LevelData.side_of(color)
	var steps := _cells_to_bar(n, dir)
	var time := clampf(SLIDE_MIN + SLIDE_PER_CELL * steps, BOX_FLY_MIN, SLIDE_TIME)
	var axis := Vector2(absf(dir.x), absf(dir.y))
	_begin()
	_move_begin(seq)
	_suck_wind(g, dir, side, time)
	var tw := g.create_tween().set_parallel(true)
	tw.tween_property(g, "position", g.position + dir * steps * _cell, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(g, "scale", Vector2.ONE + axis * SLIDE_STRETCH - Vector2(axis.y, axis.x) * SLIDE_STRETCH * 0.5, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(_box_burst.bind(g, dir, side, color, seq))


func _box_burst(g: BlockNode, dir: Vector2, side: String, color: String, seq: int) -> void:
	_gate_reach(seq)
	var mouth := g.get_global_transform() * _leading_point(g.local_cells(), dir)
	var span := maxf(g.size.x, g.size.y)
	_hit_bar(side, g, dir, false, 1.0, CandyFrame.SPIN_EXIT)
	ObstacleFx.paper_burst(_fx_root, mouth, dir, _cell, ThemeKit.block_color(color), span)
	# paper, not candy: sfx_shatter is the candy grind, so the box keeps sfx_exit until a paper-tear sound exists
	Sfx.play_or("box_tear", "exit")
	var tw := g.create_tween().set_parallel(true)
	tw.tween_property(g, "modulate:a", 0.0, 0.1)
	tw.tween_property(g, "scale", g.scale * 1.15, 0.1)
	tw.chain().tween_callback(_finish_box.bind(g, seq))


func _finish_box(g: BlockNode, seq: int) -> void:
	_move_end(seq)
	_finish_exit(g)


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
		_gate_prog[side] = 1.0 if bool(_gate_shown.get(side, true)) else 0.0
		_frame.set_gate(side, _gate_prog[side])


# --- cổng nhịp: board đổi ngay lúc chạm, hình cổng đổi khi hoạt ảnh của lượt chạm xong ---
# Khối dội vào cổng khoá: cổng còn khoá tới khi khối về chỗ rồi mới mở. Khối nghiền qua cổng mở: cổng còn mở tới khi
# khối qua hết thanh rồi mới khoá. Chạm nhanh nhiều lượt thì cổng đổi theo thứ tự lượt; khối của lượt sau chạm tới
# thanh trước khi lượt trước xong thì cổng theo kịp ngay trạng thái mà lượt đó gặp (_gate_reach()).

## Ghi một lượt chạm hợp lệ (board đã tap xong): trạng thái cổng sau lượt, chờ một mốc "left" để apply_result tự
## nhả sau khi đã bắt đầu mọi hoạt ảnh của lượt. Trả số lượt.
func _gate_move(sfx: bool) -> int:
	_gate_seq += 1
	if _board != null:
		_gate_state = _board.gates()
	_gate_moves[_gate_seq] = {"gates": _gate_state.duplicate(), "sfx": sfx, "left": 1}
	return _gate_seq


## Một hoạt ảnh của lượt `seq` bắt đầu.
func _move_begin(seq: int) -> void:
	if _gate_moves.has(seq):
		_gate_moves[seq]["left"] = int(_gate_moves[seq]["left"]) + 1


## Một hoạt ảnh của lượt `seq` xong. Các lượt liền nhau từ lượt đang hiện đã xong hết thì cổng hiện theo lượt cuối
## trong số đó; lượt trước còn chạy thì lượt sau chờ.
func _move_end(seq: int) -> void:
	if not _gate_moves.has(seq):
		return
	_gate_moves[seq]["left"] = int(_gate_moves[seq]["left"]) - 1
	var to := _gate_shown_seq
	while _gate_moves.has(to + 1) and int(_gate_moves[to + 1]["left"]) <= 0:
		to += 1
	_show_gates(to)


## Khối (hoặc hộp giấy) của lượt `seq` chạm tới thanh: cổng phải như lúc lượt đó được tính, tức sau lượt trước nó.
func _gate_reach(seq: int) -> void:
	_show_gates(seq - 1)


## Hình cổng theo board sau lượt `seq`; chỉ tiến, không lùi. Cổng nào đổi thì chạy hoạt ảnh, nháy sáng và kêu.
func _show_gates(seq: int) -> void:
	if seq <= _gate_shown_seq or not _gate_moves.has(seq):
		return
	var m: Dictionary = _gate_moves[seq]
	for k: int in _gate_moves.keys():
		if k <= seq:
			_gate_moves.erase(k)
	_gate_shown_seq = seq
	var now: Dictionary = m["gates"]
	var changed := false
	for side in now:
		if bool(_gate_shown.get(side, true)) != bool(now[side]):
			changed = true
			_tween_gate(str(side), bool(now[side]), true)
	_gate_shown = now.duplicate()
	if changed:
		_flash_gates()
		if bool(m["sfx"]) and is_inside_tree():
			Sfx.play("gate")


## Đọc lại cổng từ board không chạy hoạt ảnh (refresh). Còn lượt chưa hiện lên cổng thì lượt cuối nhận trạng thái
## mới, cổng đổi khi lượt đó xong như thường.
func _sync_gates_now() -> void:
	_gate_state = _board.gates()
	if _gate_moves.has(_gate_seq):
		_gate_moves[_gate_seq]["gates"] = _gate_state.duplicate()
		return
	for side in _gate_state:
		if bool(_gate_shown.get(side, true)) != bool(_gate_state[side]):
			_tween_gate(str(side), bool(_gate_state[side]), false)
	_gate_shown = _gate_state.duplicate()
	_set_gate_progress_now()


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
## `pop`: sao Gợi ý vừa chạm, khối loé trắng và nảy to rồi mới nhấp nháy.
## `glitter`: Gợi ý từ booster, sao lấp lánh phủ khắp khối (HintGlitter) tới khi bỏ highlight.
func highlight(id: String, pop: bool = false, glitter: bool = false) -> void:
	clear_highlight()
	if not _nodes.has(id):
		return
	var n: BlockNode = _nodes[id]
	_hl_id = id
	Sfx.play("hint")
	if glitter:
		_hl_glitter = HintGlitter.spawn(_fx_root, n, n.local_cells(), _cell)
	if not pop:
		n.glow = 1.0
		n.queue_redraw()
		_hl_tween = BoardFx.pulse(n)
		return
	n.pivot_offset = n.size * 0.5
	var tw := n.create_tween()
	_hl_tween = tw
	tw.tween_property(n, "scale", Vector2(HINT_POP, HINT_POP), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_set_glow.bind(n), HINT_POP_GLOW, 1.0, 0.5)
	tw.tween_property(n, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if _hl_tween == tw:
			_hl_tween = BoardFx.pulse(n))


func _set_glow(v: float, n: BlockNode) -> void:
	n.glow = v
	n.queue_redraw()


func highlighted_id() -> String:
	return _hl_id


func clear_highlight() -> void:
	if _hl_tween != null:
		_hl_tween.kill()
		_hl_tween = null
	if is_instance_valid(_hl_glitter):
		_hl_glitter.stop()
	_hl_glitter = null
	if _hl_id != "" and _nodes.has(_hl_id):
		var n: BlockNode = _nodes[_hl_id]
		n.scale = Vector2.ONE
		n.glow = 0.0
		n.queue_redraw()
	_hl_id = ""


## Điểm búa gõ (toạ độ toàn cục): tâm ô của khối gần tâm khung khối nhất, để khối hình chữ L vẫn gõ trúng kẹo.
func strike_point(id: String) -> Vector2:
	var n: BlockNode = _nodes.get(id, null)
	if n == null:
		return get_global_rect().get_center()
	return n.get_global_transform() * (_strike_cell(n) * _cell)


## Tâm ô gõ, toạ độ ô của khối.
func _strike_cell(n: BlockNode) -> Vector2:
	var mid := n.size * 0.5 / _cell
	var best := Vector2.ZERO
	var best_d := INF
	for c in n.local_cells():
		var p := Vector2(c) + Vector2(0.5, 0.5)
		if p.distance_squared_to(mid) < best_d:
			best_d = p.distance_squared_to(mid)
			best = p
	return best


## Phá khối (búa kẹo mút gõ): khối vỡ tung thành mảnh kẹo đúng chất liệu, loé sáng, sao bắn, bàn rung mạnh.
## Gọi sau (hoặc trước) board.smash(id).
func smash_anim(id: String) -> void:
	if not _nodes.has(id):
		_check_done.call_deferred()
		return
	if _hl_id == id:
		clear_highlight()
	var n: BlockNode = _nodes[id]
	var ramp := BoardFx.block_ramp(n.view)
	var at := _strike_cell(n)
	var xf := n.get_global_transform()
	var world := xf * (at * _cell)
	_unmap(id)
	_nodes.erase(id)
	n.busy = true
	_begin()
	Sfx.play("smash")
	_shake_root(Vector2(0.5, 1), _cell * SHAKE_SMASH)
	var crystal := BoardFx.is_crystal(n.view)
	CandyShards.shatter(_fx_root, n.local_cells(), _cell, ramp, xf, at, _rng, crystal)
	BoardFx.impact_flash(_fx_root, world, ramp["stripe"], _cell * FLASH_SMASH, 0.3, 0.8)
	BoardFx.sparkles(_fx_root, world, ramp, Vector2.UP, _cell / SPARK_SCALE_SMASH, SPARKS_SMASH)
	if crystal:
		Sfx.play("crystal")
		ObstacleFx.crystal_glints(_fx_root, world, Vector2.UP, _cell, ramp, CRYSTAL_SMASH_GLINTS, 180.0)
	n.modulate.a = 0.0  # mảnh vỡ thay chỗ khối ngay lúc gõ
	var tw := n.create_tween()
	tw.tween_interval(SMASH_SETTLE)
	tw.finished.connect(_finish_exit.bind(n))
	if _board != null:
		_sync_states(true)
