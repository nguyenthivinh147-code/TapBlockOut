extends "res://src/ui/stub_ui.gd"
## Wireframe 8.2 How it works: luật xếp hạng. Chưa nối logic.

func _title() -> String:
	return tr("lb_howto_title")


func _fill(box: VBoxContainer) -> void:
	for i in 4:
		box.add_child(_step_row(i + 1, tr("lb_howto_%d" % (i + 1))))
	box.add_child(_btn(tr("mech_got_it"), "primary", "ok"))
