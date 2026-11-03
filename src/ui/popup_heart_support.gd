extends "res://src/ui/stub_ui.gd"
## Wireframe 5.3 Heart Support Pack: gói mạng khi hết mạng. Chưa nối logic.

func _sample() -> Dictionary:
	return SampleData.HEART_SUPPORT


func _title() -> String:
	return tr("hearts_support_title")


func _fill(box: VBoxContainer) -> void:
	box.add_child(ThemeKit.make_sprite("big_heart", 200))
	box.add_child(_say(tr("hearts_support_body")))
	box.add_child(_btn(tr("hearts_support_buy") % str(view.price), "gold", "buy"))
	box.add_child(_btn(tr("hearts_support_refill"), "ghost", "refill"))
