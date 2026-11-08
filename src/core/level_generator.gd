extends RefCounted
## Bộ sinh level (design.md mục 3-4, kế hoạch Task 9.1). Thuần: chỉ dùng RandomNumberGenerator có seed,
## cùng (id, seed) cho cùng level. Cách làm: chọn một hình (`Silhouette`) trong khung cục bộ, lát hình đó thành
## polyomino cỡ và hình bất kỳ (tự do hoặc đối xứng), rồi mô phỏng ván chơi tiến: mỗi bước chọn một khối còn có đường thoát và gán
## luôn màu (hướng) của nó theo đường đó, nên level luôn giải được; lúc gán, độ sâu chuỗi chặn được lái về số lượt
## dọn bàn của đường cong (`DifficultyCurve.wave_count`, đo bằng `Solver.clear_rounds` sau khi rải cơ chế). Sau đó
## rải cơ chế theo `mech_plan` (tối đa Config.LEVEL_MECH_MAX loại, có level nghỉ không cơ chế), dịch
## hình vào giữa bàn cố định (ngoài hình là ô trống nên đường thoát không đổi), cuối cùng qua validate và Solver.
## Từ DifficultyCurve.MOTIF_FROM hình lấy từ bản vẽ tay (`Motifs`), không khoét rìa, và khối cắt đối xứng theo trục của
## hình (màu vẫn gán tự do), mỗi khối tối đa Config.BLOCK_MAX_CELLS ô, theo một trong ba kiểu (`cut_style`): đối xứng tự
## do, hình học (dải, vòng, đan, gạch) hoặc theo vùng vẽ trong bản vẽ. Level dạy cơ chế (id = Config.UNLOCK) cũng sinh
## như vậy, chỉ bật đúng cơ chế mới.
## Trường `seed` trong kết quả là seed thật đã dùng (sau khi sinh lại). generate(id, level.seed) cho đúng level đó nếu
## level sinh được trước lần thử thứ COUNT_RELAX_EVERY; từ lần đó bộ sinh bớt khối mục tiêu nên lần chạy lại khác đi.

const LevelData := preload("res://src/core/level_data.gd")
const Solver := preload("res://src/core/solver.gd")
const Config := preload("res://src/config.gd")
const BoardState := preload("res://src/core/board_state.gd")
const Silhouette := preload("res://src/core/silhouette.gd")
const Motifs := preload("res://src/core/motifs.gd")
const DifficultyCurve := preload("res://src/core/difficulty_curve.gd")

## Cắt khối đối xứng có thể lệch số khối mục tiêu tới 2.
const MAX_BLOCKS := DifficultyCurve.BLOCK_CAP + 3
## Khung lớn nhất của hình: 12x17, chừa một ô mỗi phía theo chiều ngang; chiều dọc giữ 17 hàng như khi lưới còn 19 hàng
## nên level sinh ra không đổi (BoardView co ô để hình cộng lề vừa lưới chuẩn).
const MAX_W := Config.BOARD_W - 2
const MAX_H := Config.BOARD_H - 1
const MAX_TRIES := 60
## Cứ mỗi COUNT_RELAX_EVERY lần thử hỏng thì bớt 1 khối mục tiêu (`_target_count`).
const COUNT_RELAX_EVERY := 20
## Bàn có cổng nhịp giữ ít khối (mỗi khối qua cổng khoá tốn thêm một cú dội), nên `mech_plan` chỉ cho cổng nhịp vào
## level có số khối mục tiêu tới GATE_MAX_BLOCKS. Từ GATE2_FROM bàn tới GATE2_MAX_BLOCKS khối có 2 cổng.
const GATE_MAX_BLOCKS := 52
const GATE2_MAX_BLOCKS := 40
const GATE2_FROM := 130
## Lần thử từ MECH_DROP_AT bỏ mọi cơ chế, từ GATE_DROP_AT bỏ cổng nhịp (trừ level dạy).
const MECH_DROP_AT := 40
const GATE_DROP_AT := 24
## Seed riêng của `mech_plan` (chỉ theo id, không theo seed của lần sinh).
const PLAN_SEED := 977
## `_finish`: gán hướng lại tối đa ASSIGN_TRIES lần để số lượt dọn bàn vào khoảng của đường cong, bỏ cách cắt khi
## ROUNDS_STALL lần liền không sâu thêm; cứ ROUNDS_RELAX_EVERY lần thử hỏng thì nới khoảng đó thêm 1.
const ASSIGN_TRIES := 8
## Chế độ sinh trong game (`strict_rounds` false) chỉ gán FAST_ASSIGN_TRIES lần rồi giữ bàn gần nhất.
const FAST_ASSIGN_TRIES := 3
const ROUNDS_STALL := 2
const ROUNDS_RELAX_EVERY := 5
## `_assign`: khi chuỗi chặn sâu nhất còn nông hơn mục tiêu, trọng số mỗi cách gán nhân DEPTH_PUSH ^ (độ sâu của nó trừ
## độ sâu lớn nhất) nên khối nằm sâu được ưu tiên, còn khối thoát được ngay từ đầu nhân DEPTH_FREE để vẫn còn vài khối đi
## được lúc đầu; khi đã đủ sâu thì cách gán làm chuỗi sâu thêm nhân DEPTH_HOLD.
const DEPTH_PUSH := 2.0
const DEPTH_HOLD := 0.05
const DEPTH_FREE := 0.3
## `_attempt_motif`: đặt lại thùng sắt và cắt lại tối đa STONE_TRIES lần khi có khối bị thùng chắn cả bốn hướng.
const STONE_TRIES := 3
## Bước nhảy trong Motifs.KINDS giữa hai level liền nhau (nguyên tố cùng nhau với số hình), để hình kế tiếp khác nhóm.
const MOTIF_STRIDE := 8
const MECHS := ["stone", "ice", "chain", "layer", "fog", "pulse"]
const NEIGHBORS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Kiểu cắt khối theo hình học (`cut_style`): "rows" dải ngang, "cols" dải dọc, "rings" vòng theo viền hình,
## "weave" đan rổ (ô WEAVE_TILE x WEAVE_TILE, dải ngang và dọc xen kẽ), "bricks" gạch xây so le dài BRICK_LEN.
const GEO_STYLES := ["rows", "rings", "weave", "cols", "bricks"]
const WEAVE_TILE := 4
## `_tile_sym`: mỗi lần quét các cách gộp chọn tới 1/TILE_BATCH số lần gộp còn lại.
const TILE_BATCH := 4
const BRICK_LEN := 4


