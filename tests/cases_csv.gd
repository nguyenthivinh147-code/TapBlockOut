extends RefCounted
## Đọc danh sách test case `tests/cases/<MODULE>.csv` (docs/TESTING.md "Test case"): 11 cột của skill
## /game-testcase-generator cộng cột AUTO. tests/test_cases.gd kiểm định dạng và case có trong code; tests/smoke/smoke.gd
## báo case của kịch bản không chạy tới. Thư mục có .gdignore (Godot không import CSV thành bản dịch) và không vào APK:
## trên máy thật trả rỗng.

const DIR := "res://tests/cases"
const COLUMNS: Array[String] = ["ID", "CASE", "PRIORITY", "DESCRIPTIONS", "PRE COND", "INPUT", "STEP",
	"EXPECTED RESULT", "ACTUAL RESULT", "STATUS", "NOTE", "AUTO"]


## Mọi file: {"<tên>.csv": {"header": Array[String], "rows": Array[Dictionary]}}. Mỗi row có các cột theo header,
## `rec` (số bản ghi, header là 1; ô có xuống dòng nên không phải số dòng của file) và `cells` (số ô đọc được).
static func load_all() -> Dictionary:
	var out := {}
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.get_extension() == "csv":
			out[f] = read(DIR.path_join(f))
	return out


static func read(path: String) -> Dictionary:
	var res := {"header": [] as Array[String], "rows": []}
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return res
	for h in fa.get_csv_line():
		res.header.append(h.strip_edges().trim_prefix("﻿"))
	var rec := 1
	while not fa.eof_reached():
		var cells := fa.get_csv_line()
		rec += 1
		if cells.size() <= 1 and (cells.is_empty() or cells[0].strip_edges().is_empty()):
			continue
		var row := {"rec": rec, "cells": cells.size()}
		for i in res.header.size():
			row[res.header[i]] = cells[i].strip_edges() if i < cells.size() else ""
		res.rows.append(row)
	return res


## ID các case có AUTO `smoke:<scen>`, theo thứ tự trong file.
static func smoke_ids(scen: String) -> Array[String]:
	var ids: Array[String] = []
	var all := load_all()
	for f in all.values():
		for row in f.rows:
			if str(row.get("AUTO", "")) == "smoke:" + scen:
				ids.append(str(row.get("ID", "")))
	return ids
