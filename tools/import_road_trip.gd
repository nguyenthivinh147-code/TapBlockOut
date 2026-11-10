extends SceneTree
## Builds the 400 Road Trip levels data/road_trip/rt_NNNN.json (design.md mục 7 "Road Trip") from a level table and a
## folder of level files.
## Input: <cfg>/TABLE (order, Difficulty, StepLimit) and <cfg>/LEVELS<LevelDataPath>.
## Input axes: a cell's x is its row (up = -x) and y its column (left = -y); the only reading under which every level
## clears. The shape is already portrait (10-14 columns, 12-24 rows), so it is kept as is, centred in a grid of at least
## Config.BOARD_W x BOARD_H. Each block keeps its exit side in `dir`; moves = StepLimit.
## Re-cut (2026-11-10, user: more L blocks, fewer straight ones; design.md mục 7 "Road Trip"): the input's cells are
## cut again into as many blocks by LevelGenerator._tile (L blocks favored, Config.TILE_*), and exit sides are assigned
## by LevelGenerator._assign (`recut`) aiming at the input's depth (longest chain of waits); a block never takes a side
## where it would straddle two gates (the cuts below: INPUT_CUT, or the thirds of the shape) unless every side does.
## The input's blocks only give the cells, the depth and the blocked-at-start count that harden() measures against.
## Gates: every side is split into colored gates, each gate its own color, and a block takes the color of the gate it
## leaves through (the gate holding most of its cells along that side). Levels up to TWO_GATES_UNTIL have 2 gates a
## side (8 colors, cut at INPUT_CUT: column 10, row 14 of the input's 20 x 28 grid); later levels 3 gates a side
## (12 colors), cut near the thirds of the shape where the fewest leaving blocks straddle a cut. Gate colors are
## LevelData.GATE_COLORS (the first 8, or all 12) shuffled with the level number as seed.
## Harder levels (harden_all): after the gates are cut, some blocks change exit side so that more blocks are blocked at
## the start; the gates stay, a block that changes side takes the color of its gate on the new side.
## Every level must clear by greedy removal (no mechanics here, so removing a block never blocks another) in exactly
## its block count of taps, with taps <= StepLimit; otherwise nothing is written.
## Run: tools/godot.sh --headless --path . -s res://tools/import_road_trip.gd -- <cfg dir>

const Config := preload("res://src/config.gd")
const BoardState := preload("res://src/core/board_state.gd")
const LevelData := preload("res://src/core/level_data.gd")
const LevelGenerator := preload("res://src/core/level_generator.gd")

