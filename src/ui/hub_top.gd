extends HBoxContainer
## Thanh trên dùng chung Home, Shop, Leaderboard (wireframe 2.1): avatar, mạng, vàng, settings.
## Tự nghe Game và tự đếm hồi mạng. Bấm nút phát action("profile" | "no_lives" | "shop" | "settings").

signal action(action_name: String)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Profile := preload("res://src/ui/profile.gd")

const AVATAR_PX := 104
const CHIP_ICON := 44
const SIGNALS := ["coins_changed", "lives_changed", "cos_changed", "inv_changed"]

var profile_btn: Button = null
var lives_panel: Control = null
var lives_label: Label = null
var lives_timer_label: Label = null
var gold_label: Label = null
var settings_btn: Button = null

var _avatar: Control = null


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


func _init() -> void:
	name = "HubTop"
	add_theme_constant_override("separation", 10)

	profile_btn = Button.new()
	profile_btn.name = "ProfileButton"
	profile_btn.flat = true
	profile_btn.focus_mode = Control.FOCUS_NONE
	profile_btn.custom_minimum_size = Vector2(AVATAR_PX, AVATAR_PX)
	profile_btn.pressed.connect(_fire.bind("profile"))
	add_child(profile_btn)

	var lives_cell := _chip_cell("LivesPlus", _on_lives_plus)
	lives_cell.name = "LivesPanel"
	lives_cell.size_flags_stretch_ratio = 1.15
	lives_panel = lives_cell
	add_child(lives_cell)
	var lives_col: VBoxContainer = lives_cell.get_child(0)
	var lives_chip := _chip("ui_heart")
	lives_col.add_child(lives_chip[0])
	lives_label = ThemeKit.make_label("", ThemeKit.FS_SMALL + 2)
	lives_label.name = "LivesLabel"
	lives_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	(lives_chip[1] as HBoxContainer).add_child(lives_label)
	(lives_chip[1] as HBoxContainer).add_child(ThemeKit.make_icon("ui_plus", CHIP_ICON))
	lives_timer_label = ThemeKit.make_label("", ThemeKit.FS_SMALL - 6, ThemeKit.TEXT_DIM)
	lives_timer_label.name = "LivesTimerLabel"
	lives_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lives_col.add_child(lives_timer_label)

	var gold_cell := _chip_cell("GoldPlus", _fire.bind("shop"))
	add_child(gold_cell)
	var gold_col: VBoxContainer = gold_cell.get_child(0)
	var gold_chip := _chip("ui_gold")
	gold_col.add_child(gold_chip[0])
	gold_label = ThemeKit.make_label("0", ThemeKit.FS_SMALL + 2, ThemeKit.GOLD)
	gold_label.name = "GoldLabel"
	gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	(gold_chip[1] as HBoxContainer).add_child(gold_label)
	(gold_chip[1] as HBoxContainer).add_child(ThemeKit.make_icon("ui_plus", CHIP_ICON))

	settings_btn = ThemeKit.make_icon_button("ui_settings", 96)
	settings_btn.name = "SettingsButton"
	settings_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	settings_btn.pressed.connect(_fire.bind("settings"))
	add_child(settings_btn)

	var tick := Timer.new()
	tick.wait_time = 1.0
	tick.autostart = true
	tick.timeout.connect(refresh_lives)
	add_child(tick)


func _enter_tree() -> void:
	for s in SIGNALS:
		if not Game.is_connected(s, _on_game_changed):
			Game.connect(s, _on_game_changed)
	refresh()


func _exit_tree() -> void:
	for s in SIGNALS:
		if Game.is_connected(s, _on_game_changed):
			Game.disconnect(s, _on_game_changed)


func _on_game_changed(_v: Variant = null) -> void:
	refresh()


## Chip tiền tệ: nền tối bo tròn + icon. Trả [panel, hàng ngang để thêm chữ và nút].
func _chip(icon_name: String) -> Array:
	var chip := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = ThemeKit.PANEL
	s.set_corner_radius_all(30)
	s.set_border_width_all(3)
	s.border_color = ThemeKit.PANEL_BORDER
	s.content_margin_left = 8
	s.content_margin_right = 6
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", s)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	chip.add_child(row)
	row.add_child(ThemeKit.make_icon(icon_name, CHIP_ICON))
	return [chip, row]


## Ô chứa chip: cột chip và chữ phụ, phủ một nút trong suốt để cả ô nhận chạm (đủ cỡ 96). Dấu + chỉ là hình.
func _chip_cell(node_name: String, on_press: Callable) -> MarginContainer:
	var cell := MarginContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(col)
	var hit := Button.new()
	hit.name = node_name
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.custom_minimum_size = ThemeKit.MIN_BUTTON
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		hit.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	hit.pressed.connect(on_press)
	cell.add_child(hit)
	return cell


func refresh() -> void:
	gold_label.text = str(int(Game.s.coins))
	if _avatar != null:
		profile_btn.remove_child(_avatar)
		_avatar.queue_free()
	var cosm: Dictionary = Game.s.cos
	_avatar = Profile.make_avatar(str(cosm.get("avatar", "avatar_00")), str(cosm.get("frame", "frame_00")), AVATAR_PX)
	_avatar.name = "AvatarView"
	profile_btn.add_child(_avatar)
	refresh_lives()


func refresh_lives() -> void:
	var lv: Dictionary = Game.lives_view()
	var show_lives := bool(lv.get("open", false))
	lives_panel.visible = show_lives
	if not show_lives:
		return
	if bool(lv.get("infinite", false)):
		lives_label.text = "∞"
		lives_timer_label.text = tr("home_lives_unlimited_left") % fmt_time(int(lv.get("infinite_left", 0)))
		return
	lives_label.text = "%d/%d" % [int(lv.count), int(lv.max)]
	var wait := int(lv.get("seconds_to_next", 0))
	lives_timer_label.text = tr("home_lives_full") if wait <= 0 else tr("home_lives_next") % fmt_time(wait)


func _fire(action_name: String) -> void:
	action.emit(action_name)


## Dấu + cạnh mạng: sang màn hết mạng khi chưa đầy.
func _on_lives_plus() -> void:
	var lv: Dictionary = Game.lives_view()
	if bool(lv.get("infinite", false)) or int(lv.get("count", 0)) >= int(lv.get("max", 0)):
		return
	action.emit("no_lives")
