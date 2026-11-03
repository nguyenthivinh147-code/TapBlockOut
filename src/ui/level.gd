extends Control
## Màn level: HUD, bàn cờ, booster, luồng hết MOVES, thắng, thua, restart.
## setup({challenge: true}) chạy Daily Challenge (Game.start_challenge) thay vì level kế tiếp; thắng thì về Home.
## closed({"action": "home" | "no_lives"}). Popup mở qua Main.open_popup (hoặc lớp riêng khi chạy lẻ).
## HUD theo wireframe 3.4: lượt, tên level, restart, bánh răng (Home và Retry nằm trong popup cài đặt); chip mảnh dưới chip lượt.
## Hàng booster luôn đủ 3 ô; ô chưa mở tối đi, có ổ khoá và ghi level mở.
## UI chỉ gọi Game và Sfx; hoạt ảnh bàn do BoardView lo.

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const UiAtlas := preload("res://src/ui/ui_atlas.gd")
const Config := preload("res://src/config.gd")
const Unlocks := preload("res://src/meta/unlocks.gd")
const BoardState := preload("res://src/core/board_state.gd")
const BoardViewScene := preload("res://scenes/board_view.tscn")
const HintFx := preload("res://src/ui/hint_fx.gd")
const MoveFx := preload("res://src/ui/move_fx.gd")
const SmashFx := preload("res://src/ui/smash_fx.gd")

const POPUP_RESCUE := "res://scenes/popup_rescue.tscn"
const POPUP_OFFER := "res://scenes/popup_offer.tscn"
const WIN_CARD := "res://scenes/win_card.tscn"
const LOSE_CARD := "res://scenes/lose_card.tscn"
const SHOP_MINI := "res://scenes/shop_mini.tscn"
const INGAME_SETTINGS := "res://scenes/popup_ingame_settings.tscn"
const POPUP_LB_RESULT := "res://scenes/popup_lb_result.tscn"
const BOOSTERS := ["hint", "move", "smash"]
const FREE_PLACEMENT := "booster_free"
const MECHS := ["stone", "ice", "chain", "layer", "fog", "pulse"]
## Ô booster chưa mở: tô tối nền và icon (ổ khoá, nhãn là node con nên giữ màu).
const LOCKED_TINT := Color(0.55, 0.55, 0.62)


## Hộp thoại nhỏ dựng bằng code theo PopupOkLayer (color-cube-match-puzzle). items: [{id, text, kind, name, close}].
## Bấm nút phát chosen(id), rồi closed(id) nếu close (mặc định true). Back của Android phát closed(null).
## Mục id "close" là nút X (và chạm nền mờ) như PopupOkUICoreLayer.closeButtons; các mục khác nằm ở hàng nút,
## mục "ghost" bên trái như Cancel của prefab. art: ảnh bên trái chữ, đặt như HeartIcon của PopupKeepPlaying.
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


## Trạng thái: intro (chưa chơi) | playing | dialog | resolving | over | left.
var state: String = "intro"
var attempt: Dictionary = {}
var board: BoardState = null
var board_view: Control = null
var title_label: Label = null
var hard_badge: Control = null
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
## id booster -> nút, nhãn góc (số còn lại hoặc "+"), ổ khoá (hiện khi chưa mở), chữ dưới nút (tên hoặc level mở)
var booster_buttons: Dictionary = {}
var booster_badges: Dictionary = {}
var booster_locks: Dictionary = {}
var booster_caps: Dictionary = {}
## Mốc bắt đầu "đang nghĩ" (ms); test lùi mốc này để thử tiếng vỗ tay.
var think_start_ms: int = 0

var _built: bool = false
var _challenge: bool = false
var _level: int = 0
var _smash_mode: bool = false
var _offer_id: String = ""
var _overlay: Control = null
var _hint_fx: Control = null  # sao Gợi ý đang bay; còn bay thì bấm Gợi ý không làm gì
var _moves_pending: int = 0  # lượt +Move đã cộng vào bàn nhưng dấu "+" chưa bay tới chip lượt
var _toast_token: int = 0
var _left: bool = false
var _waiters: Array = []