const OUT_DIR := "res://data/road_trip/"
const OUT_FILE := "rt_%04d.json"
const TABLE := "configs_base_tabledata/tb_morecolorlevel_config"
const LEVELS := "configs_morecolorlevels/"
## Order gates are colored in: up left to right, right top to bottom, down left to right, left top to bottom. Also the
## side index order of harden().
const SIDE_ORDER := ["up", "right", "down", "left"]
const TWO_GATES_UNTIL := 200
## The input's own cut on a side, in its grid: first column / row of the second gate.
const INPUT_CUT := {"x": 10, "y": 14}
## 3-gate cuts are searched this many cells around the thirds.
const CUT_SEARCH := 3
## Blocked at the start after harden, in percent of before (rounded up), per level and over all levels.
const HARDEN_PERCENT := 110
## harden() search budget: restarts of the side flips, restarts of the rebuild, climb steps per rebuild.
const FLIP_TRIES := 4
const PEEL_TRIES := 3
const CLIMB_STEPS := 6000
## recut(): RECUT_TRIES cuts, each with up to RECUT_ASSIGN side assignments (weight exponent RECUT_POWER, so most blocks
## wait at the start like the input); the assignment closest to the input's depth wins, ties to more blocked blocks.
## Seeded by RECUT_SALT + level number.
const RECUT_TRIES := 6
const RECUT_ASSIGN := 10
const RECUT_POWER := 1
const RECUT_SALT := 910000


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Cần <cfg dir> (thư mục chứa bảng level TABLE và thư mục level LEVELS)")
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
	var levels: Array = []
	for i in rows.size():
		var r: Dictionary = rows[i]
		var src: Variant = JSON.parse_string(FileAccess.get_file_as_string(cfg + LEVELS + str(r.LevelDataPath)))
		if not (src is Dictionary):
			push_error("Không đọc được level " + str(r.LevelDataPath))
			quit(1)
			return
		var lvl := convert_level(src, i + 1, r)
		if lvl.is_empty():
			push_error("level %d: không cắt lại được" % (i + 1))
			quit(1)
			return
		levels.append(lvl)
	var report := harden_all(levels)
	var out: Array[String] = []
	var tiers := {1: 0, 2: 0, 3: 0}
	for d: Dictionary in levels:
		var errs := LevelData.validate(d)
		if not errs.is_empty():
			push_error("level %d: %s" % [int(d.id), ", ".join(errs)])
			quit(1)
			return
		var taps := greedy_taps(d)
		if taps != (d.blocks as Array).size() or taps > int(d.moves):
			push_error("level %d: không giải được trong %d bước (greedy %d)" % [int(d.id), int(d.moves), taps])
			quit(1)
			return
		tiers[int(d.difficulty)] = int(tiers.get(int(d.difficulty), 0)) + 1
		out.append(to_json(d))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for i in out.size():
		var f := FileAccess.open(OUT_DIR + OUT_FILE % (i + 1), FileAccess.WRITE)
		f.store_string(out[i])
		f.close()
	print("road trip: %d level, độ khó %s" % [out.size(), str(tiers)])
	print(report_text(report))
	print(shape_text(levels))
	quit(0)


## Share of block shapes over all levels (LevelGenerator._shape_kind): 1 cell, straight, L, other.
static func shape_text(levels: Array) -> String:
	var counts := {"1 ô": 0, "thẳng": 0, "L": 0, "khác": 0}
	var total := 0
	for d: Dictionary in levels:
		for b in d.blocks:
			var cells: Array = []
			for c in b.cells:
				cells.append(Vector2i(int(c[0]), int(c[1])))
			var key := "khác"
			if cells.size() == 1:
				key = "1 ô"
			else:
				match LevelGenerator._shape_kind(cells):
					LevelGenerator.SHAPE_STRAIGHT:
						key = "thẳng"
					LevelGenerator.SHAPE_L:
						key = "L"
			counts[key] += 1
			total += 1
	var parts := PackedStringArray()
	for k in counts:
		parts.append("%s %.1f%%" % [k, 100.0 * counts[k] / maxi(total, 1)])
	return "hình khối (%d khối): %s" % [total, ", ".join(parts)]


## One input level (row r of the table) in the game's level format, id = n.
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
	var input := {"w": w, "h": h, "blocks": blocks}
	var p0 := ways(input)
	var orig: Array[int] = []
	for b in blocks:
		orig.append(SIDE_ORDER.find(str(b.dir)))
	var k_ref := _blocked(p0, orig)
	blocks = recut(blocks, w, h, n, seam_cuts(count, lo, span, shift, w, h), _depth(p0, orig))
	if blocks.is_empty():
		return {}
	var gates := {}
	var colors := gate_colors(n, count)
	var ci := 0
	for side in SIDE_ORDER:
		var vertical: bool = side == "left" or side == "right"
		var length := h if vertical else w
		var cuts: Array[int] = []
		if count == 2:
			var cut: int = INPUT_CUT.y + shift.y if vertical else INPUT_CUT.x + shift.x
			cuts.append(clampi(cut, 1, length - 1))
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
	var diff := clampi(int(r.get("Difficulty", 1)), 1, 3)
	var d := {"id": n, "w": w, "h": h, "hard": diff >= 2, "difficulty": diff, "min_taps": blocks.size(),
		"moves": int(r.StepLimit), "stones": [], "pulse_sides": [], "gates": gates, "blocks": blocks, "k_ref": k_ref}
	color_blocks(d)
	return d


