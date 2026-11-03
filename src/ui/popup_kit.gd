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
