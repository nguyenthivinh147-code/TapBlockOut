extends "res://src/ui/stub_ui.gd"
## Wireframe 1.6 No Internet: mất kết nối. Chưa nối logic.

func _title() -> String:
	return tr("boot_offline_title")


func _fill(box: VBoxContainer) -> void:
	box.add_child(ThemeKit.make_icon("ic_wifi", 150))
	box.add_child(_say(tr("boot_offline_lost"), ThemeKit.FS_BODY, ThemeKit.BROWN))
	box.add_child(_say(tr("boot_offline_body")))
	box.add_child(_btn(tr("boot_retry"), "primary", "retry"))
