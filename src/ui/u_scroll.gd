extends Node
## Unity ScrollRect on the parent control: drag, elastic bounds (SmoothDamp), inertia (decelerationRate).
## Buttons inside the content get MOUSE_FILTER_PASS from unity_ui.gd so drags reach this host; a drag past
## DRAG_THRESHOLD cancels the held u_button so releasing does not click it.

const UButton := preload("res://src/ui/u_button.gd")

## EventSystem.pixelDragThreshold (10 px on a 1080-wide reference) in 720-wide viewport px.
const DRAG_THRESHOLD := 7.0

var host: Control = null
var viewport: Control = null
var content: Control = null
var horizontal := false
var vertical := true
## 0 unrestricted, 1 elastic, 2 clamped.
var movement := 1
var elasticity := 0.1
var inertia := true
var deceleration := 0.135
var wheel := 1.0
var velocity := Vector2.ZERO

var _down := false
var _dragging := false
var _press := Vector2.ZERO
var _start := Vector2.ZERO
var _prev := Vector2.ZERO


func setup(h: Control, vp: Control, c: Control, cfg: Dictionary) -> void:
	host = h
	viewport = vp if vp != null else h
	content = c
	horizontal = bool(cfg.get("h", false))
	vertical = bool(cfg.get("v", true))
	movement = int(cfg.get("move", 1))
	elasticity = float(cfg.get("elastic", 0.1))
	inertia = bool(cfg.get("inertia", true))
	deceleration = float(cfg.get("decel", 0.135))
	wheel = float(cfg.get("wheel", 1.0))
	if host.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		host.mouse_filter = Control.MOUSE_FILTER_PASS
	host.gui_input.connect(_on_input)


## Scroll so content's top-left is at `pos` (viewport local units); stops motion.
func set_content_position(pos: Vector2) -> void:
	if content == null:
		return
	content.position = pos
	velocity = Vector2.ZERO


## 0..1 like ScrollRect.verticalNormalizedPosition (1 = top).
func set_vertical_normalized(v: float) -> void:
	if content == null:
		return
	var span := content.size.y - viewport.size.y
	if span <= 0.0:
		return
	content.position.y = -span * (1.0 - clampf(v, 0.0, 1.0))
	velocity = Vector2.ZERO


func _on_input(e: InputEvent) -> void:
	if content == null:
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_down = true
				_dragging = false
				_press = _local(mb.global_position)
				_start = content.position
			else:
				_down = false
				_dragging = false
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var dir := 1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
			var step := Vector2(0, dir * 20.0 * wheel) if vertical else Vector2(dir * 20.0 * wheel, 0)
			content.position = _clamp_if_needed(content.position + step)
	elif e is InputEventMouseMotion and _down:
		var p := _local((e as InputEventMouseMotion).global_position)
		if not _dragging:
			var px := (p - _press) * _px_per_unit()
			if px.length() < DRAG_THRESHOLD:
				return
			_dragging = true
			_press = p
			_start = content.position
			var held: Button = UButton.active
			if held != null and is_instance_valid(held) and host.is_ancestor_of(held):
				held.call("cancel_press")
		var d := p - _press
		var target := _start + Vector2(d.x if horizontal else 0.0, d.y if vertical else 0.0)
		var off := _offset(target)
		if movement == 1:
			target -= off
			if off.x != 0.0:
				target.x += _rubber(off.x, viewport.size.x)
			if off.y != 0.0:
				target.y += _rubber(off.y, viewport.size.y)
		elif movement == 2:
			target -= off
		content.position = target


func _process(delta: float) -> void:
	if content == null or delta <= 0.0:
		return
	var pos := content.position
	if _dragging:
		if inertia:
			velocity = velocity.lerp((pos - _prev) / delta, minf(1.0, delta * 10.0))
		_prev = pos
		return
	var off := _offset(pos)
	if off == Vector2.ZERO and velocity == Vector2.ZERO:
		_prev = pos
		return
	for axis in 2:
		if (axis == 0 and not horizontal) or (axis == 1 and not vertical):
			velocity[axis] = 0.0
			continue
		if movement == 1 and off[axis] != 0.0:
			var res := _smooth_damp(pos[axis], pos[axis] - off[axis], velocity[axis], elasticity, delta)
			pos[axis] = res.x
			velocity[axis] = res.y if absf(res.y) >= 1.0 else 0.0
		elif inertia:
			velocity[axis] *= pow(deceleration, delta)
			if absf(velocity[axis]) < 1.0:
				velocity[axis] = 0.0
			pos[axis] += velocity[axis] * delta
		else:
			velocity[axis] = 0.0
	if movement == 2:
		pos -= _offset(pos)
	content.position = pos
	_prev = pos


## How far content at `pos` is outside the viewport bounds (positive: too far down/right).
func _offset(pos: Vector2) -> Vector2:
	var off := Vector2.ZERO
	var view := viewport.size
	var csize := content.size * content.scale
	for axis in 2:
		var lo := pos[axis]
		var hi := pos[axis] + csize[axis]
		if csize[axis] <= view[axis]:
			# Smaller than the view: keep it at the start edge (Unity keeps it by pivot; top/left for lists).
			off[axis] = lo
		elif lo > 0.0:
			off[axis] = lo
		elif hi < view[axis]:
			off[axis] = hi - view[axis]
	return off


func _clamp_if_needed(pos: Vector2) -> Vector2:
	return pos - _offset(pos) if movement != 0 else pos


## ScrollRect.RubberDelta.
static func _rubber(over: float, view_size: float) -> float:
	if view_size <= 0.0:
		return 0.0
	return (1.0 - 1.0 / (absf(over) * 0.55 / view_size + 1.0)) * view_size * signf(over)


## Mathf.SmoothDamp; returns (position, velocity).
static func _smooth_damp(cur: float, target: float, vel: float, smooth_time: float, dt: float) -> Vector2:
	smooth_time = maxf(0.0001, smooth_time)
	var omega := 2.0 / smooth_time
	var x := omega * dt
	var e := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := cur - target
	var orig := target
	var temp := (vel + omega * change) * dt
	vel = (vel - omega * temp) * e
	var out := target + (change + temp) * e
	if (orig - cur > 0.0) == (out > orig):
		out = orig
		vel = (out - orig) / dt
	return Vector2(out, vel)


func _local(global_pos: Vector2) -> Vector2:
	return viewport.get_global_transform_with_canvas().affine_inverse() * global_pos


func _px_per_unit() -> Vector2:
	var s := viewport.get_global_transform_with_canvas().get_scale()
	return Vector2(absf(s.x), absf(s.y))
