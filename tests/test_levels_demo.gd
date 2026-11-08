extends RefCounted
## 20 level demo theo design.md mục 4: màu, số khối, HARD, kích thước, solver, hình khối.
const T := preload("res://tests/t.gd")
const BoardState := preload("res://src/core/board_state.gd")
const LevelData := preload("res://src/core/level_data.gd")
const Solver := preload("res://src/core/solver.gd")
const Validate := preload("res://tools/validate_levels.gd")
const Config := preload("res://src/config.gd")
const DifficultyCurve := preload("res://src/core/difficulty_curve.gd")

const NEIGHBORS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func _load(id: int) -> Dictionary:
	var path := "res://data/levels/level_%04d.json" % id
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _colors_of(d: Dictionary) -> Dictionary:
	var s := {}
	for b in d["blocks"]:
		s[b["color"]] = true
	return s


func _shape(cells: Array) -> String:
	var set := {}
	for c in cells:
		set[LevelData.cell_of(c)] = true
	var n := cells.size()
	if n == 1:
		return "mono"
	var xs := {}
	var ys := {}
	for c in set:
		xs[c.x] = true
		ys[c.y] = true
	if xs.size() == 1 or ys.size() == 1:
		return "bar"
	if n == 3:
		return "L"
	if n == 5 and xs.size() * ys.size() == 6:
		return "U"
	if n == 4:
		for c in set:
			var deg := 0
			for dv in NEIGHBORS:
				if set.has(c + dv):
					deg += 1
			if deg == 3:
				return "T"
		var cx := {}
		var cy := {}
		for c in set:
			cx[c.x] = cx.get(c.x, 0) + 1
			cy[c.y] = cy.get(c.y, 0) + 1
		var line := false
		for k in cx:
			line = line or cx[k] >= 3
		for k in cy:
			line = line or cy[k] >= 3
		return "L" if line else "S"
	return "other"


## Hình đối xứng trái phải quanh trục của chính nó (hình có thể lệch nửa ô so với giữa bàn).
func _mirror_symmetric(d: Dictionary) -> bool:
	var occ := {}
	var min_x := 1 << 20
	var max_x := -1
	for b in d["blocks"]:
		for c in b["cells"]:
			var cell := LevelData.cell_of(c)
			occ[cell] = true
			min_x = mini(min_x, cell.x)
			max_x = maxi(max_x, cell.x)
	for c in occ:
		if not occ.has(Vector2i(min_x + max_x - c.x, c.y)):
			return false
	return true


func test_files_exist_and_valid(t: T) -> void:
	for id in range(1, 21):
		var d := _load(id)
		t.ok(not d.is_empty(), "L%d đọc được" % id)
		if d.is_empty():
			continue
		var errs := Validate.check_file("res://data/levels/level_%04d.json" % id, "level_%04d.json" % id)
		t.eq(errs.size(), 0, "L%d hợp lệ %s" % [id, str(errs)])
		t.eq(int(d["id"]), id, "L%d id" % id)


func test_table(t: T) -> void:
	for id in range(1, 21):
		var d := _load(id)
		if d.is_empty():
			continue
		var n: int = d["blocks"].size()
		var want := DifficultyCurve.block_count(id)
		t.ok(absi(n - want) <= 2, "L%d số khối %d ~ đường cong %d" % [id, n, want])
		t.eq(bool(d["hard"]), DifficultyCurve.is_hard(id), "L%d cờ HARD" % id)
		if id <= 4:
			t.eq(_colors_of(d).size(), [2, 3, 3, 4][id - 1], "L%d số màu" % id)
		else:
			t.ok(_colors_of(d).size() >= 3, "L%d có ít nhất 3 màu" % id)
		t.eq(int(d["w"]), Config.BOARD_W, "L%d bàn rộng cố định" % id)
		t.eq(int(d["h"]), Config.BOARD_H, "L%d bàn cao cố định" % id)
		if id < int(Config.UNLOCK.stone):
			t.eq(d["stones"].size(), 0, "L%d chưa có đá" % id)
		t.eq(d["pulse_sides"].size(), 0, "L%d không có cổng nhịp" % id)
	# L1 có 2 màu, L4 đủ 4 màu: số màu tăng ngay từ 4 level đầu
	t.ok(_colors_of(_load(1)).size() == 2, "L1 hai màu")
	t.ok(_colors_of(_load(4)).size() == 4, "L4 đủ bốn màu")


