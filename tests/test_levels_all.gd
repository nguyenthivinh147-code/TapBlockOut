extends RefCounted
## 100 level đóng gói sẵn: L1-4 làm tay (bảng EARLY), còn lại do tools/gen_levels.gd sinh. Từ L14 (kể cả 6 level dạy
## cơ chế) khối xếp theo hình vẽ tay, đối xứng, nhiều khối hơn.
const T := preload("res://tests/t.gd")
const BoardState := preload("res://src/core/board_state.gd")
const LevelData := preload("res://src/core/level_data.gd")
const Solver := preload("res://src/core/solver.gd")
const Gen := preload("res://src/core/level_generator.gd")
const GenTool := preload("res://tools/gen_levels.gd")
const Config := preload("res://src/config.gd")
const DifficultyCurve := preload("res://src/core/difficulty_curve.gd")

const TOTAL := 100
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
	t.ok(shapes.size() >= 30, "nhiều hình dạng khác nhau (%d)" % shapes.size())


## Từ DifficultyCurve.SHAPED_FROM: khối và đá xếp thành hình đối xứng (trái phải hoặc trên dưới), cách cắt khối cũng
## đối xứng, hình nằm đúng giữa bàn theo chiều ngang, và các level dùng nhiều hình khác nhau.
func test_shaped_levels_are_symmetric(t: T) -> void:
	var outlines := {}
	for id in range(DifficultyCurve.SHAPED_FROM, TOTAL + 1):
		var d := _level(id)
		if d.is_empty():
			continue
		var box := _footprint(d)
		t.eq(box.position.x, Config.BOARD_W - box.end.x, "L%d đúng giữa bàn theo chiều ngang" % id)
		var occ := {}
		for s in d["stones"]:
			occ[LevelData.cell_of(s)] = "#"
		var sigs := {}
		for b in d["blocks"]:
			var cells: Array = []
			for c in b["cells"]:
				cells.append(LevelData.cell_of(c))
				occ[LevelData.cell_of(c)] = "b"
			cells.sort()
			sigs[str(cells)] = true
		var sym := {"h": true, "v": true}
		for axis in sym:
			for b in d["blocks"]:
				var m: Array = []
				for raw in b["cells"]:
					var c := LevelData.cell_of(raw)
					m.append(Vector2i(box.position.x + box.end.x - 1 - c.x, c.y) if axis == "h" \
						else Vector2i(c.x, box.position.y + box.end.y - 1 - c.y))
				m.sort()
				sym[axis] = sym[axis] and sigs.has(str(m))
			for c: Vector2i in occ:
				var mc := Vector2i(box.position.x + box.end.x - 1 - c.x, c.y) if axis == "h" \
					else Vector2i(c.x, box.position.y + box.end.y - 1 - c.y)
				sym[axis] = sym[axis] and occ.get(mc, "") == occ[c]
		t.ok(sym["h"] or sym["v"], "L%d khối và đá đối xứng theo hình" % id)
		var norm: Array = []
		for c: Vector2i in occ:
			norm.append(c - box.position)
		norm.sort()
		outlines[str(norm)] = true
	t.ok(outlines.size() >= 40, "L%d-%d dùng nhiều hình (%d dạng)" % [DifficultyCurve.SHAPED_FROM, TOTAL, outlines.size()])


## Từ DifficultyCurve.SHAPED_FROM khó hơn bản cũ: nhiều khối hơn và ít khối thoát được ngay lúc đầu.
func test_shaped_levels_are_harder(t: T) -> void:
	var blocks := 0
	var free0 := 0
	var count := 0
	for id in range(DifficultyCurve.SHAPED_FROM, TOTAL + 1):
		var d := _level(id)
		if d.is_empty():
			continue
		var n: int = d["blocks"].size()
		t.ok(absi(n - DifficultyCurve.block_count(id)) <= 2 or (d["pulse_sides"].size() > 0 and n <= Gen.GATE_MAX_BLOCKS + 2),
			"L%d số khối %d ~ đường cong %d" % [id, n, DifficultyCurve.block_count(id)])
		var b := BoardState.new(d)
		for bid in b.block_ids():
			if b.peek(bid) == "exit":
				free0 += 1
		blocks += n
		count += 1
	t.ok(float(blocks) / count >= 27.0 * DifficultyCurve.COUNT_SCALE, "trung bình %.1f khối mỗi level" % (float(blocks) / count))
	t.ok(float(free0) / blocks <= 0.3, "chỉ %.0f%% khối thoát được ngay lúc đầu" % (100.0 * free0 / blocks))


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


