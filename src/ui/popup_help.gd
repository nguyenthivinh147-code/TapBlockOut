extends "res://src/ui/stub_ui.gd"
## Wireframe 10.5 Help & Support: gửi phản hồi. Chưa nối logic.

func _title() -> String:
	return tr("settings_help_title")


func _fill(box: VBoxContainer) -> void:
	box.add_child(_say(tr("settings_help_sub"), ThemeKit.FS_BODY, ThemeKit.BROWN))
	for key in ["settings_help_bug", "settings_help_purchase", "settings_help_idea"]:
		box.add_child(_check_row(tr(key)))
	var input := TextEdit.new()
	input.name = "Message"
	input.placeholder_text = tr("settings_help_placeholder")
	input.custom_minimum_size = Vector2(0, 180)
	input.add_theme_font_size_override("font_size", ThemeKit.FS_SMALL + 2)
	input.add_theme_color_override("font_color", ThemeKit.INK)
	input.add_theme_color_override("font_placeholder_color", ThemeKit.INK_DIM)
	var s := StyleBoxFlat.new()
	s.bg_color = ThemeKit.WELL
	s.set_corner_radius_all(18)
	s.set_content_margin_all(14)
	input.add_theme_stylebox_override("normal", s)
	input.add_theme_stylebox_override("focus", s)
	box.add_child(input)
	box.add_child(_btn(tr("settings_help_send"), "primary", "send"))
	box.add_child(_say(tr("settings_help_note"), ThemeKit.FS_SMALL, ThemeKit.INK_DIM))