func setup(args: Dictionary) -> void:
	_challenge = bool(args.get("challenge", false))
	_build()
	_start_level()


func _exit_tree() -> void:
	# Màn bị gỡ giữa chừng: cho các luồng đang đợi popup kết thúc, không treo.
	_left = true
	for w in _waiters.duplicate():
		(w as Waiter).done.emit(null)
	_waiters.clear()
	for sig in [Game.inv_changed, Game.coins_changed]:
		if (sig as Signal).is_connected(_on_game_changed):
			(sig as Signal).disconnect(_on_game_changed)
	if Game.offer_ready.is_connected(_on_offer_ready):
		Game.offer_ready.disconnect(_on_offer_ready)


func _icon_button(icon_name: String, node_name: String) -> Button:
	var b := ThemeKit.make_sprite_button(icon_name, Vector2(88, 88))
	b.name = node_name
	return b


## Chữ trắng viền tím trên sprite HUD.
func _hud_label(text: String, font_size: int) -> Label:
	var l := ThemeKit.make_label(text, font_size)
	l.add_theme_color_override("font_outline_color", ThemeKit.HUD_OUTLINE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build() -> void:
	if _built:
		return
	_built = true
	theme = ThemeKit.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ThemeKit.make_image_background(ThemeKit.LEVEL_BG_IMAGE, ThemeKit.LEVEL_BG_DIM, ThemeKit.LEVEL_BG, ThemeKit.LEVEL_BG_IMAGE_ALPHA)
	bg.name = "Background"
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	# thanh trên: lượt, tên level + độ khó, restart, cài đặt; hàng dưới là chip đếm mảnh.
	# Chỉ thanh này và hàng booster chiếm chiều cao, để cỡ ô không đổi giữa các level.
	var head := VBoxContainer.new()
	head.name = "TopBar"
	head.add_theme_constant_override("separation", 6)
	col.add_child(head)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	head.add_child(top)
	# khung MOVES (sprite hud_moves_panel): chữ MOVES nhỏ ở trên, số lượt to ở dưới.
	# Dòng chữ Baloo cao hơn mặt chữ nhiều nên hai nhãn xếp chồng với giãn âm, giữ khung thấp như nút tròn.
	moves_chip = PanelContainer.new()
	moves_chip.name = "MovesChip"
	moves_chip.add_theme_stylebox_override("panel", ThemeKit.sprite_box("hud_moves_panel",
		Vector4(44, 44, 44, 48), Vector4(10, 2, 10, 10)))
	moves_chip.custom_minimum_size = Vector2(150, 104)
	moves_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(moves_chip)
	var moves_col := VBoxContainer.new()
	moves_col.alignment = BoxContainer.ALIGNMENT_CENTER
	moves_col.add_theme_constant_override("separation", -22)
	moves_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	moves_chip.add_child(moves_col)
	var moves_cap := _hud_label(tr("level_moves").to_upper(), ThemeKit.FS_SMALL - 2)
	moves_cap.name = "MovesCaption"
	moves_col.add_child(moves_cap)
	moves_label = _hud_label("", ThemeKit.FS_TITLE)
	moves_label.name = "MovesLabel"
	moves_col.add_child(moves_label)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(mid)
	title_label = ThemeKit.make_label("", ThemeKit.FS_BUTTON + 4)
	title_label.name = "TitleLabel"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(title_label)
	var hard := _hud_label(tr("level_hard"), ThemeKit.FS_SMALL)
	hard.name = "HardBadge"
	hard.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# pill hud_pill cao 44: lề cắt dọc 20 + 22 nên nhãn không được thấp hơn 44
	hard.add_theme_stylebox_override("normal", ThemeKit.sprite_box("hud_pill", Vector4(22, 20, 22, 22), Vector4(22, 0, 22, 4)))
	hard.custom_minimum_size = Vector2(96, 44)
	hard.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hard.visible = false
	hard_badge = hard
	mid.add_child(hard)
	restart_button = _icon_button("hud_btn_restart", "RestartButton")
	restart_button.pressed.connect(_on_restart_pressed)
	top.add_child(restart_button)
	settings_button = _icon_button("hud_btn_settings", "SettingsButton")
	settings_button.pressed.connect(_on_settings_pressed)
	top.add_child(settings_button)
	# chip đếm mảnh leaderboard: hàng riêng dưới chip lượt (hàng trên không còn chỗ ngang khi tên level dài)
	var piece_row := HBoxContainer.new()
	piece_row.name = "PieceRow"
	piece_row.custom_minimum_size.y = 48  # giữ chỗ cả khi level không có khối đặc biệt
	head.add_child(piece_row)
	piece_chip = ThemeKit.make_panel()
	piece_chip.name = "PieceChip"
	piece_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ps := piece_chip.get_theme_stylebox("panel").duplicate() as StyleBox
	ps.content_margin_left = 16
	ps.content_margin_right = 22
	ps.content_margin_top = 4
	ps.content_margin_bottom = 4
	piece_chip.add_theme_stylebox_override("panel", ps)
	piece_chip.visible = false
	piece_row.add_child(piece_chip)
	var piece_box := HBoxContainer.new()
	piece_box.add_theme_constant_override("separation", 6)
	piece_chip.add_child(piece_box)
	piece_icon = ThemeKit.make_icon("lb_piece", 40)
	piece_box.add_child(piece_icon)
	piece_label = ThemeKit.make_label("", ThemeKit.FS_SMALL + 4, ThemeKit.GOLD)
	piece_label.name = "PieceLabel"
	piece_box.add_child(piece_label)

	# bàn cờ
	var holder := Control.new()
	holder.name = "BoardHolder"
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(holder)
	board_view = BoardViewScene.instantiate() as Control
	board_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_view.block_tapped.connect(_on_block_tapped)
	holder.add_child(board_view)
	clap_label = ThemeKit.make_label(tr("level_clap"), ThemeKit.FS_HUGE, ThemeKit.GOLD)
	clap_label.name = "ClapLabel"
	clap_label.set_anchors_preset(Control.PRESET_CENTER)
	clap_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	clap_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	clap_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clap_label.visible = false
	holder.add_child(clap_label)
	toast_label = ThemeKit.make_label("", ThemeKit.FS_BODY, ThemeKit.TEXT)
	toast_label.name = "ToastLabel"
	toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.visible = false
	holder.add_child(toast_label)
	tut_label = _board_overlay_label("TutLabel", ThemeKit.TEXT_DIM)
	holder.add_child(tut_label)
	smash_label = _board_overlay_label("SmashLabel", ThemeKit.GOLD)
	smash_label.text = tr("booster_smash_pick")
	smash_label.visible = false
	holder.add_child(smash_label)

	# booster: luôn đủ 3 ô, ô chưa mở hiện khoá
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	row.custom_minimum_size.y = 168  # giữ chỗ, để khung không xê dịch giữa các level
	col.add_child(row)
	for kind in BOOSTERS:
		var c := VBoxContainer.new()
		c.name = "Booster_" + kind
		c.add_theme_constant_override("separation", 4)
		var b := ThemeKit.make_sprite_button("hud_booster_" + kind, Vector2(144, 129))
		b.name = "BoosterButton_" + kind
		b.pressed.connect(_on_booster_pressed.bind(kind))
		c.add_child(b)
		# huy hiệu góc dưới phải: tròn xanh ghi số còn lại, hết kho thì đổi sang sprite dấu + (xem _refresh_hud)
		var badge := _hud_label("", ThemeKit.FS_SMALL)
		badge.name = "BoosterBadge_" + kind
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_stylebox_override("normal", ThemeKit.sprite_box("hud_badge_count"))
		badge.custom_minimum_size = Vector2(52, 52)
		b.add_child(badge)
		badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
		badge.offset_left = -42
		badge.offset_top = -44
		badge.offset_right = 10
		badge.offset_bottom = 8
		var lock := ThemeKit.make_icon("ui_lock", 64)
		lock.name = "BoosterLock_" + kind
		b.add_child(lock)
		lock.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		lock.offset_left = -58
		lock.offset_top = -58
		lock.offset_right = 6
		lock.offset_bottom = 6
		var cap := ThemeKit.make_label(tr("booster_" + kind), ThemeKit.FS_SMALL, ThemeKit.TEXT)
		cap.name = "BoosterCaption_" + kind
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(cap)
		row.add_child(c)
		booster_buttons[kind] = b
		booster_badges[kind] = badge
		booster_locks[kind] = lock
		booster_caps[kind] = cap

	_overlay = Control.new()
	_overlay.name = "LocalPopups"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	Game.inv_changed.connect(_on_game_changed)
	Game.coins_changed.connect(_on_game_changed)
	Game.offer_ready.connect(_on_offer_ready)


## Chữ phủ lên phần trên của bàn: không chiếm chiều cao nên không làm đổi cỡ ô khi hiện hay ẩn.
func _board_overlay_label(label_name: String, color: Color) -> Label:
	var l := ThemeKit.make_label("", ThemeKit.FS_BODY, color)
	l.name = label_name
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	l.offset_left = 48
	l.offset_right = -48
	l.offset_top = 52
	return l


func _on_game_changed(_v: Variant = null) -> void:
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


func _reset_think() -> void:
	think_start_ms = Time.get_ticks_msec()


func _leave(action: String) -> void:
	if _left:
		return
	_left = true
	_set_state("left")
	closed.emit({"action": action})


func _can_play() -> bool:
	return bool(Game.lives_view().get("can_play", true))


## Back của Android khi không có popup: như bấm Home.
func on_back() -> void:
	_on_home_pressed()


# --- bắt đầu level ---

func _start_level(warn: bool = true) -> void:
	_set_state("intro")
	_set_smash_mode(false)
	_moves_pending = 0
	# Daily Challenge sinh trong game: màn chờ ngắn, vẽ xong mới sinh.
	if _challenge and Game.challenge_needs_generation():
		tut_label.text = tr("common_loading")
		await get_tree().process_frame
		await get_tree().process_frame
		if _left:
			return
	attempt = Game.start_challenge() if _challenge else Game.start_attempt()
	if attempt.is_empty():
		_leave("home")
		return
	board = attempt.board
	_level = int(attempt.level)
	title_label.text = tr("challenge_title") if _challenge else tr("level_title") % _level
	var is_hard := bool(attempt.get("hard", false))
	var very_hard := is_hard and not _challenge and Game.difficulty_of(_level) == "very_hard"
	hard_badge.visible = is_hard
	(hard_badge as Label).text = tr("level_very_hard") if very_hard else tr("level_hard")
	tut_label.text = _mech_hint()
	board_view.setup(board)
	board_view.set_specials(attempt.get("specials", []))
	_refresh_hud()
	while true:
		var kind := Game.claim_gift()
		if kind == "":
			break
		var dlg := Dialog.new(tr("mech_new") % tr("booster_" + kind), tr("tut_%s_gift" % kind),
			[{"id": "ok", "text": tr("mech_got_it"), "kind": "primary", "name": "GotItButton"}])
		await _ask(dlg)
		if _left:
			return
	_refresh_hud()
	if warn and is_hard:
		_set_state("dialog")
		await _show_difficulty_banner(very_hard)
		if _left:
			return
	_set_state("playing")
	_reset_think()
	if _level == 1:
		tut_label.text = tr("tut_tap")
		board_view.highlight(board.hint())


## Dải cảnh báo độ khó theo WarningHardLevelLayer (color-cube-match-puzzle): WarningHardAnimation hiện dần 0.2s rồi
## nhịp các icon, chữ, vạch chắn chạy; giữ Config.CONTENT.hard_banner_sec (chạm để bỏ qua), mờ đi 0.2s rồi tự vào chơi.
## Đầu lâu bay về huy hiệu độ khó trên HUD (SkullTarget của prefab) trong lúc đã chơi được.
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
	var skip := [false]
	root.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed or ev is InputEventScreenTouch and ev.pressed:
			skip[0] = true)
	Sfx.play("button")
	# WarningHardAnimation.PlayAnim: fade in, then yoyo pulses (InOutSine) and the barrier tapes shrink from 100x width.
	var extreme: Control = v.node("Panel/WarningExtreme")
	extreme.modulate.a = 0.0
	var loops: Array[Tween] = []
	var tin := root.create_tween()
	tin.tween_property(extreme, "modulate:a", 1.0, 0.2)
	tin.tween_callback(func() -> void:
		for p in [["Panel/WarningExtreme/Noti1", 1.15, 0.3], ["Panel/WarningExtreme/Noti2", 1.15, 0.3],
				["GameObject/Skull", 1.12, 0.4], ["Panel/WarningExtreme/HardLevelTxt", 1.12, 0.4]]:
			var n: Control = v.node(p[0])
			var tw := n.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(n, "scale", Vector2.ONE * float(p[1]), float(p[2]))
			tw.tween_property(n, "scale", Vector2.ONE, float(p[2]))
			loops.append(tw))
	for p in ["Panel/WarningExtreme/Image", "Panel/WarningExtreme/Image (1)"]:
		var bar: Control = v.node(p)
		var r: Dictionary = bar.get_meta("u_rect")
		var w := float((r.size as Vector2).x)
		var tw := bar.create_tween().set_loops()
		tw.tween_method(func(x: float) -> void:
			r.size = Vector2(x, (r.size as Vector2).y)
			UnityUI.apply_rect(bar), w * 100.0, w, 30.0)
		loops.append(tw)
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


