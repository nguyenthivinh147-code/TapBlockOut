extends "res://src/ui/stub_ui.gd"
## Wireframe 10.2 Change Name: đổi tên. Chưa nối logic.

func _sample() -> Dictionary:
	return SampleData.PROFILE_NAME


func _title() -> String:
	return tr("profile_name_title")


func _fill(box: VBoxContainer) -> void:
	box.add_child(_say(tr("profile_name_rules"), ThemeKit.FS_SMALL + 2))
	var input := LineEdit.new()
	input.name = "NameInput"
	input.text = str(view.name)
	input.custom_minimum_size = Vector2(0, 96)
	input.add_theme_font_size_override("font_size", ThemeKit.FS_BODY)
	input.add_theme_color_override("font_color", ThemeKit.INK)
	var s := StyleBoxFlat.new()
	s.bg_color = ThemeKit.WELL
	s.set_corner_radius_all(18)
	s.set_content_margin_all(18)
	input.add_theme_stylebox_override("normal", s)
	input.add_theme_stylebox_override("focus", s)
	box.add_child(input)
	if bool(view.get("error", false)):
		box.add_child(_say(tr("profile_name_taken"), ThemeKit.FS_SMALL, ThemeKit.INK_DANGER))
	box.add_child(_btn(tr("common_ok"), "primary", "ok"))
