extends "res://src/ui/stub_ui.gd"
## Wireframe 11.3 Reward Claimed và 6.3 Purchase Success: nhận thưởng chung. Chưa nối logic.

func _sample() -> Dictionary:
	return SampleData.REWARD


func _title() -> String:
	return tr("ads_reward_title")


func _opts() -> Dictionary:
	return {"banner": "win"}


func _fill(box: VBoxContainer) -> void:
	box.add_child(ThemeKit.make_sprite("big_coin", 170))
	box.add_child(_centered_gold(tr("win_reward") % int(view.gold)))
	box.add_child(_btn(tr("daily_claim"), "primary", "claim"))
	box.add_child(_btn(tr("ads_reward_x2"), "video", "claim_x2", "ui_video"))


func _centered_gold(content: String) -> Label:
	var l := ThemeKit.gold_label(content, ThemeKit.FS_TITLE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
