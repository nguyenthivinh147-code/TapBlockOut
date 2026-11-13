extends Control
## Layer Weekly Pass. Active: Main Tree (free + VIP), Bonus Bank, mua VIP. Waiting: đếm ngược.
## Popup cuối mùa (nếu có) hiện trước. setup(args); signal closed({}).
## No Unity prefab (docs/UI_UNITY.md): PopupOkLayer frame dressed in PopupFlashPack's art (Popup_FlashPack 9-sliced
## as the panel, Popup_FlashPack_Title as the header) with copies of PopupWinStreakMain (time pill, "!" button,
## scroll frame with the vertical track and milestone diamonds, Claim pill), DailyRewardAdLayer (progress slider,
## reward items, claimed tick) and PopupRewardLayer's grid numbers for the Bonus Bank. The frame and every fixed piece
## of the pass are nodes of scenes/weekly_pass.tscn; a message (Locked, Waiting, end of season) is the frame resized
## with the pass hidden. Milestone rows and the bank are built from Game.weekly_view().

signal closed(result: Variant)

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const LbKit := preload("res://src/ui/lb_kit.gd")
const RewardText := preload("res://src/ui/reward_text.gd")
const UScroll := preload("res://src/ui/u_scroll.gd")
const WeeklyPass := preload("res://src/meta/weekly_pass.gd")
const Config := preload("res://src/config.gd")
const RewardFly := preload("res://src/ui/reward_fly.gd")
const TutorialScene := preload("res://scenes/weekly_pass_tutorial.tscn")
const HOWTO_SCENE := "res://scenes/popup_weekly_tutorial.tscn"

const TUTORIAL_DELAY := 0.45  # DialogueReveal (0.4 s) xong thì lỗ spotlight mới khớp vị trí thật

const STREAK := "PopupWinStreakMain"
const DAILY_AD := "DailyRewardAdLayer"
const STREAK_CONTENT := "Panel/Image#3/Scroll View/Viewport/Content"
const STREAK_MILESTONE := STREAK_CONTENT + "/Progress/MilestoneContainer/Milestone"
const DAILY_MILESTONE := "Panel/Content/Preview/Bottom/Slider/MilestonesParent/Milestone/ScaleMilestone/ChildScaleMilestone"
## Milestone diamonds (ImageStateKeeper of Milestone/Level): 0 not reached, 1 the milestone reached last, 2 passed.
const DIAMOND := "UI_Winstreak_Atlas:UI_Winstreak_Atlas_14"
## Main Tree cards: the shop pack frames of UI_Shop_Packs_Atlas (340x304 px), pink for free, yellow for VIP. Icons and
## amounts sit on the cream panel (CARD_CREAM_PX), the Claim pill on the coloured band below it.
const CARD_FREE := "UI_Shop_Packs_Atlas:UI_Shop_Packs_Atlas_8"
const CARD_VIP := "UI_Shop_Packs_Atlas:UI_Shop_Packs_Atlas_9"
const CARD_PX := Vector2(340, 304)
const CARD_CREAM_PX := Rect2(16, 17, 306, 169)
## Quantity of a Main Tree reward moved this much further down than the prefab's, under its icon.
const AMOUNT_DROP := 18.0
const LOCK := "Resources_moved_UI_Maincenter:UI_Maincenter_18"
## RewardItemSO icons: gold (RewardType 1) and unlimited lives (RewardType 5).
const GOLD_ICON := "Resources_moved_UI_Maincenter:UI_Maincenter_3"
const INF_ICON := "Resources_moved_UI_Maincenter:UI_Maincenter_16"
## Time text colour of PopupWinStreakMain/Panel/Time, used for the purchase error.
const WARN := "ec304fff"

