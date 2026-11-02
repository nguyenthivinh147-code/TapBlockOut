extends RefCounted
## Bộ sinh level (design.md mục 3-4, kế hoạch Task 9.1). Thuần: chỉ dùng RandomNumberGenerator có seed,
## cùng (id, seed) cho cùng level. Cách làm: lát bàn thành polyomino (tự do hoặc đối xứng), rồi mô phỏng
## ván chơi tiến: mỗi bước chọn một khối còn có đường thoát và gán luôn màu (hướng) của nó theo đường đó,
## nên level luôn giải được. Sau đó rải cơ chế theo `Config.UNLOCK`, cuối cùng qua validate và Solver.
## Trường `seed` trong kết quả là seed thật đã dùng (sau khi sinh lại), generate(id, level.seed) cho đúng level đó.

const LevelData := preload("res://src/core/level_data.gd")
const Solver := preload("res://src/core/solver.gd")
const Config := preload("res://src/config.gd")
const BoardState := preload("res://src/core/board_state.gd")
const DifficultyCurve := preload("res://src/core/difficulty_curve.gd")

const MAX_BLOCKS := 30
const MAX_W := 8
const MAX_H := 11
const MAX_TRIES := 60
## Bàn có cổng nhịp: solver phải tìm chính xác nên giữ ít khối.
const GATE_MAX_BLOCKS := 20
const BLOCK_CAP := 5
const NEIGHBORS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## Level hợp lệ cho (id, seed), hoặc {} nếu mọi lần thử đều hỏng (không xảy ra trong thực tế).
static func generate(id: int, seed_value: int) -> Dictionary:
	for attempt in MAX_TRIES:
		var lvl := _attempt(id, seed_value + attempt, attempt)
		if not lvl.is_empty():
			return lvl
	return {}


## Cơ chế nào bật ở level này (theo Config.UNLOCK). Dùng cho test và công cụ.
static func mechanics_for(id: int) -> Array[String]:
	var out: Array[String] = []
	for m in ["stone", "ice", "chain", "layer", "fog", "pulse"]:
		if id >= int(Config.UNLOCK.get(m, 1 << 30)):
			out.append(m)
	return out


static func is_hard(id: int) -> bool:
	return DifficultyCurve.is_hard(id)


static func _mix(v: int) -> int:
	v = (v ^ (v >> 30)) * -4658895280553007687
	v = (v ^ (v >> 27)) * -7723592293110705685
	return v ^ (v >> 31)


