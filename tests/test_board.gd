extends RefCounted
const T := preload("res://tests/t.gd")
const BoardState := preload("res://src/core/board_state.gd")
const LevelData := preload("res://src/core/level_data.gd")


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


func _load(name: String) -> Dictionary:
	var f := FileAccess.open("res://tests/fixtures/%s.json" % name, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


func test_exit_and_distance(t: T) -> void:
	var b := BoardState.new(_lv(5, 5, [_b("b1", "yellow", [[2, 2], [2, 3]]), _b("b2", "blue", [[0, 0]])]))
	t.eq(b.remaining_count(), 2, "2 khối")
	var r := b.tap("b1")
	t.eq(r["kind"], "exit", "vàng thoát")
	t.eq(r["distance"], 4, "khoảng cách tới khi rời hẳn")
	t.eq(r["moves_left"], 19, "giảm 1 MOVES")
	t.eq(r["won"], false, "chưa thắng")
	t.eq(b.remaining_count(), 1, "còn 1 khối")
	# Bốn hướng.
	for pair in [["yellow", Vector2i(0, -1)], ["green", Vector2i(-1, 0)], ["blue", Vector2i(1, 0)], ["purple", Vector2i(0, 1)]]:
		var c := BoardState.new(_lv(5, 5, [_b("x", pair[0], [[2, 2]])]))
		var rr := c.tap("x")
		t.eq(rr["kind"], "exit", "hướng " + pair[0])
		t.eq(rr["won"], true, "thắng khi hết khối " + pair[0])
		t.ok(LevelData.dir_of(pair[0]) == pair[1], "hằng hướng " + pair[0])


func test_blocked_by_block_and_stone(t: T) -> void:
	var b := BoardState.new(_lv(5, 5,
		[_b("y", "yellow", [[2, 4]]), _b("g", "green", [[2, 1]]), _b("p", "purple", [[4, 0]])],
		{"stones": [[4, 3]]}))
	var r := b.tap("y")
	t.eq(r["kind"], "blocked", "bị khối chặn")
	t.eq(r["distance"], 2, "trượt 2 ô tới (2,2)")
	t.eq(r["blocker"], "g", "khối chặn")
	t.eq(r["moves_left"], 19, "chạm bị chặn vẫn tốn 1")
	t.eq(b.remaining_count(), 3, "bàn không đổi")
	var r2 := b.tap("p")
	t.eq(r2["kind"], "blocked", "đá chặn")
	t.eq(r2["distance"], 2, "tới (4,2)")
	t.eq(r2["blocker"], "stone", "blocker là đá")
	# Khối nhiều ô: ô sau bị chặn bởi khối ở cột khác thì không.
	var c := BoardState.new(_lv(5, 5, [_b("l", "yellow", [[1, 3], [2, 3]]), _b("o", "green", [[2, 1]])]))
	var r3 := c.tap("l")
	t.eq(r3["kind"], "blocked", "ô (2,3) bị chặn")
	t.eq(r3["distance"], 1, "trượt 1 ô")


func test_own_cells_do_not_block(t: T) -> void:
	var b := BoardState.new(_lv(4, 6, [_b("tall", "purple", [[1, 0], [1, 1], [1, 2]])]))
	t.eq(b.tap("tall")["kind"], "exit", "thanh dọc tự trượt")


func test_rejected_cases(t: T) -> void:
	var b := BoardState.new(_lv(4, 4, [_b("a", "yellow", [[0, 0]])]))
	t.eq(b.tap("zzz")["kind"], "rejected", "id lạ")
	t.eq(b.moves_left(), 20, "không tốn")
	b.tap("a")
	t.eq(b.is_won(), true, "thắng")
	var r := b.tap("a")
	t.eq(r["kind"], "rejected", "đã thắng")
	t.eq(r["won"], true, "won giữ nguyên")
	var c := BoardState.new(_lv(4, 4, [_b("a", "yellow", [[0, 1]]), _b("b", "blue", [[3, 3]])], {"moves": 1}))
	t.eq(c.tap("a")["kind"], "exit", "tap cuối")
	t.eq(c.moves_left(), 0, "hết MOVES")
	t.eq(c.is_out_of_moves(), true, "hết MOVES chưa thắng")
	var r2 := c.tap("b")
	t.eq(r2["kind"], "rejected", "hết MOVES thì từ chối")
	t.eq(r2["moves_left"], 0, "không âm")
	c.add_moves(3)
	t.eq(c.moves_left(), 3, "cộng MOVES")
	t.eq(c.is_out_of_moves(), false, "còn MOVES")
	t.eq(c.tap("b")["won"], true, "thắng sau khi cộng")
	t.eq(c.is_out_of_moves(), false, "thắng thì không tính hết MOVES")


func test_win_on_last_move(t: T) -> void:
	var b := BoardState.new(_lv(3, 3, [_b("a", "yellow", [[1, 1]])], {"moves": 1}))
	var r := b.tap("a")
	t.eq(r["won"], true, "thắng ở nước cuối")
	t.eq(b.is_out_of_moves(), false, "không phải hết MOVES")


func test_ice(t: T) -> void:
	var b := BoardState.new(_lv(5, 5, [_b("i", "yellow", [[2, 2]], {"ice": 1})]))
	t.eq(b.can_exit("i"), false, "băng chưa đi được")
	t.eq(b.hint(), "", "hint rỗng khi chỉ còn khối băng")
	var r := b.tap("i")
	t.eq(r["kind"], "crack", "nứt")
	t.eq(r["moves_left"], 19, "nứt tốn MOVES")
	t.eq(b.remaining_count(), 1, "khối còn")
	t.eq(b.block_view("i")["ice"], 0, "hết băng")
	t.eq(b.can_exit("i"), true, "đi được")
	t.eq(b.tap("i")["kind"], "exit", "thoát")


func test_chain(t: T) -> void:
	var b := BoardState.new(_lv(5, 5, [
		_b("k", "blue", [[0, 4]]),
		_b("c", "green", [[3, 1]], {"chained_by": "k"})]))
	t.eq(b.can_exit("c"), false, "xích")
	t.eq(b.block_view("c")["chained"], true, "view chained")
	var r := b.tap("c")
	t.eq(r["kind"], "chained", "bị xích")
	t.eq(r["blocker"], "k", "chìa")
	t.eq(r["moves_left"], 19, "tốn MOVES")
	b.tap("k")
	t.eq(b.can_exit("c"), true, "chìa đã thoát")
	t.eq(b.block_view("c")["chained"], false, "hết xích")
	t.eq(b.tap("c")["kind"], "exit", "đi được")
	# Phá chìa cũng mở xích.
	var c := BoardState.new(_lv(5, 5, [
		_b("k", "blue", [[0, 4]]),
		_b("c", "green", [[3, 1]], {"chained_by": "k"})]))
	t.eq(c.smash("k"), true, "phá chìa")
	t.eq(c.can_exit("c"), true, "mở xích")
	# Xích đi trước băng.
	var d := BoardState.new(_lv(5, 5, [
		_b("k", "blue", [[0, 4]]),
		_b("c", "green", [[3, 1]], {"chained_by": "k", "ice": 1})]))
	t.eq(d.tap("c")["kind"], "chained", "xích trước băng")
	d.tap("k")
	t.eq(d.tap("c")["kind"], "crack", "rồi tới băng")


func test_peel(t: T) -> void:
	var b := BoardState.new(_lv(5, 5, [_b("p", "purple", [[2, 1]], {"inner_color": "yellow"})]))
	t.eq(b.can_exit("p"), true, "lớp ngoài đi được")
	var r := b.tap("p")
	t.eq(r["kind"], "peel", "bóc lớp")
	t.eq(r["distance"], 4, "lớp ngoài trượt hết bàn")
	t.eq(b.remaining_count(), 1, "khối ở nguyên")
	t.eq(b.is_won(), false, "chưa thắng")
	var v := b.block_view("p")
	t.eq(v["color"], "yellow", "lộ màu trong")
	t.eq(v["inner_color"], "", "hết lớp")
	var r2 := b.tap("p")
	t.eq(r2["kind"], "exit", "thoát bằng màu trong")
	t.eq(r2["distance"], 2, "hướng lên")
	t.eq(r2["won"], true, "thắng")
	# Lớp ngoài bị chặn thì chưa bóc được.
	var c := BoardState.new(_lv(5, 5, [
		_b("p", "purple", [[2, 1]], {"inner_color": "yellow"}),
		_b("s", "blue", [[2, 3]])]))
	t.eq(c.tap("p")["kind"], "blocked", "lớp ngoài bị chặn")


func test_fog(t: T) -> void:
	var lvl := _lv(3, 3, [
		_b("f", "yellow", [[1, 1]], {"fog": true}),
		_b("n", "yellow", [[1, 0]]),
		_b("w", "green", [[0, 1]]),
		_b("e", "blue", [[2, 1]]),
		_b("s", "purple", [[1, 2]])])
	var b := BoardState.new(lvl)
	t.eq(b.block_view("f")["is_fog_hidden"], true, "bị vây nên ẩn")
	t.eq(b.block_view("n")["is_fog_hidden"], false, "khối thường không ẩn")
	var r := b.tap("f")
	t.eq(r["kind"], "blocked", "chạm khối ẩn vẫn tốn MOVES nếu bị chặn")
	t.eq(r["moves_left"], 19, "tốn 1")
	t.eq(b.block_view("f")["is_fog_hidden"], true, "vẫn ẩn")
	var r2 := b.tap("n")
	t.eq(r2["kind"], "exit", "n thoát")
	t.eq(r2["revealed"].size(), 1, "lộ 1 khối")
	t.eq(r2["revealed"][0], "f", "lộ f")
	t.eq(b.block_view("f")["is_fog_hidden"], false, "hết ẩn")
	# Khối ẩn lộ ngay từ đầu nếu có ô kề trống.
	var c := BoardState.new(_lv(4, 4, [_b("f", "yellow", [[2, 2]], {"fog": true})]))
	t.eq(c.block_view("f")["is_fog_hidden"], false, "có ô trống kề")
	# Đá không phải ô trống.
	var d := BoardState.new(_lv(3, 3, [_b("f", "yellow", [[1, 1]], {"fog": true})],
		{"stones": [[0, 1], [2, 1], [1, 0], [1, 2]]}))
	t.eq(d.block_view("f")["is_fog_hidden"], true, "đá vây")
	# Phá khối lân cận cũng làm lộ.
	var e := BoardState.new(lvl)
	e.smash("w")
	t.eq(e.block_view("f")["is_fog_hidden"], false, "phá w làm lộ f")


func test_pulse_gate(t: T) -> void:
	var lvl := _lv(5, 5, [
		_b("y", "yellow", [[2, 2]]),
		_b("g", "green", [[0, 4]])],
		{"pulse_sides": [{"side": "up", "open": false}]})
	var b := BoardState.new(lvl)
	t.eq(b.gate_open("up"), false, "cổng trên đóng")
	t.eq(b.gate_open("left"), true, "cạnh không có nhịp luôn mở")
	t.eq(b.can_exit("y"), false, "đóng thì không thoát")
	t.eq(b.hint(), "g", "hint bỏ qua khối bị cổng đóng")
	var r := b.tap("y")
	t.eq(r["kind"], "gate_closed", "cổng đóng")
	t.eq(r["distance"], 2, "trượt tới mép")
	t.eq(r["moves_left"], 19, "tốn MOVES")
	t.eq(b.gate_open("up"), true, "đổi sau mỗi chạm")
	t.eq(b.can_exit("y"), true, "giờ mở")
	t.eq(b.hint(), "y", "hint tính cổng mở")
	var r2 := b.tap("g")
	t.eq(r2["kind"], "exit", "g thoát")
	t.eq(b.gate_open("up"), false, "đổi lại")
	# Chạm bị chặn cũng đổi nhịp.
	var c := BoardState.new(_lv(5, 5, [
		_b("x", "purple", [[0, 0]]), _b("z", "yellow", [[0, 2]])],
		{"pulse_sides": [{"side": "up", "open": false}, {"side": "down", "open": true}]}))
	var rc := c.tap("x")
	t.eq(rc["kind"], "blocked", "chặn")
	t.eq(c.gate_open("up"), true, "up mở")
	t.eq(c.gate_open("down"), false, "down đóng")
	# smash không đổi nhịp.
	c.smash("z")
	t.eq(c.gate_open("up"), true, "smash không đổi nhịp")
	t.eq(c.moves_left(), 19, "smash không tốn MOVES")


func test_smash(t: T) -> void:
	var b := BoardState.new(_lv(5, 5, [_b("a", "yellow", [[1, 1]]), _b("b", "blue", [[2, 2]])],
		{"stones": [[4, 4]]}))
	t.eq(b.smash("a"), true, "phá a")
	t.eq(b.moves_left(), 20, "không tốn MOVES")
	t.eq(b.remaining_count(), 1, "còn 1")
	t.eq(b.smash("a"), false, "đã phá")
	t.eq(b.smash("stone"), false, "đá không chọn được")
	t.eq(b.smash("nope"), false, "id lạ")
	t.eq(b.is_won(), false, "chưa thắng")
	t.eq(b.smash("b"), true, "phá b")
	t.eq(b.is_won(), true, "phá khối cuối thì thắng")


func test_smash_at_zero_moves(t: T) -> void:
	var c := BoardState.new(_lv(5, 5, [_b("a", "yellow", [[1, 1]]), _b("b", "blue", [[1, 3]]),
		_b("c", "purple", [[4, 4]])], {"moves": 1}))
	c.tap("b")
	t.eq(c.is_out_of_moves(), true, "hết MOVES")
	t.eq(c.smash("a"), true, "phá khi 0 MOVES")
	t.eq(c.smash("c"), true, "phá nốt")
	t.eq(c.is_won(), true, "thắng bằng phá")


func test_hint(t: T) -> void:
	var b := BoardState.new(_lv(5, 5, [
		_b("blk", "yellow", [[2, 4]]), _b("top", "green", [[2, 1]])]))
	t.eq(b.hint(), "top", "khối đi được ngay")
	b.tap("top")
	t.eq(b.hint(), "blk", "sau khi top thoát")
	b.tap("blk")
	t.eq(b.hint(), "", "thắng thì rỗng")
	var dead := BoardState.new(_load("unsolvable"))
	t.eq(dead.hint(), "", "không có khối đi được")


func test_clone_independent(t: T) -> void:
	var b := BoardState.new(_lv(5, 5, [_b("a", "yellow", [[2, 2]], {"ice": 1}), _b("b", "blue", [[0, 0]])],
		{"pulse_sides": [{"side": "up", "open": false}]}))
	var c := b.clone()
	c.tap("b")
	c.tap("a")
	t.eq(b.remaining_count(), 2, "bản gốc giữ nguyên")
	t.eq(b.moves_left(), 20, "MOVES gốc")
	t.eq(b.block_view("a")["ice"], 1, "băng gốc")
	t.eq(b.gate_open("up"), false, "cổng gốc")
	t.eq(c.remaining_count(), 1, "bản sao đổi")
	t.ok(b.state_key() != c.state_key(), "khoá khác nhau")
	t.eq(b.clone().state_key(), b.state_key(), "clone cùng khoá")


func test_block_view_and_ids(t: T) -> void:
	var b := BoardState.new(_lv(5, 5, [_b("a", "yellow", [[1, 1], [1, 2]]), _b("b", "blue", [[3, 3]])]))
	var ids := b.block_ids()
	t.eq(ids.size(), 2, "2 id")
	t.eq(ids[0], "a", "đúng thứ tự")
	var v := b.block_view("a")
	t.eq(v["color"], "yellow", "màu")
	t.eq(v["cells"].size(), 2, "2 ô")
	t.ok(v["cells"][0] == Vector2i(1, 1), "ô đầu")
	t.eq(b.block_view("zz").size(), 0, "id lạ trả rỗng")
	b.tap("b")
	t.eq(b.block_ids().size(), 1, "b đã thoát")


func test_fixture_mechanics(t: T) -> void:
	var b := BoardState.new(_load("mechanics"))
	t.eq(b.remaining_count(), 4, "4 khối")
	t.eq(b.gate_open("up"), false, "cổng trên đóng")
	t.eq(b.tap("b1")["kind"], "crack", "b1 băng")
	t.eq(b.tap("b2")["kind"], "chained", "b2 bị xích")


func test_validate_ok(t: T) -> void:
	for n in ["basic", "mechanics", "unsolvable"]:
		var errs := LevelData.validate(_load(n))
		t.eq(errs.size(), 0, "fixture %s hợp lệ: %s" % [n, str(errs)])


func test_validate_errors(t: T) -> void:
	var base := _lv(4, 4, [_b("a", "yellow", [[0, 0], [0, 1]]), _b("b", "blue", [[3, 3]])])
	t.eq(LevelData.validate(base).size(), 0, "nền hợp lệ")
	var d := base.duplicate(true)
	d.erase("w")
	t.ok(LevelData.validate(d).size() > 0, "thiếu w")
	d = base.duplicate(true)
	d.erase("blocks")
	t.ok(LevelData.validate(d).size() > 0, "thiếu blocks")
	d = base.duplicate(true)
	d["blocks"][1]["cells"] = [[0, 1]]
	t.ok(LevelData.validate(d).size() > 0, "ô trùng")
	d = base.duplicate(true)
	d["blocks"][1]["cells"] = [[4, 3]]
	t.ok(LevelData.validate(d).size() > 0, "ô ngoài bàn")
	d = base.duplicate(true)
	d["blocks"][1]["cells"] = [[-1, 0]]
	t.ok(LevelData.validate(d).size() > 0, "ô âm")
	d = base.duplicate(true)
	d["blocks"][1]["id"] = "a"
	t.ok(LevelData.validate(d).size() > 0, "id trùng")
	d = base.duplicate(true)
	d["blocks"][1]["color"] = "red"
	t.ok(LevelData.validate(d).size() > 0, "màu lạ")
	d = base.duplicate(true)
	d["blocks"][1]["chained_by"] = "ghost"
	t.ok(LevelData.validate(d).size() > 0, "chìa không tồn tại")
	d = base.duplicate(true)
	d["blocks"][1]["chained_by"] = "b"
	t.ok(LevelData.validate(d).size() > 0, "tự xích")
	d = base.duplicate(true)
	d["blocks"][0]["chained_by"] = "b"
	d["blocks"][1]["chained_by"] = "a"
	var errs := LevelData.validate(d)
	var cyc := false
	for e in errs:
		if "chu trình" in e:
			cyc = true
	t.ok(cyc, "chu trình xích")
	d = base.duplicate(true)
	d["blocks"][0]["cells"] = [[0, 0], [0, 2]]
	t.ok(LevelData.validate(d).size() > 0, "ô không liền nhau")
	d = base.duplicate(true)
	d["stones"] = [[3, 3]]
	t.ok(LevelData.validate(d).size() > 0, "đá đè khối")
	d = base.duplicate(true)
	d["stones"] = [[9, 9]]
	t.ok(LevelData.validate(d).size() > 0, "đá ngoài bàn")
	d = base.duplicate(true)
	d["pulse_sides"] = [{"side": "north", "open": true}]
	t.ok(LevelData.validate(d).size() > 0, "cạnh lạ")
	d = base.duplicate(true)
	d["pulse_sides"] = [{"side": "up", "open": true}, {"side": "up", "open": false}]
	t.ok(LevelData.validate(d).size() > 0, "cạnh trùng")
	d = base.duplicate(true)
	d["blocks"][0]["ice"] = 2
	t.ok(LevelData.validate(d).size() > 0, "ice 2")
	d = base.duplicate(true)
	d["blocks"][0]["inner_color"] = "pink"
	t.ok(LevelData.validate(d).size() > 0, "lớp trong lạ")
	d = base.duplicate(true)
	d["min_taps"] = 30
	t.ok(LevelData.validate(d).size() > 0, "moves < min_taps")
	d = base.duplicate(true)
	d["w"] = 0
	t.ok(LevelData.validate(d).size() > 0, "w = 0")
