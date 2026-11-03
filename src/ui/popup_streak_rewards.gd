extends "res://src/ui/stub_ui.gd"
## Wireframe 9.3 Rewards Info: thưởng từng mốc. Chưa nối logic.


const ICONS := {"gold": "ui_gold", "hint": "booster_hint", "heart": "ui_heart", "chest": "ic_giftbox3"}

func _sample() -> Dictionary:
	return SampleData.STREAK_REWARDS


func _title() -> String:
	return tr("streak_rewards_title")


func _fill(box: VBoxContainer) -> void:
	for r in view.rows:
		var well := ThemeKit.make_well()
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		well.add_child(h)
		h.add_child(ThemeKit.make_icon(str(ICONS[str(r.kind)]), 72))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(v)
		v.add_child(ThemeKit.ink_label(tr("streak_row") % int(r.streak), ThemeKit.FS_SMALL + 4, ThemeKit.BROWN))
		v.add_child(ThemeKit.ink_label(tr("streak_reward_" + str(r.kind)) % int(r.amount), ThemeKit.FS_SMALL))
		box.add_child(well)
	box.add_child(_btn(tr("common_close"), "primary", "ok"))
	box.add_child(_say(tr("streak_rewards_note"), ThemeKit.FS_SMALL, ThemeKit.INK_DIM))