## Level hợp lệ cho (id, seed), hoặc {} nếu mọi lần thử đều hỏng (không xảy ra trong thực tế).
## `strict_rounds` false (Daily Challenge, sinh trong game): vẫn gán hướng lại để số lượt gần đường cong, nhưng giữ bàn
## gần nhất thay vì cắt lại hay sinh lại, nên nhanh gần như khi chưa có mục tiêu số lượt.
static func generate(id: int, seed_value: int, strict_rounds: bool = true) -> Dictionary:
	for attempt in MAX_TRIES:
		var lvl := _attempt(id, seed_value + attempt, attempt, strict_rounds)
		if not lvl.is_empty():
			return lvl
	return {}


## Cơ chế đã mở ở level này (theo Config.UNLOCK). Dùng cho test và công cụ.
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


## Level nghỉ: từ level mở cơ chế đầu tiên, cứ Config.LEVEL_REST_EVERY level có một level không cơ chế nào (level dạy
## vẫn có cơ chế của nó).
static func is_rest(id: int) -> bool:
	return posmod(id, Config.LEVEL_REST_EVERY) == Config.LEVEL_REST_AT and teach_mech(id) == ""


## Cơ chế của level `id`, theo id (không theo seed): level dạy chỉ có cơ chế mới; chưa mở cơ chế nào hoặc level nghỉ thì
## không có; level khác rút 1..Config.LEVEL_MECH_MAX loại trong các cơ chế đã mở theo Config.LEVEL_MECH_WEIGHTS, và cơ
## chế vừa mở (trong Config.LEVEL_MECH_FRESH level sau level dạy) luôn có mặt. Cổng nhịp chỉ ở level có số khối mục tiêu
## tới GATE_MAX_BLOCKS.
static func mech_plan(id: int) -> Array[String]:
	var out: Array[String] = []
	var teach := teach_mech(id)
	if teach != "":
		out.append(teach)
		return out
	var open := mechanics_for(id)
	if open.is_empty() or is_rest(id):
		return out
	var rng := _rng(id, PLAN_SEED)
	var weights: Array[float] = []
	weights.assign(Config.LEVEL_MECH_WEIGHTS)
	var want := _pick_weighted(weights, rng) + 1
	var pool: Array[String] = []
	var fresh := ""
	var fresh_at := -1
	for m in open:
		if m == "pulse" and DifficultyCurve.block_count(id) > GATE_MAX_BLOCKS:
			continue
		pool.append(m)
		var u := int(Config.UNLOCK[m])
		if id <= u + Config.LEVEL_MECH_FRESH and u > fresh_at:
			fresh = m
			fresh_at = u
	_shuffle(pool, rng)
	if fresh != "":
		pool.erase(fresh)
		pool.push_front(fresh)
	for m in pool.slice(0, mini(want, Config.LEVEL_MECH_MAX)):
		out.append(m)
	return out


