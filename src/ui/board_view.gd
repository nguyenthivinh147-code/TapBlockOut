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
const ChocoCover := preload("res://src/ui/choco_cover.gd")
const PopFuse := preload("res://src/ui/pop_fuse.gd")
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
const GRIND_HAPTIC_EVERY := 0.05  # giây: suốt lúc khối qua thanh, máy rung một nhịp Sfx.HAPTIC_MS["grind"] sau mỗi chừng này
const GRIND_HAPTIC_GAP := 0.04  # giây: nhiều khối cùng nghiền vẫn chung một nhịp, nhịp sát nhịp trước hơn chừng này thì bỏ
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
const JELLY_JOLT := 2.2  # khối phủ pudding bị va nhún mạnh gấp chừng này khối thường (khối phủ băng nhún như thường)
const FOG_LIFT_GROW := 1.15  # sương tan: lớp sương phồng ra chừng này lần trong lúc mờ đi
const FOG_LIFT_TIME := 0.45
const FOG_NUDGE := 0.05  # chạm khối còn trong sương: lắc ngang tại chỗ chừng này ô
const COVER_SQUISH := 0.16  # chạm khối còn pudding: nén dẹt chừng này rồi rung như thạch
const COVER_SQUISH_TIME := 0.5
const COVER_HALF := 0.5  # bóc lớp ngoài của khối 2 lớp: hiệu ứng vỡ cỡ chừng này lần lúc bóc lớp cuối
const COVER_HALF_DB := -6.0  # và tiếng nhỏ hơn chừng này dB
const BOX_FLY_MIN := 0.22  # giây ngắn nhất hộp giấy bay tới thanh
const CHOCO_NUDGE := 0.12  # chạm khối hướng về thanh còn socola: nhích về phía thanh chừng này ô rồi về
const CHOCO_CHIP_DB := -4.0  # bớt một lớp socola (chưa phải lớp cuối) kêu nhỏ hơn lớp cuối chừng này dB
const CHOCO_CHIPS := 9  # vụn socola lúc bớt một lớp
const CHOCO_BREAK_CHIPS := 5  # vụn mỗi đoạn dài một ô dọc thanh lúc lớp cuối vỡ
const CHOCO_CHIP_CELL := 0.8  # vụn socola cỡ như vụn của khối rộng chừng này ô
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
		# `ribbon_only`: lớp ruy băng ngoài bay đi, chỉ vẽ các dải và nơ
		var ribbon_only := bool(view.get("ribbon_only", false))
		var candy := 0.0 if jelly_only or ribbon_only else 1.0
		BoardFx.Pudding.set_layers(_body, layers["jelly"], layers["paper"], tape, candy)
		BoardFx.Pudding.set_cover(_body, layers["thick"], layers["frost"])
		BoardFx.Pudding.set_crystal(_body, 0.0 if ribbon_only else layers["crystal"])
		BoardFx.Pudding.set_ribbons(_body, layers["ribbons"])
		if shadow != null:
			BoardFx.Pudding.update_body(shadow.body, lc, cell_size, ramp)
			BoardFx.Pudding.set_layers(shadow.body, layers["jelly"], 0.0)
			BoardFx.Pudding.set_cover(shadow.body, layers["thick"], layers["frost"])
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
var _grind_buzz_ms: int = -1000000  # Time.get_ticks_msec() của nhịp rung nghiền gần nhất
var _rng := RandomNumberGenerator.new()
var _specials: Dictionary = {}  # id -> true: khối đặc biệt của leaderboard (vẽ bằng chất liệu crystal)
var _knocked: Dictionary = {}  # Vector2i -> true: ô thùng sắt đang rung (vẽ bằng node riêng)
## id -> số lớp phủ board đã bóc mà hình chưa bóc: khối kề đã thoát nhưng chưa chạm thanh. Trong lúc đó khối vẫn tính là
## còn phủ (cover_held), lớp vỡ lúc khối kề chạm thanh (_release_covers).
var _cover_hold: Dictionary = {}
## Socola trên thanh: board bớt lớp ngay lúc chạm, hình bớt khi thứ đi qua thanh khác chạm tới thanh đó (hoặc lúc búa
## gõ). Trong lúc đó khối hướng về thanh vẫn tính là còn socola (choco_held).
var _choco_shown: Dictionary = {}  # cạnh -> số lớp đang hiện
var _choco_due: Dictionary = {}  # lượt -> các cạnh sẽ bớt 1 lớp khi thứ của lượt đó chạm thanh
var _choco_nodes: Dictionary = {}  # cạnh -> ChocoCover
## Bom kẹo: board gỡ lớp phủ, sương của khối trong vùng nổ ngay lúc chạm (hoặc lúc Phá), hình chỉ gỡ lúc bom kẹo chạm
## thanh (hoặc lúc búa gõ), lần lượt từ gần ra xa. Trong lúc đó khối vẫn hiện và tính như cũ (pop_held).
var _pop_hold: Dictionary = {}  # id -> {"ice": số lớp đang hiện, "fog": còn sương trên hình}
var _pop_due: Dictionary = {}  # lượt -> {"cells": ô của bom kẹo, "ids": khối bị nổ}: nổ khi bom kẹo của lượt đó chạm thanh
var _pop_gen: int = 0  # tăng khi setup: lời gọi hẹn giờ của bàn cũ bỏ qua
var _sfx_db: float = 0.0  # tiếng vỡ lớp phủ, sương tan nhỏ hơn chừng này dB (lúc bom kẹo nổ)
var _sfx_mute: bool = false  # bỏ tiếng vỡ (bom kẹo nổ đã đủ Config.POP_SFX_MAX tiếng)

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
	# Nơ của khối ruy băng tràn ra ngoài khối: vẽ sau khối thường để không bị khối bên cạnh che.
	for id in _nodes:
		if int((_nodes[id] as BlockNode).view.get("ribbons", 0)) > 0:
			_blocks_root.move_child(_nodes[id], -1)
	# Sương phủ lấn ra ngoài mép khối: khối còn trong sương vẽ sau mọi khối khác để phủ lên mép khối bên cạnh.
	for id in _nodes:
		if bool((_nodes[id] as BlockNode).view.get("is_fog_hidden", false)):
			_blocks_root.move_child(_nodes[id], -1)
	# Ngòi bom kẹo chĩa ra ngoài khối: khối bom kẹo vẽ sau cùng để ngòi đè lên khối bên cạnh (và lên sương).
	for id in _nodes:
		if bool((_nodes[id] as BlockNode).view.get("pop", false)):
			_blocks_root.move_child(_nodes[id], -1)
	_box = _content_box()
	_gate_state = board.gates()
	_gate_shown = _gate_state.duplicate()
	_set_gate_progress_now()
	_choco_shown = board.choco()
	for side in _choco_shown:
		var c := ChocoCover.new()
		c.setup(str(side), int(_choco_shown[side]))
		_frame.add_child(c)
		_choco_nodes[side] = c
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
	_sync_choco(false)


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


