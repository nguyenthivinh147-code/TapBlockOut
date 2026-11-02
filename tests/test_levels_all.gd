extends RefCounted
## 300 level đóng gói sẵn (Task 9.3): L1-20 làm sẵn, L21-300 do tools/gen_levels.gd sinh, 6 level dạy làm tay.
const T := preload("res://tests/t.gd")
const BoardState := preload("res://src/core/board_state.gd")
const LevelData := preload("res://src/core/level_data.gd")
const Solver := preload("res://src/core/solver.gd")
const Gen := preload("res://src/core/level_generator.gd")
const GenTool := preload("res://tools/gen_levels.gd")
const Config := preload("res://src/config.gd")

const TOTAL := 300
const HARD_EARLY := [8, 12, 16, 20]
const MECHS := ["stone", "ice", "chain", "layer", "fog", "pulse"]

var _cache: Dictionary = {}  # id -> level


## Cùng khuôn với dữ liệu đọc từ file (số nguyên thành số thực qua JSON).
func _norm(d: Dictionary) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(d)))


func _level(id: int) -> Dictionary:
	if not _cache.has(id):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/level_%04d.json" % id))
		_cache[id] = parsed if parsed is Dictionary else {}
	return _cache[id]


## Tập cơ chế có mặt trong level.
func _mechs(d: Dictionary) -> Dictionary:
	var m := {}
	if not d["stones"].is_empty():
		m["stone"] = 0
	if not d["pulse_sides"].is_empty():
		m["pulse"] = 0
	for b in d["blocks"]:
		if int(b["ice"]) > 0:
			m["ice"] = int(m.get("ice", 0)) + 1
		if str(b["chained_by"]) != "":
			m["chain"] = int(m.get("chain", 0)) + 1
		if str(b["inner_color"]) != "":
			m["layer"] = int(m.get("layer", 0)) + 1
		if bool(b["fog"]):
			m["fog"] = int(m.get("fog", 0)) + 1
	return m


## Khung bao các ô có khối hoặc đá.
func _footprint(d: Dictionary) -> Rect2i:
	var r := Rect2i()
	var first := true
	var all: Array = d["stones"].duplicate()
	for b in d["blocks"]:
		all.append_array(b["cells"])
	for raw in all:
		var c := LevelData.cell_of(raw)
		r = Rect2i(c, Vector2i.ONE) if first else r.expand(c).expand(c + Vector2i.ONE)
		first = false
	return r


## Khối xếp thành hình, không kín khung bao của hình đó; hình nằm giữa bàn, có khoảng trống quanh.
func test_levels_form_shapes_with_gaps(t: T) -> void:
	var shapes := {}
	var gappy := 0
	for id in range(1, TOTAL + 1):
		var d := _level(id)
		if d.is_empty():
			continue
		var box := _footprint(d)
		var cells: Array = d["stones"].duplicate()
		for b in d["blocks"]:
			cells.append_array(b["cells"])
		t.ok(cells.size() < Config.BOARD_W * Config.BOARD_H, "L%d còn khoảng trống trên bàn" % id)
		t.ok(absi(box.position.x - (Config.BOARD_W - box.end.x)) <= 1, "L%d giữa bàn theo chiều ngang" % id)
		t.ok(absi(box.position.y - (Config.BOARD_H - box.end.y)) <= 1, "L%d giữa bàn theo chiều dọc" % id)
		if cells.size() < box.size.x * box.size.y:
			gappy += 1
		shapes[str(box.size) + ":" + str(cells.size())] = true
	t.ok(gappy >= TOTAL * 0.95, "hầu hết level có khoảng trống trong hình (%d/%d)" % [gappy, TOTAL])
	t.ok(shapes.size() >= 40, "nhiều hình dạng khác nhau (%d)" % shapes.size())


func _early_range(id: int) -> Array:
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


func _early_colors(id: int) -> int:
	if id <= 3:
		return 1
	if id <= 5:
		return 2
	if id <= 8:
		return 3
	return 4


func test_all_files_and_ids(t: T) -> void:
	for id in range(1, TOTAL + 1):
		var d := _level(id)
		t.ok(not d.is_empty(), "L%d đọc được" % id)
		if not d.is_empty():
			t.eq(int(d["id"]), id, "L%d id liên tục" % id)
	t.ok(not FileAccess.file_exists("res://data/levels/level_%04d.json" % (TOTAL + 1)), "không có level thừa")


