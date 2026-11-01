extends Control
## Màn level: HUD, bàn cờ, booster, luồng hết MOVES, thắng, thua, restart.
## setup({challenge: true}) chạy Daily Challenge (Game.start_challenge) thay vì level kế tiếp; thắng thì về Home.
## closed({"action": "home" | "no_lives"}). Popup mở qua Main.open_popup (hoặc lớp riêng khi chạy lẻ).
## UI chỉ gọi Game và Sfx; hoạt ảnh bàn do BoardView lo.

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Config := preload("res://src/config.gd")
const Unlocks := preload("res://src/meta/unlocks.gd")
const BoardState := preload("res://src/core/board_state.gd")
const BoardViewScene := preload("res://scenes/board_view.tscn")

const POPUP_RESCUE := "res://scenes/popup_rescue.tscn"
const POPUP_OFFER := "res://scenes/popup_offer.tscn"
const WIN_CARD := "res://scenes/win_card.tscn"
const LOSE_CARD := "res://scenes/lose_card.tscn"
const SHOP_MINI := "res://scenes/shop_mini.tscn"
const BOOSTERS := ["hint", "move", "smash"]
const FREE_PLACEMENT := "booster_free"
const MECHS := ["stone", "ice", "chain", "layer", "fog", "pulse"]


## Hộp thoại nhỏ dựng bằng code. items: [{id, text, kind, name, close}]. Bấm nút phát chosen(id),
## rồi closed(id) nếu close (mặc định true). Back của Android phát closed(null).
class Dialog extends Control:
	const ThemeKit := preload("res://src/ui/theme_kit.gd")
	signal closed(result: Variant)
	signal chosen(id: String)
	var buttons: Dictionary = {}
	var title_label: Label = null
	var body_label: Label = null
	var message_label: Label = null
	var _panel: Control = null

	func _init(title: String = "", body: String = "", items: Array = [], message: String = "") -> void:
		name = "Dialog"
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var dim := ColorRect.new()
		dim.name = "Dim"
		dim.color = Color(0, 0, 0, 0.6)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(dim)
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(center)
		_panel = ThemeKit.make_panel()
		_panel.name = "Panel"
		center.add_child(_panel)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 20)
		_panel.add_child(box)
		title_label = _label(title, ThemeKit.FS_TITLE, ThemeKit.TEXT, "TitleLabel")
		box.add_child(title_label)
		if body != "":
			body_label = _label(body, ThemeKit.FS_BODY, ThemeKit.TEXT_DIM, "BodyLabel")
			box.add_child(body_label)
		message_label = _label(message, ThemeKit.FS_SMALL, ThemeKit.DANGER, "MessageLabel")
		message_label.visible = message != ""
		box.add_child(message_label)
		for it in items:
			var b := ThemeKit.make_button(str(it.get("text", "")), str(it.get("kind", "primary")))
			var id := str(it.get("id", ""))
			b.name = str(it.get("name", "Btn_" + id))
			b.pressed.connect(_on_pressed.bind(id, bool(it.get("close", true))))
			box.add_child(b)
			buttons[id] = b

	func _ready() -> void:
		_animate_in.call_deferred()

	func _animate_in() -> void:
		if _panel != null and is_instance_valid(_panel):
			ThemeKit.popup_in(_panel)

	func _label(text: String, px_size: int, color: Color, node_name: String) -> Label:
		var l := ThemeKit.make_label(text, px_size, color)
		l.name = node_name
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 560
		return l

	func _on_pressed(id: String, close: bool) -> void:
		Sfx.play("button")
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
var tut_label: Label = null
var clap_label: Label = null
var toast_label: Label = null
var smash_label: Label = null
var home_button: Button = null
var restart_button: Button = null
## id booster -> nút và nhãn góc (số còn lại hoặc "+")
var booster_buttons: Dictionary = {}
var booster_badges: Dictionary = {}
## Mốc bắt đầu "đang nghĩ" (ms); test lùi mốc này để thử tiếng vỗ tay.
var think_start_ms: int = 0

