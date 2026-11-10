extends RefCounted
## Màn đặc biệt (design.md mục 7 "Màn đặc biệt"): bàn hình chữ nhật lát kín và bom. Logic thuần.
## - `generate(index, seed)`: bàn rộng Config.SPECIAL rect_w_*, cao rect_h_*, lát kín bằng khối 4 màu, không cơ chế, đặt
##   giữa lưới Config.BOARD_W x BOARD_H. Cắt và gán hướng bằng `LevelGenerator._tile` / `_assign` (cùng cách level chính
##   bảo đảm giải được); số lượt dọn bàn nhắm `rounds_share` x số khối. moves = số khối + dư (`slack`, đôi khi +1 / +2).
## - `bomb_plan(level, count, seed)`: chọn khối mang bom và số giây. "Số lần chạm để gỡ" một khối = số khối phải rời bàn
##   trước nó (cả chuỗi chặn, tính trên bàn đầy) + 1. Khoảng [bomb_min_taps, bomb_max_share x số khối] chia `count` tầng
##   đều nhau, mỗi tầng một khối. Bom xếp từ nông tới sâu; quả thứ k có `bomb_seconds(số khối khác nhau phải chạm để
##   gỡ hết quả 1..k)` giây, nên chạm 1 lần mỗi giây theo thứ tự đó luôn kịp (bàn tối đa 64 khối).
## - `urgent_hint(board, bombs)`: khối thoát được ngay nằm trong chuỗi chặn của quả bom gấp nhất.

const Config := preload("res://src/config.gd")
const LevelData := preload("res://src/core/level_data.gd")
const LevelGenerator := preload("res://src/core/level_generator.gd")
const Solver := preload("res://src/core/solver.gd")
const BoardState := preload("res://src/core/board_state.gd")

const PATH := "res://data/special/sp_%04d.json"
const TRIES := 40
const ASSIGN_TRIES := 12
## Seed riêng để bàn Special không trùng rng của level chính cùng số.
const ID_SALT := 700000


static func path_of(index: int) -> String:
	return PATH % index


## Bàn thứ `index` (1-based) với seed cơ sở `seed_value`, hoặc {} nếu mọi lần thử đều hỏng.
static func generate(index: int, seed_value: int) -> Dictionary:
	for attempt in TRIES:
		var lvl := _attempt(index, seed_value + attempt)
		if not lvl.is_empty():
			return lvl
	return {}


static func _attempt(index: int, s: int) -> Dictionary:
	var sp: Dictionary = Config.SPECIAL
	var rng := LevelGenerator._rng(ID_SALT + index, s)
	var w := rng.randi_range(int(sp.rect_w_min), int(sp.rect_w_max))
	var h := rng.randi_range(int(sp.rect_h_min), int(sp.rect_h_max))
	var area: Array[Vector2i] = []
	for y in h:
		for x in w:
			area.append(Vector2i(x, y))
	var per := rng.randf_range(float(sp.cells_per_block_min), float(sp.cells_per_block_max))
	var n := roundi(float(area.size()) / per)
	var no_stones: Array[Vector2i] = []
	var groups := LevelGenerator._tile(area, w, h, no_stones, n, "", rng)
	if groups.is_empty():
		return {}
	var want := maxi(1, roundi(groups.size() * float(sp.rounds_share)))
	var tol := maxi(Config.LEVEL_ROUNDS_TOL_MIN, roundi(want * Config.LEVEL_ROUNDS_TOL))
	var colors: Array[int] = [0, 1, 2, 3]
	var aim := want
	var best := {}
	var best_err := 1 << 20
	for _k in ASSIGN_TRIES:
		var asg := LevelGenerator._assign(w, h, no_stones, groups, colors, int(sp.blocked_power), rng, aim)
		if asg.is_empty():
			return {}
		var depth: int = asg["depth"]
		if absi(depth - want) < best_err:
			best = asg
			best_err = absi(depth - want)
		if best_err <= tol:
			break
		aim = clampi(aim + want - depth, 1, groups.size())
	if best_err > tol:
		return {}
	var level := _build(index, s, w, h, groups, best, rng)
	if not LevelData.validate(level).is_empty():
		return {}
	var r := Solver.solve(level)
	if not bool(r.get("ok", false)) or int(r["min_taps"]) != groups.size():
		return {}
	level["rounds"] = Solver.clear_rounds(level)
	return level


