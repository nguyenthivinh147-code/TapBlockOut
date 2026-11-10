extends Control
## Popup quà 28 ngày: chỉ mở khi người chơi bấm. Hiện 7 ô của tuần đang đi.
## setup(args: Dictionary); signal closed(result) với result = {claimed: bool, ahead: bool}.
## No Unity prefab (docs/UI_UNITY.md): PopupOkLayer frame. Each day is a copy of ProfileLayer's frame cell
## (Profile_FrameCells: swirl, orange frame, green Select glow for today, Lock veil and Equipped tick for a claimed
## day) holding PopupRewardLayer's ItemReward per reward. The buttons are
## DailyRewardAdLayer's ClaimFreeBtn and WatchAdsBtn. Frame, texts and buttons are nodes of scenes/popup_daily.tscn;
## the day cells are built from Game.daily_view().

signal closed(result: Variant)

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const LbKit := preload("res://src/ui/lb_kit.gd")
const Config := preload("res://src/config.gd")
const RewardFly := preload("res://src/ui/reward_fly.gd")

const CELLS := "Profile_FrameCells"
## Every cell is the pink card of the shop packs (UI_Shop_Packs_Atlas1_0: pink well above, pink band below) sliced
## so the band stays PINK_BAND tall; the day name sits in the band, the rewards in the well. Today gets the green
## outline (the sliced outline of PopupOkLayer's well family) tinted with the colour sampled from Select.
const PINK := "UI_Shop_Packs_Atlas1:UI_Shop_Packs_Atlas1_0"
## Card inside the 512x312 sprite (without the soft shadow) and its 9-slice border in texture px: l, t, r, b.
const PINK_REGION := Rect2(8, 8, 496, 298)
const PINK_BORDER := Vector4(40, 40, 40, 100)
const PINK_SCALE := 0.55
const PINK_BAND := 55.0
const PINK_TOP := 22.0
const FRAME_WIDE := "Resources_UI_Maincenter:UI_Maincenter_23"
const WIDE_TODAY := "18f418ff"
## RewardItemSO gold icon; the TV of the video buttons marks the day a video can claim ahead.
const GOLD_ICON := "Resources_moved_UI_Maincenter:UI_Maincenter_3"
const VIDEO_ICON := "Resources_moved_UI_Maincenter:UI_Maincenter_5"
## Text colours on the dark purple PopupDailyRewardAd panel: normal and error.
const TEXT := "ffffffff"
const WARN := "ff8aa0ff"

## Layout in Unity canvas units from the panel's top-left corner (popup frame, 800 wide).
const COLS := 3
## Three pink cards fill a row of the frame; they are tall enough for a whole ItemReward (icon + quantity) above the band.
const CELL := Vector2(216, 250)
## Rows sit closer than columns, and the big-gift row is shorter, so the grid keeps the height of the old square cells.
const ROW_GAP := 24.0
const WIDE_H := 220.0
## PopupRewardLayer/Panel/Content: GridLayoutGroup spacing 32, cell 148.
const GAP := 24.0
const ITEM := 148.0
const ITEM_SCALE := 1.0
const GRID := Vector2(52, 200)

var claim_button: Button = null
var video_button: Button = null
var close_button: Button = null
var status_label: Label = null
var cell_nodes: Array[Control] = []
var claimed_any: bool = false
var ahead_any: bool = false
## Unity view of the frame (UnityKit.frame).
var ui: RefCounted = null

var _busy: bool = false
var _content: Control = null
var _info: Label = null


func setup(_args: Dictionary = {}) -> void:
	if _content == null:
		_build()


func _ready() -> void:
	if _content == null:
		_build()


## Frame, week line, status, buttons and info line are nodes of scenes/popup_daily.tscn; the day cells follow the
## week and are built in _refresh.
func _build() -> void:
	_content = %Layer
	ui = UnityKit.frame(_content, tr("daily_title"), close)
	close_button = ui.button("Panel/Top/btnTurnOff")
	close_button.name = "CloseButton"
	status_label = %StatusLabel
	UnityUI.set_text(status_label, "")
	claim_button = %ClaimButton
	UnityUI.set_text(claim_button.get_node("Out"), tr("daily_claim"))
	claim_button.connect("clicked", _on_claim)
	video_button = %VideoButton
	UnityUI.set_text(video_button.get_node("Out"), tr("daily_video"))
	video_button.connect("clicked", _on_video)
	_info = %InfoLabel
	_refresh()


