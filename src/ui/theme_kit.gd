extends RefCounted
## Bảng màu, cỡ chữ, nút, panel, popup tween và icon (có placeholder vẽ bằng code).
## Giá trị lấy từ Figma "Tapblock" > page "02 · Foundations"; sprite nút/khung nằm trong ui_atlas.gd.
## Dùng: const ThemeKit := preload("res://src/ui/theme_kit.gd")

const UiAtlas := preload("res://src/ui/ui_atlas.gd")

const BLOCK_COLORS := {
	"yellow": Color("FDD414"),
	"green": Color("6DED1E"),
	"blue": Color("0C9CFD"),
	"purple": Color("E644F4"),
}
## Bốn tông của khối kẹo; `face` trùng BLOCK_COLORS. Đổi sắc theo tông (vàng về cam, tím về tím đậm) nên không suy ra từ một màu.
const BLOCK_RAMPS := {
	"yellow": {"deep": Color("F19B09"), "side": Color("F8B20F"), "face": Color("FDD414"), "stripe": Color("FDE846")},
	"green": {"deep": Color("20A208"), "side": Color("41C412"), "face": Color("6DED1E"), "stripe": Color("84F437")},
	"blue": {"deep": Color("0260E6"), "side": Color("148FF8"), "face": Color("0C9CFD"), "stripe": Color("41C1FD")},
	"purple": {"deep": Color("B113CC"), "side": Color("C622DC"), "face": Color("E644F4"), "stripe": Color("EC5FF6")},
}

# Brand / Menu
const BG := Color("3967BF")
const BG_TOP := Color("3967BF")
const BG_BOTTOM := Color("7B9EDD")
const NAV_TOP := Color("4A5199")
const NAV_BOTTOM := Color("2E3270")
# Popup Lavender: PANEL là nền tối cho khối thông tin trên nền màu, POPUP_CREAM + INK cho thân popup sáng.
const PANEL := Color("2E3270")
const PANEL_BORDER := Color("7E86C8")
const POPUP_CREAM := Color("F8F3DE")
const INK := Color("3A3F6E")
const TEXT := Color("FFFFFF")
const TEXT_DIM := Color("BEC6EF")
const TEXT_OUTLINE := Color("1A1C3A")
const GOLD := Color("FFC933")
const GOLD_DEEP := Color("FFA508")
const GOOD := Color("73DF31")
const DANGER := Color("F2581F")
const HARD_BANNER := Color("B757FA")
const HARD_BANNER_VERY := Color("C31F1F")
const VIDEO := Color("2F92E0")
const SCRIM := Color(0.0, 0.016, 0.059, 0.8)
# Theme Slate (Gameplay)
const SLATE_BG := Color("504D73")
const SLATE_SURFACE := Color("3D3A63")
# Chữ và khối trên thân popup kem (Theme Warm + Popup Lavender)
const INK_DIM := Color("6C74AE")
const INK_GOOD := Color("3E7F1E")
const INK_DANGER := Color("C31F1F")
const BROWN := Color("A95D3A")
const WELL := Color("F2E3C3")
const WELL_HOT := Color("FAE2BA")
const WELL_HEADER := Color("F59A1F")
const WELL_TODAY := Color("71CB1B")
const PATH_LINE := Color("20417B")
const TOGGLE_ON := Color("52DA41")
const TOGGLE_OFF := Color("859DC6")
const GOLD_STROKE := Color("6B2C07")
const RIBBON_STROKE := Color("3A1C6E")

## Màu viền chữ trên nút (cột "label stroke" của Button ramp).
const BUTTON_STROKE := {
	"primary": Color("0B4F0F"),
	"secondary": Color("2D3650"),
	"video": Color("0E2F6D"),
	"danger": Color("4F0606"),
	"gold": Color("6B2C07"),
	"purple": Color("3A1C6E"),
	"icon": Color("123F86"),
	"booster": Color("0B4F0F"),
	"ghost": Color("1A1C3A"),
}
## kind -> sprite nút trong ui_atlas.gd (ghost vẽ phẳng, không có sprite).
const BUTTON_ART := {
	"primary": "pill_green",
	"secondary": "pill_gray",
	"video": "pill_blue",
	"danger": "pill_red",
	"gold": "pill_yellow",
	"purple": "pill_purple",
	"icon": "tile_lavender",
	"booster": "tile_green",
}

const FS_SMALL := 24
const FS_BODY := 32
const FS_BUTTON := 36
const FS_TITLE := 52
const FS_HUGE := 80