static func _build(index: int, s: int, w: int, h: int, groups: Array, asg: Dictionary,
		rng: RandomNumberGenerator) -> Dictionary:
	var sp: Dictionary = Config.SPECIAL
	@warning_ignore("integer_division")
	var shift := Vector2i((Config.BOARD_W - w) / 2, (Config.BOARD_H - h) / 2)
	var n := groups.size()
	var first := func(i: int) -> Vector2i:
		var best: Vector2i = groups[i][0]
		for c: Vector2i in groups[i]:
			if c.y < best.y or (c.y == best.y and c.x < best.x):
				best = c
		return best
	var idx: Array = range(n)
	idx.sort_custom(func(a: int, b: int) -> bool:
		var ca: Vector2i = first.call(a)
		var cb: Vector2i = first.call(b)
		return ca.y < cb.y or (ca.y == cb.y and ca.x < cb.x))
	var blocks: Array = []
	for k in n:
		var i: int = idx[k]
		var cells: Array[Vector2i] = []
		cells.assign(groups[i])
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y or (a.y == b.y and a.x < b.x))
		var cl: Array = []
		for c in cells:
			cl.append([c.x + shift.x, c.y + shift.y])
		blocks.append({"id": "b%d" % (k + 1), "color": LevelData.COLORS[int(asg["color"][i])], "cells": cl,
			"ice": 0, "chained_by": "", "inner_color": "", "fog": false})
	var roll := rng.randf()
	var slack := int(sp.slack)
	if roll < float(sp.slack_plus2_share):
		slack += 2
	elif roll < float(sp.slack_plus2_share) + float(sp.slack_plus1_share):
		slack += 1
	return {
		"id": index, "w": Config.BOARD_W, "h": Config.BOARD_H, "hard": false, "seed": s, "special": true,
		"rect": [shift.x, shift.y, w, h], "min_taps": n, "moves": n + slack, "stones": [], "pulse_sides": [],
		"blocks": blocks,
	}


## {id: {cells: Array[Vector2i], dir: Vector2i}} của các khối trong `level` (dữ liệu file).
static func _shape_of_level(level: Dictionary) -> Dictionary:
	var out := {}
	for b in level.get("blocks", []):
		var cells: Array[Vector2i] = []
		for raw in b.get("cells", []):
			cells.append(LevelData.cell_of(raw))
		out[str(b.get("id", ""))] = {"cells": cells, "dir": LevelData.side_dir(LevelData.block_side(b))}
	return out


## Như `_shape_of_level` nhưng chỉ các khối còn trên `board`.
static func _shape_of_board(board: BoardState) -> Dictionary:
	var out := {}
	for id in board.block_ids():
		var v := board.block_view(id)
		var cells: Array[Vector2i] = []
		cells.assign(v["cells"])
		out[id] = {"cells": cells, "dir": LevelData.side_dir(str(v["dir"]))}
	return out


## Khối chặn trực tiếp: id -> {id khối nằm trên đường ra: true}.
static func _blockers(shape: Dictionary, w: int, h: int) -> Dictionary:
	var owner := {}
	for id in shape:
		for c: Vector2i in shape[id]["cells"]:
			owner[c] = id
	var out := {}
	for id in shape:
		var d: Vector2i = shape[id]["dir"]
		var set := {}
		for c: Vector2i in shape[id]["cells"]:
			var q := c + d
			while q.x >= 0 and q.y >= 0 and q.x < w and q.y < h:
				var o: Variant = owner.get(q)
				if o != null and o != id:
					set[o] = true
				q += d
		out[id] = set
	return out


## Mọi khối phải rời bàn trước `id` (đệ quy theo khối chặn), không gồm chính nó.
static func _closure(blockers: Dictionary, id: String) -> Dictionary:
	var seen := {}
	var stack: Array = blockers[id].keys()
	while not stack.is_empty():
		var k: String = stack.pop_back()
		if seen.has(k) or k == id:
			continue
		seen[k] = true
		stack.append_array(blockers[k].keys())
	return seen


## Số lần chạm để gỡ từng khối trên bàn đầy: id -> số khối trong chuỗi chặn + 1.
static func taps_to_free(level: Dictionary) -> Dictionary:
	var shape := _shape_of_level(level)
	var bl := _blockers(shape, int(level.w), int(level.h))
	var out := {}
	for id in shape:
		out[id] = _closure(bl, id).size() + 1
	return out


## Ô đặt bom: ô của khối gần trọng tâm khối nhất (trùng khoảng cách thì ô đầu theo hàng rồi cột).
static func bomb_cell(cells: Array) -> Vector2i:
	var sum := Vector2.ZERO
	for raw in cells:
		sum += Vector2(LevelData.cell_of(raw))
	var mid := sum / float(maxi(cells.size(), 1))
	var best := LevelData.cell_of(cells[0])
	var best_d := INF
	for raw in cells:
		var c := LevelData.cell_of(raw)
		var dd := Vector2(c).distance_squared_to(mid)
		if dd < best_d - 0.0001 or (absf(dd - best_d) <= 0.0001 and (c.y < best.y or (c.y == best.y and c.x < best.x))):
			best = c
			best_d = dd
	return best


