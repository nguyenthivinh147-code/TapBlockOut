extends RefCounted
## One-shot UI motion shared by every screen and popup (design.md mục 2 "Chuyển động UI"). Calm by design: short,
## soft overshoot, never blocks a tap it does not have to.
## - close_popup: a closing popup shrinks its panel and fades panel and dim out, then frees itself. Its input is off
##   from the first frame, and Main no longer counts it (closing()).
## - stagger / pop_in: content pops in one after another (scale POP_FROM -> its own, fading in), top to bottom.
##   UnityUI.play_reveal staggers a popup's panel_items while the panel grows; screens stagger their own lists.
## - roll: a number label counts to its new value instead of jumping.
## - bump: a node swells and settles back (counters, badges).
## Numbers here are visual tuning, like ui_motion.gd; never runs while UnityUI.baking (callers check).

## {panel, dim, tween}: the reveal of a popup (UnityUI.build sets it on the owner from DialogueReveal).
const META_REVEAL := "ui_reveal"
const META_CLOSING := "ui_closing"
const META_POP := "ui_pop"
const META_ROLL := "ui_roll"
## Shared with RewardFly's landing bump, so a landing and a counter change never fight over the scale.
const META_BUMP := "reward_bump"

## Close: panel scale -> CLOSE_SCALE of its own (quad in: it falls away faster at the end), panel and dim alpha -> 0
## (linear, so the close shows from the first frame).
const CLOSE_SEC := 0.18
const CLOSE_SCALE := 0.85
## Screen change outside the hub tabs (Main.go): the new screen fades in over FADE_SEC while the old one fades out.
const FADE_SEC := 0.25
## Pop in: scale POP_FROM -> 1 (out-back) over POP_SEC, alpha 0 -> 1 over POP_FADE_SEC. Items start POP_STEP apart,
## all of them within POP_SPREAD; past POP_MAX items the rest show at once.
const POP_FROM := 0.7
const POP_SEC := 0.3
const POP_FADE_SEC := 0.16
const POP_STEP := 0.05
const POP_SPREAD := 0.45
const POP_MAX := 40
## A popup's items start this long after its panel starts to grow (0.4 s out-back).
const REVEAL_LEAD := 0.12
## A popup with no prefab reveal (fade_in) fades in whole over OPEN_FADE_SEC.
const OPEN_FADE_SEC := 0.2
## Number roll: ease-out over ROLL_SEC.
const ROLL_SEC := 0.45
## Bump: scale BUMP -> 1 over BUMP_SEC (out-back).
const BUMP := 1.15
const BUMP_SEC := 0.3
## Bars (bars_in): the top bar's chips slide down from above the screen, the bottom bar up from below, over BAR_SEC
## (out-back), the chips BAR_STAGGER s apart from left to right; BAR_PAST px (screen) beyond the edge at the start.
const BAR_SEC := 0.35
const BAR_STAGGER := 0.04
const BAR_PAST := 8.0
## Main starts a screen's bars this long after the screen opens (with its 0.25 s fade).
const BAR_DELAY := 0.05
const META_SLIDE := "ui_slide"
## Unity prefab scripts that already animate a node's scale: such a node does not pop.
const OWN_SCALE_ANIMS := ["UIAnim_ScaleAppear", "UIAnim_Pulse", "UIAnimScale", "AnimScaleButton"]


# --- popup close ---

## True while `node` plays its close (Main skips it as a popup, Back goes to the one below).
static func closing(node: Node) -> bool:
	return is_instance_valid(node) and (node.is_queued_for_deletion() or node.has_meta(META_CLOSING))


