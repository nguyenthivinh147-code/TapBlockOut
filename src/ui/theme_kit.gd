extends RefCounted
## Bảng màu, cỡ chữ, nút, panel, popup tween và icon (có placeholder vẽ bằng code).
## Dùng: const ThemeKit := preload("res://src/ui/theme_kit.gd")

const BLOCK_COLORS := {
	"yellow": Color("FDE437"),
	"green": Color("8DD142"),
	"blue": Color("2EA4FF"),
	"purple": Color("8D45E0"),
}

const BG := Color("1E2433")
const BG_TOP := Color("2A3350")
const PANEL := Color("2B3350")
const PANEL_BORDER := Color("3C466B")
const TEXT := Color("F4F6FB")
const TEXT_DIM := Color("A9B1CC")
const GOLD := Color("FFC93C")
const GOOD := Color("43B649")
const DANGER := Color("E0566B")
const VIDEO := Color("2F80ED")

const FS_SMALL := 24
const FS_BODY := 32
const FS_BUTTON := 36
const FS_TITLE := 52
const FS_HUGE := 80

const MIN_BUTTON := Vector2(96, 96)
const RADIUS := 24
const ICON_SIZE := 96
const ICON_DIRS := ["res://assets/ui/", "res://assets/avatars/", "res://assets/frames/"]
## Tên UI hay gọi mà file mang tên khác.
const ICON_ALIAS := {
	"coin": "ui_gold",
	"booster_hint": "ui_hint",
	"booster_move": "ui_moves",
	"booster_smash": "ui_smash",
}

static var _icon_cache: Dictionary = {}


static func block_color(color_name: String) -> Color:
	return BLOCK_COLORS.get(color_name, TEXT_DIM)


## Nền toàn màn hình, thêm vào đầu danh sách con của màn.
static func make_background() -> ColorRect:
	var r := ColorRect.new()
	r.color = BG
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func _box(fill: Color, border: Color = Color(0, 0, 0, 0), border_w: int = 0, shadow: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(RADIUS)
	s.set_border_width_all(border_w)
	s.border_color = border
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 16
	s.content_margin_bottom = 16
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * 0.5)
	return s


## kind: primary, secondary, video, danger, ghost.
static func button_color(kind: String) -> Color:
	match kind:
		"secondary":
			return PANEL_BORDER
		"video":
			return VIDEO
		"danger":
			return DANGER
		"ghost":
			return Color(1, 1, 1, 0.08)
	return GOOD


static func make_button(text: String, kind: String = "primary") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = MIN_BUTTON
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", FS_BUTTON)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", TEXT)
	b.add_theme_color_override("font_disabled_color", TEXT_DIM)
	var c := button_color(kind)
	var shadow := 0 if kind == "ghost" else 6
	b.add_theme_stylebox_override("normal", _box(c, Color(0, 0, 0, 0), 0, shadow))
	b.add_theme_stylebox_override("hover", _box(c.lightened(0.08), Color(0, 0, 0, 0), 0, shadow))
	b.add_theme_stylebox_override("pressed", _box(c.darkened(0.2), Color(0, 0, 0, 0), 0, 0))
	b.add_theme_stylebox_override("disabled", _box(c.darkened(0.45), Color(0, 0, 0, 0), 0, 0))
	return b


static func make_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(PANEL, PANEL_BORDER, 3, 12))
	return p


static func make_label(text: String, size: int = FS_BODY, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Theme chung (đặt vào gốc UI): chữ và nút mặc định cùng bảng màu.
static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = FS_BODY
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", FS_BODY)
	t.set_color("font_color", "Button", TEXT)
	t.set_font_size("font_size", "Button", FS_BUTTON)
	t.set_stylebox("normal", "Button", _box(button_color("primary"), Color(0, 0, 0, 0), 0, 6))
	t.set_stylebox("hover", "Button", _box(button_color("primary").lightened(0.08), Color(0, 0, 0, 0), 0, 6))
	t.set_stylebox("pressed", "Button", _box(button_color("primary").darkened(0.2)))
	t.set_stylebox("disabled", "Button", _box(button_color("primary").darkened(0.45)))
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, PANEL_BORDER, 3, 12))
	return t


# --- popup vào ra ---

## Hiện popup: phóng nhẹ từ 0,92 và mờ dần vào. Trả Tween, hoặc null nếu node chưa ở trong cây.
static func popup_in(node: Control, dur: float = 0.18) -> Tween:
	if node == null or not node.is_inside_tree():
		return null
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(0.92, 0.92)
	node.modulate.a = 0.0
	var tw := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, dur)
	tw.tween_property(node, "modulate:a", 1.0, dur)
	return tw


## Đóng popup: thu nhẹ và mờ đi. Trả Tween (await tw.finished rồi queue_free), hoặc null.
static func popup_out(node: Control, dur: float = 0.14) -> Tween:
	if node == null or not node.is_inside_tree():
		return null
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(node, "scale", Vector2(0.92, 0.92), dur)
	tw.tween_property(node, "modulate:a", 0.0, dur)
	return tw


# --- icon ---

## Nạp icon theo tên. Thử `name`, `ui_<name>`, rồi alias (ICON_ALIAS) trong các thư mục ICON_DIRS.
## Thiếu hết hoặc không phải ảnh thì trả placeholder vẽ bằng code.
static func icon(icon_name: String) -> Texture2D:
	if _icon_cache.has(icon_name):
		return _icon_cache[icon_name]
	var tex: Texture2D = null
	var path := _icon_path(icon_name)
	if path != "":
		tex = load(path) as Texture2D
	if tex == null:
		tex = _placeholder(icon_name)
	_icon_cache[icon_name] = tex
	return tex


## Có file icon thật cho tên này không (placeholder thì false).
static func has_real_icon(icon_name: String) -> bool:
	return _icon_path(icon_name) != ""


## Đường dẫn file icon thật cho tên này, "" nếu không có.
static func _icon_path(icon_name: String) -> String:
	var names: Array[String] = [icon_name, "ui_" + icon_name]
	if ICON_ALIAS.has(icon_name):
		names.append(ICON_ALIAS[icon_name])
	for n in names:
		for dir in ICON_DIRS:
			var path := "%s%s.png" % [dir, n]
			if ResourceLoader.exists(path):
				return path
	return ""


static func clear_icon_cache() -> void:
	_icon_cache.clear()


## Xoá mọi cache tĩnh (gọi lúc thoát).
static func clear_cache() -> void:
	clear_icon_cache()


## Hình tròn bo màu theo tên, có vòng sáng và chấm giữa. Cùng tên cho cùng hình.
static func _placeholder(icon_name: String) -> Texture2D:
	var keys := BLOCK_COLORS.keys()
	var base: Color = BLOCK_COLORS[keys[absi(icon_name.hash()) % keys.size()]]
	var n := ICON_SIZE
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	var r_out := n * 0.5 - 2.0
	var r_in := r_out - 6.0
	var r_dot := n * 0.14
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length()
			var col := Color(0, 0, 0, 0)
			if d <= r_dot:
				col = TEXT
			elif d <= r_in:
				col = base
			elif d <= r_out:
				col = base.lightened(0.45)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
