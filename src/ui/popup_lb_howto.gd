extends "res://src/ui/stub_ui.gd"
## Wireframe 8.2 How it works: luật xếp hạng. Chưa nối logic.

const ART := ["howto_win", "howto_rows", "howto_promote", "ic_giftbox1"]


func _title() -> String:
	return tr("lb_howto_title")


func _fill(box: VBoxContainer) -> void:
	for i in ART.size():
		var well := ThemeKit.make_well()
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		well.add_child(h)
		h.add_child(ThemeKit.make_icon(ART[i], 110))
		var l := ThemeKit.ink_label(tr("lb_howto_%d" % (i + 1)), ThemeKit.FS_SMALL + 2)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(l)
		box.add_child(well)
	box.add_child(_btn(tr("mech_got_it"), "primary", "ok"))