## Cơ chế bật ở lần thử `attempt`: theo `mech_plan`, bỏ hết từ lần MECH_DROP_AT và bỏ cổng nhịp từ lần GATE_DROP_AT;
## level dạy luôn giữ cơ chế của nó.
static func _features(id: int, attempt: int) -> Dictionary:
	var plan := mech_plan(id)
	var teach := teach_mech(id)
	var feats := {}
	for m in MECHS:
		var keep: bool = attempt < MECH_DROP_AT and (m != "pulse" or attempt < GATE_DROP_AT)
		feats[m] = plan.has(m) and (keep or m == teach)
	return feats


## Khoảng lệch cho phép của số lượt dọn bàn so với `want`, nới dần theo số lần thử hỏng.
static func _rounds_tol(want: int, attempt: int) -> int:
	@warning_ignore("integer_division")
	return maxi(Config.LEVEL_ROUNDS_TOL_MIN, roundi(want * Config.LEVEL_ROUNDS_TOL)) + attempt / ROUNDS_RELAX_EVERY


## Kiểu cắt khối của level `id` (từ DifficultyCurve.MOTIF_FROM), xen kẽ theo id: "sym" (gộp tự do, đối xứng theo trục của
## hình), một kiểu hình học trong GEO_STYLES, hoặc "template" (chỉ gộp ô cùng vùng vẽ trong bản vẽ).
static func cut_style(id: int) -> String:
	match posmod(id, 3):
		0:
			return "sym"
		1:
			@warning_ignore("integer_division")
			return GEO_STYLES[posmod(id / 3, GEO_STYLES.size())]
	return "template"


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
	return maxi(2, DifficultyCurve.block_count(id) - attempt / COUNT_RELAX_EVERY)


static func _ramp(id: int, unlock: int, lo: float, hi: float, over: int) -> float:
	return lerpf(lo, hi, clampf(float(id - unlock) / float(over), 0.0, 1.0))


static func _attempt(id: int, s: int, attempt: int, strict: bool = true) -> Dictionary:
	if id >= DifficultyCurve.MOTIF_FROM:
		return _attempt_motif(id, s, attempt, strict)
	var rng := _rng(id, s)
	var feats := _features(id, attempt)
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
	return _finish(id, s, rng, feats, w, h, stones, groups, "", attempt, strict)


## Từ DifficultyCurve.MOTIF_FROM: hình vẽ tay, đá và khối đối xứng theo trục của hình, cắt theo `cut_style(id)`; level
## dạy chỉ bật cơ chế mới.
static func _attempt_motif(id: int, s: int, attempt: int, strict: bool = true) -> Dictionary:
	var rng := _rng(id, s)
	var teach := teach_mech(id)
	var feats := _features(id, attempt)
	var n := _target_count(id, rng, attempt)
	if feats["pulse"]:
		n = mini(n, GATE_MAX_BLOCKS)
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
	# Thùng sắt chắn cả bốn hướng của một khối thì khối đó không bao giờ ra được: đặt lại thùng và cắt lại (rẻ hơn hỏng
	# cả lần thử ở bước gán hướng).
	var stones: Array[Vector2i] = []
	var groups: Array = []
	for _try in STONE_TRIES:
		stones = _place_stones_sym(shape["cells"], w, h, n_stones, sym_h, sym_v, rng)
		groups = _tile_sym(shape["cells"], w, h, stones, n, sym_h, sym_v, rng, cut_style(id), shape["regions"])
		if not groups.is_empty() and (stones.is_empty() or not _stone_dead(groups, stones, w, h)):
			break
	if groups.is_empty():
		return {}
	return _finish(id, s, rng, feats, w, h, stones, groups, teach, attempt, strict)


## Có khối nào mà đường ra theo cả bốn hướng đều gặp thùng sắt không (khối đó không bao giờ ra được).
static func _stone_dead(groups: Array, stones: Array[Vector2i], w: int, h: int) -> bool:
	var stone_set := {}
	for c in stones:
		stone_set[c] = true
	for g in groups:
		var own := {}
		for c in g:
			own[c] = true
		var blocked := 0
		for d in NEIGHBORS:
			var hit := false
			for c: Vector2i in g:
				var q: Vector2i = c + d
				while not hit and q.x >= 0 and q.y >= 0 and q.x < w and q.y < h:
					hit = stone_set.has(q)
					q += d
				if hit:
					break
			blocked += int(hit)
		if blocked == 4:
			return true
	return false


