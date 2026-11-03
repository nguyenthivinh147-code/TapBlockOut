extends "res://src/ui/stub_ui.gd"
## Wireframe 2.3 ADS Daily: xem quảng cáo để đầy thanh thưởng. Chưa nối logic.

func _sample() -> Dictionary:
	return SampleData.ADS_DAILY


func _title() -> String:
	return tr("home_ads_daily")


func _fill(box: VBoxContainer) -> void:
	box.add_child(_say(tr("ads_daily_sub"), ThemeKit.FS_SMALL + 2, ThemeKit.INK_DIM))
	var tiles: Array = []
	for r in view.rewards:
		tiles.append(PopupKit.reward_tile(ThemeKit.icon("ui_gift"), tr("booster_count") % int(r), 72))
	box.add_child(PopupKit.row(tiles, 8))
	box.add_child(_bar(float(view.watched) / float(view.total)))
	box.add_child(_say(tr("ads_daily_progress") % [int(view.watched), int(view.total)], ThemeKit.FS_SMALL, ThemeKit.INK_DIM))
	box.add_child(_btn(tr("ads_daily_watch"), "video", "watch", "ui_video"))
	box.add_child(_say(tr("ads_daily_reset"), ThemeKit.FS_SMALL, ThemeKit.INK_DIM))