## Khối còn lớp phủ trên hình mà board đã bóc (khối kề đang lao tới thanh): chạm vào tính là khối còn phủ.
## Khối hướng về thanh mà hình còn socola (board có thể đã bớt hết nhưng thứ làm tan lớp cuối chưa tới thanh): chạm vào
## chỉ nhích, như khi board còn socola. Khối còn trong sương thì không (chạm vào lắc như sương mù).
func choco_held(id: String) -> bool:
	var n: BlockNode = _nodes.get(id, null)
	if n == null or bool(n.view.get("is_fog_hidden", false)):
		return false
	return _choco_shown.has(LevelData.block_side(n.view))


## Thanh còn socola trên hình -> số lớp đang hiện.
func choco_shown() -> Dictionary:
	return _choco_shown.duplicate()


func cover_held(id: String) -> bool:
	return _cover_hold.has(id) and _nodes.has(id)


## Khối trong vùng nổ của bom kẹo chưa chạm thanh: hình vẫn còn sương ("fog") hoặc lớp phủ ("covered"); "" nếu không.
func pop_held(id: String) -> String:
	if not _pop_hold.has(id) or not _nodes.has(id):
		return ""
	var h: Dictionary = _pop_hold[id]
	if bool(h["fog"]):
		return "fog"
	return "covered" if int(h["ice"]) > 0 else ""


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
	# Every node on the block layer: also blocks flying out (_anim_exit takes them out of _nodes before they reach the
	# bar, so a restart mid-flight used to leave them grinding into the new board) and the exit clips of blocks being
	# ground (their shards in _fx_root go below); their tweens stop with them.
	for ch in _blocks_root.get_children():
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
	_cover_hold.clear()
	_pop_hold.clear()
	_pop_due.clear()
	_pop_gen += 1
	_sfx_db = 0.0
	_sfx_mute = false
	for side in _choco_nodes:
		(_choco_nodes[side] as Node).queue_free()
	_choco_nodes.clear()
	_choco_shown.clear()
	_choco_due.clear()
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
	if bool(v.get("pop", false)):
		n.add_child(PopFuse.new())


