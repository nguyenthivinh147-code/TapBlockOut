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
const RewardFly := preload("res://src/ui/reward_fly.gd")
const UiTween := preload("res://src/ui/ui_tween.gd")

const SCENE_PATH := "res://scenes/hub_top.tscn"
const DESIGN_W := 886.0
const DESIGN_H := 124.0
const AVATAR_PX := 124
## Avatar thụt 3% mỗi cạnh: to vừa đủ lấp lỗ frame, không hở ở góc.
const AVATAR_INSET := 0.03
const SIGNALS := ["coins_changed", "lives_changed", "cos_changed", "inv_changed"]
## Lives and gold chip (3D pill of the Home ref, Figma 106:385; tools/make_pastel_home.py): CHIP_SCALE px per design px,
## body CHIP_BODY design px high (= the bar), soft shadow CHIP_SHADOW below it. Scaled to the bar, 9-sliced across with
## round caps of half the body height.
const CHIP_TEX := "res://assets/ui/figma/hub_chip.png"
const CHIP_SCALE := 3.0
const CHIP_BODY := 70.0
const CHIP_SHADOW := 8.0
## Chip art per bar height in px (every HubTop of a screen size shares it).
static var _chip_cache: Dictionary = {}

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
var gold_icon: TextureRect = null:
	get:
		_bind()
		return gold_icon
## Số gold hiện thay cho Game.s.coins khi >= 0 (gold đang bay lên thanh đếm dần tới số trong ví); -1 là số trong ví.
var gold_shown: int = -1:
	set(v):
		gold_shown = v
		if _bound:
			_show_gold()
var settings_btn: Button = null:
	get:
		_bind()
		return settings_btn

var _avatar: Control = null
var _lives_icon: TextureRect = null
var _fb := FigmaBox.new()
var _bars: Array[Panel] = []
var _bound: bool = false
## Lives number on the heart (-1 before the first, or while unlimited): a change bumps the heart.
var _lives_shown: int = -1


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
	add_to_group(RewardFly.GROUP)


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
	gold_icon = $GoldPanel/Icon
	settings_btn = $SettingsButton
	# _layout() gives each bar the chip art at its height (the scene's flat box is the fallback without the art)
	_bars = [$LivesPanel/Bar, $GoldPanel/Bar]
	profile_btn.pressed.connect(_fire.bind("profile"))
	($LivesPanel/LivesPlus as Button).pressed.connect(_on_lives_plus)
	($GoldPanel/GoldPlus as Button).pressed.connect(_fire.bind("shop"))
	settings_btn.pressed.connect(_fire.bind("settings"))
	# Pressed look (design.md mục 2 "Chạm vào UI"): the avatar and the gear press themselves; the lives and gold
	# buttons are invisible over their chips, which press instead.
	for pair in [[profile_btn, profile_btn], [$LivesPanel/LivesPlus, lives_panel], [$GoldPanel/GoldPlus, $GoldPanel],
			[settings_btn, settings_btn]]:
		var b := pair[0] as Button
		b.button_down.connect(Callable(UiTween, "press").bind(pair[1], true))
		b.button_up.connect(Callable(UiTween, "press").bind(pair[1], false))
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
	var chip := chip_box(CHIP_BODY * s)
	for bar in _bars:
		if chip != null:
			bar.add_theme_stylebox_override("panel", chip)
	_fb.apply(s)


## Chip art scaled so its body is bar_h px high: 9-slice across (caps keep their round shape at any width), the shadow
## drawn below the bar through expand_margin_bottom. Null when the art can't be read.
static func chip_box(bar_h: float) -> StyleBoxTexture:
	var key := roundi(bar_h)
	if key <= 0:
		return null
	var k := float(key) / (CHIP_BODY * CHIP_SCALE)
	var t: Texture2D = _chip_cache.get(key)
	if t == null:
		var src := load(CHIP_TEX) as Texture2D
		var img := src.get_image() if src != null else null
		if img == null:
			return null
		if img.is_compressed():
			img.decompress()
		img.resize(maxi(roundi(img.get_width() * k), 3), maxi(roundi(img.get_height() * k), 1), Image.INTERPOLATE_LANCZOS)
		t = ImageTexture.create_from_image(img)
		_chip_cache[key] = t
	var cap := floorf(t.get_width() * 0.5 - 1.0)
	var sb := StyleBoxTexture.new()
	sb.texture = t
	sb.texture_margin_left = cap
	sb.texture_margin_right = cap
	sb.expand_margin_bottom = t.get_height() - key
	return sb


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
	_show_gold(true)
	if _avatar != null:
		profile_btn.remove_child(_avatar)
		_avatar.queue_free()
	var cosm: Dictionary = Game.s.cos
	_avatar = Profile.make_avatar(str(cosm.get("avatar", "avatar_00")), str(cosm.get("frame", "frame_00")), AVATAR_PX, AVATAR_INSET)
	_avatar.name = "AvatarView"
	_avatar.set_meta("u_rt", true)
	_avatar.custom_minimum_size = Vector2.ZERO
	_avatar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	profile_btn.add_child(_avatar)
	refresh_lives()


## animate (a wallet change from Game, refresh()): the number counts to its new value (UiTween.roll; the first one
## shows at once). Otherwise it shows at once: coins landing on the chip (RewardFly, gold_shown) step it themselves.
func _show_gold(animate: bool = false) -> void:
	var v := maxi(int(Game.s.coins) - RewardFly.held("gold"), 0) if gold_shown < 0 else gold_shown
	if animate:
		UiTween.roll(gold_label, v)
	else:
		UiTween.set_number(gold_label, v)


## RewardFly: gold lands on the gold icon, lives and unlimited lives on the heart.
func reward_target(kind: String) -> Control:
	_bind()
	match kind:
		"gold":
			return gold_icon
		"lives", "inf":
			return _lives_icon if lives_panel.visible else null
	return null


## RewardFly: a part landed or stopped flying.
func reward_refresh() -> void:
	if is_inside_tree():
		_show_gold()
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
		_lives_shown = -1
		lives_timer_label.text = tr("home_lives_forever") if bool(lv.get("infinite_forever", false)) \
			else fmt_time(int(lv.get("infinite_left", 0)))
	else:
		_lives_icon.texture = ThemeKit.icon("ui_heart")
		var n := maxi(int(lv.count) - RewardFly.held("lives"), 0)
		lives_label.text = str(n)
		# A life lost or won bumps the heart (a RewardFly landing bumps it too, sharing the tween).
		if _lives_shown >= 0 and n != _lives_shown and _lives_icon.is_visible_in_tree():
			UiTween.bump(_lives_icon)
		_lives_shown = n
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
