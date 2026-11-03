extends "res://src/ui/stub_ui.gd"
## Wireframe 3.8 New Booster Unlocked: mở booster mới. Chưa nối logic.

func _sample() -> Dictionary:
	return SampleData.BOOSTER_UNLOCK


func _title() -> String:
	return tr("booster_new_title")


func _opts() -> Dictionary:
	return {"banner": "red"}


func _fill(box: VBoxContainer) -> void:
	box.add_child(_say(tr("booster_new_name"), ThemeKit.FS_BODY, ThemeKit.BROWN))
	box.add_child(ThemeKit.make_icon("booster_move", 180))
	box.add_child(ThemeKit.gold_label(tr("booster_count") % int(view.count), ThemeKit.FS_TITLE))
	box.get_child(-1).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_say(tr("booster_new_body")))
	box.add_child(_btn(tr("booster_buy") % int(view.price), "gold", "buy", "ui_gold"))
	box.add_child(_say(tr("boot_tap_continue"), ThemeKit.FS_SMALL, ThemeKit.INK_DIM))
