extends RefCounted
## Real input for the UI rule tests (tests/test_ui_back_rules.gd, tests/test_ui_tap_rules.gd; design.md mục 2
## "Back Android và ESC", "Chạm vào UI"). Mouse and touch events go into the root viewport at canvas coordinates, so
## they pass GUI hit-testing like a finger (tests/e2e_driver.gd emits signals instead); Back is the notification
## Android sends, ESC a desktop key. Home helpers use the save with every feature open (smoke_saves.gd all_unlocked).

const UiTween := preload("res://src/ui/ui_tween.gd")
const Scen := preload("res://tests/smoke/scenarios.gd")
const Saves := preload("res://tests/smoke/smoke_saves.gd")


static func tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


# --- verdicts with the KNOWN list of a test file ---
# KNOWN lists what the game does not follow yet: it prints ALLOWED instead of failing, so tools/test.sh stays the
# gate for every session; an entry that no longer happens fails, so the list only shrinks. Fixing one: delete its
# entry first, see the test red, then fix the game.

## One case of a rule; `known`: it is in KNOWN.
static func expect(t: RefCounted, ok: bool, msg: String, known: bool) -> void:
	if not known:
		t.ok(ok, msg)
	elif ok:
		t.fail("%s: đã đúng luật, xoá khỏi KNOWN" % msg)
	else:
		t.allow("%s (lỗi game đã biết, KNOWN)" % msg)


## A sweep: `got` maps each item that breaks the rule to what was seen; `known` the items in KNOWN.
static func expect_none(t: RefCounted, msg: String, got: Dictionary, known: Array) -> void:
	var fresh := {}
	for k in got:
		if known.has(k):
			t.allow("%s: %s → %s (lỗi game đã biết, KNOWN)" % [msg, k, str(got[k])])
		else:
			fresh[k] = got[k]
	t.eq(fresh, {}, msg)
	for k in known:
		if not got.has(k):
			t.fail("%s: %s đã đúng luật, xoá khỏi KNOWN" % [msg, k])


static func root() -> Window:
	return tree().root


static func frames(n: int = 1) -> void:
	for i in n:
		await tree().process_frame


## Game seconds: Engine.time_scale applies, as it does to the animations.
static func wait(sec: float) -> void:
	await tree().create_timer(sec).timeout


# --- input ---

static func center(c: Control) -> Vector2:
	return c.get_global_transform_with_canvas() * (c.size * 0.5)


static func motion(p: Vector2, held: bool = false) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	if held:
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	root().push_input(ev, true)


static func button(p: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	ev.position = p
	ev.global_position = p
	root().push_input(ev, true)


static func click(p: Vector2) -> void:
	button(p, true)
	button(p, false)


## Finger `index` as Android sends it. Godot turns finger 0 into the mouse
## (input_devices/pointing/emulate_mouse_from_touch); the other fingers stay touch events.
static func touch(index: int, p: Vector2, down: bool) -> void:
	if index == 0:
		button(p, down)
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = p
	ev.pressed = down
	root().push_input(ev, true)


## Holds the mouse at `from`, drags it to `to` in a few steps and lifts it there.
static func drag_release(from: Vector2, to: Vector2) -> void:
	for i in range(1, 7):
		motion(from.lerp(to, i / 6.0), true)
		await tree().process_frame
	button(to, false)


## Android Back, as it reaches the game: the notification travels down from the root.
static func back() -> void:
	root().propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(3)


static func esc() -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.physical_keycode = KEY_ESCAPE
		ev.pressed = down
		root().push_input(ev, true)
	await frames(3)


## Back or ESC by name ("Back", "ESC").
static func send(key: String) -> void:
	if key == "ESC":
		await esc()
	else:
		await back()


# --- hit-testing ---

static func hovered_at(p: Vector2) -> Control:
	motion(p)
	await tree().process_frame
	return root().gui_get_hovered_control()


static func inside(n: Node, owner: Variant) -> bool:
	if n == null or not is_instance_valid(owner):
		return false
	var o := owner as Node
	return o != null and (n == o or o.is_ancestor_of(n))


## A point where a tap reaches `c` (or a child of it): its center, else a 3x3 grid over it (as smoke.gd tap()).
## Vector2.INF when no point on it takes the tap.
static func aim(c: Control) -> Vector2:
	var spots: Array[Vector2] = [Vector2(0.5, 0.5)]
	for iy in 3:
		for ix in 3:
			spots.append(Vector2((ix + 0.5) / 3.0, (iy + 0.5) / 3.0))
	for f in spots:
		var p := c.get_global_transform_with_canvas() * (c.size * f)
		if inside(await hovered_at(p), c):
			return p
	return Vector2.INF


## Waits until `c` stands still (center moves under 0.5 px over 2 frames), at most `ms`.
static func settle(c: Control, ms: int = 3000) -> void:
	var last := Vector2.INF
	var same := 0
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline and same < 2:
		await tree().process_frame
		if not is_instance_valid(c):
			return
		var p := center(c)
		same = same + 1 if p.distance_to(last) < 0.5 else 0
		last = p


## Corners and edge midpoints of the screen, 16 units in.
static func edge_points() -> Array[Vector2]:
	var r := root().get_visible_rect().grow(-16.0)
	var out: Array[Vector2] = []
	for f in [Vector2(0, 0), Vector2(0.5, 0), Vector2(1, 0), Vector2(0, 0.5), Vector2(1, 0.5), Vector2(0, 1),
			Vector2(0.5, 1), Vector2(1, 1)]:
		out.append(r.position + r.size * f)
	return out


## A point where a tap reaches no button (to drag a held finger off a button), farthest first from `from`.
static func empty_spot(from: Vector2) -> Vector2:
	var r := root().get_visible_rect().grow(-24.0)
	var spots: Array[Vector2] = []
	for iy in 9:
		for ix in 5:
			spots.append(r.position + r.size * Vector2(ix / 4.0, iy / 8.0))
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(from) > b.distance_to(from))
	for p in spots:
		var h := await hovered_at(p)
		var n: Node = h
		while n != null and not (n is BaseButton):
			n = n.get_parent()
		if n == null:
			return p
	return Vector2.INF


