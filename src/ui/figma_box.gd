extends RefCounted
## Đặt node theo toạ độ Figma (px thiết kế) rồi co theo s = rộng thật / rộng khung Figma.
## Toạ độ tính theo node cha. bottom = true: neo theo đáy khung, dời theo chênh lệch chiều cao (shift_y).
## Dùng: var fb := FigmaBox.new(); fb.put(node, Rect2(x, y, w, h)); fb.font(label, 36); fb.apply(s, shift_y).
## put() và font() ghi cả meta lên node (fb_rect, fb_bottom, fb_font) nên node lưu trong scene giữ toạ độ thiết kế;
## script của scene gọi fb.adopt(root) để nhận lại các node đó.

const ThemeKit := preload("res://src/ui/theme_kit.gd")

const META_RECT := "fb_rect"
const META_BOTTOM := "fb_bottom"
const META_FONT := "fb_font"

## node -> [Rect2, bottom]
var _rects: Dictionary = {}
## label/button -> [cỡ chữ, viền, rộng tối đa (0: không ép)]
var _fonts: Dictionary = {}


func put(node: Control, rect: Rect2, bottom: bool = false) -> Control:
	_rects[node] = [rect, bottom]
	node.set_meta(META_RECT, rect)
	if bottom:
		node.set_meta(META_BOTTOM, true)
	elif node.has_meta(META_BOTTOM):
		node.remove_meta(META_BOTTOM)
	return node


func rect_of(node: Control) -> Rect2:
	return (_rects[node] as Array)[0]


func move(node: Control, pos: Vector2) -> void:
	var r: Array = _rects[node]
	r[0] = Rect2(pos, (r[0] as Rect2).size)
	node.set_meta(META_RECT, r[0])


func resize(node: Control, rect: Rect2) -> void:
	(_rects[node] as Array)[0] = rect
	node.set_meta(META_RECT, rect)


## Cỡ chữ và viền theo px thiết kế. fit_w > 0: chữ dài thì thu nhỏ cho vừa rộng đó (px thiết kế).
func font(node: Control, px: float, outline: float = 0.0, fit_w: float = 0.0) -> void:
	_fonts[node] = [px, outline, fit_w]
	node.set_meta(META_FONT, [px, outline, fit_w])


## Registers every node of root's scene (owner == root, root itself excluded) that carries the metas put() and
## font() leave. Nodes of an instanced scene inside (another owner) are left to that scene's own FigmaBox.
func adopt(root: Node) -> void:
	_adopt(root, root)


func _adopt(n: Node, root: Node) -> void:
	for c in n.get_children():
		if c is Control and c.owner == root:
			if c.has_meta(META_RECT):
				_rects[c] = [c.get_meta(META_RECT) as Rect2, bool(c.get_meta(META_BOTTOM, false))]
			if c.has_meta(META_FONT):
				var f: Array = c.get_meta(META_FONT)
				_fonts[c] = [float(f[0]), float(f[1]), float(f[2])]
		_adopt(c, root)


func apply(s: float, shift_y: float = 0.0) -> void:
	for n in _rects.keys():
		if not is_instance_valid(n):
			continue
		var r: Rect2 = _rects[n][0]
		var y := r.position.y + (shift_y if bool(_rects[n][1]) else 0.0)
		var c := n as Control
		c.position = Vector2(r.position.x, y) * s
		c.size = r.size * s
	for n in _fonts.keys():
		if not is_instance_valid(n):
			continue
		var f: Array = _fonts[n]
		var fs := maxi(roundi(float(f[0]) * s), 8)
		var ol := roundi(float(f[1]) * 2.0 * s)
		var text := str((n as Object).get("text"))
		if n is Label and (n as Label).uppercase:
			text = text.to_upper()
		var limit := minf(float(f[2]) * s if float(f[2]) > 0.0 else INF, _button_room(n as Control, s))
		if limit < INF and text != "":
			# The outline is drawn past the glyphs.
			limit -= ol
			while fs > 8 and ThemeKit.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > limit:
				fs -= 1
		(n as Control).add_theme_font_size_override("font_size", fs)
		(n as Control).add_theme_constant_override("outline_size", ol)
		# Figma: bóng chữ cùng màu viền, lệch xuống (không phải bóng đen mặc định).
		if n is Label:
			ThemeKit.underlay(n as Label, ol)
			if ol > 0:
				(n as Label).add_theme_color_override("font_shadow_color", (n as Label).get_theme_color("font_outline_color"))


## Width a label on a button may fill, by its alignment, inside the button's ThemeKit.button_text_area (px at
## scale s). INF for a label that is not on a button.
func _button_room(c: Control, s: float) -> float:
	var b := c.get_parent() as BaseButton
	if b == null or not (c is Label):
		return INF
	var area := ThemeKit.button_text_area((_rects[b][0] as Rect2).size * s if _rects.has(b) else b.size)
	var r := Rect2((_rects[c][0] as Rect2).position * s, (_rects[c][0] as Rect2).size * s) if _rects.has(c) else Rect2(c.position, c.size)
	match (c as Label).horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			var mid := r.get_center().x
			return maxf(2.0 * minf(mid - area.position.x, area.end.x - mid), 0.0)
		HORIZONTAL_ALIGNMENT_RIGHT:
			return maxf(r.end.x - area.position.x, 0.0)
	return maxf(area.end.x - r.position.x, 0.0)
