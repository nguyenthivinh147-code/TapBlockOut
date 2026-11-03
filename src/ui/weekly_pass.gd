extends Control
## Layer Weekly Pass. Active: Main Tree (free + VIP), Bonus Bank, mua VIP. Waiting: đếm ngược.
## Popup cuối mùa (nếu có) hiện trước. setup(args); signal closed({}).
## No Unity prefab (docs/UI_UNITY.md): PopupOkLayer frame through UnityKit, with copies of PopupWinStreakMain (time
## pill, "!" button, scroll frame with the vertical track and milestone diamonds, Claim pill), DailyRewardAdLayer
## (progress slider, reward items, claimed tick) and PopupRewardLayer's grid numbers for the Bonus Bank.

signal closed(result: Variant)

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const LbKit := preload("res://src/ui/lb_kit.gd")
const RewardText := preload("res://src/ui/reward_text.gd")
const UScroll := preload("res://src/ui/u_scroll.gd")
const WeeklyPass := preload("res://src/meta/weekly_pass.gd")
const Config := preload("res://src/config.gd")
const Tutorial := preload("res://src/ui/weekly_pass_tutorial.gd")
const HOWTO_SCENE := "res://scenes/popup_weekly_tutorial.tscn"

const TUTORIAL_DELAY := 0.45  # DialogueReveal (0.4 s) xong thì lỗ spotlight mới khớp vị trí thật

const STREAK := "PopupWinStreakMain"
const DAILY_AD := "DailyRewardAdLayer"
const STREAK_CONTENT := "Panel/Image#3/Scroll View/Viewport/Content"
const STREAK_MILESTONE := STREAK_CONTENT + "/Progress/MilestoneContainer/Milestone"
const DAILY_MILESTONE := "Panel/Content/Preview/Bottom/Slider/MilestonesParent/Milestone/ScaleMilestone/ChildScaleMilestone"
## Milestone diamonds (ImageStateKeeper of Milestone/Level): 0 not reached, 1 the milestone reached last, 2 passed.
const DIAMOND := "UI_Winstreak_Atlas:UI_Winstreak_Atlas_14"
const CARD_FREE := "Resources_moved_UI_Maincenter:UI_Maincenter_62"
const CARD_VIP := "Resources_moved_UI_Maincenter:UI_Maincenter_63"
const LOCK := "Resources_moved_UI_Maincenter:UI_Maincenter_18"
## RewardItemSO icons: gold (RewardType 1) and unlimited lives (RewardType 5).
const GOLD_ICON := "Resources_moved_UI_Maincenter:UI_Maincenter_3"
const INF_ICON := "Resources_moved_UI_Maincenter:UI_Maincenter_16"
## Time text colour of PopupWinStreakMain/Panel/Time, used for the purchase error.
const WARN := "ec304fff"

## Layout in Unity canvas units from the panel's top-left corner.
const PANEL := Vector2(800, 1688)
const MESSAGE := Vector2(724, 660)
const LIST := Rect2(55, 370, 690, 1010)
const TAB_H := 70.0
## UI_EWStreakProgress.milestoneSpacingY.
const ROW_STEP := 200.0
const LIST_PAD := 10.0
const TRACK_X := 54.0
const CELL := Vector2(280, 180)
const FREE_X := 110.0
const VIP_X := 400.0
## PopupRewardLayer/Panel/Content grid: cell 148, spacing 32.
const BANK_CELL := 148.0
const BANK_SP := 32.0
const BANK_COLS := 4
const BOTTOM_Y := 1500.0
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
## Unity view of the current frame (UnityKit.popup).
var ui: RefCounted = null

var _content: Control = null
var _scroll: UScroll = null  # ScrollRect of the reward list
var _time_label: Label = null
var _timer: Timer = null
var _busy: bool = false
var _closed: bool = false
var _tutorial_waiting: bool = false
var _built_once: bool = false


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


func _rebuild() -> void:
	var keep_y := 0.0
	if _scroll != null and is_instance_valid(_scroll) and _scroll.content != null:
		keep_y = (_scroll.content as Control).position.y
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
	_time_label = null
	view = Game.weekly_view()

	var root := Control.new()
	root.name = "Layer"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_content = root

	if not end_info.is_empty():
		_build_end(root)
	elif str(view.state) == WeeklyPass.ACTIVE:
		_build_active(root)
		_restore_scroll(keep_y)
	elif str(view.state) == WeeklyPass.WAITING:
		_build_message(root, tr("weekly_title"), "%s\n%s" % [tr("weekly_waiting_title"),
			tr("weekly_waiting_body") % fmt_time(int(view.seconds_left))], "WaitingLabel")
	else:
		_build_message(root, tr("weekly_title"), tr("weekly_locked"), "LockedLabel")
	if _built_once:
		_no_reveal(ui)
	_built_once = true
	_auto_tutorial.call_deferred()