## Week line, the 7 day cells (rebuilt in place, between the week line and the status) and the buttons.
func _refresh() -> void:
	var view: Dictionary = Game.daily_view()
	var week: Label = %WeekLabel
	UnityUI.set_text(week, tr("daily_week") % (int(view.week) + 1))
	for c in cell_nodes:
		c.get_parent().remove_child(c)
		c.queue_free()
	cell_nodes.clear()
	var panel: Control = ui.node("Panel/Content")
	var cells: Array = view.cells
	for i in cells.size():
		var col := i % COLS
		@warning_ignore("integer_division")
		var row := i / COLS
		var rect := Rect2(GRID.x + (CELL.x + GAP) * col, GRID.y + (CELL.y + ROW_GAP) * row, CELL.x, CELL.y)
		# The last day is the week's big gift: a whole row of its own.
		if i == cells.size() - 1:
			rect = Rect2(GRID.x, GRID.y + (CELL.y + ROW_GAP) * ceili(float(i) / COLS), CELL.x * COLS + GAP * (COLS - 1), WIDE_H)
		var card := _make_cell(panel, cells[i], rect, _can_ahead(view, cells[i]))
		panel.move_child(card, week.get_index() + 1 + i)
		cell_nodes.append(card)
	_refresh_buttons(view)


## Ô có thể nhận trước bằng video: ô "next" khi hôm nay đã nhận và video còn lượt.
func _can_ahead(view: Dictionary, cell: Dictionary) -> bool:
	return str(cell.state) == "next" and bool(view.can_ad_next) and bool(view.open)


func _make_cell(panel: Control, cell: Dictionary, rect: Rect2, ahead: bool) -> Control:
	var state := str(cell.state)
	var today := state == "current"
	var s := UnityKit.spec(CELLS, "")
	s.n = "Cell%d" % int(cell.day)
	s.erase("tog")
	s.erase("cs")
	var kids: Dictionary = {}
	for c in s.ch:
		kids[str(c.n)] = c
	# Select (green outline) marks today; Lock's dark veil and Equipped's tick mark a claimed day.
	kids.Image.a = false
	kids.Select.img.sp = FRAME_WIDE
	kids.Select.img.t = 1
	kids.Select.img.ppu = 0.85
	kids.Select.img.c = WIDE_TODAY
	kids.Select.a = today
	kids.Lock.ch = [kids.Lock.ch[0]]
	kids.Lock.a = state == "claimed"
	kids.Equipped.a = state == "claimed"
	var card: Control = UnityKit.add(panel, s, rect).root
	card.set_meta("state", state)
	_pink(card.get_node("FrameImage"), Color.WHITE)
	_pink(card.get_node("Lock"), Color(0, 0, 0, 0.55))
	card.get_node("Lock/Image").visible = false
	var day := UnityKit.label(card, tr("daily_day") % int(cell.day), Rect2(0, rect.size.y - PINK_BAND, rect.size.x, PINK_BAND - 6),
		40, "ffffffff", "Baloo Outline - Purple")
	day.name = "Day"
	_rewards(card, cell.reward, rect.size)
	# Veil and tick above the rewards, like the Profile cell's Lock and Equipped.
	for n in ["Lock", "Equipped"]:
		card.move_child(card.get_node(n), -1)
	# The tick sits in the card's top-right corner, clear of the day name in the band.
	UnityKit.place(card.get_node("Equipped"), Rect2(rect.size.x - 66.0, 6.0, 60.0, 60.0))
	if ahead:
		UnityKit.sprite(card, VIDEO_ICON, Rect2(rect.size.x - 62, -14, 76, 76)).name = "Video"
	return card


## Sliced pink card of the shop packs on a built Image node, tinted with `tint`.
func _pink(node: Control, tint: Color) -> void:
	var info := UnityUI.sprite_info(PINK)
	var k := float((info.region as Rect2).size.x) / 512.0
	var img: Control = UnityUI.image_of(node)
	img.set("kind", 1)
	img.set("color", tint)
	img.call("set_texture", info.tex, Rect2(PINK_REGION.position * k, PINK_REGION.size * k), PINK_BORDER * k, PINK_SCALE / k)