## Layout in Unity canvas units from the panel's top-left corner.
const PANEL := Vector2(800, 1688)
## The pass panel sits this much below the canvas center so the Popup_FlashPack_Title ribbon above it stays on
## screen; a message is centered.
const PANEL_DROP := 84.0
## PopupOkLayer's well and button row sit 60 higher in the scene (above Popup_FlashPack's bottom band), so the
## message is 60 taller than the prefab's 660 to keep the well's size.
const MESSAGE := Vector2(724, 720)
const LIST := Rect2(55, 370, 690, 940)
## UI_EWStreakProgress.milestoneSpacingY was 200; the cards keep CARD_PX's aspect at the FreeTab / VipTab width (280),
## so a row is that tall plus a 20 gap.
const ROW_STEP := 270.0
const LIST_PAD := 10.0
const TRACK_X := 54.0
const CELL := Vector2(280, 250)
const FREE_X := 110.0
const VIP_X := 400.0
## PopupRewardLayer/Panel/Content grid: cell 148, spacing 32.
const BANK_CELL := 148.0
const BANK_SP := 32.0
const BANK_COLS := 4
## Above Popup_FlashPack's bottom band (the cream ends 114 units above the panel's bottom).
const BOTTOM_Y := 1430.0
const BUTTON := Vector2(330, 120)

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
## Unity view of the frame (UnityKit.frame).
var ui: RefCounted = null

var _content: Control = null
var _scroll: UScroll = null  # ScrollRect of the reward list while the pass is shown
var _list_scroll: UScroll = null
var _list: Control = null  # content of the reward list
var _slider: RefCounted = null  # view of the progress slider
var _time_label: Label = null
var _waiting_label: Label = null  # countdown to 06:00 while Waiting
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
	_bind()
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
	if _waiting_label != null and is_instance_valid(_waiting_label):
		UnityUI.set_text(_waiting_label, _waiting_text(int(Game.weekly_view().seconds_left)))
		return
	if _time_label == null or not is_instance_valid(_time_label):
		return
	UnityUI.set_text(_time_label, _time_text(int(Game.weekly_view().seconds_left)))


static func fmt_time(sec: int) -> String:
	sec = maxi(sec, 0)
	if sec >= 86400:
		@warning_ignore("integer_division")
		return "%dd %dh" % [sec / 86400, (sec % 86400) / 3600]
	@warning_ignore("integer_division")
	return "%d:%02d:%02d" % [sec / 3600, (sec % 3600) / 60, sec % 60]


func _time_text(sec: int) -> String:
	return tr("weekly_time_left") % fmt_time(sec)


func _waiting_text(sec: int) -> String:
	return "%s\n%s" % [tr("weekly_waiting_title"), tr("weekly_waiting_body") % fmt_time(sec)]


## Wires the frame and the pass's nodes of scenes/weekly_pass.tscn once; _rebuild shows the state in them.
func _bind() -> void:
	_content = %Layer
	ui = UnityKit.frame(_content, tr("weekly_title"), close)
	close_button = ui.button("Panel/Top/btnTurnOff")
	close_button.name = "CloseButton"
	ui.on_click("Panel/Content/Button/Ok", _on_message_ok)
	%InfoButton.connect("clicked", open_howto)
	%KeyButton.connect("clicked", open_howto)
	%BuyVipButton.connect("clicked", _on_buy_vip)
	%ClaimAllButton.connect("clicked", _on_claim_all)
	# The slider sits under the ProgressBar (not a Unity node), which the frame's view does not walk into.
	_slider = UnityUI.adopt(%Slider, ui.get("canvas"))
	var list: RefCounted = ui.sub(%List)
	_list_scroll = list.node("Scroll View").get_node("ScrollRect")
	_list = list.node("Scroll View/Viewport/Content")


func _rebuild() -> void:
	var keep_y := 0.0
	if _scroll != null and is_instance_valid(_scroll) and _scroll.content != null:
		keep_y = (_scroll.content as Control).position.y
	_stop_tutorial()
	main_buttons = {}
	bank_buttons = []
	buy_vip_button = null
	claim_all_button = null
	info_button = null
	key_button = null
	progress_row = null
	_scroll = null
	_time_label = null
	_waiting_label = null
	view = Game.weekly_view()
	# Milestone rows and the bank follow the season; out of the tree now so the new ones keep their names.
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()

	var active := end_info.is_empty() and str(view.state) == WeeklyPass.ACTIVE
	_show_layout(active)
	if not end_info.is_empty():
		_show_end()
	elif active:
		_show_active()
		_restore_scroll(keep_y)
	elif str(view.state) == WeeklyPass.WAITING:
		_show_message(tr("weekly_title"), _waiting_text(int(view.seconds_left)), "WaitingLabel")
		_waiting_label = _content.find_child("WaitingLabel", true, false) as Label
	else:
		_show_message(tr("weekly_title"), tr("weekly_locked"), "LockedLabel")
	_auto_tutorial.call_deferred()


