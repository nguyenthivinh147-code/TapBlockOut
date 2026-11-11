extends RefCounted
## Bộ sinh level (Task 9.1): 500 level (L5-504) hợp lệ, xác định, đúng cơ chế theo Config.UNLOCK, dưới 200 ms mỗi level
## ở chế độ sinh trong game (`strict_rounds` false, Daily Challenge). Chế độ đóng gói (mặc định) bám số lượt dọn bàn
## của đường cong nên chậm hơn; test_levels_all kiểm kết quả của nó.
const T := preload("res://tests/t.gd")
const Gen := preload("res://src/core/level_generator.gd")
const LevelData := preload("res://src/core/level_data.gd")
const Solver := preload("res://src/core/solver.gd")
const BoardState := preload("res://src/core/board_state.gd")
const Config := preload("res://src/config.gd")
const DifficultyCurve := preload("res://src/core/difficulty_curve.gd")
const GenTool := preload("res://tools/gen_levels.gd")
const Validate := preload("res://tools/validate_levels.gd")
const Silhouette := preload("res://src/core/silhouette.gd")

## L1-4 làm tay (tools/gen_levels.gd EARLY), bộ sinh bắt đầu từ L5.
const FIRST_ID := 5
const COUNT := 500
const MAX_MSEC := 200.0


func _uses(d: Dictionary) -> Dictionary:
	var u := {"stone": not d["stones"].is_empty(), "ice": false, "frost": false, "chain": false, "layer": false,
		"fog": false, "pulse": not d["pulse_sides"].is_empty()}
	for b in d["blocks"]:
		if int(b["ice"]) > 0:
			u["frost" if str(d.get("cover", "")) == "frost" else "ice"] = true
		if str(b["chained_by"]) != "":
			u["chain"] = true
		if str(b["inner_color"]) != "":
			u["layer"] = true
		if bool(b["fog"]):
			u["fog"] = true
	return u



func test_valid_solvable_fast(t: T) -> void:
	var seen := {"stone": 0, "ice": 0, "frost": 0, "chain": 0, "layer": 0, "fog": 0, "pulse": 0}
	var max_ms := 0.0
	var total_ms := 0.0
	var worst_id := 0
	var hards := 0
	for i in COUNT:
		var id := FIRST_ID + i
		var t0 := Time.get_ticks_usec()
		var d := Gen.generate(id, 0, false)
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
		t.eq(int(d["w"]), Config.BOARD_W, "id %d bàn rộng cố định" % id)
		t.eq(int(d["h"]), Config.BOARD_H, "id %d bàn cao cố định" % id)
		t.eq(bool(d["hard"]), DifficultyCurve.is_hard(id), "id %d HARD" % id)
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
		var kinds := 0
		for m in u:
			if u[m]:
				seen[m] += 1
				kinds += 1
				t.ok(id >= int(Config.UNLOCK[m]), "id %d dùng %s trước khi mở khoá" % [id, m])
		t.ok(kinds <= Config.LEVEL_MECH_MAX, "id %d có %d cơ chế" % [id, kinds])
	for m in seen:
		t.ok(seen[m] > 0, "cơ chế %s không xuất hiện" % m)
	t.ok(hards > 0, "có level HARD")
	print("generator: %d level, tb %.1f ms, max %.1f ms (id %d), đếm cơ chế %s" % [
		COUNT, total_ms / COUNT, max_ms, worst_id, str(seen)])


