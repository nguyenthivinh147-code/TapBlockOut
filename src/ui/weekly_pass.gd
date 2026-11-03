extends Control
## Layer Weekly Pass. Active: Main Tree (free + VIP), Bonus Bank, mua VIP. Waiting: đếm ngược.
## Popup cuối mùa (nếu có) hiện trước. setup(args); signal closed({}).

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const PopupKit := preload("res://src/ui/popup_kit.gd")
const RewardText := preload("res://src/ui/reward_text.gd")
const WeeklyPass := preload("res://src/meta/weekly_pass.gd")
const Config := preload("res://src/config.gd")
const Tutorial := preload("res://src/ui/weekly_pass_tutorial.gd")
const HOWTO_SCENE := "res://scenes/popup_weekly_tutorial.tscn"

const BANK_COLS := 4
const ROW_LABEL_W := 100
const ROW_CELL_W := 220
const SCROLL_H := 450  # card cao ~1210 để vừa màn 720x1280 cùng ribbon, đồng hồ và nút
const TUTORIAL_DELAY := 0.35  # chờ popup_in xong để lỗ spotlight khớp vị trí thật

var view: Dictionary = {}
var end_info: Dictionary = {}
var toast_text: String = ""
var buy_vip_button: Button = null
var claim_all_button: Button = null
var close_button: Button = null
var info_button: Button = null
var key_button: Button = null
var progress_row: Control = null
var main_buttons: Dictionary = {}  # "free_3" / "vip_3" -> Button
var bank_buttons: Array[Button] = []
var tutorial: Control = null  # overlay đang chạy
var howto: Control = null  # popup "How to earn rewards" đang mở

var _content: Control = null
var _scroll: ScrollContainer = null
var _time_label: Label = null
var _timer: Timer = null
var _busy: bool = false
var _closed: bool = false
var _tutorial_waiting: bool = false


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
	_stop_tutorial()
	main_buttons = {}
	bank_buttons = []
	buy_vip_button = null
	claim_all_button = null
	info_button = null
	key_button = null
	progress_row = null
	_scroll = null
	view = Game.weekly_view()

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_content = root
	var k := PopupKit.make(root, tr("weekly_title"), close, {"separation": 12, "width": 680.0})
	close_button = k.close
	close_button.name = "CloseButton"
	var v: VBoxContainer = k.box

	if not end_info.is_empty():
		_build_end(v)
	elif str(view.state) == WeeklyPass.ACTIVE:
		_build_active(v)
	elif str(view.state) == WeeklyPass.WAITING:
		_build_waiting(v)
	else:
		v.add_child(PopupKit.text(tr("weekly_locked")))
	PopupKit.show_in(k)
	_auto_tutorial.call_deferred()


func _title(text: String) -> Label:
	return PopupKit.text(text, ThemeKit.FS_BODY + 4, ThemeKit.BROWN)


func _build_end(v: VBoxContainer) -> void:
	v.add_child(_title(tr("weekly_end_title")))
	var msg: String
	if bool(end_info.get("vip", false)):
		var rt := RewardText.text({"coins": int(end_info.get("coins", 0)), "items": end_info.get("items", {}),
			"inf_min": int(end_info.get("inf_min", 0))})
		msg = tr("weekly_end_vip") % (rt if rt != "" else "-")
	else:
		msg = tr("weekly_end_free") % int(end_info.get("points", 0))
	v.add_child(PopupKit.text(msg, ThemeKit.FS_BODY, ThemeKit.INK, "EndLabel"))
	var ok := ThemeKit.make_button(tr("common_ok"), "primary")
	ok.name = "EndOkButton"
	ok.pressed.connect(func() -> void:
		end_info = {}
		_rebuild())
	v.add_child(ok)


func _build_waiting(v: VBoxContainer) -> void:
	v.add_child(PopupKit.text(tr("weekly_waiting_title"), ThemeKit.FS_BUTTON))
	v.add_child(PopupKit.text(tr("weekly_waiting_body") % fmt_time(int(view.seconds_left)), ThemeKit.FS_BODY, ThemeKit.INK_DIM, "WaitingLabel"))
	_time_label = null  # chỉ làm mới khi đổi state


