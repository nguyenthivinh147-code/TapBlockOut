extends Control
## Màn Home. Chỉ đọc Game; không tự mở popup. Điều hướng qua closed({"action": ...}):
## play, no_lives, profile, gift, shop, settings, challenge, offer (kèm "id").

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Unlocks := preload("res://src/meta/unlocks.gd")
const Config := preload("res://src/config.gd")
const Profile := preload("res://src/ui/profile.gd")

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
var settings_btn: Button = null
var challenge_btn: Button = null
var offer_chip: Button = null
var coming_soon_label: Label = null

var _args: Dictionary = {}
var _built: bool = false
var _tick: Timer = null
var _offer_id: String = ""
var _avatar_holder: Control = null
var _gift_col: Control = null


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


func _icon_button(icon_name: String, caption: String) -> Array:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var b := ThemeKit.make_button("", "secondary")
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


func _build() -> void:
	if _built:
		return
	_built = true
	theme = ThemeKit.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ThemeKit.make_background())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	margin.add_child(col)

	# hàng trên: profile, vàng + mạng, settings
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	col.add_child(top)
	profile_btn = Button.new()
	profile_btn.name = "ProfileButton"
	profile_btn.flat = true
	profile_btn.focus_mode = Control.FOCUS_NONE
	profile_btn.custom_minimum_size = Vector2(144, 144)
	profile_btn.pressed.connect(_emit.bind("profile"))
	top.add_child(profile_btn)
	var chips := VBoxContainer.new()
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.add_theme_constant_override("separation", 8)
	top.add_child(chips)
	var gold_chip := ThemeKit.make_panel()
	chips.add_child(gold_chip)
	var gold_row := HBoxContainer.new()
	gold_row.add_theme_constant_override("separation", 10)
	gold_chip.add_child(gold_row)
	var gi := TextureRect.new()
	gi.texture = ThemeKit.icon("ui_gold")
	gi.custom_minimum_size = Vector2(44, 44)
	gi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gold_row.add_child(gi)
	gold_label = ThemeKit.make_label("0", ThemeKit.FS_BODY, ThemeKit.GOLD)
	gold_label.name = "GoldLabel"
	gold_row.add_child(gold_label)
	lives_panel = ThemeKit.make_panel()
	lives_panel.name = "LivesPanel"
	chips.add_child(lives_panel)
	var lv := VBoxContainer.new()
	lives_panel.add_child(lv)
	lives_label = ThemeKit.make_label("", ThemeKit.FS_BODY)
	lives_label.name = "LivesLabel"
	lv.add_child(lives_label)
	lives_timer_label = ThemeKit.make_label("", ThemeKit.FS_SMALL, ThemeKit.TEXT_DIM)
	lives_timer_label.name = "LivesTimerLabel"
	lv.add_child(lives_timer_label)
	var st := _icon_button("ui_settings", tr("home_settings"))
	settings_btn = st[1]
	settings_btn.name = "SettingsButton"
	settings_btn.pressed.connect(_emit.bind("settings"))
	top.add_child(st[0])

	# giữa: tên game, nút Chơi
	var mid := VBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 48)
	col.add_child(mid)
	var title := ThemeKit.make_label(tr("APP_NAME"), ThemeKit.FS_HUGE)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(title)
	play_btn = ThemeKit.make_button("", "primary")
	play_btn.name = "PlayButton"
	play_btn.custom_minimum_size = Vector2(520, 160)
	play_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_btn.add_theme_font_size_override("font_size", 48)
	play_btn.pressed.connect(_on_play)
	mid.add_child(play_btn)
	hard_tag = Label.new()
	hard_tag.name = "HardTag"
	hard_tag.add_theme_font_size_override("font_size", ThemeKit.FS_SMALL)
	hard_tag.add_theme_color_override("font_color", ThemeKit.TEXT)
	var tag_box := StyleBoxFlat.new()
	tag_box.set_corner_radius_all(18)
	tag_box.content_margin_left = 28
	tag_box.content_margin_right = 28
	tag_box.content_margin_top = 2
	tag_box.content_margin_bottom = 2
	hard_tag.add_theme_stylebox_override("normal", tag_box)
	hard_tag.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hard_tag.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hard_tag.offset_top = -22
	hard_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hard_tag.visible = false
	play_btn.add_child(hard_tag)
	coming_soon_label = ThemeKit.make_label(tr("home_coming_soon"), ThemeKit.FS_BODY, ThemeKit.TEXT_DIM)
	coming_soon_label.name = "ComingSoonLabel"
	coming_soon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(coming_soon_label)

	# dưới: quà, shop, challenge, offer
	var side := HBoxContainer.new()
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override("separation", 48)
	col.add_child(side)
	var gf := _icon_button("ui_gift", tr("home_gift"))
	_gift_col = gf[0]
	gift_btn = gf[1]
	gift_btn.name = "GiftButton"
	gift_btn.pressed.connect(_emit.bind("gift"))
	side.add_child(gf[0])
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
	var sh := _icon_button("ui_shop", tr("home_shop"))
	shop_btn = sh[1]
	shop_caption = sh[2]
	shop_btn.name = "ShopButton"
	shop_btn.pressed.connect(_emit.bind("shop"))
	side.add_child(sh[0])

	challenge_btn = ThemeKit.make_button("", "secondary")
	challenge_btn.name = "ChallengeButton"
	challenge_btn.add_theme_font_size_override("font_size", ThemeKit.FS_BODY)
	challenge_btn.pressed.connect(_on_challenge)
	col.add_child(challenge_btn)
	offer_chip = ThemeKit.make_button("", "video")
	offer_chip.name = "OfferChip"
	offer_chip.add_theme_font_size_override("font_size", ThemeKit.FS_BODY)
	offer_chip.pressed.connect(_on_offer)
	col.add_child(offer_chip)

	_tick = Timer.new()
	_tick.wait_time = 1.0
	_tick.one_shot = false
	_tick.timeout.connect(_refresh_timers)
	add_child(_tick)
	_tick.start()


func refresh() -> void:
	if not _built:
		return
	var level := int(Game.s.level)
	gold_label.text = str(int(Game.s.coins))

	# avatar và frame đang đeo
	if _avatar_holder != null:
		_avatar_holder.queue_free()
	var cosm: Dictionary = Game.s.cos
	_avatar_holder = Profile.make_avatar(str(cosm.get("avatar", "avatar_00")), str(cosm.get("frame", "frame_00")), 144)
	_avatar_holder.name = "AvatarView"
	profile_btn.add_child(_avatar_holder)

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

	# challenge
	var ch: Dictionary = Game.challenge_view()
	var ch_open := bool(ch.get("open", false))
	challenge_btn.disabled = not ch_open
	challenge_btn.text = tr("home_challenge") if ch_open else tr("home_challenge_locked") % int(ch.get("unlock_level", Config.UNLOCK.challenge))
	challenge_btn.icon = null if ch_open else ThemeKit.icon("ui_lock")
	challenge_btn.expand_icon = true

	_refresh_timers()


## Đếm hồi mạng và hạn offer; gọi mỗi giây.
func _refresh_timers() -> void:
	if not _built:
		return
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


func _on_play() -> void:
	Sfx.play("button")
	if bool(Game.lives_view().get("can_play", true)):
		closed.emit({"action": "play"})
	else:
		closed.emit({"action": "no_lives"})


func _on_offer() -> void:
	Sfx.play("button")
	if _offer_id != "":
		closed.emit({"action": "offer", "id": _offer_id})