## Sinh nhanh (trong game): level dạy Hai lớp đặt hộp giấy vào khối bóc được ngay, nên lần thử đầu đã qua `_teach_ok`.
## Trước đó hộp giấy rơi vào khối ngẫu nhiên, thường phải chờ khối khác: L65 seed 0 tốn 7 lần thử (215 ms > MAX_MSEC),
## seed 2000 tốn 23 lần (670 ms). Đếm lần thử (seed ghi trong level − seed truyền vào) thay cho đo giờ.
func test_fast_layer_teach_first_attempt(t: T) -> void:
	var id := int(Config.UNLOCK["layer"])
	t.eq(Gen.teach_mech(id), "layer", "L%d là level dạy Hai lớp" % id)
	for k in 12:
		var sd := k * 1000
		var d := Gen.generate(id, sd, false)
		t.ok(not d.is_empty(), "L%d seed %d sinh được" % [id, sd])
		if d.is_empty():
			continue
		t.ok(int(d["seed"]) - sd <= 1, "L%d seed %d: %d lần thử" % [id, sd, int(d["seed"]) - sd + 1])
		t.ok(Gen._teach_ok(d, "layer"), "L%d seed %d có khối bóc được ngay" % [id, sd])


## Các ô có khối hoặc đá của level.
func _occupied(d: Dictionary) -> Dictionary:
	var occ := {}
	for s in d["stones"]:
		occ[LevelData.cell_of(s)] = true
	for b in d["blocks"]:
		for c in b["cells"]:
			occ[LevelData.cell_of(c)] = true
	return occ


func _bbox(occ: Dictionary) -> Rect2i:
	var keys: Array = occ.keys()
	var r := Rect2i(keys[0], Vector2i.ONE)
	for c in keys:
		r = r.expand(c).expand(c + Vector2i.ONE)
	return r


## Khối xếp thành hình ở giữa bàn cố định: có khoảng trống, không kín khung, nhiều dạng khác nhau.
func test_blocks_form_varied_silhouettes_in_the_fixed_board(t: T) -> void:
	var shapes := {}
	var layouts := {}
	var gappy := 0
	var total := 300
	var biggest := {false: 0, true: 0}  # cỡ khối lớn nhất trước / từ SHAPED_FROM
	var blocks := {false: 0, true: 0}
	var singles := {false: 0, true: 0}  # khối 1 ô
	var forced := {false: 0, true: 0}  # khối 1 ô không tránh được: max(0, 2 * số khối - số ô) mỗi level
	for id in range(FIRST_ID, FIRST_ID + total):
		var d := Gen.generate(id, 0, false)
		var shaped := id >= DifficultyCurve.SHAPED_FROM
		var n_cells := 0
		for b in d["blocks"]:
			biggest[shaped] = maxi(int(biggest[shaped]), b["cells"].size())
			n_cells += b["cells"].size()
			if b["cells"].size() == 1:
				singles[shaped] += 1
		blocks[shaped] += d["blocks"].size()
		forced[shaped] += maxi(0, 2 * d["blocks"].size() - n_cells)
		var occ := _occupied(d)
		var box := _bbox(occ)
		t.ok(occ.size() < Config.BOARD_W * Config.BOARD_H, "id %d còn khoảng trống trên bàn" % id)
		t.ok(box.size.x <= Gen.MAX_W and box.size.y <= Gen.MAX_H, "id %d hình %s vừa vùng xếp" % [id, str(box.size)])
		var left := box.position.x
		var right := Config.BOARD_W - box.end.x
		var top := box.position.y
		var bottom := Config.BOARD_H - box.end.y
		t.ok(absi(left - right) <= 1 and absi(top - bottom) <= 1, "id %d hình ở giữa bàn (%d %d %d %d)" % [id, left, right, top, bottom])
		if occ.size() < box.size.x * box.size.y:
			gappy += 1
		var keys: Array = occ.keys()
		keys.sort()
		shapes[str(keys)] = true
		# Từ L14 hình lặp lại theo thư viện vẽ tay, nhưng cách cắt khối mỗi level một khác.
		var cuts: Array = []
		for b in d["blocks"]:
			cuts.append(str(b["cells"]))
		cuts.sort()
		layouts[str(cuts)] = true
	t.ok(gappy >= total * 0.95, "hầu hết level không kín khung hình (%d/%d)" % [gappy, total])
	t.ok(shapes.size() >= 40, "nhiều hình dạng khác nhau (%d/%d)" % [shapes.size(), total])
	t.ok(layouts.size() >= total * 0.95, "cách cắt khối khác nhau (%d/%d)" % [layouts.size(), total])
	# Khối tối đa Config.BLOCK_MAX_CELLS ô (trước 2026-11-05 trần 5 ô, rồi không giới hạn tới 2026-11-08).
	for shaped in [false, true]:
		t.ok(int(biggest[shaped]) > 5 and int(biggest[shaped]) <= Config.BLOCK_MAX_CELLS,
			"%s khối lớn nhất %d ô" % ["L5-13" if not shaped else "từ L14", int(biggest[shaped])])
	# Hình khoảng 3 ô mỗi khối nên không có khối 1 ô bắt buộc (max(0, 2 * số khối - số ô) = 0). Config.TILE_SINGLE_BIAS
	# 1,5 (từ bản 500 level; trước đó 5) gộp khối 1 ô trước ít hơn nên còn khoảng 11% khối 1 ô (trước khoảng 5%).
	for shaped in [false, true]:
		var share := float(singles[shaped]) / float(blocks[shaped])
		t.ok(share >= (0.05 if shaped else 0.0) and share <= 0.18 and forced[shaped] == 0, "%s khối 1 ô %.1f%% (bắt buộc %d)" % [
			"L5-13" if not shaped else "từ L14", 100.0 * share, int(forced[shaped])])


