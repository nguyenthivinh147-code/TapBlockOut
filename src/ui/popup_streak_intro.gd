extends "res://src/ui/stub_ui.gd"
## Wireframe 9.1 Instruction: giới thiệu Win Streak. Chưa nối logic.

func _title() -> String:
	return tr("streak_title")


func _fill(box: VBoxContainer) -> void:
	box.add_child(ThemeKit.make_icon("avatar_01", 170))
	box.add_child(_step_row(1, tr("streak_intro_1")))
	box.add_child(_step_row(2, tr("streak_intro_2")))
	box.add_child(_step_row(3, tr("streak_intro_3")))
	box.add_child(_btn(tr("streak_go"), "primary", "go"))