var _built: bool = false
var _challenge: bool = false
var _level: int = 0
var _smash_mode: bool = false
var _offer_id: String = ""
var _overlay: Control = null
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
	var b := ThemeKit.make_button("", "secondary")
	b.name = node_name
	b.icon = ThemeKit.icon(icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(96, 96)
	if node_name == "HomeButton" or node_name == "RestartButton":
		_shrink_margins(b)
	return b


## Nút icon vuông 96px: bớt lề trong để icon không bé như chấm.
func _shrink_margins(b: Button) -> void:
	for sb_name in ["normal", "hover", "pressed", "disabled"]:
		var sb := b.get_theme_stylebox(sb_name) as StyleBoxFlat
		if sb == null:
			continue
		sb = sb.duplicate()
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 16
		sb.content_margin_bottom = 16
		b.add_theme_stylebox_override(sb_name, sb)


func _build() -> void:
	if _built:
		return
	_built = true
	theme = ThemeKit.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ThemeKit.make_background())

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

	# thanh trên: Home, tên level, restart
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	col.add_child(top)
	home_button = _icon_button("ui_home", "HomeButton")
	home_button.pressed.connect(_on_home_pressed)
	top.add_child(home_button)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(mid)
	title_label = ThemeKit.make_label("", ThemeKit.FS_TITLE)
	title_label.name = "TitleLabel"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(title_label)
	var hard := Label.new()
	hard.name = "HardBadge"
	hard.text = tr("level_hard")
	hard.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hard.add_theme_font_size_override("font_size", ThemeKit.FS_SMALL)
	hard.add_theme_color_override("font_color", ThemeKit.TEXT)
	var hs := StyleBoxFlat.new()
	hs.bg_color = ThemeKit.DANGER
	hs.set_corner_radius_all(14)
	hs.content_margin_left = 16
	hs.content_margin_right = 16
	hs.content_margin_top = 2
	hs.content_margin_bottom = 2
	hard.add_theme_stylebox_override("normal", hs)
	hard.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hard.visible = false
	hard_badge = hard
	mid.add_child(hard)
	restart_button = _icon_button("ui_restart", "RestartButton")
	restart_button.pressed.connect(_on_restart_pressed)
	top.add_child(restart_button)

	moves_label = ThemeKit.make_label("", ThemeKit.FS_TITLE, ThemeKit.GOLD)
	moves_label.name = "MovesLabel"
	moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(moves_label)

	tut_label = ThemeKit.make_label("", ThemeKit.FS_BODY, ThemeKit.TEXT_DIM)
	tut_label.name = "TutLabel"
	tut_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tut_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tut_label.custom_minimum_size.y = 48
	col.add_child(tut_label)

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

	smash_label = ThemeKit.make_label(tr("booster_smash_pick"), ThemeKit.FS_BODY, ThemeKit.GOLD)
	smash_label.name = "SmashLabel"
	smash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	smash_label.visible = false
	col.add_child(smash_label)

	# booster
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	col.add_child(row)
	for kind in BOOSTERS:
		var c := VBoxContainer.new()
		c.name = "Booster_" + kind
		c.add_theme_constant_override("separation", 4)
		var b := _icon_button("booster_" + kind, "BoosterButton_" + kind)
		b.custom_minimum_size = Vector2(128, 128)
		b.pressed.connect(_on_booster_pressed.bind(kind))
		c.add_child(b)
		var badge := Label.new()
		badge.name = "BoosterBadge_" + kind
		badge.add_theme_font_size_override("font_size", ThemeKit.FS_SMALL)
		badge.add_theme_color_override("font_color", ThemeKit.TEXT)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var bs := StyleBoxFlat.new()
		bs.bg_color = ThemeKit.DANGER
		bs.set_corner_radius_all(18)
		bs.content_margin_left = 10
		bs.content_margin_right = 10
		bs.content_margin_top = 0
		bs.content_margin_bottom = 0
		badge.add_theme_stylebox_override("normal", bs)
		badge.custom_minimum_size = Vector2(36, 36)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(badge)
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		badge.offset_top = -8
		badge.offset_right = 8
		var cap := ThemeKit.make_label(tr("booster_" + kind), ThemeKit.FS_SMALL, ThemeKit.TEXT_DIM)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(cap)
		row.add_child(c)
		booster_buttons[kind] = b
		booster_badges[kind] = badge

	_overlay = Control.new()
	_overlay.name = "LocalPopups"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	Game.inv_changed.connect(_on_game_changed)
	Game.coins_changed.connect(_on_game_changed)
	Game.offer_ready.connect(_on_offer_ready)


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