func test_early_levels_handmade(t: T) -> void:
	# L1-4 làm tay: 2, 3, 3, 4 màu; L1-3 không khối nào phải chờ quá một chạm, dư 5 MOVES.
	for id in range(1, 5):
		var d := _level(id)
		if d.is_empty():
			continue
		var cols := {}
		for b in d["blocks"]:
			cols[b["color"]] = true
		t.eq(cols.size(), DifficultyCurve.color_count(id), "L%d số màu" % id)
		t.eq(cols.size(), [2, 3, 3, 4][id - 1], "L%d đúng bảng màu 2/3/3/4" % id)
		t.ok(not bool(d["hard"]), "L%d không HARD" % id)
		t.eq(_mechs(d).size(), 0, "L%d không cơ chế" % id)
		t.eq(_norm(GenTool.build_spec(id, GenTool.EARLY[id])), _norm(d), "L%d khớp bảng EARLY" % id)
		if id <= 3:
			t.eq(Solver.slack_for(d), 5, "L%d dư 5 MOVES" % id)
			t.eq(int(d["moves"]), int(d["min_taps"]) + 5, "L%d moves" % id)
			# thắng chắc: dù chạm bừa theo mọi thứ tự, còn đủ MOVES để thắng bằng cách chạm lại khối bị chặn.
			t.ok(int(d["min_taps"]) <= d["blocks"].size() + 1, "L%d gần như không khối bị chặn" % id)


func test_early_levels_follow_curve(t: T) -> void:
	for id in range(5, 21):
		var d := _level(id)
		if d.is_empty():
			continue
		var n: int = d["blocks"].size()
		t.ok(absi(n - DifficultyCurve.block_count(id)) <= 1 or Gen.mechanics_for(id).size() > 0, "L%d số khối %d ~ đường cong %d" % [id, n, DifficultyCurve.block_count(id)])
	# Độ khó tăng dần: trung bình số khối mỗi 10 level (bỏ level dạy cơ chế, bàn nhỏ) không giảm trong 30 level đầu (đường cong tự trũng nhẹ ở L31-40).
	var prev := 0.0
	for start in [1, 11, 21]:
		var sum := 0
		var cnt := 0
		for id in range(start, start + 10):
			if Gen.teach_mech(id) != "":
				continue
			sum += _level(id)["blocks"].size()
			cnt += 1
		t.ok(float(sum) / float(cnt) >= prev, "trung bình khối L%d-%d không giảm" % [start, start + 9])
		prev = float(sum) / float(cnt)


func test_hard_follows_curve(t: T) -> void:
	var hard := 0
	for id in range(1, TOTAL + 1):
		var d := _level(id)
		if d.is_empty():
			continue
		t.eq(bool(d["hard"]), DifficultyCurve.is_hard(id), "L%d cờ HARD theo đường cong" % id)
		if bool(d["hard"]):
			hard += 1
			t.eq(Solver.slack_for(d), 1, "L%d HARD dư 1" % id)
	t.eq(hard, DifficultyCurve.HARD.size() + DifficultyCurve.VERY_HARD.size(), "26 level HARD/VeryHard trong L1-100")
	t.eq(hard, 26, "26 level HARD")


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
		t.ok(int(count.get(m, 0)) >= (TOTAL - u) * 0.5, "%s dùng đủ nhiều (%d level)" % [m, int(count.get(m, 0))])
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
		t.eq(Gen.teach_mech(id), m, "L%d dạy %s" % [id, m])
		var d := _level(id)
		if d.is_empty():
			continue
		var mech := _mechs(d)
		t.eq(mech.keys(), [m], "L%d chỉ có đúng cơ chế mới %s" % [id, m])
		t.ok(not bool(d["hard"]), "L%d không HARD" % id)
		# Level dạy sinh to như level thường (từ L14 xếp theo hình), không còn bảng làm tay nhỏ.
		var n: int = d["blocks"].size()
		t.ok(n >= 15, "L%d level to (%d khối)" % [id, n])
		var b := BoardState.new(d)
		t.ok(b.hint() != "", "L%d có khối thoát ngay" % id)
		var exits := 0
		for bid in b.block_ids():
			if b.can_exit(bid):
				exits += 1
		# Level hai lớp: khối nhiều lớp tính là "đi được" (bóc) nên chờ thể hiện ở min_taps (kiểm riêng bên dưới).
		t.ok(exits >= 2 and (exits < n or m == "layer"), "L%d có khối thoát ngay và có khối phải chờ (%d/%d)" % [id, exits, n])
		# Sinh lại bằng seed gốc phải ra đúng file đã đóng gói.
		t.eq(_norm(Gen.generate(id, GenTool.BASE_SEED)), _norm(d), "L%d khớp generate(id, BASE_SEED)" % id)
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
	# Level sinh ra khớp file đóng gói khi dùng seed gốc (mẫu vài level, không đủ thời gian cho cả 100).
	for id in [22, 41, 77, 100]:
		var d := _level(id)
		if d.is_empty():
			continue
		var again := Gen.generate(id, GenTool.BASE_SEED)
		t.eq(_norm(again), _norm(d), "L%d khớp generate(id, BASE_SEED)" % id)