## Mọi khối sương mù đều ẩn lúc đầu, dù ở rìa hình có ô trống kề.
func test_fog_blocks_start_hidden(t: T) -> void:
	var fogged := 0
	for id in range(int(Config.UNLOCK["fog"]), FIRST_ID + COUNT):
		var d := Gen.generate(id, 0, false)
		var board := BoardState.new(d)
		for b in d["blocks"]:
			if bool(b["fog"]):
				fogged += 1
				t.ok(bool(board.block_view(str(b["id"]))["is_fog_hidden"]), "id %d: %s ẩn lúc đầu" % [id, b["id"]])
	t.ok(fogged > 0, "có khối sương mù")


## Khối ẩn không đi được: sương làm bàn kẹt thì `_unstick` bỏ sương ở khối ẩn đầu tiên lộ ra là đi được, giữ sương ở
## khối sẽ lộ khi khối kề rời đi.
func test_fog_fix_unsticks(t: T) -> void:
	var blk := func(id: String, color: String, cell: Array, fog: bool) -> Dictionary:
		return {"id": id, "color": color, "cells": [cell], "ice": 0, "chained_by": "", "inner_color": "", "fog": fog}
	# a (lên) chặn b bên dưới, chỉ b kề a nên a không bao giờ lộ; c đứng riêng; d lộ khi b rời đi.
	var lv := {"id": 80, "w": 5, "h": 5, "hard": false, "min_taps": 0, "moves": 20, "seed": 0, "stones": [],
		"pulse_sides": [], "blocks": [blk.call("a", "yellow", [1, 1], true), blk.call("b", "yellow", [1, 2], false),
			blk.call("c", "blue", [4, 4], true), blk.call("d", "purple", [2, 2], true)]}
	t.eq(Solver.solve(lv)["ok"], false, "kẹt vì sương")
	Gen._unstick(lv)
	var fog := {}
	for b in lv["blocks"]:
		fog[b["id"]] = b["fog"]
	t.eq(fog, {"a": false, "b": false, "c": false, "d": true}, "bỏ sương ở a, c; giữ ở d")
	t.eq(Solver.solve(lv)["ok"], true, "giải được sau khi sửa")


