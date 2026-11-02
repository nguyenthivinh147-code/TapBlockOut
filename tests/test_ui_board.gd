extends RefCounted
const T := preload("res://tests/t.gd")
const BoardState := preload("res://src/core/board_state.gd")
const Config := preload("res://src/config.gd")
const SCENE := "res://scenes/board_view.tscn"


func _b(id: String, color: String, cells: Array, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": id, "color": color, "cells": cells, "ice": 0, "chained_by": "",
		"inner_color": "", "fog": false}
	d.merge(extra, true)
	return d


func _lv(w: int, h: int, blocks: Array, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": 7, "w": w, "h": h, "hard": false, "min_taps": 0, "moves": 20, "seed": 0,
		"stones": [], "pulse_sides": [], "blocks": blocks}
	d.merge(extra, true)
	return d


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _make(level: Dictionary, area: Vector2 = Vector2(720, 900)) -> Control:
	var v := (load(SCENE) as PackedScene).instantiate() as Control
	_root().add_child(v)
	v.setup(BoardState.new(level), area)
	return v


func _wait_done(v: Control, limit_ms: int = 2000) -> bool:
	var state := {"done": false}
	v.animation_done.connect(func() -> void: state["done"] = true, CONNECT_ONE_SHOT)
	var deadline := Time.get_ticks_msec() + limit_ms
	while not state["done"] and Time.get_ticks_msec() < deadline:
		await (Engine.get_main_loop() as SceneTree).process_frame
	return state["done"]


