extends RefCounted
## Bộ sinh level (Task 9.1): 500 level hợp lệ, xác định, đúng cơ chế theo Config.UNLOCK, dưới 200 ms mỗi level.
const T := preload("res://tests/t.gd")
const Gen := preload("res://src/core/level_generator.gd")
const LevelData := preload("res://src/core/level_data.gd")
const Solver := preload("res://src/core/solver.gd")
const BoardState := preload("res://src/core/board_state.gd")
const Config := preload("res://src/config.gd")
const GenTool := preload("res://tools/gen_levels.gd")
const Validate := preload("res://tools/validate_levels.gd")

const FIRST_ID := 21
const COUNT := 500
const MAX_MSEC := 200.0


func _uses(d: Dictionary) -> Dictionary:
	var u := {"stone": not d["stones"].is_empty(), "ice": false, "chain": false, "layer": false,
		"fog": false, "pulse": not d["pulse_sides"].is_empty()}
	for b in d["blocks"]:
		if int(b["ice"]) > 0:
			u["ice"] = true
		if str(b["chained_by"]) != "":
			u["chain"] = true
		if str(b["inner_color"]) != "":
			u["layer"] = true
		if bool(b["fog"]):
			u["fog"] = true
	return u



func test_valid_solvable_fast(t: T) -> void:
	var seen := {"stone": 0, "ice": 0, "chain": 0, "layer": 0, "fog": 0, "pulse": 0}
	var max_ms := 0.0
	var total_ms := 0.0
	var worst_id := 0
	var hards := 0
	for i in COUNT:
		var id := FIRST_ID + i
		var t0 := Time.get_ticks_usec()
		var d := Gen.generate(id, 0)
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		total_ms += ms
		if ms > max_ms:
			max_ms = ms
			worst_id = id
		if d.is_empty():
			t.fail("id %d: không sinh được" % id)
			continue
		var errs := LevelData.validate(d)
		t.ok(errs.is_empty(), "id %d validate: %s" % [id, str(errs)])
		t.eq(int(d["id"]), id, "id %d khớp" % id)
		var n: int = d["blocks"].size()
		t.ok(n >= 2 and n <= Gen.MAX_BLOCKS, "id %d số khối %d" % [id, n])
		t.ok(int(d["w"]) <= Gen.MAX_W and int(d["h"]) <= Gen.MAX_H, "id %d cỡ bàn" % id)
		t.eq(bool(d["hard"]), id % 4 == 0, "id %d HARD" % id)
		if bool(d["hard"]):
			hards += 1
		var r := Solver.solve(d)
		t.ok(bool(r["ok"]), "id %d giải được" % id)
		t.eq(int(d["min_taps"]), int(r["min_taps"]), "id %d min_taps" % id)
		t.eq(int(d["moves"]), Solver.compute_moves(d), "id %d moves" % id)
		t.ok(int(d["moves"]) >= int(d["min_taps"]) + 1, "id %d dư" % id)
		t.ok(Solver.immediate_exit_exists(d), "id %d có khối thoát ngay" % id)
		t.ok(BoardState.new(d).hint() != "", "id %d hint" % id)
		t.ok(ms < MAX_MSEC, "id %d mất %.0f ms" % [id, ms])
		var u := _uses(d)
		for m in u:
			if u[m]:
				seen[m] += 1
				t.ok(id >= int(Config.UNLOCK[m]), "id %d dùng %s trước khi mở khoá" % [id, m])
	for m in seen:
		t.ok(seen[m] > 0, "cơ chế %s không xuất hiện" % m)
	t.ok(hards > 0, "có level HARD")
	print("generator: %d level, tb %.1f ms, max %.1f ms (id %d), đếm cơ chế %s" % [
		COUNT, total_ms / COUNT, max_ms, worst_id, str(seen)])


func test_deterministic(t: T) -> void:
	for id in [21, 31, 46, 61, 81, 101, 150, 300, 301, 777]:
		for sd in [0, 5, 12345]:
			var a := Gen.generate(id, sd)
			var b := Gen.generate(id, sd)
			t.ok(not a.is_empty(), "id %d seed %d" % [id, sd])
			t.eq(JSON.stringify(a), JSON.stringify(b), "id %d seed %d lặp lại" % [id, sd])
			# seed ghi trong level tái tạo đúng level đó
			var c := Gen.generate(id, int(a["seed"]))
			t.eq(JSON.stringify(a), JSON.stringify(c), "id %d seed ghi lại" % id)


func test_seeds_differ(t: T) -> void:
	var sigs := {}
	for sd in 10:
		sigs[JSON.stringify(Gen.generate(120, sd * 1000))] = true
	t.ok(sigs.size() >= 8, "10 seed cho ít nhất 8 level khác nhau (có %d)" % sigs.size())


func test_hard_and_early_ids(t: T) -> void:
	for id in [1, 4, 8, 12, 16, 20, 24, 28]:
		var d := Gen.generate(id, 0)
		t.ok(not d.is_empty(), "id %d sinh được" % id)
		if d.is_empty():
			continue
		t.eq(bool(d["hard"]), id % 4 == 0, "HARD id %d" % id)
		if id <= 20:
			t.ok(d["stones"].is_empty() and d["pulse_sides"].is_empty(), "id %d chưa có đá và cổng" % id)
		t.eq(int(d["moves"]), Solver.compute_moves(d), "moves id %d" % id)


func test_mechanics_for(t: T) -> void:
	t.eq(Gen.mechanics_for(20).size(), 0, "L20 chưa cơ chế")
	t.eq(Gen.mechanics_for(21), ["stone"] as Array[String], "L21")
	t.eq(Gen.mechanics_for(101).size(), 6, "L101 đủ 6")


func test_gen_tool_roundtrip(t: T) -> void:
	var dir := "user://test_test_generator/out"
	var res := GenTool.generate_range(21, 30, 0, dir)
	t.eq(int(res["count"]), 10, "đếm")
	t.eq(int(res["bad"]), 0, "không lỗi")
	for id in range(21, 31):
		var name := "level_%04d.json" % id
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "/" + name))
		t.ok(parsed is Dictionary, "%s đọc được" % name)
		if parsed is Dictionary:
			var again: Variant = JSON.parse_string(JSON.stringify(Gen.generate(id, 0)))
			t.eq(JSON.stringify(parsed), JSON.stringify(again), "%s khớp generate" % name)
		var errs := Validate.check_file(dir + "/" + name, name)
		t.ok(errs.is_empty(), "%s qua validate_levels: %s" % [name, str(errs)])
	var opt := GenTool.parse_args(PackedStringArray(["--from=5", "--to=9", "--out=user://x", "--seed=3", "--zzz=1"]))
	t.eq(int(opt["from"]), 5, "from")
	t.eq(int(opt["to"]), 9, "to")
	t.eq(str(opt["out"]), "user://x", "out")
	t.eq(int(opt["seed"]), 3, "seed")
	t.eq(str(GenTool.parse_args(PackedStringArray())["out"]), "user://gen_out", "mặc định ghi user://gen_out")
