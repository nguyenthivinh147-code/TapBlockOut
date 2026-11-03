extends Control
## Màn Home. Chỉ đọc Game; không tự mở popup. Điều hướng qua closed({"action": ...}):
## play, no_lives, profile, gift, shop, ranking, settings, challenge, offer (kèm "id"),
## preview (kèm "scene": màn đã dựng UI, chưa nối logic; chỉ hiện khi Config.ui_preview).

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Unlocks := preload("res://src/meta/unlocks.gd")
const Config := preload("res://src/config.gd")
const UiAtlas := preload("res://src/ui/ui_atlas.gd")
const HubTop := preload("res://src/ui/hub_top.gd")
const HubNav := preload("res://src/ui/hub_nav.gd")

var gold_label: Label = null
var lives_panel: Control = null
var lives_label: Label = null
var lives_timer_label: Label = null
var profile_btn: Button = null
var play_btn: Button = null
var hard_tag: Label = null
var gift_btn: Button = null
var gift_badge: Control = null
var shop_btn: Button = null
var shop_caption: Label = null
var sale_btn: Button = null
var settings_btn: Button = null
var challenge_btn: Button = null
var offer_chip: Button = null
var coming_soon_label: Label = null
var weekly_btn: Button = null
var weekly_caption: Label = null
var weekly_dot: Control = null
var chain_btn: Button = null
var chain_dot: Control = null
var special_btn: Button = null
var _path_box: Control = null
var _next_node: TextureRect = null
var _next_num: Label = null
var _next_cap: Label = null
var _cur_node: TextureRect = null
var _cur_num: Label = null
var _cur_cap: Label = null
var _prev_node: TextureRect = null
var _prev_num: Label = null
var _prev_cap: Label = null

var _args: Dictionary = {}
var _built: bool = false
var _tick: Timer = null
var _offer_id: String = ""
var _top: HubTop = null
var _nav: HubNav = null
var _gift_col: Control = null
var _sale_col: Control = null
var _weekly_col: Control = null
var _chain_col: Control = null
var _special_col: Control = null
var _special_id: String = ""


## 75 -> "1:15", 3725 -> "1:02:05", từ 1 ngày: "1d 3h".
static func fmt_time(sec: int) -> String:
	return HubTop.fmt_time(sec)


func _ready() -> void:
	_build()
	_connect_game()
	refresh()


func _exit_tree() -> void:
	for sig in [Game.coins_changed, Game.lives_changed, Game.cos_changed, Game.inv_changed, Game.offer_ready]:
		if (sig as Signal).is_connected(_on_game_changed):
			(sig as Signal).disconnect(_on_game_changed)


func setup(args: Dictionary) -> void:
	_args = args
	_build()
	_connect_game()
	refresh()


func _connect_game() -> void:
	for sig in [Game.coins_changed, Game.lives_changed, Game.cos_changed, Game.inv_changed, Game.offer_ready]:
		if not (sig as Signal).is_connected(_on_game_changed):
			(sig as Signal).connect(_on_game_changed)


func _on_game_changed(_v: Variant = null) -> void:
	refresh()


## Chấm đỏ thông báo ở góc trên phải của nút.
func _make_dot(btn: Button, node_name: String) -> Control:
	var dot := Panel.new()
	dot.name = node_name
	dot.custom_minimum_size = Vector2(32, 32)
	dot.size = Vector2(32, 32)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := StyleBoxFlat.new()
	bs.bg_color = ThemeKit.DANGER
	bs.set_corner_radius_all(16)
	bs.set_border_width_all(3)
	bs.border_color = ThemeKit.TEXT
	dot.add_theme_stylebox_override("panel", bs)
	btn.add_child(dot)
	dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dot.offset_left = -26
	dot.offset_right = 6
	dot.offset_top = -6
	dot.offset_bottom = 26
	dot.visible = false
	return dot


