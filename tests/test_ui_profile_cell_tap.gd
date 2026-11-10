extends RefCounted
const T := preload("res://tests/t.gd")

const DIR := "user://test_ui_profile_cell_tap"
const SCENE := "res://scenes/profile.tscn"


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _frame() -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame


func _mouse(c: Control, local: Vector2, down: bool) -> void:
	var at: Vector2 = c.get_global_transform_with_canvas() * local
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	e.global_position = at
	_root().push_input(e, true)
	await _frame()


## Tap through the viewport like a finger (hit testing included), at the cell's center.
func _tap_cell(p: Control, id: String) -> void:
	var b: Button = p.cells[id].panel
	var at: Vector2 = b.size * 0.5
	await _mouse(b, at, true)
	await _mouse(b, at, false)


func _disabled_cells(p: Control) -> Array:
	var out := []
	for id in p.cells:
		if (p.cells[id].panel as Button).disabled:
			out.append(id)
	return out


## Previewing one avatar, then the one beside it, then back: every tap must preview and no cell may stay disabled.
func test_tap_cell_then_neighbor(t: T) -> void:
	var g: Node = _root().get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.s.level = 5
	var p := (load(SCENE) as PackedScene).instantiate() as Control
	_root().add_child(p)
	p.setup({})
	await _frame()
	await _frame()
	for id in ["avatar_04", "avatar_05", "avatar_04", "avatar_03", "avatar_05", "avatar_05", "avatar_04"]:
		await _tap_cell(p, id)
		t.eq(str(p._sel.avatar), id, "chạm ô " + id + " thì xem trước nó")
		t.eq(_disabled_cells(p), [], "sau khi chạm " + id + " không ô nào bị khoá")
	p.queue_free()


## A cell left disabled (ToggleAnimator of a pressed toggle) is freed by the next refresh.
func test_refresh_frees_stale_disabled_cell(t: T) -> void:
	var g: Node = _root().get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.s.level = 5
	var p := (load(SCENE) as PackedScene).instantiate() as Control
	_root().add_child(p)
	p.setup({})
	await _frame()
	(p.cells["avatar_04"].panel as Button).disabled = true
	p.select("avatar_05")
	t.eq(_disabled_cells(p), [], "refresh mở khoá ô avatar_04")
	await _tap_cell(p, "avatar_04")
	t.eq(str(p._sel.avatar), "avatar_04", "chạm lại ô avatar_04 xem trước được")
	p.queue_free()