## Gán hướng, rải cơ chế, dịch vào giữa bàn, chọn trạng thái cổng, rồi qua validate và Solver. {} nếu hỏng.
## Số lượt dọn bàn (`Solver.clear_rounds`) phải lệch đường cong tối đa `_rounds_tol`: lệch thì gán hướng lại với độ sâu
## mục tiêu bù phần lệch, tối đa ASSIGN_TRIES lần; ROUNDS_STALL lần liền không sâu thêm thì bỏ cách cắt này. Bàn chỉ có
## thùng sắt thì số lượt bằng độ sâu lúc gán hướng nên không cần mô phỏng; pudding, xích, hộp giấy, sương mù chỉ làm
## chuỗi dài thêm nên độ sâu đã quá mục tiêu thì gán lại luôn. Sương mù rải xong qua `_fog_fix` để bàn không kẹt.
## `teach`: cơ chế level này dạy ("" nếu không), level phải cho chạm thử cơ chế đó ngay lúc đầu.
static func _finish(id: int, s: int, rng: RandomNumberGenerator, feats: Dictionary, w: int, h: int,
		stones: Array[Vector2i], groups: Array, teach: String, attempt: int, strict: bool = true) -> Dictionary:
	var hard := is_hard(id)
	var want := DifficultyCurve.wave_count(id)
	var tol := _rounds_tol(want, attempt)
	var aim := want
	var shift := _centering(groups, stones)
	var plain: bool = not (feats["ice"] or feats["chain"] or feats["layer"] or feats["fog"] or feats["pulse"])
	var level := {}
	var near := {}  # bàn có số lượt gần nhất (giữ khi không `strict`)
	var near_err := 1 << 20
	var low := -1
	var stall := 0
	var tries := ASSIGN_TRIES if strict else FAST_ASSIGN_TRIES
	for _k in tries:
		var asg := _assign(w, h, stones, groups, _allowed_colors(id), DifficultyCurve.blocked_power(id), rng, aim)
		if asg.is_empty():
			return {}
		var rounds: int = asg["depth"]
		if not strict or absi(rounds - want) <= tol or (not plain and (feats["pulse"] or rounds < want)):
			var mech := _mechanics(id, feats, groups.size(), asg, rng)
			var cand := _build(id, s, hard, _shifted(stones, shift), _shifted_groups(groups, shift), asg, mech)
			if not mech["fog"].is_empty():
				_fog_fix(cand)
			# Cổng nhịp khoá có thể chặn hết khối đi được lúc đầu (cú dội không tính); level dạy cổng cần khối dội vào được ngay.
			if not mech["pulse"].is_empty():
				if not Solver.immediate_exit_exists(cand) or (teach == "pulse" and not _teach_ok(cand, teach)):
					continue
			if not plain:
				rounds = Solver.clear_rounds(cand)
				if rounds < 0:
					continue
			if absi(rounds - want) <= tol:
				level = cand
				break
			if absi(rounds - want) < near_err:
				near = cand
				near_err = absi(rounds - want)
		if rounds < want:
			stall = stall + 1 if rounds <= low else 0
			low = maxi(low, rounds)
			if stall >= ROUNDS_STALL:
				break
		aim = clampi(aim + want - rounds, 1, groups.size())
	if level.is_empty() and not strict:
		level = near
	if level.is_empty():
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


## Khối còn trong sương không đi được và chỉ lộ khi khối kề rời đi, nên sương rải ngẫu nhiên có thể làm bàn kẹt (khối
## thường chờ khối sương, khối sương chờ khối thường). Đi tham lam như Solver; mỗi lần kẹt thì bỏ sương của khối ẩn đầu
## tiên (theo thứ tự khối) sẽ đi được nếu lộ, tới khi dọn hết bàn hoặc không còn khối như vậy (bàn kẹt vì lý do khác,
## Solver loại sau). Khối thấy sớm hơn chỉ mở thêm nước đi nên bàn đã sửa vẫn giải được. Không dùng rng.
static func _fog_fix(level: Dictionary) -> void:
	var b := BoardState.new(level)
	b.add_moves(Solver.BIG_MOVES)
	var lifted := {}
	var guard := 0
	while not b.is_won() and guard < Solver.GUARD:
		guard += 1
		var pick := Solver.pick_tap(b)
		if pick != "":
			b.tap(pick)
			continue
		var lift := ""
		for bid in b.block_ids():
			if not bool(b.block_view(bid)["is_fog_hidden"]):
				continue
			var c := b.clone()
			c.reveal(bid)
			if Solver.RANK.has(c.peek(bid)):
				lift = bid
				break
		if lift == "":
			break
		b.reveal(lift)
		lifted[lift] = true
	for bd in level["blocks"]:
		if lifted.has(str(bd["id"])):
			bd["fog"] = false


