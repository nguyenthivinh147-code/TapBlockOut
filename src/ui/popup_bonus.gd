extends "res://src/ui/stub_ui.gd"
## Wireframe 4.2 Bonus Multiplier: chạm dừng mũi tên để nhân thưởng. Chưa nối logic.

func _sample() -> Dictionary:
	return SampleData.BONUS


func _title() -> String:
	return tr("win_bonus_title")


func _opts() -> Dictionary:
	return {"banner": "win"}


func _fill(box: VBoxContainer) -> void:
	box.add_child(_say(tr("win_bonus_tap")))
	box.add_child(ThemeKit.make_icon("ic_arrow", 56))
	var strip := PanelContainer.new()
	strip.custom_minimum_size = Vector2(PopupKit.CONTENT_W, 104)
	strip.add_theme_stylebox_override("panel", UiAtlas.box("bar_rainbow", Vector4(40, 30, 40, 30), Vector4(10, 8, 10, 12)))
	box.add_child(strip)
	var labels: Array = []
	for m in view.multipliers:
		var l := ThemeKit.make_label(tr("booster_count") % int(m), ThemeKit.FS_BODY)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		labels.append(l)
	strip.add_child(PopupKit.row(labels, 0))
	box.add_child(PopupKit.row([_gold_tile(int(view.coins), 96)]))
	box.add_child(_say(tr("win_bonus_total") % int(view.result), ThemeKit.FS_BODY, ThemeKit.BROWN))
	box.add_child(_btn(tr("win_bonus_claim"), "video", "claim", "ui_video"))
	box.add_child(_btn(tr("offer_no_thanks"), "ghost", "skip"))
