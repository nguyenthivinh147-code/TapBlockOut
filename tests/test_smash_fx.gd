extends RefCounted
## Booster Phá khối: búa kẹo mút hiện giữa màn, bay tới gõ; bàn khoá chạm trong lúc búa bay, khối vỡ lúc búa chạm.
const T := preload("res://tests/t.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")

const DIR := "user://test_smash_fx"
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


func test_smash_fx_hits_then_breaks(t: T) -> void:
	var g := _g(17)
	g.s.inv.smash = 2
	var lv := _mount()
	await _wait_until(func() -> bool: return lv.state == "playing")
	var count: int = lv.board.remaining_count()
	lv.booster_buttons.smash.pressed.emit()
	t.ok(lv._smash_mode, "đang chờ chọn khối")
	var id: String = lv.board.hint()
	t.ok(id != "", "có khối để chọn")
	lv.board_view.block_tapped.emit(id)
	t.eq(int(g.s.inv.smash), 1, "trừ kho ngay")
	t.eq(lv.board.remaining_count(), count - 1, "bàn bỏ khối ngay")
	t.eq(lv.state, "smashing", "khoá chạm khi búa bay")
	t.ok(lv.get_node_or_null("LocalPopups/SmashFx") != null, "búa hiện")
	t.ok(lv.board_view.block_node(id) != null, "khối còn trên bàn tới khi búa gõ")
	var other: String = lv.board.hint()
	if other != "":
		lv.board_view.block_tapped.emit(other)
		t.eq(lv.board.remaining_count(), count - 1, "chạm khối khác lúc búa bay không có tác dụng")
	t.ok(await _wait_until(func() -> bool: return lv.board_view.block_node(id) == null), "búa gõ, khối vỡ")
	t.ok(lv.find_child("Shards", true, false) != null, "mảnh kẹo bắn ra")
	t.ok(lv.state == "playing" or lv.state == "resolving", "mở lại chạm sau cú gõ")
	t.ok(await _wait_until(func() -> bool: return lv.get_node_or_null("LocalPopups/SmashFx") == null), "hiệu ứng tự xoá")
	lv.free()


func test_smash_fx_strike_point_on_block(t: T) -> void:
	_g(17)
	var lv := _mount()
	await _wait_until(func() -> bool: return lv.state == "playing")
	for id in lv.board.block_ids():
		var n: Control = lv.board_view.block_node(str(id))
		if n == null:
			continue
		var p: Vector2 = lv.board_view.strike_point(str(id))
		var local: Vector2 = n.get_global_transform().affine_inverse() * p
		var c := Vector2i((local / lv.board_view.cell_size()).floor())
		t.ok(n.local_cells().has(c), "điểm gõ nằm trên một ô của khối %s" % id)
	lv.free()