## Where the gates of a level will be cut, before the blocks are known: {"x": columns (up / down gates), "y": rows
## (left / right gates)}, each the first cell of the next gate. 2 gates: INPUT_CUT; 3 gates: the thirds of the shape
## (best_cuts later searches around them).
static func seam_cuts(count: int, lo: Vector2i, span: Vector2i, shift: Vector2i, w: int, h: int) -> Dictionary:
	if count == 2:
		return {"x": [clampi(int(INPUT_CUT.x) + shift.x, 1, w - 1)],
			"y": [clampi(int(INPUT_CUT.y) + shift.y, 1, h - 1)]}
	var out := {}
	for axis in ["x", "y"]:
		var a: int = lo.x + shift.x if axis == "x" else lo.y + shift.y
		var third := float(span.x if axis == "x" else span.y) / 3.0
		out[axis] = [roundi(a + third), roundi(a + third * 2.0)]
	return out


## Re-cuts the cells of `blocks` (one level, already on the board grid w x h) into as many blocks with
## LevelGenerator._tile and assigns exit sides with LevelGenerator._assign aiming at `depth_ref`; no block takes a side
## where its cells straddle a cut of `cuts` (seam_cuts) unless all four do. Blocks are named b1.. by first cell (row,
## then column), cells sorted the same way, `color` left for color_blocks. [] when no cut works.
static func recut(blocks: Array, w: int, h: int, n: int, cuts: Dictionary, depth_ref: int) -> Array:
	var area: Array[Vector2i] = []
	for b in blocks:
		for c in b.cells:
			area.append(Vector2i(int(c[0]), int(c[1])))
	area.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var none: Array[Vector2i] = []
	var allowed: Array[int] = [0, 1, 2, 3]
	var best: Array = []
	var best_err := 1 << 20
	var best_k := -1
	for t in RECUT_TRIES:
		var rng := LevelGenerator._rng(RECUT_SALT + n, t)
		var groups := LevelGenerator._tile(area, w, h, none, blocks.size(), "", rng)
		if groups.size() != blocks.size():
			continue
		var forbid := _straddle_mask(groups, cuts)
		var aim := depth_ref
		for _k in RECUT_ASSIGN:
			var asg := LevelGenerator._assign(w, h, none, groups, allowed, RECUT_POWER, rng, aim, forbid)
			if asg.is_empty():
				break
			var cand := _named_blocks(groups, asg.color)
			var cd := {"w": w, "h": h, "blocks": cand}
			var dirs: Array[int] = []
			for b in cand:
				dirs.append(SIDE_ORDER.find(str(b.dir)))
			var k := _blocked(ways(cd), dirs)
			var err := absi(int(asg.depth) - depth_ref)
			if err < best_err or (err == best_err and k > best_k):
				best = cand
				best_err = err
				best_k = k
			aim = clampi(aim + depth_ref - int(asg.depth), 1, groups.size())
	return best


## forbid for LevelGenerator._assign: forbid[i * 4 + c] = 1 when block i's cells straddle a cut on side
## LevelData.SIDES[c] (columns for up / down, rows for left / right); all zero for a block that straddles on every side.
static func _straddle_mask(groups: Array, cuts: Dictionary) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(groups.size() * 4)
	for i in groups.size():
		var mn := Vector2i(1 << 20, 1 << 20)
		var mx := Vector2i(-(1 << 20), -(1 << 20))
		for c: Vector2i in groups[i]:
			mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
			mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
		var row := PackedByteArray([0, 0, 0, 0])
		for col in 4:
			var side: String = LevelData.SIDES[col]
			var vertical := side == "left" or side == "right"
			var lo_p := mn.y if vertical else mn.x
			var hi_p := mx.y if vertical else mx.x
			for cut: int in cuts["y" if vertical else "x"]:
				if lo_p < cut and hi_p >= cut:
					row[col] = 1
		if row.count(1) < 4:
			for col in 4:
				out[i * 4 + col] = row[col]
	return out


