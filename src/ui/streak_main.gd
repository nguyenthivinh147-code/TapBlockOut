extends "res://src/ui/stub_ui.gd"
## Wireframe 9.2 Win Streak Main: đường mốc chuỗi thắng. Chưa nối logic.

func _sample() -> Dictionary:
	return SampleData.STREAK_MAIN


func _full_screen() -> bool:
	return true


func _title() -> String:
	return tr("streak_title")


func _fill(box: VBoxContainer) -> void:
	box.add_child(_say(tr("streak_ends") % str(view.ends_in), ThemeKit.FS_SMALL, ThemeKit.INK_DIM))
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	head.add_child(ThemeKit.ink_label(tr("streak_current"), ThemeKit.FS_SMALL + 4, ThemeKit.BROWN))
	head.add_child(ThemeKit.gold_label(str(int(view.streak)), ThemeKit.FS_TITLE))
	var info := ThemeKit.make_icon_button("ui_info")
	info.pressed.connect(_act.bind("info"))
	head.add_child(info)
	for m in view.milestones:
		box.add_child(_milestone(int(m)))
	box.add_child(_btn(tr("home_play"), "primary", "play"))


func _milestone(m: int) -> Control:
	var done := int(view.streak) >= m
	var well := ThemeKit.make_well(ThemeKit.WELL_HOT if done else ThemeKit.WELL)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	well.add_child(h)
	var badge := ThemeKit.make_sprite("node_green" if done else "node_gray", 110)
	h.add_child(badge)
	var num := ThemeKit.make_label(str(m), ThemeKit.FS_BUTTON)
	num.set_anchors_preset(Control.PRESET_FULL_RECT)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(num)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)
	h.add_child(ThemeKit.make_icon("ic_giftbox2" if done else "ic_giftbox1", 96))
	return well
