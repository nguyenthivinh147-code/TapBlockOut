extends "res://src/ui/stub_ui.gd"
## Wireframe 3.7 Booster Coming Soon: booster còn khoá theo level. Chưa nối logic.

func _build() -> void:
	var col := _overlay(Color(ThemeKit.SCRIM, 0.55))
	col.add_child(_shout(tr("booster_soon_body"), ThemeKit.FS_BODY))
	col.add_child(_shout(tr("booster_soon_keep"), ThemeKit.FS_BODY, ThemeKit.GOLD))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	for k in ["hint", "move", "smash"]:
		var b := ThemeKit.make_icon("ui_lock" if k == "smash" else "booster_" + k, 110)
		row.add_child(b)