## Level dạy cơ chế (14, 30, 40, 55, 70, 90): một dòng "Tên: luật" ở đầu level. Challenge không có.
func _mech_hint() -> String:
	if _challenge:
		return ""
	for m in MECHS:
		if _level == int(Config.UNLOCK.get(m, -1)):
			return "%s: %s" % [tr("mech_" + m), tr("mech_%s_desc" % m)]
	return ""


func _touched() -> bool:
	return int(attempt.taps) > 0 or board.moves_left() < int(attempt.moves0) \
		or board.remaining_count() < int(attempt.count0)


# --- HUD ---

func _refresh_hud() -> void:
	if not _built or board == null:
		return
	moves_label.text = str(board.moves_left() - _moves_pending)
	var total := (attempt.get("specials", []) as Array).size()
	piece_chip.visible = total > 0
	piece_label.text = "%d/%d" % [int(attempt.get("pieces", 0)), total]
	for kind in BOOSTERS:
		var open := Unlocks.is_open(kind, _level)
		(booster_buttons[kind] as Button).self_modulate = Color.WHITE if open else LOCKED_TINT
		(booster_locks[kind] as Control).visible = not open
		(booster_caps[kind] as Label).text = tr("booster_" + kind) if open else tr("level_title") % _unlock_level(kind)
		var badge: Label = booster_badges[kind]
		badge.visible = open
		var n := int(Game.s.inv.get(kind, 0))
		badge.text = (tr("booster_count") % n) if n > 0 else ""
		badge.add_theme_stylebox_override("normal", _badge_box(n > 0))