func _icon_button(icon_name: String, caption: String) -> Array:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var b := ThemeKit.make_button("", "icon")
	b.icon = ThemeKit.icon(icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(104, 104)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(b)
	var l := ThemeKit.make_label(caption, ThemeKit.FS_SMALL - 4, ThemeKit.TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 130
	col.add_child(l)
	return [col, b, l]


## Mốc trên đường level: sprite + số ở giữa, chữ chú thích bên dưới. Trả [mốc, nhãn số, nhãn chú thích].
func _path_node(parent: Control, node_name: String, top: float, px: float) -> Array:
	var n := TextureRect.new()
	n.name = node_name
	n.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	n.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.set_anchors_preset(Control.PRESET_CENTER_TOP)
	n.offset_left = -px * 0.5
	n.offset_right = px * 0.5
	n.offset_top = top
	n.offset_bottom = top + px
	parent.add_child(n)
	var num := ThemeKit.make_label("", int(px * 0.3))
	num.set_anchors_preset(Control.PRESET_FULL_RECT)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.add_child(num)
	var cap := ThemeKit.make_label("", ThemeKit.FS_SMALL - 4, ThemeKit.TEXT_DIM)
	cap.set_anchors_preset(Control.PRESET_CENTER_TOP)
	cap.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cap.offset_top = top + px - 6
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cap)
	return [n, num, cap]


func _build() -> void:
	if _built:
		return
	_built = true
	theme = ThemeKit.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ThemeKit.make_background())

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 16)
	root.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)

	# hàng trên: avatar, mạng, vàng, settings
	_top = HubTop.new()
	_top.action.connect(_emit)
	col.add_child(_top)
	profile_btn = _top.profile_btn
	lives_panel = _top.lives_panel
	lives_label = _top.lives_label
	lives_timer_label = _top.lives_timer_label
	gold_label = _top.gold_label
	settings_btn = _top.settings_btn

	# giữa: quà bên trái, đường level ở giữa, ưu đãi bên phải
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 8)
	col.add_child(mid)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(130, 0)
	left.add_theme_constant_override("separation", 12)
	mid.add_child(left)
	var gf := _icon_button("ui_gift", tr("home_gift"))
	_gift_col = gf[0]
	gift_btn = gf[1]
	gift_btn.name = "GiftButton"
	gift_btn.pressed.connect(_emit.bind("gift"))
	left.add_child(gf[0])
	gift_badge = Panel.new()
	gift_badge.name = "GiftBadge"
	gift_badge.custom_minimum_size = Vector2(32, 32)
	gift_badge.size = Vector2(32, 32)
	gift_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := StyleBoxFlat.new()
	bs.bg_color = ThemeKit.DANGER
	bs.set_corner_radius_all(16)
	bs.set_border_width_all(3)
	bs.border_color = ThemeKit.TEXT
	gift_badge.add_theme_stylebox_override("panel", bs)
	gift_btn.add_child(gift_badge)
	gift_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gift_badge.offset_left = -26
	gift_badge.offset_right = 6
	gift_badge.offset_top = -6
	gift_badge.offset_bottom = 26
	if Config.ui_preview():
		left.add_child(_preview_button("ui_video", tr("home_ads_daily"), "popup_ads_daily"))

	_path_box = Control.new()
	_path_box.name = "LevelPath"
	_path_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_path_box.custom_minimum_size = Vector2(0, 560)
	mid.add_child(_path_box)
	var line := ColorRect.new()
	line.color = ThemeKit.PATH_LINE
	line.set_anchors_preset(Control.PRESET_CENTER_TOP)
	line.offset_left = -9
	line.offset_right = 9
	line.offset_top = 40
	line.offset_bottom = 540
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_path_box.add_child(line)
	var pn := _path_node(_path_box, "NextNode", 0, 130)
	_next_node = pn[0]
	_next_num = pn[1]
	_next_cap = pn[2]
	var pc := _path_node(_path_box, "CurrentNode", 170, 210)
	_cur_node = pc[0]
	_cur_num = pc[1]
	_cur_cap = pc[2]
	var pp := _path_node(_path_box, "PrevNode", 410, 130)
	_prev_node = pp[0]
	_prev_num = pp[1]
	_prev_cap = pp[2]
	hard_tag = Label.new()
	hard_tag.name = "HardTag"
	hard_tag.add_theme_font_size_override("font_size", ThemeKit.FS_SMALL)
	hard_tag.add_theme_color_override("font_color", ThemeKit.TEXT)
	hard_tag.add_theme_color_override("font_outline_color", ThemeKit.TEXT_OUTLINE)
	hard_tag.add_theme_constant_override("outline_size", 6)
	var tag_box := StyleBoxFlat.new()
	tag_box.set_corner_radius_all(18)
	tag_box.content_margin_left = 28
	tag_box.content_margin_right = 28
	tag_box.content_margin_top = 2
	tag_box.content_margin_bottom = 2
	hard_tag.add_theme_stylebox_override("normal", tag_box)
	hard_tag.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hard_tag.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hard_tag.offset_top = 150
	hard_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hard_tag.visible = false
	_path_box.add_child(hard_tag)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(130, 0)
	right.add_theme_constant_override("separation", 12)
	mid.add_child(right)
	var sl := _icon_button("ui_shop", tr("home_weekend_sale"))
	_sale_col = sl[0]
	sale_btn = sl[1]
	sale_btn.name = "WeekendSaleButton"
	sale_btn.pressed.connect(_emit.bind("shop"))
	sl[2].add_theme_color_override("font_color", ThemeKit.GOLD)
	right.add_child(sl[0])
	# sự kiện: Weekly Pass, Chain Offer, Special Pack (ẩn khi chưa đủ điều kiện)
	var wk := _icon_button("ui_gold", tr("home_weekly"))
	_weekly_col = wk[0]
	weekly_btn = wk[1]
	weekly_caption = wk[2]
	weekly_btn.name = "WeeklyPassButton"
	weekly_btn.pressed.connect(_emit.bind("weekly"))
	weekly_dot = _make_dot(weekly_btn, "WeeklyDot")
	right.add_child(wk[0])
	var ch := _icon_button("ui_gift", tr("home_chain"))
	_chain_col = ch[0]
	chain_btn = ch[1]
	chain_btn.name = "ChainOfferButton"
	chain_btn.pressed.connect(_emit.bind("chain"))
	chain_dot = _make_dot(chain_btn, "ChainDot")
	right.add_child(ch[0])
	var sp := _icon_button("shop_special_pack", tr("home_special_pack"))
	_special_col = sp[0]
	special_btn = sp[1]
	special_btn.name = "SpecialPackButton"
	special_btn.pressed.connect(_on_special)
	sp[2].add_theme_color_override("font_color", ThemeKit.GOLD)
	right.add_child(sp[0])
	if Config.ui_preview():
		right.add_child(_preview_button("ui_noads", tr("shop_remove_ads"), "popup_remove_ads"))
		right.add_child(_preview_button("ui_star", tr("streak_title"), "streak_main"))

	# nút Chơi
	play_btn = ThemeKit.make_button("", "primary", "lg")
	play_btn.name = "PlayButton"
	play_btn.custom_minimum_size = Vector2(520, 150)
	play_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_btn.add_theme_font_size_override("font_size", 46)
	play_btn.pressed.connect(_on_play)
	col.add_child(play_btn)
	coming_soon_label = ThemeKit.make_label(tr("home_coming_soon"), ThemeKit.FS_BODY, ThemeKit.TEXT_DIM)
	coming_soon_label.name = "ComingSoonLabel"
	coming_soon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(coming_soon_label)

	challenge_btn = ThemeKit.make_button("", "secondary")
	challenge_btn.name = "ChallengeButton"
	challenge_btn.add_theme_font_size_override("font_size", ThemeKit.FS_BODY - 4)
	challenge_btn.pressed.connect(_on_challenge)
	col.add_child(challenge_btn)
	offer_chip = ThemeKit.make_button("", "video")
	offer_chip.name = "OfferChip"
	offer_chip.add_theme_font_size_override("font_size", ThemeKit.FS_BODY - 4)
	offer_chip.pressed.connect(_on_offer)
	col.add_child(offer_chip)

	# thanh điều hướng: Shop · Home · Ranking
	_nav = HubNav.new("home")
	_nav.tab.connect(_on_tab)
	root.add_child(_nav)
	shop_btn = _nav.shop_btn
	shop_caption = _nav.shop_caption

	_tick = Timer.new()
	_tick.wait_time = 1.0
	_tick.one_shot = false
	_tick.timeout.connect(_refresh_timers)
	add_child(_tick)
	_tick.start()