func _unmap(id: String) -> void:
	_cover_hold.erase(id)
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
	for side in _choco_nodes:
		(_choco_nodes[side] as ChocoCover).layout(CandyFrame.bar_rect(str(side), _area, _unit), _unit, _cell)
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
	if kind == "rejected" or kind == "fog" or kind == "covered" or kind == "choco":
		if kind == "fog" and _nodes.has(id):
			_anim_fogged(_nodes[id])
		elif kind == "covered" and _nodes.has(id):
			_anim_covered(_nodes[id])
		elif kind == "choco" and _nodes.has(id):
			_anim_choco(_nodes[id])
		_check_done.call_deferred()
		return
	# chặn ở cổng thì tiếng cổng đã kêu lúc va, cổng mở ra sau đó không kêu lại
	var seq := _gate_move(kind != "gate_closed")
	var melts: Array = result.get("choco", [])
	if not melts.is_empty():
		_choco_due[seq] = melts.duplicate()
	if not _nodes.has(id):
		_choco_reach(seq)
		_after_result(seq)
		_move_end(seq)
		_check_done.call_deferred()
		return
	var node: BlockNode = _nodes[id]
	var dir: Vector2 = Vector2(LevelData.side_dir(LevelData.block_side(node.view)))
	var dist := int(result.get("distance", 0))
	match kind:
		"exit":
			# khối kề bị bóc lớp phủ: hình giữ lớp tới khi khối này chạm thanh
			var strips: Array = result.get("stripped", [])
			for sid in strips:
				_cover_hold[sid] = int(_cover_hold.get(sid, 0)) + 1
			# bom kẹo: khối trong vùng nổ giữ hình tới lúc bom kẹo chạm thanh
			if bool(node.view.get("pop", false)):
				var popped: Array = result.get("popped", [])
				_hold_pops(popped)
				_pop_due[seq] = {"cells": node.cells.duplicate(), "ids": popped.duplicate()}
			_anim_exit(node, dir, seq, strips)
		"blocked":
			_anim_bounce(node, dir, float(dist), dist, str(result.get("blocker", "")), "", seq)
		"gate_closed":
			var gate_side := LevelData.block_side(node.view)
			_anim_bounce(node, dir, _cells_to_bar(node, dir), dist, "", gate_side, seq)
		"chained":
			Sfx.play("chain")
			_anim_chained(node, str(result.get("blocker", "")), seq)
		"peel":
			# node.view còn là trạng thái trước lượt này (_sync_states chạy sau)
			if int(node.view.get("ribbons", 0)) > 0:
				Sfx.play_or("ribbon", "layer")
			else:
				Sfx.play("layer")
			_anim_pop(node, seq)
	_after_result(seq)
	_move_end(seq)


