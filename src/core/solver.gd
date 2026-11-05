extends RefCounted
## Solver và tính MOVES. Cơ chế đơn điệu (chỉ có xoá khối, nứt băng, bóc lớp) nên đi tham lam
## là tối ưu; chỉ cổng nhịp mới sinh "chạm chờ". Level có cổng mà tham lam phải chờ thì tìm
## chính xác (DFS nhớ trạng thái, có ngân sách), vượt ngân sách thì giữ kết quả tham lam.

const BoardState := preload("res://src/core/board_state.gd")
const Config := preload("res://src/config.gd")

const BIG_MOVES := 100000
const SEARCH_BUDGET := 20000
const INF := 1 << 30


## {ok, min_taps, order, wasted, exact}. Không giải được: ok=false, min_taps=-1.
static func solve(level: Dictionary) -> Dictionary:
	return solve_state(BoardState.new(level))


## Giải từ một trạng thái bất kỳ (MOVES của bàn bị bỏ qua).
static func solve_state(board: BoardState) -> Dictionary:
	var b := board.clone()
	b.add_moves(BIG_MOVES)
	var greedy := _greedy(b.clone())
	if not greedy["ok"] or int(greedy["wasted"]) == 0 or b.gates().is_empty():
		return greedy
	var memo := {}
	var ctr := [0, false]  # số nút, đã vượt ngân sách
	var best := _search(b, memo, ctr)
	if bool(ctr[1]) or best >= INF:
		return greedy
	var order: Array[String] = []
	var cur := b.clone()
	while not cur.is_won():
		var ch: String = memo[cur.state_key()][1]
		order.append(ch)
		cur.tap(ch)
	return {"ok": true, "min_taps": order.size(), "order": order, "wasted": best, "exact": true}


static func immediate_exit_exists(level: Dictionary) -> bool:
	return BoardState.new(level).hint() != ""


## Spare MOVES per design.md section 3: HARD (VeryHard too) 3, L1-3 5, L4-13 3, later levels 4.
## Fixed per tier, not scaled by block count; numbers live in Config.CONTENT (slack_*).
static func slack_for(level: Dictionary) -> int:
	var c: Dictionary = Config.CONTENT
	if bool(level.get("hard", false)):
		return int(c["slack_hard"])
	var id := int(level.get("id", 0))
	if id <= int(c["slack_easy_until"]):
		return int(c["slack_easy"])
	if id <= int(c["slack_early_until"]):
		return int(c["slack_early"])
	return int(c["slack_normal"])


## min_taps + dư; -1 nếu level không giải được.
static func compute_moves(level: Dictionary) -> int:
	var r := solve(level)
	if not r["ok"]:
		return -1
	return int(r["min_taps"]) + slack_for(level)


## Phân loại các khối theo kết quả chạm hiện tại.
static func _classify(b: BoardState) -> Dictionary:
	var cls := {"exit": [], "crack": [], "peel": [], "waste": [], "latent": false}
	for id in b.block_ids():
		var k := b.peek(id)
		if k == "exit" or k == "crack" or k == "peel":
			cls[k].append(id)
		else:
			cls["waste"].append(id)
			if k == "gate_closed":
				cls["latent"] = true
	return cls


static func _greedy(b: BoardState) -> Dictionary:
	var order: Array[String] = []
	var wasted := 0
	var guard := 0
	while not b.is_won():
		guard += 1
		if guard > 20000:
			break
		var cls := _classify(b)
		var pick := ""
		if not cls["exit"].is_empty():
			pick = cls["exit"][0]
		elif not cls["crack"].is_empty():
			pick = cls["crack"][0]
		elif not cls["peel"].is_empty():
			pick = cls["peel"][0]
		elif cls["latent"]:
			pick = cls["waste"][0]
			wasted += 1
		else:
			return {"ok": false, "min_taps": -1, "order": order, "wasted": wasted, "exact": true}
		order.append(pick)
		b.tap(pick)
	return {"ok": b.is_won(), "min_taps": order.size() if b.is_won() else -1, "order": order,
		"wasted": wasted, "exact": true}


## Số chạm chờ ít nhất từ trạng thái này (INF nếu bí). Ghi nước chọn vào memo.
static func _search(b: BoardState, memo: Dictionary, ctr: Array) -> int:
	if b.is_won():
		return 0
	var key := b.state_key()
	if memo.has(key):
		return memo[key][0]
	ctr[0] += 1
	if ctr[0] > SEARCH_BUDGET:
		ctr[1] = true
		return INF
	var cls := _classify(b)
	var best := INF
	var choice := ""
	var useful: Array = cls["exit"] + cls["crack"] + cls["peel"]
	if not useful.is_empty():
		for id in useful:
			var c := b.clone()
			c.tap(id)
			var r := _search(c, memo, ctr)
			if r < best:
				best = r
				choice = id
			if best == 0 or bool(ctr[1]):
				break
	elif cls["latent"]:
		var id: String = cls["waste"][0]
		var c := b.clone()
		c.tap(id)
		var r := _search(c, memo, ctr)
		if r < INF:
			best = r + 1
			choice = id
	memo[key] = [best, choice]
	return best