## Đường level: mốc kế (khoá), mốc hiện tại (xanh, hard thì tím/đỏ), mốc vừa qua.
func _refresh_path(level: int) -> void:
	var tier := Game.difficulty_of(level) if Game.level_exists(level) else ""
	_cur_node.texture = UiAtlas.tex("hex_red" if tier == "very_hard" else ("hex_purple" if tier == "hard" else "node_green"))
	_cur_num.text = str(level)
	_cur_cap.text = ""
	_next_node.texture = UiAtlas.tex("node_gray")
	_next_num.text = str(level + 1)
	_next_cap.text = tr("home_path_locked")
	_prev_node.visible = level > 1
	_prev_num.text = str(level - 1)
	_prev_cap.visible = level > 1
	_prev_cap.text = tr("home_path_cleared")
	_prev_node.texture = UiAtlas.tex("node_gray")


func refresh() -> void:
	if not _built:
		return
	var level := int(Game.s.level)
	_top.refresh()
	_nav.refresh()

	_refresh_path(level)

	# nút Chơi
	var ended := not Game.level_exists(level)
	coming_soon_label.visible = ended
	if ended:
		play_btn.text = tr("home_play")
		play_btn.disabled = true
		hard_tag.visible = false
	else:
		play_btn.text = "%s\n%s" % [tr("home_play"), tr("home_play_level") % level]
		play_btn.disabled = false
		var tier := Game.difficulty_of(level)
		hard_tag.visible = tier != ""
		if tier != "":
			hard_tag.text = tr("level_very_hard") if tier == "very_hard" else tr("level_hard")
			var tag_box := hard_tag.get_theme_stylebox("normal") as StyleBoxFlat
			tag_box.bg_color = ThemeKit.HARD_BANNER_VERY if tier == "very_hard" else ThemeKit.HARD_BANNER

	# quà
	var daily: Dictionary = Game.daily_view()
	_gift_col.visible = bool(daily.get("open", false))
	gift_badge.visible = bool(daily.get("badge", false))

	# weekend sale: chỉ hiện khi sale bật và Shop đã mở
	_sale_col.visible = Unlocks.is_open("shop", level) and Game.is_sale_active()

	# challenge
	var ch: Dictionary = Game.challenge_view()
	var ch_open := bool(ch.get("open", false))
	challenge_btn.disabled = not ch_open
	challenge_btn.text = tr("home_challenge") if ch_open else tr("home_challenge_locked") % int(ch.get("unlock_level", Config.UNLOCK.challenge))
	challenge_btn.icon = null if ch_open else ThemeKit.icon("ui_lock")
	challenge_btn.expand_icon = true

	_refresh_timers()


