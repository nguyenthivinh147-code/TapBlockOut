extends "res://src/ui/stub_ui.gd"
## Wireframe 9.5 Keep Your Streak?: giữ chuỗi bằng quảng cáo. Chưa nối logic.

func _sample() -> Dictionary:
	return SampleData.STREAK_KEEP


func _title() -> String:
	return tr("streak_keep_title")


func _fill(box: VBoxContainer) -> void:
	box.add_child(ThemeKit.make_sprite("big_clock", 160))
	box.add_child(_say(tr("streak_row") % int(view.streak), ThemeKit.FS_BUTTON, ThemeKit.BROWN))
	box.add_child(_say(tr("streak_keep_reset"), ThemeKit.FS_SMALL + 4, ThemeKit.INK_DANGER))
	box.add_child(_say(tr("streak_keep_body")))
	box.add_child(PopupKit.row([_btn(tr("streak_keep_ad"), "video", "continue", "ui_video"), _btn(tr("lose_keep_quit"), "danger", "quit")]))
