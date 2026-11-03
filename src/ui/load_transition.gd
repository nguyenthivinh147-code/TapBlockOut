extends "res://src/ui/stub_ui.gd"
## Wireframe 3.1 Load Level Transition: chuyển cảnh vào level. Chưa nối logic.

func _sample() -> Dictionary:
	return SampleData.TRANSITION


func _build() -> void:
	add_child(ThemeKit.make_background(ThemeKit.SLATE_BG, ThemeKit.SLATE_SURFACE))
	var col := _center_column()
	col.add_child(ThemeKit.make_sprite("node_green", 260))
	col.add_child(_shout(tr("level_title") % int(view.level), ThemeKit.FS_HUGE))
