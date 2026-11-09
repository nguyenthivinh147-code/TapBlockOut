extends RefCounted
## Màn đặc biệt (design.md mục 7 "Màn đặc biệt"): vé, tiến độ bàn, số bom, thưởng. Logic thuần, giờ truyền vào.
## Bản lưu s.special = {
##   "slot_at": lúc ngăn chờ có vé (unix giây; now >= slot_at là đang có vé; 0 = có sẵn, như lúc mới mở),
##   "bonus": số vé ngăn thưởng (thắng Hard / VeryHard),
##   "wins": số trận Special đã thắng (quyết định số bom),
##   "board": bàn sẽ chơi (1, 2, ...; file theo board_file), chỉ tăng khi thắng,
##   "invited": đã tự mời lần đầu sau khi mở, "guide": đã xem hướng dẫn lần đầu,
## }. Ngăn chờ giữ tối đa 1 vé: dùng vé thì đồng hồ Config.SPECIAL.timer_sec bắt đầu, đủ giờ thì có vé và dừng.
## Vé ngăn thưởng không ảnh hưởng đồng hồ. Vào chơi dùng vé ngăn chờ trước.

const Config := preload("res://src/config.gd")
const SpecialBoard := preload("res://src/core/special_board.gd")

const SOURCE_TIMER := "timer"
const SOURCE_BONUS := "bonus"


static func _sp(s: Dictionary) -> Dictionary:
	return s["special"]


## Giờ máy lùi làm thời gian chờ dài hơn timer_sec: kéo về đúng timer_sec (đồng hồ không chạy ngược).
static func normalize(s: Dictionary, now: int) -> void:
	var sp := _sp(s)
	var cap := now + int(Config.SPECIAL.timer_sec)
	if int(sp.get("slot_at", 0)) > cap:
		sp["slot_at"] = cap


static func timer_ready(s: Dictionary, now: int) -> bool:
	return now >= int(_sp(s).get("slot_at", 0))


## Giây tới khi ngăn chờ có vé (0 khi đang có).
static func wait_left(s: Dictionary, now: int) -> int:
	return clampi(int(_sp(s).get("slot_at", 0)) - now, 0, int(Config.SPECIAL.timer_sec))


static func bonus(s: Dictionary) -> int:
	return maxi(int(_sp(s).get("bonus", 0)), 0)


static func tickets(s: Dictionary, now: int) -> int:
	return int(timer_ready(s, now)) + bonus(s)


## Vé ngăn thưởng khi thắng level chính có độ khó `difficulty` ("" | "hard" | "very_hard").
static func tickets_for(difficulty: String) -> int:
	match difficulty:
		"hard":
			return int(Config.SPECIAL.ticket_hard)
		"very_hard":
			return int(Config.SPECIAL.ticket_very_hard)
	return 0


## Cộng `n` vé vào ngăn thưởng (bonus_cap > 0 thì không vượt). Trả số vé thực cộng.
static func add_bonus(s: Dictionary, n: int) -> int:
	if n <= 0:
		return 0
	var sp := _sp(s)
	var before := bonus(s)
	var after := before + n
	var cap := int(Config.SPECIAL.bonus_cap)
	if cap > 0:
		after = mini(after, maxi(cap, before))
	sp["bonus"] = after
	return after - before


## Dùng một vé: ngăn chờ trước (đồng hồ bắt đầu), rồi ngăn thưởng. Trả nguồn ("timer" | "bonus"), "" khi hết vé.
static func consume(s: Dictionary, now: int) -> String:
	var sp := _sp(s)
	if timer_ready(s, now):
		sp["slot_at"] = now + int(Config.SPECIAL.timer_sec)
		return SOURCE_TIMER
	if bonus(s) > 0:
		sp["bonus"] = bonus(s) - 1
		return SOURCE_BONUS
	return ""


static func wins(s: Dictionary) -> int:
	return maxi(int(_sp(s).get("wins", 0)), 0)


static func board(s: Dictionary) -> int:
	return maxi(int(_sp(s).get("board", 1)), 1)


## File bàn (1..boards) của bàn thứ `n`: hết `boards` bàn thì quay lại bàn 1.
static func board_file(n: int) -> int:
	return posmod(maxi(n, 1) - 1, maxi(int(Config.SPECIAL.boards), 1)) + 1


static func bomb_count(s: Dictionary) -> int:
	return SpecialBoard.bomb_count(wins(s))


## Seed đặt bom: cùng bàn và cùng số trận thắng thì cùng bom (thua chơi lại gặp đúng bàn và bom cũ).
static func bomb_seed(s: Dictionary) -> int:
	return board(s) * 7919 + wins(s)


## Thắng: +1 trận, sang bàn kế.
static func win(s: Dictionary) -> void:
	var sp := _sp(s)
	sp["wins"] = wins(s) + 1
	sp["board"] = board(s) + 1


## Booster thưởng, rút đều trong mảng Config.SPECIAL.reward_kinds theo `seed_value` (tên lặp lại = tỉ lệ cao hơn).
static func pick_reward(seed_value: int) -> String:
	var kinds: Array = Config.SPECIAL.reward_kinds
	if kinds.is_empty():
		return "hint"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return str(kinds[rng.randi_range(0, kinds.size() - 1)])


## Lúc ngăn chờ có vé lại (cho thông báo); 0 khi đang có vé.
static func ready_at(s: Dictionary, now: int) -> int:
	return 0 if timer_ready(s, now) else int(_sp(s).get("slot_at", 0))
