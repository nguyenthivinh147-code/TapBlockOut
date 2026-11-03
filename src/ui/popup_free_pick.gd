extends "res://src/ui/stub_ui.gd"
## Wireframe 3.9 Free Pick: dùng thử booster lần đầu. Chưa nối logic.

func _title() -> String:
	return tr("booster_new_short")


func _fill(box: VBoxContainer) -> void:
	box.add_child(_say(tr("booster_free_pick"), ThemeKit.FS_BUTTON, ThemeKit.BROWN))
	box.add_child(ThemeKit.make_sprite("hand_tap", 200))
	box.add_child(_say(tr("booster_free_pick_body")))
	box.add_child(_btn(tr("daily_claim"), "primary", "claim"))