## Số bom khi đã thắng `wins` trận Special: bombs_start + wins / bombs_every, tối đa bombs_max.
static func bomb_count(wins: int) -> int:
	var sp: Dictionary = Config.SPECIAL
	@warning_ignore("integer_division")
	var n := int(sp.bombs_start) + maxi(wins, 0) / maxi(int(sp.bombs_every), 1)
	return mini(n, int(sp.bombs_max))


## Số giây của quả bom khi phải chạm `need` khối khác nhau: bomb_time_share x (bomb_base_sec + bomb_sec_per_tap x need),
## làm tròn lên (trừ một chút để sai số float không đẩy số chẵn lên thêm 1 giây).
static func bomb_seconds(need: int) -> int:
	var sp: Dictionary = Config.SPECIAL
	var raw := float(sp.bomb_time_share) * (float(sp.bomb_base_sec) + float(sp.bomb_sec_per_tap) * need)
	return ceili(raw - 0.001)


## Bom của bàn: [{id, cell: Vector2i, taps, seconds}] xếp theo số giây tăng dần. Ít khối hợp lệ hơn `count` thì ít bom
## hơn. Cùng (level, count, seed) cho cùng kết quả.
static func bomb_plan(level: Dictionary, count: int, seed_value: int) -> Array[Dictionary]:
	var sp: Dictionary = Config.SPECIAL
	var out: Array[Dictionary] = []
	if count <= 0:
		return out
	var shape := _shape_of_level(level)
	var bl := _blockers(shape, int(level.w), int(level.h))
	var n := shape.size()
	var lo := int(sp.bomb_min_taps)
	var hi := maxi(lo, floori(n * float(sp.bomb_max_share)))
	var taps := {}
	var cands: Array[String] = []
	for b in level.get("blocks", []):
		var id := str(b.id)
		var t := _closure(bl, id).size() + 1
		taps[id] = t
		if t >= lo and t <= hi:
			cands.append(id)
	var k := mini(count, cands.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = LevelGenerator._mix(seed_value * 2654435761 + int(level.get("id", 0)) * 40503 + k)
	var picked: Array[String] = []
	var span := hi - lo + 1
	for band in k:
		@warning_ignore("integer_division")
		var b_lo := lo + span * band / k
		@warning_ignore("integer_division")
		var b_hi := lo + span * (band + 1) / k - 1
		var pool: Array[String] = []
		for id in cands:
			if not picked.has(id) and int(taps[id]) >= b_lo and int(taps[id]) <= b_hi:
				pool.append(id)
		if pool.is_empty():
			# Tầng trống: lấy khối chưa chọn gần giữa tầng nhất.
			var mid := (b_lo + b_hi) / 2.0
			var best := ""
			for id in cands:
				if not picked.has(id) and (best == "" or absf(taps[id] - mid) < absf(taps[best] - mid)):
					best = id
			if best == "":
				break
			pool.append(best)
		picked.append(pool[rng.randi_range(0, pool.size() - 1)])
	picked.sort_custom(func(a: String, b: String) -> bool:
		return int(taps[a]) < int(taps[b]) or (int(taps[a]) == int(taps[b]) and a < b))
	var union := {}
	for id in picked:
		union.merge(_closure(bl, id))
		union[id] = true
		out.append({"id": id, "cell": bomb_cell(shape[id]["cells"]), "taps": int(taps[id]),
			"seconds": bomb_seconds(union.size())})
	return out


## Gợi ý của Màn đặc biệt: theo thứ tự `bombs` (id khối bom còn đếm, gấp nhất trước), khối thoát được ngay nằm trong
## chuỗi chặn của quả đầu tiên có khối như vậy (chính khối bom nếu nó đi được). "" nếu không có: dùng `board.hint()`.
static func urgent_hint(board: BoardState, bombs: Array) -> String:
	if board.is_won():
		return ""
	var shape := _shape_of_board(board)
	var bl := _blockers(shape, board.width(), board.height())
	for bid in bombs:
		if not shape.has(bid):
			continue
		if board.can_exit(bid):
			return bid
		var cl := _closure(bl, bid)
		var ids: Array = cl.keys()
		ids.sort()
		for id in ids:
			if board.can_exit(id):
				return id
	return ""