func test_every_level_solvable(t: T) -> void:
	for id in range(1, TOTAL + 1):
		var d := _level(id)
		if d.is_empty():
			continue
		var errs := LevelData.validate(d)
		t.ok(errs.is_empty(), "L%d validate %s" % [id, str(errs)])
		if not errs.is_empty():
			continue
		var r := Solver.solve(d)
		t.ok(bool(r["ok"]), "L%d solver ok" % id)
		t.eq(int(d["min_taps"]), int(r["min_taps"]), "L%d min_taps" % id)
		t.eq(int(d["moves"]), int(r["min_taps"]) + Solver.slack_for(d), "L%d moves = compute_moves" % id)
		t.ok(Solver.immediate_exit_exists(d), "L%d có khối thoát ngay" % id)
		t.ok(not d["blocks"].is_empty(), "L%d có khối" % id)
		t.eq(int(d["w"]), Config.BOARD_W, "L%d bàn rộng cố định" % id)
		t.eq(int(d["h"]), Config.BOARD_H, "L%d bàn cao cố định" % id)


func test_play_through_solver_order(t: T) -> void:
	for id in range(1, TOTAL + 1):
		var d := _level(id)
		if d.is_empty():
			continue
		var r := Solver.solve(d)
		if not bool(r["ok"]):
			continue
		var b := BoardState.new(d)
		for bid in r["order"]:
			b.tap(bid)
		t.ok(b.is_won(), "L%d thắng theo order" % id)
		t.eq(b.moves_left(), Solver.slack_for(d), "L%d còn đúng phần dư" % id)


func test_early_levels_unchanged(t: T) -> void:
	for id in range(1, 21):
		var d := _level(id)
		if d.is_empty():
			continue
		var n: int = d["blocks"].size()
		var rng := _early_range(id)
		t.ok(n >= rng[0] and n <= rng[1], "L%d số khối %d" % [id, n])
		var cols := {}
		for b in d["blocks"]:
			cols[b["color"]] = true
		t.eq(cols.size(), _early_colors(id), "L%d số màu" % id)
		t.eq(bool(d["hard"]), HARD_EARLY.has(id), "L%d cờ HARD" % id)
		t.eq(_mechs(d).size(), 0, "L%d không cơ chế" % id)


func test_hard_every_fourth(t: T) -> void:
	var hard := 0
	for id in range(21, TOTAL + 1):
		var d := _level(id)
		if d.is_empty():
			continue
		t.eq(bool(d["hard"]), id % 4 == 0, "L%d cờ HARD" % id)
		if bool(d["hard"]):
			hard += 1
			t.eq(Solver.slack_for(d), 1, "L%d HARD dư 1" % id)
	t.eq(hard, 70, "70 level HARD trong L21-300")


func test_mechanics_follow_unlock_table(t: T) -> void:
	var first := {}
	var count := {}
	for id in range(1, TOTAL + 1):
		var d := _level(id)
		if d.is_empty():
			continue
		for m in _mechs(d):
			t.ok(id >= int(Config.UNLOCK[m]), "L%d có %s trước level mở khoá %d" % [id, m, int(Config.UNLOCK[m])])
			if not first.has(m):
				first[m] = id
			count[m] = int(count.get(m, 0)) + 1
	for m in MECHS:
		var u := int(Config.UNLOCK[m])
		t.eq(int(first.get(m, 0)), u, "%s xuất hiện đầu tiên ở level mở khoá %d" % [m, u])
		t.ok(int(count.get(m, 0)) >= 30, "%s dùng đủ nhiều (%d level)" % [m, int(count.get(m, 0))])
	# Cơ chế mới không biến mất sau level dạy: 10 level sau mỗi level dạy đều còn cơ chế đó.
	for m in MECHS:
		var u := int(Config.UNLOCK[m])
		var hit := 0
		for id in range(u + 1, u + 11):
			if _mechs(_level(id)).has(m):
				hit += 1
		t.ok(hit >= 8, "%s có mặt trong 10 level sau level dạy (%d)" % [m, hit])