## Level dạy có cho chạm thử cơ chế `mech` ngay lúc đầu không: Đá có ít nhất 2 viên; Băng có khối nứt được; Xích có khối
## bị xích mà chìa thoát được ngay và bỏ chìa thì khối đó đi được; Hai lớp có khối bóc được; Sương mù có khối ẩn màu;
## Cổng nhịp có cổng khoá lúc đầu và khối dội vào được cổng đó ngay.
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


## Lát các ô của hình (trừ đá) thành đúng `n` polyomino bằng cách gộp dần các ô đơn, mỗi khối tối đa
## Config.BLOCK_MAX_CELLS ô; trọng số mỗi cách gộp theo `_merge_weight` (ưu tiên gộp khối 1 ô).
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
					var na: int = groups[gi].size()
					var nb_size: int = groups[gj].size()
					if na + nb_size > Config.BLOCK_MAX_CELLS:
						continue
					pairs.append([gi, gj])
					weights.append(_merge_weight(na + nb_size, int(na == 1) + int(nb_size == 1)))
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


## Trọng số của một cách gộp ra khối `size` ô, trong đó `singles` (0-2) khối gộp vào là khối 1 ô:
## Config.TILE_SINGLE_BIAS ^ singles / size. Hệ số làm khối 1 ô được gộp trước nên còn ít khối 1 ô.
static func _merge_weight(size: int, singles: int) -> float:
	return pow(Config.TILE_SINGLE_BIAS, singles) / float(size * size)


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
## như `_tile`: mỗi khối tối đa Config.BLOCK_MAX_CELLS ô, trọng số `_merge_weight`. `style` (`cut_style`) chỉ cho gộp qua
## những cạnh hợp kiểu (`_edge_ok`); khi không còn cách gộp hợp kiểu mà số khối còn nhiều hơn `n` thì gộp tự do.
## `regions`: ô -> tên vùng trong bản vẽ (kiểu "template"). Mỗi lần gộp bớt 1, 2 hoặc 4 khối nên số khối ra trong
## n-2..n+2. Trả mảng các `Array[Vector2i]` trên cả hình, hoặc [] nếu kẹt.
static func _tile_sym(area: Array[Vector2i], w: int, h: int, stones: Array[Vector2i], n: int, sym_h: bool,
		sym_v: bool, rng: RandomNumberGenerator, style: String = "sym", regions: Dictionary = {}) -> Array:
	var stone_set := {}
	for c in stones:
		stone_set[c] = true
	@warning_ignore("integer_division")
	var ax := (w - 1) / 2
	@warning_ignore("integer_division")
	var ay := (h - 1) / 2
	var ctx := {"style": style, "w": w, "h": h, "sym_h": sym_h, "sym_v": sym_v, "regions": regions}
	if style == "rings":
		ctx["layer"] = _layers(area)
	var owner := {}
	var groups := {}  # id -> [cells, nối trục dọc, nối trục ngang]
	var total := 0
	for c in area:
		if stone_set.has(c) or not _in_domain(c, w, h, sym_h, sym_v):
			continue
		var gi := groups.size()
		owner[c] = gi
		var on_x := sym_h and w % 2 == 1 and c.x == ax
		var on_y := sym_v and h % 2 == 1 and c.y == ay
		var kinds := [0, 0, 0, 0]
		kinds[(1 if on_x else 0) + (2 if on_y else 0)] = 1
		groups[gi] = [[c], on_x, on_y, kinds]
		total += _copies(groups[gi], sym_h, sym_v)
	while total > n:
		var found := _merge_options(groups, owner, total, n, ax, ay, ctx, true)
		if (found[0] as Array).is_empty() and style != "sym":
			found = _merge_options(groups, owner, total, n, ax, ay, ctx, false)
		var opts: Array = found[0]
		var weights: Array[float] = found[1]
		var under: Array = found[2]
		if opts.is_empty():
			var pick: Array = []
			for u in under:
				if total - int(u[4]) >= n - 2 and (pick.is_empty() or int(u[4]) < int(pick[4])):
					pick = u
			if not pick.is_empty():
				total = _apply_merge(groups, owner, pick, total)
			break
		# Một lần quét chọn tới 1/TILE_BATCH số lần gộp còn lại, các lần gộp không chung nhóm nào nên trọng số của những
		# cách gộp còn lại vẫn đúng; nhóm vừa gộp chờ lần quét sau.
		var used := {}
		@warning_ignore("integer_division")
		for _k in maxi(1, (total - n) / TILE_BATCH):
			var sum := 0.0
			for i in opts.size():
				var o: Array = opts[i]
				if weights[i] > 0.0 and (used.has(o[0]) or used.has(o[1]) or total - int(o[4]) < n):
					weights[i] = 0.0
				sum += weights[i]
			if sum <= 0.0:
				break
			var pick: Array = opts[_pick_weighted(weights, rng)]
			used[pick[0]] = true
			used[pick[1]] = true
			total = _apply_merge(groups, owner, pick, total)
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


