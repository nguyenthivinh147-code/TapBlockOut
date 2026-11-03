extends "res://src/ui/stub_ui.gd"
## Wireframe 8.4 Weekly Result: kết quả tuần. Chưa nối logic.

func _sample() -> Dictionary:
	return SampleData.LB_RESULT


func _title() -> String:
	return tr("lb_result_title")


func _fill(box: VBoxContainer) -> void:
	box.add_child(ThemeKit.make_sprite("big_trophy", 180))
	box.add_child(_say(tr("lb_result_rank") % int(view.rank), ThemeKit.FS_BODY, ThemeKit.BROWN))
	box.add_child(_say(tr("lb_result_promoted") % tr("lb_league_" + str(view.promoted_to)), ThemeKit.FS_SMALL + 2, ThemeKit.INK_GOOD))
	box.add_child(PopupKit.row([_gold_tile(int(view.gold)), _hint_tile(int(view.hint))]))
	box.add_child(_btn(tr("daily_claim"), "primary", "claim"))
