extends "res://src/ui/stub_ui.gd"
## Wireframe 3.11 Speed-up Tutorial: giữ để tăng tốc. Chưa nối logic.

func _build() -> void:
	var col := _overlay(Color(ThemeKit.SCRIM, 0.55))
	col.add_child(_shout(tr("level_speed_title"), ThemeKit.FS_TITLE))
	col.add_child(_shout(tr("level_speed_body"), ThemeKit.FS_SMALL + 4))
	col.add_child(ThemeKit.make_sprite("hand_tap", 180))
	col.add_child(_shout(tr("level_speed_hold"), ThemeKit.FS_BODY, ThemeKit.GOLD))
