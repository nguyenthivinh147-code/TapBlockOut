extends "res://src/ui/stub_ui.gd"
## Wireframe 8.3 Leagues: các hạng và thưởng tuần. Chưa nối logic.

func _sample() -> Dictionary:
	return SampleData.LEAGUES


func _title() -> String:
	return tr("lb_leagues_title")


func _fill(box: VBoxContainer) -> void:
	box.add_child(_say(tr("lb_leagues_sub"), ThemeKit.FS_SMALL + 2, ThemeKit.INK_DIM))
	for r in view.rows:
		var cur := str(r.id) == str(view.current)
		var well := ThemeKit.make_well(ThemeKit.WELL_HOT if cur else ThemeKit.WELL, ThemeKit.WELL_HEADER if cur else Color(0, 0, 0, 0))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		well.add_child(h)
		h.add_child(ThemeKit.make_icon("cup_" + str(r.id), 96))
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(v)
		v.add_child(ThemeKit.ink_label(tr("lb_league_" + str(r.id)), ThemeKit.FS_SMALL + 6, ThemeKit.BROWN))
		v.add_child(ThemeKit.ink_label(tr("lb_weekly_reward") % int(r.gold), ThemeKit.FS_SMALL - 2))
		if cur:
			var c := ThemeKit.ink_label(tr("lb_current"), ThemeKit.FS_SMALL - 2, ThemeKit.INK_GOOD)
			c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			h.add_child(c)
		box.add_child(well)
