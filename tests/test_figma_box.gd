extends RefCounted
## FigmaBox fonts: a label on a button fits ThemeKit.button_text_area, measured as drawn (upper case, outline).
const T := preload("res://tests/t.gd")
const FigmaBox := preload("res://src/ui/figma_box.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")

const S := 0.8


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## A caption as HubNav's open tab has it (upper case, centered; tab 295x248, fit width 265).
func _tab(text: String, parent: Control) -> Label:
	var l := Label.new()
	l.text = text
	l.uppercase = true
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _width(l: Label) -> float:
	var fs := l.get_theme_font_size("font_size")
	return ThemeKit.FONT.get_string_size(l.text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + l.get_theme_constant("outline_size")


func test_caption_fits_button_area(t: T) -> void:
	var b := Button.new()
	_tree().root.add_child(b)
	var l := _tab("Startseite", b)
	var fb := FigmaBox.new()
	fb.put(b, Rect2(0, 0, 295, 248))
	fb.put(l, Rect2(10, 167, 275, 68))
	fb.font(l, 60, 3, 265)
	fb.apply(S)
	var area := ThemeKit.button_text_area(Vector2(295, 248) * S)
	t.ok(_width(l) <= area.size.x + 0.5, "chữ hoa và viền nằm trong vùng chữ của nút")
	t.ok(l.get_theme_font_size("font_size") < roundi(60 * S), "chữ dài co lại")
	l.text = "Home"
	fb.apply(S)
	t.eq(l.get_theme_font_size("font_size"), roundi(60 * S), "chữ ngắn giữ cỡ thiết kế")
	b.free()


func test_label_off_button_keeps_fit_width(t: T) -> void:
	var p := Control.new()
	_tree().root.add_child(p)
	var l := _tab("Startseite", p)
	var fb := FigmaBox.new()
	fb.put(p, Rect2(0, 0, 295, 248))
	fb.put(l, Rect2(10, 167, 275, 68))
	fb.font(l, 60, 3, 265)
	fb.apply(S)
	t.ok(_width(l) <= 265 * S + 0.5, "ngoài nút chỉ theo rộng fit")
	t.ok(_width(l) > ThemeKit.button_text_area(Vector2(295, 248) * S).size.x, "không bị ép theo vùng chữ của nút")
	p.free()
