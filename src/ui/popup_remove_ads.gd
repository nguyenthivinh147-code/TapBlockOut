extends "res://src/ui/stub_ui.gd"
## Wireframe 2.4 Remove Ads: mua bỏ quảng cáo. Chưa nối logic.

func _sample() -> Dictionary:
	return SampleData.REMOVE_ADS


func _title() -> String:
	return tr("shop_remove_ads")


func _fill(box: VBoxContainer) -> void:
	box.add_child(ThemeKit.make_sprite("big_noads", 170))
	box.add_child(_check_row(tr("ads_noads_one")))
	box.add_child(_check_row(tr("ads_noads_two")))
	box.add_child(_check_row(tr("ads_noads_three")))
	box.add_child(_btn(tr("ads_noads_buy") % str(view.price), "gold", "buy"))
	box.add_child(_btn(tr("ads_noads_bundle") % str(view.bundle_price), "secondary", "buy_bundle"))
	box.add_child(_btn(tr("shop_restore"), "ghost", "restore"))