## Nền huy hiệu booster: tròn xanh trống (còn hàng, code ghi số) hoặc sprite dấu + (hết kho).
func _badge_box(has_stock: bool) -> StyleBoxTexture:
	return ThemeKit.sprite_box("hud_badge_count" if has_stock else "hud_badge_plus")


func _unlock_level(kind: String) -> int:
	return int(Config.UNLOCK.get(kind, 0))


func _toast(text: String) -> void:
	toast_label.text = text
	toast_label.visible = true
	_toast_token += 1
	var token := _toast_token
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if token == _toast_token and is_instance_valid(toast_label):
			toast_label.visible = false)


func _show_clap() -> void:
	Sfx.play("clap")
	clap_label.visible = true
	clap_label.modulate.a = 1.0
	var tw := clap_label.create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(clap_label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void: clap_label.visible = false)


## Tâm khối trên màn hình (toạ độ toàn cục), lấy trước khi khối rời bàn.
func _block_center(id: String) -> Vector2:
	var n: Control = board_view.block_node(id)
	return n.get_global_rect().get_center() if n != null else board_view.get_global_rect().get_center()


## Mảnh leaderboard bay từ khối vừa rời bàn về chip đếm mảnh, tới nơi thì chip nảy nhẹ.
func _fly_piece(from: Vector2) -> void:
	Sfx.play("sfx_coin")
	var px := 64.0
	var icon := ThemeKit.make_icon("lb_piece", px)
	icon.name = "FlyingPiece"
	_overlay.add_child(icon)
	icon.size = Vector2(px, px)
	icon.pivot_offset = icon.size * 0.5
	icon.position = from - _overlay.global_position - icon.size * 0.5
	var to := piece_icon.get_global_rect().get_center() - _overlay.global_position - icon.size * 0.5
	var tw := icon.create_tween()
	tw.tween_property(icon, "scale", Vector2(1.4, 1.4), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(icon, "position", to, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(icon, "scale", Vector2(0.7, 0.7), 0.45)
	tw.tween_callback(func() -> void:
		icon.queue_free()
		if is_instance_valid(piece_icon):
			piece_icon.pivot_offset = piece_icon.size * 0.5
			var pulse := piece_icon.create_tween()
			pulse.tween_property(piece_icon, "scale", Vector2(1.25, 1.25), 0.08)
			pulse.tween_property(piece_icon, "scale", Vector2.ONE, 0.14))


# --- chạm khối ---

func _on_block_tapped(id: String) -> void:
	if state != "playing":
		return
	if _smash_mode:
		_do_smash(id)
		return
	var idle_ms := Time.get_ticks_msec() - think_start_ms
	var from := _block_center(id)
	var res: Dictionary = Game.tap(attempt, id)
	var kind := str(res.get("kind", "rejected"))
	if kind == "rejected":
		return
	board_view.apply_result(res)
	if bool(res.get("piece", false)):
		_fly_piece(from)
	if (kind == "exit" or kind == "peel") and idle_ms >= int(Config.CONTENT.think_clap_sec) * 1000:
		_show_clap()
	_tutorial_after(kind)
	_reset_think()
	_refresh_hud()
	if board.is_won() or board.is_out_of_moves():
		_resolve()


func _tutorial_after(kind: String) -> void:
	if _level != 1:
		return
	var taps := int(attempt.taps)
	if kind == "blocked" or kind == "gate_closed":
		tut_label.text = tr("tut_blocked")
	elif taps == 1:
		tut_label.text = tr("tut_color_dir")
	else:
		tut_label.text = ""
	if not board.is_won() and not board.is_out_of_moves() and taps < 3:
		board_view.highlight(board.hint())


## Đợi hoạt ảnh bàn xong (tối đa vài giây) rồi nghỉ một nhịp.
func _settle() -> void:
	var t0 := Time.get_ticks_msec()
	while board_view.is_animating() and Time.get_ticks_msec() - t0 < 2500:
		await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout


func _resolve() -> void:
	_set_state("resolving")
	_set_smash_mode(false)
	await _settle()
	if _left:
		return
	if board.is_won():
		if DisplayServer.get_name() != "headless":
			await get_tree().create_timer(float(Config.CONTENT.win_delay_sec)).timeout
			if _left:
				return
		await _win_flow()
	else:
		await _rescue_flow()


# --- hết MOVES ---

func _rescue_flow() -> void:
	for i in 12:
		# duplicate: dict của RescueFlow giữ chính nó trong _cur, gắn attempt vào sẽ tạo vòng tham chiếu.
		var o: Dictionary = Game.rescue_offer(attempt).duplicate()
		if bool(o.get("lost", true)):
			break
		o["attempt"] = attempt
		var r: Variant = await _popup_scene(POPUP_RESCUE, o)
		if _left:
			return
		var method := str(r) if r is String else ""
		if method == "inventory" or method == "gold" or method == "video":
			board_view.refresh()
			_refresh_hud()
			_set_state("playing")
			_reset_think()
			return
		if method == "need_coins":
			await _popup_scene(SHOP_MINI, {"source": "rescue"})
			if _left:
				return
			continue
		if bool(o.get("warn_life", false)) and not bool(Game.lives_view().get("infinite", false)):
			var dlg := Dialog.new(tr("rescue_confirm_title"), tr("rescue_warn_life"), [
				{"id": "yes", "text": tr("rescue_confirm_yes"), "kind": "danger", "name": "ConfirmButton"},
				{"id": "no", "text": tr("level_restart_no"), "kind": "ghost", "name": "CancelButton"}], "", UiAtlas.tex("big_heart_broken"))
			var ans: Variant = await _ask(dlg)
			if _left:
				return
			if str(ans) != "yes":
				continue
		Game.rescue_skip(attempt)
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
	var res: Dictionary = Game.on_level_won(attempt)
	_refresh_hud()
	var wr: Variant = await _popup_scene(WIN_CARD, res)
	if _left:
		return
	var x2_offered := bool(res.get("x2_available", false))
	var x2_taken := false
	var rate := bool(res.get("rate_prompt", false))
	if wr is Dictionary:
		x2_offered = bool(wr.get("x2_offered", x2_offered))
		x2_taken = bool(wr.get("x2_taken", false))
		rate = bool(wr.get("rate_prompt", rate))
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
		await _popup_scene(POPUP_OFFER, {"id": _offer_id})
		if _left:
			return
	if rate:
		Game.rate_now()
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
	return _level >= int(Config.LIVES.from_level) and _touched() and not bool(Game.lives_view().get("infinite", false))


func _on_home_pressed() -> void:
	if state != "playing":
		return
	Sfx.play("button")
	_set_state("dialog")
	if _confirm_life_loss():
		var dlg := Dialog.new(tr("level_home"), tr("rescue_warn_life"), [
			{"id": "yes", "text": tr("common_confirm"), "kind": "danger", "name": "ConfirmButton"},
			{"id": "no", "text": tr("level_restart_no"), "kind": "ghost", "name": "CancelButton"}], "", UiAtlas.tex("big_heart_broken"))
		var r: Variant = await _ask(dlg)
		if _left:
			return
		if str(r) != "yes":
			_set_state("playing")
			_reset_think()
			return
		Game.restart_cost_life(attempt)
	_leave("home")


## Bánh răng: popup cài đặt trong màn (wireframe 3.5). Home và Retry đi tiếp qua luồng xác nhận mất mạng.
func _on_settings_pressed() -> void:
	if state != "playing":
		return
	Sfx.play("button")
	_set_state("dialog")
	var r: Variant = await _popup_scene(INGAME_SETTINGS, {"life_cost": _confirm_life_loss()})
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
	Sfx.play("button")
	_set_state("dialog")
	if _level >= int(Config.LIVES.from_level):
		var body := tr("level_restart_confirm_life") if _touched() else tr("level_restart_confirm_free")
		var dlg := Dialog.new(tr("level_restart_confirm_title"), body, [
			{"id": "yes", "text": tr("level_restart_yes"), "kind": "danger", "name": "ConfirmButton"},
			{"id": "no", "text": tr("level_restart_no"), "kind": "ghost", "name": "CancelButton"}], "",
			UiAtlas.tex("big_heart_broken") if _touched() else null)
		var r: Variant = await _ask(dlg)
		if _left:
			return
		if str(r) != "yes":
			_set_state("playing")
			_reset_think()
			return
	var charged := Game.restart_cost_life(attempt)
	if charged and not _can_play():
		_leave("no_lives")
		return
	await _start_level(false)


# --- booster ---

func _on_booster_pressed(kind: String) -> void:
	if state != "playing":
		return
	Sfx.play("button")
	if not Unlocks.is_open(kind, _level):
		_toast(tr("booster_locked") % _unlock_level(kind))
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
			var id := board.hint()
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


## Sao bay từ nút Gợi ý tới khối, chạm thì khối mới sáng lên. Người chơi đã đi nước khác hoặc khối đã rời bàn
## trong lúc sao bay thì nháy gợi ý mới (không nảy), để booster không mất.
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
			var hid := id if same else board.hint()
			if hid != "":
				board_view.highlight(hid, same))


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


func _set_smash_mode(on: bool) -> void:
	_smash_mode = on
	if smash_label != null:
		smash_label.visible = on
		tut_label.visible = not on  # cùng một chỗ trên bàn


## Bàn và kho cập nhật ngay; búa kẹo mút hiện giữa màn rồi bay tới gõ, khối chỉ vỡ (và mảnh mới bay) lúc búa chạm.
## Trong lúc búa bay, bàn và các nút không nhận chạm (state "smashing").
func _do_smash(id: String) -> void:
	_set_smash_mode(false)
	if not Game.use_booster("smash"):
		return
	var from := _block_center(id)
	var target: Vector2 = board_view.strike_point(id)
	var r: Dictionary = Game.smash_block(attempt, id)
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
		board_view.smash_anim(id)
		if bool(r.piece):
			_fly_piece(from)
		if state == "smashing":
			_set_state("playing")
		_reset_think()
		if board.is_won():
			_resolve())