func test_no_mechanics(t: T) -> void:
	for id in range(1, 21):
		var d := _load(id)
		if d.is_empty():
			continue
		for b in d["blocks"]:
			t.eq(int(b["ice"]), 0, "L%d %s không băng" % [id, b["id"]])
			t.eq(str(b["chained_by"]), "", "L%d %s không xích" % [id, b["id"]])
			t.eq(str(b["inner_color"]), "", "L%d %s không lớp trong" % [id, b["id"]])
			t.eq(bool(b["fog"]), false, "L%d %s không sương mù" % [id, b["id"]])


func test_solver_and_moves(t: T) -> void:
	for id in range(1, 21):
		var d := _load(id)
		if d.is_empty():
			continue
		var r := Solver.solve(d)
		t.ok(r["ok"], "L%d giải được" % id)
		t.eq(int(r["min_taps"]), d["blocks"].size(), "L%d min_taps bằng số khối (chỉ có thoát)" % id)
		t.eq(int(d["min_taps"]), int(r["min_taps"]), "L%d min_taps lưu" % id)
		var slack: int = Solver.slack_for(d)
		t.eq(int(d["moves"]), int(r["min_taps"]) + slack, "L%d moves" % id)
		if id <= 3:
			t.eq(slack, 5, "L%d dư 5" % id)
		elif DifficultyCurve.is_hard(id):
			t.eq(slack, 3, "L%d HARD dư 3" % id)
		else:
			t.eq(slack, 3 if id <= 13 else 4, "L%d dư 3 (L4-13) hoặc 4 (từ L14)" % id)
		t.ok(Solver.immediate_exit_exists(d), "L%d có khối thoát ngay" % id)


func test_play_through(t: T) -> void:
	for id in range(1, 21):
		var d := _load(id)
		if d.is_empty():
			continue
		var b := BoardState.new(d)
		t.eq(b.moves_left(), int(d["moves"]), "L%d moves ban đầu" % id)
		for bid in Solver.solve(d)["order"]:
			var res := b.tap(bid)
			t.eq(res["kind"], "exit", "L%d %s thoát" % [id, bid])
		t.ok(b.is_won(), "L%d thắng theo order" % id)
		t.eq(b.moves_left(), Solver.slack_for(d), "L%d còn đúng phần dư" % id)


func test_early_levels_have_blocked_block(t: T) -> void:
	# L3-4: có khối đầu tiên bị chặn (không phải khối nào cũng thoát ngay)
	for id in [3, 4]:
		var d := _load(id)
		var b := BoardState.new(d)
		var stuck := 0
		for bid in b.block_ids():
			if not b.can_exit(bid):
				stuck += 1
		t.ok(stuck >= 1, "L%d có khối bị chặn" % id)
	# L1-2 chỉ cần chạm là đi
	for id in [1, 2]:
		var b1 := BoardState.new(_load(id))
		for bid in b1.block_ids():
			t.ok(b1.can_exit(bid), "L%d %s thoát ngay" % [id, bid])


func test_shapes_and_layouts(t: T) -> void:
	var seen := {}
	var sym := 0
	var sigs := {}
	for id in range(1, 21):
		var d := _load(id)
		if d.is_empty():
			continue
		for b in d["blocks"]:
			seen[_shape(b["cells"])] = true
		if _mirror_symmetric(d):
			sym += 1
		var sig := JSON.stringify(d["blocks"])
		t.ok(not sigs.has(sig), "L%d không trùng layout level khác" % id)
		sigs[sig] = true
	for k in ["bar", "L"]:
		t.ok(seen.has(k), "có khối dạng %s" % k)