## Lớp phủ làm bàn kẹt thì `_unstick` bóc từng lớp ở khối phủ đầu tiên hết phủ là đi được, giữ lớp phủ ở khối sẽ được
## bóc khi khối kề rời đi.
func test_unstick_covers(t: T) -> void:
	var blk := func(id: String, color: String, cell: Array, ice: int) -> Dictionary:
		return {"id": id, "color": color, "cells": [cell], "ice": ice, "chained_by": "", "inner_color": "", "fog": false}
	# a (lên) chặn b bên dưới, chỉ b kề a nên a không bao giờ hết phủ; c đứng riêng, 2 lớp; d hết phủ khi b rời đi.
	var lv := {"id": 80, "w": 5, "h": 5, "hard": false, "min_taps": 0, "moves": 20, "seed": 0, "stones": [],
		"pulse_sides": [], "blocks": [blk.call("a", "yellow", [1, 1], 1), blk.call("b", "yellow", [1, 2], 0),
			blk.call("c", "blue", [4, 4], 2), blk.call("d", "purple", [2, 2], 1)]}
	t.eq(Solver.solve(lv)["ok"], false, "kẹt vì lớp phủ")
	Gen._unstick(lv)
	var ice := {}
	for b in lv["blocks"]:
		ice[b["id"]] = b["ice"]
	t.eq(ice, {"a": 0, "b": 0, "c": 0, "d": 1}, "bỏ phủ ở a, c (cả 2 lớp); giữ ở d")
	t.eq(Solver.solve(lv)["ok"], true, "giải được sau khi sửa")


## Lớp phủ trong level sinh: level dạy chỉ 1 lớp và có khối phủ kề khối thoát được ngay; pudding và băng không cùng level;
## khối 2 lớp có từ COVER_DOUBLE_AFTER level sau mốc mở và kề ít nhất 2 khối; lớp phủ không chung khối với sương,
## xích, hộp giấy.
func test_covers_in_generated_levels(t: T) -> void:
	var doubles := {"ice": 0, "frost": 0}
	for id in range(int(Config.UNLOCK["ice"]), int(Config.UNLOCK["frost"]) + 60):
		var d := Gen.generate(id, 0, false)
		var plan := Gen.mech_plan(id)
		t.ok(not (plan.has("ice") and plan.has("frost")), "L%d: pudding và băng không cùng level" % id)
		var kind := "frost" if str(d.get("cover", "")) == "frost" else "ice"
		var owner := {}
		for b in d["blocks"]:
			for c in b["cells"]:
				owner[LevelData.cell_of(c)] = str(b["id"])
		for b in d["blocks"]:
			var layers := int(b["ice"])
			if layers == 0:
				continue
			t.ok(plan.has(kind), "L%d: lớp phủ %s theo mech_plan" % [id, kind])
			t.ok(not bool(b["fog"]) and str(b["chained_by"]) == "" and str(b["inner_color"]) == "",
				"L%d %s: lớp phủ không chung khối với cơ chế khác" % [id, b["id"]])
			if layers < 2:
				continue
			doubles[kind] += 1
			t.ok(id >= int(Config.UNLOCK[kind]) + Config.COVER_DOUBLE_AFTER, "L%d: 2 lớp sau mốc" % id)
			var near := {}
			for c in b["cells"]:
				for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var o := str(owner.get(LevelData.cell_of(c) + dv, ""))
					if o != "" and o != str(b["id"]):
						near[o] = true
			t.ok(near.size() >= 2, "L%d %s: khối 2 lớp kề ít nhất 2 khối" % [id, b["id"]])
	t.ok(doubles["ice"] > 0, "có pudding 2 lớp (%d)" % doubles["ice"])
	t.ok(doubles["frost"] > 0, "có băng 2 lớp (%d)" % doubles["frost"])
	for teach in ["ice", "frost"]:
		var lid := int(Config.UNLOCK[teach])
		var d := Gen.generate(lid, 0, false)
		t.eq(Gen.mech_plan(lid), [teach] as Array[String], "L%d dạy %s" % [lid, teach])
		t.eq(str(d.get("cover", "pudding")), "frost" if teach == "frost" else "pudding", "L%d chất liệu" % lid)
		var covered := 0
		for b in d["blocks"]:
			t.ok(int(b["ice"]) <= 1, "L%d level dạy chỉ 1 lớp" % lid)
			covered += int(int(b["ice"]) > 0)
		t.ok(covered > 0, "L%d có khối phủ" % lid)
		t.ok(Gen._teach_ok(d, teach), "L%d cho thử cơ chế ngay" % lid)


