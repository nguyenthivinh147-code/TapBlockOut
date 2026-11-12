extends RefCounted
## Khung popup chung theo Figma (component "popup"): nền mờ, khung kem viền lavender, ribbon tiêu đề, nút X.
## Dùng: var k := PopupKit.make(self, title, close); k.box.add_child(...); PopupKit.show_in(k).

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const UiAtlas := preload("res://src/ui/ui_atlas.gd")

const WIDTH := 640.0
const CONTENT_W := WIDTH - 2.0 * 56.0
const FRAME_MARGIN := 78
const FRAME_PAD := 56
const TITLE_SIZE := 44
const RIBBON_H := 104.0
const RIBBON_OVERLAP := 40
const CLOSE_PX := 96.0

## Khung hi-fi Figma rộng 886 px. make_fig dựng popup bằng toạ độ Figma rồi thu cả khối về màn 720 px,
## nên số trong code là số đọc thẳng từ Figma (node 47:3486: Setting, Profile, Language).
const FIG_SCALE := 720.0 / 886.0
const FIG_W := 807.0
const FIG_FRAME_W := 802.0
const FIG_RIBBON := Rect2(135, 0, 532, 156)
const FIG_TITLE_SIZE := 68
const FIG_CLOSE_CENTER := Vector2(771, 132)
const FIG_CLOSE_ICON := 72.0
## Vùng chạm tối thiểu 96 px trên màn, tính ra px Figma.
const FIG_HIT := 96.0 / FIG_SCALE
const FIG_INK := Color("4A2A6B")
const FIG_WELL := Color("FAE4BF")
const FIG_CREAM := Color("FFFAF0")
const FIG_TITLE_STROKE := Color("5519B7")
const FIG_TAB_STROKE := Color("5E45BA")
## Sprite nút -> màu viền chữ trên nút đó.
const FIG_BUTTON_STROKE := {
	"pill_green": Color("2E8B00"),
	"pill_red": Color("8C1830"),
	"pill_gray": Color("6E6E6E"),
	"pill_purple": Color("3A1C6E"),
	"pill_blue": Color("0E2F6D"),
	"pill_cyan": Color("007997"),
}

## Ribbon cho màn kết quả: tên -> [sprite, màu viền chữ, cao].
const BANNERS := {
	"win": ["ribbon_orange", Color("6B2C07"), 150.0],
	"lose": ["ribbon_blue", Color("0E2F6D"), 150.0],
	"red": ["ribbon_red", Color("7E1010"), 150.0],
}


## Dựng vào owner: Dim, CenterContainer, card (ribbon + khung).
## on_close hợp lệ thì có nút X. opts: width, separation, banner (khoá BANNERS), frame ("wide" | "tall").
## Trả {card, frame, box, title, close}; box là VBox nội dung, close là null nếu không có X.
static func make(owner: Control, title: String, on_close: Callable = Callable(), opts: Dictionary = {}) -> Dictionary:
	owner.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = ThemeKit.SCRIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	owner.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.add_child(center)
	var res := make_card(title, on_close, opts)
	center.add_child(res.card)
	return res


## Chỉ dựng card (khi màn tự lo nền, như màn hết mạng).
static func make_card(title: String, on_close: Callable = Callable(), opts: Dictionary = {}) -> Dictionary:
	var width := float(opts.get("width", WIDTH))
	var card := VBoxContainer.new()
	card.name = "Panel"
	card.add_theme_constant_override("separation", -RIBBON_OVERLAP)
	var ribbon := _ribbon(title, str(opts.get("banner", "")))
	ribbon.z_index = 1
	card.add_child(ribbon)

	var frame := PanelContainer.new()
	frame.name = "Frame"
	frame.custom_minimum_size.x = width
	frame.add_theme_stylebox_override("panel", _frame_box(str(opts.get("frame", "wide"))))
	card.add_child(frame)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", int(opts.get("separation", 18)))
	frame.add_child(box)

	var close: Button = null
	if on_close.is_valid():
		var over := Control.new()
		over.name = "Overlay"
		over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(over)
		close = _close_button()
		close.pressed.connect(on_close)
		over.add_child(close)
		close.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		# Tâm nút nằm ở góc trên phải khung, như component popup.
		close.offset_left = FRAME_PAD - CLOSE_PX * 0.5 - 24.0
		close.offset_right = FRAME_PAD + CLOSE_PX * 0.5 - 24.0
		close.offset_top = -FRAME_PAD - RIBBON_OVERLAP * 0.5
		close.offset_bottom = -FRAME_PAD - RIBBON_OVERLAP * 0.5 + CLOSE_PX
	var label := ribbon.get_child(0) as Label
	return {"card": card, "frame": frame, "box": box, "title": label, "close": close}


