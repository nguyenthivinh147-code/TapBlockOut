extends SceneTree
## Imports the 400 MoreColor levels of the reference game into data/road_trip/rt_NNNN.json (Road Trip,
## design.md mục 7 "Road Trip").
## Source: <cfg>/configs_base_tabledata/tb_morecolorlevel_config (order, Difficulty, StepLimit) and
## <cfg>/configs_morecolorlevels/<LevelDataPath>.
## Source axes: a cell's x is its row (up = -x) and y its column (left = -y); the only reading under which every
## level clears. The shape is already portrait (10-14 columns, 12-24 rows), so it is kept as is, centred in a grid of
## at least Config.BOARD_W x BOARD_H. Each block keeps its exit side in `dir`; moves = StepLimit.
## Gates: every side is split into colored gates, each gate its own color, and a block takes the color of the gate it
## leaves through (the gate holding most of its cells along that side). Levels up to TWO_GATES_UNTIL have 2 gates a
## side (8 colors, cut where the source cuts: column 10, row 14 of its 20 x 28 grid); later levels 3 gates a side
## (12 colors), cut near the thirds of the shape where the fewest leaving blocks straddle a cut. Gate colors are
## LevelData.GATE_COLORS (the first 8, or all 12) shuffled with the level number as seed.
## Every level must clear by greedy removal (no mechanics here, so removing a block never blocks another) in exactly
## its block count of taps, with taps <= StepLimit; otherwise nothing is written.
## Run: tools/godot.sh --headless --path . -s res://tools/import_road_trip.gd -- <cfg dir>

const Config := preload("res://src/config.gd")
const BoardState := preload("res://src/core/board_state.gd")
const LevelData := preload("res://src/core/level_data.gd")

const OUT_DIR := "res://data/road_trip/"
const OUT_FILE := "rt_%04d.json"
const TABLE := "configs_base_tabledata/tb_morecolorlevel_config"
const LEVELS := "configs_morecolorlevels/"
## Order gates are colored in: up left to right, right top to bottom, down left to right, left top to bottom.
const SIDE_ORDER := ["up", "right", "down", "left"]
const TWO_GATES_UNTIL := 200
## The source's own cut on a side, in its grid: first column / row of the second gate.
const SOURCE_CUT := {"x": 10, "y": 14}
## 3-gate cuts are searched this many cells around the thirds.
const CUT_SEARCH := 3


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Cần <cfg dir> (thư mục chứa configs_base_tabledata và configs_morecolorlevels)")
		quit(1)
		return
	var cfg := str(args[0]).trim_suffix("/").trim_suffix("\\") + "/"
	var table: Variant = JSON.parse_string(FileAccess.get_file_as_string(cfg + TABLE))
	if not (table is Array) or (table as Array).is_empty():
		push_error("Không đọc được " + cfg + TABLE)
		quit(1)
		return
	var rows: Array = (table as Array).duplicate()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.id) < int(b.id))
	var out: Array[String] = []
	var tiers := {1: 0, 2: 0, 3: 0}
	var straddle := 0
	for i in rows.size():
		var r: Dictionary = rows[i]
		var src: Variant = JSON.parse_string(FileAccess.get_file_as_string(cfg + LEVELS + str(r.LevelDataPath)))
		if not (src is Dictionary):
			push_error("Không đọc được level " + str(r.LevelDataPath))
			quit(1)
			return
		var d := convert_level(src, i + 1, r)
		straddle += int(d.get("_straddle", 0))
		d.erase("_straddle")
		var errs := LevelData.validate(d)
		if not errs.is_empty():
			push_error("%s: %s" % [r.LevelDataPath, ", ".join(errs)])
			quit(1)
			return
		var taps := greedy_taps(d)
		if taps != (d.blocks as Array).size() or taps > int(d.moves):
			push_error("%s: không giải được trong %d bước (greedy %d)" % [r.LevelDataPath, int(d.moves), taps])
			quit(1)
			return
		tiers[int(d.difficulty)] = int(tiers.get(int(d.difficulty), 0)) + 1
		out.append(to_json(d))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for i in out.size():
		var f := FileAccess.open(OUT_DIR + OUT_FILE % (i + 1), FileAccess.WRITE)
		f.store_string(out[i])
		f.close()
	print("road trip: %d level, độ khó %s, khối nằm vắt hai cổng %d" % [out.size(), str(tiers), straddle])
	quit(0)


