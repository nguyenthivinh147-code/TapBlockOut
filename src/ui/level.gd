extends Control
## Màn level: HUD, bàn cờ, booster, luồng hết MOVES, thắng, thua, restart.
## setup({challenge: true}) chạy Daily Challenge (Game.start_challenge) thay vì level kế tiếp; thắng thì về Home.
## setup({road_trip: true}) chạy level Road Trip đang chơi (Game.start_road_trip): không mất mạng, không hướng dẫn L1,
## booster mở theo level chính; hết bước thì xem quảng cáo hồi sinh, thắng thì popup Road Trip rồi closed("home")
## (màn Road Trip đưa về bản đồ).
## setup({special: true}) chạy Màn đặc biệt (Game.special_start, design.md mục 7): bàn lát kín có bom (SpecialBombs),
## không mất mạng, không cứu lượt, không chơi lại (nút Restart thành Rời màn); thắng / thua thì popup_special_end rồi
## đổi tại chỗ sang level chính kế (hoặc về Home). Thắng level chính Hard / VeryHard được vé thì mời vào Special ngay
## sau thẻ thắng (màn mưa bom bomb_curtain.gd).
## closed({"action": "home" | "no_lives"}). Popup mở qua Main.open_popup (hoặc lớp riêng khi chạy lẻ).
## HUD theo wireframe 3.4: lượt, tên level, restart, bánh răng (Home và Retry nằm trong popup cài đặt); chip mảnh dưới chip lượt.
## Hàng booster luôn đủ 3 ô; ô chưa mở tối đi, có ổ khoá và ghi level mở. Treo máy thì nhắc Gợi ý (bong bóng IdleTip).
## UI chỉ gọi Game và Sfx; hoạt ảnh bàn do BoardView lo.
## HUD, bàn (BoardView) và hàng booster là node trong scenes/level.tscn; script điền chữ, dữ liệu và nối signal.
## Dialog, dải cảnh báo độ khó và hiệu ứng bay vẫn sinh lúc chạy.

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const UiAtlas := preload("res://src/ui/ui_atlas.gd")
const Config := preload("res://src/config.gd")
const Unlocks := preload("res://src/meta/unlocks.gd")
const BoardState := preload("res://src/core/board_state.gd")
const HintFx := preload("res://src/ui/hint_fx.gd")
const MoveFx := preload("res://src/ui/move_fx.gd")
const RewardFly := preload("res://src/ui/reward_fly.gd")
const SmashFx := preload("res://src/ui/smash_fx.gd")
const CrystalFly := preload("res://src/ui/crystal_fly.gd")
const GlassCrack := preload("res://src/ui/glass_crack.gd")
const PraiseFx := preload("res://src/ui/praise_fx.gd")
const Pudding := preload("res://src/ui/pudding.gd")
const HUD_TONE := preload("res://src/ui/hud_tone.gdshader")
const SpecialBombs := preload("res://src/ui/special_bombs.gd")
const SpecialBoard := preload("res://src/core/special_board.gd")
const BombCurtain := preload("res://src/ui/bomb_curtain.gd")
const LOW_MOVES_SHADER := preload("res://src/ui/low_moves.gdshader")

const POPUP_RESCUE := "res://scenes/popup_rescue.tscn"
const POPUP_OFFER := "res://scenes/popup_offer.tscn"
const POPUP_REMOVE_ADS := "res://scenes/popup_remove_ads.tscn"
const WIN_CARD := "res://scenes/win_card.tscn"
const LOSE_CARD := "res://scenes/lose_card.tscn"
const SHOP_MINI := "res://scenes/shop_mini.tscn"
const BOOSTER_UNLOCKED := "res://scenes/booster_unlocked.tscn"
const INGAME_SETTINGS := "res://scenes/popup_ingame_settings.tscn"
const POPUP_LB_RESULT := "res://scenes/popup_lb_result.tscn"
const POPUP_LB_HOWTO := "res://scenes/popup_lb_howto.tscn"
const POPUP_RT_WIN := "res://scenes/popup_road_trip_win.tscn"
const POPUP_KEEP := "res://scenes/popup_keep_playing.tscn"
const POPUP_STREAK_KEEP := "res://scenes/popup_streak_keep.tscn"
const POPUP_NOTICE := "res://scenes/popup_notice.tscn"
const POPUP_RATE := "res://scenes/popup_rate.tscn"
const HELPER_PACK := "res://scenes/popup_helper_pack.tscn"
const TUTORIAL_INTRO := "res://scenes/tutorial_intro.tscn"
const POPUP_SPECIAL := "res://scenes/popup_special.tscn"
const POPUP_SPECIAL_END := "res://scenes/popup_special_end.tscn"
## Bom chỉ trừ tối đa chừng này giây mỗi khung (khung giật, máy chậm không làm bom nhảy cóc).
const BOMB_MAX_STEP := 0.25
## Candy-cane frame and skull badge of the difficulty banner, by tier ("hard", "very_hard"); the layer scene holds the
## Hard pair. Built by tools/make_warn_banner_art.py, both tiers the same size.
const WARN_ART := "res://assets/ui/warn_banner/warn_%s_%s.png"
## HUD difficulty pill by tier, in the tier color like Home (home.gd TIERS) and the warning banner: Hard strawberry red
## (tools/make_hud_pill_hard.py turns the hue of hud_pill.png), Very Hard grape purple. Text outline and shadow are the
## purple pill's ones turned to the same hue. The scene's pill gives the 9-slice margins.
const PILL_TIERS := {
	"hard": {"tex": "res://assets/ui/hud/hud_pill_hard.png", "outline": Color("9E2035"), "shadow": Color("6E1C29")},
	"very_hard": {"tex": "res://assets/ui/hud/hud_pill.png", "outline": Color("5B1F9E"), "shadow": Color("3A1C6E")},
}
const BOOSTERS := ["hint", "move", "smash"]
const FREE_PLACEMENT := "booster_free"
const MECHS := Unlocks.MECHS
## Ô booster chưa mở: tô tối nền và icon (ổ khoá, nhãn là node con nên giữ màu).
const LOCKED_TINT := Color(0.55, 0.55, 0.62)


## Hộp thoại nhỏ dựng bằng code theo PopupOkLayer (color-cube-match-puzzle). items: [{id, text, kind, name, close}].
## Bấm nút phát chosen(id), rồi closed(id) nếu close (mặc định true). Back của Android phát closed(null).
## Mục id "close" là nút X (và chạm nền mờ) như PopupOkUICoreLayer.closeButtons; các mục khác nằm ở hàng nút,
## mục "ghost" bên trái như Cancel của prefab. art: ảnh bên trái chữ, đặt như HeartIcon của PopupKeepPlaying.
## Mục mua bằng gold: {gold: giá} thay cho text, nút vàng chỉ có icon gold và giá; dim: true làm mờ (thiếu gold).
class Dialog extends Control:
	const UnityUI := preload("res://src/ui/unity_ui.gd")
	const UnityKit := preload("res://src/ui/unity_kit.gd")
	## kind -> màu nút UnityKit.BUTTONS (Ok xanh lá, Cancel xanh dương như PopupOkLayer).
	const KIND_COLOR := {"primary": "green", "secondary": "gray", "danger": "red", "ghost": "blue", "video": "blue", "gold": "yellow"}
	## Hàng nút của PopupOkLayer: rộng 612, nút 280x120, cách 52.
	const ROW_W := 612.0
	const ROW_SP := 52.0
	const BTN := Vector2(280, 120)
	signal closed(result: Variant)
	signal chosen(id: String)
	var buttons: Dictionary = {}
	var title_label: Label = null
	var body_label: Label = null
	var message_label: Label = null
	var ui: RefCounted = null

	func _init(title: String = "", body: String = "", items: Array = [], message: String = "", art: Texture2D = null) -> void:
		name = "Dialog"
		set_anchors_preset(Control.PRESET_FULL_RECT)
		ui = UnityUI.build(self, "PopupOkLayer")
		title_label = ui.text("Panel/Image/txtHeader", title)
		title_label.name = "TitleLabel"
		var content: Control = ui.node("Panel/Content")
		if body != "":
			body_label = ui.text("Panel/Content/Description", body)
			body_label.name = "BodyLabel"
		else:
			ui.show("Panel/Content/Description", false)
		if art != null:
			# PopupKeepPlaying: icon left in the well, description to its right.
			var icon: RefCounted = UnityKit.add(content, UnityKit.spec("PopupKeepPlaying", "Panel/Content/HeartIcon"))
			icon.root.name = "Art"
			icon.texture("", art)
			UnityUI.image_of(icon.root).preserve_aspect = true
			if body_label != null:
				_set_rect(body_label, UnityKit.spec("PopupKeepPlaying", "Panel/Content/Description").r)
		var ms := UnityKit.spec("PopupOkLayer", "Panel/Content/Description")
		ms.n = "MessageLabel"
		ms.txt.s = message
		ms.txt.fs = 30.0
		ms.txt.auto = [18.0, 30.0]
		ms.txt.c = "ffffffff"
		ms.txt.mat = "Baloo Outline - Red"
		# Bottom strip of the cream well (well spans y 133..440 of the 660 panel).
		message_label = UnityKit.add(content, ms, Rect2(72, 392, 580, 46)).root as Label
		message_label.visible = message != ""
		ui.show("Panel/Content/Button/Cancel", false)
		ui.show("Panel/Content/Button/Ok", false)
		var x: Button = ui.button("Panel/Top/btnTurnOff")
		x.visible = false
		var row_items: Array = []
		for it in items:
			if str(it.get("id", "")) == "close":
				var id := str(it.id)
				x.name = str(it.get("name", "Btn_close"))
				x.visible = true
				x.connect("clicked", _on_pressed.bind(id, bool(it.get("close", true))))
				ui.on_click("Bg", _on_pressed.bind(id, bool(it.get("close", true))))
				buttons[id] = x
			elif str(it.get("kind", "")) == "ghost":
				row_items.push_front(it)
			else:
				row_items.append(it)
		var n := row_items.size()
		var w := minf(BTN.x, (ROW_W - ROW_SP * (n - 1)) / maxf(1.0, n))
		for it in row_items:
			var id := str(it.get("id", ""))
			var kind := str(it.get("kind", "primary"))
			var v: RefCounted = UnityKit.button(ui.node("Panel/Content/Button"), str(KIND_COLOR.get(kind, "green")),
				str(it.get("text", "")), Rect2(Vector2.ZERO, Vector2(w, BTN.y)), _on_pressed.bind(id, bool(it.get("close", true))))
			v.root.name = str(it.get("name", "Btn_" + id))
			if it.has("gold"):
				UnityKit.gold_price(v.root, int(it.gold))
			if bool(it.get("dim", false)):
				v.root.modulate.a = 0.6
			if kind == "video":
				# PopupReviveLayer AdsBtn: TV icon on the top-right corner, text kept clear of it.
				UnityKit.add(v.root, UnityKit.spec("PopupReviveLayer", "Bg/Panel/Content/GameObject/AdsBtn/Image"))
				var out: Control = v.node("Out")
				var r: Dictionary = out.get_meta("u_rect")
				r.pos = Vector2(-20, (r.pos as Vector2).y)
				r.size = Vector2(-40, (r.size as Vector2).y)
				UnityUI.apply_rect(out)
			buttons[id] = v.root
		ui.relayout("Panel/Content/Button")

	func _ready() -> void:
		# Built in _init, before the dialog is in the tree: anchored sizes were still 0, so lay the row out again.
		ui.relayout("Panel/Content/Button")

	## Replaces a node's RectTransform with an exported rect array [amin.x, amin.y, amax.x, amax.y, pos, size, pivot].
	static func _set_rect(c: Control, r: Array) -> void:
		c.set_meta("u_rect", {"amin": Vector2(r[0], r[1]), "amax": Vector2(r[2], r[3]), "pos": Vector2(r[4], r[5]),
			"size": Vector2(r[6], r[7]), "pivot": Vector2(r[8], r[9])})
		UnityUI.apply_rect(c)

	func _on_pressed(id: String, close: bool) -> void:
		chosen.emit(id)
		if close:
			closed.emit(id)


