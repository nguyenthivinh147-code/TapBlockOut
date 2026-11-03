extends Control
## Layer Weekly Pass. Active: Main Tree (free + VIP), Bonus Bank, mua VIP. Waiting: đếm ngược.
## Popup cuối mùa (nếu có) hiện trước. setup(args); signal closed({}).

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const RewardText := preload("res://src/ui/reward_text.gd")
const WeeklyPass := preload("res://src/meta/weekly_pass.gd")
const Config := preload("res://src/config.gd")

const BANK_COLS := 5

var view: Dictionary = {}
var end_info: Dictionary = {}
var toast_text: String = ""
var buy_vip_button: Button = null
var claim_all_button: Button = null
var close_button: Button = null
var main_buttons: Dictionary = {}  # "free_3" / "vip_3" -> Button
var bank_buttons: Array[Button] = []

var _content: Control = null
var _time_label: Label = null
var _timer: Timer = null
var _busy: bool = false
var _closed: bool = false


func setup(_args: Dictionary = {}) -> void:
	if _content != null:
		return
	Game.weekly_refresh()
	end_info = Game.weekly_take_end()
	if Game.weekly_state() == WeeklyPass.ACTIVE:
		Game.weekly_opened()
	_rebuild()


func _ready() -> void:
	if _content == null:
		setup()
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_timer.start()


func _tick() -> void:
	if _content == null:
		return
	if Game.weekly_state() != str(view.get("state", "")):
		_rebuild()
		return
	if _time_label == null:
		return
	_time_label.text = _time_text(int(Game.weekly_view().seconds_left))


static func fmt_time(sec: int) -> String:
	sec = maxi(sec, 0)
	if sec >= 86400:
		@warning_ignore("integer_division")
		return "%dd %dh" % [sec / 86400, (sec % 86400) / 3600]
	@warning_ignore("integer_division")
	return "%d:%02d:%02d" % [sec / 3600, (sec % 3600) / 60, sec % 60]


func _time_text(sec: int) -> String:
	return tr("weekly_time_left") % fmt_time(sec)


