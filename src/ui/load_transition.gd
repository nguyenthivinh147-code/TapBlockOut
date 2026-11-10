extends "res://src/ui/stub_ui.gd"
## Wireframe 3.1 Load Level Transition. Layout of LoadLevelProcessVer2 (color-cube-match-puzzle): "icon" is a Mask
## shaped like bomb_(2) (graphic hidden) and its child "Background" a black CutoutMaskUI, which draws everywhere
## except inside that shape. InverseAnimateIconAsync shrinks the icon 10000 -> 0 units (0.8 s, EaseOutCubic), so
## the screen closes to black through a bomb-shaped hole. The game's level title is a copy of
## WarningHardLevelLayer's "Hard Level" text in the centre.
## level.gd plays the reverse (view.open, AnimateIcon): when the next level or a retry loads, the screen starts black
## with the level title and opens through the growing bomb-shaped hole over the new board, then the node frees
## itself (closed({"action": "done"})); taps are blocked meanwhile. Without view.open (UI gallery) it closes as the
## prefab does and a tap emits "tap". setup({view}): {level, open: bool}.
## The title is large candy text (white-to-lilac face, purple outline and drop shadow, scenes/load_transition.tscn) that pops in with an
## overshoot and, when opening, shrinks away over the end of the hole's growth.

const UnityUI := preload("res://src/ui/unity_ui.gd")

## LoadLevelProcessVer2.inverseAnimateIconSeconds (inverseAnimateIconEasing EaseOutCubic).
const CLOSE_SEC := 0.8
const ICON_MAX := 10000.0
## Black hold with the title before the hole opens (level.gd).
const OPEN_HOLD_SEC := 0.25
## Title pop: scale TITLE_FROM -> TITLE_PEAK in TITLE_POP_SEC (back ease), then -> 1 in TITLE_SETTLE_SEC.
const TITLE_FROM := 0.2
const TITLE_PEAK := 1.15
const TITLE_POP_SEC := 0.18
const TITLE_SETTLE_SEC := 0.14
## The title shrinks away (back ease in) over the last TITLE_OUT_SEC of the opening. Scale, not alpha: the glyphs'
## outlines overlap, so a see-through title shows the overlaps.
const TITLE_OUT_SEC := 0.3
## Baloo cap height, share of the font size (where the face gradient starts above the baseline).
const TITLE_CAP := 0.7

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
	var title: Label = %LevelTitle
	UnityUI.set_text(title, tr("level_title") % int(view.get("level", 1)))
	_place_gradient(title)
	var opening := bool(view.get("open", false))
	_set_icon(0.0 if opening else ICON_MAX)
	if UnityUI.baking:
		return
	_pop_title(title)
	if opening:
		# AnimateIconAsync: the hole grows from nothing over the new board (ease in, the reverse of the close).
		var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_interval(OPEN_HOLD_SEC)
		tw.tween_method(_set_icon, 0.0, ICON_MAX, CLOSE_SEC)
		tw.parallel().tween_property(title, "scale", Vector2.ZERO, TITLE_OUT_SEC).set_delay(CLOSE_SEC - TITLE_OUT_SEC) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			_send("done")
			queue_free())
		return
	# InverseAnimateIconAsync.
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_icon, ICON_MAX, 0.0, CLOSE_SEC)


## Fits the face gradient (tmp_text.gdshader grad_*) to the letters at the size auto size chose: from the cap top to
## the baseline of the one centred line. On its own copy of the material: the scene's is shared (SceneCache).
func _place_gradient(title: Label) -> void:
	if not title.material is ShaderMaterial:
		return
	var mat := title.material.duplicate() as ShaderMaterial
	title.material = mat
	var font := title.get_theme_font("font")
	var fs := title.get_theme_font_size("font_size")
	var baseline := (title.size.y - font.get_height(fs)) * 0.5 + font.get_ascent(fs)
	mat.set_shader_parameter("grad_y0", baseline - TITLE_CAP * fs)
	mat.set_shader_parameter("grad_y1", baseline)


## Springs the title up from small with an overshoot (pivot at its centre, set in the scene).
func _pop_title(title: Label) -> void:
	title.scale = Vector2.ONE * TITLE_FROM
	var tw := create_tween()
	tw.tween_property(title, "scale", Vector2.ONE * TITLE_PEAK, TITLE_POP_SEC) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(title, "scale", Vector2.ONE, TITLE_SETTLE_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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
		if not bool(view.get("open", false)):
			_send("tap")