## PopupRewardLayer's ItemReward (icon 117.6, quantity 48) per reward, in a row on that layer's grid spacing.
func _rewards(card: Control, reward: Dictionary, size: Vector2) -> void:
	var list: Array = []
	var coins := int(reward.get("coins", 0))
	if coins > 0:
		list.append([GOLD_ICON, null, LbKit.fmt_int(coins), "gold"])
	var items: Dictionary = reward.get("items", {})
	for k in ["hint", "move", "smash"]:
		if items.has(k):
			list.append(["", ThemeKit.icon("booster_" + k), tr("booster_count") % int(items[k]), k])
	# RewardFly part -> icon, for the flight when the day is claimed.
	var icons := {}
	card.set_meta("icons", icons)
	var well := size.y - PINK_TOP - PINK_BAND
	var box: Control = UnityKit.add(card, {"n": "Rewards", "a": true, "r": [0, 1, 0, 1, 0, 0, size.x, well, 0.5, 0.5]},
		Rect2(0, PINK_TOP, size.x, well)).root
	var k := minf(ITEM_SCALE, (size.x - 16.0) / maxf(1.0, (ITEM + GAP) * list.size() - GAP))
	k = minf(k, well / ITEM)
	var step := (ITEM + GAP) * k
	var x0 := (size.x - step * list.size() + GAP * k) * 0.5
	for i in list.size():
		var s := UnityKit.spec("PopupRewardLayer", "Panel/Content/ItemReward")
		s.n = "Reward%d" % (i + 1)
		if list[i][0] != "":
			s.ch[0].img.sp = list[i][0]
		s.ch[0].img.pa = true
		# Quantity: purple outline like the day name (the prefab's black one reads harsh on the pink card).
		for c in s.ch:
			if str(c.n) == "Quantity":
				c.txt.mat = "Baloo Outline - Purple"
		var v := UnityKit.add(box, s, Rect2(x0 + step * i, (well - ITEM * k) * 0.5 - 8.0, ITEM, ITEM))
		v.root.scale = Vector2.ONE * k
		v.root.pivot_offset_ratio = Vector2.ZERO
		if list[i][1] != null:
			v.texture("Icon Item", list[i][1])
		v.text("Quantity", list[i][2])
		icons[list[i][3]] = v.node("Icon Item")


func _refresh_buttons(view: Dictionary) -> void:
	var is_open := bool(view.open)
	var can_claim := bool(view.can_claim)
	var can_next := bool(view.can_ad_next)
	claim_button.visible = is_open and can_claim
	claim_button.disabled = _busy
	video_button.visible = is_open and not can_claim and can_next
	video_button.disabled = _busy
	if video_button.visible:
		Game.offer_video("daily_next")
	if not is_open:
		UnityUI.set_text(_info, tr("common_locked_level") % int(Config.UNLOCK.get("daily_gift", 0)))
	elif can_claim:
		UnityUI.set_text(_info, "")
	elif can_next:
		UnityUI.set_text(_info, tr("daily_come_back"))
	else:
		UnityUI.set_text(_info, "%s\n%s" % [tr("daily_come_back"), tr("daily_video_used")])


func _fail_text() -> String:
	match Game.last_ad_reason:
		"not_ready", "offline":
			return ""  # Main đã báo bằng popup (Game.notice)
		"closed":
			return tr("ads_closed_early")
	return tr("ads_failed")


func _status(text: String, warn: bool = false) -> void:
	status_label.add_theme_color_override("font_color", Color(WARN if warn else TEXT))
	UnityUI.set_text(status_label, text)


func _on_claim() -> void:
	if _busy:
		return
	_busy = true
	var reward: Dictionary = Game.daily_claim()
	_busy = false
	if reward.is_empty():
		_status("")
	else:
		claimed_any = true
		_fly("current", reward)
		_status(tr("daily_reward_received"))
	_rebuild_keep_status()


func _on_video() -> void:
	if _busy:
		return
	_busy = true
	_refresh_buttons(Game.daily_view())
	var reward: Dictionary = await Game.daily_claim_next()
	_busy = false
	if not is_inside_tree():
		return
	if reward.is_empty():
		_status(_fail_text(), true)
		_refresh_buttons(Game.daily_view())
		return
	claimed_any = true
	ahead_any = true
	_fly("next", reward)
	_status(tr("daily_reward_received"))
	_rebuild_keep_status()


## The claimed day's rewards fly from its cell (cell state `state` before the claim) to their counters; the coin
## sound plays here when nothing flies.
func _fly(state: String, reward: Dictionary) -> void:
	var icons := {}
	for c in cell_nodes:
		if str(c.get_meta("state", "")) == state:
			icons = c.get_meta("icons", {})
	if RewardFly.launch(self, reward, icons) == 0:
		Sfx.play("sfx_coin")


func _rebuild_keep_status() -> void:
	_refresh()


## The frame's X and dim (prefab buttons play their own click sound).
func close() -> void:
	closed.emit({"claimed": claimed_any, "ahead": ahead_any})
