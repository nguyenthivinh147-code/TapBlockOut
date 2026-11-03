extends Control
## Thanh trên dùng chung Home, Shop, Leaderboard (Figma "main menu" > Frame 1893566669): avatar, mạng, vàng, settings.
## Toạ độ theo khung Figma rộng 886, co theo rộng thật. Tự nghe Game và tự đếm hồi mạng.
## Bấm nút phát action("profile" | "lives" | "shop" | "settings").
## Shop, Leaderboard gọi hide_side_buttons(): chỉ còn mạng và vàng.
## Node nằm trong scenes/hub_top.tscn (toạ độ thiết kế trong meta fb_rect, fb_font của FigmaBox); script chỉ nối nút,
## điền chữ, avatar. Tạo bằng HubTop.create().

signal action(action_name: String)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Profile := preload("res://src/ui/profile.gd")
const FigmaBox := preload("res://src/ui/figma_box.gd")

const SCENE_PATH := "res://scenes/hub_top.tscn"
const DESIGN_W := 886.0
const DESIGN_H := 124.0
const AVATAR_PX := 124
const SIGNALS := ["coins_changed", "lives_changed", "cos_changed", "inv_changed"]

# Getters bind the scene's nodes on first use (callers read them before adding the bar to the tree).
var profile_btn: Button = null:
	get:
		_bind()
		return profile_btn
var lives_panel: Control = null:
	get:
		_bind()
		return lives_panel
## Số mạng vẽ trên icon tim (trống khi mạng vô hạn).
var lives_label: Label = null:
	get:
		_bind()
		return lives_label
## Chữ trong thanh mạng: "Full" hoặc thời gian tới mạng kế / hết vô hạn.
var lives_timer_label: Label = null:
	get:
		_bind()
		return lives_timer_label
var gold_label: Label = null:
	get:
		_bind()
		return gold_label
var settings_btn: Button = null:
	get:
		_bind()
		return settings_btn

var _avatar: Control = null
var _lives_icon: TextureRect = null
var _fb := FigmaBox.new()
var _bar_boxes: Array[StyleBoxFlat] = []
var _bound: bool = false


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


# Only the name (the scene's root has the same one): other built-in properties come from the scene.
func _init() -> void:
	name = "HubTop"


## The bar as an instance of its scene.
static func create() -> Control:
	return (load(SCENE_PATH) as PackedScene).instantiate()


## Finds the scene's nodes and wires them. Called on first use, not in _init(): a scene adds the children after the
## script starts.
func _bind() -> void:
	if _bound:
		return
	_bound = true
	profile_btn = $ProfileButton
	lives_panel = $LivesPanel
	_lives_icon = $LivesPanel/Icon
	lives_label = $LivesPanel/LivesLabel
	lives_timer_label = $LivesPanel/LivesTimerLabel
	gold_label = $GoldPanel/GoldLabel
	settings_btn = $SettingsButton
	# Sub-resources are shared by every instance of the scene; _layout() scales these per bar.
	for bar: Panel in [$LivesPanel/Bar, $GoldPanel/Bar]:
		var bs := (bar.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
		bar.add_theme_stylebox_override("panel", bs)
		_bar_boxes.append(bs)
	profile_btn.pressed.connect(_fire.bind("profile"))
	($LivesPanel/LivesPlus as Button).pressed.connect(_on_lives_plus)
	($GoldPanel/GoldPlus as Button).pressed.connect(_fire.bind("shop"))
	settings_btn.pressed.connect(_fire.bind("settings"))
	($Tick as Timer).timeout.connect(refresh_lives)
	_fb.adopt(self)
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	if not _bound or size.x <= 0.0:
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
	_bind()
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


func refresh() -> void:
	_bind()
	gold_label.text = str(int(Game.s.coins))
	if _avatar != null:
		profile_btn.remove_child(_avatar)
		_avatar.queue_free()
	var cosm: Dictionary = Game.s.cos
	_avatar = Profile.make_avatar(str(cosm.get("avatar", "avatar_00")), str(cosm.get("frame", "frame_00")), AVATAR_PX)
	_avatar.name = "AvatarView"
	_avatar.set_meta("u_rt", true)
	_avatar.custom_minimum_size = Vector2.ZERO
	_avatar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	profile_btn.add_child(_avatar)
	refresh_lives()


func refresh_lives() -> void:
	_bind()
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


## Hides the avatar and settings buttons (Shop, Leaderboard keep only lives and gold).
func hide_side_buttons() -> void:
	_bind()
	profile_btn.visible = false
	settings_btn.visible = false


func _fire(action_name: String) -> void:
	action.emit(action_name)


## Chip mạng: mở popup tim (kể cả khi đầy mạng; lúc đó popup chỉ báo đầy).
func _on_lives_plus() -> void:
	action.emit("lives")
