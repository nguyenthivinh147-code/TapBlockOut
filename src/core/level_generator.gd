extends RefCounted
## Bộ sinh level (design.md mục 3-4, kế hoạch Task 9.1). Thuần: chỉ dùng RandomNumberGenerator có seed,
## cùng (id, seed) cho cùng level. Cách làm: chọn một hình (`Silhouette`) trong khung cục bộ, lát hình đó thành
## polyomino cỡ và hình bất kỳ (tự do hoặc đối xứng), rồi mô phỏng ván chơi tiến: mỗi bước chọn một khối còn có đường thoát và gán
## luôn màu (hướng) của nó theo đường đó, nên level luôn giải được. Sau đó rải cơ chế theo `Config.UNLOCK`, dịch
## hình vào giữa bàn cố định (ngoài hình là ô trống nên đường thoát không đổi), cuối cùng qua validate và Solver.
## Từ DifficultyCurve.SHAPED_FROM hình lấy từ bản vẽ tay (`Motifs`), không khoét rìa, và khối cắt đối xứng theo trục của
## hình (màu vẫn gán tự do); level dạy cơ chế (id = Config.UNLOCK) cũng sinh to như vậy, chỉ bật đúng cơ chế mới.
## Trường `seed` trong kết quả là seed thật đã dùng (sau khi sinh lại), generate(id, level.seed) cho đúng level đó.

const LevelData := preload("res://src/core/level_data.gd")
const Solver := preload("res://src/core/solver.gd")
const Config := preload("res://src/config.gd")
const BoardState := preload("res://src/core/board_state.gd")
const Silhouette := preload("res://src/core/silhouette.gd")
const Motifs := preload("res://src/core/motifs.gd")
const DifficultyCurve := preload("res://src/core/difficulty_curve.gd")

## Cắt khối đối xứng có thể lệch số khối mục tiêu tới 2.
const MAX_BLOCKS := DifficultyCurve.BOOST_MAX * DifficultyCurve.COUNT_SCALE + 2
## Khung lớn nhất của hình: 12x17, chừa một ô mỗi phía theo chiều ngang; chiều dọc giữ 17 hàng như khi lưới còn 19 hàng
## nên level sinh ra không đổi (BoardView co ô để hình cộng lề vừa lưới chuẩn).
const MAX_W := Config.BOARD_W - 2
const MAX_H := Config.BOARD_H - 1
const MAX_TRIES := 60
## Bàn có cổng nhịp: giữ ít khối để tìm được trạng thái cổng ban đầu không bắt chạm chờ. Từ GATE2_FROM bàn có tới 2
## cổng, khó tìm hơn nên trần thấp hơn (GATE2_MAX_BLOCKS) để sinh trong game vẫn nhanh.
const GATE_MAX_BLOCKS := 52
const GATE2_MAX_BLOCKS := 40
const GATE2_FROM := 130
## Bước nhảy trong Motifs.KINDS giữa hai level liền nhau (nguyên tố cùng nhau với số hình), để hình kế tiếp khác nhóm.
const MOTIF_STRIDE := 8
const MECHS := ["stone", "ice", "chain", "layer", "fog", "pulse"]
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
	for m in MECHS:
		if id >= int(Config.UNLOCK.get(m, 1 << 30)):
			out.append(m)
	return out


## Cơ chế mà level `id` dạy (id = Config.UNLOCK của cơ chế đó), hoặc "".
static func teach_mech(id: int) -> String:
	for m in MECHS:
		if int(Config.UNLOCK.get(m, -1)) == id:
			return m
	return ""


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


## Trần số khối của bàn có cổng nhịp ở level `id`.
static func _gate_max(id: int) -> int:
	return GATE2_MAX_BLOCKS if id >= GATE2_FROM else GATE_MAX_BLOCKS


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
	if id >= DifficultyCurve.SHAPED_FROM:
		return _attempt_motif(id, s, attempt)
	var rng := _rng(id, s)
	var feats := {}
	for m in MECHS:
		feats[m] = _enabled(id, m, rng, attempt)
	var n := _target_count(id, rng, attempt)
	if feats["pulse"]:
		n = mini(n, _gate_max(id))
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
	var shape := _pick_shape(n, n_stones, mirror, rng)
	if shape.is_empty():
		return {}
	var w: int = shape["w"]
	var h: int = shape["h"]
	var area := _roughen(shape["cells"], w, h, mirror, rng)
	var stones := _place_stones(area, w, h, n_stones, mirror, rng)
	var groups := _tile(area, w, h, stones, n, mirror, rng)
	if groups.is_empty():
		return {}
	return _finish(id, s, rng, feats, w, h, stones, groups, "")