class Waiter extends RefCounted:
	signal done(result: Variant)

	func fire() -> void:
		done.emit(null)


## Trạng thái: intro (chưa chơi) | playing | dialog | resolving | over | left.
var state: String = "intro"
var attempt: Dictionary = {}
var board: BoardState = null
var board_view: Control = null
var title_label: Label = null
var hard_badge: Control = null
## Stylebox of the difficulty pill by tier (PILL_TIERS), built once from the scene's pill.
var _pill_boxes := {}
var moves_label: Label = null
## Khung MOVES chứa moves_label; dấu "+" của +Move bay tới và nảy khung này.
var moves_chip: PanelContainer = null
## Chip đếm mảnh leaderboard đã nhặt / tổng khối đặc biệt (thanh trên, dưới chip lượt); ẩn khi level không có khối đặc biệt.
var piece_chip: PanelContainer = null
var piece_icon: TextureRect = null
var piece_label: Label = null
var tut_label: Label = null
var clap_label: Label = null
var toast_label: Label = null
var smash_label: Label = null
var settings_button: Button = null
var restart_button: Button = null
## Booster id -> button, corner badge (count left or "+"), lock (shown while locked). No caption under the buttons.
var booster_buttons: Dictionary = {}
var booster_badges: Dictionary = {}
var booster_locks: Dictionary = {}
## Mốc bắt đầu "đang nghĩ" (ms); test lùi mốc này để thử tiếng vỗ tay.
var think_start_ms: int = 0
## Mốc lần chạm màn hình cuối (ms) để nhắc Gợi ý khi treo máy; test lùi mốc này để thử.
var idle_start_ms: int = 0
## Bong bóng "Available Block : N" trên nút Gợi ý; gốc node là đầu đuôi bong bóng.
var idle_tip: Control = null

var _built: bool = false
var _challenge: bool = false
var _road_trip: bool = false
var _special: bool = false
## Bom của Màn đặc biệt (SpecialBombs), con của màn; rỗng ở level khác.
var bombs: Node = null
var _app_paused: bool = false
var _skip_tick: bool = false
var _restart_icon: Texture2D = null
var _level: int = 0
var _smash_mode: bool = false
var _caption_max_w: float = 0.0  # caption bubble wraps past this width (the board frame's), 0 = not laid out yet
var _offer_id: String = ""
var _overlay: Control = null
var _hint_fx: Control = null  # sao Gợi ý đang bay; còn bay thì bấm Gợi ý không làm gì
var _moves_pending: int = 0  # lượt +Move đã cộng vào bàn nhưng dấu "+" chưa bay tới chip lượt
var _moves_cashed: int = 0  # lượt thừa thẻ thắng đã đổi ra gold (đồng gold đã rời chip lượt)
var _chip_tw: Tween = null
var _warn: ColorRect = null  # red vignette of the last move, between the HUD and the popups
var _warn_pulse_tw: Tween = null  # loops the MOVES chip scale and the vignette breath
var _warn_fade_tw: Tween = null
var _warn_on: bool = false
var _pieces_pending: int = 0  # mảnh đã nhặt nhưng icon crystal chưa bay tới chip mảnh
var _toast_token: int = 0
var _left: bool = false
var _waiters: Array = []
var _idle_bulb: TextureRect = null  # bóng đèn vàng booster_hint phủ lên nút Gợi ý trong lúc nhắc
var _idle_count: Label = null
var _nudging: bool = false  # đang nhắc Gợi ý (nút lắc hoặc bong bóng đang hiện)
var _nudge_token: int = 0
var _nudge_tweens: Array[Tween] = []
var _card_path: String = ""  # thẻ kết quả đang nạp nền (load_threaded_request), chưa lấy ra
var _card_scene: PackedScene = null  # thẻ kết quả đã nạp, giữ để nằm trong cache suốt màn


func setup(args: Dictionary) -> void:
	_challenge = bool(args.get("challenge", false))
	_road_trip = bool(args.get("road_trip", false)) and not _challenge
	_special = bool(args.get("special", false)) and not _challenge and not _road_trip
	Sfx.music(Sfx.MUSIC_LEVEL)
	_build()
	_warm_result_card()
	_start_level()


func _exit_tree() -> void:
	# Màn bị gỡ giữa chừng: cho các luồng đang đợi popup kết thúc, không treo.
	_left = true
	for w in _waiters.duplicate():
		(w as Waiter).done.emit(null)
	_waiters.clear()
	# Nạp nền chưa lấy ra (rời màn trước khi thắng): lấy để trả token của ResourceLoader.
	_take_result_card()
	for sig in [Game.inv_changed, Game.coins_changed]:
		if (sig as Signal).is_connected(_on_game_changed):
			(sig as Signal).disconnect(_on_game_changed)
	if Game.offer_ready.is_connected(_on_offer_ready):
		Game.offer_ready.disconnect(_on_offer_ready)


