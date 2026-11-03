extends "res://src/ui/stub_ui.gd"
## Wireframe 1.5 First-time Tutorial: bàn tay chỉ khối đầu tiên. Chưa nối logic.

func _build() -> void:
	var col := _overlay(Color(ThemeKit.SCRIM, 0.55))
	col.add_child(ThemeKit.make_sprite("hand_tap", 220))
	col.add_child(_shout(tr("boot_tut_body"), ThemeKit.FS_BODY))
	col.add_child(_shout(tr("boot_tap_continue"), ThemeKit.FS_SMALL, ThemeKit.TEXT_DIM))
