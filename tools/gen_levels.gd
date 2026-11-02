extends SceneTree
## Sinh hàng loạt level bằng LevelGenerator và ghi level_NNNN.json.
## Chạy: tools/godot.sh --headless --path . -s res://tools/gen_levels.gd -- [--from=21] [--to=300] [--out=user://gen_out] [--seed=0] [--teach=0]
## Mặc định ghi vào user://gen_out. Muốn ghi vào data/levels thì truyền --out=res://data/levels một cách chủ ý.
## Thoát 1 nếu có level không sinh được hoặc không qua kiểm tra.
##
## Bản phát hành L21-300 (Task 9.3) sinh bằng đúng lệnh này, seed gốc BASE_SEED = 20261101:
##   tools/godot.sh --headless --path . -s res://tools/gen_levels.gd -- --from=21 --to=300 --seed=20261101 --teach=1 --out=res://data/levels
## `--teach=1`: các level dạy cơ chế (id lấy từ Config.UNLOCK: 21, 31, 46, 61, 81, 101) dựng tay bằng TEACH ở dưới
## thay cho bộ sinh; min_taps và moves vẫn do Solver tính. Không có cờ này thì mọi level đều do bộ sinh.

const Gen := preload("res://src/core/level_generator.gd")
const LevelData := preload("res://src/core/level_data.gd")
const Solver := preload("res://src/core/solver.gd")
const Config := preload("res://src/config.gd")

const DEFAULT_FROM := 21
const DEFAULT_TO := 300
const DEFAULT_OUT := "user://gen_out"
## Seed gốc của bản phát hành L21-300 (ngày chốt thiết kế). Mặc định của --seed vẫn là 0.
const BASE_SEED := 20261101

## Level dạy làm tay, mỗi cơ chế một level, id = Config.UNLOCK[cơ chế]. Chỉ MỘT cơ chế mới, hình nhỏ, có khối thoát ngay.
## `rows`: mỗi chuỗi một hàng (y tăng xuống dưới), '.' ô trống, '#' đá, chữ cái là khối (cùng chữ = cùng khối).
## `blk[chữ]`: color (yellow lên, green trái, blue phải, purple xuống) và tuỳ chọn ice, chain (chữ khối chìa),
## inner (màu lớp trong), fog. `pulse`: cạnh có cổng nhịp và trạng thái mở ban đầu.
const TEACH := {
	"stone": {  # đá cố định: B không bay lên được vì đá phía trên, phải chờ A rời khỏi trước
		"rows": ["A.#..", "ABBC.", "...CD", "E.#.D", "EFF.."],
		"blk": {"A": {"color": "yellow"}, "B": {"color": "green"}, "C": {"color": "blue"},
			"D": {"color": "blue"}, "E": {"color": "green"}, "F": {"color": "purple"}},
	},
	"ice": {  # D phải chạm hai lần (nứt rồi thoát), B chờ D
		"rows": ["AA..", "..B.", "C.BD", "C..D", ".EE."],
		"blk": {"A": {"color": "yellow"}, "B": {"color": "blue"}, "C": {"color": "green"},
			"D": {"color": "blue", "ice": 1}, "E": {"color": "purple"}},
	},
	"chain": {  # C có đường thông nhưng bị xích vào D: phải cho D thoát trước
		"rows": ["AA...", ".....", "B.CC.", "B...D", "...EE"],
		"blk": {"A": {"color": "yellow"}, "B": {"color": "green"}, "C": {"color": "yellow", "chain": "D"},
			"D": {"color": "blue"}, "E": {"color": "purple"}},
	},
	"layer": {  # L bóc lớp tím, lộ lớp xanh lá đi trái nhưng bị M chặn: cần thêm một lần chạm
		"rows": ["AA..", "....", "MLL.", "...B", "C..B"],
		"blk": {"A": {"color": "yellow"}, "M": {"color": "green"}, "L": {"color": "purple", "inner": "green"},
			"B": {"color": "blue"}, "C": {"color": "purple"}},
	},
	"fog": {  # D và E kẹt giữa các khối nên ẩn màu, lộ khi ô bên cạnh trống
		"rows": ["AABB", "CDDH", "CEFF", "GG.."],
		"blk": {"A": {"color": "yellow"}, "B": {"color": "yellow"}, "C": {"color": "green"},
			"D": {"color": "yellow", "fog": true}, "E": {"color": "green", "fog": true},
			"F": {"color": "purple"}, "G": {"color": "purple"}, "H": {"color": "blue"}},
	},
	"pulse": {  # cổng phải đóng lúc đầu: B và D (xanh dương) chờ, A và C đi trước làm cổng mở
		"rows": ["AA..", "...B", "C..B", "C.DD"],
		"blk": {"A": {"color": "yellow"}, "B": {"color": "blue"}, "C": {"color": "green"}, "D": {"color": "blue"}},
		"pulse": [{"side": "right", "open": false}],
	},
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var opt := parse_args(OS.get_cmdline_user_args())
	var res := generate_range(int(opt["from"]), int(opt["to"]), int(opt["seed"]), str(opt["out"]), int(opt["teach"]) != 0)
	print("---- %d level, %d lỗi, tb %.1f ms, max %.1f ms (id %d) -> %s ----" % [
		res["count"], res["bad"], res["avg_ms"], res["max_ms"], res["max_id"],
		ProjectSettings.globalize_path(str(opt["out"]))])
	quit(1 if int(res["bad"]) > 0 else 0)


## `--khoá=giá trị`; khoá lạ bị bỏ qua.
static func parse_args(args: PackedStringArray) -> Dictionary:
	var opt := {"from": DEFAULT_FROM, "to": DEFAULT_TO, "out": DEFAULT_OUT, "seed": 0, "teach": 0}
	for a in args:
		if not a.begins_with("--") or not a.contains("="):
			continue
		var kv := a.substr(2).split("=", true, 1)
		match kv[0]:
			"from", "to", "seed", "teach":
				if kv[1].is_valid_int():
					opt[kv[0]] = int(kv[1])
			"out":
				if kv[1] != "":
					opt["out"] = kv[1]
	return opt


## Id của level dạy cơ chế `mech` (theo Config.UNLOCK).
static func teach_id(mech: String) -> int:
	return int(Config.UNLOCK[mech])


## Cơ chế mà level `id` dạy, hoặc "" nếu không phải level dạy.
static func teach_mech(id: int) -> String:
	for m in TEACH:
		if teach_id(m) == id:
			return m
	return ""


## Dựng level dạy từ bảng TEACH; min_taps và moves do Solver tính. {} nếu bảng sai.
static func build_teach(mech: String) -> Dictionary:
	var spec: Dictionary = TEACH[mech]
	var rows: Array = spec["rows"]
	var h := rows.size()
	var w := str(rows[0]).length()
	# Dựng ở giữa bàn cố định: ngoài bảng TEACH là ô trống nên đường thoát không đổi.
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
		"id": teach_id(mech), "w": Config.BOARD_W, "h": Config.BOARD_H, "hard": false, "min_taps": 0, "moves": 0, "seed": 0,
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
## `teach`: level dạy cơ chế lấy từ TEACH thay cho bộ sinh.
static func generate_range(from_id: int, to_id: int, seed: int, out: String, teach: bool = false) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var bad := 0
	var total := 0.0
	var max_ms := 0.0
	var max_id := 0
	var count := 0
	for id in range(from_id, to_id + 1):
		var t0 := Time.get_ticks_usec()
		var tm := teach_mech(id) if teach else ""
		var d := build_teach(tm) if tm != "" else Gen.generate(id, seed)
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