## Hiệu ứng vào cho card; gọi sau khi dựng xong.
static func show_in(k: Dictionary) -> void:
	_animate.call_deferred(k.card)


## card không gõ kiểu: node có thể đã bị free khi lệnh deferred chạy.
static func _animate(card: Variant) -> void:
	if is_instance_valid(card) and (card as Control).is_inside_tree():
		ThemeKit.popup_in(card)


static func _frame_box(kind: String) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load("%s%s.png" % [ThemeKit.FIGMA_DIR, "popup_frame3" if kind == "tall" else "popup_frame1"]) as Texture2D
	s.texture_margin_left = FRAME_MARGIN
	s.texture_margin_right = FRAME_MARGIN
	s.texture_margin_top = FRAME_MARGIN
	s.texture_margin_bottom = FRAME_MARGIN
	s.content_margin_left = FRAME_PAD
	s.content_margin_right = FRAME_PAD
	s.content_margin_top = FRAME_PAD + RIBBON_OVERLAP * 0.5
	s.content_margin_bottom = FRAME_PAD
	return s


static func _ribbon(title: String, banner: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "Ribbon"
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var stroke := ThemeKit.RIBBON_STROKE
	var style: StyleBoxTexture
	var min_h := RIBBON_H
	if BANNERS.has(banner):
		var b: Array = BANNERS[banner]
		style = UiAtlas.box(str(b[0]), Vector4(170, 0, 170, 0), Vector4(150, 8, 150, 40))
		stroke = b[1]
		min_h = float(b[2])
		p.custom_minimum_size = Vector2(UiAtlas.size_of(str(b[0])).x, min_h)
	else:
		# Ribbon hình bầu dục: kéo giãn cả sprite để giữ dáng.
		style = UiAtlas.box("label_purple", Vector4.ZERO, Vector4(72, 10, 72, 22))
		p.custom_minimum_size = Vector2(360, min_h)
	p.add_theme_stylebox_override("panel", style)
	var l := ThemeKit.make_label(title, TITLE_SIZE, ThemeKit.TEXT)
	l.name = "TitleLabel"
	l.add_theme_color_override("font_outline_color", stroke)
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


static func _close_button() -> Button:
	var b := Button.new()
	b.name = "CloseX"
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var e := StyleBoxEmpty.new()
		e.set_content_margin_all(14)
		b.add_theme_stylebox_override(st, e)
	b.icon = ThemeKit.icon("ui_close")
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(CLOSE_PX, CLOSE_PX)
	return b


## Popup theo khung Figma: Dim, CenterContainer, card. height là cao cả popup tính từ đỉnh ribbon (px Figma),
## frame_top là y mép trên khung tím. Con đặt vào fig bằng toạ độ Figma tương đối với góc trên trái popup.
## extra_h thêm chỗ dưới khung (chữ nằm ngoài popup như số phiên bản). Trả {card, fig, frame, title, close}.
static func make_fig(owner: Control, title: String, on_close: Callable, height: float, frame_top: float = 100.0,
		extra_h: float = 0.0) -> Dictionary:
	owner.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = ThemeKit.SCRIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	owner.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.add_child(center)
	var res := make_fig_card(title, on_close, height, frame_top, extra_h)
	center.add_child(res.card)
	return res


## Chỉ dựng card Figma (khi màn tự lo nền).
static func make_fig_card(title: String, on_close: Callable, height: float, frame_top: float = 100.0,
		extra_h: float = 0.0) -> Dictionary:
	var card := Control.new()
	card.name = "Panel"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(FIG_W, height + extra_h) * FIG_SCALE
	var fig := Control.new()
	fig.name = "Fig"
	fig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fig.size = Vector2(FIG_W, height + extra_h)
	fig.scale = Vector2.ONE * FIG_SCALE
	card.add_child(fig)

	var frame := NinePatchRect.new()
	frame.name = "Frame"
	frame.texture = load("%spopup_frame1.png" % ThemeKit.FIGMA_DIR) as Texture2D
	frame.patch_margin_left = FRAME_MARGIN
	frame.patch_margin_right = FRAME_MARGIN
	frame.patch_margin_top = FRAME_MARGIN
	frame.patch_margin_bottom = FRAME_MARGIN
	frame.position = Vector2(0, frame_top)
	frame.size = Vector2(FIG_FRAME_W, height - frame_top)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fig.add_child(frame)

	var ribbon := TextureRect.new()
	ribbon.name = "Ribbon"
	ribbon.texture = UiAtlas.tex("label_purple")
	ribbon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ribbon.stretch_mode = TextureRect.STRETCH_SCALE
	ribbon.position = FIG_RIBBON.position
	ribbon.size = FIG_RIBBON.size
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fig.add_child(ribbon)
	var label := ThemeKit.make_label(title, FIG_TITLE_SIZE, ThemeKit.TEXT)
	label.name = "TitleLabel"
	label.add_theme_color_override("font_outline_color", FIG_TITLE_STROKE)
	label.add_theme_constant_override("outline_size", 10)
	ThemeKit.underlay(label, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(FIG_RIBBON.position.x, 16)
	label.size = Vector2(FIG_RIBBON.size.x, 120)
	fit_font(label, FIG_RIBBON.size.x - 100)
	fig.add_child(label)

	var close: Button = null
	if on_close.is_valid():
		close = Button.new()
		close.name = "CloseX"
		close.flat = true
		close.focus_mode = Control.FOCUS_NONE
		var pad := (FIG_HIT - FIG_CLOSE_ICON) * 0.5
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			var e := StyleBoxEmpty.new()
			e.set_content_margin_all(pad)
			close.add_theme_stylebox_override(st, e)
		close.icon = ThemeKit.icon("ui_close")
		close.expand_icon = true
		close.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		close.position = FIG_CLOSE_CENTER - Vector2(FIG_HIT, FIG_HIT) * 0.5
		close.size = Vector2(FIG_HIT, FIG_HIT)
		close.pressed.connect(on_close)
		fig.add_child(close)
	return {"card": card, "fig": fig, "frame": frame, "title": label, "close": close}


## Hộp bo góc đặt tuyệt đối (px Figma).
static func fig_box(parent: Control, rect: Rect2, fill: Color, radius: float, border: Color = Color(0, 0, 0, 0),
		border_w: int = 0) -> Panel:
	var p := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(int(radius))
	s.anti_aliasing = true
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	p.add_theme_stylebox_override("panel", s)
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


## Ảnh đặt tuyệt đối, co vừa rect và giữ tỉ lệ.
static func fig_icon(parent: Control, rect: Rect2, tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.position = rect.position
	r.size = rect.size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## Chữ mực (không viền) đặt tuyệt đối; canh giữa theo chiều dọc trong rect.
static func fig_text(parent: Control, rect: Rect2, content: String, size: int, color: Color = FIG_INK,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := ThemeKit.ink_label(content, size, color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = rect.position
	l.size = rect.size
	fit_font(l, rect.size.x)
	parent.add_child(l)
	return l


## Nút sprite đúng cỡ Figma. Vùng chạm cao tối thiểu FIG_HIT, hình nút vẫn đúng rect.
## region: sprite trong ui_atlas.gd (pill_*, tab_*). stroke trống thì lấy theo FIG_BUTTON_STROKE.
## icon_name khác rỗng thì có icon trước chữ (như đồng gold trên nút giá).
static func fig_button(parent: Control, rect: Rect2, region: String, content: String, size: int,
		stroke: Color = Color(0, 0, 0, 0), icon_name: String = "") -> Button:
	var b := Button.new()
	b.text = content
	b.focus_mode = Control.FOCUS_NONE
	if icon_name != "":
		b.icon = ThemeKit.icon(icon_name)
		b.add_theme_constant_override("icon_max_width", int(size * 0.9))
		b.add_theme_constant_override("h_separation", 12)
	var hit := maxf(rect.size.y, FIG_HIT)
	var trim := (hit - rect.size.y) * 0.5
	b.position = rect.position - Vector2(0, trim)
	b.size = Vector2(rect.size.x, hit)
	b.custom_minimum_size = b.size
	for st in ["normal", "hover", "pressed", "disabled"]:
		var s := UiAtlas.fit_box(region, rect.size.y)
		s.expand_margin_top = -trim
		s.expand_margin_bottom = -trim
		s.content_margin_left = rect.size.y * 0.3
		s.content_margin_right = rect.size.y * 0.3
		match st:
			"hover":
				s.modulate_color = Color(1.08, 1.08, 1.08)
			"pressed":
				s.modulate_color = Color(0.82, 0.82, 0.82)
		b.add_theme_stylebox_override(st, s)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, ThemeKit.TEXT)
	b.add_theme_color_override("font_outline_color", stroke if stroke.a > 0.0 else FIG_BUTTON_STROKE.get(region, ThemeKit.TEXT_OUTLINE))
	b.add_theme_constant_override("outline_size", maxi(6, int(size * 0.16)))
	_fit_button(b, rect.size.x - rect.size.y * 0.6)
	parent.add_child(b)
	return b


## Icon bật tắt (âm thanh, rung, nhạc...). on_icon, off_icon là sprite atlas (tog_*) hoặc tên icon.
## Hai icon trùng nhau (không có bản tắt) thì khi tắt tô xám.
static func fig_toggle(parent: Control, rect: Rect2, on_icon: String, off_icon: String, on: bool) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var icon_id := on_icon if on else off_icon
	b.icon = UiAtlas.tex(icon_id) if UiAtlas.has(icon_id) else ThemeKit.icon(icon_id)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not on and on_icon == off_icon:
		b.self_modulate = Color(0.55, 0.55, 0.55, 0.9)
	b.position = rect.position
	b.size = rect.size
	b.custom_minimum_size = rect.size
	parent.add_child(b)
	return b


## Chữ gạch chân bấm được (Privacy Policy, số phiên bản). center là tâm chữ; align_right thì center.x là mép phải.
static func fig_link(parent: Control, center: Vector2, content: String, size: int, color: Color = FIG_INK,
		align_right: bool = false) -> Button:
	var b := Button.new()
	b.text = content
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, color)
	b.add_theme_constant_override("outline_size", 0)
	var w := ThemeKit.FONT.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var box := Vector2(maxf(w + 8.0, FIG_HIT), FIG_HIT)
	b.size = box
	b.custom_minimum_size = box
	b.position = Vector2(center.x - (box.x if align_right else box.x * 0.5), center.y - box.y * 0.5)
	if align_right:
		b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var line := ColorRect.new()
	line.name = "Underline"
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.size = Vector2(w, maxf(2.0, size * 0.07))
	line.position = Vector2(box.x - w - 4.0 if align_right else (box.x - w) * 0.5, box.y * 0.5 + size * 0.42)
	b.add_child(line)
	parent.add_child(b)
	return b


## Thu cỡ chữ của label cho vừa bề rộng max_w (chữ tiếng Việt dài hơn tiếng Anh).
static func fit_font(l: Label, max_w: float) -> void:
	var size := l.get_theme_font_size("font_size")
	while size > 16 and ThemeKit.FONT.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w:
		size -= 2
	l.add_theme_font_size_override("font_size", size)


static func _fit_button(b: Button, max_w: float) -> void:
	var size := b.get_theme_font_size("font_size")
	var icon_w := 0.0
	if b.icon != null:
		icon_w = float(b.get_theme_constant("icon_max_width")) + 10.0
	while size > 16 and ThemeKit.FONT.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + icon_w > max_w:
		size -= 2
	b.add_theme_font_size_override("font_size", size)


## Nhãn chữ mực canh giữa, tự xuống dòng, rộng vừa thân popup.
static func text(content: String, size: int = ThemeKit.FS_BODY, color: Color = ThemeKit.INK, node_name: String = "") -> Label:
	var l := ThemeKit.ink_label(content, size, color)
	if node_name != "":
		l.name = node_name
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = CONTENT_W
	return l


## Hàng ngang giãn đều các con (hai nút cạnh nhau, ba ô thưởng...).
static func row(children: Array, separation: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", separation)
	for c in children:
		var ctrl := c as Control
		ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(ctrl)
	return h


## Ô thưởng: icon trên, chữ dưới, trên nền warm/tan.
static func reward_tile(icon_tex: Texture2D, caption: String, px: float = 96.0) -> PanelContainer:
	var w := ThemeKit.make_well()
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	w.add_child(v)
	var r := TextureRect.new()
	r.texture = icon_tex
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(r)
	var l := ThemeKit.ink_label(caption, ThemeKit.FS_SMALL, ThemeKit.BROWN)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	return w