## Plays the close of popup `node`, then frees it. A popup that is hidden, outside the tree or not a Control is freed
## at once; a second call does nothing.
static func close_popup(node: Node) -> void:
	if not is_instance_valid(node) or closing(node):
		return
	var c := node as Control
	if c == null or not c.is_inside_tree() or not c.is_visible_in_tree():
		node.queue_free()
		return
	c.set_meta(META_CLOSING, true)
	_mute(c)
	var r := reveal_of(c)
	var panel: Control = r.get("panel")
	var dim: Control = r.get("dim")
	var grow: Variant = r.get("tween")
	if grow is Tween and (grow as Tween).is_valid():
		(grow as Tween).kill()
	var tw := c.create_tween().set_parallel(true)
	if panel != null:
		tw.tween_property(panel, "scale", panel.scale * CLOSE_SCALE, CLOSE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(panel, "modulate:a", 0.0, CLOSE_SEC)
		if dim != null and dim != panel:
			tw.tween_property(dim, "modulate:a", 0.0, CLOSE_SEC)
	else:
		tw.tween_property(c, "modulate:a", 0.0, CLOSE_SEC)
	tw.chain().tween_callback(c.queue_free)


## {panel, dim, tween} of popup c: its own META_REVEAL, else the first one in its subtree (a popup that builds its
## frame into a child); panel or dim may be null. Empty when none.
static func reveal_of(c: Control) -> Dictionary:
	var queue: Array[Node] = [c]
	while not queue.is_empty():
		var n: Node = queue.pop_front()
		if n.has_meta(META_REVEAL):
			var r: Dictionary = n.get_meta(META_REVEAL)
			var out := {}
			for k in ["panel", "dim"]:
				var v: Variant = r.get(k)
				out[k] = v if is_instance_valid(v) and v is Control and (v as Control).is_inside_tree() else null
			out["tween"] = r.get("tween")
			return out
		queue.append_array(n.get_children())
	return {}


## No more taps, keys or Back for a closing popup: every control ignores the mouse, no node gets input callbacks.
static func _mute(c: Control) -> void:
	for m in ["set_process_input", "set_process_unhandled_input", "set_process_unhandled_key_input", "set_process_shortcut_input"]:
		c.propagate_call(m, [false])
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for n in c.find_children("*", "Control", true, false):
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


## Opening of a popup with no prefab reveal: it fades in whole. Its close (close_popup) stops the fade first.
static func fade_in(c: Control, dur: float = OPEN_FADE_SEC) -> void:
	if not c.is_inside_tree():
		return
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	c.set_meta(META_REVEAL, {"tween": tw})


# --- pop in ---

## Pops nodes in, in this order, the first after `delay` s. Hidden or zero-scale nodes are skipped.
static func stagger(nodes: Array, delay: float = 0.0) -> void:
	var list: Array[Control] = []
	for n in nodes:
		if n is Control and is_instance_valid(n) and (n as Control).is_inside_tree() and (n as Control).is_visible_in_tree():
			list.append(n)
	var count := mini(list.size(), POP_MAX)
	var step := POP_STEP if count <= 1 else minf(POP_STEP, POP_SPREAD / float(count - 1))
	for i in count:
		pop_in(list[i], delay + step * i)


## One node pops in after `delay` s: it waits shrunk and clear, then grows to its own scale and fades to its own
## alpha. A node already popping keeps that pop.
static func pop_in(c: Control, delay: float = 0.0) -> void:
	if c.has_meta(META_POP) or c.has_meta("u_scale_loop") or not c.is_inside_tree():
		return
	var base_scale := c.scale
	var base_a := c.modulate.a
	if is_zero_approx(base_scale.x) or is_zero_approx(base_scale.y) or is_zero_approx(base_a):
		return
	c.set_meta(META_POP, true)
	# Grow from the middle unless the node has a pivot of its own (Unity nodes carry their RectTransform pivot).
	if c.pivot_offset == Vector2.ZERO and c.pivot_offset_ratio == Vector2.ZERO and not c.has_meta("u"):
		c.pivot_offset_ratio = Vector2(0.5, 0.5)
	c.scale = base_scale * POP_FROM
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "scale", base_scale, POP_SEC).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", base_a, POP_FADE_SEC).set_delay(delay)
	tw.chain().tween_callback(c.remove_meta.bind(META_POP))


## What pops in a popup's panel, top to bottom: every button, and every child of a layout group (Unity layout group
## or Godot container), not looking inside one already taken. Nodes with a scale animation of their own, hidden
## nodes and their subtrees are left out.
static func panel_items(panel: Control) -> Array:
	var found: Array = []
	for ch in panel.get_children():
		if ch is Control:
			_collect(ch, _is_layout(panel), (ch as Control).position, found)
	found.sort_custom(func(a: Array, b: Array) -> bool:
		var pa: Vector2 = a[1]
		var pb: Vector2 = b[1]
		return pa.y < pb.y - 1.0 or (absf(pa.y - pb.y) <= 1.0 and pa.x < pb.x))
	var out: Array = []
	for f in found:
		out.append(f[0])
	return out