## One source level (row r of the table) in the game's level format, id = n.
static func convert_level(src: Dictionary, n: int, r: Dictionary) -> Dictionary:
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-(1 << 20), -(1 << 20))
	for b in src.blockList:
		for c in b.cells:
			var p := Vector2i(int(c.y), int(c.x))
			lo = Vector2i(mini(lo.x, p.x), mini(lo.y, p.y))
			hi = Vector2i(maxi(hi.x, p.x), maxi(hi.y, p.y))
	var span := hi - lo + Vector2i.ONE
	var w := maxi(Config.BOARD_W, span.x)
	var h := maxi(Config.BOARD_H, span.y)
	var shift := Vector2i((w - span.x) / 2, (h - span.y) / 2) - lo
	var list: Array = (src.blockList as Array).duplicate()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.id) < int(b.id))
	var blocks: Array = []
	for b in list:
		var cells: Array = []
		for c in b.cells:
			var p := Vector2i(int(c.y), int(c.x)) + shift
			cells.append([p.x, p.y])
		blocks.append({"id": "b%d" % int(b.id), "color": "", "dir": str(b.exitDir), "cells": cells,
			"ice": 0, "chained_by": "", "inner_color": "", "fog": false})
	var count := 2 if n <= TWO_GATES_UNTIL else 3
	var gates := {}
	var straddle := 0
	var colors := gate_colors(n, count)
	var ci := 0
	for side in SIDE_ORDER:
		var vertical: bool = side == "left" or side == "right"
		var length := h if vertical else w
		var cuts: Array[int] = []
		if count == 2:
			var src_cut: int = SOURCE_CUT.y + shift.y if vertical else SOURCE_CUT.x + shift.x
			cuts.append(clampi(src_cut, 1, length - 1))
		else:
			var a: int = (lo.y + shift.y) if vertical else (lo.x + shift.x)
			var e: int = a + (span.y if vertical else span.x)
			cuts = best_cuts(blocks, side, a, e, length)
		var segs: Array = []
		var at := 0
		for k in cuts.size() + 1:
			var to: int = cuts[k] if k < cuts.size() else length
			segs.append([colors[ci], at, to])
			ci += 1
			at = to
		gates[side] = segs
		for b in blocks:
			if str(b.dir) != side:
				continue
			var votes := {}
			for c in b.cells:
				var pos: int = int(c[1]) if vertical else int(c[0])
				var g := gate_index(segs, pos)
				votes[g] = int(votes.get(g, 0)) + 1
			if votes.size() > 1:
				straddle += 1
			var best := -1
			for g in votes:
				if best < 0 or int(votes[g]) > int(votes[best]) or (votes[g] == votes[best] and int(g) < best):
					best = int(g)
			b["color"] = str(segs[best][0])
	var diff := clampi(int(r.get("Difficulty", 1)), 1, 3)
	return {"id": n, "w": w, "h": h, "hard": diff >= 2, "difficulty": diff, "min_taps": blocks.size(),
		"moves": int(r.StepLimit), "source": str(r.LevelDataPath), "stones": [], "pulse_sides": [],
		"gates": gates, "blocks": blocks, "_straddle": straddle}


## The `count` * 4 gate colors of level n: the first 8 (2 gates a side) or all 12 of GATE_COLORS, shuffled by n.
static func gate_colors(n: int, count: int) -> Array:
	var pool: Array = LevelData.GATE_COLORS.slice(0, count * 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = n
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	return pool


static func gate_index(segs: Array, pos: int) -> int:
	for k in segs.size():
		if pos < int(segs[k][2]):
			return k
	return segs.size() - 1


## Two cuts for 3 gates on `side`, near the thirds of the shape's extent [a, e): fewest blocks leaving through that
## side straddle a cut, then closest to the thirds. Cuts stay inside 1..length-1 and apart.
static func best_cuts(blocks: Array, side: String, a: int, e: int, length: int) -> Array[int]:
	var vertical: bool = side == "left" or side == "right"
	var ranges: Array[Vector2i] = []
	for b in blocks:
		if str(b.dir) != side:
			continue
		var mn := 1 << 20
		var mx := -(1 << 20)
		for c in b.cells:
			var pos: int = int(c[1]) if vertical else int(c[0])
			mn = mini(mn, pos)
			mx = maxi(mx, pos)
		ranges.append(Vector2i(mn, mx))
	var third := float(e - a) / 3.0
	var i1 := roundi(a + third)
	var i2 := roundi(a + third * 2.0)
	var best: Array[int] = [clampi(i1, 1, length - 2), clampi(i2, 2, length - 1)]
	var best_cost := INF
	for c1 in range(i1 - CUT_SEARCH, i1 + CUT_SEARCH + 1):
		for c2 in range(i2 - CUT_SEARCH, i2 + CUT_SEARCH + 1):
			if c1 < 1 or c2 > length - 1 or c2 - c1 < 2:
				continue
			var cross := 0
			for rg in ranges:
				if (rg.x < c1 and rg.y >= c1) or (rg.x < c2 and rg.y >= c2):
					cross += 1
			var cost := cross * 100.0 + absf(c1 - i1) + absf(c2 - i2)
			if cost < best_cost:
				best_cost = cost
				best = [c1, c2]
	return best


## Taps to clear by always taking the first block that can leave; -1 when stuck.
static func greedy_taps(d: Dictionary) -> int:
	var data := d.duplicate(true)
	data["moves"] = 1 << 20
	var b := BoardState.new(data)
	var taps := 0
	while not b.is_won():
		var id := b.hint()
		if id == "":
			return -1
		b.tap(id)
		taps += 1
	return taps


## Same layout as data/levels: header lines, one gate side and one block per line.
static func to_json(d: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("{")
	lines.append('\t"id": %d, "w": %d, "h": %d, "hard": %s, "difficulty": %d,' % [d.id, d.w, d.h,
		"true" if d.hard else "false", d.difficulty])
	lines.append('\t"min_taps": %d, "moves": %d, "source": %s,' % [d.min_taps, d.moves, JSON.stringify(d.source)])
	lines.append('\t"stones": [],')
	lines.append('\t"pulse_sides": [],')
	lines.append('\t"gates": {')
	var sides: Array = d.gates.keys()
	for i in sides.size():
		lines.append('\t\t"%s": %s%s' % [sides[i], JSON.stringify(d.gates[sides[i]], "", false), "," if i < sides.size() - 1 else ""])
	lines.append('\t},')
	lines.append('\t"blocks": [')
	var bl: Array = d.blocks
	for i in bl.size():
		lines.append("\t\t" + JSON.stringify(bl[i], "", false) + ("," if i < bl.size() - 1 else ""))
	lines.append("\t]")
	lines.append("}")
	return "\n".join(lines) + "\n"