func test_teaching_levels(t: T) -> void:
	var ids := {}
	for m in MECHS:
		var id := int(Config.UNLOCK[m])
		ids[m] = id
		t.eq(GenTool.teach_id(m), id, "%s: id dạy khớp Config.UNLOCK" % m)
		t.eq(GenTool.teach_mech(id), m, "L%d dạy %s" % [id, m])
		var d := _level(id)
		if d.is_empty():
			continue
		var mech := _mechs(d)
		t.eq(mech.keys(), [m], "L%d chỉ có đúng cơ chế mới %s" % [id, m])
		t.ok(not bool(d["hard"]), "L%d không HARD" % id)
		var n: int = d["blocks"].size()
		var box := _footprint(d)
		t.ok(n <= 8 and box.size.x * box.size.y <= 25, "L%d hình nhỏ (%d khối, %s)" % [id, n, str(box.size)])
		var b := BoardState.new(d)
		t.ok(b.hint() != "", "L%d có khối thoát ngay" % id)
		var exits := 0
		for bid in b.block_ids():
			if b.can_exit(bid):
				exits += 1
		# Level hai lớp: khối nhiều lớp tính là "đi được" (bóc) nên chờ thể hiện ở min_taps (kiểm riêng bên dưới).
		t.ok(exits >= 2 and (exits < n or m == "layer"), "L%d có khối thoát ngay và có khối phải chờ (%d/%d)" % [id, exits, n])
		# Dựng lại bằng bảng tay phải ra đúng file đã đóng gói.
		var rebuilt := GenTool.build_teach(m)
		t.eq(_norm(rebuilt), _norm(d), "L%d khớp bảng TEACH" % id)
		var r := Solver.solve(d)
		match m:
			"stone":
				var near := false
				for s in d["stones"]:
					var sc := LevelData.cell_of(s)
					for bl in d["blocks"]:
						for c in bl["cells"]:
							var dv := LevelData.cell_of(c) - sc
							if absi(dv.x) + absi(dv.y) == 1:
								near = true
				t.ok(near, "stone: đá nằm sát khối")
				t.ok(d["stones"].size() >= 2, "stone: có đá")
				# đá không trượt, không chọn được
				t.ok(not b.smash("stone") and not b.can_exit("stone"), "stone: đá không phải khối")
				var blocked := 0
				for bid in b.block_ids():
					if b.peek(bid) == "blocked":
						blocked += 1
				t.ok(blocked >= 1, "stone: có khối bị chặn phải đi sau")
			"ice":
				t.eq(int(r["min_taps"]), n + int(mech["ice"]), "ice: tốn thêm một chạm nứt")
				var cracked := false
				for bid in b.block_ids():
					cracked = cracked or b.peek(bid) == "crack"
				t.ok(cracked, "ice: lần chạm đầu vào khối băng là nứt")
			"chain":
				var locked := ""
				for bid in b.block_ids():
					if b.peek(bid) == "chained":
						locked = bid
				t.ok(locked != "", "chain: có khối bị xích")
				if locked != "":
					var key: String = b.block_view(locked)["chained_by"]
					t.ok(b.can_exit(key), "chain: khối chìa thoát ngay được")
					var c := b.clone()
					c.smash(key)
					t.ok(c.can_exit(locked), "chain: bỏ chìa thì khối xích đi được (xích là thứ duy nhất chặn)")
			"layer":
				t.eq(int(r["min_taps"]), n + int(mech["layer"]), "layer: tốn thêm một chạm bóc")
				var peel := false
				for bid in b.block_ids():
					peel = peel or b.peek(bid) == "peel"
				t.ok(peel, "layer: có khối bóc được")
			"fog":
				var hidden := 0
				for bid in b.block_ids():
					if bool(b.block_view(bid)["is_fog_hidden"]):
						hidden += 1
				t.ok(hidden >= 1, "fog: có khối ẩn màu lúc đầu")
				# lộ ra sau khi thoát đúng khối
				var shown := false
				var c := BoardState.new(d)
				for bid in r["order"]:
					c.tap(bid)
					for k in c.block_ids():
						if bool(c.block_view(k)["fog"]) and not bool(c.block_view(k)["is_fog_hidden"]):
							shown = true
				t.ok(shown, "fog: khối ẩn lộ màu khi ô bên cạnh trống")
			"pulse":
				var closed := 0
				for bid in b.block_ids():
					if b.peek(bid) == "gate_closed":
						closed += 1
				t.ok(closed >= 1, "pulse: có khối bị cổng đóng lúc đầu")
				var side: String = d["pulse_sides"][0]["side"]
				t.ok(not b.gate_open(side), "pulse: cổng %s đóng lúc đầu" % side)
				var tapped := b.clone()
				tapped.tap(tapped.hint())
				t.ok(tapped.gate_open(side), "pulse: một lần chạm làm cổng đảo trạng thái")


func test_generator_reproduces_files(t: T) -> void:
	# Level sinh ra khớp file đóng gói khi dùng seed gốc (mẫu vài level, không đủ thời gian cho cả 300).
	for id in [22, 40, 77, 120, 213, 300]:
		var d := _level(id)
		if d.is_empty():
			continue
		var again := Gen.generate(id, GenTool.BASE_SEED)
		t.eq(_norm(again), _norm(d), "L%d khớp generate(id, BASE_SEED)" % id)
