extends "res://src/ui/stub_ui.gd"
## Wireframe 3.1 Load Level Transition. Layout of LoadLevelProcessVer2 (color-cube-match-puzzle): "icon" is a Mask
## shaped like bomb_(2) (graphic hidden) and its child "Background" a black CutoutMaskUI, which draws everywhere
## except inside that shape. InverseAnimateIconAsync shrinks the icon 10000 -> 0 units (0.8 s, EaseOutCubic), so
## the screen closes to black through a bomb-shaped hole. The game's level title is a copy of
## WarningHardLevelLayer's "Hard Level" text in the centre. A tap anywhere emits "tap", as before. Not wired to logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")

## LoadLevelProcessVer2.inverseAnimateIconSeconds (inverseAnimateIconEasing EaseOutCubic).
const CLOSE_SEC := 0.8
const ICON_MAX := 10000.0

var _icon: Control = null


func _sample() -> Dictionary:
	return SampleData.TRANSITION


func _build() -> void:
	# scenes/load_transition.tscn stretches the prefab root (a zero rect at scale 0, sized by whoever shows it) over
	# the screen and holds LevelTitle (WarningHardLevelLayer's "Hard Level" text) in the centre.
	ui = UnityUI.build(self, "LoadLevelProcessVer2")
	# Also at runtime: a scene does not keep an instanced node's property set back to its class default (anchor_top
	# 0, scale 1).
	var root: Control = ui.node("")
	var rr: Dictionary = root.get_meta("u_rect")
	rr.amin = Vector2.ZERO
	rr.amax = Vector2.ONE
	rr.pos = Vector2.ZERO
	rr.size = Vector2.ZERO
	UnityUI.apply_rect(root)
	root.scale = Vector2.ONE
	_icon = ui.node("icon")
	UnityUI.set_text(%LevelTitle, tr("level_title") % int(view.get("level", 1)))
	_set_icon(ICON_MAX)
	# InverseAnimateIconAsync.
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_icon, ICON_MAX, 0.0, CLOSE_SEC)


## LerpRectSizeFromToWithEasingAsync step: icon sizeDelta = (s, s).
func _set_icon(s: float) -> void:
	if not is_instance_valid(_icon):
		return
	var r: Dictionary = _icon.get_meta("u_rect")
	r.size = Vector2(s, s)
	UnityUI.apply_rect(_icon)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_send("tap")
