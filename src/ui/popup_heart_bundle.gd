extends "res://src/ui/stub_ui.gd"
## Wireframe 5.2 Heart Bundle Offer: mạng vô hạn theo giờ. Chưa nối logic.

func _sample() -> Dictionary:
	return SampleData.HEART_BUNDLE


func _title() -> String:
	return tr("hearts_bundle_title")


func _fill(box: VBoxContainer) -> void:
	box.add_child(ThemeKit.make_sprite("big_heart_inf", 170))
	box.add_child(_say(tr("hearts_bundle_body"), ThemeKit.FS_SMALL + 4, ThemeKit.BROWN))
	for r in view.rows:
		var well := ThemeKit.make_well()
		var h := HBoxContainer.new()
		well.add_child(h)
		var l := ThemeKit.ink_label(tr("hearts_hour_one") if int(r.hours) == 1 else tr("hearts_hours") % int(r.hours), ThemeKit.FS_BODY)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(l)
		var b := _btn(str(r.price), "primary", "buy_%d" % int(r.hours))
		b.custom_minimum_size.x = 170
		h.add_child(b)
		box.add_child(well)
	box.add_child(_say(tr("offer_time_left") % str(view.ends_in), ThemeKit.FS_SMALL, ThemeKit.INK_DIM))
