extends "res://src/ui/stub_ui.gd"
## Wireframe 1.5 First-time Tutorial. Layout of MainTutorialLayer (color-cube-match-puzzle): Step1 shows its text
## panel and hand, Step2 stays hidden. level.gd opens it once, before the first play of L1 (Game.take_intro,
## s.meta.intro_seen), with view {aim, hit}: aim() is the global rect of the block cell to tap, hit(p) whether the
## global point p is on that block. The hand's fingertip follows aim() and pokes it; only a tap on that block continues
## (closed({"action": "tap"})), and level.gd then plays that tap as the first move. Without aim (UI gallery) the hand
## stays where the prefab puts it and a tap anywhere continues.
## The poke is this script's own loop instead of TutController_Step1 (which only swaps the sprite in place): the hand
## comes in along the finger, presses (UI_Maincenter_20) while the ring (TapFx) and dot (TapFx2) spread from the
## fingertip, then lifts back.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const STEP := "GameObject/Step1"
## Hand/TapFx (where the tap rings play) relative to Hand, Unity units (y up): the fingertip.
const FINGER := Vector2(-32.9, 22)
const HAND_UP := "Resources_UI_Maincenter:UI_Maincenter_19"
const HAND_DOWN := "Resources_UI_Maincenter:UI_Maincenter_20"
## Poke loop (seconds, fractions of it, canvas units). The finger points up-left, so the hand lifts down-right.
const POKE_SEC := 1.1
const POKE_IN := 0.3  # reaches the cell
const POKE_HOLD := 0.5  # lets go
const POKE_OUT := 0.75  # back at LIFT, rests until the loop ends
const LIFT := Vector2(30, 30)
const PRESS_SCALE := 0.9  # HandSprite scale while pressed, times its prefab scale
const RING_SEC := 0.45  # ring spreads and fades from POKE_IN
const RING_CELLS := 1.8  # ring diameter at the end, in cells
const RING_ALPHA := 0.9
const DOT_SEC := 0.25
const DOT_ALPHA := 0.6

var _hand: Control = null
var _sprite: Control = null
var _ring: Control = null
var _dot: Control = null
var _sprite_home := Vector2.ZERO
var _sprite_scale := Vector2.ONE
## Ring scale at the end of its spread (prefab TapFx is 150.5 units wide): RING_CELLS cells once aim is known.
var _ring_end := 1.5
var _aim_rect := Rect2()
var _t := 0.0
var _pressed := false


func _build() -> void:
	ui = UnityUI.build(self, "MainTutorialLayer")
	# The poke below replaces the step's Animator, which keeps the prefab's values while off.
	ui.animator(STEP).enabled = false
	var target: Button = ui.button(STEP + "/Hand/TargetButton")
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.text(STEP + "/Panel/Canvas/Text (TMP)", tr("boot_tut_body"))
	if UnityUI.baking:
		return  # the saved scene keeps the prefab's pose
	_hand = ui.node(STEP + "/Hand")
	_sprite = ui.node(STEP + "/Hand/HandSprite")
	_ring = ui.node(STEP + "/Hand/TapFx")
	_dot = ui.node(STEP + "/Hand/TapFx2")
	_sprite_home = _sprite.position
	_sprite_scale = _sprite.scale
	_track()
	_poke(0.0)


func _process(delta: float) -> void:
	if _hand == null:
		return
	_track()
	_t = fposmod(_t + delta, POKE_SEC)
	_poke(_t / POKE_SEC)


## Fingertip on the centre of aim() (Step1's local units), when it moved.
func _track() -> void:
	var aim: Variant = view.get("aim")
	if not (aim is Callable) or not (aim as Callable).is_valid():
		return
	var r: Rect2 = (aim as Callable).call()
	if r == _aim_rect or r.size == Vector2.ZERO:
		return
	_aim_rect = r
	var step := _hand.get_parent() as Control
	var inv := step.get_global_transform().affine_inverse()
	var at: Vector2 = inv * r.get_center() - Vector2(FINGER.x, -FINGER.y)
	var size: Vector2 = (_hand.get_meta("u_rect") as Dictionary).size
	UnityKit.place(_hand, Rect2(at - size * 0.5, size))
	var cell: float = (inv.basis_xform(Vector2(r.size.x, 0))).length()
	_ring_end = RING_CELLS * cell / maxf(_ring.size.x, 1.0)


## One frame of the poke loop, `k` in [0, 1).
func _poke(k: float) -> void:
	var lift := 1.0
	if k < POKE_IN:
		lift = 1.0 - ease(k / POKE_IN, 2.0)
	elif k < POKE_HOLD:
		lift = 0.0
	elif k < POKE_OUT:
		lift = ease((k - POKE_HOLD) / (POKE_OUT - POKE_HOLD), 0.5)
	_sprite.position = _sprite_home + LIFT * lift
	var down := k >= POKE_IN and k < POKE_HOLD
	if down != _pressed:
		_pressed = down
		UnityUI.set_sprite(_sprite, HAND_DOWN if down else HAND_UP)
	_sprite.scale = _sprite_scale * (PRESS_SCALE if down else 1.0)
	var since := (k - POKE_IN) * POKE_SEC
	var ring := since / RING_SEC
	_ring.visible = ring >= 0.0 and ring < 1.0
	if _ring.visible:
		_ring.scale = Vector2.ONE * lerpf(0.2, _ring_end, ease(ring, 0.4))
		UnityUI.set_color_channel(_ring, "a", RING_ALPHA * (1.0 - ring))
	var dot := since / DOT_SEC
	_dot.visible = dot >= 0.0 and dot < 1.0
	if _dot.visible:
		UnityUI.set_color_channel(_dot, "a", DOT_ALPHA * (1.0 - dot))


## Global point (fingertip) the hand pokes; the popup's own centre without aim.
func aim_point() -> Vector2:
	return _aim_rect.get_center() if _aim_rect.size != Vector2.ZERO else get_global_rect().get_center()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		var hit: Variant = view.get("hit")
		if hit is Callable and (hit as Callable).is_valid():
			if not bool((hit as Callable).call(get_global_transform() * (event as InputEventMouseButton).position)):
				return
		_send("tap")