## Bộ sinh dùng đủ mọi dạng hình, không chỉ vài dạng quen (hình cũ, cho level trước DifficultyCurve.SHAPED_FROM).
func test_every_shape_kind_is_used(t: T) -> void:
	var seen := {}
	for sd in 400:
		var shape := Gen._pick_shape(20, 0, "", Gen._rng(150, sd))
		t.ok(not shape.is_empty(), "seed %d có hình" % sd)
		seen[shape.get("kind", "")] = true
	for kind in Silhouette.KINDS:
		t.ok(seen.has(kind), "có dùng hình %s" % kind)


## Kiểu cắt khối xen kẽ theo level: đối xứng tự do, hình học (đủ các kiểu trong GEO_STYLES), theo vùng vẽ. L5 tới
## Config.EARLY_SHAPE_UNTIL luôn đối xứng tự do (khối to, nhiều chữ L).
func test_cut_styles_alternate(t: T) -> void:
	for id in range(DifficultyCurve.MOTIF_FROM, Config.EARLY_SHAPE_UNTIL + 1):
		t.eq(Gen.cut_style(id), "sym", "L%d cắt tự do" % id)
	var seen := {}
	for id in range(Config.EARLY_SHAPE_UNTIL + 1, Config.EARLY_SHAPE_UNTIL + 16):
		seen[Gen.cut_style(id)] = true
		t.ok(Gen.cut_style(id) != Gen.cut_style(id + 1), "L%d và L%d khác kiểu cắt" % [id, id + 1])
	for style in ["sym", "template"] + Gen.GEO_STYLES:
		t.ok(seen.has(style), "15 level liền nhau có kiểu %s" % style)


func test_deterministic(t: T) -> void:
	for id in [14, 30, 45, 65, 85, 100, 115, 165, 300, 350, 777]:
		for sd in [0, 5, 12345]:
			var a := Gen.generate(id, sd)
			var b := Gen.generate(id, sd)
			t.ok(not a.is_empty(), "id %d seed %d" % [id, sd])
			t.eq(JSON.stringify(a), JSON.stringify(b), "id %d seed %d lặp lại" % [id, sd])
			# seed ghi trong level tái tạo đúng level đó khi level sinh được trước lần nới đầu tiên của bộ sinh
			# (số lượt dọn bàn mỗi Gen.ROUNDS_RELAX_EVERY lần thử, khối thoát ngay mỗi Config.EXIT_RELAX_EVERY, số khối
			# mục tiêu mỗi Gen.COUNT_RELAX_EVERY): lần thử sau đó nới luật nên seed ghi lại bắt đầu lại từ luật chặt.
			if int(a["seed"]) - sd < mini(Gen.ROUNDS_RELAX_EVERY, mini(Config.EXIT_RELAX_EVERY, Gen.COUNT_RELAX_EVERY)):
				var c := Gen.generate(id, int(a["seed"]))
				t.eq(JSON.stringify(a), JSON.stringify(c), "id %d seed ghi lại" % id)