## UnityKit.popup always plays DialogueReveal; a rebuild after a claim keeps the panel where it is.
func _no_reveal(v: RefCounted) -> void:
	var cfg: Dictionary = v.get("reveal_cfg")
	var panel: Variant = cfg.get("panel")
	var dim: Variant = cfg.get("dim")
	v.set("reveal_cfg", {})
	if panel is Control:
		(panel as Control).scale = Vector2.ONE
	if dim is Control:
		(dim as Control).modulate.a = 1.0


func _frame(root: Control, title: String, size: Vector2) -> Control:
	ui = UnityKit.popup(root, title, size, close)
	close_button = ui.button("Panel/Top/btnTurnOff")
	close_button.name = "CloseButton"
	return ui.node("Panel/Content")


## PopupOkLayer as it is: header, description on the cream well, one Ok button.
func _build_message(root: Control, title: String, body: String, node_name: String, on_ok: Callable = Callable()) -> void:
	_frame(root, title, MESSAGE)
	for p in ["Panel/Content/Description", "Panel/Content/Image", "Panel/Content/Button"]:
		ui.show(p)
	ui.show("Panel/Content/Button/Cancel", false)
	ui.text("Panel/Content/Description", body).name = node_name
	ui.text("Panel/Content/Button/Ok/Out", tr("common_ok"))
	ui.on_click("Panel/Content/Button/Ok", on_ok if on_ok.is_valid() else close)
	ui.relayout("Panel/Content/Button")


func _build_end(root: Control) -> void:
	var msg: String
	if bool(end_info.get("vip", false)):
		var rt := RewardText.text({"coins": int(end_info.get("coins", 0)), "items": end_info.get("items", {}),
			"inf_min": int(end_info.get("inf_min", 0))})
		msg = tr("weekly_end_vip") % (rt if rt != "" else "-")
	else:
		msg = tr("weekly_end_free") % int(end_info.get("points", 0))
	_build_message(root, tr("weekly_end_title"), msg, "EndLabel", func() -> void:
		end_info = {}
		_rebuild())
	ui.button("Panel/Content/Button/Ok").name = "EndOkButton"


func _build_active(root: Control) -> void:
	var panel := _frame(root, tr("weekly_title"), PANEL)
	_build_time(panel)
	_build_progress(panel)
	_build_tabs(panel)
	_build_list(panel)
	_build_bottom(panel)


## PopupWinStreakMain/Panel/Time, widened for "6d 3h left".
func _build_time(panel: Control) -> void:
	var s := UnityKit.spec(STREAK, "Panel/Time")
	s.ch = [s.ch[0], s.ch[1]]  # txtEnd is the "event ended" text, the layer closes instead
	(s.ch[1] as Dictionary).r[6] = 196.0
	var v := UnityKit.add(panel, s, Rect2(250, 96, 300, 68))
	_time_label = v.label("Text (TMP)")
	_time_label.name = "TimeLabel"
	UnityUI.set_text(_time_label, _time_text(int(view.seconds_left)))


## Hàng tiến độ: nút "i", chìa (bấm để xem cách kiếm thưởng), thanh tới mốc kế và số key.
## Đây cũng là target của bước 3 trong tutorial.
func _build_progress(panel: Control) -> Control:
	var row: Control = UnityKit.add(panel, {"n": "ProgressRow", "a": true, "r": [0, 1, 0, 1, 0, 0, 720, 100, 0.5, 0.5]},
		Rect2(40, 180, 720, 100)).root
	progress_row = row

	var info := UnityKit.spec(STREAK, "Panel/Button")
	info.n = "InfoButton"
	info_button = UnityKit.add(row, info, Rect2(0, 20, 60, 60)).root as Button
	info_button.connect("clicked", open_howto)

	var key := UnityKit.spec(STREAK, "Panel/Button")
	key.n = "KeyButton"
	key.img.pa = true
	var kv := UnityKit.add(row, key, Rect2(84, 5, 90, 90))
	kv.texture("", ThemeKit.icon("mech_key"))
	key_button = kv.root as Button
	key_button.connect("clicked", open_howto)

	# Tests read the ratio from a ProgressBar; it draws nothing, the DailyRewardAdLayer slider inside it does.
	var bar := ProgressBar.new()
	bar.name = "ProgressBar"
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.001  # mặc định 0.01 làm tròn tỉ lệ
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for st in ["background", "fill"]:
		bar.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	bar.position = Vector2(196, 18)
	bar.size = Vector2(524, 44.68)
	bar.value = float(view.progress)
	row.add_child(bar)
	var s := UnityKit.spec(DAILY_AD, "Panel/Content/Preview/Bottom/Slider")
	var kids: Array = []
	for c in s.ch:
		if str(c.n) in ["Background (2)", "Background (1)", "Fill Area"]:
			kids.append(c)
	s.ch = kids
	UnityKit.add(bar, s, Rect2(0, 0, 524, 44.68)).slider("", float(view.progress))

	var keys := UnityKit.label(row, tr("weekly_keys") % [int(view.points), int(view.last_points)], Rect2(196, 62, 524, 38), 32)
	keys.name = "KeysLabel"
	return row