## Gộp theo `pick` = [gi, gj (-1: nối với ảnh lật), nối dọc, nối ngang, số khối bớt]; trả số khối còn lại.
static func _apply_merge(groups: Dictionary, owner: Dictionary, pick: Array, total: int) -> int:
	var a: int = pick[0]
	var b: int = pick[1]
	if b >= 0:
		for c in groups[b][0]:
			owner[c] = a
			groups[a][0].append(c)
		groups[a][3] = _sum4(groups[a][3], groups[b][3])
		groups.erase(b)
	groups[a][1] = pick[2]
	groups[a][2] = pick[3]
	return total - int(pick[4])


## Mọi cách gộp của `_tile_sym` ở bước này: [opts, weights, under] (xem `_merge_option`). `constrained`: chỉ gộp qua cạnh
## hợp kiểu cắt trong `ctx` (`_edge_ok`), kể cả cạnh nối một nhóm với ảnh lật của nó.
static func _merge_options(groups: Dictionary, owner: Dictionary, total: int, n: int, ax: int, ay: int, ctx: Dictionary,
		constrained: bool) -> Array:
	var w: int = ctx["w"]
	var h: int = ctx["h"]
	var sym_h: bool = ctx["sym_h"]
	var sym_v: bool = ctx["sym_v"]
	var opts: Array = []  # [gi, gj (-1: nối với ảnh lật), nối dọc, nối ngang, số khối bớt]
	var weights: Array[float] = []
	var under: Array = []  # các lần gộp làm số khối xuống dưới n
	var none := [0, 0, 0, 0]
	for gi in groups:
		var g: Array = groups[gi]
		var g_single := _full_size(g[3], g[1], g[2]) == 1
		var self_x := false
		var self_y := false
		for c: Vector2i in g[0]:
			if sym_h and w % 2 == 0 and c.x == ax and (not constrained or _edge_ok(c, Vector2i(w - 1 - c.x, c.y), ctx)):
				self_x = true
			if sym_v and h % 2 == 0 and c.y == ay and (not constrained or _edge_ok(c, Vector2i(c.x, h - 1 - c.y), ctx)):
				self_y = true
			for dv in NEIGHBORS:
				var nb: Vector2i = c + dv
				if not owner.has(nb):
					continue
				var gj: int = owner[nb]
				if gj <= gi or (constrained and not _edge_ok(c, nb, ctx)):
					continue
				var o: Array = groups[gj]
				var singles := int(g_single) + int(_full_size(o[3], o[1], o[2]) == 1)
				_merge_option([gi, gj, bool(g[1]) or bool(o[1]), bool(g[2]) or bool(o[2])], g[3], o[3],
					_copies(g, sym_h, sym_v) + _copies(o, sym_h, sym_v), singles, total, n, sym_h, sym_v,
					opts, weights, under)
		var own := _copies(g, sym_h, sym_v)
		# Nối với ảnh lật của chính nó: hai bản của nhóm thành một khối, nên khối 1 ô tính là hai khối 1 ô gộp lại.
		var self_singles := 2 if g_single else 0
		if self_x and not bool(g[1]):
			_merge_option([gi, -1, true, g[2]], g[3], none, own, self_singles, total, n, sym_h, sym_v, opts,
				weights, under)
		if self_y and not bool(g[2]):
			_merge_option([gi, -1, g[1], true], g[3], none, own, self_singles, total, n, sym_h, sym_v, opts,
				weights, under)
	return [opts, weights, under]


## Ghi một cách gộp hai nhóm (đếm ô `a`, `b` theo `_sum4`; b toàn 0: nối với ảnh lật) vào `opts` kèm trọng số
## `_merge_weight` nếu khối đầy đủ không quá Config.BLOCK_MAX_CELLS ô và không làm số khối xuống dưới `n`; xuống dưới
## `n` thì ghi vào `under`. `opt`: [gi, gj, nối dọc, nối ngang]; `before`: số khối trước gộp; `singles`: số khối 1 ô được
## gộp (0-2).
static func _merge_option(opt: Array, a: Array, b: Array, before: int, singles: int, total: int, n: int,
		sym_h: bool, sym_v: bool, opts: Array, weights: Array[float], under: Array) -> void:
	var cut := before - _copies([null, opt[2], opt[3]], sym_h, sym_v)
	if cut <= 0:
		return
	var size := _full_size(_sum4(a, b), opt[2], opt[3])
	if size > Config.BLOCK_MAX_CELLS:
		return
	var full: Array = opt + [cut]
	if total - cut >= n:
		opts.append(full)
		weights.append(_merge_weight(size, singles))
	else:
		under.append(full)