func _build() -> void:
	if _built:
		return
	_built = true
	add_to_group(RewardFly.GROUP)
	# Background, top bar (moves, title, difficulty, restart, settings, piece chip), board holder with BoardView and
	# the overlay labels, booster row and LocalPopups are nodes of scenes/level.tscn.
	# The top bar and booster row alone take height, so the cell size stays the same across levels.
	moves_chip = %MovesChip
	moves_label = %MovesLabel
	title_label = %TitleLabel
	hard_badge = %HardBadge
	restart_button = %RestartButton
	settings_button = %SettingsButton
	piece_chip = %PieceChip
	piece_icon = %PieceIcon
	piece_label = %PieceLabel
	board_view = %BoardView
	clap_label = %ClapLabel
	toast_label = %ToastLabel
	tut_label = %TutLabel
	smash_label = %SmashLabel
	_overlay = %LocalPopups
	(%MovesCaption as Label).text = tr("level_moves").to_upper()
	_build_warn()
	title_label.text = ""
	moves_label.text = ""
	(hard_badge as Label).text = tr("level_hard")
	hard_badge.visible = false
	var pill_box := hard_badge.get_theme_stylebox("normal") as StyleBoxTexture
	for tier: String in PILL_TIERS:
		var box := pill_box.duplicate() as StyleBoxTexture
		box.texture = load(str(PILL_TIERS[tier].tex)) as Texture2D
		_pill_boxes[tier] = box
	piece_label.text = ""
	piece_chip.visible = false
	clap_label.text = tr("level_clap")
	clap_label.visible = false
	toast_label.text = ""
	toast_label.visible = false
	smash_label.text = tr("booster_smash_pick")
	_fit_caption(smash_label)
	_set_tut("")
	restart_button.pressed.connect(_on_restart_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	board_view.block_tapped.connect(_on_block_tapped)
	# BoardView re-lays its frame on resize first (connected in its _ready), then the captions follow the frame.
	board_view.resized.connect(_place_captions)
	# Booster row: always 3 slots, a locked slot shows its lock (see _refresh_hud).
	for kind in BOOSTERS:
		var b: Button = get_node("%BoosterButton_" + kind)
		b.pressed.connect(_on_booster_pressed.bind(kind))
		booster_buttons[kind] = b
		booster_badges[kind] = get_node("%BoosterBadge_" + kind)
		booster_locks[kind] = get_node("%BoosterLock_" + kind)
	# Tone down the purple HUD sprites; a CanvasItem material does not reach child nodes, so labels, badges and locks
	# keep their colors. The piece chip draws its frame in the PieceFrame child, the MOVES chip in its own panel.
	var tone := ShaderMaterial.new()
	tone.shader = HUD_TONE
	tone.set_shader_parameter("saturation", Config.HUD_TONE_SAT)
	tone.set_shader_parameter("value", Config.HUD_TONE_VAL)
	tone.set_shader_parameter("gloss_cut", Config.HUD_TONE_GLOSS)
	for c: CanvasItem in hud_toned():
		c.material = tone
	_restart_icon = restart_button.icon
	bombs = SpecialBombs.new()
	bombs.name = "SpecialBombs"
	add_child(bombs)
	idle_tip = %IdleTip
	idle_tip.visible = false
	(%IdleTipLabel as Label).text = tr("level_idle_blocks")
	_idle_count = %IdleTipCount
	_idle_bulb = %BoosterNudge_hint
	_idle_bulb.visible = false

	Game.inv_changed.connect(_on_game_changed)
	Game.coins_changed.connect(_on_game_changed)
	Game.offer_ready.connect(_on_offer_ready)


func _on_game_changed(_v: Variant = null) -> void:
	_refresh_hud()


## RewardFly: a booster received in the level flies into its button (an unlocked one).
func reward_target(kind: String) -> Control:
	if not _built or not booster_buttons.has(kind) or not (booster_badges[kind] as Control).visible:
		return null
	return booster_buttons[kind]


## RewardFly: a booster landed, its badge counts on.
func reward_refresh() -> void:
	_refresh_hud()


func _on_offer_ready(id: String) -> void:
	_offer_id = id


# --- popup ---

func _host() -> Node:
	var n := get_parent()
	while n != null:
		if n.has_method("add_popup") and n.has_method("open_popup"):
			return n
		n = n.get_parent()
	return null


## Đợi `node.closed`; trả kết quả, hoặc null nếu màn bị gỡ trước.
func _wait_closed(node: Node) -> Variant:
	var w := Waiter.new()
	_waiters.append(w)
	node.connect("closed", func(res: Variant) -> void: w.done.emit(res), CONNECT_ONE_SHOT)
	var r: Variant = await w.done
	_waiters.erase(w)
	return r


func _show_node(node: Node) -> void:
	var h := _host()
	if h != null:
		h.call("add_popup", node)
		return
	_overlay.add_child(node)
	if node.has_signal("closed"):
		node.connect("closed", func(_r: Variant) -> void: node.queue_free())


## Mở popup scene, đợi closed. Trả kết quả của popup (null khi Back).
func _popup_scene(path: String, args: Dictionary = {}) -> Variant:
	var node: Node = null
	var h := _host()
	if h != null:
		node = h.call("open_popup", path, args)
	else:
		node = (load(path) as PackedScene).instantiate()
		_show_node(node)
		if node.has_method("setup"):
			node.call("setup", args)
	if node == null:
		return null
	return await _wait_closed(node)


func _ask(dlg: Control) -> Variant:
	_show_node(dlg)
	return await _wait_closed(dlg)


func _set_state(s: String) -> void:
	state = s
	if board_view != null:
		board_view.input_enabled = s == "playing"
	if s == "playing":
		idle_start_ms = Time.get_ticks_msec()
	elif _nudging:
		_end_nudge()


func _reset_think() -> void:
	think_start_ms = Time.get_ticks_msec()


func _leave(action: String) -> void:
	if _left:
		return
	_left = true
	_set_state("left")
	closed.emit({"action": action})


func _can_play() -> bool:
	return _road_trip or _special or bool(Game.lives_view().get("can_play", true))


## Level that boosters unlock by: the main level in Road Trip and Special Bomb, whose level numbers are their own.
func _unlock_ref() -> int:
	return int(Game.s.level) if _road_trip or _special else _level


## Back của Android khi không có popup: như bấm Home (Màn đặc biệt: như Rời màn).
func on_back() -> void:
	if _special:
		_on_leave_special()
		return
	_on_home_pressed()


# --- bắt đầu level ---

func _start_level(warn: bool = true) -> void:
	_set_state("intro")
	_set_smash_mode(false)
	_moves_pending = 0
	_moves_cashed = 0
	_pieces_pending = 0
	for ch in _overlay.get_children():
		# A bomb's cracked glass may still be fading when "Level N" starts the next level in place.
		if ch.get_script() == CrystalFly or ch.get_script() == GlassCrack:
			ch.queue_free()
	# Daily Challenge sinh trong game: màn chờ ngắn, vẽ xong mới sinh.
	if _challenge and Game.challenge_needs_generation():
		_set_tut(tr("common_loading"))
		await get_tree().process_frame
		await get_tree().process_frame
		if _left:
			return
	if _special:
		attempt = Game.special_start()
	elif _road_trip:
		attempt = Game.start_road_trip()
	else:
		attempt = Game.start_challenge() if _challenge else Game.start_attempt()
	if attempt.is_empty():
		_leave("home")
		return
	# Block body SDFs missing from the baked bank build on worker threads. The Daily Challenge (made at run time) waits
	# for them behind its loading line; file levels are baked, and a stale bank only makes the first draw wait.
	Pudding.prewarm(_board_shapes(attempt.board))
	if _challenge and not Pudding.is_warm():
		_set_tut(tr("common_loading"))
		while not Pudding.is_warm():
			await get_tree().process_frame
			if _left:
				return
	board = attempt.board
	_level = int(attempt.level)
	if _special:
		title_label.text = tr("special_title")
	else:
		title_label.text = tr("challenge_title") if _challenge else tr("level_title") % _level
	restart_button.icon = ThemeKit.icon("ui_home") if _special else _restart_icon
	var is_hard := bool(attempt.get("hard", false)) and not _special
	var very_hard := false
	if _road_trip:
		very_hard = int(attempt.get("difficulty", 1)) >= 3
	elif not _challenge:
		very_hard = is_hard and Game.difficulty_of(_level) == "very_hard"
	hard_badge.visible = is_hard
	(hard_badge as Label).text = tr("level_very_hard") if very_hard else tr("level_hard")
	_style_pill("very_hard" if very_hard else "hard")
	_set_tut(_mech_hint())
	board_view.setup(board)
	board_view.set_specials(attempt.get("specials", []))
	bombs.call("setup", board_view, attempt.get("bombs", []))
	_place_captions()
	_refresh_hud()
	while not _special:
		var kind := Game.claim_gift()
		if kind == "":
			break
		# Quà đã vào kho: scene giới thiệu booster mới (wireframe 3.8) với số trong kho; chạm đâu hoặc Back thì đi tiếp.
		await _popup_scene(BOOSTER_UNLOCKED, {"view": {"kind": kind, "count": int(Game.s.inv.get(kind, 0))}})
		if _left:
			return
	# Level dạy cơ chế của level chính: cùng popup đó giới thiệu cơ chế mới, một lần; chạm đâu hoặc Back thì đi tiếp.
	var mech := "" if _challenge or _road_trip or _special else Game.claim_mech_intro(_level)
	if mech != "":
		await _popup_scene(BOOSTER_UNLOCKED, {"view": {"mech": mech}})
		if _left:
			return
	# Level có khối crystal đầu tiên (mở Leaderboard, Config.UNLOCK.leaderboard): popup Cách hoạt động (popup nút "i" của Leaderboard); một lần.
	if Game.lb_take_guide(attempt):
		await _popup_scene(POPUP_LB_HOWTO)
		if _left:
			return
	# Màn đặc biệt lần đầu: hướng dẫn (khung popup vật cản mới) với quả bom và luật; một lần.
	if _special and bool(Game.special_view().guide):
		_set_state("dialog")
		Game.special_mark_guide()
		await _popup_scene(BOOSTER_UNLOCKED, {"view": {"special": true}})
		if _left:
			return
	_refresh_hud()
	if warn and is_hard:
		_set_state("dialog")
		await _show_difficulty_banner(very_hard)
		if _left:
			return
	# Hướng dẫn lần đầu (wireframe 1.5): trước khi chơi L1 lần đầu, bàn tay chỉ vào một ô của khối gợi ý; chạm khối
	# đó là nước đi đầu tiên.
	var intro_tap := ""
	if _level == 1 and not _road_trip and not _challenge and not _special and Game.take_intro():
		_set_state("dialog")
		var aim := board.hint()
		if aim != "":
			board_view.highlight(aim)
		var r: Variant = await _popup_scene(TUTORIAL_INTRO, {"view": _intro_view(aim)} if aim != "" else {})
		if _left:
			return
		if aim != "" and r is Dictionary and str(r.get("action", "")) == "tap":
			intro_tap = aim
	_set_state("playing")
	_reset_think()
	if intro_tap != "":
		Sfx.play("tap")
		_on_block_tapped(intro_tap)
	elif _level == 1 and not _road_trip and not _special:
		_set_tut(tr("tut_tap"))
		board_view.highlight(board.hint())


## View of tutorial_intro for block `id`: aim() is the global rect of the cell the hand pokes (the block's cell nearest
## its centre, as strike_point), hit(p) whether the global point p is on that block.
func _intro_view(id: String) -> Dictionary:
	return {
		"aim": func() -> Rect2:
			var s: float = board_view.cell_size() * board_view.get_global_transform().get_scale().x
			return Rect2(board_view.strike_point(id) - Vector2(s, s) * 0.5, Vector2(s, s)),
		"hit": func(p: Vector2) -> bool:
			return board_view.block_at(board_view.get_global_transform().affine_inverse() * p) == id,
	}


## Bỏ ván mất mạng hoặc làm chuỗi Win Streak tụt: hỏi bằng popup 4.6, hoặc 9.5 khi chuỗi tụt (design.md mục 7
## "Win Streak"). true khi người chơi chọn bỏ (hoặc không có gì để mất).
func _confirm_quit(mode: String, life: bool) -> bool:
	var streak := Game.streak_at_stake(attempt)
	if not life and not streak:
		return true
	var r: Variant = null
	if streak:
		var v: Dictionary = Game.streak_view()
		r = await _popup_scene(POPUP_STREAK_KEEP, {"view": {"mode": mode, "streak": int(v.streak),
			"drop_to": int(v.floor), "life": life}})
	else:
		r = await _popup_scene(POPUP_KEEP, {"view": {"mode": mode}})
	return r is Dictionary and str(r.get("action", "")) == "quit"


## ShowLostStreakNotify: chuỗi vừa tụt thì báo "Bạn đã mất chuỗi" (popup_notice), một lần.
func _notify_streak_lost() -> void:
	if Game.streak_take_lost():
		await _popup_scene(POPUP_NOTICE, {"view": {"title": "streak_title", "body": "streak_lost"}})


## Local cells of every block on `b`, the shapes Pudding draws the bodies of.
static func _board_shapes(b: BoardState) -> Array:
	var out: Array = []
	for id in b.block_ids():
		out.append(Pudding.local_shape(b.block_view(id)["cells"]))
	return out


## Dải cảnh báo độ khó theo WarningHardLevelLayer (color-cube-match-puzzle), khung kẹo gậy và huy hiệu đầu lâu theo
## bậc (WARN_ART: Hard đỏ dâu, VeryHard tím nho; scene bỏ tam giác "!" và vạch chắn của prefab). WarningHardAnimation
## hiện dần 0.2s rồi nhịp đầu lâu và chữ; giữ Config.CONTENT.hard_banner_sec (chạm để bỏ qua), mờ đi 0.2s rồi tự vào
## chơi. Đầu lâu bay về huy hiệu độ khó trên HUD (SkullTarget của prefab) trong lúc đã chơi được.
func _show_difficulty_banner(very_hard: bool) -> void:
	await get_tree().process_frame
	if _left:
		return
	var root := Control.new()
	root.name = "DifficultyBanner"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var v: RefCounted = UnityUI.build(root, "WarningHardLevelLayer")
	var text: Label = v.text("Panel/WarningExtreme/HardLevelTxt", tr("level_very_hard") if very_hard else tr("level_hard"))
	text.name = "Text"
	var skull: Control = v.node("GameObject/Skull")
	v.texture("GameObject/Skull", ThemeKit.icon("ui_superhard" if very_hard else "ui_hard"))
	UnityUI.image_of(skull).preserve_aspect = true
	if very_hard:
		for p in [["Panel/WarningExtreme/Bar", "frame"], ["Panel/WarningExtreme/Center", "badge"]]:
			UnityUI.image_of(v.node(p[0])).tex = load(WARN_ART % [p[1], "very_hard"]) as Texture2D
	var skip := [false]
	root.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed or ev is InputEventScreenTouch and ev.pressed:
			skip[0] = true)
	Sfx.play("button")
	# WarningHardAnimation.PlayAnim: fade in, then yoyo pulses (InOutSine) of the skull and the text.
	var extreme: Control = v.node("Panel/WarningExtreme")
	extreme.modulate.a = 0.0
	var loops: Array[Tween] = []
	var tin := root.create_tween()
	tin.tween_property(extreme, "modulate:a", 1.0, 0.2)
	tin.tween_callback(func() -> void:
		for p in [["GameObject/Skull", 1.12, 0.4], ["Panel/WarningExtreme/HardLevelTxt", 1.12, 0.4]]:
			var n: Control = v.node(p[0])
			var tw := n.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(n, "scale", Vector2.ONE * float(p[1]), float(p[2]))
			tw.tween_property(n, "scale", Vector2.ONE, float(p[2]))
			loops.append(tw))
	var deadline := Time.get_ticks_msec() + int(float(Config.CONTENT.hard_banner_sec) * 1000.0)
	while not _left and not skip[0] and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if _left or not is_instance_valid(root):
		return
	# StopAnimAsync: stop the loops, fade out.
	for tw in loops:
		tw.kill()
	var tout := root.create_tween()
	tout.tween_property(extreme, "modulate:a", 0.0, 0.2)
	await tout.finished
	if _left or not is_instance_valid(root):
		return
	# PlaySkullFlyAnimation runs while the level is already playable; the warning itself is over.
	root.name = "DifficultyBannerOut"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fly_skull(root, skull, v.node("GameObject/SkullTarget"))


