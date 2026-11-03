extends "res://src/ui/stub_ui.gd"
## Wireframe 11.1 Rewarded Ad Loading: chờ quảng cáo. Chưa nối logic.

func _build() -> void:
	var col := _overlay()
	var clock := ThemeKit.make_sprite("big_clock", 170)
	col.add_child(clock)
	col.add_child(_shout(tr("ads_loading"), ThemeKit.FS_BODY))
	clock.pivot_offset = Vector2(85, 85)
	var spin := clock.create_tween().set_loops()
	spin.tween_property(clock, "rotation", TAU, 1.4).from(0.0)