## Weekly Pass, Chain Offer, Special Pack: hiện/ẩn theo điều kiện. Gọi cả mỗi giây vì hết hạn theo giờ.
func _refresh_events() -> void:
	if not _built:
		return
	var wv: Dictionary = Game.weekly_view()
	_weekly_col.visible = bool(wv.unlocked)
	if bool(wv.unlocked):
		var badge := int(wv.badge)
		weekly_caption.text = tr("home_weekly") if badge <= 0 else "%s (%d)" % [tr("home_weekly"), badge]
		weekly_dot.visible = bool(wv.dot) or badge > 0
	var cv: Dictionary = Game.chain_view()
	_chain_col.visible = not cv.is_empty()
	chain_dot.visible = not cv.is_empty() and int(cv.step) < int(cv.count)
	_special_id = Game.special_pack_id()
	_special_col.visible = _special_id != ""


## Đếm hồi mạng và hạn offer; gọi mỗi giây.
func _refresh_timers() -> void:
	if not _built:
		return
	_refresh_events()
	var offers: Array = Game.offers_open()
	if offers.is_empty():
		offer_chip.visible = false
		_offer_id = ""
	else:
		var o: Dictionary = offers[0]
		_offer_id = str(o.id)
		offer_chip.visible = true
		var left := fmt_time(int(o.until) - Game.now())
		offer_chip.text = "%s - %s" % [tr("offer_%s_title" % _offer_id), tr("home_offer_left") % left]


func _emit(action: String) -> void:
	Sfx.play("button")
	closed.emit({"action": action})


## Daily Challenge: chỉ phát closed; Main chuyển sang màn challenge.
func _on_challenge() -> void:
	if not bool(Game.challenge_view().get("open", false)):
		return
	_emit("challenge")


## Tab dưới: Home đang ở đây nên không làm gì.
func _on_tab(tab_name: String) -> void:
	match tab_name:
		"shop":
			_emit("shop")
		"ranking":
			_emit("ranking")


## Nút mở một màn chưa nối logic (chỉ dựng khi Config.ui_preview).
func _preview_button(icon_name: String, caption: String, scene: String) -> Control:
	var res := _icon_button(icon_name, caption)
	(res[1] as Button).pressed.connect(func() -> void:
		Sfx.play("button")
		closed.emit({"action": "preview", "scene": scene}))
	return res[0]


func _on_play() -> void:
	Sfx.play("button")
	if bool(Game.lives_view().get("can_play", true)):
		closed.emit({"action": "play"})
	else:
		closed.emit({"action": "no_lives"})


func _on_special() -> void:
	Sfx.play("button")
	if _special_id != "":
		closed.emit({"action": "offer", "id": _special_id})


func _on_offer() -> void:
	Sfx.play("button")
	if _offer_id != "":
		closed.emit({"action": "offer", "id": _offer_id})