## Đầu lâu bay tới huy hiệu độ khó (hoặc SkullTarget) 0.6s: di chuyển InOutQuad, thu còn 0.5 OutQuad.
func _fly_skull(root: Control, skull: Control, fallback: Control) -> void:
	var to_global := hard_badge.get_global_rect().get_center() if hard_badge != null and hard_badge.is_visible_in_tree() \
		else fallback.get_global_rect().get_center()
	var parent := skull.get_parent() as Control
	var to := parent.get_global_transform().affine_inverse() * to_global - skull.size * 0.5
	skull.scale = Vector2.ONE
	var tw := skull.create_tween().set_parallel(true)
	tw.tween_property(skull, "position", to, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(skull, "scale", Vector2(0.5, 0.5), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(root.queue_free)


## Level dạy cơ chế (14, 30, 40, 55, 70, 90, 110, 130, 150): một dòng "Tên: luật" ở đầu level. Challenge không có.
func _mech_hint() -> String:
	if _challenge or _road_trip or _special:
		return ""
	for m in MECHS:
		if _level == int(Config.UNLOCK.get(m, -1)):
			return "%s: %s" % [tr("mech_" + m), tr("mech_%s_desc" % m)]
	return ""


func _touched() -> bool:
	return int(attempt.taps) > 0 or board.moves_left() < int(attempt.moves0) \
		or board.remaining_count() < int(attempt.count0)


# --- HUD ---

## Difficulty pill in the tier color (PILL_TIERS): sprite, text outline and shadow.
func _style_pill(tier: String) -> void:
	var t: Dictionary = PILL_TIERS[tier]
	hard_badge.add_theme_stylebox_override("normal", _pill_boxes[tier])
	hard_badge.add_theme_color_override("font_outline_color", t.outline)
	hard_badge.add_theme_color_override("font_shadow_color", t.shadow)


## Nodes drawing the candy HUD sprites that hud_tone.gdshader tones down: restart, settings, the 3 booster buttons,
## the MOVES chip panel, the piece chip frame and the difficulty pill (purple, red on Hard). The pill is a Label
## drawing its own text, so the text outline gets the same tone.
func hud_toned() -> Array[CanvasItem]:
	var out: Array[CanvasItem] = [restart_button, settings_button, moves_chip, piece_chip.get_node("PieceFrame"),
			hard_badge]
	for kind in BOOSTERS:
		out.append(booster_buttons[kind])
	return out


func _refresh_hud() -> void:
	if not _built or board == null:
		return
	var shown := maxi(0, board.moves_left() - _moves_pending - _moves_cashed)
	moves_label.text = str(shown)
	_set_low_moves(shown == Config.LOW_MOVES and not board.is_won() and state != "over" and state != "left")
	var total := (attempt.get("specials", []) as Array).size()
	piece_chip.visible = total > 0
	piece_label.text = "%d/%d" % [int(attempt.get("pieces", 0)) - _pieces_pending, total]
	for kind in BOOSTERS:
		var open := Unlocks.is_open(kind, _unlock_ref())
		(booster_buttons[kind] as Button).self_modulate = Color.WHITE if open else LOCKED_TINT
		(booster_locks[kind] as Control).visible = not open
		var badge: Label = booster_badges[kind]
		badge.visible = open
		var n := maxi(int(Game.s.inv.get(kind, 0)) - RewardFly.held(kind), 0)
		badge.text = (tr("booster_count") % n) if n > 0 else ""
		badge.add_theme_stylebox_override("normal", _badge_box(n > 0))


## Red vignette node of the last-move warning: full screen, ignores touches, sits above the HUD and below IdleTip and
## the popups. Hidden until _set_low_moves(true).
func _build_warn() -> void:
	_warn = ColorRect.new()
	_warn.name = "LowMovesWarn"
	_warn.set_anchors_preset(Control.PRESET_FULL_RECT)
	_warn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warn.visible = false
	var mat := ShaderMaterial.new()
	mat.shader = LOW_MOVES_SHADER
	mat.set_shader_parameter("reach", Config.LOW_MOVES_REACH)
	mat.set_shader_parameter("max_alpha", Config.LOW_MOVES_ALPHA)
	mat.set_shader_parameter("amount", 0.0)
	mat.set_shader_parameter("breath", 0.0)
	_warn.material = mat
	_warn.resized.connect(func() -> void: mat.set_shader_parameter("rect_size", _warn.size))
	add_child(_warn)
	move_child(_warn, %IdleTip.get_index())


## Last move: the vignette fades in and the MOVES chip pulses until the count changes or the level ends.
func _set_low_moves(on: bool) -> void:
	if _warn == null or on == _warn_on:
		return
	_warn_on = on
	var mat := _warn.material as ShaderMaterial
	mat.set_shader_parameter("rect_size", _warn.size)
	if _warn_fade_tw != null and _warn_fade_tw.is_valid():
		_warn_fade_tw.kill()
	if _warn_pulse_tw != null and _warn_pulse_tw.is_valid():
		_warn_pulse_tw.kill()
	_warn_fade_tw = create_tween()
	if on:
		_warn.visible = true
		_warn_fade_tw.tween_property(mat, "shader_parameter/amount", 1.0, Config.LOW_MOVES_FADE)
		var half := Config.LOW_MOVES_PERIOD * 0.5
		var peak := Vector2.ONE * Config.LOW_MOVES_CHIP_SCALE
		moves_chip.pivot_offset = moves_chip.size * 0.5
		_warn_pulse_tw = create_tween().set_loops()
		_warn_pulse_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_warn_pulse_tw.tween_property(moves_chip, "scale", peak, half)
		_warn_pulse_tw.parallel().tween_property(mat, "shader_parameter/breath", 1.0, half)
		_warn_pulse_tw.tween_property(moves_chip, "scale", Vector2.ONE, half)
		_warn_pulse_tw.parallel().tween_property(mat, "shader_parameter/breath", 0.0, half)
	else:
		_warn_fade_tw.tween_property(mat, "shader_parameter/amount", 0.0, Config.LOW_MOVES_FADE)
		_warn_fade_tw.tween_callback(func() -> void: _warn.visible = _warn_on)
		moves_chip.scale = Vector2.ONE


## Nền huy hiệu booster: tròn xanh trống (còn hàng, code ghi số) hoặc sprite dấu + (hết kho).
func _badge_box(has_stock: bool) -> StyleBoxTexture:
	return ThemeKit.sprite_box("hud_badge_count" if has_stock else "hud_badge_plus")


func _toast(text: String) -> void:
	toast_label.text = text
	toast_label.visible = true
	_toast_token += 1
	var token := _toast_token
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if token == _toast_token and is_instance_valid(toast_label):
			toast_label.visible = false)


## Lời khen (PraiseFx): chữ bật lên giữa hàng trên của HUD và khung, đáy chữ trên mép khung; hào quang nằm sau bàn
## (khung che phần dưới), sao và confetti bay trước bàn; dòng hướng dẫn trên khung mờ đi trong lúc đó.
func _show_clap() -> void:
	Sfx.play("clap")
	var holder := clap_label.get_parent() as Control
	var old := holder.get_node_or_null("PraiseFx")
	if old != null:
		holder.remove_child(old)
		old.free()
	var fx := PraiseFx.new()
	fx.name = "PraiseFx"
	holder.add_child(fx)
	holder.move_child(fx, board_view.get_index())  # halo behind the board: the frame stays on top of it
	var r := praise_rect()
	var s: float = board_view.frame_unit() / Config.BOARD_FRAME_UNIT if board_view.frame_unit() > 0.0 else 1.0
	var dim: Array[CanvasItem] = [tut_label]
	fx.start(clap_label, Vector2(r.get_center().x, r.end.y), r.size.x, r.size.y, s, dim)


## Chỗ của lời khen, toạ độ BoardHolder: từ đáy hàng trên của HUD (MOVES, tên level, nút) tới mép trên khung trừ
## BOARD_CAPTION_GAP, chừa lề hai bên.
func praise_rect() -> Rect2:
	var holder := clap_label.get_parent() as Control
	var inv := holder.get_global_transform().affine_inverse()
	var row := get_node("Margin/Column/TopBar/TopRow") as Control
	var s: float = board_view.frame_unit() / Config.BOARD_FRAME_UNIT if board_view.frame_unit() > 0.0 else 1.0
	var top: float = (inv * row.get_global_rect().end).y + Config.BOARD_CAPTION_GAP * s
	var bottom: float = board_view.position.y + board_view.frame_rect().position.y - Config.BOARD_CAPTION_GAP * s
	var side := 24.0
	return Rect2(side, top, maxf(holder.size.x - 2.0 * side, 1.0), maxf(bottom - top, 1.0))


## Tâm khối trên màn hình (toạ độ toàn cục), lấy trước khi khối rời bàn.
func _block_center(id: String) -> Vector2:
	var n: Control = board_view.block_node(id)
	return n.get_global_rect().get_center() if n != null else board_view.get_global_rect().get_center()


## Mảnh leaderboard: icon khối crystal bật ra ở tâm khối vừa rời bàn rồi bay về chip đếm mảnh (`CrystalFly`); số trên
## chip chỉ tăng lúc icon chạm chip, kèm số nảy. Nơi gọi đã cộng `_pieces_pending` từ lúc Game ghi nhận mảnh.
func _fly_piece(from: Vector2) -> void:
	Sfx.play_or("crystal", "sfx_coin")
	var a := attempt
	var fx := CrystalFly.new()
	fx.name = "FlyingPiece"
	fx.on_launch = Sfx.play_or.bind("crystal_get", "sfx_coin")
	_overlay.add_child(fx)
	fx.start(from, piece_icon, func() -> void:
		if _left or not is_same(attempt, a):
			return
		_pieces_pending = maxi(0, _pieces_pending - 1)
		_refresh_hud()
		_pop_piece_label())


## Số trên chip mảnh nảy to, loé sáng rồi về.
func _pop_piece_label() -> void:
	piece_label.pivot_offset = piece_label.size * 0.5
	piece_label.scale = Vector2(1.5, 1.5)
	piece_label.modulate = Color(1.8, 1.8, 1.8)
	var tw := piece_label.create_tween().set_parallel(true)
	tw.tween_property(piece_label, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(piece_label, "modulate", Color.WHITE, 0.3)


# --- chạm khối ---

func _on_block_tapped(id: String) -> void:
	if state != "playing":
		return
	if _smash_mode:
		_do_smash(id)
		return
	# Lớp phủ đã bóc trên board nhưng khối kề chưa tới thanh: khối vẫn tính là còn phủ (design.md mục 4, Pudding).
	if board_view.cover_held(id):
		board_view.apply_result({"kind": "covered", "id": id})
		return
	# Socola tương tự: board đã tan lớp cuối nhưng thứ làm tan chưa tới thanh, hình vẫn còn socola.
	if board_view.choco_held(id):
		board_view.apply_result({"kind": "choco", "id": id})
		return
	# Bom kẹo đã gỡ khối này trên board nhưng chưa chạm thanh: hình vẫn còn sương hoặc lớp phủ.
	var held: String = board_view.pop_held(id)
	if held != "":
		board_view.apply_result({"kind": held, "id": id})
		return
	var idle_ms := Time.get_ticks_msec() - think_start_ms
	var from := _block_center(id)
	var res: Dictionary = Game.tap(attempt, id)
	var kind := str(res.get("kind", "rejected"))
	if kind == "rejected":
		return
	board_view.apply_result(res)
	if kind == "fog" or kind == "covered" or kind == "choco":
		return  # khối còn trong sương, còn phủ hay hướng về thanh socola chỉ nhún, lắc tại chỗ: không tốn MOVES, không tính là nước đi
	if _special:
		_bomb_touch(id, kind == "exit")
	if bool(res.get("piece", false)):
		_pieces_pending += 1
		_fly_piece(from)
	if (kind == "exit" or kind == "peel") and idle_ms >= int(Config.CONTENT.think_clap_sec) * 1000:
		_show_clap()
	_tutorial_after(kind)
	_reset_think()
	_refresh_hud()
	if board.is_won() or board.is_out_of_moves():
		_resolve()


func _tutorial_after(kind: String) -> void:
	if _level != 1 or _road_trip or _special:
		return
	var taps := int(attempt.taps)
	if kind == "blocked" or kind == "gate_closed":
		_set_tut(tr("tut_blocked"))
	elif taps == 1:
		_set_tut(tr("tut_color_dir"))
	else:
		_set_tut("")
	if not board.is_won() and not board.is_out_of_moves() and taps < 3:
		board_view.highlight(board.hint())


## Đợi hoạt ảnh bàn và mảnh crystal đang bay xong (tối đa vài giây), rồi nghỉ thêm `pause` giây: hết MOVES thì một
## nhịp trước popup cứu, thắng thì Config.CONTENT.win_card_delay_sec cho vụn của khối cuối bắn ra trước khi thẻ hiện.
func _settle(pause: float) -> void:
	var t0 := Time.get_ticks_msec()
	while (board_view.is_animating() or _pieces_pending > 0) and Time.get_ticks_msec() - t0 < 2500:
		if _pieces_pending > 0:
			await get_tree().process_frame
		else:
			await _board_done(2500 - (Time.get_ticks_msec() - t0))
	if pause > 0.0:
		await get_tree().create_timer(pause).timeout


## Đợi bàn báo xong (animation_done), tối đa `ms`. Bàn báo lúc xử lý tween: nhịp nghỉ sau đó tính đúng từ lúc khối
## cuối nghiền xong (đợi process_frame thì trễ thêm một frame).
func _board_done(ms: int) -> void:
	var w := Waiter.new()
	_waiters.append(w)
	board_view.animation_done.connect(w.fire, CONNECT_ONE_SHOT)
	get_tree().create_timer(maxf(float(ms), 1.0) / 1000.0).timeout.connect(w.fire)
	await w.done
	_waiters.erase(w)
	if is_instance_valid(board_view) and board_view.animation_done.is_connected(w.fire):
		board_view.animation_done.disconnect(w.fire)


func _resolve() -> void:
	_set_state("resolving")
	_set_smash_mode(false)
	await _settle(float(Config.CONTENT.win_card_delay_sec) if board.is_won() else 0.25)
	if _left:
		return
	if board.is_won():
		await _win_flow()
	else:
		await _rescue_flow()


## Nạp nền thẻ thắng (Road Trip: popup thắng) từ lúc vào màn: lần nạp đầu kéo theo nhiều atlas, nạp lúc thắng thì
## thẻ hiện trễ. Thắng thì _take_result_card() lấy ra và giữ để các lần thắng sau trong màn này mở ngay từ cache.
func _warm_result_card() -> void:
	var path := POPUP_RT_WIN if _road_trip else WIN_CARD
	if _card_path != "" or (_card_scene != null and _card_scene.resource_path == path):
		return
	if ResourceLoader.load_threaded_request(path) == OK:
		_card_path = path


func _take_result_card() -> void:
	if _card_path == "":
		return
	var res := ResourceLoader.load_threaded_get(_card_path)
	_card_path = ""
	if res is PackedScene:
		_card_scene = res


# --- hết MOVES ---

func _rescue_flow() -> void:
	if _special:
		# Màn đặc biệt: hết bước là thua ngay, không cứu lượt.
		await _special_fail("steps")
		return
	if _road_trip:
		await _revive_flow()
		return
	for i in 12:
		# duplicate: dict của RescueFlow giữ chính nó trong _cur, gắn attempt vào sẽ tạo vòng tham chiếu.
		var o: Dictionary = Game.rescue_offer(attempt).duplicate()
		if bool(o.get("lost", true)):
			break
		o["attempt"] = attempt
		# Lần hết MOVES thứ helper_pack_fail liên tiếp ở level này, lần cứu đầu: popup kèm Helper Pack (4.7).
		var path := HELPER_PACK if i == 0 and Game.helper_pack_due(attempt, o) else POPUP_RESCUE
		var r: Variant = await _popup_scene(path, o)
		if _left:
			return
		var method := str(r) if r is String else ""
		if method == "inventory" or method == "gold" or method == "video":
			board_view.refresh()
			Sfx.play("moves")
			_fly_moves(int(Config.ECON.rescue_moves))
			_refresh_hud()
			_set_state("playing")
			_reset_think()
			return
		if method == "need_coins":
			await _popup_scene(SHOP_MINI, {"source": "rescue"})
			if _left:
				return
			continue
		# Bỏ cứu lượt mà mất mạng hoặc tụt chuỗi Win Streak: hỏi lại (4.6 / 9.5); Chơi tiếp thì về popup cứu lượt.
		var warn := bool(o.get("warn_life", false)) and not bool(Game.lives_view().get("infinite", false))
		var quit: bool = await _confirm_quit("give_up", warn)
		if _left:
			return
		if not quit:
			continue
		Game.rescue_skip(attempt)
		break
	await _lose_flow()


## Road Trip out of moves: watch an ad for +revive_moves (up to revive_max a level) or give up. No life is at stake.
func _revive_flow() -> void:
	while true:
		var v: Dictionary = Game.road_trip_revive_view(attempt)
		if not bool(v.available):
			break
		_set_state("dialog")
		var dlg := Dialog.new(tr("rescue_title"), tr("rt_revive_body") % int(v.moves), [
			{"id": "video", "text": tr("rt_revive_video") % int(v.moves), "kind": "video", "name": "ReviveButton", "close": false},
			{"id": "give_up", "text": tr("rescue_give_up"), "kind": "ghost", "name": "GiveUpButton"}],
			tr("rescue_remaining") % board.remaining_count() if board.remaining_count() != 1 else tr("rescue_remaining_one"))
		_show_node(dlg)
		var picked: Array = [""]
		dlg.chosen.connect(func(id: String) -> void:
			if id != "video" or picked[0] != "":
				return
			picked[0] = "video"
			var ok: bool = await Game.road_trip_revive(attempt)
			if is_instance_valid(dlg):
				if ok:
					dlg.closed.emit("revived")
				else:
					picked[0] = ""
					# Không có video hay mất mạng: Main đã báo bằng popup (Game.notice).
					if not Game.notice_shown(Game.last_ad_reason):
						_toast(tr("ads_failed")))
		var r: Variant = await _wait_closed(dlg)
		if _left:
			return
		if str(r) == "revived":
			board_view.refresh()
			Sfx.play("moves")
			_fly_moves(int(v.moves))
			_refresh_hud()
			_set_state("playing")
			_reset_think()
			return
		break
	await _lose_flow()


func _lose_flow() -> void:
	_set_state("over")
	_offer_id = ""
	Game.on_level_lost(attempt)
	var offer := "rescue_pack" if _offer_id == "rescue_pack" else ""
	var r: Variant = await _popup_scene(LOSE_CARD, {"offer": offer, "life_charged": bool(attempt.get("life_charged", false))})
	if _left:
		return
	# TryShowPendingLostStreakNotify: sau thẻ thua.
	await _notify_streak_lost()
	if _left:
		return
	if str(r) == "retry":
		if _can_play():
			await _start_level()
		else:
			_leave("no_lives")
	else:
		_leave("home")


# --- thắng ---

func _win_flow() -> void:
	_set_state("over")
	_take_result_card()
	if _special:
		bombs.call("stop_all")
	var res: Dictionary = Game.on_level_won(attempt)
	_refresh_hud()
	if _special:
		await _special_win(res)
		return
	if _road_trip:
		await _popup_scene(POPUP_RT_WIN, res)
		if _left:
			return
		# Interstitial result_exit under the same pacing as the main win card.
		await Game.road_trip_leave_win(_level)
		if not _left:
			_leave("home")
		return
	var x2_offered := bool(res.get("x2_available", false))
	var x2_taken := false
	var rate := bool(res.get("rate_prompt", false))
	if bool(res.get("card", true)):
		# Gold MOVES thừa bay từ chip lượt vào ô gold của thẻ; mỗi đồng rời chip thì số lượt giảm.
		var card := res.duplicate()
		card["moves_chip"] = moves_chip
		card["moves_left"] = board.moves_left()
		card["on_move_cashed"] = _cash_moves
		var wr: Variant = await _popup_scene(WIN_CARD, card)
		if _left:
			return
		if wr is Dictionary:
			x2_offered = bool(wr.get("x2_offered", x2_offered))
			x2_taken = bool(wr.get("x2_taken", false))
			rate = bool(wr.get("rate_prompt", rate))
	else:
		# Below Config.ECON.win_card_from_level: no win card, the gold is already in the wallet; straight to the next
		# level (Game.next_after_win never sends these wins Home).
		Sfx.play("sfx_win")
	# Vừa lên league: popup nhận thưởng. Thưởng league đầu (lúc mới mở khoá) chờ tới khi mở màn Leaderboard.
	var lb: Dictionary = res.get("lb", {})
	var promo := Game.lb_pending_view()
	if not (lb.get("promoted", []) as Array).is_empty() and not promo.is_empty():
		await _popup_scene(POPUP_LB_RESULT, {"view": promo})
		if _left:
			return
	_offer_id = ""
	await Game.leave_win_card(x2_offered, x2_taken)
	if _left:
		return
	if _offer_id != "":
		# Offer Remove Ads mở popup 2.4 (hai gói bỏ quảng cáo); offer khác dùng popup_offer.
		if _offer_id == "remove_ads":
			await _popup_scene(POPUP_REMOVE_ADS)
		else:
			await _popup_scene(POPUP_OFFER, {"id": _offer_id})
		if _left:
			return
	if rate:
		# Rate us (wireframe 4.3): hỏi trước, Có thì mở popup đánh giá của store.
		var rr: Variant = await _popup_scene(POPUP_RATE)
		if _left:
			return
		if rr is Dictionary and str(rr.get("action", "")) == "rate":
			Game.rate_now()
	# Thắng Hard / VeryHard được vé Màn đặc biệt: mời ngay (về Home thì Home mời, Game.special_take_invite).
	if not _challenge and int(res.get("special_tickets", 0)) > 0:
		if Game.next_after_win(res, false) == "home":
			Game.special_queue_invite()
		elif int(Game.special_view().tickets) > 0:
			var ir: Variant = await _popup_scene(POPUP_SPECIAL)
			if _left:
				return
			if ir is Dictionary and str(ir.get("action", "")) == "start":
				await _enter_special()
				return
	if _challenge:
		_leave("home")
	elif Game.next_after_win(res, false) == "home":
		_leave("home")
	elif not Game.level_exists(int(Game.s.level)):
		var dlg := Dialog.new(tr("level_title") % int(Game.s.level), tr("level_demo_end"),
			[{"id": "ok", "text": tr("common_ok"), "kind": "primary", "name": "OkButton"}])
		await _ask(dlg)
		_leave("home")
	elif not _can_play():
		_leave("no_lives")
	else:
		await _start_level()


# --- Home và restart ---

func _confirm_life_loss() -> bool:
	return not _road_trip and not _special and _level >= int(Config.LIVES.from_level) and _touched() \
		and not bool(Game.lives_view().get("infinite", false))


func _on_home_pressed() -> void:
	if state != "playing":
		return
	if _special:
		_on_leave_special()
		return
	Sfx.play("button")
	_set_state("dialog")
	var life := _confirm_life_loss()
	var quit: bool = await _confirm_quit("home", life)
	if _left:
		return
	if not quit:
		_set_state("playing")
		_reset_think()
		return
	if life:
		Game.restart_cost_life(attempt)
	Game.leave_attempt(attempt)
	await _notify_streak_lost()
	if _left:
		return
	_leave("home")


## Bánh răng: popup cài đặt trong màn (wireframe 3.5). Home và Retry đi tiếp qua luồng xác nhận mất mạng.
func _on_settings_pressed() -> void:
	if state != "playing":
		return
	Sfx.play("button")
	_set_state("dialog")
	var r: Variant = await _popup_scene(INGAME_SETTINGS, {"life_cost": _confirm_life_loss(), "no_retry": _special})
	if _left:
		return
	_set_state("playing")
	_reset_think()
	match str(r):
		"home":
			_on_home_pressed()
		"retry":
			_on_restart_pressed()


func _on_restart_pressed() -> void:
	if state != "playing":
		return
	if _special:
		# Màn đặc biệt không có chơi lại: nút này là Rời màn.
		_on_leave_special()
		return
	Sfx.play("button")
	_set_state("dialog")
	var life := _confirm_life_loss()
	if life or Game.streak_at_stake(attempt):
		# Mất mạng hoặc tụt chuỗi: popup 4.6 / 9.5.
		var quit: bool = await _confirm_quit("restart", life)
		if _left:
			return
		if not quit:
			_set_state("playing")
			_reset_think()
			return
	elif not _road_trip and _level >= int(Config.LIVES.from_level):
		var dlg := Dialog.new(tr("level_restart_confirm_title"), tr("level_restart_confirm_free"), [
			{"id": "yes", "text": tr("level_restart_yes"), "kind": "danger", "name": "ConfirmButton"},
			{"id": "no", "text": tr("level_restart_no"), "kind": "ghost", "name": "CancelButton"}])
		var r: Variant = await _ask(dlg)
		if _left:
			return
		if str(r) != "yes":
			_set_state("playing")
			_reset_think()
			return
	var charged := Game.restart_cost_life(attempt)
	await _notify_streak_lost()
	if _left:
		return
	if charged and not _can_play():
		_leave("no_lives")
		return
	await _start_level(false)


# --- booster ---

func _on_booster_pressed(kind: String) -> void:
	if state != "playing":
		return
	Sfx.play("button")
	if not Unlocks.is_open(kind, _unlock_ref()):
		# A locked booster only clicks: no popup 3.7 (design.md mục 4 "Mở khoá theo level", 2026-11-12).
		return
	if kind == "hint" and is_instance_valid(_hint_fx):
		return
	if _smash_mode:
		_set_smash_mode(false)
		if kind == "smash":
			return
	if int(Game.s.inv.get(kind, 0)) > 0:
		_use_booster(kind)
	else:
		_booster_dialog(kind)


func _use_booster(kind: String) -> void:
	match kind:
		"hint":
			var id := _hint_target()
			if id == "":
				_toast(tr("level_hint_none"))
				return
			if Game.use_booster("hint"):
				_fly_hint(id)
		"move":
			if Game.use_booster("move"):
				board.add_moves(int(Config.ECON.rescue_moves))
				board_view.refresh()
				Sfx.play("moves")
				_fly_moves(int(Config.ECON.rescue_moves))
		"smash":
			_set_smash_mode(true)
	_refresh_hud()
	_reset_think()


## Sao bay từ nút Gợi ý tới khối, chạm thì khối mới sáng lên và sao lấp lánh phủ khắp khối. Người chơi đã đi nước
## khác hoặc khối đã rời bàn trong lúc sao bay thì nháy gợi ý mới (không nảy, vẫn lấp lánh), để booster không mất.
func _fly_hint(id: String) -> void:
	var taps := int(attempt.taps)
	_hint_fx = HintFx.new()
	_hint_fx.name = "HintFx"
	_overlay.add_child(_hint_fx)
	_hint_fx.start(booster_buttons.hint.get_global_rect().get_center(), _block_center(id), board_view.cell_size(),
		func() -> void:
			if state != "playing":
				return
			var same := int(attempt.taps) == taps and board_view.block_node(id) != null
			var hid := id if same else _hint_target()
			if hid != "":
				board_view.highlight(hid, same, true))


## Khối Gợi ý chỉ: Màn đặc biệt ưu tiên khối thoát được trong chuỗi chặn của quả bom gấp nhất (SpecialBoard.urgent_hint),
## không có thì như level thường (board.hint()).
func _hint_target() -> String:
	if _special:
		var id := SpecialBoard.urgent_hint(board, bombs.call("live_ids"))
		if id != "":
			return id
	return board.hint()


## Dấu "+" bay từ nút +Move tới chip lượt; mỗi dấu chạm thì số lượt hiện tăng thêm phần của nó (bàn đã cộng sẵn).
## Lượt mới bắt đầu trong lúc bay thì bỏ qua các dấu còn lại.
func _fly_moves(n: int) -> void:
	var a := attempt
	_moves_pending += n
	var fx := MoveFx.new()
	fx.name = "MoveFx"
	_overlay.add_child(fx)
	fx.start(booster_buttons.move, moves_chip, n, func(share: int) -> void:
		if not is_same(attempt, a):
			return
		_moves_pending = maxi(0, _moves_pending - share)
		Sfx.play("sfx_coin")
		_refresh_hud())


## Thẻ thắng đổi `n` lượt thừa ra gold: số lượt hiện giảm (bàn giữ nguyên) và chip nảy nhẹ.
func _cash_moves(n: int) -> void:
	if _left or not is_inside_tree():
		return
	_moves_cashed += n
	_refresh_hud()
	if _chip_tw != null and _chip_tw.is_valid():
		_chip_tw.kill()
	moves_chip.pivot_offset = moves_chip.size * 0.5
	moves_chip.scale = Vector2(1.12, 1.12)
	_chip_tw = moves_chip.create_tween()
	_chip_tw.tween_property(moves_chip, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Tutorial and smash captions: a bubble (the label's `normal` style) centred on the frame, bottom edge
## Config.BOARD_CAPTION_GAP above the frame's top bar, growing upward and sideways (grow_* in the scene), so a wrapped
## line never covers the frame. The frame is centred in BoardHolder, so its top edge moves with the screen height.
func _place_captions() -> void:
	if board_view.board_rect().size == Vector2.ZERO:
		return
	var s: float = board_view.frame_unit() / Config.BOARD_FRAME_UNIT
	var frame: Rect2 = board_view.frame_rect()
	var bottom: float = board_view.position.y + frame.position.y - Config.BOARD_CAPTION_GAP * s
	var mid: float = board_view.position.x + frame.get_center().x
	_caption_max_w = frame.size.x
	for l: Label in [tut_label, smash_label]:
		l.offset_left = mid
		l.offset_right = mid
		l.offset_top = bottom
		l.offset_bottom = bottom
		_fit_caption(l)


## The bubble hugs a single line; text wider than the frame wraps inside a frame-wide bubble.
func _fit_caption(l: Label) -> void:
	var max_w: float = _caption_max_w if _caption_max_w > 0.0 else (l.get_parent() as Control).size.x
	var pad: float = l.get_theme_stylebox("normal").get_minimum_size().x
	var font: Font = l.get_theme_font("font")
	var w: float = font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
	var wrap := w + pad > max_w
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.custom_minimum_size.x = max_w if wrap else 0.0


func _set_tut(text: String) -> void:
	tut_label.text = text
	_fit_caption(tut_label)
	_show_captions()


## Both captions share one spot above the frame: the smash prompt replaces the tutorial line, and an empty line hides
## its bubble.
func _show_captions() -> void:
	smash_label.visible = _smash_mode
	tut_label.visible = not _smash_mode and tut_label.text != ""


func _set_smash_mode(on: bool) -> void:
	_smash_mode = on
	if smash_label != null:
		_show_captions()


## Bàn và kho cập nhật ngay; búa kẹo mút hiện giữa màn rồi bay tới gõ, khối chỉ vỡ (và mảnh mới bay) lúc búa chạm.
## Trong lúc búa bay, bàn và các nút không nhận chạm (state "smashing").
func _do_smash(id: String) -> void:
	_set_smash_mode(false)
	if not Game.use_booster("smash"):
		return
	var from := _block_center(id)
	var target: Vector2 = board_view.strike_point(id)
	var r: Dictionary = Game.smash_block(attempt, id)
	if bool(r.get("piece", false)):
		_pieces_pending += 1  # số trên chip đợi icon crystal bay tới (sau cú gõ)
	if _special and bool(r.get("ok", false)):
		_bomb_touch(id, true)
	_reset_think()
	_refresh_hud()
	if not bool(r.ok):
		if board.is_won():
			_resolve()
		return
	var a := attempt
	_set_state("smashing")
	var fx := SmashFx.new()
	fx.name = "SmashFx"
	_overlay.add_child(fx)
	fx.start(target, board_view.cell_size(), func() -> void:
		if _left or not is_same(attempt, a):
			return
		board_view.smash_anim(id, r.get("popped", []))
		if bool(r.piece):
			_fly_piece(from)
		if state == "smashing":
			_set_state("playing")
		_reset_think()
		if board.is_won():
			_resolve())


## Booster hết kho: mua bằng gold, hoặc video miễn phí (không giới hạn số lần) khi thiếu gold.
func _booster_dialog(kind: String) -> void:
	_set_state("dialog")
	var message := ""
	var got := false
	var from := Rect2()
	for i in 8:
		var price := int(Config.ECON.booster_price.get(kind, 0))
		var can_afford := int(Game.s.coins) >= price
		var items: Array = [{"id": "buy", "gold": price, "kind": "gold", "dim": not can_afford, "name": "BuyButton"}]
		var free_ok := not can_afford and bool(Game.lives_view().get("video_ready", false))
		if free_ok:
			items.append({"id": "video", "text": tr("booster_free_video"), "kind": "video", "name": "VideoButton"})
			Game.offer_video(FREE_PLACEMENT)
		items.append({"id": "close", "text": tr("common_close"), "kind": "ghost", "name": "CloseButton"})
		var dlg := Dialog.new(tr("booster_" + kind), tr("booster_%s_desc" % kind), items, message, ThemeKit.icon("booster_" + kind))
		message = ""
		var r: Variant = await _ask(dlg)
		if _left:
			return
		# Where the booster's picture was: a bought booster flies from there (the dialog is gone after a video).
		var art := dlg.find_child("Art", true, false) as Control
		if art != null:
			from = art.get_global_rect()
		var choice := str(r) if r is String else ""
		if choice == "buy":
			if Game.buy_booster(kind):
				got = true
				break
			await _popup_scene(SHOP_MINI, {"source": "booster"})
			if _left:
				return
		elif choice == "video":
			if await Game.booster_video(kind):
				got = true
				break
			match Game.last_ad_reason:
				"not_ready", "offline":
					message = ""  # Main đã báo bằng popup (Game.notice)
				"closed":
					message = tr("ads_closed_early")
				_:
					message = tr("ads_failed")
		else:
			break
	if got:
		# Unity's PopUpBuyMore: the booster flies into its button (badge counts on), then it is used.
		var fx := RewardFly.fly(null, {"items": {kind: 1}}, {kind: from})
		if not fx.is_empty():
			await Signal(fx[0], "arrived")
			if _left:
				return
	_set_state("playing")
	_reset_think()
	if got:
		_use_booster(kind)


# --- nhắc Gợi ý khi treo máy ---

## Đang chơi mà không chạm màn hình Config.CONTENT.idle_hint_sec giây thì nhắc Gợi ý. Không đếm khi chưa mở Gợi ý,
## đang chọn khối để phá, sao Gợi ý đang bay hay có popup; không khối nào thoát được thì bỏ lượt nhắc đó.
func _process(delta: float) -> void:
	if not _built or board == null:
		return
	if _special:
		_tick_bombs(delta)
	var now := Time.get_ticks_msec()
	if _nudging or state != "playing" or _smash_mode or is_instance_valid(_hint_fx) \
			or not Unlocks.is_open("hint", _unlock_ref() if _special else _level):
		idle_start_ms = now
		return
	if now - idle_start_ms < int(float(Config.CONTENT.idle_hint_sec) * 1000.0):
		return
	idle_start_ms = now
	var n := _exit_count()
	if n > 0:
		_start_nudge(n)


## Chạm bất kỳ đâu: tính lại thời gian treo và tắt lời nhắc ngay. Chạm không bị nuốt, vẫn tới bàn và nút.
func _input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.is_pressed():
		idle_start_ms = Time.get_ticks_msec()
		if _nudging:
			_end_nudge()


func _notification(what: int) -> void:
	# Thời gian app nằm nền không tính là treo, và bom không đếm (khung đầu sau khi quay lại cũng bỏ).
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		idle_start_ms = Time.get_ticks_msec()
		_app_paused = false
		_skip_tick = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_app_paused = true


## Số khối thoát được ngay (Gợi ý chọn trong số này trước, cú dội cổng nhịp không tính), ghi trên bong bóng nhắc.
func _exit_count() -> int:
	var n := 0
	for id in board.block_ids():
		if board.can_exit(id):
			n += 1
	return n


## Nút Gợi ý lắc, bóng đèn trắng đổi sang bóng đèn vàng booster_hint, rồi bong bóng hiện trên nút.
func _start_nudge(n: int) -> void:
	_nudging = true
	_nudge_token += 1
	var token := _nudge_token
	var b: Button = booster_buttons.hint
	_idle_bulb.visible = true
	b.pivot_offset = b.size * 0.5
	var tw := b.create_tween()
	for deg in [-12.0, 10.0, -8.0, 6.0, -3.0, 0.0]:
		tw.tween_property(b, "rotation_degrees", deg, 0.06)
	tw.tween_callback(_show_idle_tip.bind(n, token))
	_nudge_tweens.append(tw)


## Bong bóng "Available Block : N" bật ra, đuôi chỉ xuống nút Gợi ý; tự tắt sau Config.CONTENT.idle_hint_show_sec giây.
func _show_idle_tip(n: int, token: int) -> void:
	if token != _nudge_token:
		return
	_idle_count.text = str(n)
	var r := (booster_buttons.hint as Button).get_global_rect()
	var tip := r.position + r.size * Vector2(0.6, 0.1)
	idle_tip.position = (idle_tip.get_parent() as Control).get_global_transform().affine_inverse() * tip
	idle_tip.scale = Vector2(0.4, 0.4)
	idle_tip.modulate.a = 0.0
	idle_tip.visible = true
	var tw := idle_tip.create_tween()
	tw.tween_property(idle_tip, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(idle_tip, "modulate:a", 1.0, 0.1)
	tw.tween_interval(float(Config.CONTENT.idle_hint_show_sec))
	tw.tween_property(idle_tip, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func() -> void:
		if token == _nudge_token:
			_end_nudge())
	_nudge_tweens.append(tw)


func _end_nudge() -> void:
	_nudging = false
	_nudge_token += 1
	idle_start_ms = Time.get_ticks_msec()
	for tw in _nudge_tweens:
		if tw.is_valid():
			tw.kill()
	_nudge_tweens.clear()
	(booster_buttons.hint as Button).rotation = 0.0
	_idle_bulb.visible = false
	idle_tip.visible = false
	idle_tip.scale = Vector2.ONE
	idle_tip.modulate.a = 1.0


# --- Màn đặc biệt (design.md mục 7 "Màn đặc biệt") ---

## Lần chạm hợp lệ (cả chạm khối bị chặn, cả búa): bom bắt đầu đếm từ lần đầu. Khối mang bom rời bàn (`out`: thoát
## hoặc bị búa) thì quả đó tắt hẳn; bom của khối khác vẫn đếm.
func _bomb_touch(id: String, out: bool) -> void:
	if not bool(bombs.get("started")):
		bombs.call("start")
	if out and bool(bombs.call("is_live", id)):
		bombs.call("defuse", id)


## Bom chỉ đếm khi người chơi chạm được vào bàn: đang chơi (không popup của màn, không búa bay), không sao Gợi ý đang
## bay, không popup nào của Main đang mở, app không ở nền. Khung đầu sau khi app quay lại bị bỏ.
func _bomb_can_tick() -> bool:
	if state != "playing" or _app_paused or is_instance_valid(_hint_fx):
		return false
	var h := _host()
	return h == null or not h.has_method("popup_count") or int(h.call("popup_count")) == 0


func _tick_bombs(delta: float) -> void:
	if bombs == null or not bool(bombs.get("started")):
		return
	if not _bomb_can_tick():
		return
	if _skip_tick:
		_skip_tick = false
		return
	var hit: String = bombs.call("tick", minf(delta, BOMB_MAX_STEP))
	if hit != "":
		_bomb_exploded(hit)


## Bom về 0: thua ngay (Game ghi lại trước), chặn chạm, nổ, khoảng boom_popup_sec giây sau hiện popup "Bùm!".
func _bomb_exploded(id: String) -> void:
	_set_state("over")
	_set_smash_mode(false)
	var live: int = bombs.call("live_count")
	Game.special_lost(attempt, "bomb", live)
	bombs.call("explode", id, _overlay, board_view)
	await get_tree().create_timer(float(Config.SPECIAL.boom_popup_sec)).timeout
	if _left:
		return
	await _special_end_popup("boom")


## Hết bước (Màn đặc biệt không cứu lượt): thua, popup "Thử thách thất bại".
func _special_fail(reason: String) -> void:
	_set_state("over")
	var live: int = bombs.call("live_count")
	bombs.call("stop_all")
	Game.special_lost(attempt, reason, live)
	await _special_end_popup("fail")


## Popup thua: "Level N" vào level chính kế (đổi tại chỗ), X về Home. Không interstitial.
func _special_end_popup(mode: String) -> void:
	var r: Variant = await _popup_scene(POPUP_SPECIAL_END, {"mode": mode, "level": int(Game.s.level)})
	if _left:
		return
	if r is Dictionary and str(r.get("action", "")) == "level":
		await _continue_main()
	else:
		_leave("home")


## Thắng: thẻ thắng như level thường (win_card, ô thưởng là booster đã vào kho; x2 bằng quảng cáo), interstitial
## result_exit theo nhịp thẻ thắng, rồi về Home (nút của thẻ là Trang chủ).
func _special_win(res: Dictionary) -> void:
	var wr: Variant = await _popup_scene(WIN_CARD, res)
	if _left:
		return
	var x2 := wr is Dictionary and bool(wr.get("x2_taken", false))
	await Game.special_leave_win(x2)
	if _left:
		return
	_leave("home")


## Rời Màn đặc biệt sang level chính kế ngay trong màn này (không màn chuyển cảnh), hoặc về Home khi hết level, sang
## màn hết mạng khi hết mạng.
func _continue_main() -> void:
	_special = false
	bombs.call("clear")
	if not Game.level_exists(int(Game.s.level)):
		_leave("home")
		return
	if not _can_play():
		_leave("no_lives")
		return
	_warm_result_card()
	await _start_level()


## Vào Màn đặc biệt từ popup mời sau thẻ thắng: màn mưa bom phủ kín, dựng bàn Special bên dưới rồi mở ra.
func _enter_special() -> void:
	var start := func() -> void:
		_special = true
		_start_level()
	var h := _host()
	if h != null and h.has_method("curtain_swap"):
		await h.curtain_swap(start, BombCurtain)
	else:
		start.call()


## Rời màn (nút Rời màn, Home trong cài đặt, Back): hỏi trước; đồng ý thì thua (vé đã dùng) và về Home, không
## interstitial.
func _on_leave_special() -> void:
	if state != "playing":
		return
	Sfx.play("button")
	_set_state("dialog")
	var dlg := Dialog.new(tr("special_leave_title"), tr("special_leave_body"), [
		{"id": "leave", "text": tr("special_leave_yes"), "kind": "danger", "name": "LeaveButton"},
		{"id": "stay", "text": tr("special_leave_no"), "kind": "ghost", "name": "StayButton"}])
	var r: Variant = await _ask(dlg)
	if _left:
		return
	if str(r) != "leave":
		_set_state("playing")
		_reset_think()
		return
	_set_state("over")
	var live: int = bombs.call("live_count")
	bombs.call("stop_all")
	Game.special_lost(attempt, "quit", live)
	_leave("home")