## Level blocks from groups of cells and color indices (LevelData.SIDES order): b1.. by first cell, row then column.
static func _named_blocks(groups: Array, colors: Array) -> Array:
	var by_row := func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x)
	var items: Array = []
	for i in groups.size():
		var cells: Array[Vector2i] = []
		cells.assign(groups[i])
		cells.sort_custom(by_row)
		items.append([cells, int(colors[i])])
	items.sort_custom(func(a: Array, b: Array) -> bool: return by_row.call(a[0][0], b[0][0]))
	var out: Array = []
	for k in items.size():
		var cl: Array = []
		for c: Vector2i in items[k][0]:
			cl.append([c.x, c.y])
		out.append({"id": "b%d" % (k + 1), "color": "", "dir": LevelData.SIDES[int(items[k][1])], "cells": cl,
			"ice": 0, "chained_by": "", "inner_color": "", "fog": false})
	return out


## p[i][s] = blocks on block i's way out through side SIDE_ORDER[s] (indices into d.blocks), as harden() uses it.
static func ways(d: Dictionary) -> Array:
	var blocks: Array = d.blocks
	var occ := {}
	for i in blocks.size():
		for c in blocks[i].cells:
			occ[Vector2i(int(c[0]), int(c[1]))] = i
	var p: Array = []
	for i in blocks.size():
		var row: Array = []
		for side in SIDE_ORDER:
			var step: Vector2i = LevelData.SIDE_DIR[side]
			var seen := {}
			var way := PackedInt32Array()
			for c in blocks[i].cells:
				var q := Vector2i(int(c[0]), int(c[1])) + step
				while q.x >= 0 and q.y >= 0 and q.x < int(d.w) and q.y < int(d.h):
					var o: int = occ.get(q, -1)
					if o >= 0 and o != i and not seen.has(o):
						seen[o] = true
						way.append(o)
					q += step
			row.append(way)
		p.append(row)
	return p


## Every block takes the color of the gate on its `dir` side that holds most of its cells (ties: the first gate).
## Returns how many blocks straddle two gates.
static func color_blocks(d: Dictionary) -> int:
	var straddle := 0
	for b in d.blocks:
		var side := str(b.dir)
		var vertical: bool = side == "left" or side == "right"
		var segs: Array = d.gates[side]
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
	return straddle


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


# --- harder levels -------------------------------------------------------------------------------------------------
# A block is blocked when another block lies on its way out (BoardState: the whole block slides to the edge). With no
# mechanics, block a waits for every block on its way, so a level clears iff these waits have no cycle; its depth is
# the longest chain of waits (the rounds of removing every free block at once). harden() works on block indices, side
# indices into SIDE_ORDER, and p[i][s] = blocks on block i's way out through side s.


## Makes every level harder and recolors its blocks; the gates do not change. Per level (harden): at least
## HARDEN_PERCENT % as many blocks blocked at the start as before (rounded up, at least one block stays free) when a
## search finds it, else the most it found; the depth never drops; as few blocks as possible change side; a block
## moves to a side where it straddles two gates only when the level falls short of its target otherwise. Over all
## levels: blocked blocks reach HARDEN_PERCENT % of before, levels that met their own target taking more side flips in
## level order if needed. Deterministic for the same levels. Returns the numbers for report_text.
static func harden_all(levels: Array) -> Dictionary:
	var states: Array = []
	var k0_sum := 0
	var k_sum := 0
	for d: Dictionary in levels:
		var st := harden(d)
		states.append(st)
		k0_sum += int(st.k0)
		k_sum += _blocked(st.p, st.dirs)
	var need := (k0_sum * HARDEN_PERCENT + 99) / 100
	for i in states.size():
		if k_sum >= need:
			break
		var st: Dictionary = states[i]
		var k := _blocked(st.p, st.dirs)
		if k < int(st.target):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = int(levels[i].id) * 31337
		var nk := _flip(st.p, st.forbid, st.dirs, mini((st.dirs as Array).size() - 1, k + need - k_sum), rng)
		k_sum += nk - k
	var rep := {"levels": levels.size(), "blocks": 0, "k0": 0, "k": 0, "need": need, "depth0": 0, "depth": 0,
		"changed": 0, "straddle": 0, "short": [], "tiers": {}}
	for i in levels.size():
		var d: Dictionary = levels[i]
		var st: Dictionary = states[i]
		var dirs: Array[int] = st.dirs
		var blocks: Array = d.blocks
		for j in blocks.size():
			blocks[j]["dir"] = SIDE_ORDER[dirs[j]]
		rep.straddle += color_blocks(d)
		var k := _blocked(st.p, dirs)
		var n := blocks.size()
		rep.blocks += n
		rep.k0 += int(st.k0)
		rep.k += k
		rep.depth0 += int(st.depth0)
		rep.depth += _depth(st.p, dirs)
		rep.changed += _changed(st.orig, dirs)
		if k < int(st.target):
			rep.short.append([int(d.id), int(st.k0), int(st.target), k])
		var tier: Array = rep.tiers.get(int(d.difficulty), [0, 0, 0])
		rep.tiers[int(d.difficulty)] = [int(tier[0]) + n, int(tier[1]) + int(st.k0), int(tier[2]) + k]
	return rep