## The frame holds the pass (PANEL, PopupOkLayer's description, well and button row hidden) or a message
## (PopupOkLayer as it is, MESSAGE).
func _show_layout(active: bool) -> void:
	for p in ["Panel/Content/Description", "Panel/Content/Image", "Panel/Content/Button"]:
		ui.show(p, not active)
	# The button row is laid out as the prefab's (Cancel and Ok at the message size), then with Ok alone for a
	# message; the pass hides it.
	ui.show("Panel/Content/Button/Cancel")
	_panel_size(MESSAGE)
	ui.relayout("Panel/Content/Button")
	if active:
		_panel_size(PANEL)
	else:
		ui.show("Panel/Content/Button/Cancel", false)
		ui.relayout("Panel/Content/Button")
	ui.node("Panel/Content/Description").name = "Description"
	ui.node("Panel/Content/Button/Ok").name = "Ok"
	for n: Control in [%Time, %ProgressRow, %FreeTab, %VipTab, %List, %VipLabel, %BuyVipButton, %VipHint, %ToastLabel,
			%ClaimAllButton]:
		n.visible = active


func _panel_size(size: Vector2) -> void:
	var panel: Control = ui.node("Panel")
	(panel.get_meta("u_rect") as Dictionary).pos = Vector2(0, -PANEL_DROP if size == PANEL else 0.0)
	UnityKit.set_size(panel, size)
	var bg: Control = ui.node("Panel/Bg")
	UnityKit.set_size(bg, size)
	# Popup_FlashPack is sliced at the panel's width, so its borders keep their proportions at both sizes.
	bg.set("border_scale", size.x / (bg.get("region") as Rect2).size.x)


## PopupOkLayer as it is: header, description on the cream well, one Ok button.
func _show_message(title: String, body: String, node_name: String) -> void:
	ui.text("Panel/Image/txtHeader", title)
	ui.text("Panel/Content/Description", body).name = node_name
	ui.text("Panel/Content/Button/Ok/Out", tr("common_ok"))


func _show_end() -> void:
	var msg: String
	if bool(end_info.get("vip", false)):
		var rt := RewardText.text({"coins": int(end_info.get("coins", 0)), "items": end_info.get("items", {}),
			"inf_min": int(end_info.get("inf_min", 0))})
		msg = tr("weekly_end_vip") % (rt if rt != "" else "-")
	else:
		msg = tr("weekly_end_free") % int(end_info.get("points", 0))
	_show_message(tr("weekly_end_title"), msg, "EndLabel")
	ui.button("Panel/Content/Button/Ok").name = "EndOkButton"


## Ok of the end-of-season popup opens the pass; Ok of the other messages closes the layer.
func _on_message_ok() -> void:
	if end_info.is_empty():
		close()
		return
	end_info = {}
	_rebuild()


func _show_active() -> void:
	ui.text("Panel/Image/txtHeader", tr("weekly_title"))
	# PopupWinStreakMain/Panel/Time, widened for "6d 3h left".
	_time_label = %TimeLabel
	UnityUI.set_text(_time_label, _time_text(int(view.seconds_left)))
	_show_progress()
	# Column heads over the list on the same star cards as the cells.
	UnityUI.set_text(%FreeTab.get_node("Text"), tr("weekly_free"))
	UnityUI.set_text(%VipTab.get_node("Text"), tr("weekly_vip"))
	_fill_list()
	_show_bottom()


## Hàng tiến độ: nút "i", chìa (bấm để xem cách kiếm thưởng), thanh tới mốc kế và số key.
## Đây cũng là target của bước 3 trong tutorial.
func _show_progress() -> void:
	progress_row = %ProgressRow
	info_button = %InfoButton
	key_button = %KeyButton
	# Tests read the ratio from a ProgressBar; it draws nothing, the DailyRewardAdLayer slider inside it does.
	(%ProgressBar as ProgressBar).value = float(view.progress)
	_slider.slider("", float(view.progress))
	UnityUI.set_text(%KeysLabel, tr("weekly_keys") % [int(view.points), int(view.last_points)])