## Từ Config.EXIT_RANGE_FROM (design.md mục 4, 2026-11-11): số khối chạm được ngay (Gen.free_count) nằm trong
## Gen.exit_range theo tag, và tối đa Config.LEVEL_MECH_BLOCK_SHARE số khối mang cơ chế (Gen.mech_blocks).
func test_exit_range_and_mech_budget(t: T) -> void:
	t.eq(Gen.exit_range(13), Vector2i.ZERO, "trước L14 không giới hạn")
	t.eq(Gen.exit_range(14), Config.EXIT_RANGE_EARLY, "L14-29")
	t.eq(Gen.exit_range(Config.EXIT_RANGE_EARLY_UNTIL + 2), Config.EXIT_RANGE_NORMAL, "level thường")
	t.eq(Gen.exit_range(33), Config.EXIT_RANGE_VERY_HARD, "L33 VeryHard")
	var relaxed := Gen.exit_range(33, Config.EXIT_RELAX_EVERY * 2)
	t.eq(relaxed, Vector2i(maxi(1, Config.EXIT_RANGE_VERY_HARD.x - 2), Config.EXIT_RANGE_VERY_HARD.y + 2), "nới dần")
	t.eq(Gen.mech_budget(45), 22, "45 khối: tối đa 22 khối có cơ chế")
	var base := 20261101
	for id in range(Config.EXIT_RANGE_FROM, 501, 13):
		var d := Gen.generate(id, base)
		if d.is_empty():
			t.fail("L%d không sinh được" % id)
			continue
		var r := Gen.exit_range(id, int(d["seed"]) - base)
		var f := Gen.free_count(d)
		t.ok(f >= r.x and f <= r.y, "L%d: %d khối thoát ngay trong %s" % [id, f, str(r)])
		var n: int = d["blocks"].size()
		t.ok(Gen.mech_blocks(d) <= Gen.mech_budget(n), "L%d: %d/%d khối có cơ chế" % [id, Gen.mech_blocks(d), n])


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
		t.eq(bool(d["hard"]), DifficultyCurve.is_hard(id), "HARD id %d" % id)
		if id < int(Config.UNLOCK.stone):
			t.ok(d["stones"].is_empty() and d["pulse_sides"].is_empty(), "id %d chưa có đá và cổng" % id)
		t.eq(int(d["moves"]), Solver.compute_moves(d), "moves id %d" % id)


func test_mechanics_for(t: T) -> void:
	t.eq(Gen.mechanics_for(13).size(), 0, "L13 chưa cơ chế")
	t.eq(Gen.mechanics_for(14), ["stone"] as Array[String], "L14")
	t.eq(Gen.mechanics_for(int(Config.UNLOCK.pulse)).size(), 6, "L115 đủ 6")
	t.ok(not Gen.mechanics_for(int(Config.UNLOCK.frost) - 1).has("frost"), "L164 chưa có băng")
	t.ok(Gen.mechanics_for(int(Config.UNLOCK.frost)).has("frost"), "L165 mở băng")


## mech_plan: level dạy chỉ cơ chế mới (bom kẹo thì cùng pudding); trước L14 và level nghỉ không có; còn lại
## 1..LEVEL_MECH_MAX cơ chế đã mở,
## cơ chế vừa mở luôn có, cổng nhịp chỉ ở bàn tới GATE_MAX_BLOCKS khối; cùng id cùng kết quả.
func test_mech_plan(t: T) -> void:
	var sizes := {}
	for id in range(1, 601):
		var plan := Gen.mech_plan(id)
		t.eq(plan, Gen.mech_plan(id), "L%d xác định" % id)
		var teach := Gen.teach_mech(id)
		if teach == "pop":
			# Bom kẹo đứng một mình không có tác dụng: dạy cùng Config.POP_TEACH_WITH.
			t.eq(plan, [Config.POP_TEACH_WITH, teach] as Array[String], "L%d dạy %s cùng pudding" % [id, teach])
			continue
		if teach != "":
			t.eq(plan, [teach] as Array[String], "L%d dạy %s" % [id, teach])
			continue
		if id < int(Config.UNLOCK["stone"]) or Gen.is_rest(id):
			t.eq(plan.size(), 0, "L%d không cơ chế" % id)
			continue
		t.ok(plan.size() >= 1 and plan.size() <= Config.LEVEL_MECH_MAX, "L%d có %d cơ chế" % [id, plan.size()])
		sizes[plan.size()] = true
		for m in plan:
			t.ok(Gen.mechanics_for(id).has(m), "L%d: %s đã mở" % [id, m])
		if plan.has("pulse"):
			t.ok(DifficultyCurve.block_count(id) <= Gen.GATE_MAX_BLOCKS, "L%d: cổng nhịp trên bàn nhỏ" % id)
	t.eq(sizes.size(), Config.LEVEL_MECH_MAX, "có level 1, 2 và 3 cơ chế")
	t.ok(Gen.is_rest(15) and not Gen.is_rest(16), "L15 nghỉ, L16 không")
	# L115 chia 4 dư 3 nhưng là level dạy cổng nhịp.
	t.ok(not Gen.is_rest(int(Config.UNLOCK.pulse)), "L115 là level dạy, không nghỉ")


