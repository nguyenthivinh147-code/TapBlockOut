extends "res://src/ui/stub_ui.gd"
## Wireframe 1.2 Check Update: có bản mới. Chưa nối logic.

func _title() -> String:
	return tr("boot_update_title")


func _fill(box: VBoxContainer) -> void:
	box.add_child(ThemeKit.make_sprite("big_settings", 160))
	box.add_child(_say(tr("boot_update_body")))
	box.add_child(_btn(tr("boot_update_now"), "primary", "update"))
	box.add_child(_btn(tr("boot_later"), "ghost", "later"))
