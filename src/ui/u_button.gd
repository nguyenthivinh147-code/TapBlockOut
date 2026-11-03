extends Button
## Unity Button / Toggle. The child "image" (u_image.gd) draws the button's own Image; the tint follows
## Selectable.ColorTint on the target graphic, the press pulse follows UIHoldAnim_Pulse. The hit area grows to
## MIN_HIT screen px around the art, which keeps the prefab's size.
## Listen to `clicked`: it skips a press that a ScrollRect drag took over (`pressed` still fires for tests).

signal clicked

## Touch target, screen px.
const MIN_HIT := 96.0

## Button being held, so a ScrollRect drag can cancel it.
static var active: Button = null

var image: Control = null
var tint_target: CanvasItem = null
## ColorTint colors: normal, highlighted, pressed, disabled (already multiplied by colorMultiplier).
@export var tint_colors: Array[Color] = [Color.WHITE, Color("f5f5f5"), Color("c8c8c8"), Color(0.784, 0.784, 0.784, 0.5)]
@export var tint_dur := 0.1
## Selectable.Transition: 0 none, 1 color tint, 2 sprite swap, 3 animation.
@export var transition := 1
@export var pressed_sprite: Dictionary = {}
## UIHoldAnim_Pulse: scale while held (0 = off).
@export var pulse_scale := 0.0
@export var pulse_dur := 0.15
@export var pulse_trans := Tween.TRANS_QUAD
@export var pulse_ease := Tween.EASE_OUT
## PressEffect: [[CanvasItem, normal Color, pressed Color, duration], ...].
var press_effects: Array = []
@export var sound := false
@export var vibrate := false
## Toggle graphic shown while on.
var toggle_graphic: CanvasItem = null

var _cancel := false
var _tint_tw: Tween = null
var _pulse_tw: Tween = null
var _normal_sprite: Dictionary = {}


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed", "normal_mirrored", "hover_mirrored", "pressed_mirrored", "disabled_mirrored", "hover_pressed_mirrored"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())


func _ready() -> void:
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	pressed.connect(_on_pressed)
	toggled.connect(_on_toggled)
	_apply_tint(3 if disabled else 0, false)


func set_interactable(on: bool) -> void:
	disabled = not on
	_apply_tint(0 if on else 3, false)


## Drop the current press (a ScrollRect started dragging): no click on release.
func cancel_press() -> void:
	_cancel = true
	_release_visuals()


func _on_down() -> void:
	_cancel = false
	active = self
	_apply_tint(2, true)
	if transition == 2 and image != null and not pressed_sprite.is_empty():
		_normal_sprite = {"tex": image.tex, "region": image.region}
		image.set_texture(pressed_sprite.tex, pressed_sprite.region, image.border, image.border_scale)
	if pulse_scale > 0.0:
		_pulse(Vector2.ONE * pulse_scale)
	for e in press_effects:
		_color_to(e[0], e[2], e[3])


func _on_up() -> void:
	if active == self:
		active = null
	_release_visuals()


func _release_visuals() -> void:
	_apply_tint(3 if disabled else 0, true)
	if not _normal_sprite.is_empty() and image != null:
		image.set_texture(_normal_sprite.tex, _normal_sprite.region, image.border, image.border_scale)
		_normal_sprite = {}
	if pulse_scale > 0.0:
		_pulse(Vector2.ONE)
	for e in press_effects:
		_color_to(e[0], e[1], e[3])


func _on_pressed() -> void:
	if _cancel:
		_cancel = false
		return
	if sound:
		var sfx := get_node_or_null("/root/Sfx")
		if sfx != null:
			sfx.call("play", "button")
	if vibrate:
		var game := get_node_or_null("/root/Game")
		if game != null and game.has_method("haptic"):
			game.call("haptic", 20)
	clicked.emit()


func _on_toggled(on: bool) -> void:
	if toggle_graphic != null:
		toggle_graphic.visible = on


func _apply_tint(state: int, animate: bool) -> void:
	if transition != 1 or tint_target == null:
		return
	var c: Color = tint_colors[state]
	if _tint_tw != null:
		_tint_tw.kill()
	if animate and tint_dur > 0.0 and is_inside_tree():
		_tint_tw = create_tween()
		_tint_tw.tween_property(tint_target, "self_modulate", c, tint_dur)
	else:
		tint_target.self_modulate = c


func _pulse(to: Vector2) -> void:
	if _pulse_tw != null:
		_pulse_tw.kill()
	if not is_inside_tree():
		scale = to
		return
	_pulse_tw = create_tween().set_trans(pulse_trans).set_ease(pulse_ease)
	_pulse_tw.tween_property(self, "scale", to, pulse_dur)


func _color_to(target: CanvasItem, c: Color, dur: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not is_inside_tree() or dur <= 0.0:
		target.self_modulate = c
		return
	create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(target, "self_modulate", c, dur)


## Art keeps the prefab size; the hit area grows to MIN_HIT screen px around its center.
func _has_point(point: Vector2) -> bool:
	return hit_rect().has_point(point)


## Hit rect in local units.
func hit_rect() -> Rect2:
	var r := Rect2(Vector2.ZERO, size)
	var px := _px_per_unit()
	if px.x <= 0.0 or px.y <= 0.0:
		return r
	var gx := maxf(0.0, (MIN_HIT / px.x - r.size.x) * 0.5)
	var gy := maxf(0.0, (MIN_HIT / px.y - r.size.y) * 0.5)
	return r.grow_individual(gx, gy, gx, gy)


## Hit size in viewport px (720-wide space; tests check MIN_HIT).
func hit_size() -> Vector2:
	return hit_rect().size * _px_per_unit()


## Viewport px per canvas unit from the CanvasScaler root, so reveal and press animations do not shrink it.
func _px_per_unit() -> Vector2:
	if not is_inside_tree():
		return Vector2.ONE
	var p := get_parent()
	while p != null and not (p is Control and (p as Control).has_meta("u_canvas")):
		p = p.get_parent()
	var s := (p as Control).get_global_transform_with_canvas().get_scale() if p != null else get_global_transform_with_canvas().get_scale()
	return Vector2(absf(s.x), absf(s.y))