static func report_text(rep: Dictionary) -> String:
	var pct := func(a: int, b: int) -> String: return "%.2f%%" % (100.0 * a / maxi(b, 1))
	var lines := PackedStringArray()
	lines.append("bị chặn lúc đầu: %s -> %s (cần %s)" % [pct.call(rep.k0, rep.blocks), pct.call(rep.k, rep.blocks),
		pct.call(rep.need, rep.blocks)])
	var tiers: Array = rep.tiers.keys()
	tiers.sort()
	for t in tiers:
		var v: Array = rep.tiers[t]
		lines.append("  độ khó %d: %s -> %s" % [t, pct.call(v[1], v[0]), pct.call(v[2], v[0])])
	lines.append("độ sâu trung bình: %.2f -> %.2f" % [float(rep.depth0) / rep.levels, float(rep.depth) / rep.levels])
	lines.append("khối đổi hướng: %d (%.2f mỗi level), khối vắt hai cổng: %d" % [rep.changed,
		float(rep.changed) / rep.levels, rep.straddle])
	lines.append("level chưa đạt %d%%: %d %s" % [HARDEN_PERCENT, (rep.short as Array).size(),
		" ".join((rep.short as Array).map(func(s: Array) -> String: return "L%d(%d->%d/%d)" % [s[0], s[1], s[3], s[2]]))])
	return "\n".join(lines)


## Search for one level, seeded by its id: first with no block moved to a side where it would straddle two gates;
## when that falls short of the target, again without that rule, kept if it blocks more. `k0` is the input's blocked
## count (`k_ref`, set by convert_level) when there is one. Returns {p, orig, forbid, dirs, k0, target, depth0}; d is
## not changed.
static func harden(d: Dictionary) -> Dictionary:
	var blocks: Array = d.blocks
	var n := blocks.size()
	var p := ways(d)
	var orig: Array[int] = []
	for i in n:
		orig.append(SIDE_ORDER.find(str(blocks[i].dir)))
	var straddle: Array = []
	var none: Array = []
	for i in n:
		var row := PackedByteArray()
		row.resize(SIDE_ORDER.size())
		for s in SIDE_ORDER.size():
			if s != orig[i] and _straddles(blocks[i], SIDE_ORDER[s], d.gates):
				row[s] = 1
		straddle.append(row)
		var zero := PackedByteArray()
		zero.resize(SIDE_ORDER.size())
		none.append(zero)
	# Measured against the input's blocks (`k_ref`, before recut) so the re-cut levels stay HARDEN_PERCENT % harder than
	# the input; the depth never drops below the re-cut level's own.
	var k0 := int(d.get("k_ref", _blocked(p, orig)))
	var depth0 := _depth(p, orig)
	var target := mini(n - 1, (k0 * HARDEN_PERCENT + 99) / 100)
	var forbid := straddle
	var best := _search(p, orig, straddle, target, depth0, int(d.id))
	if int(best.k) < target:
		var loose := _search(p, orig, none, target, depth0, int(d.id))
		if mini(int(loose.k), target) > int(best.k):
			best = loose
			forbid = none
	return {"p": p, "orig": orig, "forbid": forbid, "dirs": best.dirs, "k0": k0, "target": target, "depth0": depth0}