## Từ DifficultyCurve.SHAPED_FROM: hình vẽ tay, đá và khối đối xứng theo trục của hình; level dạy chỉ bật cơ chế mới.
static func _attempt_motif(id: int, s: int, attempt: int) -> Dictionary:
	var rng := _rng(id, s)
	var teach := teach_mech(id)
	var feats := {}
	for m in MECHS:
		feats[m] = _enabled(id, m, rng, attempt)
		if teach != "":
			feats[m] = m == teach
	var n := _target_count(id, rng, attempt)
	if feats["pulse"]:
		n = mini(n, _gate_max(id))
	var n_stones := 0
	if feats["stone"]:
		@warning_ignore("integer_division")
		n_stones = mini(6, 1 + (id - int(Config.UNLOCK["stone"])) / 20 + rng.randi_range(0, 1))
	var shape := _pick_motif(id, s, n, n_stones, rng)
	if shape.is_empty():
		return {}
	var w: int = shape["w"]
	var h: int = shape["h"]
	var sym_h: bool = shape["sym_h"]
	var sym_v: bool = shape["sym_v"]
	var stones := _place_stones_sym(shape["cells"], w, h, n_stones, sym_h, sym_v, rng)
	var groups := _tile_sym(shape["cells"], w, h, stones, n, sym_h, sym_v, rng)
	if groups.is_empty():
		return {}
	return _finish(id, s, rng, feats, w, h, stones, groups, teach)


## Gán hướng, rải cơ chế, dịch vào giữa bàn, chọn trạng thái cổng, rồi qua validate và Solver. {} nếu hỏng.
## `teach`: cơ chế level này dạy ("" nếu không), level phải cho chạm thử cơ chế đó ngay lúc đầu.
static func _finish(id: int, s: int, rng: RandomNumberGenerator, feats: Dictionary, w: int, h: int,
		stones: Array[Vector2i], groups: Array, teach: String) -> Dictionary:
	var hard := is_hard(id)
	var asg := _assign(w, h, stones, groups, _allowed_colors(id), DifficultyCurve.blocked_power(id), rng)
	if asg.is_empty():
		return {}
	var mech := _mechanics(id, feats, groups.size(), asg, rng)
	var shift := _centering(groups, stones)
	var level := _build(id, s, hard, _shifted(stones, shift), _shifted_groups(groups, shift), asg, mech)
	if not mech["pulse"].is_empty() and not _fix_gates(level, rng, teach):
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
	if teach != "" and not _teach_ok(level, teach):
		return {}
	return level


## Thử các tổ hợp mở/đóng ban đầu của cổng, giữ tổ hợp đầu tiên mà không phải chạm chờ (solver chỉ tốn
## thời gian tìm chính xác khi phải chờ). false nếu không có tổ hợp nào như vậy. Level dạy cổng nhịp còn cần
## cổng đóng lúc đầu và có khối đang chờ cổng (`_teach_ok`).
static func _fix_gates(level: Dictionary, rng: RandomNumberGenerator, teach: String = "") -> bool:
	var sides: Array = level["pulse_sides"]
	var combos := 1 << sides.size()
	var start := rng.randi_range(0, combos - 1)
	for k in combos:
		var m := (start + k) % combos
		for i in sides.size():
			sides[i]["open"] = (m >> i) & 1 == 1
		if _no_wait(level) and (teach != "pulse" or _teach_ok(level, teach)):
			return true
	return false