const MIN_BUTTON := Vector2(96, 96)
const RADIUS := 24
const ICON_SIZE := 96
const ICON_DIRS := ["res://assets/ui/", "res://assets/ui/figma/", "res://assets/avatars/", "res://assets/frames/"]
const FIGMA_DIR := "res://assets/ui/figma/"
const PILL_DIR := "res://assets/ui/figma/pill/"
## Tên UI hay gọi mà file mang tên khác.
const ICON_ALIAS := {
	"coin": "ui_gold",
	"booster_hint": "ui_hint",
	"booster_move": "ui_moves",
	"booster_smash": "ui_smash",
	# mảnh leaderboard: dùng tạm ngôi sao cho tới khi có assets/ui/figma/lb_piece.png
	"lb_piece": "ic_star1",
}
## Tên UI -> icon Figma (assets/ui/figma/<tên>.png). Có trong bảng này thì ưu tiên hơn file cũ.
const FIGMA_ICON := {
	"ui_gold": "ic_gold",
	"coin": "ic_gold",
	"ui_gift": "ic_dailygift",
	"ui_shop": "ic_store",
	"ui_lock": "ic_lock",
	"ui_settings": "ic_setting",
	"ui_home": "ic_home",
	"ui_heart": "ic_heart",
	"ui_video": "ic_watchads",
	"ui_sound": "ic_sound_on",
	"ui_music": "ic_music_on",
	"ui_smash": "ic_bomb",
	"booster_smash": "ic_bomb",
	"ui_leaderboard": "ic_leaderboard",
	"ui_noads": "ic_noads",
	"ui_plus": "ic_plus",
	"ui_close": "ic_close",
	"ui_clock": "ic_clock",
	"ui_check": "ic_check",
	"ui_info": "ic_info",
	"ui_hard": "ic_hard",
	"ui_superhard": "ic_superhard",
	"ui_star": "ic_star1",
	"shop_gold_pack_1": "gold1",
	"shop_gold_pack_2": "gold2",
	"shop_gold_pack_3": "gold3",
	"shop_gold_pack_4": "gold4",
	"shop_gold_pack_5": "gold5",
	"shop_gold_pack_6": "gold6",
	"shop_starter_pack": "gold5",
	"shop_level_pack": "gold3",
	"shop_rescue_pack": "ic_giftbox1",
	"shop_remove_ads": "ic_noads",
	"shop_special_pack": "gold6",
}

static var _icon_cache: Dictionary = {}


static func block_color(color_name: String) -> Color:
	return BLOCK_COLORS.get(color_name, TEXT_DIM)


## Bốn tông của khối theo tên màu; màu lạ thì suy từ `base`.
static func block_ramp(color_name: String, base: Color = TEXT_DIM) -> Dictionary:
	if BLOCK_RAMPS.has(color_name):
		return BLOCK_RAMPS[color_name]
	return {"deep": base.darkened(0.38), "side": base.darkened(0.2), "face": base, "stripe": base.lightened(0.14)}


## Nền toàn màn hình, thêm vào đầu danh sách con của màn.
static func make_background(top: Color = BG_TOP, bottom: Color = BG_BOTTOM) -> ColorRect:
	var r := ColorRect.new()
	r.color = BG
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var grad := TextureRect.new()
	grad.name = "Gradient"
	grad.texture = gt
	grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(grad)
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


## kind: primary, secondary, video, danger, gold, purple, icon (nút vuông chỉ có icon), booster, ghost.
static func button_color(kind: String) -> Color:
	match kind:
		"secondary":
			return Color("8EA0BE")
		"video":
			return VIDEO
		"danger":
			return DANGER
		"gold":
			return GOLD
		"purple":
			return Color("9B51E0")
		"ghost":
			return Color(INK, 0.06)
	return GOOD


## Sprite 9-slice của nút theo kind và cỡ. md dùng pill thu về cao 96px để đầu tròn đúng tỉ lệ; lg dùng nguyên sprite atlas.
static func _button_art(kind: String, size_name: String) -> StyleBoxTexture:
	var art: String = BUTTON_ART[kind]
	if kind == "icon" or kind == "booster":
		return UiAtlas.box(art, Vector4(44, 44, 44, 56), Vector4(10, 10, 10, 18))
	if size_name == "lg":
		return UiAtlas.box(art, Vector4(84, 50, 84, 60), Vector4(48, 14, 48, 26))
	var s := StyleBoxTexture.new()
	s.texture = load("%s%s_96.png" % [PILL_DIR, art]) as Texture2D
	s.texture_margin_left = 50
	s.texture_margin_right = 50
	s.texture_margin_top = 30
	s.texture_margin_bottom = 36
	s.content_margin_left = 30
	s.content_margin_right = 30
	s.content_margin_top = 8
	s.content_margin_bottom = 16
	return s


## Hộp nút theo trạng thái: hover sáng hơn, pressed tối hơn, disabled xám. ghost vẽ phẳng có viền.
static func _button_box(kind: String, state: String, size_name: String = "md") -> StyleBox:
	if not BUTTON_ART.has(kind):
		var f := _box(button_color(kind), Color(INK_DIM, 0.5), 2)
		f.set_corner_radius_all(48)
		match state:
			"hover":
				f.bg_color = Color(INK, 0.12)
			"pressed":
				f.bg_color = Color(INK, 0.2)
			"disabled":
				f.bg_color = Color(INK, 0.03)
		return f
	var s := _button_art(kind, size_name)
	match state:
		"hover":
			s.modulate_color = Color(1.08, 1.08, 1.08)
		"pressed":
			s.modulate_color = Color(0.82, 0.82, 0.82)
			s.content_margin_top += 6.0
			s.content_margin_bottom = maxf(s.content_margin_bottom - 6.0, 0.0)
		"disabled":
			s.modulate_color = Color(0.55, 0.55, 0.6, 0.9)
	return s