static func _collect(c: Control, in_layout: bool, at: Vector2, found: Array) -> void:
	if not c.visible or c.has_meta("u_rt") or _animates_scale(c):
		return
	if in_layout or c is BaseButton:
		found.append([c, at + c.size * 0.5])
		return
	var lay := _is_layout(c)
	for ch in c.get_children():
		if ch is Control:
			_collect(ch, lay, at + (ch as Control).position, found)


static func _is_layout(c: Control) -> bool:
	if c is BoxContainer or c is GridContainer or c is FlowContainer:
		return true
	return c.has_meta("u") and (c.get_meta("u") as Dictionary).has("lay")


static func _animates_scale(c: Control) -> bool:
	if c.has_meta("u_scale_loop"):
		return true
	if not c.has_meta("u"):
		return false
	for cs in (c.get_meta("u") as Dictionary).get("cs", []):
		if cs is Dictionary and OWN_SCALE_ANIMS.has(str((cs as Dictionary).get("name", ""))):
			return true
	return false


# --- slide in ---

## A screen's bars come in (design.md mục 2 "Chuyển động UI"): every shown child of `top` (avatar, lives, gold,
## settings) slides down from above the screen, left to right BAR_STAGGER s apart; `nav` slides up from below the
## screen without overshoot (an overshoot would open a gap under it). Either may be null or hidden. The first move starts
## after `delay` s.
static func bars_in(top: Control, nav: Control, delay: float = 0.0) -> void:
	if top != null and is_instance_valid(top) and top.is_visible_in_tree():
		var chips: Array[Control] = []
		for ch in top.get_children():
			if ch is Control and (ch as Control).visible:
				chips.append(ch)
		chips.sort_custom(func(a: Control, b: Control) -> bool: return a.position.x < b.position.x)
		for i in chips.size():
			slide_in_from(chips[i], Vector2.UP, BAR_SEC, delay + i * BAR_STAGGER)
	if nav != null and is_instance_valid(nav) and nav.is_visible_in_tree():
		slide_in_from(nav, Vector2.DOWN, BAR_SEC, delay, Tween.TRANS_CUBIC)


## c slides in (slide_in) from just past the screen edge on `side` (Vector2.UP, DOWN, LEFT or RIGHT). The distance is
## measured when the move starts (after `delay`), with c at its place: a screen still sliding in (a tab switch) or not
## laid out yet would give a wrong one now. Until then c waits a whole screen away on that side. A node that sits on
## that edge takes TRANS_CUBIC: no overshoot past its place.
static func slide_in_from(c: Control, side: Vector2, dur: float = BAR_SEC, delay: float = 0.0,
		trans: Tween.TransitionType = Tween.TRANS_BACK) -> void:
	if not c.is_inside_tree():
		return
	var vp := c.get_viewport_rect().size
	var far := (vp + c.get_global_rect().size) * side.abs() + Vector2(BAR_PAST, BAR_PAST) * side.abs()
	slide_in(c, side * far / _parent_scale(c), dur, delay, trans, side)


## Offset (c's parent units) that puts c, at its place, just past the screen edge on `side`.
static func _edge_offset(c: Control, side: Vector2) -> Vector2:
	var r := c.get_global_rect()
	var vp := c.get_viewport_rect().size
	var d := r.end.y if side.y < 0.0 else (vp.y - r.position.y if side.y > 0.0 else (r.end.x if side.x < 0.0 else vp.x - r.position.x))
	return side * (maxf(d, 0.0) + BAR_PAST) / _parent_scale(c)


