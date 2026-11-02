extends SceneTree
## Kiểm mọi data/levels/level_NNNN.json: khung, cỡ bàn cố định, solver, khối thoát ngay, min_taps và moves đúng công thức.
## Chạy: tools/godot.sh --headless --path . -s res://tools/validate_levels.gd (thoát 1 nếu có lỗi).

const LevelData := preload("res://src/core/level_data.gd")
const Solver := preload("res://src/core/solver.gd")
const Config := preload("res://src/config.gd")

const DIR := "res://data/levels"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var dir := DirAccess.open(DIR)
	if dir == null:
		printerr("Không mở được %s" % DIR)
		quit(1)
		return
	var files: Array[String] = []
	for f in dir.get_files():
		if f.begins_with("level_") and f.ends_with(".json"):
			files.append(f)
	files.sort()
	if files.is_empty():
		printerr("Không có file level nào trong %s" % DIR)
		quit(1)
		return
	var bad := 0
	for f in files:
		var errs := check_file(DIR + "/" + f, f)
		if errs.is_empty():
			print("ok   %s" % f)
		else:
			bad += 1
			for e in errs:
				printerr("FAIL %s: %s" % [f, e])
	print("---- %d level, %d lỗi ----" % [files.size(), bad])
	quit(1 if bad > 0 else 0)


## Trả danh sách lỗi của một file level.
static func check_file(path: String, fname: String) -> Array[String]:
	var errs: Array[String] = []
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		errs.append("không đọc được JSON")
		return errs
	var d: Dictionary = parsed
	errs.append_array(LevelData.validate(d))
	if not errs.is_empty():
		return errs
	var expect_id := fname.trim_prefix("level_").trim_suffix(".json").to_int()
	if int(d["id"]) != expect_id:
		errs.append("id %d không khớp tên file" % int(d["id"]))
	if int(d["w"]) != Config.BOARD_W or int(d["h"]) != Config.BOARD_H:
		errs.append("bàn %dx%d khác cỡ cố định %dx%d" % [int(d["w"]), int(d["h"]), Config.BOARD_W, Config.BOARD_H])
	if d["blocks"].is_empty():
		errs.append("level không có khối")
		return errs
	var r := Solver.solve(d)
	if not r["ok"]:
		errs.append("solver không giải được")
		return errs
	if not d.has("min_taps") or int(d["min_taps"]) != int(r["min_taps"]):
		errs.append("min_taps %s khác solver %d" % [str(d.get("min_taps")), int(r["min_taps"])])
	var want := Solver.compute_moves(d)
	if int(d["moves"]) != want:
		errs.append("moves %d khác công thức %d" % [int(d["moves"]), want])
	if not Solver.immediate_exit_exists(d):
		errs.append("không có khối thoát ngay")
	return errs