## PopupWinStreakMain/Panel/Image#3 (cream frame, ScrollRect, sky viewport) is in the scene. The cat tower inside it
## is replaced by the pass: the vertical track with one diamond per milestone, free and VIP cards beside it.
func _fill_list() -> void:
	_scroll = _list_scroll
	_scroll.velocity = Vector2.ZERO
	var rows: Array = view.main
	var n := rows.size()
	_build_track(_list, rows)
	for r in rows:
		_build_row(_list, r)
	var y := LIST_PAD + ROW_STEP * n
	y = _build_bank(_list, y + 10.0)
	# Also puts the content back at the top, as a new list would be.
	UnityKit.set_size(_list, Vector2(0, y + 30.0))
	# Cards are added after the ScrollRect was set up: let drags that start on them reach it.
	for b in _list.find_children("*", "Button", true, false):
		(b as Control).mouse_filter = Control.MOUSE_FILTER_PASS


func _row_center(i: int) -> float:
	return LIST_PAD + ROW_STEP * (float(i) + 0.5)


## Milestone/Progress (ImageSlider, vertical fill) from the first to the last diamond, filled up to the key count.
func _build_track(list: Control, rows: Array) -> void:
	var s := UnityKit.spec(STREAK, STREAK_CONTENT + "/Progress")
	s.ch = [s.ch[0]]
	s.erase("cs")
	var top := _row_center(0)
	var span := _row_center(rows.size() - 1) - top
	var v := UnityKit.add(list, s, Rect2(TRACK_X - 15.0, top, 30, span))
	var fill: Control = v.image("Image")
	fill.set("fill_origin", 1)  # the pass runs top-down, Unity's tower bottom-up
	var pts := int(view.points)
	var at := 0.0
	for i in range(rows.size() - 1):
		var a := int(rows[i].points)
		var b := int(rows[i + 1].points)
		if pts >= b:
			at = float(i + 1)
		elif pts > a:
			at = float(i) + float(pts - a) / float(maxi(1, b - a))
			break
		else:
			break
	fill.call("set_fill", at / float(maxi(1, rows.size() - 1)))


func _build_row(list: Control, row: Dictionary) -> void:
	var i := int(row.index)
	var cy := _row_center(i)
	var d := UnityKit.add(list, UnityKit.spec(STREAK, STREAK_MILESTONE + "/Level"), Rect2(TRACK_X - 40.0, cy - 40.0, 80, 80))
	d.root.name = "Milestone%d" % i
	d.text("Text (TMP)", str(int(row.points)))
	var pts := int(view.points)
	var state := 0
	if pts >= int(row.points):
		var last := i + 1 >= (view.main as Array).size() or pts < int(view.main[i + 1].points)
		state = 1 if last else 2
	_diamond(d.image(""), state)
	for kind in ["free", "vip"]:
		var b := _reward_card(list, kind, row, Rect2(FREE_X if kind == "free" else VIP_X, cy - CELL.y * 0.5, CELL.x, CELL.y))
		b.connect("clicked", _on_claim.bind(kind, i))
		main_buttons["%s_%d" % [kind, i]] = b


## ImageStateKeeper sprites of Milestone/Level (UI_Winstreak_Atlas_16 / _14 / _15) are not exported, only _14
## (the prefab default); they sit next to it in the atlas, 80 px apart.
func _diamond(img: Control, state: int) -> void:
	var si := UnityUI.sprite_info(DIAMOND)
	if si.is_empty() or img == null:
		return
	var r: Rect2 = si.region
	var k := r.size.x / 76.0
	r.position.x += [160.0, 0.0, 80.0][state] * k
	img.call("set_texture", si.tex, r, Vector4.ZERO, float(si.scale))


## Card button (PopupOkLayer Ok without its text) on a star card; the state shows as Claim pill, tick or lock.
func _card(parent: Control, sprite: String, n: String, rect: Rect2) -> Button:
	var s := UnityKit.spec("PopupOkLayer", "Panel/Content/Button/Ok")
	s.n = n
	s.img.sp = sprite
	s.img.t = 1
	s.img.pa = false
	s.img.ppu = 1
	s.ch = []
	# Locked and claimed cards keep their colours.
	s.btn.c[3] = s.btn.c[0]
	return UnityKit.add(parent, s, rect).root as Button