## Số ô của khối đầy đủ khi nối qua trục dọc (`joined_h`) và trục ngang (`joined_v`), từ số ô của nhóm trong phần cơ sở
## chia theo vị trí (`kinds`): [ngoài cả hai trục lẻ, trên cột giữa lẻ, trên hàng giữa lẻ, trên cả hai]. Ô nằm đúng trên
## trục lẻ là ảnh của chính nó. Bằng `_expand(...).size()` nhưng không dựng mảng.
static func _full_size(kinds: Array, joined_h: bool, joined_v: bool) -> int:
	var mh := 2 if joined_h else 1
	var mv := 2 if joined_v else 1
	return int(kinds[0]) * mh * mv + int(kinds[1]) * mv + int(kinds[2]) * mh + int(kinds[3])


static func _sum4(a: Array, b: Array) -> Array:
	return [int(a[0]) + int(b[0]), int(a[1]) + int(b[1]), int(a[2]) + int(b[2]), int(a[3]) + int(b[3])]


## Cạnh giữa hai ô kề nhau `a`, `b` (hoặc một ô và ảnh lật của nó) có được gộp theo kiểu cắt `ctx.style` không:
## "rows" chỉ cạnh ngang, "cols" chỉ cạnh dọc, "rings" hai ô cùng vòng (`_layers`), "weave" cùng ô đan và đúng hướng
## của ô đó, "bricks" cạnh ngang trừ chỗ nối gạch, "template" hai ô cùng vùng vẽ. "sym" gộp tự do. Mọi kiểu đều đối xứng
## qua trục của hình nên cách cắt vẫn đối xứng.
static func _edge_ok(a: Vector2i, b: Vector2i, ctx: Dictionary) -> bool:
	match str(ctx["style"]):
		"rows":
			return a.y == b.y
		"cols":
			return a.x == b.x
		"rings":
			return int(ctx["layer"].get(a, -1)) == int(ctx["layer"].get(b, -2))
		"template":
			return str(ctx["regions"].get(a, "")) == str(ctx["regions"].get(b, "?"))
		"weave":
			var xa := _axis(a.x, ctx["w"], ctx["sym_h"])
			var xb := _axis(b.x, ctx["w"], ctx["sym_h"])
			var ya := _axis(a.y, ctx["h"], ctx["sym_v"])
			var yb := _axis(b.y, ctx["h"], ctx["sym_v"])
			@warning_ignore("integer_division")
			var tile := Vector2i(xa.y / WEAVE_TILE, ya.y / WEAVE_TILE)
			@warning_ignore("integer_division")
			if xa.x != xb.x or ya.x != yb.x or tile != Vector2i(xb.y / WEAVE_TILE, yb.y / WEAVE_TILE):
				return false
			return a.y == b.y if (tile.x + tile.y) % 2 == 0 else a.x == b.x
		"bricks":
			if a.y != b.y:
				return false
			@warning_ignore("integer_division")
			var shift := (_axis(a.y, ctx["h"], ctx["sym_v"]).y % 2) * (BRICK_LEN / 2)
			var xa := _axis(a.x, ctx["w"], ctx["sym_h"])
			var xb := _axis(b.x, ctx["w"], ctx["sym_h"])
			if xa.x != xb.x:
				return shift != 0  # qua trục: hàng so le thì có viên gạch vắt qua trục
			return (maxi(xa.y, xb.y) + shift) % BRICK_LEN != 0
	return true


## Toạ độ `v` (cột hoặc hàng) tính từ trục đối xứng ra ngoài: (phía, khoảng cách tới trục). Hai ô đối xứng qua trục cùng
## khoảng cách, khác phía; không đối xứng thì phía 0, khoảng cách là chính `v`.
static func _axis(v: int, size: int, sym: bool) -> Vector2i:
	if not sym:
		return Vector2i(0, v)
	@warning_ignore("integer_division")
	var half := size / 2
	if size % 2 == 0:
		return Vector2i(0, half - 1 - v) if v < half else Vector2i(1, v - half)
	return Vector2i(signi(v - half) + 1, absi(v - half))


## Vòng của mỗi ô trong hình: 0 nếu một trong 8 ô quanh nó nằm ngoài hình, rồi tăng dần vào trong.
static func _layers(area: Array[Vector2i]) -> Dictionary:
	var inside := {}
	for c in area:
		inside[c] = true
	var layer := {}
	var queue: Array[Vector2i] = []
	for c in area:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if not layer.has(c) and not inside.has(c + Vector2i(dx, dy)):
					layer[c] = 0
					queue.append(c)
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nb := c + Vector2i(dx, dy)
				if inside.has(nb) and not layer.has(nb):
					layer[nb] = int(layer[c]) + 1
					queue.append(nb)
	return layer


