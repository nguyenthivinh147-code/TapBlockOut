extends SceneTree
## Sinh hàng loạt level bằng LevelGenerator và ghi level_NNNN.json.
## Chạy: tools/godot.sh --headless --path . -s res://tools/gen_levels.gd -- [--from=1] [--to=100] [--out=user://gen_out] [--seed=0] [--early=0]
## Mặc định ghi vào user://gen_out. Muốn ghi vào data/levels thì truyền --out=res://data/levels một cách chủ ý.
## Thoát 1 nếu có level không sinh được hoặc không qua kiểm tra.
##
## Bản phát hành L1-100 (đường cong độ khó difficulty_curve.gd) sinh bằng đúng lệnh này, seed gốc BASE_SEED = 20261101:
##   tools/godot.sh --headless --path . -s res://tools/gen_levels.gd -- --from=1 --to=100 --seed=20261101 --early=1 --out=res://data/levels
## `--early=1`: 4 level đầu (EARLY, chắc chắn thắng) dựng tay thay cho bộ sinh; min_taps và moves vẫn do Solver tính.
## Level dạy cơ chế (id = Config.UNLOCK: 14, 30, 40, 55, 70, 90) do bộ sinh tạo như level thường, chỉ bật cơ chế mới.

const Gen := preload("res://src/core/level_generator.gd")
const LevelData := preload("res://src/core/level_data.gd")
const Solver := preload("res://src/core/solver.gd")
const Config := preload("res://src/config.gd")

const DEFAULT_FROM := 1
const DEFAULT_TO := 100
const DEFAULT_OUT := "user://gen_out"
## Seed gốc của bản phát hành L21-300 (ngày chốt thiết kế). Mặc định của --seed vẫn là 0.
const BASE_SEED := 20261101