func _start_level() -> void:
	_set_state("intro")
	_set_smash_mode(false)
	# Level sinh trong game (sau L300, Daily Challenge): màn chờ ngắn, vẽ xong mới sinh.
	if Game.challenge_needs_generation() if _challenge else Game.level_needs_generation():
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
	hard_badge.visible = bool(attempt.get("hard", false))
	tut_label.text = _mech_hint()
	board_view.setup(board)
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
	_set_state("playing")
	_reset_think()
	if _level == 1:
		tut_label.text = tr("tut_tap")
		board_view.highlight(board.hint())


## Level dạy cơ chế (21, 31, 46, 61, 81, 101): một dòng "Tên: luật" ở đầu level. Challenge không có.
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
	moves_label.text = tr("level_moves_left") % board.moves_left()
	for kind in BOOSTERS:
		var open := Unlocks.is_open(kind, _level)
		var b: Button = booster_buttons[kind]
		b.get_parent().visible = open
		var n := int(Game.s.inv.get(kind, 0))
		(booster_badges[kind] as Label).text = (tr("booster_count") % n) if n > 0 else "+"


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


# --- chạm khối ---

func _on_block_tapped(id: String) -> void:
	if state != "playing":
		return
	if _smash_mode:
		_do_smash(id)
		return
	var idle_ms := Time.get_ticks_msec() - think_start_ms
	var res: Dictionary = Game.tap(attempt, id)
	var kind := str(res.get("kind", "rejected"))
	if kind == "rejected":
		return
	board_view.apply_result(res)
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
		if bool(o.get("warn_life", false)):
			var dlg := Dialog.new(tr("rescue_confirm_title"), tr("rescue_warn_life"), [
				{"id": "yes", "text": tr("rescue_confirm_yes"), "kind": "danger", "name": "ConfirmButton"},
				{"id": "no", "text": tr("level_restart_no"), "kind": "ghost", "name": "CancelButton"}])
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
	return _level >= int(Config.LIVES.from_level) and _touched()


func _on_home_pressed() -> void:
	if state != "playing":
		return
	Sfx.play("button")
	_set_state("dialog")
	if _confirm_life_loss():
		var dlg := Dialog.new(tr("level_home"), tr("rescue_warn_life"), [
			{"id": "yes", "text": tr("common_confirm"), "kind": "danger", "name": "ConfirmButton"},
			{"id": "no", "text": tr("level_restart_no"), "kind": "ghost", "name": "CancelButton"}])
		var r: Variant = await _ask(dlg)
		if _left:
			return
		if str(r) != "yes":
			_set_state("playing")
			_reset_think()
			return
		Game.restart_cost_life(attempt)
	_leave("home")


func _on_restart_pressed() -> void:
	if state != "playing":
		return
	Sfx.play("button")
	_set_state("dialog")
	if _level >= int(Config.LIVES.from_level):
		var body := tr("level_restart_confirm_life") if _touched() else tr("level_restart_confirm_free")
		var dlg := Dialog.new(tr("level_restart_confirm_title"), body, [
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
	if charged and not _can_play():
		_leave("no_lives")
		return
	await _start_level()


# --- booster ---

func _on_booster_pressed(kind: String) -> void:
	if state != "playing":
		return
	Sfx.play("button")
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
				board_view.highlight(id)
		"move":
			if Game.use_booster("move"):
				board.add_moves(int(Config.ECON.rescue_moves))
				board_view.refresh()
				Sfx.play("moves")
		"smash":
			_set_smash_mode(true)
	_refresh_hud()
	_reset_think()


func _set_smash_mode(on: bool) -> void:
	_smash_mode = on
	if smash_label != null:
		smash_label.visible = on


func _do_smash(id: String) -> void:
	_set_smash_mode(false)
	if not Game.use_booster("smash"):
		return
	if board.smash(id):
		board_view.smash_anim(id)
	_reset_think()
	_refresh_hud()
	if board.is_won():
		_resolve()


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
		var dlg := Dialog.new(tr("booster_" + kind), tr("booster_%s_desc" % kind), items, message)
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
