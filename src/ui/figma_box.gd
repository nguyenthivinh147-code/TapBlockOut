extends RefCounted
## Đặt node theo toạ độ Figma (px thiết kế) rồi co theo s = rộng thật / rộng khung Figma.
## Toạ độ tính theo node cha. bottom = true: neo theo đáy khung, dời theo chênh lệch chiều cao (shift_y).
## Dùng: var fb := FigmaBox.new(); fb.put(node, Rect2(x, y, w, h)); fb.font(label, 36); fb.apply(s, shift_y).

const ThemeKit := preload("res://src/ui/theme_kit.gd")

## node -> [Rect2, bottom]
var _rects: Dictionary = {}
## label/button -> [cỡ chữ, viền, rộng tối đa (0: không ép)]
var _fonts: Dictionary = {}


func put(node: Control, rect: Rect2, bottom: bool = false) -> Control:
	_rects[node] = [rect, bottom]
	return node


func rect_of(node: Control) -> Rect2:
	return (_rects[node] as Array)[0]


func move(node: Control, pos: Vector2) -> void:
	var r: Array = _rects[node]
	r[0] = Rect2(pos, (r[0] as Rect2).size)


func resize(node: Control, rect: Rect2) -> void:
	(_rects[node] as Array)[0] = rect


## Cỡ chữ và viền theo px thiết kế. fit_w > 0: chữ dài thì thu nhỏ cho vừa rộng đó (px thiết kế).
func font(node: Control, px: float, outline: float = 0.0, fit_w: float = 0.0) -> void:
	_fonts[node] = [px, outline, fit_w]


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
		var text := str((n as Object).get("text"))
		if float(f[2]) > 0.0 and text != "":
			var limit := float(f[2]) * s
			while fs > 8 and ThemeKit.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > limit:
				fs -= 1
		(n as Control).add_theme_font_size_override("font_size", fs)
		var ol := roundi(float(f[1]) * 2.0 * s)
		(n as Control).add_theme_constant_override("outline_size", ol)
		# Figma: bóng chữ cùng màu viền, lệch xuống (không phải bóng đen mặc định).
		if n is Label:
			ThemeKit.underlay(n as Label, ol)
			if ol > 0:
				(n as Label).add_theme_color_override("font_shadow_color", (n as Label).get_theme_color("font_outline_color"))