## Bốn level đầu làm tay, khoá là id: 2, 3, 3, 4 màu. L1-3 không khối nào bị chặn quá một lần và dư 5 MOVES nên chắc
## chắn thắng; L4 có một khối phải chờ.
## `rows`: mỗi chuỗi một hàng (y tăng xuống dưới), '.' ô trống, '#' đá, chữ cái là khối (cùng chữ = cùng khối).
## `blk[chữ]`: color (yellow lên, green trái, blue phải, purple xuống) và tuỳ chọn ice, chain (chữ khối chìa),
## inner (màu lớp trong), fog. `pulse`: cạnh có cổng nhịp và trạng thái mở ban đầu.
## Số khối 4, 6, 8, 10 (gấp đôi bản đầu, DifficultyCurve.COUNT_SCALE). L3 chỉ D chờ G, L4 chỉ E chờ H.
const EARLY := {
	1: {"rows": ["AB.CC", "AB...", "...DD"],
		"blk": {"A": {"color": "yellow"}, "B": {"color": "yellow"}, "C": {"color": "blue"}, "D": {"color": "blue"}}},
	2: {"rows": ["A.B.C", "A.B.C", "DD.EE", ".FF.."],
		"blk": {"A": {"color": "yellow"}, "B": {"color": "yellow"}, "C": {"color": "blue"}, "D": {"color": "green"},
			"E": {"color": "blue"}, "F": {"color": "green"}}},
	3: {"rows": ["A.BCC", "A.B..", "DD..E", "..F.E", "GGF.H"],
		"blk": {"A": {"color": "yellow"}, "B": {"color": "yellow"}, "C": {"color": "blue"}, "D": {"color": "purple"},
			"E": {"color": "blue"}, "F": {"color": "purple"}, "G": {"color": "purple"}, "H": {"color": "blue"}}},
	4: {"rows": ["A.BB.C", "A....C", "DDE.FF", "..E...", "G.HH.I", "G...JI"],
		"blk": {"A": {"color": "yellow"}, "B": {"color": "yellow"}, "C": {"color": "blue"}, "D": {"color": "green"},
			"E": {"color": "purple"}, "F": {"color": "blue"}, "G": {"color": "green"}, "H": {"color": "purple"},
			"I": {"color": "blue"}, "J": {"color": "purple"}}},
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var opt := parse_args(OS.get_cmdline_user_args())
	var res := generate_range(int(opt["from"]), int(opt["to"]), int(opt["seed"]), str(opt["out"]), int(opt["early"]) != 0)
	print("---- %d level, %d lỗi, tb %.1f ms, max %.1f ms (id %d) -> %s ----" % [
		res["count"], res["bad"], res["avg_ms"], res["max_ms"], res["max_id"],
		ProjectSettings.globalize_path(str(opt["out"]))])
	quit(1 if int(res["bad"]) > 0 else 0)


## `--khoá=giá trị`; khoá lạ bị bỏ qua.
static func parse_args(args: PackedStringArray) -> Dictionary:
	var opt := {"from": DEFAULT_FROM, "to": DEFAULT_TO, "out": DEFAULT_OUT, "seed": 0, "early": 0}
	for a in args:
		if not a.begins_with("--") or not a.contains("="):
			continue
		var kv := a.substr(2).split("=", true, 1)
		match kv[0]:
			"from", "to", "seed", "early":
				if kv[1].is_valid_int():
					opt[kv[0]] = int(kv[1])
			"out":
				if kv[1] != "":
					opt["out"] = kv[1]
	return opt


## Dựng level `id` từ một bảng rows/blk (EARLY); min_taps và moves do Solver tính.
static func build_spec(id: int, spec: Dictionary) -> Dictionary:
	var rows: Array = spec["rows"]
	var h := rows.size()
	var w := str(rows[0]).length()
	# Dựng ở giữa bàn cố định: ngoài bảng là ô trống nên đường thoát không đổi.
	@warning_ignore("integer_division")
	var ox := (Config.BOARD_W - w) / 2
	@warning_ignore("integer_division")
	var oy := (Config.BOARD_H - h) / 2
	var cells := {}  # chữ -> mảng ô
	var stones: Array = []
	var first := {}  # chữ -> ô đầu (y rồi x) để đặt id b1.. theo vị trí như bộ sinh
	for y in h:
		var row := str(rows[y])
		if row.length() != w:
			return {}
		for x in w:
			var ch := row[x]
			if ch == ".":
				continue
			if ch == "#":
				stones.append([x + ox, y + oy])
				continue
			if not cells.has(ch):
				cells[ch] = []
				first[ch] = Vector2i(x + ox, y + oy)
			cells[ch].append([x + ox, y + oy])
	var letters: Array = cells.keys()
	letters.sort_custom(func(a: String, b: String) -> bool:
		var fa: Vector2i = first[a]
		var fb: Vector2i = first[b]
		return fa.y < fb.y or (fa.y == fb.y and fa.x < fb.x))
	var name_of := {}
	for i in letters.size():
		name_of[letters[i]] = "b%d" % (i + 1)
	var blocks: Array = []
	for ch in letters:
		if not spec["blk"].has(ch):
			return {}
		var a: Dictionary = spec["blk"][ch]
		blocks.append({
			"id": name_of[ch], "color": a["color"], "cells": cells[ch], "ice": int(a.get("ice", 0)),
			"chained_by": name_of[a["chain"]] if a.has("chain") else "",
			"inner_color": str(a.get("inner", "")), "fog": bool(a.get("fog", false))})
	var d := {
		"id": id, "w": Config.BOARD_W, "h": Config.BOARD_H, "hard": false, "min_taps": 0, "moves": 0, "seed": 0,
		"stones": stones, "pulse_sides": spec.get("pulse", []).duplicate(true), "blocks": blocks,
	}
	if not LevelData.validate(d).is_empty():
		return {}
	var r := Solver.solve(d)
	if not bool(r["ok"]):
		return {}
	d["min_taps"] = int(r["min_taps"])
	d["moves"] = int(r["min_taps"]) + Solver.slack_for(d)
	return d


## Sinh id từ..đến, ghi từng file vào `out`. Trả {count, bad, avg_ms, max_ms, max_id}.
## `early`: 4 level đầu lấy từ EARLY thay cho bộ sinh.
static func generate_range(from_id: int, to_id: int, seed: int, out: String, early: bool = false) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var bad := 0
	var total := 0.0
	var max_ms := 0.0
	var max_id := 0
	var count := 0
	for id in range(from_id, to_id + 1):
		var t0 := Time.get_ticks_usec()
		var d: Dictionary
		if early and EARLY.has(id):
			d = build_spec(id, EARLY[id])
		else:
			d = Gen.generate(id, seed)
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		count += 1
		total += ms
		if ms > max_ms:
			max_ms = ms
			max_id = id
		var err := check_level(d, id)
		if err != "":
			bad += 1
			printerr("FAIL level %d: %s" % [id, err])
			continue
		if not write_level(out, d):
			bad += 1
			printerr("FAIL level %d: không ghi được file" % id)
	return {"count": count, "bad": bad, "avg_ms": total / maxf(count, 1), "max_ms": max_ms, "max_id": max_id}


## Rỗng nếu level qua validate, solver, min_taps, moves và khối thoát ngay.
static func check_level(d: Dictionary, id: int) -> String:
	if d.is_empty():
		return "không sinh được"
	var errs := LevelData.validate(d)
	if not errs.is_empty():
		return str(errs)
	if int(d["id"]) != id:
		return "id lệch"
	var r := Solver.solve(d)
	if not bool(r["ok"]) or int(d["min_taps"]) != int(r["min_taps"]):
		return "solver không khớp min_taps"
	if int(d["moves"]) != Solver.compute_moves(d):
		return "moves sai công thức"
	if not Solver.immediate_exit_exists(d):
		return "không có khối thoát ngay"
	return ""


static func write_level(dir: String, d: Dictionary) -> bool:
	var f := FileAccess.open("%s/level_%04d.json" % [dir, int(d["id"])], FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(format_level(d))
	f.close()
	return true


## Cùng khuôn dạng các file level 1-20: đầu level nhiều dòng, mỗi khối một dòng.
static func format_level(d: Dictionary) -> String:
	var lines: Array[String] = []
	for b in d["blocks"]:
		lines.append("\t\t" + JSON.stringify({
			"id": b["id"], "color": b["color"], "cells": b["cells"], "ice": b["ice"],
			"chained_by": b["chained_by"], "inner_color": b["inner_color"], "fog": b["fog"]}, "", false))
	return "{\n\t\"id\": %d, \"w\": %d, \"h\": %d, \"hard\": %s,\n\t\"min_taps\": %d, \"moves\": %d, \"seed\": %d,\n\t\"stones\": %s,\n\t\"pulse_sides\": %s,\n\t\"blocks\": [\n%s\n\t]\n}\n" % [
		d["id"], d["w"], d["h"], str(d["hard"]).to_lower(), d["min_taps"], d["moves"], d["seed"],
		JSON.stringify(d["stones"]), JSON.stringify(d["pulse_sides"], "", false), ",\n".join(lines)]
