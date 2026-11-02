extends Control
## Màn Home. Chỉ đọc Game; không tự mở popup. Điều hướng qua closed({"action": ...}):
## play, no_lives, profile, gift, shop, settings, challenge, offer (kèm "id").

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Unlocks := preload("res://src/meta/unlocks.gd")
const Config := preload("res://src/config.gd")
const Profile := preload("res://src/ui/profile.gd")
const UiAtlas := preload("res://src/ui/ui_atlas.gd")

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
var _avatar_holder: Control = null
var _gift_col: Control = null
var _sale_col: Control = null
var _weekly_col: Control = null
var _chain_col: Control = null
var _special_col: Control = null
var _special_id: String = ""


## 75 -> "1:15", 3725 -> "1:02:05", từ 1 ngày: "1d 3h".
static func fmt_time(sec: int) -> String:
	sec = maxi(sec, 0)
	if sec >= 86400:
		@warning_ignore("integer_division")
		return "%dd %dh" % [sec / 86400, (sec % 86400) / 3600]
	if sec >= 3600:
		@warning_ignore("integer_division")
		return "%d:%02d:%02d" % [sec / 3600, (sec % 3600) / 60, sec % 60]
	@warning_ignore("integer_division")
	return "%d:%02d" % [sec / 60, sec % 60]


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
	b.custom_minimum_size = Vector2(112, 112)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(b)
	var l := ThemeKit.make_label(caption, ThemeKit.FS_SMALL, ThemeKit.TEXT_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	return [col, b, l]


## Chip tiền tệ: panel + icon + chữ. Trả [panel, hộp ngang để thêm chữ/nút].
func _chip(icon_name: String, icon_px: int) -> Array:
	var chip := ThemeKit.make_panel()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	chip.add_child(row)
	var ic := TextureRect.new()
	ic.texture = ThemeKit.icon(icon_name)
	ic.custom_minimum_size = Vector2(icon_px, icon_px)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	return [chip, row]


## Nút "+" nhỏ cuối chip.
func _plus_button(node_name: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.icon = ThemeKit.icon("ui_plus")
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(52, 52)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(action)
	return b


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


## Tab thanh dưới: nút (icon) + chú thích. Trả [cột, nút, nhãn].
func _nav_tab(icon_name: String, caption: String, kind: String) -> Array:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	var b := ThemeKit.make_button("", kind)
	b.icon = ThemeKit.icon(icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(0, 104)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(b)
	var l := ThemeKit.make_label(caption, ThemeKit.FS_SMALL - 2, ThemeKit.TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	return [col, b, l]


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
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	profile_btn = Button.new()
	profile_btn.name = "ProfileButton"
	profile_btn.flat = true
	profile_btn.focus_mode = Control.FOCUS_NONE
	profile_btn.custom_minimum_size = Vector2(112, 112)
	profile_btn.pressed.connect(_emit.bind("profile"))
	top.add_child(profile_btn)
	var lives_chip := _chip("ui_heart", 48)
	lives_panel = lives_chip[0]
	lives_panel.name = "LivesPanel"
	top.add_child(lives_panel)
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", -4)
	(lives_chip[1] as HBoxContainer).add_child(lv)
	lives_label = ThemeKit.make_label("", ThemeKit.FS_SMALL + 2)
	lives_label.name = "LivesLabel"
	lv.add_child(lives_label)
	lives_timer_label = ThemeKit.make_label("", ThemeKit.FS_SMALL - 6, ThemeKit.TEXT_DIM)
	lives_timer_label.name = "LivesTimerLabel"
	lv.add_child(lives_timer_label)
	(lives_chip[1] as HBoxContainer).add_child(_plus_button("LivesPlus", _on_lives_plus))
	var gold_chip := _chip("ui_gold", 48)
	top.add_child(gold_chip[0])
	gold_label = ThemeKit.make_label("0", ThemeKit.FS_SMALL + 4, ThemeKit.GOLD)
	gold_label.name = "GoldLabel"
	gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(gold_chip[1] as HBoxContainer).add_child(gold_label)
	(gold_chip[1] as HBoxContainer).add_child(_plus_button("GoldPlus", _emit.bind("shop")))
	settings_btn = ThemeKit.make_button("", "icon")
	settings_btn.name = "SettingsButton"
	settings_btn.icon = ThemeKit.icon("ui_settings")
	settings_btn.expand_icon = true
	settings_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_btn.custom_minimum_size = Vector2(88, 88)
	settings_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	settings_btn.pressed.connect(_emit.bind("settings"))
	top.add_child(settings_btn)

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

	_path_box = Control.new()
	_path_box.name = "LevelPath"
	_path_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_path_box.custom_minimum_size = Vector2(0, 560)
	mid.add_child(_path_box)
	var line := ColorRect.new()
	line.color = Color("20417B")
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

	# nút Chơi
	play_btn = ThemeKit.make_button("", "primary")
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
	var nav := PanelContainer.new()
	nav.name = "NavBar"
	var nav_box := StyleBoxFlat.new()
	nav_box.bg_color = ThemeKit.NAV_TOP
	nav_box.corner_radius_top_left = 36
	nav_box.corner_radius_top_right = 36
	nav_box.border_width_top = 4
	nav_box.border_color = ThemeKit.NAV_BOTTOM
	nav_box.content_margin_left = 24
	nav_box.content_margin_right = 24
	nav_box.content_margin_top = 14
	nav_box.content_margin_bottom = 18
	nav.add_theme_stylebox_override("panel", nav_box)
	root.add_child(nav)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 16)
	nav.add_child(tabs)
	var sh := _nav_tab("ui_shop", tr("home_shop"), "video")
	shop_btn = sh[1]
	shop_caption = sh[2]
	shop_btn.name = "ShopButton"
	shop_btn.pressed.connect(_emit.bind("shop"))
	tabs.add_child(sh[0])
	var hm := _nav_tab("ui_home", tr("home_home"), "gold")
	hm[1].name = "HomeTab"
	tabs.add_child(hm[0])
	var rk := _nav_tab("ui_leaderboard", tr("home_ranking_soon"), "video")
	rk[1].name = "RankingTab"
	rk[1].disabled = true
	tabs.add_child(rk[0])

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
	gold_label.text = str(int(Game.s.coins))

	# avatar và frame đang đeo
	if _avatar_holder != null:
		_avatar_holder.queue_free()
	var cosm: Dictionary = Game.s.cos
	_avatar_holder = Profile.make_avatar(str(cosm.get("avatar", "avatar_00")), str(cosm.get("frame", "frame_00")), 112)
	_avatar_holder.name = "AvatarView"
	profile_btn.add_child(_avatar_holder)

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

	# shop
	var shop_open := Unlocks.is_open("shop", level)
	shop_btn.disabled = not shop_open
	shop_btn.icon = ThemeKit.icon("ui_shop" if shop_open else "ui_lock")
	shop_caption.text = tr("home_shop") if shop_open else tr("home_shop_locked") % int(Config.UNLOCK.shop)

	# weekend sale: chỉ hiện khi sale bật và Shop đã mở
	_sale_col.visible = shop_open and Game.is_sale_active()

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
	var lv: Dictionary = Game.lives_view()
	var show_lives := bool(lv.get("open", false))
	lives_panel.visible = show_lives
	if show_lives:
		lives_label.text = tr("no_lives_lives") % [int(lv.count), int(lv.max)]
		var wait := int(lv.get("seconds_to_next", 0))
		lives_timer_label.text = tr("home_lives_full") if wait <= 0 else tr("home_lives_next") % fmt_time(wait)
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


## Dấu + cạnh mạng: sang màn hết mạng khi chưa đầy.
func _on_lives_plus() -> void:
	var lv: Dictionary = Game.lives_view()
	if bool(lv.get("infinite", false)) or int(lv.get("count", 0)) >= int(lv.get("max", 0)):
		return
	Sfx.play("button")
	closed.emit({"action": "no_lives"})


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