## Xích, sương mù, hộp giấy đổi theo board ngay (lớp phủ chờ khối kề chạm thanh); hộp giấy bay về thanh thuộc lượt `seq`.
func _after_result(seq: int) -> void:
	if _board == null:
		return
	_sync_states(true, seq)


## Khối lao nhanh dần, gần tới thanh cùng màu thì chậm lại về tốc độ nghiền (trừ khối cuối trên bàn), chạm mặt trong
## của thanh rồi trôi qua thanh và bị nghiền thành khối vuông nhỏ. `strips`: khối kề có lớp phủ vỡ lúc chạm thanh.
func _anim_exit(node: BlockNode, dir: Vector2, seq: int, strips: Array = []) -> void:
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
	tw.finished.connect(_grind.bind(node, dir, side, seq, strips))


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
func _grind(node: BlockNode, dir: Vector2, side: String, seq: int, strips: Array = []) -> void:
	# The board was set up again (_clear) in the frame the flight ended: that move belongs to the old board.
	if node.is_queued_for_deletion():
		return
	_gate_reach(seq)
	_release_covers(strips)
	_choco_reach(seq)
	if _pop_due.has(seq):
		var due: Dictionary = _pop_due[seq]
		_pop_due.erase(seq)
		_pop_blast(due["cells"], due["ids"], node)
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
	var buzz := GRIND_HAPTIC_EVERY * GRIND_SPEED * _cell
	var state := {"done": 0.0, "passed": {}, "bits": counts.x, "small": counts.y, "spawned": 0, "spawned_small": 0, "phase": _rng.randf(), "buzz": buzz, "buzz_step": buzz}
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


## Một bước nghiền: dời khối, rung theo nhịp, rồi các ô vừa vắt qua mặt trong của thanh phun mảnh to và mảnh nhỏ.
## Cả khối ra state["bits"] mảnh to và state["small"] mảnh nhỏ (_grind_counts()): tới lúc này đã ra chừng ấy nhân phần
## diện tích khối đã qua thanh. Mảnh rải đều theo bề ngang các ô đang qua thanh bằng dãy tỉ lệ vàng, không chụm một chỗ.
func _grind_step(v: float, node: BlockNode, lc: Array, dir: Vector2, inner: float, outer: float, bits: CandyShards, start: Vector2, state: Dictionary) -> void:
	node.position = start + dir * v
	if v <= float(state["done"]):
		return
	state["done"] = v
	if v >= float(state["buzz"]):
		while v >= float(state["buzz"]):
			state["buzz"] = float(state["buzz"]) + float(state["buzz_step"])
		_grind_buzz()
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


## Một nhịp rung lúc khối đang nghiền qua thanh (nhịp đầu là rung của sfx_shatter lúc chạm thanh). Nhiều khối cùng
## nghiền thì giữ một nhịp chung: nhịp sát nhịp trước hơn GRIND_HAPTIC_GAP thì bỏ.
func _grind_buzz() -> void:
	var now := Time.get_ticks_msec()
	if now - _grind_buzz_ms < roundi(GRIND_HAPTIC_GAP * 1000.0):
		return
	_grind_buzz_ms = now
	Sfx.pulse("grind")


## Khối đã qua hết thanh: giờ cổng mới đổi theo lượt này (cổng nhịp khoá lại sau khối).
func _end_grind(clip: Control, bits: CandyShards, seq: int) -> void:
	clip.queue_free()
	bits.close()
	# Bàn hết khối: báo xong ngay (level tự chờ Config.CONTENT.win_card_delay_sec rồi hiện thẻ thắng), vụn vẫn bay
	# tiếp dưới thẻ; cổng không đổi nữa.
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
	# chỗ cũ tính từ ô lưới, không lấy node.position: tap lại lúc khối đang bật thì position đang lệch
	var home := _origin + Vector2(node.origin_cell) * _cell
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
			if int(b.view.get("ice", 0)) > 0 and str(b.view.get("cover", "")) == BoardState.COVER_FROST:
				ObstacleFx.frost_hit(_fx_root, world, -dir, _cell)
			elif int(b.view.get("ice", 0)) > 0:
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
	var home := _origin + Vector2(node.origin_cell) * _cell
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