## The block's cells along `side` fall in more than one gate.
static func _straddles(b: Dictionary, side: String, gates: Dictionary) -> bool:
	var vertical := side == "left" or side == "right"
	var segs: Array = gates[side]
	var first := -1
	for c in b.cells:
		var g := gate_index(segs, int(c[1]) if vertical else int(c[0]))
		if first < 0:
			first = g
		elif g != first:
			return true
	return false


## Side flips of free blocks that make no cycle (a few restarts); when they fall short, a rebuild (_peel) plus a climb
## back to the old depth and fewer changes. forbid[i][s] = 1: block i may not take side s. Returns {dirs, k, c}.
static func _search(p: Array, orig: Array[int], forbid: Array, target: int, depth0: int, id: int) -> Dictionary:
	var k0 := _blocked(p, orig)
	var rng := RandomNumberGenerator.new()
	var best_dirs: Array[int] = orig.duplicate()
	var best_k := k0
	var best_c := 0
	for s in FLIP_TRIES:
		rng.seed = id * 7919 + s + 1
		var dirs: Array[int] = orig.duplicate()
		var k := _flip(p, forbid, dirs, target, rng)
		_cleanup(p, orig, dirs, mini(k, target), depth0, rng)
		k = _blocked(p, dirs)
		var c := _changed(orig, dirs)
		if s == 0 or _better(k, c, best_k, best_c, target):
			best_dirs = dirs
			best_k = k
			best_c = c
	if best_k < target:
		for s in PEEL_TRIES:
			rng.seed = id * 104729 + s + 1
			var dirs := _peel(p, forbid, orig, target, rng)
			if dirs.is_empty():
				continue
			var keep := mini(target, _blocked(p, dirs))
			if keep <= best_k:
				continue
			_climb(p, forbid, orig, dirs, keep, depth0, rng)
			if _depth(p, dirs) < depth0:
				continue
			_cleanup(p, orig, dirs, keep, depth0, rng)
			var k := _blocked(p, dirs)
			var c := _changed(orig, dirs)
			if _better(k, c, best_k, best_c, target):
				best_dirs = dirs
				best_k = k
				best_c = c
			if best_k >= target:
				break
	return {"dirs": best_dirs, "k": best_k, "c": best_c}


static func _better(k: int, c: int, best_k: int, best_c: int, target: int) -> bool:
	var a := mini(k, target)
	var b := mini(best_k, target)
	return a > b or (a == b and c < best_c)


static func _blocked(p: Array, dirs: Array[int]) -> int:
	var k := 0
	for i in dirs.size():
		if not (p[i][dirs[i]] as PackedInt32Array).is_empty():
			k += 1
	return k


static func _changed(orig: Array[int], dirs: Array[int]) -> int:
	var c := 0
	for i in dirs.size():
		if dirs[i] != orig[i]:
			c += 1
	return c


## Longest chain of waits, counting blocks (1 when every block is free); -1 when the waits have a cycle.
static func _depth(p: Array, dirs: Array[int]) -> int:
	var lv: Array[int] = []
	lv.resize(dirs.size())
	var best := 0
	for i in dirs.size():
		var v := _depth_of(p, dirs, lv, i)
		if v < 0:
			return -1
		best = maxi(best, v)
	return best


## lv[i]: 0 not seen, -1 on the current chain, else the depth of i.
static func _depth_of(p: Array, dirs: Array[int], lv: Array[int], i: int) -> int:
	if lv[i] != 0:
		return lv[i]
	lv[i] = -1
	var m := 0
	for j in (p[i][dirs[i]] as PackedInt32Array):
		var v := _depth_of(p, dirs, lv, j)
		if v < 0:
			return -1
		m = maxi(m, v)
	lv[i] = m + 1
	return m + 1