## Cổng nhịp đặt ở cạnh có ít lần qua nhất (khối theo màu, hộp giấy tính cả màu vỏ lẫn màu trong), vì mỗi lần qua cổng
## khoá tốn một cú dội; lúc đầu luôn có khối thoát được ngay. Level dạy (Config.UNLOCK.pulse, L115) khoá sẵn và có
## khối dội vào được ngay.
func test_pulse_on_least_used_side(t: T) -> void:
	var gated := 0
	var u := int(Config.UNLOCK.pulse)
	for id in range(u, u + 130):
		if not Gen.mech_plan(id).has("pulse"):
			continue
		var d := Gen.generate(id, 0, false)
		if d.is_empty() or d["pulse_sides"].is_empty():
			continue
		gated += 1
		var passes := {}
		for b in d["blocks"]:
			for col in [str(b["color"]), str(b["inner_color"])]:
				if col != "":
					var side := LevelData.side_of(col)
					passes[side] = int(passes.get(side, 0)) + 1
		var counts: Array = passes.values()
		counts.sort()
		var got: Array = []
		for p in d["pulse_sides"]:
			got.append(int(passes.get(str(p["side"]), 0)))
		got.sort()
		t.eq(got, counts.slice(0, got.size()), "L%d: cổng ở cạnh ít lần qua nhất %s" % [id, str(passes)])
		t.ok(Solver.immediate_exit_exists(d), "L%d có khối thoát ngay" % id)
	t.ok(gated >= 5, "đủ level có cổng (%d)" % gated)
	var teach := Gen.generate(u, 0, false)
	var bt := BoardState.new(teach)
	t.eq(bt.gate_open(str(teach["pulse_sides"][0]["side"])), false, "L%d cổng khoá lúc đầu" % u)
	var bump := ""
	for bid in bt.block_ids():
		if bt.peek(bid) == "gate_closed":
			bump = bid
	t.ok(bump != "", "L%d có khối dội vào cổng được ngay" % u)


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


## Level dạy socola (Config.UNLOCK.choco): file ghi ra phải giữ `choco_sides`, nếu không thanh socola mất khỏi game.
func test_gen_tool_keeps_choco(t: T) -> void:
	var dir := "user://test_test_generator/choco"
	var id := int(Config.UNLOCK["choco"])
	t.eq(int(GenTool.generate_range(id, id, 0, dir)["bad"]), 0, "không lỗi")
	var name := "level_%04d.json" % id
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "/" + name))
	t.ok(parsed is Dictionary and not (parsed.get("choco_sides", []) as Array).is_empty(), "%s có choco_sides" % name)
	if parsed is Dictionary:
		var again: Variant = JSON.parse_string(JSON.stringify(Gen.generate(id, 0)))
		t.eq(JSON.stringify(parsed), JSON.stringify(again), "%s khớp generate" % name)
