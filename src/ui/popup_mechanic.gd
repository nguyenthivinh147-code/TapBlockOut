extends "res://src/ui/stub_ui.gd"
## Wireframe 3.3 New Mechanic Intro: giới thiệu cơ chế mới. Chưa nối logic.

func _sample() -> Dictionary:
	return SampleData.MECHANIC


func _title() -> String:
	return tr("level_new_mechanic")


func _fill(box: VBoxContainer) -> void:
	var m := str(view.mech)
	box.add_child(ThemeKit.make_icon("mech_" + m, 200))
	box.add_child(_say(tr("mech_" + m), ThemeKit.FS_BUTTON, ThemeKit.BROWN))
	box.add_child(_say(tr("mech_%s_desc" % m)))
	box.add_child(_btn(tr("mech_got_it"), "primary", "ok"))
