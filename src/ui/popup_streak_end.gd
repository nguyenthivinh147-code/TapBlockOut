extends "res://src/ui/stub_ui.gd"
## Wireframe 9.4 Streak Ended: kết thúc chuỗi, nhận thưởng. Chưa nối logic.

func _sample() -> Dictionary:
	return SampleData.STREAK_END


func _title() -> String:
	return tr("streak_end_title")


func _opts() -> Dictionary:
	return {"banner": "lose"}


func _fill(box: VBoxContainer) -> void:
	box.add_child(ThemeKit.make_icon("avatar_02", 170))
	box.add_child(_say(tr("streak_end_final") % int(view.streak), ThemeKit.FS_BODY, ThemeKit.BROWN))
	box.add_child(_say(tr("streak_end_ready")))
	box.add_child(PopupKit.row([
		_gold_tile(int(view.gold)),
		_hint_tile(int(view.hint)),
		PopupKit.reward_tile(ThemeKit.icon("ic_giftbox3"), tr("streak_chest"), 80),
	], 8))
	box.add_child(_btn(tr("daily_claim"), "primary", "claim"))