## Level dạy có cho chạm thử cơ chế `mech` ngay lúc đầu không: Đá có ít nhất 2 viên; Băng có khối nứt được; Xích có khối
## bị xích mà chìa thoát được ngay và bỏ chìa thì khối đó đi được; Hai lớp có khối bóc được; Sương mù có khối ẩn màu;
## Cổng nhịp có cổng đóng và khối đang chờ cổng đó.
static func _teach_ok(level: Dictionary, mech: String) -> bool:
	var b := BoardState.new(level)
	b.add_moves(Solver.BIG_MOVES)
	match mech:
		"stone":
			return level["stones"].size() >= 2
		"ice", "layer":
			var want := "crack" if mech == "ice" else "peel"
			for bid in b.block_ids():
				if b.peek(bid) == want:
					return true
		"chain":
			for bid in b.block_ids():
				if b.peek(bid) != "chained":
					continue
				var key: String = b.block_view(bid)["chained_by"]
				if not b.can_exit(key):
					continue
				var c := b.clone()
				c.smash(key)
				if c.can_exit(bid):
					return true
		"fog":
			for bid in b.block_ids():
				if bool(b.block_view(bid)["is_fog_hidden"]):
					return true
		"pulse":
			if b.gate_open(str(level["pulse_sides"][0]["side"])):
				return false
			for bid in b.block_ids():
				if b.peek(bid) == "gate_closed":
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


## Chọn hình và khung: h >= w, số ô trống khoảng 2,4 đến 3,4 lần số khối. Trả {kind, w, h, cells}, {} nếu không có.
static func _pick_shape(n: int, n_stones: int, mirror: String, rng: RandomNumberGenerator) -> Dictionary:
	var kinds: Array = Silhouette.KINDS
	if n < Config.SHAPE_MIN_BLOCKS:
		kinds = [Silhouette.RECT]
	elif mirror == "v":
		kinds = Silhouette.V_SYMMETRIC
	var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
	var lo := 2.4
	var hi := 3.4
	for widen in 4:
		var cand: Array[Vector2i] = []
		for w in range(2, MAX_W + 1):
			for h in range(w, MAX_H + 1):
				if float(h) > Config.SHAPE_MAX_ASPECT * float(w) + 0.5:
					continue
				if mirror == "h" and w % 2 != 0:
					continue
				if mirror == "v" and h % 2 != 0:
					continue
				var free := Silhouette.cells(kind, w, h).size() - n_stones
				if free >= int(ceil(n * lo)) and free <= int(n * hi) and free >= n:
					cand.append(Vector2i(w, h))
		if not cand.is_empty():
			var size: Vector2i = cand[rng.randi_range(0, cand.size() - 1)]
			return {"kind": kind, "w": size.x, "h": size.y, "cells": Silhouette.cells(kind, size.x, size.y)}
		lo -= 0.3
		hi += 0.4
	return {}


