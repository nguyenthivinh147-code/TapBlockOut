extends Control
## Thanh trên dùng chung Home, Shop, Leaderboard (Figma "main menu" > Frame 1893566669): avatar, mạng, vàng, settings.
## Toạ độ theo khung Figma rộng 886, co theo rộng thật. Tự nghe Game và tự đếm hồi mạng.
## Bấm nút phát action("profile" | "no_lives" | "shop" | "settings").

signal action(action_name: String)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Profile := preload("res://src/ui/profile.gd")
const FigmaBox := preload("res://src/ui/figma_box.gd")

const DESIGN_W := 886.0
const DESIGN_H := 124.0
const AVATAR_PX := 124
const BAR_FILL := Color("FFFAF0")
const BAR_STROKE := Color("B56915")
const BAR_TEXT := Color("1C4A83")
const SIGNALS := ["coins_changed", "lives_changed", "cos_changed", "inv_changed"]

var profile_btn: Button = null
var lives_panel: Control = null
## Số mạng vẽ trên icon tim (trống khi mạng vô hạn).
var lives_label: Label = null
## Chữ trong thanh mạng: "Full" hoặc thời gian tới mạng kế / hết vô hạn.
var lives_timer_label: Label = null
var gold_label: Label = null
var settings_btn: Button = null

var _avatar: Control = null
var _lives_icon: TextureRect = null
var _fb := FigmaBox.new()
var _bar_boxes: Array[StyleBoxFlat] = []


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
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	profile_btn = _hit_button("ProfileButton", _fire.bind("profile"))
	_fb.put(profile_btn, Rect2(11, 0, AVATAR_PX, AVATAR_PX))
	add_child(profile_btn)

	var lv := _chip("LivesPlus", "ui_heart", _on_lives_plus)
	lives_panel = lv[0]
	lives_panel.name = "LivesPanel"
	_lives_icon = lv[1]
	lives_timer_label = lv[2]
	lives_timer_label.name = "LivesTimerLabel"
	_fb.put(lives_panel, Rect2(189, 10, 272, 105))
	lives_label = ThemeKit.make_label("")
	lives_label.name = "LivesLabel"
	lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lives_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lives_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lives_label.add_theme_color_override("font_outline_color", Color("8A201F"))
	_fb.put(lives_label, Rect2(0, 8, 92, 80))
	_fb.font(lives_label, 40, 3)
	# trên icon tim, dưới dấu + và vùng chạm
	lives_panel.add_child(lives_label)
	lives_panel.move_child(lives_label, 2)
	add_child(lives_panel)

	var gd := _chip("GoldPlus", "ui_gold", _fire.bind("shop"))
	gold_label = gd[2]
	gold_label.name = "GoldLabel"
	_fb.put(gd[0], Rect2(477, 10, 272, 105))
	add_child(gd[0])

	# vùng chạm 118 (đủ 96px ở 720), hình 88 theo Figma
	settings_btn = _hit_button("SettingsButton", _fire.bind("settings"))
	_fb.put(settings_btn, Rect2(780, 3, 118, 118))
	var gear := _icon("ui_settings")
	_fb.put(gear, Rect2(15, 15, 88, 88))
	settings_btn.add_child(gear)
	add_child(settings_btn)

	var tick := Timer.new()
	tick.wait_time = 1.0
	tick.autostart = true
	tick.timeout.connect(refresh_lives)
	add_child(tick)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	if size.x <= 0.0:
		return
	var s := size.x / DESIGN_W
	var h := DESIGN_H * s
	if not is_equal_approx(custom_minimum_size.y, h):
		custom_minimum_size.y = h
	for b in _bar_boxes:
		b.set_corner_radius_all(roundi(36 * s))
		b.set_border_width_all(maxi(roundi(2 * s), 1))
	_fb.apply(s)


