extends RefCounted
## Booster +Move: dấu "+" bay từ nút tới chip lượt, số lượt hiện tăng dần, hiệu ứng tự xoá.
const T := preload("res://tests/t.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")
const Config := preload("res://src/config.gd")

const DIR := "user://test_move_fx"
const NOW := 1800000000


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _g(level: int) -> Node:
	DirAccess.make_dir_recursive_absolute(DIR)
	var g: Node = _tree().root.get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.test_now = NOW
	var p: Node = _tree().root.get_node("Platform")
	p.ads.calls.clear()
	p.ads.set_ready(true, true)
	p.iap = MockIap.new()
	g.s.level = level
	for k in ["hint", "move", "smash"]:
		g.s.gifted[k] = true
	return g


func _mount() -> Control:
	var lv := (load("res://scenes/level.tscn") as PackedScene).instantiate() as Control
	_tree().root.add_child(lv)
	lv.setup({})
	return lv


func _wait_until(cond: Callable, ms: int = 6000) -> bool:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await _tree().process_frame
	return cond.call()


func test_move_fx_counts_up(t: T) -> void:
	var g := _g(12)
	g.s.inv.move = 1
	var lv := _mount()
	await _wait_until(func() -> bool: return lv.state == "playing")
	var before: int = lv.board.moves_left()
	var add := int(Config.ECON.rescue_moves)
	lv.booster_buttons.move.pressed.emit()
	t.eq(lv.board.moves_left(), before + add, "bàn cộng lượt ngay")
	t.eq(int(g.s.inv.move), 0, "trừ kho")
	t.eq(lv.moves_label.text, str(before), "chip chưa đổi khi dấu còn bay")
	t.ok(lv.get_node_or_null("LocalPopups/MoveFx") != null, "dấu bay từ nút")
	var seen: Array = [lv.moves_label.text]
	var done := await _wait_until(func() -> bool:
		if seen[-1] != lv.moves_label.text:
			seen.append(lv.moves_label.text)
		return lv.moves_label.text == str(before + add))
	t.ok(done, "chip tới số mới")
	t.eq(seen.size(), add + 1, "tăng từng lượt một")
	t.ok(await _wait_until(func() -> bool: return lv.get_node_or_null("LocalPopups/MoveFx") == null), "hiệu ứng tự xoá")
	var chip: Control = lv.moves_chip
	t.eq(chip.scale, Vector2.ONE, "chip về cỡ cũ")
	lv.free()


func test_move_fx_tap_during_flight(t: T) -> void:
	var g := _g(12)
	g.s.inv.move = 1
	var lv := _mount()
	await _wait_until(func() -> bool: return lv.state == "playing")
	lv.booster_buttons.move.pressed.emit()
	var id: String = lv.board.hint()
	if id != "":
		lv.board_view.block_tapped.emit(id)
	t.ok(await _wait_until(func() -> bool: return lv.get_node_or_null("LocalPopups/MoveFx") == null), "hiệu ứng tự xoá")
	t.eq(lv.moves_label.text, str(lv.board.moves_left()), "chip khớp bàn sau khi bay xong")
	lv.free()