static func _flipped(cells: Array[Vector2i], w: int, h: int, horizontal: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in cells:
		out.append(Vector2i(w - 1 - c.x, c.y) if horizontal else Vector2i(c.x, h - 1 - c.y))
	return out


## Mô phỏng ván tiến. Trả {order: Array[int], color: Array[int] (theo chỉ số nhóm),
## clear: Array (mỗi nhóm: các màu thoát được lúc nó bị chọn), depth: chuỗi chặn sâu nhất}; {} nếu kẹt.
## `power`: số mũ của trọng số (1 + số khối chắn đường lúc đầu); càng lớn càng nhiều khối phải chờ lúc đầu.
## Độ sâu của một khối là lượt nó rời bàn khi mỗi lượt cho mọi khối đang thông đường đi: 1 nếu đường ra không có khối
## nào lúc đầu, không thì 1 + độ sâu lớn nhất của các khối chắn đường đó (chúng đã đi trước). `aim` > 0: lái chuỗi
## sâu nhất về `aim` (DEPTH_PUSH, DEPTH_FREE khi còn nông, DEPTH_HOLD khi đã đủ sâu).
static func _assign(w: int, h: int, stones: Array[Vector2i], groups: Array, allowed: Array[int],
		power: int, rng: RandomNumberGenerator, aim: int = 0) -> Dictionary:
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
	var hit: Array = []  # hit[i*4+col]: các khối nằm trên đường ra lúc đầu
	for i in n:
		for col in 4:
			var p := PackedInt32Array()
			var d: Vector2i = dirs[col]
			var seen := {}
			var on_way := {}
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
							on_way[grid[gi]] = true
					q += d
			path.append(p)
			hit.append(PackedInt32Array(on_way.keys()))
	var alive := PackedByteArray()
	alive.resize(n)
	alive.fill(1)
	var used := [0, 0, 0, 0]
	var order: Array[int] = []
	var color: Array[int] = []
	color.resize(n)
	var clear: Array = []
	clear.resize(n)
	var depth := PackedInt32Array()
	depth.resize(n)
	var deepest := 0
	for step in n:
		var cand: Array = []  # [i, col, độ sâu]
		var weights: Array[float] = []
		var per_block := {}
		var behind := deepest < aim
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
				var dp := 1
				for j in hit[i * 4 + col]:
					dp = maxi(dp, depth[j] + 1)
				if aim > 0:
					if dp > deepest and deepest >= aim:
						wt *= DEPTH_HOLD
					elif behind:
						wt *= pow(DEPTH_PUSH, dp - deepest) if dp > 1 else DEPTH_FREE
				cand.append([i, col, dp])
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
		depth[bi] = pick[2]
		deepest = maxi(deepest, pick[2])
		used[bc] += 1
		alive[bi] = 0
		for c in groups[bi]:
			grid[c.y * w + c.x] = -1
	return {"order": order, "color": color, "clear": clear, "depth": deepest}


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
	# Level dạy xích: khối thứ hai trong thứ tự giải bị xích vào khối thứ nhất, nên chìa thoát được ngay và bỏ chìa thì
	# khối bị xích đi được (`_teach_ok`).
	if teach_mech(id) == "chain" and order.size() > 1:
		pool.erase(order[1])
		pool.push_front(order[1])
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
		# Mỗi lần qua cổng khoá tốn một cú dội, nên cổng đặt ở cạnh có ít lần qua nhất (khối theo màu, hộp giấy tính cả
		# màu vỏ lẫn màu trong); bằng nhau thì ngẫu nhiên. Cổng mở sẵn hay khoá ngẫu nhiên; level dạy luôn khoá.
		var passes := {}
		for i in n:
			var col := int(asg["color"][i])
			passes[col] = int(passes.get(col, 0)) + 1
			if layer.has(i):
				passes[int(layer[i])] = int(passes.get(int(layer[i]), 0)) + 1
		var cols: Array = passes.keys()
		cols.sort()
		_shuffle(cols, rng)
		cols.sort_custom(func(a: int, b: int) -> bool: return int(passes[a]) < int(passes[b]))
		var want := 2 if id >= GATE2_FROM and cols.size() >= 2 and n <= GATE2_MAX_BLOCKS else 1
		for k in mini(want, cols.size()):
			var open := rng.randf() < 0.5 and teach_mech(id) != "pulse"
			pulse.append({"side": LevelData.SIDES[int(cols[k])], "open": open})
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