static func label(n: Node) -> String:
	if n == null:
		return "null"
	var s := n.get_script() as Script
	return "%s (%s)" % [n.name, s.resource_path.get_file() if s != null else n.get_class()]


## What a button shows: its own tint, scale and art (UButton tint target and image), the pressed style of a themed
## Button, and the tint and scale of its parent (an invisible button over a chip, like hub_top's LivesPlus, presses the
## chip). Changes while it is held = press feedback.
static func look(b: Control) -> Array:
	var out: Array = [b.modulate, b.self_modulate, b.scale]
	var parent := b.get_parent() as Control
	if parent != null:
		out.append_array([parent.modulate, parent.scale])
	var tint: Variant = b.get("tint_target")
	if tint is CanvasItem and is_instance_valid(tint):
		out.append((tint as CanvasItem).self_modulate)
	var img: Variant = b.get("image")
	if img is Object and is_instance_valid(img):
		out.append((img as Object).get("texture"))
		out.append((img as Object).get("region"))
	if b is Button:
		var btn := b as Button
		out.append(btn.get_draw_mode() == BaseButton.DRAW_PRESSED
			and btn.get_theme_stylebox("pressed") != btn.get_theme_stylebox("normal"))
	return out


# --- Main and Home ---

static func popup_by_script(main: Control, file: String) -> Node:
	for c in main.popup_layer.get_children():
		if UiTween.closing(c):
			continue
		var s := c.get_script() as Script
		if s != null and s.resource_path.get_file() == file:
			return c
	return null


## `p` may be a popup already freed (Variant: a typed argument rejects a freed object).
static func is_open(p: Variant) -> bool:
	if not is_instance_valid(p):
		return false
	var n := p as Node
	return n != null and n.is_inside_tree() and not UiTween.closing(n)


static func idle(main: Control, ms: int = 8000) -> void:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		if main.curtain == null and main.get("_slide_out") == null:
			return
		await tree().process_frame


## Closes every popup (closed(null), as Main does for Back) and waits for the close animation.
static func close_all(main: Control) -> void:
	for i in 3:
		var any := false
		for c in main.popup_layer.get_children():
			if UiTween.closing(c):
				continue
			any = true
			if c.has_signal("closed"):
				c.emit_signal("closed", null)
			else:
				c.queue_free()
		if not any:
			return
		await wait(0.3)


## Back on Home with no popup and the bars in place. `rebuild` re-creates Home (after the save changed).
static func to_home(d: RefCounted, rebuild: bool = false) -> void:
	var main: Control = d.main
	await close_all(main)
	await idle(main)
	if rebuild or main.current_name != "home":
		main.go("home")
		await frames(2)
		await idle(main)
	# Home may open a popup by itself (offer, upsell) once it is shown.
	await wait(0.6)
	await close_all(main)


## Save with every feature open (smoke_saves.gd all_unlocked), on Home.
static func home_all_unlocked(d: RefCounted) -> void:
	Saves.all_unlocked(d.game())
	await to_home(d, true)


## Home button `name` (tests/smoke/scenarios.gd HOME_BUTTONS) when it shows and is enabled, else null.
static func home_button(main: Control, name: String) -> Control:
	if main.current_name != "home":
		return null
	var b := Scen.find_visible(main.current_screen, name) as Control
	if b == null or (b is BaseButton and (b as BaseButton).disabled):
		return null
	return b


## Where a tap on Home button `name` lands, once the button stands still; Vector2.INF when it is hidden, disabled
## or covered.
static func home_aim(main: Control, name: String) -> Vector2:
	var b := home_button(main, name)
	if b == null:
		return Vector2.INF
	await settle(b)
	return await aim(b)


## Result of a tap: the screen shown and how many popups it added.
static func outcome(main: Control, popups_before: int) -> Dictionary:
	return {"screen": main.current_name, "popups": main.popup_count() - popups_before}


## Waits until something reacts to a tap on Home (a popup or another screen), then lets it finish opening.
static func await_reaction(d: RefCounted, popups_before: int) -> void:
	var main: Control = d.main
	await d.wait_until(func() -> bool: return main.popup_count() != popups_before or main.current_name != "home", 3000)
	await idle(main)
	await wait(0.6)


## Taps Home button `name` like a finger. Returns the popup it opened, or null (hidden, disabled, covered, opened a
## screen or nothing).
static func open_from_home(d: RefCounted, name: String) -> Node:
	var main: Control = d.main
	var p := await home_aim(main, name)
	if p == Vector2.INF:
		return null
	var before: int = main.popup_count()
	click(p)
	await await_reaction(d, before)
	if main.current_name == "home" and main.popup_count() > before:
		return main.call("_top_popup")
	return null
