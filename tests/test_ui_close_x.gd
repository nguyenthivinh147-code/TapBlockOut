extends RefCounted
## Close X of the Unity popups (UnityUI._grow_close): the art is Config.CLOSE_ART_SCALE times the prefab size around
## its center, the touch target Config.CLOSE_HIT_SCALE times the prefab one; it stays on the canvas; a bake keeps the
## prefab size.
const T := preload("res://tests/t.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const UButton := preload("res://src/ui/u_button.gd")
const Config := preload("res://src/config.gd")

const X := "Panel/Top/btnTurnOff"
## Sprite-less X: an 80 unit button holding the 64 unit art in its child Image.
const INGAME_X := "Panel/PauseMenu/Top/btnTurnOff"


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## [owner, view] of `layer` built into a fresh 886x1920 owner; bake builds it as tools/bake_screen.gd does.
func _build(layer: String, bake: bool) -> Array:
	var o := Control.new()
	o.size = UnityUI.REF
	_tree().root.add_child(o)
	UnityUI.baking = bake
	var v := UnityUI.build(o, layer, {"reveal": false})
	UnityUI.baking = false
	return [o, v]


func _center(c: Control) -> Vector2:
	return c.position + c.size * 0.5


## Rect in canvas units on the rest layout (positions only), as _keep_on_canvas measures it.
func _on_canvas(c: Control) -> Rect2:
	var pos := c.position
	var p := c.get_parent() as Control
	while p != null and not p.has_meta("u_canvas"):
		pos += p.position
		p = p.get_parent() as Control
	return Rect2(pos, c.size)


func test_x_grows_around_its_center(t: T) -> void:
	var baked := _build("PopupOkLayer", true)
	var live := _build("PopupOkLayer", false)
	var prefab: Control = (baked[1] as RefCounted).call("node", X)
	var x: Control = (live[1] as RefCounted).call("node", X)
	t.ok(not prefab.has_meta("u_close"), "bake giữ cỡ prefab")
	t.eq(prefab.size, Vector2(64, 64), "X prefab 64")
	t.eq(x.size, prefab.size * Config.CLOSE_ART_SCALE, "X to gấp CLOSE_ART_SCALE")
	t.ok(_center(x).distance_to(_center(prefab)) < 0.01, "phóng quanh tâm, X vẫn ở chỗ cũ")
	var old_hit: Vector2 = prefab.call("hit_size")
	var hit: Vector2 = x.call("hit_size")
	t.ok(old_hit.x >= UButton.MIN_HIT - 0.1, "vùng chạm cũ nới tới MIN_HIT")
	t.near(hit.x, old_hit.x * Config.CLOSE_HIT_SCALE, 0.01, "vùng chạm rộng gấp CLOSE_HIT_SCALE")
	t.near(hit.y, old_hit.y * Config.CLOSE_HIT_SCALE, 0.01, "vùng chạm cao gấp CLOSE_HIT_SCALE")
	var hr: Rect2 = x.call("hit_rect")
	t.ok(hr.get_center().distance_to(x.size * 0.5) < 0.01, "vùng chạm quanh tâm X")
	var at := x.offset_left
	await _tree().process_frame
	t.eq(x.offset_left, at, "popup thường không bị dịch")
	# A copy of a wired X (a template the screen clones) keeps meta u_close and is not grown twice.
	var copy := UnityUI.strip_runtime(x.duplicate()) as Control
	x.get_parent().add_child(copy)
	UnityUI.adopt(copy, (live[1] as RefCounted).get("canvas"))
	t.eq(copy.size, x.size, "bản chép không phóng hai lần")
	t.near(float(copy.get("art_scale")), Config.CLOSE_ART_SCALE, 0.0001, "bản chép giữ art_scale")
	(baked[0] as Node).free()
	(live[0] as Node).free()


func test_art_inside_a_sprite_less_x_grows(t: T) -> void:
	var baked := _build("SettingInGameLayer", true)
	var live := _build("SettingInGameLayer", false)
	var prefab: Control = (baked[1] as RefCounted).call("node", INGAME_X)
	var x: Control = (live[1] as RefCounted).call("node", INGAME_X)
	var art0: Control = prefab.get_node("Image")
	var art: Control = x.get_node("Image")
	t.eq(art0.size, Vector2(64, 64), "hình X prefab 64")
	t.eq(art.size, art0.size * Config.CLOSE_ART_SCALE, "hình X bên trong to theo")
	t.ok(_center(art).distance_to(x.size * 0.5) < 0.01, "hình nằm giữa nút")
	(baked[0] as Node).free()
	(live[0] as Node).free()


func test_x_moves_in_to_stay_on_screen(t: T) -> void:
	var live := _build("PopupOkLayer", false)
	var x: Control = (live[1] as RefCounted).call("node", X)
	var canvas: Control = (live[1] as RefCounted).get("canvas")
	await _tree().process_frame
	# As on a popup almost as wide as the screen (shop_mini): the grown X hangs past the right edge.
	x.offset_left += 200.0
	x.offset_right += 200.0
	t.ok(_on_canvas(x).end.x > canvas.size.x, "X tràn mép phải")
	UnityUI._keep_on_canvas(x)
	t.near(_on_canvas(x).end.x, canvas.size.x - Config.CLOSE_EDGE_GAP, 0.01, "dịch vào, cách mép CLOSE_EDGE_GAP")
	t.eq(x.size, Vector2(64, 64) * Config.CLOSE_ART_SCALE, "giữ cỡ")
	var at := x.offset_left
	UnityUI.apply_rect(x)
	t.near(x.offset_left, at, 0.01, "rect Unity theo chỗ mới, relayout giữ chỗ")
	(live[0] as Node).free()