## For each block, the blocks that wait on it directly.
static func _waiters(p: Array, dirs: Array[int]) -> Array:
	var rev: Array = []
	for i in dirs.size():
		rev.append([])
	for i in dirs.size():
		for j in (p[i][dirs[i]] as PackedInt32Array):
			(rev[j] as Array).append(i)
	return rev


## 1 for every block that waits on `a`, directly or through others.
static func _waiting_on(rev: Array, a: int) -> PackedByteArray:
	var mark := PackedByteArray()
	mark.resize(rev.size())
	var stack: Array[int] = [a]
	while not stack.is_empty():
		var x: int = stack.pop_back()
		for k: int in rev[x]:
			if mark[k] == 0:
				mark[k] = 1
				stack.append(k)
	return mark


## Turns free blocks to a side where something is on their way, picked at random among those that make no cycle,
## until `lim` blocks are blocked or one block would be the last free one. Waits only grow, so the depth never drops.
## Returns the blocked count.
static func _flip(p: Array, forbid: Array, dirs: Array[int], lim: int, rng: RandomNumberGenerator) -> int:
	var k := _blocked(p, dirs)
	while k < lim:
		var free: Array[int] = []
		for i in dirs.size():
			if (p[i][dirs[i]] as PackedInt32Array).is_empty():
				free.append(i)
		if free.size() <= 1:
			break
		var rev := _waiters(p, dirs)
		var cands: Array[Vector2i] = []
		for a in free:
			var waiting := _waiting_on(rev, a)
			for s in SIDE_ORDER.size():
				var way: PackedInt32Array = p[a][s]
				if s == dirs[a] or way.is_empty() or forbid[a][s] == 1:
					continue
				var ok := true
				for x in way:
					if waiting[x] == 1:
						ok = false
						break
				if ok:
					cands.append(Vector2i(a, s))
		if cands.is_empty():
			break
		var pick := cands[rng.randi_range(0, cands.size() - 1)]
		dirs[pick.x] = pick.y
		k += 1
	return k


## Puts changed blocks back on their old side, in random order, while `keep` blocks stay blocked and the depth stays
## at least depth0; repeats until nothing more goes back.
static func _cleanup(p: Array, orig: Array[int], dirs: Array[int], keep: int, depth0: int,
		rng: RandomNumberGenerator) -> void:
	var again := true
	while again:
		again = false
		var idx: Array[int] = []
		for i in dirs.size():
			if dirs[i] != orig[i]:
				idx.append(i)
		_shuffle(idx, rng)
		for i in idx:
			var od := dirs[i]
			dirs[i] = orig[i]
			if _blocked(p, dirs) >= keep and _depth(p, dirs) >= depth0:
				again = true
			else:
				dirs[i] = od