static func _rng(id: int, s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = _mix(_mix(id * 2654435761 + 40503) + s * 1442695040888963407)
	return r


## Số khối mục tiêu theo đường cong độ khó (difficulty_curve.gd); `attempt` lớn thì giảm dần để lần sinh lại dễ đạt hơn.
static func _target_count(id: int, _rng: RandomNumberGenerator, attempt: int) -> int:
	@warning_ignore("integer_division")
	return maxi(2, DifficultyCurve.block_count(id) - attempt / 20)


static func _enabled(id: int, mech: String, rng: RandomNumberGenerator, attempt: int) -> bool:
	var unlock: int = int(Config.UNLOCK.get(mech, 1 << 30))
	if id < unlock:
		return false
	var roll := rng.randf()  # luôn rút để chuỗi ngẫu nhiên không lệch theo attempt
	if attempt >= 40:
		return false
	if mech == "pulse" and attempt >= 24:
		return false
	if id < unlock + 10:
		return true
	return roll < 0.7


static func _ramp(id: int, unlock: int, lo: float, hi: float, over: int) -> float:
	return lerpf(lo, hi, clampf(float(id - unlock) / float(over), 0.0, 1.0))


static func _attempt(id: int, s: int, attempt: int) -> Dictionary:
	var rng := _rng(id, s)
	var hard := is_hard(id)
	var feats := {}
	for m in ["stone", "ice", "chain", "layer", "fog", "pulse"]:
		feats[m] = _enabled(id, m, rng, attempt)
	var n := _target_count(id, rng, attempt)
	if feats["pulse"]:
		n = mini(n, GATE_MAX_BLOCKS)
	var mirror := ""
	if n >= 8 and n % 2 == 0 and rng.randf() < 0.35:
		mirror = "h" if rng.randf() < 0.5 else "v"
	var n_stones := 0
	if feats["stone"]:
		var unlock: int = int(Config.UNLOCK["stone"])
		@warning_ignore("integer_division")
		n_stones = mini(6, 1 + (id - unlock) / 20 + rng.randi_range(0, 1))
		if mirror != "":
			n_stones = n_stones + (n_stones % 2)
	var size := _pick_size(n, n_stones, mirror, rng)
	if size == Vector2i.ZERO:
		return {}
	var w := size.x
	var h := size.y
	if mirror == "h" and w % 2 != 0:
		mirror = ""
	elif mirror == "v" and h % 2 != 0:
		mirror = ""
	var stones := _place_stones(w, h, n_stones, mirror, rng)
	var groups := _tile(w, h, stones, n, mirror, rng)
	if groups.is_empty():
		return {}
	var allowed := _allowed_colors(id)
	var asg := _assign(w, h, stones, groups, allowed, hard, rng)
	if asg.is_empty():
		return {}
	var mech := _mechanics(id, feats, n, groups, asg, allowed, rng)
	var level := _build(id, s, hard, w, h, stones, groups, asg, mech)
	if not mech["pulse"].is_empty() and not _fix_gates(level, rng):
		return {}
	var errs := LevelData.validate(level)
	if not errs.is_empty():
		return {}
	var r := Solver.solve(level)
	if not bool(r["ok"]):
		return {}
	level["min_taps"] = int(r["min_taps"])
	level["moves"] = int(r["min_taps"]) + Solver.slack_for(level)
	if not Solver.immediate_exit_exists(level):
		return {}
	return level


## Thử các tổ hợp mở/đóng ban đầu của cổng, giữ tổ hợp đầu tiên mà không phải chạm chờ (solver chỉ tốn
## thời gian tìm chính xác khi phải chờ). false nếu không có tổ hợp nào như vậy.
static func _fix_gates(level: Dictionary, rng: RandomNumberGenerator) -> bool:
	var sides: Array = level["pulse_sides"]
	var combos := 1 << sides.size()
	var start := rng.randi_range(0, combos - 1)
	for k in combos:
		var m := (start + k) % combos
		for i in sides.size():
			sides[i]["open"] = (m >> i) & 1 == 1
		if _no_wait(level):
			return true
	return false


## Tham lam (thoát > nứt > bóc) có đi hết mà không phải chạm chờ cổng không; đồng thời có khối thoát ngay.
static func _no_wait(level: Dictionary) -> bool:
	var b := BoardState.new(level)
	if b.hint() == "":
		return false
	b.add_moves(Solver.BIG_MOVES)
	while not b.is_won():
		var pick := ""
		var rank := 9
		for id in b.block_ids():
			var k := b.peek(id)
			var r := 9
			if k == "exit":
				r = 0
			elif k == "crack":
				r = 1
			elif k == "peel":
				r = 2
			if r < rank:
				rank = r
				pick = id
				if r == 0:
					break
		if pick == "":
			return false
		b.tap(pick)
	return true


static func _allowed_colors(id: int) -> Array[int]:
	var k := DifficultyCurve.color_count(id)
	var out: Array[int] = []
	for i in k:
		out.append(i)
	return out


## Chọn (w, h): h >= w, w <= 8, h <= 11, số ô trống khoảng 2,4 đến 3,4 lần số khối.
static func _pick_size(n: int, n_stones: int, mirror: String, rng: RandomNumberGenerator) -> Vector2i:
	var lo := 2.4
	var hi := 3.4
	for widen in 4:
		var cand: Array[Vector2i] = []
		for w in range(2, MAX_W + 1):
			for h in range(w, MAX_H + 1):
				if float(h) > 1.6 * float(w) + 0.5:
					continue
				if mirror == "h" and w % 2 != 0:
					continue
				if mirror == "v" and h % 2 != 0:
					continue
				var free := w * h - n_stones
				if free >= int(ceil(n * lo)) and free <= int(n * hi) and free >= n:
					cand.append(Vector2i(w, h))
		if not cand.is_empty():
			return cand[rng.randi_range(0, cand.size() - 1)]
		lo -= 0.3
		hi += 0.4
	return Vector2i.ZERO


static func _mirror_cell(c: Vector2i, w: int, h: int, mirror: String) -> Vector2i:
	if mirror == "h":
		return Vector2i(w - 1 - c.x, c.y)
	return Vector2i(c.x, h - 1 - c.y)


## Nửa bàn dùng để dựng khi đối xứng; không đối xứng thì cả bàn.
static func _in_half(c: Vector2i, w: int, h: int, mirror: String) -> bool:
	if mirror == "h":
		@warning_ignore("integer_division")
		return c.x < w / 2
	if mirror == "v":
		@warning_ignore("integer_division")
		return c.y < h / 2
	return true


static func _place_stones(w: int, h: int, count: int, mirror: String, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if _in_half(c, w, h, mirror):
				cells.append(c)
	_shuffle(cells, rng)
	var out: Array[Vector2i] = []
	@warning_ignore("integer_division")
	var want := count / 2 if mirror != "" else count
	for i in mini(want, cells.size()):
		out.append(cells[i])
		if mirror != "":
			out.append(_mirror_cell(cells[i], w, h, mirror))
	return out


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t


## Lát các ô trống thành đúng `n` polyomino bằng cách gộp dần các ô đơn, ưu tiên gộp mảnh nhỏ.
## Trả mảng các `Array[Vector2i]`, hoặc [] nếu kẹt.
static func _tile(w: int, h: int, stones: Array[Vector2i], n: int, mirror: String,
		rng: RandomNumberGenerator) -> Array:
	var stone_set := {}
	for s in stones:
		stone_set[s] = true
	var cells: Array[Vector2i] = []
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if not stone_set.has(c) and _in_half(c, w, h, mirror):
				cells.append(c)
	@warning_ignore("integer_division")
	var target := n / 2 if mirror != "" else n
	var owner := {}
	var groups := {}
	for i in cells.size():
		owner[cells[i]] = i
		groups[i] = [cells[i]]
	var count := cells.size()
	while count > target:
		var pairs: Array = []
		var weights: Array[float] = []
		for gi in groups:
			for c in groups[gi]:
				for dv in NEIGHBORS:
					var nb: Vector2i = c + dv
					if not owner.has(nb):
						continue
					var gj: int = owner[nb]
					if gj <= gi:
						continue
					var sum: int = groups[gi].size() + groups[gj].size()
					if sum > BLOCK_CAP:
						continue
					pairs.append([gi, gj])
					weights.append(float((BLOCK_CAP + 1 - sum) * (BLOCK_CAP + 1 - sum)))
		if pairs.is_empty():
			return []
		var pick: Array = pairs[_pick_weighted(weights, rng)]
		var a: int = pick[0]
		var b: int = pick[1]
		for c in groups[b]:
			owner[c] = a
			groups[a].append(c)
		groups.erase(b)
		count -= 1
	var out: Array = []
	var keys := groups.keys()
	keys.sort()
	for k in keys:
		var g: Array[Vector2i] = []
		g.assign(groups[k])
		out.append(g)
		if mirror != "":
			var m: Array[Vector2i] = []
			for c in g:
				m.append(_mirror_cell(c, w, h, mirror))
			out.append(m)
	return out


static func _pick_weighted(weights: Array[float], rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for x in weights:
		total += x
	var r := rng.randf() * total
	for i in weights.size():
		r -= weights[i]
		if r < 0.0:
			return i
	return weights.size() - 1


## Mô phỏng ván tiến. Trả {order: Array[int], color: Array[int] (theo chỉ số nhóm),
## clear: Array (mỗi nhóm: các màu thoát được lúc nó bị chọn)}; {} nếu kẹt.
static func _assign(w: int, h: int, stones: Array[Vector2i], groups: Array, allowed: Array[int],
		hard: bool, rng: RandomNumberGenerator) -> Dictionary:
	var n := groups.size()
	var grid := PackedInt32Array()
	grid.resize(w * h)
	grid.fill(-1)
	for s in stones:
		grid[s.y * w + s.x] = -2
	for i in n:
		for c in groups[i]:
			grid[c.y * w + c.x] = i
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]
	# path[i*4+col]: chỉ số ô phía trước khối (không tính ô của chính nó), -1 trong dead nếu có đá.
	var path: Array = []
	var dead := PackedByteArray()
	dead.resize(n * 4)
	var blockers := PackedInt32Array()
	blockers.resize(n * 4)
	for i in n:
		for col in 4:
			var p := PackedInt32Array()
			var d: Vector2i = dirs[col]
			var seen := {}
			for c in groups[i]:
				var q: Vector2i = c + d
				while q.x >= 0 and q.y >= 0 and q.x < w and q.y < h:
					var gi := q.y * w + q.x
					if grid[gi] != i and not seen.has(gi):
						seen[gi] = true
						p.append(gi)
						if grid[gi] == -2:
							dead[i * 4 + col] = 1
						else:
							blockers[i * 4 + col] += 1
					q += d
			path.append(p)
	var alive := PackedByteArray()
	alive.resize(n)
	alive.fill(1)
	var used := [0, 0, 0, 0]
	var order: Array[int] = []
	var color: Array[int] = []
	color.resize(n)
	var clear: Array = []
	clear.resize(n)
	for step in n:
		var cand: Array = []  # [i, col]
		var weights: Array[float] = []
		var per_block := {}
		for i in n:
			if alive[i] == 0:
				continue
			for col in allowed:
				if dead[i * 4 + col] != 0:
					continue
				var free := true
				for gi in path[i * 4 + col]:
					if grid[gi] != -1:
						free = false
						break
				if not free:
					continue
				var wt := 1.0 + float(blockers[i * 4 + col])
				if hard:
					wt *= wt
				wt *= 3.0 / (3.0 + float(used[col]))
				cand.append([i, col])
				weights.append(wt)
				if not per_block.has(i):
					per_block[i] = []
				per_block[i].append(col)
		if cand.is_empty():
			return {}
		var pick: Array = cand[_pick_weighted(weights, rng)]
		var bi: int = pick[0]
		var bc: int = pick[1]
		order.append(bi)
		color[bi] = bc
		clear[bi] = per_block[bi]
		used[bc] += 1
		alive[bi] = 0
		for c in groups[bi]:
			grid[c.y * w + c.x] = -1
	return {"order": order, "color": color, "clear": clear}


## Rải cơ chế lên các khối. Trả {ice, chain (idx -> idx khoá), layer (idx -> màu trong), fog, pulse}.
static func _mechanics(id: int, feats: Dictionary, n: int, _groups: Array, asg: Dictionary,
		_allowed: Array[int], rng: RandomNumberGenerator) -> Dictionary:
	var order: Array = asg["order"]
	var pos := {}
	for k in order.size():
		pos[order[k]] = k
	var first: int = order[0]
	var taken := {}  # khối đã dùng cho băng, xích hoặc lớp
	var ice := {}
	var chain := {}
	var layer := {}
	var fog := {}
	var pulse: Array = []
	var pool: Array = []
	for i in n:
		if i != first:
			pool.append(i)
	_shuffle(pool, rng)
	if feats["ice"]:
		var cnt := maxi(1, roundi(n * _ramp(id, int(Config.UNLOCK["ice"]), 0.10, 0.28, 60)))
		for i in pool:
			if ice.size() >= cnt:
				break
			ice[i] = true
			taken[i] = true
	if feats["chain"]:
		@warning_ignore("integer_division")
		var pairs := mini(4, 1 + (id - int(Config.UNLOCK["chain"])) / 20)
		var keys := {}
		for a in pool:
			if chain.size() >= pairs:
				break
			if taken.has(a):
				continue
			var ks: Array = []
			for k in order:
				if int(pos[k]) < int(pos[a]) and not keys.has(k) and not chain.has(k):
					ks.append(k)
			if ks.is_empty():
				continue
			var key: int = ks[rng.randi_range(0, ks.size() - 1)]
			chain[a] = key
			keys[key] = true
			taken[a] = true
	if feats["layer"]:
		@warning_ignore("integer_division")
		var cnt := mini(5, 1 + (id - int(Config.UNLOCK["layer"])) / 15)
		for i in pool:
			if layer.size() >= cnt:
				break
			if taken.has(i):
				continue
			var opts: Array = []
			for col in asg["clear"][i]:
				if col != int(asg["color"][i]):
					opts.append(col)
			if opts.is_empty():
				continue
			layer[i] = opts[rng.randi_range(0, opts.size() - 1)]
			taken[i] = true
	if feats["fog"]:
		var frac := _ramp(id, int(Config.UNLOCK["fog"]), 0.2, 0.5, 30)
		var cnt := maxi(1, roundi(n * frac))
		var all: Array = range(n)
		_shuffle(all, rng)
		for i in all:
			if fog.size() >= cnt:
				break
			fog[i] = true
	if feats["pulse"]:
		var sides := {}
		for i in n:
			sides[int(asg["color"][i])] = true
		var cols: Array = sides.keys()
		cols.sort()
		_shuffle(cols, rng)
		var want := 1 if id < 130 or cols.size() < 2 else 2
		for k in mini(want, cols.size()):
			var col: int = cols[k]
			var open := rng.randf() < 0.5
			if col == int(asg["color"][first]):
				open = true
			pulse.append({"side": LevelData.SIDES[col], "open": open})
	return {"ice": ice, "chain": chain, "layer": layer, "fog": fog, "pulse": pulse}


static func _build(id: int, s: int, hard: bool, w: int, h: int, stones: Array[Vector2i], groups: Array,
		asg: Dictionary, mech: Dictionary) -> Dictionary:
	var n := groups.size()
	# Đặt id theo vị trí (hàng rồi cột của ô đầu) để id không lộ thứ tự giải.
	var idx: Array = range(n)
	var first_cell := func(i: int) -> Vector2i:
		var best: Vector2i = groups[i][0]
		for c in groups[i]:
			if c.y < best.y or (c.y == best.y and c.x < best.x):
				best = c
		return best
	idx.sort_custom(func(a: int, b: int) -> bool:
		var ca: Vector2i = first_cell.call(a)
		var cb: Vector2i = first_cell.call(b)
		return ca.y < cb.y or (ca.y == cb.y and ca.x < cb.x))
	var name_of := {}
	for k in n:
		name_of[idx[k]] = "b%d" % (k + 1)
	var blocks: Array = []
	for i in idx:
		var cells: Array[Vector2i] = []
		cells.assign(groups[i])
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y or (a.y == b.y and a.x < b.x))
		var cl: Array = []
		for c in cells:
			cl.append([c.x, c.y])
		blocks.append({
			"id": name_of[i],
			"color": LevelData.COLORS[int(asg["color"][i])],
			"cells": cl,
			"ice": 1 if mech["ice"].has(i) else 0,
			"chained_by": name_of[mech["chain"][i]] if mech["chain"].has(i) else "",
			"inner_color": LevelData.COLORS[int(mech["layer"][i])] if mech["layer"].has(i) else "",
			"fog": mech["fog"].has(i),
		})
	var st: Array = []
	var sorted_stones := stones.duplicate()
	sorted_stones.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	for c in sorted_stones:
		st.append([c.x, c.y])
	return {
		"id": id, "w": w, "h": h, "hard": hard,
		"min_taps": 0, "moves": 0, "seed": s,
		"stones": st, "pulse_sides": mech["pulse"], "blocks": blocks,
	}