## size_name: "md" (mặc định) hoặc "lg" (nút chính cỡ lớn như PLAY).
static func make_button(text: String, kind: String = "primary", size_name: String = "md") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = MIN_BUTTON
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", FS_BUTTON)
	if kind == "ghost":
		b.add_theme_color_override("font_color", INK)
		b.add_theme_color_override("font_hover_color", INK)
		b.add_theme_color_override("font_pressed_color", INK)
		b.add_theme_color_override("font_disabled_color", INK_DIM)
		b.add_theme_constant_override("outline_size", 0)
	else:
		b.add_theme_color_override("font_color", TEXT)
		b.add_theme_color_override("font_hover_color", TEXT)
		b.add_theme_color_override("font_pressed_color", TEXT)
		b.add_theme_color_override("font_disabled_color", TEXT_DIM)
		b.add_theme_color_override("font_outline_color", BUTTON_STROKE.get(kind, TEXT_OUTLINE))
		b.add_theme_constant_override("outline_size", 8)
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, _button_box(kind, st, size_name))
	return b


## Nút trong ô hẹp (lưới 3 cột): bớt lề trái phải để chữ không đẩy rộng ô.
static func tighten(b: Button, margin: float = 8.0) -> void:
	for st in ["normal", "hover", "pressed", "disabled"]:
		var s := b.get_theme_stylebox(st).duplicate() as StyleBox
		s.content_margin_left = margin
		s.content_margin_right = margin
		b.add_theme_stylebox_override(st, s)


## Gắn icon trước chữ của nút, cao px.
static func set_button_icon(b: Button, icon_name: String, px: int = 48) -> void:
	b.icon = icon(icon_name)
	b.add_theme_constant_override("icon_max_width", px)
	b.add_theme_constant_override("h_separation", 10)


## Nút chỉ có icon (vuông, nền tile), cỡ tối thiểu 96.
static func make_icon_button(icon_name: String, px: int = 96, kind: String = "icon") -> Button:
	var b := make_button("", kind)
	b.icon = icon(icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(px, px)
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
	l.add_theme_color_override("font_outline_color", TEXT_OUTLINE)
	l.add_theme_constant_override("outline_size", 6)
	return l


## Chữ đậm trên nền sáng (thân popup kem): màu ink, không viền.
static func ink_label(text: String, size: int = FS_BODY, color: Color = INK) -> Label:
	var l := make_label(text, size, color)
	l.add_theme_constant_override("outline_size", 0)
	return l


## Số vàng lớn trên nền sáng: chữ vàng viền nâu như Button/Yellow.
static func gold_label(text: String, size: int = FS_TITLE) -> Label:
	var l := make_label(text, size, GOLD)
	l.add_theme_color_override("font_outline_color", GOLD_STROKE)
	l.add_theme_constant_override("outline_size", 10)
	return l


## Ô nền trên thân popup (warm/tan). border để trống thì không viền.
static func make_well(fill: Color = WELL, border: Color = Color(0, 0, 0, 0), radius: int = 18) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(radius)
	if border.a > 0.0:
		s.set_border_width_all(4)
		s.border_color = border
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", s)
	return p


## Icon theo tên, co vừa ô px.
static func make_icon(icon_name: String, px: float = 72.0) -> TextureRect:
	return _rect(icon(icon_name), px)


## Sprite atlas theo tên (ui_atlas.gd), co vừa ô px.
static func make_sprite(region: String, px: float = 96.0) -> TextureRect:
	return _rect(UiAtlas.tex(region), px)


static func _rect(tex: Texture2D, px: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


## Thanh tiến trình bo tròn. fill mặc định xanh (Button/Green).
static func style_bar(bar: ProgressBar, fill: Color = Color("3CD020")) -> void:
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(INK, 0.25)
	bg.set_corner_radius_all(14)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(14)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)


## Theme chung (đặt vào gốc UI): chữ và nút mặc định cùng bảng màu.
static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = FS_BODY
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", FS_BODY)
	t.set_color("font_outline_color", "Label", TEXT_OUTLINE)
	t.set_constant("outline_size", "Label", 6)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_outline_color", "Button", BUTTON_STROKE["primary"])
	t.set_constant("outline_size", "Button", 8)
	t.set_font_size("font_size", "Button", FS_BUTTON)
	for st in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(st, "Button", _button_box("primary", st))
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, PANEL_BORDER, 3, 12))
	t.set_stylebox("normal", "Label", StyleBoxEmpty.new())
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
	if FIGMA_ICON.has(icon_name):
		var fp := "%s%s.png" % [FIGMA_DIR, FIGMA_ICON[icon_name]]
		if ResourceLoader.exists(fp):
			return fp
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