## Rebuild: takes blocks off one by one from the outside in. A block whose old side is clear of blocks not yet taken
## keeps it. Otherwise, while n - target free blocks are allowed, a block that was free (most waiters first) is taken
## free; after that a block gets a side whose way holds only blocks already taken, blocks that were free first, then
## the deepest chain. No cycle by construction; the depth may drop (the climb restores it). [] when stuck.
static func _peel(p: Array, forbid: Array, orig: Array[int], target: int, rng: RandomNumberGenerator) -> Array[int]:
	var n := orig.size()
	var rev := _waiters(p, orig)
	var waiters: Array[int] = []
	for a in n:
		waiters.append(_waiting_on(rev, a).count(1))
	var budget := n - target
	var done := PackedByteArray()
	done.resize(n)
	var lv: Array[int] = []
	lv.resize(n)
	var dirs: Array[int] = orig.duplicate()
	for step in n:
		var keep_side: Array[int] = []
		var blocked: Array[Vector2i] = []
		var free: Array[Vector2i] = []
		for i in n:
			if done[i] == 1:
				continue
			if _clear_after(p[i][orig[i]], done):
				keep_side.append(i)
				continue
			for s in SIDE_ORDER.size():
				var way: PackedInt32Array = p[i][s]
				if forbid[i][s] == 1:
					continue
				if way.is_empty():
					free.append(Vector2i(i, s))
				elif _clear_after(way, done):
					blocked.append(Vector2i(i, s))
		var pick := Vector2i(-1, -1)
		if not keep_side.is_empty():
			var i := keep_side[rng.randi_range(0, keep_side.size() - 1)]
			pick = Vector2i(i, orig[i])
		else:
			var was_free: Array[Vector2i] = []
			for v in free:
				if v.y == orig[v.x]:
					was_free.append(v)
			if budget > 0 and not was_free.is_empty():
				var best := -1
				for v in was_free:
					if pick.x < 0 or waiters[v.x] > best or (waiters[v.x] == best and rng.randf() < 0.5):
						pick = v
						best = waiters[v.x]
				budget -= 1
			elif not blocked.is_empty():
				var best := -1
				for v in blocked:
					var score := 1
					for j in (p[v.x][v.y] as PackedInt32Array):
						score = maxi(score, lv[j] + 1)
					if (p[v.x][orig[v.x]] as PackedInt32Array).is_empty():
						score += 1000
					if pick.x < 0 or score > best or (score == best and rng.randf() < 0.5):
						pick = v
						best = score
			elif not free.is_empty():
				var pool := was_free if not was_free.is_empty() else free
				pick = pool[rng.randi_range(0, pool.size() - 1)]
				budget -= 1
			else:
				return [] as Array[int]
		dirs[pick.x] = pick.y
		done[pick.x] = 1
		var d := 1
		for j in (p[pick.x][pick.y] as PackedInt32Array):
			d = maxi(d, lv[j] + 1)
		lv[pick.x] = d
	return dirs


## The way is not empty and holds only blocks already taken.
static func _clear_after(way: PackedInt32Array, done: PackedByteArray) -> bool:
	if way.is_empty():
		return false
	for j in way:
		if done[j] == 0:
			return false
	return true


## Random side changes that keep `keep` blocks blocked and no cycle, accepted when they do not lower
## min(depth, depth0) * 1000 - changed blocks: first back to depth0, then fewer changes.
static func _climb(p: Array, forbid: Array, orig: Array[int], dirs: Array[int], keep: int, depth0: int,
		rng: RandomNumberGenerator) -> void:
	var n := dirs.size()
	var k := _blocked(p, dirs)
	var cur_d := _depth(p, dirs)
	var cur_c := _changed(orig, dirs)
	var score := mini(cur_d, depth0) * 1000 - cur_c
	for it in CLIMB_STEPS:
		if cur_d >= depth0 and cur_c == 0:
			break
		var b := rng.randi_range(0, n - 1)
		var nd: int
		if dirs[b] != orig[b] and rng.randf() < 0.5:
			nd = orig[b]
		else:
			nd = rng.randi_range(0, SIDE_ORDER.size() - 1)
		if nd == dirs[b] or forbid[b][nd] == 1:
			continue
		var od := dirs[b]
		var nk := k - (0 if (p[b][od] as PackedInt32Array).is_empty() else 1) \
			+ (0 if (p[b][nd] as PackedInt32Array).is_empty() else 1)
		if nk < keep:
			continue
		dirs[b] = nd
		var dep := _depth(p, dirs)
		if dep < 0:
			dirs[b] = od
			continue
		var c := cur_c + (1 if od == orig[b] else 0) - (1 if nd == orig[b] else 0)
		var v := mini(dep, depth0) * 1000 - c
		if v >= score:
			score = v
			cur_d = dep
			cur_c = c
			k = nk
		else:
			dirs[b] = od


static func _shuffle(a: Array[int], rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := a[i]
		a[i] = a[j]
		a[j] = t


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
	lines.append('\t"min_taps": %d, "moves": %d,' % [d.min_taps, d.moves])
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
