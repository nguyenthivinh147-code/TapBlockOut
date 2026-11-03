extends "res://src/ui/stub_ui.gd"
## Wireframe 4.7 Out of Space + Helper Pack: cứu lượt kèm gói trợ giúp. Chưa nối logic.

func _sample() -> Dictionary:
	return SampleData.HELPER_PACK


func _title() -> String:
	return tr("rescue_title")


func _opts() -> Dictionary:
	return {"banner": "red"}


func _fill(box: VBoxContainer) -> void:
	box.add_child(_say(tr("rescue_body")))
	box.add_child(PopupKit.row([_btn(tr("common_free"), "video", "free", "ui_video"), _btn(str(int(view.gold)), "gold", "gold", "ui_gold")]))
	var well := ThemeKit.make_well(ThemeKit.WELL_HOT, ThemeKit.WELL_HEADER)
	box.add_child(well)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	well.add_child(v)
	v.add_child(_say(tr("lose_helper_title"), ThemeKit.FS_BODY, ThemeKit.BROWN))
	v.add_child(PopupKit.row([
		PopupKit.reward_tile(ThemeKit.icon("shop_gold_pack_5"), tr("lose_helper_chest"), 64),
		_hint_tile(1, 64),
		PopupKit.reward_tile(ThemeKit.icon("booster_move"), tr("booster_move"), 64),
	], 6))
	v.add_child(_btn(str(view.price), "primary", "buy_pack"))