## Khối còn lớp phủ bị chạm: pudding nén dẹt rồi rung như thạch, băng lắc ngang như khối sương. Không đi, không đổi gì
## trên bàn.
func _anim_covered(node: BlockNode) -> void:
	if str(node.view.get("cover", "")) == BoardState.COVER_FROST:
		_anim_fogged(node)
		return
	if node.busy:
		return
	node.busy = true
	_begin()
	var lc := node.local_cells()
	var bottom := -INF
	for c: Vector2i in lc:
		bottom = maxf(bottom, float(c.y) + 1.0)
	node.pivot_offset = Vector2(node.size.x * 0.5, bottom * _cell)
	node.wobble(Vector2(0, 1), COVER_SQUISH, COVER_SQUISH_TIME)
	var tw := node.create_tween()
	tw.tween_interval(COVER_SQUISH_TIME)
	tw.finished.connect(_finish_busy.bind(node))


## Khối hướng về thanh còn socola bị chạm: nhích về phía thanh rồi về chỗ, socola trên thanh nhún. Không đi, không đổi gì
## trên bàn, kể cả khi đường đang bị khối khác chặn.
func _anim_choco(node: BlockNode) -> void:
	var side := LevelData.block_side(node.view)
	var cover: ChocoCover = _choco_nodes.get(side, null)
	if cover != null:
		cover.poke()
	if node.busy:
		return
	node.busy = true
	_begin()
	var dir := Vector2(LevelData.side_dir(side))
	var home := _origin + Vector2(node.origin_cell) * _cell
	var tw := node.create_tween()
	tw.tween_property(node, "position", home + dir * _cell * CHOCO_NUDGE, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position", home, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.finished.connect(_finish_busy.bind(node))


## Thứ của lượt `seq` vừa chạm thanh của nó: các thanh còn socola bớt một lớp trên hình.
func _choco_reach(seq: int) -> void:
	if not _choco_due.has(seq):
		return
	var sides: Array = _choco_due[seq]
	_choco_due.erase(seq)
	for side in sides:
		_chip_choco(str(side), true)


## Hình theo board (búa gõ, refresh): thanh nào hiện nhiều lớp hơn board cộng phần còn chờ chạm thanh thì bớt cho khớp.
func _sync_choco(animate: bool) -> void:
	var now := _board.choco()
	var pending := {}
	for seq in _choco_due:
		for side in _choco_due[seq]:
			pending[side] = int(pending.get(side, 0)) + 1
	for side in _choco_shown.keys():
		var want := int(now.get(side, 0)) + int(pending.get(side, 0))
		while int(_choco_shown.get(side, 0)) > want:
			_chip_choco(str(side), animate)


## Bớt một lớp socola trên hình ở thanh `side`: mảng socola bong ra rơi vào bàn, số nảy. Lớp cuối thì socola vỡ tung,
## thanh nảy và sóng sáng chạy dọc thanh.
func _chip_choco(side: String, animate: bool) -> void:
	if not _choco_shown.has(side):
		return
	var left := int(_choco_shown[side]) - 1
	var cover: ChocoCover = _choco_nodes.get(side, null)
	var at := Vector2.ZERO
	if cover != null:
		at = cover.inner_point(_rng.randf_range(0.25, 0.75) if left > 0 else 0.5)
	if left > 0:
		_choco_shown[side] = left
		if cover != null:
			cover.set_layers(left, animate)
	else:
		_choco_shown.erase(side)
		_choco_nodes.erase(side)
		if cover != null:
			if animate:
				_begin()
				cover.melt_away(_end)
			else:
				cover.queue_free()
	if not animate or cover == null:
		return
	Sfx.play_or("choco", "layer", 0.0 if left <= 0 else CHOCO_CHIP_DB)
	var out := cover.out_dir()
	var xf := get_global_transform()
	if left > 0:
		_choco_chips(xf * at, out, CHOCO_CHIPS)
		BoardFx.sparkles(_fx_root, xf * at, ChocoCover.RAMP, -out, _cell / SPARK_SCALE_BUMP, SPARKS_BUMP)
		return
	# lớp cuối: cả lớp socola vỡ thành vụn dọc thanh, loé sáng, thanh nảy và sóng sáng chạy dọc thanh
	for p in cover.body_points(_cell):
		_choco_chips(xf * p, out, CHOCO_BREAK_CHIPS)
	BoardFx.impact_flash(_fx_root, xf * at, ChocoCover.SHINE, _cell * FLASH_BUMP * 1.5, 0.3, 0.7)
	BoardFx.sparkles(_fx_root, xf * at, ChocoCover.RAMP, -out, _cell / SPARK_SCALE_BUMP, SPARKS_SMASH)
	var bar := CandyFrame.bar_rect(side, _area, _unit)
	var along := bar.size.x if side == "up" or side == "down" else bar.size.y
	_frame.hit(side, bar.get_center(), along, 1.0, CandyFrame.SPIN_EXIT)


## Vụn socola (CandyShards, màu ChocoCover.RAMP) ở điểm `at` (toạ độ canvas), rơi vào trong bàn (ngược hướng `out`).
func _choco_chips(at: Vector2, out: Vector2, amount: int) -> void:
	var c := _cell * CHOCO_CHIP_CELL
	var xf := Transform2D(0.0, at - Vector2(0.5, 0.5) * c)
	CandyShards.chips(_fx_root, [Vector2i.ZERO], c, ChocoCover.RAMP, xf, Vector2(0.5, 0.5), out, amount, _rng)


## Bom kẹo vừa rời bàn trên board: các khối `ids` trong vùng nổ giữ nguyên hình (lớp phủ đang hiện, kể cả lớp còn chờ khối
## kề chạm thanh, và sương) tới lúc nổ.
func _hold_pops(ids: Array) -> void:
	for pid in ids:
		var n: BlockNode = _nodes.get(pid, null)
		if n == null:
			continue
		_pop_hold[pid] = {"ice": int(n.view.get("ice", 0)), "fog": bool(n.view.get("is_fog_hidden", false))}
		_cover_hold.erase(pid)


## Bom kẹo nổ (chạm thanh hoặc bị búa gõ): đầu ngòi loé, tiếng lách tách, sóng vuông phủ vùng nổ toả từ chỗ khối vừa
## rời; khối trong vùng vỡ lần lượt theo bậc khoảng cách (khoảng cách từ tâm ô gần nhất của khối tới tâm ô gần nhất của
## bom kẹo, mỗi giá trị khác nhau là một bậc), mỗi bậc trễ Config.POP_STAGGER giây. `cells`: ô của bom kẹo trên bàn.
func _pop_blast(cells: Array, ids: Array, node: BlockNode = null) -> void:
	var xf := get_global_transform()
	if node != null and is_instance_valid(node):
		var fuse := node.get_node_or_null("PopFuse") as PopFuse
		if fuse != null:
			var tip := fuse.get_global_transform() * fuse.tip()
			BoardFx.impact_flash(_fx_root, tip, Color(1.0, 0.9, 0.55), _cell * FLASH_BUMP * 1.6, 0.32, 0.8)
			BoardFx.sparkles(_fx_root, tip, ThemeKit.block_ramp("yellow"), Vector2.UP, _cell / SPARK_SCALE_BUMP, SPARKS_SMASH)
			fuse.burning = false
			fuse.hide()
	Sfx.play_or("pop", "shatter")
	# Bậc khoảng cách của mọi ô trong vùng nổ (trong lưới), cả ô trống.
	var own := {}
	for c: Vector2i in cells:
		own[c] = true
	var r := Config.POP_RADIUS
	var dist := {}  # ô -> khoảng cách
	for c: Vector2i in cells:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var q := c + Vector2i(dx, dy)
				if own.has(q) or q.x < 0 or q.y < 0 or q.x >= _board.width() or q.y >= _board.height():
					continue
				var d := Vector2(dx, dy).length()
				dist[q] = minf(float(dist.get(q, INF)), d)
	var levels: Array = []
	for q in dist:
		if not levels.has(dist[q]):
			levels.append(dist[q])
	levels.sort()
	var wave: Array = []
	var scale_k := xf.get_scale()
	for q: Vector2i in dist:
		var rect := Rect2(xf * (_origin + Vector2(q) * _cell), Vector2(_cell, _cell) * scale_k)
		wave.append([rect, levels.find(dist[q])])
	var w := PopFuse.Wave.new()
	w.setup(wave, _cell * scale_k.x)
	_fx_root.add_child(w)
	# Khối trong vùng nổ: bậc = bậc của ô gần bom kẹo nhất.
	var tiers := {}  # bậc -> [id]
	for pid in ids:
		var n: BlockNode = _nodes.get(pid, null)
		if n == null:
			_pop_hold.erase(pid)
			continue
		var best := INF
		for c: Vector2i in n.cells:
			best = minf(best, float(dist.get(c, INF)))
		var k := levels.find(best) if best < INF else 0
		if not tiers.has(k):
			tiers[k] = []
		tiers[k].append(pid)
	var budget := {"left": Config.POP_SFX_MAX}
	var keys := tiers.keys()
	keys.sort()
	for k in keys:
		_begin()
		var delay := float(k) * Config.POP_STAGGER
		if delay <= 0.0:
			_release_pops(_pop_gen, tiers[k], budget)
		else:
			get_tree().create_timer(delay).timeout.connect(_release_pops.bind(_pop_gen, tiers[k], budget))


## Một bậc của cú nổ: các khối `ids` hết giữ hình nên vỡ lớp phủ hoặc tan sương theo board; tiếng vỡ nhỏ hơn
## Config.POP_SFX_DB, cả cú nổ tối đa Config.POP_SFX_MAX tiếng (`budget`); rung một nhịp "pop_hit" mỗi bậc.
func _release_pops(gen: int, ids: Array, budget: Dictionary) -> void:
	if gen != _pop_gen:
		return
	Sfx.pulse("pop_hit")
	for pid in ids:
		if not _pop_hold.has(pid):
			continue
		_pop_hold.erase(pid)
		_sfx_db = Config.POP_SFX_DB
		_sfx_mute = int(budget["left"]) <= 0
		if _board != null:
			_sync_states(true)
		budget["left"] = int(budget["left"]) - 1
	_sfx_db = 0.0
	_sfx_mute = false
	_end()


## Lớp phủ của các khối `ids` vỡ trên hình (khối kề vừa chạm thanh): bỏ một lớp đang giữ rồi đọc lại từ board.
func _release_covers(ids: Array) -> void:
	if ids.is_empty():
		return
	for sid in ids:
		if not _cover_hold.has(sid):
			continue
		var k := int(_cover_hold[sid]) - 1
		if k <= 0:
			_cover_hold.erase(sid)
		else:
			_cover_hold[sid] = k
	if _board != null:
		_sync_states(true)


## Nảy to rồi về, loé sáng: hộp giấy bay đi lộ kẹo bên trong. Hạt do `_sync_states` lo theo chất liệu.
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
		v["ice"] = int(v["ice"]) + int(_cover_hold.get(id, 0))
		if _pop_hold.has(id):
			v["ice"] = int(_pop_hold[id]["ice"])
			v["is_fog_hidden"] = bool(_pop_hold[id]["fog"])
		var old := n.view
		var changed := false
		for k in ["color", "ice", "chained", "inner_color", "is_fog_hidden", "ribbons"]:
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
			if not _sfx_mute:
				Sfx.play("fog", _sfx_db)
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
			_cover_burst(n, old, v, mid, span)
		if str(old.get("inner_color", "")) != "" and str(v.get("inner_color", "")) == "":
			_box_fly(n, old, seq)
			BoardFx.sparkles(_fx_root, mid, ThemeKit.block_ramp(str(v.get("color", ""))), Vector2.UP, _cell / 110.0, 6)
		if int(old.get("ribbons", 0)) > int(v.get("ribbons", 0)):
			_box_fly(n, old, seq, true)
			BoardFx.sparkles(_fx_root, mid, ThemeKit.block_ramp(str(v.get("color", ""))), Vector2.UP, _cell / 110.0, 6)
	_refresh_keys()


## Một lớp phủ vỡ (khối kề vừa chạm thanh hoặc bị Phá): pudding bung bọt, băng vỡ mảnh, khối nảy nhẹ. Bóc lớp ngoài
## của khối 2 lớp thì hiệu ứng nhỏ hơn (COVER_HALF) và tiếng nhỏ hơn (COVER_HALF_DB).
func _cover_burst(n: BlockNode, old: Dictionary, v: Dictionary, mid: Vector2, span: Vector2) -> void:
	var frost := str(v.get("cover", "")) == BoardState.COVER_FROST
	var last := int(v.get("ice", 0)) <= 0
	var size := 1.0 if last else COVER_HALF
	var db := (0.0 if last else COVER_HALF_DB) + _sfx_db
	if frost:
		if not _sfx_mute:
			Sfx.play("ice", db)
		ObstacleFx.frost_burst(_fx_root, mid, _cell, span, size)
	else:
		if not _sfx_mute:
			Sfx.play_or("pudding", "ice", db)
		ObstacleFx.jelly_burst(_fx_root, mid, _cell, span, size)
	var ghost := {"ice": int(old.get("ice", 1)), "cover": str(v.get("cover", "")), "jelly_only": true,
		"color": old.get("color", "")}
	_spawn_ghost(n, ghost, lerpf(1.0, 1.28, size), 0.3)
	if not n.busy:
		_reveal_pop(n)


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
## Hộp rách xong thì cổng mới đổi theo lượt `seq`, như khối nghiền qua thanh. `ribbon`: lớp ruy băng ngoài (các dải cùng
## nơ, màu cũ) bay đi thay cho hộp, tới thanh thì bung thành sợi ruy băng.
func _box_fly(n: BlockNode, old_view: Dictionary, seq: int = 0, ribbon: bool = false) -> void:
	var box := old_view.duplicate()
	box["is_key"] = false
	box["special"] = false
	box["ribbon_only"] = ribbon
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
	tw.chain().tween_callback(_box_burst.bind(g, dir, side, color, seq, ribbon))


func _box_burst(g: BlockNode, dir: Vector2, side: String, color: String, seq: int, ribbon: bool = false) -> void:
	_gate_reach(seq)
	_choco_reach(seq)
	var mouth := g.get_global_transform() * _leading_point(g.local_cells(), dir)
	var span := maxf(g.size.x, g.size.y)
	_hit_bar(side, g, dir, false, 1.0, CandyFrame.SPIN_EXIT)
	if ribbon:
		ObstacleFx.ribbon_burst(_fx_root, mouth, dir, _cell, ThemeKit.block_color(color), span)
		Sfx.play("exit")
	else:
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
		_choco_reach(seq)
		return
	_gate_moves[seq]["left"] = int(_gate_moves[seq]["left"]) - 1
	# lưới an toàn: lượt đã xong hết hoạt ảnh mà thứ của nó chưa báo chạm thanh thì socola vẫn bớt
	if int(_gate_moves[seq]["left"]) <= 0:
		_choco_reach(seq)
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
## Gọi sau (hoặc trước) board.smash(id). `popped`: bom kẹo bị Phá thì các khối trong vùng nổ (Game.smash_block), vỡ
## lần lượt như lúc bom kẹo chạm thanh.
func smash_anim(id: String, popped: Array = []) -> void:
	if not _nodes.has(id):
		if _board != null:
			_sync_choco(true)
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
	var bomb := bool(n.view.get("pop", false))
	if bomb:
		_hold_pops(popped)
	if _board != null:
		_sync_states(true)
		_sync_choco(true)
	if bomb:
		_pop_blast(n.cells, popped, n)
