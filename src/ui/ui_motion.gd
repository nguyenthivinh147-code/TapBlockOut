extends Node
## Looping motion on the parent control. PULSE: glow and light-ray effects (sprites fx_1, light1; Home's Glow)
## breathe in scale. AD_HOP: a video-ad icon crouches, hops, squashes on landing and wiggles, then rests.
## The motion is added on top of the control's own position, scale and rotation: a value written by someone else
## (layout, a SimpleUIRotator spin, a press pulse) becomes the new base, so it never drifts. While the control is
## hidden the motion pauses with the base restored. UnityUI adds it by sprite (attach_by_sprite); never while baking.

enum { PULSE, AD_HOP }

const SCRIPT_PATH := "res://src/ui/ui_motion.gd"
const NODE_NAME := "Motion"
## _sprites.json keys of the video-ad icons: TV and clapperboard. Resources_moved_UI_Maincenter_7 is a clock.
const AD_SPRITES := ["Resources_moved_UI_Maincenter:UI_Maincenter_5", "Resources_UI_Maincenter:UI_Maincenter_7"]
const PULSE_SPRITES := ["fx_1", "light1"]

## PULSE: scale 1 -> 1 + PULSE_SCALE -> 1 over PULSE_SEC (sine).
const PULSE_SCALE := 0.1
const PULSE_SEC := 1.4
## AD_HOP: one hop every HOP_PERIOD s, the first after HOP_DELAY (past a popup's 0.4 s reveal).
const HOP_PERIOD := 2.0
const HOP_DELAY := 0.5
## Phase ends (s into the period): crouch, air, landing squash, wiggle; the rest of the period is still.
const HOP_CROUCH := 0.08
const HOP_AIR := 0.4
const HOP_LAND := 0.52
const HOP_WIGGLE := 1.0
## Jump height (share of the icon's height), squash and stretch (scale x + q, y - q), wiggle tilt and swings.
const HOP_HEIGHT := 0.15
const HOP_SQUASH := 0.12
const HOP_STRETCH := 0.06
const HOP_LAND_SQUASH := 0.1
const HOP_TILT_DEG := 12.0
const HOP_SWINGS := 3.0

var kind := PULSE
var time := 0.0

var _host: Control = null
var _base_pos := Vector2.ZERO
var _base_scale := Vector2.ONE
var _base_rot := 0.0
# What this node last wrote; a different value on the host was written by someone else and is the new base.
var _set_pos := Vector2.INF
var _set_scale := Vector2.INF
var _set_rot := INF
var _moved := false


## Adds a motion of kind to c, unless c already has one; returns c's motion.
static func attach(c: Control, k: int) -> Node:
	var m := c.get_node_or_null(NODE_NAME)
	if m != null:
		return m
	m = (load(SCRIPT_PATH) as GDScript).new()
	m.setup(c, k)
	return m


## The motion a node drawing sprite key gets: AD_HOP for an ad icon, PULSE for a glow; -1 for none.
static func kind_for_sprite(key: Variant) -> int:
	if key is String:
		if AD_SPRITES.has(key):
			return AD_HOP
		if PULSE_SPRITES.has(key):
			return PULSE
	return -1


func setup(c: Control, k: int) -> void:
	_host = c
	kind = k
	name = NODE_NAME
	# Not saved by tools/bake_screen.gd and dropped from copies (UnityUI.strip_runtime).
	set_meta("u_rt", true)
	time = -HOP_DELAY if k == AD_HOP else 0.0
	c.add_child(self)


func _process(delta: float) -> void:
	if _host == null or not is_instance_valid(_host):
		return
	if not _host.is_visible_in_tree():
		_rest()
		return
	time += delta
	_sync()
	if kind == PULSE:
		_host.scale = _base_scale * (1.0 + PULSE_SCALE * (0.5 - 0.5 * cos(TAU * time / PULSE_SEC)))
	else:
		var pose := hop_pose(maxf(time, 0.0))
		var q: float = pose[1]
		var s := Vector2(1.0 + q, 1.0 - q)
		_host.scale = _base_scale * s
		_host.rotation = _base_rot + deg_to_rad(float(pose[2]))
		# Height from the icon's drawn size; a squash keeps the bottom edge planted (pivot at its center).
		var h := _host.size.y * absf(_base_scale.y)
		_host.position = _base_pos + Vector2(0.0, -float(pose[0]) * h + h * 0.5 * (1.0 - s.y))
		_set_pos = _host.position
		_set_rot = _host.rotation
	_set_scale = _host.scale
	_moved = true


## [lift (share of height), squash q (scale x + q, y - q), tilt (deg)] at t s from the first hop.
static func hop_pose(t: float) -> Array:
	var p := fposmod(t, HOP_PERIOD)
	if p < HOP_CROUCH:
		return [0.0, HOP_SQUASH * sin(PI * 0.5 * p / HOP_CROUCH), 0.0]
	if p < HOP_AIR:
		var u := (p - HOP_CROUCH) / (HOP_AIR - HOP_CROUCH)
		# Squash released into a stretch at take-off, gone by touch-down.
		return [HOP_HEIGHT * sin(PI * u), HOP_SQUASH * maxf(0.0, 1.0 - u * 5.0) - HOP_STRETCH * sin(PI * u), 0.0]
	if p < HOP_LAND:
		var u := (p - HOP_AIR) / (HOP_LAND - HOP_AIR)
		return [0.0, HOP_LAND_SQUASH * sin(PI * u), 0.0]
	if p < HOP_WIGGLE:
		var u := (p - HOP_LAND) / (HOP_WIGGLE - HOP_LAND)
		return [0.0, 0.0, HOP_TILT_DEG * sin(TAU * HOP_SWINGS * u) * (1.0 - u)]
	return [0.0, 0.0, 0.0]


## Takes as base any value someone else wrote since the last frame.
func _sync() -> void:
	if not _host.scale.is_equal_approx(_set_scale):
		_base_scale = _host.scale
	if kind == AD_HOP:
		if not _host.position.is_equal_approx(_set_pos):
			_base_pos = _host.position
		if not is_equal_approx(_host.rotation, _set_rot):
			_base_rot = _host.rotation


## Puts the host back on its base (paused while hidden); a later write by someone else still wins.
func _rest() -> void:
	if not _moved:
		return
	_moved = false
	_sync()
	_host.scale = _base_scale
	_set_scale = _host.scale
	if kind == AD_HOP:
		_host.position = _base_pos
		_host.rotation = _base_rot
		_set_pos = _host.position
		_set_rot = _host.rotation
