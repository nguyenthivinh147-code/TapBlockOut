extends RefCounted
## 20 level demo theo design.md mục 4: màu, số khối, HARD, kích thước, solver, hình khối.
const T := preload("res://tests/t.gd")
const BoardState := preload("res://src/core/board_state.gd")
const LevelData := preload("res://src/core/level_data.gd")
const Solver := preload("res://src/core/solver.gd")
const Validate := preload("res://tools/validate_levels.gd")
const Config := preload("res://src/config.gd")

const HARD_LEVELS := [8, 12, 16, 20]
const NEIGHBORS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func _load(id: int) -> Dictionary:
	var path := "res://data/levels/level_%04d.json" % id
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## [min, max] số khối theo bảng design.md.
func _count_range(id: int) -> Array:
	if id == 1:
		return [2, 2]
	if id <= 3:
		return [3, 4]
	if id <= 5:
		return [5, 7]
	if id <= 7:
		return [8, 10]
	if id == 8:
		return [10, 10]
	if id <= 11:
		return [12, 15]
	if id == 12:
		return [16, 16]
	if id <= 15:
		return [16, 20]
	if id == 16:
		return [22, 22]
	if id <= 19:
		return [22, 26]
	return [28, 28]


func _colors_wanted(id: int) -> int:
	if id <= 3:
		return 1
	if id <= 5:
		return 2
	if id <= 8:
		return 3
	return 4


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
	var prev_count := 0
	for id in range(1, 21):
		var d := _load(id)
		if d.is_empty():
			continue
		var n: int = d["blocks"].size()
		var rng := _count_range(id)
		t.ok(n >= rng[0] and n <= rng[1], "L%d số khối %d trong [%d, %d]" % [id, n, rng[0], rng[1]])
		t.ok(n >= prev_count, "L%d số khối không giảm" % id)
		prev_count = n
		t.eq(bool(d["hard"]), HARD_LEVELS.has(id), "L%d cờ HARD" % id)
		t.eq(_colors_of(d).size(), _colors_wanted(id), "L%d số màu" % id)
		t.eq(int(d["w"]), Config.BOARD_W, "L%d bàn rộng cố định" % id)
		t.eq(int(d["h"]), Config.BOARD_H, "L%d bàn cao cố định" % id)
		t.eq(d["stones"].size(), 0, "L%d không có đá" % id)
		t.eq(d["pulse_sides"].size(), 0, "L%d không có cổng nhịp" % id)
	# màu tăng dần: vàng từ đầu, thêm xanh lá L4, xanh dương L6, tím L9
	t.ok(_colors_of(_load(1)).has("yellow") and _colors_of(_load(1)).size() == 1, "L1 chỉ vàng")
	t.ok(_colors_of(_load(4)).has("green"), "L4 có xanh lá")
	t.ok(_colors_of(_load(6)).has("blue"), "L6 có xanh dương")
	t.ok(_colors_of(_load(9)).has("purple"), "L9 có tím")
	t.ok(not _colors_of(_load(8)).has("purple"), "L8 chưa có tím")


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
		if id <= 5:
			t.eq(slack, 3, "L%d dư 3" % id)
		elif HARD_LEVELS.has(id):
			t.eq(slack, 1, "L%d HARD dư 1" % id)
		else:
			t.ok(slack >= 2, "L%d dư >= 2" % id)
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
	# L2-3: có khối đầu tiên bị chặn (không phải khối nào cũng thoát ngay)
	for id in [2, 3]:
		var d := _load(id)
		var b := BoardState.new(d)
		var stuck := 0
		for bid in b.block_ids():
			if not b.can_exit(bid):
				stuck += 1
		t.ok(stuck >= 1, "L%d có khối bị chặn" % id)
	# L1 chỉ cần chạm là đi
	var b1 := BoardState.new(_load(1))
	for bid in b1.block_ids():
		t.ok(b1.can_exit(bid), "L1 %s thoát ngay" % bid)


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
	for k in ["bar", "L", "T", "S", "U"]:
		t.ok(seen.has(k), "có khối dạng %s" % k)
	t.ok(not seen.has("other"), "không có hình lạ")
	t.ok(sym >= 4, "ít nhất 4 level đối xứng (có %d)" % sym)