## Column heads over the list on the same star cards as the cells.
func _build_tabs(panel: Control) -> void:
	for t in [[tr("weekly_free"), CARD_FREE, "Baloo Outline - Purple", FREE_X, "FreeTab"],
			[tr("weekly_vip"), CARD_VIP, "Baloo Outline - Orange", VIP_X, "VipTab"]]:
		var s := {"n": t[4], "a": true, "r": [0, 1, 0, 1, 0, 0, CELL.x, TAB_H, 0.5, 0.5],
			"img": {"sp": t[1], "c": "ffffffff", "t": 1, "pa": false, "fc": true, "ppu": 1}}
		var tab: Control = UnityKit.add(panel, s, Rect2(LIST.position.x + float(t[3]), LIST.position.y - TAB_H + 8, CELL.x, TAB_H)).root
		UnityKit.label(tab, t[0], Rect2(0, 4, CELL.x, TAB_H - 8), 40, "ffffffff", t[2])


## PopupWinStreakMain/Panel/Image#3: cream frame, ScrollRect and the sky viewport. The cat tower inside it is
## replaced by the pass: the vertical track with one diamond per milestone, free and VIP cards beside it.
func _build_list(panel: Control) -> void:
	var s := UnityKit.spec(STREAK, "Panel/Image#3")
	var viewport: Dictionary = s.ch[0].ch[0]
	var content: Dictionary = {}
	for c in viewport.ch:
		if str(c.n) == "Content":
			content = c
	content.erase("cs")
	content.ch = []
	viewport.ch = [content]
	s.n = "List"
	# Workaround: a Mask inside a Mask (clip_children twice) draws nothing below the inner one, so the sky
	# viewport clips as a RectMask2D and the frame's rounded Mask stays.
	viewport.erase("mask")
	viewport.rmask = {}
	var v := UnityKit.add(panel, s, LIST)
	_scroll = v.node("Scroll View").get_node("ScrollRect")
	var list: Control = v.node("Scroll View/Viewport/Content")

	var rows: Array = view.main
	var n := rows.size()
	_build_track(list, rows)
	for r in rows:
		_build_row(list, r)
	var y := LIST_PAD + ROW_STEP * n
	y = _build_bank(list, y + 10.0)
	UnityKit.set_size(list, Vector2(0, y + 30.0))
	# Cards are added after the ScrollRect was set up: let drags that start on them reach it.
	for b in list.find_children("*", "Button", true, false):
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
	_rewards(b, row[kind], rect.size, claimable)
	_state(b, rect.size, claimed, claimable, kind == "vip" and not bool(view.vip))
	b.disabled = not claimable
	return b


## RewardsParent of DailyRewardAdLayer's milestone: one ItemReward (icon + quantity) per reward, laid out in a row.
func _rewards(card: Control, reward: Dictionary, size: Vector2, pill: bool) -> void:
	var s := UnityKit.spec(DAILY_AD, DAILY_MILESTONE + "/RewardsParent")
	var item: Dictionary = s.ch[1]
	s.ch = []
	var icons: Array = []
	var coins := int(reward.get("coins", 0))
	if coins > 0:
		icons.append([GOLD_ICON, null, LbKit.fmt_int(coins)])
	var items: Dictionary = reward.get("items", {})
	for k in RewardText.BOOSTER_ORDER:
		if int(items.get(k, 0)) > 0:
			icons.append(["", ThemeKit.icon("booster_" + k), tr("booster_count") % int(items[k])])
	if int(reward.get("inf_min", 0)) > 0:
		icons.append([INF_ICON, null, tr("weekly_reward_min") % int(reward.inf_min)])
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
			n += 1
	var w := float((v.root.get_meta("u_rect") as Dictionary).size.x)
	var h := float((v.root.get_meta("u_rect") as Dictionary).size.y)
	var k := minf(1.2, (size.x - 20.0) / maxf(1.0, w))
	var room := size.y - (66.0 if pill else 20.0)
	UnityKit.place(v.root, Rect2((size.x - w) * 0.5, maxf(0.0, (room - h * k) * 0.5) + (h * k - h), w, h))
	v.root.scale = Vector2(k, k)
	UnityUI.relayout(v.root)


