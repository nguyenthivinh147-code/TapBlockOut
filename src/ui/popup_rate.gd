extends "res://src/ui/stub_ui.gd"
## Wireframe 4.3 Rate Us: xin đánh giá. Chưa nối logic.

func _title() -> String:
	return tr("win_rate_title")


func _fill(box: VBoxContainer) -> void:
	box.add_child(_say(tr("win_rate_body")))
	var stars: Array = []
	for i in 5:
		stars.append(ThemeKit.make_sprite("star_gold", 84))
	box.add_child(PopupKit.row(stars, 4))
	box.add_child(_btn(tr("common_yes"), "primary", "rate"))
