extends RefCounted
## Solver và tính MOVES. Mọi nước có ích (thoát, bóc hộp giấy, dội vào cổng nhịp khoá) đều phải làm đúng một lần dù đi
## theo thứ tự nào: khối rời bàn chỉ mở thêm đường cho khối khác, còn cổng nhịp chỉ đổi khi khối của cạnh đó chạm tới
## (dội vào thì mở, qua thì khoá), nên số cú dội của một cạnh luôn là số lần qua cạnh đó, trừ 1 nếu cổng mở sẵn. Khối
## còn trong sương mù hay còn lớp phủ (pudding, băng) không đi được (chạm không tốn gì) và chỉ lộ hay bóc lớp khi khối
## kề rời đi, nên hai cơ chế này chỉ làm chậm lại chứ không đổi số chạm. Vì vậy đi tham lam là tối ưu và không có nước
## "chờ".

const BoardState := preload("res://src/core/board_state.gd")
const Config := preload("res://src/config.gd")

const BIG_MOVES := 100000
const GUARD := 20000  # chặn vòng lặp tham lam, xa hơn mọi level thật
## Thứ tự ưu tiên của tham lam theo kết quả chạm.
const RANK := ["exit", "peel", "gate_closed"]


## {ok, min_taps, order}. Không giải được: ok=false, min_taps=-1.
static func solve(level: Dictionary) -> Dictionary:
	return solve_state(BoardState.new(level))


## Giải từ một trạng thái bất kỳ (MOVES của bàn bị bỏ qua).
static func solve_state(board: BoardState) -> Dictionary:
	var b := board.clone()
	b.add_moves(BIG_MOVES)
	return _greedy(b)


## Có khối thoát (hoặc bóc lớp) được ngay lúc đầu; cú dội vào cổng nhịp không tính.
static func immediate_exit_exists(level: Dictionary) -> bool:
	return BoardState.new(level).first_exit() != ""


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


## Clear rounds (design.md section 4): each round taps every block that can act right now (exit, peel the box, knock a
## locked pulse gate open), in block order, re-checking each one first; repeat until the board is empty. A covered
## block (pudding, ice) waits for its neighbours to leave. -1 if the board cannot be cleared. Equals the depth of the
## blocking chain on a board without mechanics.
static func clear_rounds(level: Dictionary) -> int:
	var b := BoardState.new(level)
	b.add_moves(BIG_MOVES)
	var rounds := 0
	while not b.is_won():
		var act: Array[String] = []
		for id in b.block_ids():
			if _acts(b.peek(id)):
				act.append(id)
		if act.is_empty():
			return -1
		rounds += 1
		for id in act:
			if _acts(b.peek(id)):
				b.tap(id)
	return rounds


static func _acts(kind: String) -> bool:
	return kind == "exit" or kind == "peel" or kind == "gate_closed"


## min_taps + dư; -1 nếu level không giải được.
static func compute_moves(level: Dictionary) -> int:
	var r := solve(level)
	if not r["ok"]:
		return -1
	return int(r["min_taps"]) + slack_for(level)


## Tham lam: thoát trước, rồi bóc hộp giấy, cuối cùng dội vào cổng nhịp khoá. Thứ tự không đổi tổng số
## chạm (xem đầu file), chỉ để lời giải gọn: cổng chỉ mở khi không còn gì khác để làm.
static func _greedy(b: BoardState) -> Dictionary:
	var order: Array[String] = []
	var guard := 0
	while not b.is_won():
		guard += 1
		if guard > GUARD:
			break
		var pick := pick_tap(b)
		if pick == "":
			return {"ok": false, "min_taps": -1, "order": order}
		order.append(pick)
		b.tap(pick)
	return {"ok": b.is_won(), "min_taps": order.size() if b.is_won() else -1, "order": order}


## Nước tiếp theo của tham lam theo RANK; "" nếu không còn nước có ích (bàn kẹt hoặc đã thắng).
static func pick_tap(b: BoardState) -> String:
	var pick := ""
	var rank := RANK.size()
	for id in b.block_ids():
		var r := RANK.find(b.peek(id))
		if r >= 0 and r < rank:
			rank = r
			pick = id
			if r == 0:
				break
	return pick
