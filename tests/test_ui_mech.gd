extends RefCounted
## Hiển thị cơ chế: đá, băng, xích và chìa, hai lớp, sương mù, cổng nhịp trong BoardView.
const T := preload("res://tests/t.gd")
const BoardState := preload("res://src/core/board_state.gd")
const SCENE := "res://scenes/board_view.tscn"
const FIXTURE := "res://tests/fixtures/mechanics.json"


func _b(id: String, color: String, cells: Array, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": id, "color": color, "cells": cells, "ice": 0, "chained_by": "",
		"inner_color": "", "fog": false}
	d.merge(extra, true)
	return d


func _lv(w: int, h: int, blocks: Array, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": 7, "w": w, "h": h, "hard": false, "min_taps": 0, "moves": 30, "seed": 0,
		"stones": [], "pulse_sides": [], "blocks": blocks}
	d.merge(extra, true)
	return d


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _view(board: BoardState, area: Vector2 = Vector2(720, 900)) -> Control:
	var v := (load(SCENE) as PackedScene).instantiate() as Control
	_root().add_child(v)
	v.setup(board, area)
	return v


func _fixture() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	return parsed if parsed is Dictionary else {}


func _wait_done(v: Control, limit_ms: int = 2500) -> bool:
	var state := {"done": false}
	v.animation_done.connect(func() -> void: state["done"] = true, CONNECT_ONE_SHOT)
	var deadline := Time.get_ticks_msec() + limit_ms
	while not state["done"] and Time.get_ticks_msec() < deadline:
		await (Engine.get_main_loop() as SceneTree).process_frame
	return state["done"]


func _frames(n: int) -> void:
	for i in n:
		await (Engine.get_main_loop() as SceneTree).process_frame