func _build_active(v: VBoxContainer) -> void:
	_time_label = PopupKit.text(_time_text(int(view.seconds_left)), ThemeKit.FS_SMALL, ThemeKit.INK_DIM, "TimeLabel")
	v.add_child(_time_label)
	v.add_child(_build_progress())

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, SCROLL_H)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	_scroll.add_child(list)
	var head := HBoxContainer.new()
	list.add_child(head)
	for h in [["", ROW_LABEL_W], [tr("weekly_free"), ROW_CELL_W], [tr("weekly_vip"), ROW_CELL_W]]:
		var hl := ThemeKit.ink_label(h[0], ThemeKit.FS_SMALL, ThemeKit.BROWN)
		hl.custom_minimum_size = Vector2(h[1], 0)
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_child(hl)
	for row in view.main:
		_build_row(list, row)

	list.add_child(PopupKit.text(tr("weekly_bank_title"), ThemeKit.FS_BODY, ThemeKit.BROWN))
	if bool(view.bank_unlocked):
		list.add_child(PopupKit.text(tr("weekly_bank_step") % int(Config.WEEKLY.get("bank_step", 15)), ThemeKit.FS_SMALL, ThemeKit.INK_DIM))
		var grid := GridContainer.new()
		grid.columns = BANK_COLS
		list.add_child(grid)
		for b in view.bank:
			var btn := ThemeKit.make_button(_bank_text(b), "secondary")
			btn.custom_minimum_size = Vector2(130, 96)
			btn.add_theme_font_size_override("font_size", ThemeKit.FS_SMALL)
			btn.disabled = not bool(b.claimable)
			btn.pressed.connect(_on_claim_bank.bind(int(b.index)))
			grid.add_child(btn)
			bank_buttons.append(btn)
	else:
		list.add_child(PopupKit.text(tr("weekly_bank_locked"), ThemeKit.FS_SMALL, ThemeKit.INK_DIM))

	if bool(view.vip):
		v.add_child(PopupKit.text("%s - %s" % [tr("weekly_vip_active"), tr("weekly_vip_hearts") % int(view.bonus_hearts)],
			ThemeKit.FS_SMALL, ThemeKit.INK_GOOD, "VipLabel"))
	else:
		buy_vip_button = ThemeKit.make_button(tr("weekly_buy_vip") % str(view.vip_price), "gold")
		buy_vip_button.name = "BuyVipButton"
		buy_vip_button.pressed.connect(_on_buy_vip)
		v.add_child(buy_vip_button)
		v.add_child(PopupKit.text(tr("weekly_vip_hint") + " " + tr("weekly_vip_hearts") % int(view.bonus_hearts),
			ThemeKit.FS_SMALL - 2, ThemeKit.INK_DIM))
	if toast_text != "":
		v.add_child(PopupKit.text(toast_text, ThemeKit.FS_SMALL, ThemeKit.INK_DANGER, "ToastLabel"))
	claim_all_button = ThemeKit.make_button(tr("weekly_claim_all"), "primary")
	claim_all_button.name = "ClaimAllButton"
	claim_all_button.disabled = int(view.badge) <= 0
	claim_all_button.pressed.connect(_on_claim_all)
	v.add_child(claim_all_button)



## Hàng tiến độ: nút "i", chìa (bấm để xem cách kiếm thưởng), thanh tới mốc kế và số key.
## Đây cũng là target của bước 3 trong tutorial.
func _build_progress() -> Control:
	progress_row = HBoxContainer.new()
	progress_row.name = "ProgressRow"
	(progress_row as HBoxContainer).add_theme_constant_override("separation", 12)

	info_button = ThemeKit.make_button("i", "ghost")
	info_button.name = "InfoButton"
	info_button.custom_minimum_size = Vector2(72, 72)
	info_button.pressed.connect(open_howto)
	progress_row.add_child(info_button)

	key_button = ThemeKit.make_button("", "icon")
	key_button.name = "KeyButton"
	key_button.custom_minimum_size = Vector2(72, 72)
	key_button.icon = ThemeKit.icon("mech_key")
	key_button.expand_icon = true
	key_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	key_button.add_theme_constant_override("icon_max_width", 44)
	key_button.add_theme_stylebox_override("normal", _flat(ThemeKit.PANEL_BORDER, 36, 8))
	key_button.add_theme_stylebox_override("hover", _flat(ThemeKit.PANEL_BORDER.lightened(0.08), 36, 8))
	key_button.add_theme_stylebox_override("pressed", _flat(ThemeKit.PANEL_BORDER.darkened(0.2), 36, 8))
	key_button.pressed.connect(open_howto)
	progress_row.add_child(key_button)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	progress_row.add_child(col)
	var bar := ProgressBar.new()
	bar.name = "ProgressBar"
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.001  # mặc định 0.01 làm tròn tỉ lệ
	bar.value = float(view.progress)
	bar.custom_minimum_size = Vector2(0, 28)
	ThemeKit.style_bar(bar, ThemeKit.GOLD_DEEP)
	col.add_child(bar)
	var keys := ThemeKit.ink_label(tr("weekly_keys") % [int(view.points), int(view.last_points)], ThemeKit.FS_SMALL)
	keys.name = "KeysLabel"
	col.add_child(keys)
	return progress_row