## Booster hết kho: mua bằng gold, hoặc video miễn phí (một lần mỗi lượt) khi thiếu gold.
func _booster_dialog(kind: String) -> void:
	_set_state("dialog")
	var message := ""
	var got := false
	for i in 8:
		var price := int(Config.ECON.booster_price.get(kind, 0))
		var can_afford := int(Game.s.coins) >= price
		var items: Array = [{"id": "buy", "text": tr("booster_buy") % price,
			"kind": "primary" if can_afford else "secondary", "name": "BuyButton"}]
		var free_ok := not can_afford and not bool((attempt.free_used as Dictionary).get("any", false)) \
			and bool(Game.lives_view().get("video_ready", false))
		if free_ok:
			items.append({"id": "video", "text": tr("booster_free_video"), "kind": "video", "name": "VideoButton"})
			Game.offer_video(FREE_PLACEMENT)
		items.append({"id": "close", "text": tr("common_close"), "kind": "ghost", "name": "CloseButton"})
		var dlg := Dialog.new(tr("booster_" + kind), tr("booster_%s_desc" % kind), items, message, ThemeKit.icon("booster_" + kind))
		message = ""
		var r: Variant = await _ask(dlg)
		if _left:
			return
		var choice := str(r) if r is String else ""
		if choice == "buy":
			if Game.buy_booster(kind):
				got = true
				break
			await _popup_scene(SHOP_MINI, {"source": "booster"})
			if _left:
				return
		elif choice == "video":
			if await Game.booster_video(attempt, kind):
				got = true
				break
			match Game.last_ad_reason:
				"not_ready":
					message = tr("ads_not_available")
				"closed":
					message = tr("ads_closed_early")
				_:
					message = tr("ads_failed")
		else:
			break
	_set_state("playing")
	_reset_think()
	if got:
		_use_booster(kind)