func _reward_card(list: Control, kind: String, row: Dictionary, rect: Rect2) -> Button:
	var claimed := bool(row[kind + "_claimed"])
	var claimable := bool(row[kind + "_claimable"])
	var b := _card(list, CARD_FREE if kind == "free" else CARD_VIP, "%s%d" % [kind.capitalize(), int(row.index)], rect)
	_rewards(b, row[kind], _cream(rect.size).grow(-6.0), true)
	_state(b, rect.size, claimed, claimable, kind == "vip" and not bool(view.vip))
	b.disabled = not claimable
	return b


## The frame's cream panel in a card of this size.
func _cream(size: Vector2) -> Rect2:
	var k := size / CARD_PX
	return Rect2(CARD_CREAM_PX.position * k, CARD_CREAM_PX.size * k)


## RewardsParent of DailyRewardAdLayer's milestone: one ItemReward (icon + quantity) per reward, laid out in a row,
## scaled (up to 1.2) to the width of `box` and centred in it. main (Main Tree card): the quantity sits under its
## icon (AMOUNT_DROP) and the height of `box` limits the scale too.
func _rewards(card: Control, reward: Dictionary, box: Rect2, main: bool) -> void:
	var s := UnityKit.spec(DAILY_AD, DAILY_MILESTONE + "/RewardsParent")
	var item: Dictionary = s.ch[1]
	s.ch = []
	if main:
		s.r[7] = float(s.r[7]) + AMOUNT_DROP
		item.ch[1].r[5] = float(item.ch[1].r[5]) - AMOUNT_DROP
	var icons: Array = []
	var coins := int(reward.get("coins", 0))
	if coins > 0:
		icons.append([GOLD_ICON, null, LbKit.fmt_int(coins), "gold"])
	var items: Dictionary = reward.get("items", {})
	for k in RewardText.BOOSTER_ORDER:
		if int(items.get(k, 0)) > 0:
			icons.append(["", ThemeKit.icon("booster_" + k), tr("booster_count") % int(items[k]), k])
	if int(reward.get("inf_min", 0)) > 0:
		icons.append([INF_ICON, null, tr("weekly_reward_min") % int(reward.inf_min), "inf"])
	# RewardFly part -> icon, for the flight when the card is claimed.
	var fly := {}
	card.set_meta("icons", fly)
	for e in icons:
		var it: Dictionary = item.duplicate(true)
		it.ch[0].img.sp = e[0] if e[0] != "" else null
		it.ch[0].img.pa = true
		it.ch[1].txt.s = e[2]
		s.ch.append(it)
	var v := UnityKit.add(card, s)
	var paths: Array = v.paths.keys()
	var n := 0
	for p in paths:
		if str(p).begins_with("ItemReward") and not str(p).contains("/"):
			var tex: Variant = icons[n][1]
			if tex != null:
				v.texture(str(p) + "/Icon Item", tex)
			fly[icons[n][3]] = v.node(str(p) + "/Icon Item")
			n += 1
	var w := float((v.root.get_meta("u_rect") as Dictionary).size.x)
	var h := float((v.root.get_meta("u_rect") as Dictionary).size.y)
	var k := minf(1.2, box.size.x / maxf(1.0, w))
	if main:
		k = minf(k, box.size.y / maxf(1.0, h))
	# The pivot is the bottom centre: scaling grows the row upwards and keeps it centred across.
	var top := box.position.y + maxf(0.0, (box.size.y - h * k) * 0.5)
	UnityKit.place(v.root, Rect2(box.position.x + (box.size.x - w) * 0.5, top + (h * k - h), w, h))
	v.root.scale = Vector2(k, k)
	UnityUI.relayout(v.root)


## Claimed: veil and tick; claimable: Claim pill centred on the frame's coloured band; VIP not bought: lock.
func _state(card: Control, size: Vector2, claimed: bool, claimable: bool, locked: bool) -> void:
	if claimed:
		# ObjTick of DailyRewardAdLayer's milestone: dark veil and the green tick.
		var s := UnityKit.spec(DAILY_AD, DAILY_MILESTONE + "/ObjTick")
		s.r = [0, 0, 1, 1, 0, 0, 0, 0, 0.5, 0.5]
		s.ch[0].r = [0, 0, 1, 1, 0, 0, -8, -8, 0.5, 0.5]
		s.ch[1].r = [0.5, 0.5, 0.5, 0.5, 0, 0, 85, 85, 0.5, 0.5]
		UnityKit.add(card, s).root.name = "Claimed"
	elif claimable:
		# The band runs from the cream panel to the frame's bottom outline (about 6 units).
		_claim_pill(card, Vector2(size.x * 0.5, (_cream(size).end.y + size.y - 6.0) * 0.5), 1.0)
	elif locked:
		UnityKit.sprite(card, LOCK, Rect2(size.x - 58.0, 4, 54, 54)).name = "Lock"