func _state(card: Control, size: Vector2, claimed: bool, claimable: bool, locked: bool) -> void:
	if claimed:
		# ObjTick of DailyRewardAdLayer's milestone: dark veil and the green tick.
		var s := UnityKit.spec(DAILY_AD, DAILY_MILESTONE + "/ObjTick")
		s.r = [0, 0, 1, 1, 0, 0, 0, 0, 0.5, 0.5]
		s.ch[0].r = [0, 0, 1, 1, 0, 0, -8, -8, 0.5, 0.5]
		s.ch[1].r = [0.5, 0.5, 0.5, 0.5, 0, 0, 85, 85, 0.5, 0.5]
		UnityKit.add(card, s).root.name = "Claimed"
	elif claimable:
		_claim_pill(card, size, 1.0)
	elif locked:
		UnityKit.sprite(card, LOCK, Rect2(size.x - 58.0, 4, 54, 54)).name = "Lock"


## ClaimBtn of PopupWinStreakMain's milestone as art only: the whole card is the button.
func _claim_pill(card: Control, size: Vector2, k: float) -> void:
	var s := UnityKit.spec(STREAK, STREAK_MILESTONE + "/ Info/ClaimBtn")
	s.erase("btn")
	s.n = "Claim"
	s.ch[0].txt.s = tr("weekly_claim")
	var v := UnityKit.add(card, s, Rect2((size.x - 160.0) * 0.5, size.y - 66.0, 160, 60))
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
		_rewards(btn, {"coins": int(b.coins)}, rect.size, bool(b.claimable))
		if bool(b.claimed):
			_state(btn, rect.size, true, false, false)
		elif bool(b.claimable):
			_claim_pill(btn, rect.size, 0.8)
		elif not bool(b.reached):
			UnityKit.sprite(btn, LOCK, Rect2(BANK_CELL - 50.0, 4, 46, 46)).name = "Lock"
		btn.disabled = not bool(b.claimable)
		btn.connect("clicked", _on_claim_bank.bind(int(b.index)))
		bank_buttons.append(btn)
	@warning_ignore("integer_division")
	var lines := (bank.size() + BANK_COLS - 1) / BANK_COLS
	return y + BANK_CELL * lines + BANK_SP * maxi(0, lines - 1)


## VIP hint (or VIP state), purchase error, then the button row of PopupOkLayer: Buy VIP and Claim all.
func _build_bottom(panel: Control) -> void:
	var line := Rect2(60, BOTTOM_Y - 108.0, PANEL.x - 120.0, 96)
	var vip := bool(view.vip)
	if vip:
		var l := UnityKit.label(panel, "%s - %s" % [tr("weekly_vip_active"), tr("weekly_vip_hearts") % int(view.bonus_hearts)], line, 36)
		l.name = "VipLabel"
	else:
		var price := UnityKit.button(panel, "yellow", tr("weekly_buy_vip") % str(view.vip_price),
			Rect2(PANEL.x * 0.5 - 20.0 - BUTTON.x, BOTTOM_Y, BUTTON.x, BUTTON.y), _on_buy_vip)
		buy_vip_button = price.root as Button
		buy_vip_button.name = "BuyVipButton"
		_text_inset(price.label("Out"), 28.0)
		if toast_text == "":
			UnityKit.label(panel, tr("weekly_vip_hint") + " " + tr("weekly_vip_hearts") % int(view.bonus_hearts), line, 30).name = "VipHint"
	if toast_text != "":
		var t := UnityKit.label(panel, toast_text, line if not vip else Rect2(line.position.x, line.position.y - 60.0, line.size.x, 60), 34, WARN)
		t.name = "ToastLabel"
	var x := PANEL.x * 0.5 + 20.0 if not vip else (PANEL.x - BUTTON.x) * 0.5
	var all := UnityKit.button(panel, "green", tr("weekly_claim_all"), Rect2(x, BOTTOM_Y, BUTTON.x, BUTTON.y), _on_claim_all)
	claim_all_button = all.root as Button
	claim_all_button.name = "ClaimAllButton"
	_text_inset(all.label("Out"), 28.0)
	claim_all_button.call("set_interactable", int(view.badge) > 0)


## Long button text stays off the pill's rounded ends (Ok/Out spans the whole button).
func _text_inset(l: Label, side: float) -> void:
	var r: Dictionary = l.get_meta("u_rect")
	r.size = Vector2(-2.0 * side, (r.size as Vector2).y)
	UnityUI.apply_rect(l)
	UnityUI.fit_text(l)


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
