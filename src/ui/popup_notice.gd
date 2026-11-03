extends "res://src/ui/stub_ui.gd"
## Wireframe 11.2 Ad Not Available: thông báo chung một nút OK. Chưa nối logic.

func _title() -> String:
	return tr(str(view.get("title", "ads_notice_title")))


func _fill(box: VBoxContainer) -> void:
	box.add_child(ThemeKit.make_sprite("big_tv", 150))
	box.add_child(_say(tr(str(view.get("body", "ads_not_available")))))
	box.add_child(_btn(tr("common_ok"), "primary", "ok"))
