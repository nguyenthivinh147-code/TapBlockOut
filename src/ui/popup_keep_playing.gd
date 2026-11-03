extends "res://src/ui/stub_ui.gd"
## Wireframe 4.6 Keep Playing?: xác nhận bỏ lượt mất mạng. Chưa nối logic.

func _title() -> String:
	return tr("lose_keep_title")


func _fill(box: VBoxContainer) -> void:
	box.add_child(ThemeKit.make_sprite("big_heart_broken", 170))
	box.add_child(_say(tr("lose_keep_body"), ThemeKit.FS_BODY))
	box.add_child(PopupKit.row([_btn(tr("level_restart_no"), "primary", "keep"), _btn(tr("lose_keep_quit"), "danger", "quit")]))
	box.add_child(_say(tr("lose_keep_note"), ThemeKit.FS_SMALL, ThemeKit.INK_DIM))
