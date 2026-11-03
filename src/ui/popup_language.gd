extends "res://src/ui/stub_ui.gd"
## Wireframe 10.4 Language: chọn ngôn ngữ. Chưa nối logic.

func _sample() -> Dictionary:
	return SampleData.LANGUAGES


func _title() -> String:
	return tr("settings_language")


func _fill(box: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for code in view.rows:
		var b := _btn(tr("settings_lang_" + str(code)), "primary" if str(code) == str(view.current) else "secondary", "lang_" + str(code))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.x = 250
		b.add_theme_font_size_override("font_size", ThemeKit.FS_SMALL + 2)
		grid.add_child(b)
	box.add_child(_btn(tr("settings_save"), "gold", "save"))