func _rebuild() -> void:
	if _content != null:
		_content.queue_free()
		_content = null
	main_buttons = {}
	bank_buttons = []
	buy_vip_button = null
	claim_all_button = null
	view = Game.weekly_view()

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_content = root
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var panel := ThemeKit.make_panel()
	panel.custom_minimum_size = Vector2(660, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(_title(tr("weekly_title")))

	if not end_info.is_empty():
		_build_end(v)
	elif str(view.state) == WeeklyPass.ACTIVE:
		_build_active(v)
	elif str(view.state) == WeeklyPass.WAITING:
		_build_waiting(v)
	else:
		var l := ThemeKit.make_label(tr("weekly_locked"), ThemeKit.FS_BODY)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	close_button = ThemeKit.make_button(tr("common_close"), "ghost")
	close_button.name = "CloseButton"
	close_button.pressed.connect(close)
	v.add_child(close_button)
	ThemeKit.popup_in.call_deferred(panel)


func _title(text: String) -> Label:
	var t := ThemeKit.make_label(text, ThemeKit.FS_TITLE, ThemeKit.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return t


func _build_end(v: VBoxContainer) -> void:
	v.add_child(_title(tr("weekly_end_title")))
	var msg: String
	if bool(end_info.get("vip", false)):
		var rt := RewardText.text({"coins": int(end_info.get("coins", 0)), "items": end_info.get("items", {})})
		msg = tr("weekly_end_vip") % (rt if rt != "" else "-")
	else:
		msg = tr("weekly_end_free") % int(end_info.get("points", 0))
	var l := ThemeKit.make_label(msg, ThemeKit.FS_BODY)
	l.name = "EndLabel"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var ok := ThemeKit.make_button(tr("common_ok"), "primary")
	ok.name = "EndOkButton"
	ok.pressed.connect(func() -> void:
		end_info = {}
		_rebuild())
	v.add_child(ok)


func _build_waiting(v: VBoxContainer) -> void:
	var l := ThemeKit.make_label(tr("weekly_waiting_title"), ThemeKit.FS_BUTTON)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	_time_label = ThemeKit.make_label(tr("weekly_waiting_body") % fmt_time(int(view.seconds_left)),
		ThemeKit.FS_BODY, ThemeKit.TEXT_DIM)
	_time_label.name = "WaitingLabel"
	_time_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_time_label)
	_time_label = null  # chỉ làm mới khi đổi state


func _build_active(v: VBoxContainer) -> void:
	_time_label = ThemeKit.make_label(_time_text(int(view.seconds_left)), ThemeKit.FS_SMALL, ThemeKit.TEXT_DIM)
	_time_label.name = "TimeLabel"
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_time_label)
	var keys := ThemeKit.make_label(tr("weekly_keys") % [int(view.points), int(view.last_points)], ThemeKit.FS_BUTTON)
	keys.name = "KeysLabel"
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(keys)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 640)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	var head := HBoxContainer.new()
	list.add_child(head)
	for h in [["", 150], [tr("weekly_free"), 230], [tr("weekly_vip"), 230]]:
		var hl := ThemeKit.make_label(h[0], ThemeKit.FS_SMALL, ThemeKit.TEXT_DIM)
		hl.custom_minimum_size = Vector2(h[1], 0)
		head.add_child(hl)
	for row in view.main:
		_build_row(list, row)

	var bank_title := ThemeKit.make_label(tr("weekly_bank_title"), ThemeKit.FS_BUTTON, ThemeKit.GOLD)
	list.add_child(bank_title)
	if bool(view.bank_unlocked):
		var step := ThemeKit.make_label(tr("weekly_bank_step") % int(Config.WEEKLY.get("bank_step", 15)), ThemeKit.FS_SMALL, ThemeKit.TEXT_DIM)
		list.add_child(step)
		var grid := GridContainer.new()
		grid.columns = BANK_COLS
		list.add_child(grid)
		for b in view.bank:
			var btn := ThemeKit.make_button(_bank_text(b), "secondary")
			btn.custom_minimum_size = Vector2(110, 96)
			btn.disabled = not bool(b.claimable)
			btn.pressed.connect(_on_claim_bank.bind(int(b.index)))
			grid.add_child(btn)
			bank_buttons.append(btn)
	else:
		var l := ThemeKit.make_label(tr("weekly_bank_locked"), ThemeKit.FS_SMALL, ThemeKit.TEXT_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(l)

	if bool(view.vip):
		var vl := ThemeKit.make_label("%s - %s" % [tr("weekly_vip_active"), tr("weekly_vip_hearts") % int(view.bonus_hearts)],
			ThemeKit.FS_SMALL, ThemeKit.GOOD)
		vl.name = "VipLabel"
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(vl)
	else:
		buy_vip_button = ThemeKit.make_button(tr("weekly_buy_vip") % str(view.vip_price), "video")
		buy_vip_button.name = "BuyVipButton"
		buy_vip_button.pressed.connect(_on_buy_vip)
		v.add_child(buy_vip_button)
		var hint := ThemeKit.make_label(tr("weekly_vip_hint") + " " + tr("weekly_vip_hearts") % int(view.bonus_hearts),
			ThemeKit.FS_SMALL, ThemeKit.TEXT_DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(hint)
	if toast_text != "":
		var tl := ThemeKit.make_label(toast_text, ThemeKit.FS_SMALL, ThemeKit.DANGER)
		tl.name = "ToastLabel"
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(tl)
	claim_all_button = ThemeKit.make_button(tr("weekly_claim_all"), "primary")
	claim_all_button.name = "ClaimAllButton"
	claim_all_button.disabled = int(view.badge) <= 0
	claim_all_button.pressed.connect(_on_claim_all)
	v.add_child(claim_all_button)



func _bank_text(b: Dictionary) -> String:
	if bool(b.claimed):
		return "OK"
	return str(int(b.coins))


func _build_row(list: VBoxContainer, row: Dictionary) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	list.add_child(h)
	var pts := ThemeKit.make_label(tr("weekly_milestone") % int(row.points), ThemeKit.FS_SMALL)
	pts.custom_minimum_size = Vector2(150, 0)
	h.add_child(pts)
	var i := int(row.index)
	for kind in ["free", "vip"]:
		var claimed := bool(row[kind + "_claimed"])
		var claimable := bool(row[kind + "_claimable"])
		var rt := RewardText.text(row[kind])
		var b := ThemeKit.make_button(tr("weekly_claimed") if claimed else rt, "primary" if claimable else "secondary")
		b.custom_minimum_size = Vector2(230, 96)
		b.add_theme_font_size_override("font_size", ThemeKit.FS_SMALL)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.disabled = not claimable
		b.pressed.connect(_on_claim.bind(kind, i))
		h.add_child(b)
		main_buttons["%s_%d" % [kind, i]] = b


func _on_claim(kind: String, i: int) -> void:
	if _busy or _closed:
		return
	Sfx.play("sfx_coin")
	if kind == "free":
		Game.weekly_claim_free(i)
	else:
		Game.weekly_claim_vip(i)
	_rebuild()


func _on_claim_bank(i: int) -> void:
	if _busy or _closed:
		return
	Sfx.play("sfx_coin")
	Game.weekly_claim_bank(i)
	_rebuild()


func _on_claim_all() -> void:
	if _busy or _closed:
		return
	Sfx.play("sfx_coin")
	Game.weekly_claim_all()
	_rebuild()


func _on_buy_vip() -> void:
	if _busy or _closed:
		return
	_busy = true
	buy_vip_button.disabled = true
	var r: Dictionary = await Game.weekly_buy_vip()
	_busy = false
	if not is_inside_tree() or _closed:
		return
	match str(r.get("status", "error")):
		"ok":
			if bool(r.get("granted", false)):
				Sfx.play("sfx_coin")
		"cancel":
			pass
		"pending":
			toast_text = tr("shop_buy_pending")
		_:
			toast_text = tr("shop_buy_failed")
	_rebuild()


func close() -> void:
	if _closed:
		return
	_closed = true
	closed.emit({})