func _click(v: Control, pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = pos
	v._gui_input(ev)


func test_layout_and_fit(t: T) -> void:
	var v := _make(_lv(5, 7, [_b("b1", "yellow", [[1, 1], [1, 2]]), _b("b2", "blue", [[3, 3]])]))
	t.eq(v.block_count(), 2, "2 node khối")
	var br: Rect2 = v.board_rect()
	t.ok(Rect2(Vector2.ZERO, v.size).encloses(v.frame_rect()), "bàn cùng khung cổng nằm trong vùng")
	t.ok(v.cell_size() <= 150.0, "ô không quá lớn")
	var c1: float = v.cell_size()
	v.fit_to(Vector2(360, 400))
	t.ok(v.cell_size() < c1, "vùng nhỏ thì ô co lại")
	t.ok(Rect2(Vector2.ZERO, v.size).encloses(v.board_rect()), "vẫn vừa vùng nhỏ")
	var n: Control = v.block_node("b1")
	t.near(n.size.y, v.cell_size() * 2.0, 0.01, "khối 2 ô cao 2 ô")
	t.eq(n.position, v.board_rect().position + Vector2(1, 1) * v.cell_size(), "vị trí khối theo ô")
	v.queue_free()


func test_cell_size_constant_across_boards(t: T) -> void:
	var small := _make(_lv(4, 5, [_b("b1", "yellow", [[1, 1], [1, 2]])]))
	var big := _make(_lv(Config.BOARD_W, Config.BOARD_H, [_b("b1", "yellow", [[1, 1], [1, 2]])]))
	t.near(small.cell_size(), big.cell_size(), 0.001, "bàn nhỏ và bàn chuẩn cùng cỡ ô")
	t.ok(Rect2(Vector2.ZERO, big.size).encloses(big.board_rect()), "bàn chuẩn vẫn vừa vùng")
	small.queue_free()
	big.queue_free()


## Cỡ ô cố định theo ảnh ref: không đổi theo số khối, không phóng to khi vùng chứa lớn hơn.
func test_cell_size_fixed_like_reference(t: T) -> void:
	var blocks := [_b("b1", "yellow", [[1, 1], [1, 2]])]
	for area in [Vector2(664, 936), Vector2(960, 1400), Vector2(1600, 2000)]:
		var v := _make(_lv(Config.BOARD_W, Config.BOARD_H, blocks))
		v.fit_to(area)
		t.near(v.cell_size(), float(Config.BOARD_CELL), 0.001, "vùng %s: ô đúng cỡ chuẩn" % str(area))
		t.near(v.board_rect().size.x, float(Config.BOARD_W * Config.BOARD_CELL), 0.001, "vùng %s: bàn đúng bề ngang" % str(area))
		t.ok(Rect2(Vector2.ZERO, area).encloses(v.frame_rect()), "vùng %s: khung nằm trọn" % str(area))
		v.queue_free()


func test_hit_area(t: T) -> void:
	var v := _make(_lv(5, 5, [_b("b1", "yellow", [[1, 1], [1, 2], [2, 2]])], {"stones": [[4, 4]]}))
	var seen: Array[String] = []
	v.block_tapped.connect(func(id: String) -> void: seen.append(id))
	t.eq(v.block_at(v.cell_center(Vector2i(1, 1))), "b1", "ô (1,1)")
	t.eq(v.block_at(v.cell_center(Vector2i(2, 2))), "b1", "ô (2,2)")
	t.eq(v.block_at(v.cell_center(Vector2i(2, 1))), "", "ô trống cạnh khối chữ L")
	t.eq(v.block_at(v.cell_center(Vector2i(4, 4))), "", "đá không chạm được")
	t.eq(v.block_at(Vector2(-5, -5)), "", "ngoài bàn")
	_click(v, v.cell_center(Vector2i(1, 2)))
	_click(v, v.cell_center(Vector2i(0, 0)))
	_click(v, v.cell_center(Vector2i(4, 4)))
	t.eq(seen, ["b1"] as Array[String], "chỉ ô của khối phát block_tapped")
	v.input_enabled = false
	_click(v, v.cell_center(Vector2i(1, 1)))
	t.eq(seen.size(), 1, "tắt input thì không phát")
	v.queue_free()


func test_exit_animation(t: T) -> void:
	var board := BoardState.new(_lv(5, 5, [_b("b1", "yellow", [[2, 2]]), _b("b2", "blue", [[0, 0]])]))
	var v := (load(SCENE) as PackedScene).instantiate() as Control
	_root().add_child(v)
	v.setup(board, Vector2(720, 900))
	var r := board.tap("b1")
	v.apply_result(r)
	t.eq(v.block_at(v.cell_center(Vector2i(2, 2))), "", "ô được giải phóng ngay")
	t.ok(v.is_animating(), "đang chạy hoạt ảnh")
	var done: bool = await _wait_done(v)
	t.ok(done, "animation_done phát")
	t.eq(v.block_count(), 1, "node khối đã xoá")
	t.ok(not v.is_animating(), "hết hoạt ảnh")
	v.queue_free()


func test_blocked_bounce_returns(t: T) -> void:
	var board := BoardState.new(_lv(5, 5, [_b("b1", "yellow", [[2, 4]]), _b("b2", "blue", [[2, 1]])]))
	var v := (load(SCENE) as PackedScene).instantiate() as Control
	_root().add_child(v)
	v.setup(board, Vector2(720, 900))
	var home := v.block_node("b1").position as Vector2
	var r := board.tap("b1")
	t.eq(r["kind"], "blocked", "bị chặn")
	v.apply_result(r)
	var done: bool = await _wait_done(v)
	t.ok(done, "animation_done sau khi bật về")
	t.eq(v.block_node("b1").position, home, "về đúng chỗ cũ")
	t.eq(v.block_count(), 2, "không mất khối")
	t.eq(v.block_at(v.cell_center(Vector2i(2, 4))), "b1", "vẫn chạm được")
	v.queue_free()


func test_rejected_and_unknown(t: T) -> void:
	var board := BoardState.new(_lv(3, 3, [_b("b1", "yellow", [[1, 1]])], {"moves": 0}))
	var v := (load(SCENE) as PackedScene).instantiate() as Control
	_root().add_child(v)
	v.setup(board, Vector2(720, 900))
	v.apply_result(board.tap("b1"))
	var done: bool = await _wait_done(v)
	t.ok(done, "rejected vẫn phát animation_done")
	t.eq(v.block_count(), 1, "không đổi")
	v.queue_free()


func test_arrow_setting(t: T) -> void:
	var v := _make(_lv(3, 3, [_b("b1", "yellow", [[1, 1]])]))
	t.eq(v.arrows_enabled, bool(Game.s.settings.get("arrows", true)), "theo cài đặt Game")
	v.set_arrows(false)
	t.eq(v.block_node("b1").show_arrow, false, "tắt mũi tên")
	v.set_arrows(true)
	t.eq(v.block_node("b1").show_arrow, true, "bật mũi tên")
	v.queue_free()


func test_highlight_and_smash(t: T) -> void:
	var board := BoardState.new(_lv(4, 4, [_b("b1", "yellow", [[1, 1]]), _b("b2", "green", [[3, 3]])]))
	var v := (load(SCENE) as PackedScene).instantiate() as Control
	_root().add_child(v)
	v.setup(board, Vector2(720, 900))
	v.highlight("b1")
	t.eq(v.highlighted_id(), "b1", "đang highlight")
	t.ok(v.block_node("b1").glow > 0.0, "có glow")
	v.clear_highlight()
	t.eq(v.highlighted_id(), "", "bỏ highlight")
	t.eq(v.block_node("b1").scale, Vector2.ONE, "scale về 1")
	v.highlight("b2")
	t.ok(board.smash("b2"), "board phá")
	v.smash_anim("b2")
	t.eq(v.highlighted_id(), "", "phá khối thì bỏ highlight")
	t.eq(v.block_at(v.cell_center(Vector2i(3, 3))), "", "ô trống ngay")
	var done: bool = await _wait_done(v)
	t.ok(done, "smash xong")
	t.eq(v.block_count(), 1, "còn 1 node")
	v.queue_free()


func test_mechanics_states(t: T) -> void:
	# xích: b2 bị b1 khoá; băng: b3; hai lớp: b4; sương mù: b5 bị che bởi b3, b4
	var level := _lv(6, 6, [
		_b("b1", "yellow", [[0, 5]]),
		_b("b2", "blue", [[1, 5]], {"chained_by": "b1"}),
		_b("b3", "green", [[5, 0]], {"ice": 1}),
		_b("b4", "purple", [[3, 2]], {"inner_color": "yellow"}),
	], {"pulse_sides": [{"side": "up", "open": false}]})
	var board := BoardState.new(level)
	var v := (load(SCENE) as PackedScene).instantiate() as Control
	_root().add_child(v)
	v.setup(board, Vector2(720, 900))
	t.eq(v.block_node("b2").view["chained"], true, "b2 bị xích")
	t.eq(v.block_node("b3").view["ice"], 1, "b3 có băng")
	# chạm b3: nứt
	var r := board.tap("b3")
	t.eq(r["kind"], "crack", "nứt")
	v.apply_result(r)
	t.eq(v.block_node("b3").view["ice"], 0, "view cập nhật băng")
	t.ok(await _wait_done(v), "crack xong")
	# chạm b2: bị xích
	r = board.tap("b2")
	t.eq(r["kind"], "chained", "xích")
	v.apply_result(r)
	t.ok(await _wait_done(v), "chained xong")
	t.eq(v.block_count(), 4, "không khối nào mất")
	# chạm b4: bóc lớp
	r = board.tap("b4")
	t.eq(r["kind"], "peel", "bóc lớp")
	v.apply_result(r)
	t.eq(v.block_node("b4").view["color"], "yellow", "đổi sang màu lớp trong")
	t.ok(await _wait_done(v), "peel xong")
	# b1 vàng: cổng up đóng sau 3 lần chạm hợp lệ (đổi mỗi lần): đóng -> mở -> đóng -> mở
	# lần này cổng đang ở trạng thái "mở" (đã đổi 3 lần) nên b1 thoát được
	r = board.tap("b1")
	t.eq(r["kind"], "exit", "b1 thoát")
	v.apply_result(r)
	t.eq(v.block_node("b2").view["chained"], false, "b2 hết xích khi chìa thoát")
	t.ok(await _wait_done(v), "exit xong")
	t.eq(v.block_count(), 3, "còn 3 khối")
	v.queue_free()


func test_gate_closed_and_fog(t: T) -> void:
	var level := _lv(5, 5, [
		_b("b1", "yellow", [[2, 3]]),
		_b("b2", "blue", [[1, 1]], {"fog": true}),
		_b("b3", "green", [[0, 1]]),
		_b("b4", "green", [[3, 0]]),
	], {"pulse_sides": [{"side": "up", "open": false}]})
	var board := BoardState.new(level)
	var v := (load(SCENE) as PackedScene).instantiate() as Control
	_root().add_child(v)
	v.setup(board, Vector2(720, 900))
	t.eq(v.block_node("b2").view["is_fog_hidden"], true, "b2 chưa có khối kề rời đi nên còn ẩn")
	var r := board.tap("b1")
	t.eq(r["kind"], "gate_closed", "cổng đóng")
	v.apply_result(r)
	t.ok(await _wait_done(v), "gate_closed xong")
	t.eq(v.block_count(), 4, "khối ở lại")
	r = board.tap("b1")
	t.eq(r["kind"], "exit", "lần sau cổng mở")
	v.apply_result(r)
	t.ok(await _wait_done(v), "exit xong")
	v.queue_free()


func test_setup_twice_resets(t: T) -> void:
	var v := _make(_lv(3, 3, [_b("b1", "yellow", [[1, 1]])]))
	t.eq(v.block_count(), 1, "lần 1")
	v.setup(BoardState.new(_lv(4, 4, [_b("a", "blue", [[0, 0]]), _b("b", "green", [[2, 2]])])))
	t.eq(v.block_count(), 2, "lần 2 thay hẳn")
	t.eq(v.block_at(v.cell_center(Vector2i(1, 1))), "", "ô cũ không còn")
	v.queue_free()


# --- bàn trong holder của VBox giống màn level: nằm trọn, căn giữa, theo đổi kích thước holder ---

func _fit_in_holder(t: T, w: int, h: int, holder_size: Vector2) -> void:
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
	v.setup(BoardState.new(_lv(w, h, [_b("b1", "yellow", [[1, 1]])])))
	for step in 2:
		if step == 1:
			host.size = Vector2(holder_size.x * 0.5 + 56, holder_size.y * 0.5 + 344)
		for i in 4:
			await (Engine.get_main_loop() as SceneTree).process_frame
		var tag := "%dx%d holder %s" % [w, h, str(holder.size)]
		var hs := holder.size
		t.ok(hs.x > 100.0 and hs.y > 100.0, "%s: holder có kích thước" % tag)
		t.ok(v.size.is_equal_approx(hs), "%s: BoardView = holder (%s)" % [tag, str(v.size)])
		var br: Rect2 = v.board_rect()
		t.ok(Rect2(Vector2.ZERO, hs).grow(1.5).encloses(v.frame_rect()), "%s: trọn holder (%s)" % [tag, str(br)])
		var off := (br.get_center() - hs * 0.5).abs()
		t.ok(off.x <= 2.0 and off.y <= 2.0, "%s: căn giữa (lệch %s)" % [tag, str(off)])
		t.near(br.size.x / float(w), br.size.y / float(h), 0.01, "%s: ô vuông" % tag)
		t.eq(v.block_at(v.cell_center(Vector2i(1, 1))), "b1", "%s: chạm đúng ô" % tag)
		t.eq(v.block_at(v.cell_center(Vector2i(0, 0))), "", "%s: ô trống không chạm" % tag)
	host.free()


func test_fit_in_holder(t: T) -> void:
	for dims in [Vector2i(4, 4), Vector2i(Config.BOARD_W, Config.BOARD_H), Vector2i(3, 3), Vector2i(7, 11)]:
		await _fit_in_holder(t, dims.x, dims.y, Vector2(664, 936))