func _enter_tree() -> void:
	for sig in SIGNALS:
		if not Game.is_connected(sig, _on_game_changed):
			Game.connect(sig, _on_game_changed)
	refresh()


func _exit_tree() -> void:
	for sig in SIGNALS:
		if Game.is_connected(sig, _on_game_changed):
			Game.disconnect(sig, _on_game_changed)


func _on_game_changed(_v: Variant = null) -> void:
	refresh()


## Nút trong suốt nhận chạm, hình vẽ là con của nút.
func _hit_button(node_name: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.custom_minimum_size = ThemeKit.MIN_BUTTON
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.pressed.connect(on_press)
	return b


func _icon(icon_name: String) -> TextureRect:
	var r := TextureRect.new()
	r.texture = ThemeKit.icon(icon_name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Component Currency 272x105: thanh kem 250x70, icon 92, dấu + 44, chữ xanh đậm.
## Cả ô là vùng chạm (nút trong suốt cao 122 để đủ 96px); dấu + chỉ là hình. Trả [ô, icon, nhãn].
func _chip(node_name: String, icon_name: String, on_press: Callable) -> Array:
	var cell := Control.new()
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := Panel.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := StyleBoxFlat.new()
	bs.bg_color = BAR_FILL
	bs.border_color = BAR_STROKE
	bar.add_theme_stylebox_override("panel", bs)
	_bar_boxes.append(bs)
	_fb.put(bar, Rect2(22, 18, 250, 70))
	cell.add_child(bar)
	var ic := _icon(icon_name)
	_fb.put(ic, Rect2(0, 4, 92, 92))
	cell.add_child(ic)
	var plus := _icon("ui_plus")
	_fb.put(plus, Rect2(63, 60, 44, 44))
	cell.add_child(plus)
	var l := ThemeKit.ink_label("", 36, BAR_TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.uppercase = true
	_fb.put(l, Rect2(96, 18, 170, 70))
	_fb.font(l, 44, 0, 160)
	cell.add_child(l)
	var hit := _hit_button(node_name, on_press)
	_fb.put(hit, Rect2(0, -9, 272, 122))
	cell.add_child(hit)
	return [cell, ic, l]


func refresh() -> void:
	gold_label.text = str(int(Game.s.coins))
	if _avatar != null:
		profile_btn.remove_child(_avatar)
		_avatar.queue_free()
	var cosm: Dictionary = Game.s.cos
	_avatar = Profile.make_avatar(str(cosm.get("avatar", "avatar_00")), str(cosm.get("frame", "frame_00")), AVATAR_PX)
	_avatar.name = "AvatarView"
	_avatar.custom_minimum_size = Vector2.ZERO
	_avatar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	profile_btn.add_child(_avatar)
	refresh_lives()


func refresh_lives() -> void:
	var lv: Dictionary = Game.lives_view()
	var show_lives := bool(lv.get("open", false))
	lives_panel.visible = show_lives
	if not show_lives:
		return
	if bool(lv.get("infinite", false)):
		_lives_icon.texture = ThemeKit.icon("ic_lives")
		lives_label.text = ""
		lives_timer_label.text = fmt_time(int(lv.get("infinite_left", 0)))
	else:
		_lives_icon.texture = ThemeKit.icon("ui_heart")
		lives_label.text = str(int(lv.count))
		var wait := int(lv.get("seconds_to_next", 0))
		lives_timer_label.text = tr("home_lives_full") if wait <= 0 else fmt_time(wait)
	if size.x > 0.0:
		_fb.apply(size.x / DESIGN_W)


func _fire(action_name: String) -> void:
	action.emit(action_name)


## Dấu + cạnh mạng: sang màn hết mạng khi chưa đầy.
func _on_lives_plus() -> void:
	var lv: Dictionary = Game.lives_view()
	if bool(lv.get("infinite", false)) or int(lv.get("count", 0)) >= int(lv.get("max", 0)):
		return
	action.emit("no_lives")