## Khoét bớt vài ô rìa của hình (cả ô đối xứng nếu có), giữ hình liền một mảng.
static func _roughen(cells: Array[Vector2i], w: int, h: int, mirror: String, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var keep := {}
	for c in cells:
		keep[c] = true
	var want := roundi(cells.size() * Config.SHAPE_ROUGHEN)
	var edge: Array[Vector2i] = []
	for c in cells:
		for dv in NEIGHBORS:
			if not keep.has(c + dv):
				edge.append(c)
				break
	_shuffle(edge, rng)
	var removed := 0
	for c in edge:
		if removed >= want:
			break
		var pair: Array[Vector2i] = [c]
		if mirror != "":
			var m := _mirror_cell(c, w, h, mirror)
			if m != c:
				pair.append(m)
		for p in pair:
			keep.erase(p)
		if LevelData.connected(keep):
			removed += pair.size()
		else:
			for p in pair:
				keep[p] = true
	var out: Array[Vector2i] = []
	for c in cells:
		if keep.has(c):
			out.append(c)
	return out


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


static func _place_stones(area: Array[Vector2i], w: int, h: int, count: int, mirror: String, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for c in area:
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


## Lát các ô của hình (trừ đá) thành đúng `n` polyomino bằng cách gộp dần các ô đơn. Không giới hạn cỡ hay hình khối;
## mỗi cách gộp có trọng số 1 / cỡ khối sau gộp (`_merge_weight`) nên khối to vẫn ra nhưng hiếm khi thành mảng khổng lồ.
## Trả mảng các `Array[Vector2i]`, hoặc [] nếu kẹt.
static func _tile(area: Array[Vector2i], w: int, h: int, stones: Array[Vector2i], n: int, mirror: String,
		rng: RandomNumberGenerator) -> Array:
	var stone_set := {}
	for s in stones:
		stone_set[s] = true
	var cells: Array[Vector2i] = []
	for c in area:
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
					pairs.append([gi, gj])
					weights.append(_merge_weight(groups[gi].size() + groups[gj].size()))
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


## Trọng số của một cách gộp ra khối `size` ô: nghịch đảo cỡ, không có trần.
static func _merge_weight(size: int) -> float:
	return 1.0 / float(size)


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


## Chọn hình vẽ tay: thử lần lượt các hình trong Motifs.KINDS (bắt đầu theo id và seed, bước MOTIF_STRIDE để level
## liền nhau ra hình khác), lấy hình đầu tiên có cỡ vừa: số ô trừ đá chia `n` trong Config.MOTIF_FILL_MIN..MAX.
## Trong các cỡ và bản lật vừa thì chọn ngẫu nhiên. Trả một biến thể của Motifs.variants, {} nếu không hình nào vừa.
static func _pick_motif(id: int, s: int, n: int, n_stones: int, rng: RandomNumberGenerator) -> Dictionary:
	var kinds: Array = Motifs.KINDS
	var start := posmod(id * MOTIF_STRIDE + s, kinds.size())
	for k in kinds.size():
		var fit: Array = []
		for v in Motifs.variants(kinds[(start + k) % kinds.size()]):
			var per := float(v["cells"].size() - n_stones) / float(n)
			if per >= Config.MOTIF_FILL_MIN and per <= Config.MOTIF_FILL_MAX:
				fit.append(v)
		if not fit.is_empty():
			return fit[rng.randi_range(0, fit.size() - 1)]
	return {}


## Ô thuộc phần cơ sở của hình đối xứng: nửa trái (gồm cột giữa nếu rộng lẻ) khi `sym_h`, nửa trên khi `sym_v`.
static func _in_domain(c: Vector2i, w: int, h: int, sym_h: bool, sym_v: bool) -> bool:
	@warning_ignore("integer_division")
	return (not sym_h or c.x <= (w - 1) / 2) and (not sym_v or c.y <= (h - 1) / 2)


## Ảnh của ô `c` qua các phép lật được bật (gồm chính nó, không trùng).
static func _images(c: Vector2i, w: int, h: int, flip_h: bool, flip_v: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = [c]
	if flip_h:
		out.append(Vector2i(w - 1 - c.x, c.y))
	if flip_v:
		for i in out.size():
			out.append(Vector2i(out[i].x, h - 1 - out[i].y))
	var uniq: Array[Vector2i] = []
	for o in out:
		if not uniq.has(o):
			uniq.append(o)
	return uniq


## Đá đặt theo cả nhóm ảnh đối xứng của một ô để hình vẫn đối xứng; có thể nhiều hơn `count` tối đa 3 viên.
static func _place_stones_sym(area: Array[Vector2i], w: int, h: int, count: int, sym_h: bool, sym_v: bool,
		rng: RandomNumberGenerator) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for c in area:
		if _in_domain(c, w, h, sym_h, sym_v):
			cells.append(c)
	_shuffle(cells, rng)
	var out: Array[Vector2i] = []
	for c in cells:
		if out.size() >= count:
			break
		out.append_array(_images(c, w, h, sym_h, sym_v))
	return out


## Số khối một nhóm của phần cơ sở sinh ra trên cả hình: mỗi trục đối xứng mà nhóm chưa nối qua thì nhân đôi.
## Nhóm là [cells, nối qua trục dọc, nối qua trục ngang].
static func _copies(g: Array, sym_h: bool, sym_v: bool) -> int:
	return (2 if sym_h and not bool(g[1]) else 1) * (2 if sym_v and not bool(g[2]) else 1)


## Khối đầy đủ của một nhóm: các ô của nhóm cùng ảnh lật qua những trục mà nhóm nối qua.
static func _expand(cells: Array, joined_h: bool, joined_v: bool, w: int, h: int) -> Array[Vector2i]:
	var seen := {}
	var out: Array[Vector2i] = []
	for c: Vector2i in cells:
		for img in _images(c, w, h, joined_h, joined_v):
			if not seen.has(img):
				seen[img] = true
				out.append(img)
	return out


## Lát hình đối xứng thành khoảng `n` khối: chỉ lát phần cơ sở rồi lật ra, nên cách cắt khối cũng đối xứng. Nhóm chạm
## trục có thể nối với ảnh lật của nó thành một khối nằm vắt qua trục (cạnh lẻ thì ô trên trục bắt buộc nối). Gộp dần
## như `_tile` (không giới hạn cỡ khối, trọng số `_merge_weight`). Mỗi lần gộp bớt 1, 2 hoặc 4 khối nên số khối ra trong
## n-2..n+2. Trả mảng các `Array[Vector2i]` trên cả hình, hoặc [] nếu kẹt.
static func _tile_sym(area: Array[Vector2i], w: int, h: int, stones: Array[Vector2i], n: int, sym_h: bool,
		sym_v: bool, rng: RandomNumberGenerator) -> Array:
	var stone_set := {}
	for c in stones:
		stone_set[c] = true
	@warning_ignore("integer_division")
	var ax := (w - 1) / 2
	@warning_ignore("integer_division")
	var ay := (h - 1) / 2
	var owner := {}
	var groups := {}  # id -> [cells, nối trục dọc, nối trục ngang]
	var total := 0
	for c in area:
		if stone_set.has(c) or not _in_domain(c, w, h, sym_h, sym_v):
			continue
		var gi := groups.size()
		owner[c] = gi
		groups[gi] = [[c], sym_h and w % 2 == 1 and c.x == ax, sym_v and h % 2 == 1 and c.y == ay]
		total += _copies(groups[gi], sym_h, sym_v)
	while total > n:
		var opts: Array = []  # [gi, gj (-1: nối với ảnh lật), nối dọc, nối ngang, số khối bớt]
		var weights: Array[float] = []
		var under: Array = []  # các lần gộp làm số khối xuống dưới n
		for gi in groups:
			var g: Array = groups[gi]
			var at_x := false
			var at_y := false
			for c: Vector2i in g[0]:
				at_x = at_x or c.x == ax
				at_y = at_y or c.y == ay
				for dv in NEIGHBORS:
					var nb: Vector2i = c + dv
					if not owner.has(nb):
						continue
					var gj: int = owner[nb]
					if gj <= gi:
						continue
					var o: Array = groups[gj]
					_merge_option([gi, gj, bool(g[1]) or bool(o[1]), bool(g[2]) or bool(o[2])], g[0] + o[0],
						_copies(g, sym_h, sym_v) + _copies(o, sym_h, sym_v), total, n, w, h, sym_h, sym_v,
						opts, weights, under)
			var own := _copies(g, sym_h, sym_v)
			if sym_h and w % 2 == 0 and not bool(g[1]) and at_x:
				_merge_option([gi, -1, true, g[2]], g[0], own, total, n, w, h, sym_h, sym_v, opts, weights, under)
			if sym_v and h % 2 == 0 and not bool(g[2]) and at_y:
				_merge_option([gi, -1, g[1], true], g[0], own, total, n, w, h, sym_h, sym_v, opts, weights, under)
		var pick: Array = []
		if not opts.is_empty():
			pick = opts[_pick_weighted(weights, rng)]
		else:
			for u in under:
				if total - int(u[4]) >= n - 2 and (pick.is_empty() or int(u[4]) < int(pick[4])):
					pick = u
			if pick.is_empty():
				break
		var a: int = pick[0]
		var b: int = pick[1]
		if b >= 0:
			for c in groups[b][0]:
				owner[c] = a
				groups[a][0].append(c)
			groups.erase(b)
		groups[a][1] = pick[2]
		groups[a][2] = pick[3]
		total -= int(pick[4])
		if opts.is_empty():
			break
	if absi(total - n) > 2:
		return []
	var out: Array = []
	var keys := groups.keys()
	keys.sort()
	for k in keys:
		var g: Array = groups[k]
		var blocks: Array = [_expand(g[0], g[1], g[2], w, h)]
		if sym_h and not bool(g[1]):
			blocks.append(_flipped(blocks[0], w, h, true))
		if sym_v and not bool(g[2]):
			for i in blocks.size():
				blocks.append(_flipped(blocks[i], w, h, false))
		out.append_array(blocks)
	return out


## Ghi một cách gộp vào `opts` (kèm trọng số `_merge_weight` theo cỡ khối đầy đủ) nếu không làm số khối xuống dưới
## `n`; xuống dưới `n` thì ghi vào `under`. `opt`: [gi, gj, nối dọc, nối ngang]; `before`: số khối trước gộp.
static func _merge_option(opt: Array, cells: Array, before: int, total: int, n: int, w: int, h: int, sym_h: bool,
		sym_v: bool, opts: Array, weights: Array[float], under: Array) -> void:
	var cut := before - _copies([cells, opt[2], opt[3]], sym_h, sym_v)
	if cut <= 0:
		return
	var full: Array = opt + [cut]
	if total - cut >= n:
		opts.append(full)
		weights.append(_merge_weight(_expand(cells, opt[2], opt[3], w, h).size()))
	else:
		under.append(full)


static func _flipped(cells: Array[Vector2i], w: int, h: int, horizontal: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in cells:
		out.append(Vector2i(w - 1 - c.x, c.y) if horizontal else Vector2i(c.x, h - 1 - c.y))
	return out


## Mô phỏng ván tiến. Trả {order: Array[int], color: Array[int] (theo chỉ số nhóm),
## clear: Array (mỗi nhóm: các màu thoát được lúc nó bị chọn)}; {} nếu kẹt.
## `power`: số mũ của trọng số (1 + số khối chắn đường lúc đầu); càng lớn càng nhiều khối phải chờ lúc đầu.
static func _assign(w: int, h: int, stones: Array[Vector2i], groups: Array, allowed: Array[int],
		power: int, rng: RandomNumberGenerator) -> Dictionary:
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
						elif grid[gi] >= 0:
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
				var base := 1.0 + float(blockers[i * 4 + col])
				var wt := base
				for _p in power - 1:
					wt *= base
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
static func _mechanics(id: int, feats: Dictionary, n: int, asg: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
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
		var want := 1 if id < GATE2_FROM or cols.size() < 2 else 2
		for k in mini(want, cols.size()):
			var col: int = cols[k]
			var open := rng.randf() < 0.5
			if col == int(asg["color"][first]):
				open = true
			pulse.append({"side": LevelData.SIDES[col], "open": open})
	return {"ice": ice, "chain": chain, "layer": layer, "fog": fog, "pulse": pulse}


## Độ dời đưa hình (khối và đá) vào giữa bàn cố định.
static func _centering(groups: Array, stones: Array[Vector2i]) -> Vector2i:
	var mn := Vector2i(1 << 20, 1 << 20)
	var mx := Vector2i(-(1 << 20), -(1 << 20))
	var all: Array = stones.duplicate()
	for g in groups:
		all.append_array(g)
	for c: Vector2i in all:
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
		mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
	@warning_ignore("integer_division")
	return Vector2i((Config.BOARD_W - (mx.x - mn.x + 1)) / 2 - mn.x, (Config.BOARD_H - (mx.y - mn.y + 1)) / 2 - mn.y)


static func _shifted(cells: Array, shift: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in cells:
		out.append(c + shift)
	return out


static func _shifted_groups(groups: Array, shift: Vector2i) -> Array:
	var out: Array = []
	for g in groups:
		out.append(_shifted(g, shift))
	return out


static func _build(id: int, s: int, hard: bool, stones: Array[Vector2i], groups: Array,
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
		"id": id, "w": Config.BOARD_W, "h": Config.BOARD_H, "hard": hard,
		"min_taps": 0, "moves": 0, "seed": s,
		"stones": st, "pulse_sides": mech["pulse"], "blocks": blocks,
	}
