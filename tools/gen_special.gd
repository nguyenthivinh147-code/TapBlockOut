extends SceneTree
## Sinh bàn Màn đặc biệt (design.md mục 7 "Màn đặc biệt") bằng SpecialBoard.generate và ghi sp_NNNN.json.
## Chạy: tools/godot.sh --headless --path . -s res://tools/gen_special.gd -- [--from=1] [--to=100] [--seed=0] [--out=user://gen_special]
## Mặc định ghi vào user://gen_special. Bản phát hành (Config.SPECIAL.boards bàn) sinh bằng:
##   tools/godot.sh --headless --path . -s res://tools/gen_special.gd -- --to=100 --seed=20261109 --out=res://data/special
## rồi bake lại data/pudding_sdf.res bằng tools/bake_sdf.gd. Thoát 1 nếu có bàn không sinh được.
## Bom không nằm trong file: game đặt bom lúc vào chơi (SpecialBoard.bomb_plan) theo số trận đã thắng.

const SpecialBoard := preload("res://src/core/special_board.gd")
const LevelData := preload("res://src/core/level_data.gd")
const Config := preload("res://src/config.gd")

const DEFAULT_OUT := "user://gen_special"
const BASE_SEED := 20261109
const RESEED_STEP := 1000


func _init() -> void:
	var from := 1
	var to := int(Config.SPECIAL.boards)
	var base := 0
	var out := DEFAULT_OUT
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--from="):
			from = int(a.substr(7))
		elif a.begins_with("--to="):
			to = int(a.substr(5))
		elif a.begins_with("--seed="):
			base = int(a.substr(7))
		elif a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var bad := 0
	var blocks_sum := 0
	var rounds_sum := 0
	var t0 := Time.get_ticks_msec()
	for i in range(from, to + 1):
		var d := SpecialBoard.generate(i, base + i * RESEED_STEP)
		if d.is_empty() or not LevelData.validate(d).is_empty():
			push_error("sp %d: không sinh được" % i)
			bad += 1
			continue
		blocks_sum += (d.blocks as Array).size()
		rounds_sum += int(d.rounds)
		var f := FileAccess.open("%s/sp_%04d.json" % [out, i], FileAccess.WRITE)
		if f == null:
			push_error("sp %d: không ghi được" % i)
			bad += 1
			continue
		f.store_string(format_board(d))
		f.close()
	var n := maxi(to - from + 1 - bad, 1)
	print("gen_special: %d bàn, %d hỏng, khối TB %.1f, lượt dọn bàn TB %.1f, %d ms" % [
		to - from + 1, bad, float(blocks_sum) / n, float(rounds_sum) / n, Time.get_ticks_msec() - t0])
	quit(1 if bad > 0 else 0)


## Đầu file nhiều dòng, mỗi khối một dòng (như data/levels).
static func format_board(d: Dictionary) -> String:
	var lines: Array[String] = []
	for b in d["blocks"]:
		lines.append("\t\t" + JSON.stringify({
			"id": b["id"], "color": b["color"], "cells": b["cells"], "ice": b["ice"],
			"chained_by": b["chained_by"], "inner_color": b["inner_color"], "fog": b["fog"]}, "", false))
	return ("{\n\t\"id\": %d, \"w\": %d, \"h\": %d, \"hard\": false, \"special\": true,\n" +
		"\t\"min_taps\": %d, \"moves\": %d, \"seed\": %d, \"rounds\": %d, \"rect\": %s,\n" +
		"\t\"stones\": [],\n\t\"pulse_sides\": [],\n\t\"blocks\": [\n%s\n\t]\n}\n") % [
		d["id"], d["w"], d["h"], d["min_taps"], d["moves"], d["seed"], d["rounds"], JSON.stringify(d["rect"]),
		",\n".join(lines)]