## ClaimBtn of PopupWinStreakMain's milestone as art only, centred on `at`: the whole card is the button.
func _claim_pill(card: Control, at: Vector2, k: float) -> void:
	var s := UnityKit.spec(STREAK, STREAK_MILESTONE + "/ Info/ClaimBtn")
	s.erase("btn")
	s.n = "Claim"
	s.ch[0].txt.s = tr("weekly_claim")
	var v := UnityKit.add(card, s, Rect2(at.x - 80.0, at.y - 30.0, 160, 60))
	v.root.scale = Vector2(k, k)


func _build_bank(list: Control, y: float) -> float:
	UnityKit.label(list, tr("weekly_bank_title"), Rect2(20, y, LIST.size.x - 40.0, 60), 48, "ffffffff", "Baloo Outline - Purple")
	y += 60.0
	if not bool(view.bank_unlocked):
		UnityKit.label(list, tr("weekly_bank_locked"), Rect2(30, y, LIST.size.x - 60.0, 110), 34)
		return y + 110.0
	UnityKit.label(list, tr("weekly_bank_step") % int(Config.WEEKLY.get("bank_step", 15)), Rect2(30, y, LIST.size.x - 60.0, 44), 34)
	y += 54.0
	var x0 := (LIST.size.x - (BANK_CELL * BANK_COLS + BANK_SP * (BANK_COLS - 1))) * 0.5
	var bank: Array = view.bank
	for i in bank.size():
		var b: Dictionary = bank[i]
		@warning_ignore("integer_division")
		var rect := Rect2(x0 + (BANK_CELL + BANK_SP) * (i % BANK_COLS), y + (BANK_CELL + BANK_SP) * (i / BANK_COLS), BANK_CELL, BANK_CELL)
		var btn := _card(list, UnityKit.WELL, "Bank%d" % int(b.index), rect)
		var room := rect.size.y - (66.0 if bool(b.claimable) else 20.0)
		_rewards(btn, {"coins": int(b.coins)}, Rect2(10, 0, rect.size.x - 20.0, room), false)
		if bool(b.claimed):
			_state(btn, rect.size, true, false, false)
		elif bool(b.claimable):
			_claim_pill(btn, Vector2(rect.size.x * 0.5, rect.size.y - 36.0), 0.8)
		elif not bool(b.reached):
			UnityKit.sprite(btn, LOCK, Rect2(BANK_CELL - 50.0, 4, 46, 46)).name = "Lock"
		btn.disabled = not bool(b.claimable)
		btn.connect("clicked", _on_claim_bank.bind(int(b.index)))
		bank_buttons.append(btn)
	@warning_ignore("integer_division")
	var lines := (bank.size() + BANK_COLS - 1) / BANK_COLS
	return y + BANK_CELL * lines + BANK_SP * maxi(0, lines - 1)


## VIP hint (or VIP state), purchase error, then the button row of PopupOkLayer: Buy VIP and Claim all.
func _show_bottom() -> void:
	var line := Rect2(60, BOTTOM_Y - 108.0, PANEL.x - 120.0, 96)
	var vip := bool(view.vip)
	var vip_label: Label = %VipLabel
	vip_label.visible = vip
	UnityUI.set_text(vip_label, "%s - %s" % [tr("weekly_vip_active"), tr("weekly_vip_hearts") % int(view.bonus_hearts)])
	var buy: Button = %BuyVipButton
	buy.visible = not vip
	buy.disabled = false
	UnityUI.set_text(buy.get_node("Out"), tr("weekly_buy_vip") % str(view.vip_price))
	if not vip:
		buy_vip_button = buy
	var hint: Label = %VipHint
	hint.visible = not vip and toast_text == ""
	UnityUI.set_text(hint, tr("weekly_vip_hint") + " " + tr("weekly_vip_hearts") % int(view.bonus_hearts))
	var toast: Label = %ToastLabel
	toast.visible = toast_text != ""
	UnityKit.place(toast, line if not vip else Rect2(line.position.x, line.position.y - 60.0, line.size.x, 60))
	UnityUI.set_text(toast, toast_text)
	var x := PANEL.x * 0.5 + 20.0 if not vip else (PANEL.x - BUTTON.x) * 0.5
	claim_all_button = %ClaimAllButton
	UnityKit.place(claim_all_button, Rect2(x, BOTTOM_Y, BUTTON.x, BUTTON.y))
	UnityUI.set_text(claim_all_button.get_node("Out"), tr("weekly_claim_all"))
	claim_all_button.call("set_interactable", int(view.badge) > 0)


