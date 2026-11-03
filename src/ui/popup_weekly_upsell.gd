extends "res://src/ui/stub_ui.gd"
## Wireframe 7.5 Weekly Pass Upsell: giới thiệu Weekly Pass. Chưa nối logic.

func _sample() -> Dictionary:
	return SampleData.WEEKLY_UPSELL


func _title() -> String:
	return tr("weekly_title")


func _fill(box: VBoxContainer) -> void:
	box.add_child(ThemeKit.make_icon("shop_gold_pack_6", 190))
	box.add_child(_check_row(tr("weekly_upsell_one")))
	box.add_child(_check_row(tr("weekly_upsell_two")))
	box.add_child(_check_row(tr("weekly_upsell_three")))
	box.add_child(_btn(str(view.price), "gold", "buy"))
	box.add_child(_say(tr("weekly_time_left") % str(view.ends_in), ThemeKit.FS_SMALL, ThemeKit.INK_DIM))