## c waits `offset` (its parent's units) away from its place, then after `delay` s slides home over `dur` (ease out,
## `trans`; out-back by default). `side` (slide_in_from) measures the offset again when the move starts.
## Its place is wherever layout puts it meanwhile: a position someone else writes becomes the new place. A slide still
## playing on c is replaced.
static func slide_in(c: Control, offset: Vector2, dur: float = BAR_SEC, delay: float = 0.0,
		trans: Tween.TransitionType = Tween.TRANS_BACK, side: Vector2 = Vector2.ZERO) -> void:
	if not c.is_inside_tree():
		return
	var base := c.position
	var old: Variant = c.get_meta(META_SLIDE) if c.has_meta(META_SLIDE) else null
	if old is Dictionary:
		var otw: Variant = (old as Dictionary).get("tween")
		if otw is Tween and (otw as Tween).is_valid():
			(otw as Tween).kill()
		if c.position.is_equal_approx((old as Dictionary)["at"]):
			base = (old as Dictionary)["base"]
	var st := {"base": base, "at": base, "offset": offset, "side": side}
	c.set_meta(META_SLIDE, st)
	_slide_step(0.0, c, st, dur, delay, trans)
	var tw := c.create_tween()
	tw.tween_method(_slide_step.bind(c, st, dur, delay, trans), 0.0, delay + dur, delay + dur)
	tw.tween_callback(_slide_end.bind(c, st))
	st["tween"] = tw


static func _slide_step(t: float, c: Control, st: Dictionary, dur: float, delay: float,
		trans: Tween.TransitionType) -> void:
	if not c.position.is_equal_approx(st["at"]):
		st["base"] = c.position
	if t >= delay and st["side"] != Vector2.ZERO:
		# The move starts: measure from c's place now that its screen sits where it stays.
		c.position = st["base"]
		st["offset"] = _edge_offset(c, st["side"])
		st["side"] = Vector2.ZERO
	var u := clampf((t - delay) / dur, 0.0, 1.0) if dur > 0.0 else 1.0
	var k: float = Tween.interpolate_value(0.0, 1.0, u, 1.0, trans, Tween.EASE_OUT)
	c.position = st["base"] + st["offset"] * (1.0 - k)
	st["at"] = c.position


static func _slide_end(c: Control, st: Dictionary) -> void:
	if not c.position.is_equal_approx(st["at"]):
		st["base"] = c.position
	c.position = st["base"]
	if c.has_meta(META_SLIDE) and is_same(c.get_meta(META_SLIDE), st):
		c.remove_meta(META_SLIDE)


## Canvas units per unit of c's parent (y), the space of get_global_rect.
static func _parent_scale(c: Control) -> float:
	var p := c.get_parent() as CanvasItem
	var s := absf(p.get_global_transform().get_scale().y) if p != null else 1.0
	return s if s > 0.0 else 1.0


# --- numbers ---

## Shows `value` on label: the first time (or while the label is hidden, or shows no number) at once, later counting
## from the number on show to value over ROLL_SEC. A number someone else wrote is where the count starts.
static func roll(label: Label, value: int) -> void:
	var r: Dictionary = label.get_meta(META_ROLL, {})
	var tw: Variant = r.get("tween")
	var running := tw is Tween and (tw as Tween).is_valid()
	if running and int(r.get("to", value)) == value:
		return
	if running:
		(tw as Tween).kill()
	var shown := label.text.to_int()
	if r.is_empty() or not label.text.is_valid_int() or shown == value or not label.is_visible_in_tree():
		label.set_meta(META_ROLL, {"to": value})
		label.text = str(value)
		return
	var t := label.create_tween()
	label.set_meta(META_ROLL, {"to": value, "tween": t})
	t.tween_method(_roll_step.bind(label), float(shown), float(value), ROLL_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Shows value on label at once, ending a roll (a counter that landing coins step themselves).
static func set_number(label: Label, value: int) -> void:
	var tw: Variant = (label.get_meta(META_ROLL, {}) as Dictionary).get("tween")
	if tw is Tween and (tw as Tween).is_valid():
		(tw as Tween).kill()
	label.set_meta(META_ROLL, {"to": value})
	label.text = str(value)


static func _roll_step(v: float, label: Label) -> void:
	label.text = str(roundi(v))


## The number a rolling label ends on (its text when it does not roll).
static func roll_target(label: Label) -> int:
	var r: Dictionary = label.get_meta(META_ROLL, {})
	return int(r.get("to", label.text.to_int()))


# --- bump ---

## c swells to k times its size and settles back over dur (out-back), about its middle. A bump still playing starts
## over.
static func bump(c: Control, k: float = BUMP, dur: float = BUMP_SEC) -> void:
	if not c.is_inside_tree():
		return
	if c.has_meta(META_BUMP):
		var old: Variant = c.get_meta(META_BUMP)
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(k, k)
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	c.set_meta(META_BUMP, tw)