func _restore_scroll(y: float) -> void:
	if _scroll == null or y == 0.0:
		return
	var content: Control = _scroll.content
	var vp: Control = _scroll.viewport
	_scroll.set_content_position(Vector2(content.position.x, clampf(y, minf(0.0, vp.size.y - content.size.y), 0.0)))


## ScrollRect has no ensure_visible: move the content so the card is inside the viewport.
func _scroll_to(c: Control) -> void:
	if _scroll == null or c == null:
		return
	var content: Control = _scroll.content
	var vp: Control = _scroll.viewport
	var top := c.position.y - LIST_PAD
	var bottom := c.position.y + c.size.y + LIST_PAD
	var y := content.position.y
	if top + y < 0.0:
		y = -top
	elif bottom + y > vp.size.y:
		y = vp.size.y - bottom
	_scroll.set_content_position(Vector2(content.position.x, clampf(y, minf(0.0, vp.size.y - content.size.y), 0.0)))


# --- tutorial ---

## Mở layer lần đầu (Active, chưa xem tutorial): chờ DialogueReveal xong rồi chạy tutorial.
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
	_scroll_to(free_btn)
	var first_text := tr("weekly_tut_free_claim") if bool(view.main[row].free_claimable) else tr("weekly_tut_free_earn")
	tutorial = TutorialScene.instantiate() as Control
	tutorial.name = "Tutorial"
	add_child(tutorial)
	tutorial.finished.connect(_on_tutorial_finished)
	tutorial.setup([
		{"target": free_btn, "text": first_text},
		{"target": vip_btn, "text": tr("weekly_tut_vip")},
		{"target": progress_row, "text": tr("weekly_tut_progress")},
	])
	return true


## Main: Back không làm gì khi overlay tutorial đang chạy (design.md mục 2 "Back Android và ESC", mục 7).
func blocks_back() -> bool:
	return tutorial != null and is_instance_valid(tutorial)


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


func _on_claim(kind: String, i: int) -> void:
	if _busy or _closed:
		return
	var card: Control = main_buttons.get("%s_%d" % [kind, i])
	_fly(Game.weekly_claim_free(i) if kind == "free" else Game.weekly_claim_vip(i), [card])
	_rebuild()


func _on_claim_bank(i: int) -> void:
	if _busy or _closed:
		return
	var cards: Array = bank_buttons.filter(func(b: Button) -> bool: return str(b.name) == "Bank%d" % i)
	_fly(Game.weekly_claim_bank(i), cards)
	_rebuild()


func _on_claim_all() -> void:
	if _busy or _closed:
		return
	var cards: Array = main_buttons.values() + bank_buttons
	_fly(Game.weekly_claim_all(), cards.filter(func(b: Variant) -> bool:
		return b is Button and is_instance_valid(b) and not (b as Button).disabled))
	_rebuild()


## Each part of a claimed reward flies to its counter from the first of `cards` showing it (before _rebuild frees
## them); the coin sound plays here when nothing flies.
func _fly(reward: Dictionary, cards: Array) -> void:
	if reward.is_empty():
		return
	var icons := {}
	for c: Variant in cards:
		if not (c is Control and is_instance_valid(c)):
			continue
		var m: Dictionary = (c as Control).get_meta("icons", {})
		for k: String in m:
			if not icons.has(k):
				icons[k] = m[k]
	if RewardFly.launch(self, reward, icons) == 0:
		Sfx.play("sfx_coin")


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
		"cancel", "offline":
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


## Android Back (Main): How to earn rewards over the pass closes first (a child of the pass, not a Main popup), then
## the pass (OQ-10, like Language over Settings).
func on_back() -> void:
	if howto != null and is_instance_valid(howto):
		howto.call("close")
	else:
		close()