func _click(v: Control, pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = pos
	v._gui_input(ev)


func test_fixture_loads_all_mechanics(t: T) -> void:
	var level := _fixture()
	t.ok(not level.is_empty(), "đọc được fixture cơ chế")
	var board := BoardState.new(level)
	var v := _view(board)
	t.eq(v.block_count(), 4, "4 node khối")
	t.eq(board.stones().size(), 1, "1 đá")
	var sc: Vector2i = board.stones()[0]
	t.eq(v.block_at(v.cell_center(sc)), "", "đá không phải khối, không chạm được")
	var seen: Array[String] = []
	v.block_tapped.connect(func(id: String) -> void: seen.append(id))
	_click(v, v.cell_center(sc))
	t.eq(seen.size(), 0, "chạm đá không phát block_tapped")
	t.eq(_fx_named(v, "WoodChips"), 1, "chạm gỗ văng dằm gỗ")
	t.eq(_fx_named(v, "WoodKnock"), 1, "ô gỗ nhún")
	t.eq(v.block_node("b1").view["ice"], 1, "b1 có băng")
	t.eq(v.block_node("b2").view["chained"], true, "b2 bị xích")
	t.eq(v.key_ids(), ["b3"] as Array[String], "b3 là chìa")
	t.eq(v.block_node("b4").view["inner_color"], "yellow", "b4 hai lớp")
	t.eq(v.gate_is_open("up"), false, "cổng trên đóng")
	t.near(v.gate_progress("up"), 0.0, 0.001, "hình cổng đóng")
	t.near(v.gate_progress("left"), 1.0, 0.001, "cạnh không có cổng nhịp coi như mở")
	t.eq(v.ghost_count(), 0, "chưa có hiệu ứng bóng")
	v.queue_free()


func test_ice_crack(t: T) -> void:
	var board := BoardState.new(_lv(5, 5, [_b("b1", "yellow", [[2, 2]], {"ice": 1}), _b("b2", "blue", [[0, 0]])]))
	var v := _view(board)
	t.eq(v.ghost_count(), 0, "đầu: không bóng")
	var r := board.tap("b1")
	t.eq(r["kind"], "crack", "lần 1 nứt")
	v.apply_result(r)
	t.eq(v.block_node("b1").view["ice"], 0, "băng hết sau khi nứt")
	t.ok(v.ghost_count() >= 1, "lớp pudding vỡ bay ra")
	t.ok(_fx_named(v, "JellyBurst") >= 1, "bọt pudding toả ra")
	t.eq(v.block_count(), 2, "khối còn nguyên")
	t.ok(await _wait_done(v), "crack xong")
	t.eq(v.ghost_count(), 0, "bóng đã dọn")
	t.eq(v.block_node("b1").scale, Vector2.ONE, "scale về 1")
	r = board.tap("b1")
	t.eq(r["kind"], "exit", "lần 2 đi")
	v.apply_result(r)
	t.ok(await _wait_done(v), "exit xong")
	t.eq(v.block_count(), 1, "b1 đã đi")
	v.queue_free()


func test_chain_and_key(t: T) -> void:
	var board := BoardState.new(_fixture())
	var v := _view(board)
	t.eq(v.key_ids(), ["b3"] as Array[String], "chìa b3")
	var r := board.tap("b2")
	t.eq(r["kind"], "chained", "chạm khối xích")
	v.apply_result(r)
	t.ok(_fx_named(v, "ChainSparks") >= 1, "xích bị giật toé lửa")
	t.ok(await _wait_done(v), "chained xong")
	t.eq(v.block_node("b2").view["chained"], true, "vẫn xích")
	t.eq(v.key_ids(), ["b3"] as Array[String], "chìa vẫn còn")
	t.eq(v.ghost_count(), 0, "chưa rơi xích")
	r = board.tap("b3")
	t.eq(r["kind"], "exit", "chìa thoát")
	v.apply_result(r)
	t.eq(v.block_node("b2").view["chained"], false, "b2 hết xích")
	t.eq(v.key_ids().size(), 0, "không còn chìa")
	t.ok(v.ghost_count() >= 1, "xích đứt bay ra")
	t.ok(_fx_named(v, "ChainLinks") >= 1, "mắt xích văng")
	t.ok(_fx_named(v, "LockPop") >= 1, "ổ khoá bật bay")
	t.ok(await _wait_done(v), "exit xong")
	t.eq(v.ghost_count(), 0, "bóng đã dọn")
	t.eq(v.block_count(), 3, "còn 3 khối")
	v.queue_free()


func test_two_layers_peel(t: T) -> void:
	var board := BoardState.new(_lv(5, 5, [_b("b1", "yellow", [[2, 2]], {"inner_color": "green"})]))
	var v := _view(board)
	t.eq(v.block_node("b1").view["color"], "yellow", "lớp ngoài vàng")
	t.eq(v.block_node("b1").view["inner_color"], "green", "lớp trong xanh lá")
	var r := board.tap("b1")
	t.eq(r["kind"], "peel", "bóc lớp")
	v.apply_result(r)
	t.eq(v.block_node("b1").view["color"], "green", "đổi sang lớp trong")
	t.eq(v.block_node("b1").view["inner_color"], "", "hết lớp trong")
	t.ok(v.ghost_count() >= 1, "hộp giấy bay ra")
	t.ok(await _wait_done(v), "peel xong")
	t.ok(_fx_named(v, "PaperBits") >= 1, "hộp rách thành giấy vụn ở thanh")
	t.eq(v.ghost_count(), 0, "bóng đã dọn")
	t.eq(v.block_count(), 1, "khối ở lại")
	t.eq(v.block_node("b1").scale, Vector2.ONE, "scale về 1")
	v.queue_free()


func _fog_level() -> Dictionary:
	# c ở giữa bị 4 khối vây; n (trên) thoát thì c lộ
	return _lv(3, 3, [
		_b("n", "yellow", [[1, 0]]),
		_b("w", "green", [[0, 1]]),
		_b("e", "blue", [[2, 1]]),
		_b("s", "purple", [[1, 2]]),
		_b("c", "blue", [[1, 1]], {"fog": true}),
	])


func test_fog_reveal(t: T) -> void:
	var board := BoardState.new(_fog_level())
	var v := _view(board)
	t.eq(v.block_node("c").view["is_fog_hidden"], true, "c trong sương mù")
	var r := board.tap("n")
	t.eq(r["kind"], "exit", "n thoát")
	t.eq(r["revealed"], ["c"] as Array[String], "c lộ")
	v.apply_result(r)
	t.eq(v.block_node("c").view["is_fog_hidden"], false, "view hết sương")
	t.ok(v.ghost_count() >= 1, "sương tan mờ dần")
	t.ok(await _wait_done(v), "exit xong")
	t.eq(v.ghost_count(), 0, "bóng đã dọn")
	v.queue_free()


func test_gate_toggles_visual(t: T) -> void:
	var level := _lv(5, 5, [
		_b("b1", "yellow", [[2, 3]]),
		_b("b2", "blue", [[0, 0]]),
		_b("b3", "green", [[4, 4]]),
	], {"pulse_sides": [{"side": "up", "open": false}, {"side": "down", "open": true}]})
	var board := BoardState.new(level)
	var v := _view(board)
	t.near(v.gate_progress("up"), 0.0, 0.001, "up đóng")
	t.near(v.gate_progress("down"), 1.0, 0.001, "down mở")
	var r := board.tap("b1")
	t.eq(r["kind"], "gate_closed", "cổng đóng chặn")
	v.apply_result(r)
	t.eq(v.gate_is_open("up"), true, "up mở sau chạm")
	t.eq(v.gate_is_open("down"), false, "down đóng sau chạm")
	t.ok(await _wait_done(v), "gate_closed xong")
	t.eq(v.block_count(), 3, "khối ở lại")
	t.near(v.gate_progress("up"), 1.0, 0.001, "hình up mở")
	t.near(v.gate_progress("down"), 0.0, 0.001, "hình down đóng")
	r = board.tap("b2")
	v.apply_result(r)
	t.ok(await _wait_done(v), "b2 xong")
	t.near(v.gate_progress("up"), 0.0, 0.001, "hình up đóng lại")
	t.near(v.gate_progress("down"), 1.0, 0.001, "hình down mở lại")
	v.queue_free()


func test_gate_refresh_and_fast_taps(t: T) -> void:
	var level := _lv(5, 5, [
		_b("b1", "green", [[4, 0]]), _b("b2", "green", [[4, 1]]), _b("b3", "green", [[4, 2]]),
	], {"pulse_sides": [{"side": "left", "open": false}]})
	var board := BoardState.new(level)
	var v := _view(board)
	# ba chạm liên tiếp không chờ: hoạt ảnh cổng bị ngắt giữa chừng vẫn kết thúc đúng
	for id in ["b1", "b2", "b3"]:
		v.apply_result(board.tap(id))
		await _frames(2)
	t.ok(await _wait_done(v), "xong chuỗi chạm nhanh")
	t.eq(board.gate_open("left"), true, "board: lẻ lần nên mở")
	t.near(v.gate_progress("left"), 1.0, 0.001, "hình khớp board")
	t.ok(not v.is_animating(), "không kẹt hoạt ảnh")
	board.add_moves(1)
	v.refresh()
	t.near(v.gate_progress("left"), 1.0, 0.001, "refresh giữ nguyên")
	v.queue_free()


func test_setup_resets_mechanic_state(t: T) -> void:
	var board := BoardState.new(_fixture())
	var v := _view(board)
	v.apply_result(board.tap("b1"))
	v.setup(BoardState.new(_lv(4, 4, [_b("a", "blue", [[0, 0]])])))
	t.eq(v.key_ids().size(), 0, "không còn chìa cũ")
	t.eq(v.ghost_count(), 0, "bóng cũ bị xoá")
	t.near(v.gate_progress("up"), 1.0, 0.001, "không còn cổng nhịp")
	t.ok(not v.is_animating(), "reset hoạt ảnh")
	v.queue_free()


func test_mech_assets_optional(t: T) -> void:
	# thiếu ảnh thật thì vẽ bằng code; có thì dùng. Cả hai phải cho kết quả nhất quán, không lỗi.
	const BoardFx := preload("res://src/ui/board_fx.gd")
	for n in ["mech_stone", "mech_ice", "mech_chain", "mech_key", "mech_fog"]:
		var tex := BoardFx.mech_tex(n)
		var real := ResourceLoader.exists("res://assets/ui/%s.png" % n)
		t.eq(tex != null, real, "%s: ảnh thật ⇔ có texture" % n)


# --- bố cục khi có cơ chế: bàn nằm trọn holder, căn giữa ---

func _mech_level(w: int, h: int) -> Dictionary:
	return _lv(w, h, [
		_b("b1", "yellow", [[1, 1]], {"ice": 1}),
		_b("b2", "blue", [[2, 2]], {"chained_by": "b1"}),
		_b("b3", "green", [[3, 1]], {"inner_color": "purple"}),
		_b("b4", "purple", [[1, 3]], {"fog": true}),
	], {"stones": [[w - 1, h - 1], [0, h - 1]], "pulse_sides": [
		{"side": "up", "open": false}, {"side": "left", "open": true},
		{"side": "right", "open": false}, {"side": "down", "open": true}]})


func _mech_in_holder(t: T, w: int, h: int, holder_size: Vector2) -> void:
	var host := Control.new()
	host.size = Vector2(holder_size.x + 56, holder_size.y + 344)
	_root().add_child(host)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(col)
	var top := Control.new()
	top.custom_minimum_size = Vector2(0, 300)
	col.add_child(top)
	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(holder)
	var v := (load(SCENE) as PackedScene).instantiate() as Control
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(v)
	var board := BoardState.new(_mech_level(w, h))
	v.setup(board)
	for step in 2:
		if step == 1:
			host.size = Vector2(holder_size.x * 0.5 + 56, holder_size.y * 0.5 + 344)
		await _frames(4)
		var tag := "%dx%d holder %s" % [w, h, str(holder.size)]
		var hs := holder.size
		var br: Rect2 = v.board_rect()
		t.ok(hs.x > 100.0 and hs.y > 100.0, "%s: holder có kích thước" % tag)
		t.ok(v.size.is_equal_approx(hs), "%s: BoardView = holder" % tag)
		t.ok(Rect2(Vector2.ZERO, hs).grow(1.5).encloses(v.frame_rect()), "%s: trọn holder (%s)" % [tag, str(br)])
		var off := (br.get_center() - hs * 0.5).abs()
		t.ok(off.x <= 2.0 and off.y <= 2.0, "%s: căn giữa (lệch %s)" % [tag, str(off)])
		t.eq(v.block_at(v.cell_center(Vector2i(2, 2))), "b2", "%s: chạm ô khối xích" % tag)
		t.eq(v.block_at(v.cell_center(Vector2i(w - 1, h - 1))), "", "%s: đá không chạm" % tag)
		var n: Control = v.block_node("b1")
		t.ok(Rect2(Vector2.ZERO, hs).encloses(Rect2(n.position, n.size)), "%s: khối trong vùng" % tag)
	# hiệu ứng bóng và cổng không làm vỡ bố cục: chạm băng rồi kiểm lại
	v.apply_result(board.tap("b1"))
	await _wait_done(v)
	var hs2 := holder.size
	t.ok(Rect2(Vector2.ZERO, hs2).grow(1.5).encloses(v.frame_rect()), "%dx%d: sau chạm vẫn trọn holder" % [w, h])
	t.eq(v.size, hs2, "%dx%d: size không đổi sau hoạt ảnh" % [w, h])
	host.free()


func test_mech_fit_in_holder(t: T) -> void:
	for dims in [Vector2i(5, 5), Vector2i(8, 11), Vector2i(7, 7), Vector2i(6, 9)]:
		await _mech_in_holder(t, dims.x, dims.y, Vector2(664, 936))


func _fx_named(v: Control, prefix: String) -> int:
	return v.get_node("Fx").get_children().filter(func(n: Node) -> bool: return n.name.begins_with(prefix) and not n.is_queued_for_deletion()).size()