func _flat(fill: Color, radius: int, margin: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(margin)
	return b


# --- tutorial ---

## Mở layer lần đầu (Active, chưa xem tutorial): chờ popup_in xong rồi chạy tutorial.
func _auto_tutorial() -> void:
	if _closed or _tutorial_waiting or not end_info.is_empty() or progress_row == null:
		return
	if str(view.state) != WeeklyPass.ACTIVE or Game.weekly_tutorial_seen():
		return
	_tutorial_waiting = true
	await get_tree().create_timer(TUTORIAL_DELAY).timeout
	_tutorial_waiting = false
	if _closed or not is_inside_tree() or Game.weekly_tutorial_seen():
		return
	start_tutorial()


## Chạy tutorial 3 bước trên hàng mốc hiện tại: thưởng free, thưởng VIP, thanh tiến độ.
## Trả false nếu layer không ở trạng thái có đủ target.
func start_tutorial() -> bool:
	if tutorial != null or _closed or _scroll == null or str(view.state) != WeeklyPass.ACTIVE:
		return false
	var row := int(view.tut_row)
	var free_btn: Control = main_buttons.get("free_%d" % row)
	var vip_btn: Control = main_buttons.get("vip_%d" % row)
	if free_btn == null or vip_btn == null or progress_row == null:
		return false
	_scroll.ensure_control_visible(free_btn)
	var first_text := tr("weekly_tut_free_claim") if bool(view.main[row].free_claimable) else tr("weekly_tut_free_earn")
	tutorial = Tutorial.new()
	tutorial.name = "Tutorial"
	add_child(tutorial)
	tutorial.finished.connect(_on_tutorial_finished)
	tutorial.setup([
		{"target": free_btn, "text": first_text},
		{"target": vip_btn, "text": tr("weekly_tut_vip")},
		{"target": progress_row, "text": tr("weekly_tut_progress")},
	])
	return true


## Dừng overlay mà không tính là đã xem (layer dựng lại hoặc đóng giữa chừng).
func _stop_tutorial() -> void:
	if tutorial != null and is_instance_valid(tutorial):
		tutorial.finished.disconnect(_on_tutorial_finished)
		tutorial.queue_free()
	tutorial = null


## Xong bước cuối: lưu cờ (key bắt đầu được cộng) rồi mở popup cách kiếm thưởng.
func _on_tutorial_finished(completed: bool) -> void:
	tutorial = null
	if not completed or _closed:
		return
	Game.weekly_mark_tutorial_seen()
	open_howto()


## Popup "How to earn rewards" (nút "i", chìa, hoặc sau tutorial). Mở rồi thì trả lại cái đang mở.
func open_howto() -> Control:
	if howto != null and is_instance_valid(howto):
		return howto
	var node := (load(HOWTO_SCENE) as PackedScene).instantiate() as Control
	add_child(node)
	node.setup({})
	node.closed.connect(func(_r: Variant) -> void:
		node.queue_free()
		howto = null)
	howto = node
	return node


func _bank_text(b: Dictionary) -> String:
	if bool(b.claimed):
		return "OK"
	return str(int(b.coins))


func _build_row(list: VBoxContainer, row: Dictionary) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	list.add_child(h)
	var pts := ThemeKit.ink_label(tr("weekly_start") if int(row.points) <= 0 else tr("weekly_milestone") % int(row.points), ThemeKit.FS_SMALL - 2)
	pts.custom_minimum_size = Vector2(ROW_LABEL_W, 0)
	pts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pts.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(pts)
	var i := int(row.index)
	for kind in ["free", "vip"]:
		var claimed := bool(row[kind + "_claimed"])
		var claimable := bool(row[kind + "_claimable"])
		var rt := RewardText.text(row[kind])
		var b := ThemeKit.make_button(tr("weekly_claimed") if claimed else rt, "primary" if claimable else "secondary")
		b.custom_minimum_size = Vector2(ROW_CELL_W, 96)
		b.add_theme_font_size_override("font_size", ThemeKit.FS_SMALL - 2)
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
