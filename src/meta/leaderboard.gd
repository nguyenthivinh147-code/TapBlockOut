extends RefCounted
## Leaderboard theo league (design.md mục 7). Logic thuần: giờ truyền vào (now: unix giây).
## Ghi vào s.lb {joined, points, league, seed, day, seen_rank, bots, risen, pending}.
## Bot: {n: tên, a: avatar, f: frame, c: mã cờ, p: điểm}. Người chơi không nằm trong `bots`: BXH = bots + người chơi.
## Module không cộng hàng: claim trả thưởng {coins, items, inf_min} để Game cộng.

const Config := preload("res://src/config.gd")

const DAY_SEC := 86400
## Tên bot ghép hai mảnh (kiểu "seektiger", "baytoad"), đôi khi thêm số; một phần là "Player_xxxxxx".
const NAME_HEAD := ["seek", "bay", "cub", "jou", "sun", "mint", "taffy", "pop", "fizz", "zip", "lolly", "nova",
	"pix", "mochi", "berry", "coco", "gum", "toffee", "jelly", "sugar", "lucky", "swift", "tiny", "happy"]
const NAME_TAIL := ["tiger", "toad", "remy", "ca", "fox", "bear", "drop", "pie", "bean", "cat", "owl", "star",
	"kid", "puff", "chip", "bun", "moon", "wolf", "duck", "lime", "pop", "boo", "zee", "max"]
const PLAYER_NAME_PCT := 15
const NAME_NUMBER_PCT := 30
## Mã cờ (ISO 3166-1 alpha-2) của bot.
const FLAGS := ["VN", "US", "BR", "ID", "PH", "TH", "IN", "MX", "DE", "FR", "GB", "TR", "RU", "KR", "JP", "ES", "IT", "CA"]


static func enabled() -> bool:
	return bool(Config.LEADERBOARD.get("enabled", true)) and not leagues().is_empty()


# --- league ---

static func leagues() -> Array:
	return Config.LEADERBOARD.get("leagues", [])


static func _league(i: int) -> Dictionary:
	var ls := leagues()
	if ls.is_empty():
		return {}
	return ls[clampi(i, 0, ls.size() - 1)]


static func league_id(i: int) -> String:
	return str(_league(i).get("id", ""))


static func league_min(i: int) -> int:
	return int(_league(i).get("min", 0))


static func is_top(i: int) -> bool:
	return i >= leagues().size() - 1


## Điểm tối thiểu của league kế; -1 nếu đã ở league cuối.
static func next_min(i: int) -> int:
	return -1 if is_top(i) else league_min(i + 1)


## League cao nhất có min <= points.
static func league_for(points: int) -> int:
	var out := 0
	for i in leagues().size():
		if points >= league_min(i):
			out = i
	return out


## Khoảng điểm [x, y] của bot trong league `i`. League cuối không có trần: [min, min + top_span].
static func range_of(i: int) -> Vector2i:
	var lo := league_min(i)
	if is_top(i):
		return Vector2i(lo, lo + maxi(int(Config.LEADERBOARD.get("top_span", 1000)), 1))
	return Vector2i(lo, maxi(next_min(i) - 1, lo))


static func reward_of(i: int) -> Dictionary:
	var raw: Variant = _league(i).get("reward", {})
	if not (raw is Dictionary):
		return _empty()
	return {"coins": int(raw.get("coins", 0)), "items": (raw.get("items", {}) as Dictionary).duplicate(),
		"inf_min": int(raw.get("inf_min", 0))}


static func _empty() -> Dictionary:
	return {"coins": 0, "items": {}, "inf_min": 0}


static func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var items: Dictionary = (a.get("items", {}) as Dictionary).duplicate()
	var bi: Dictionary = b.get("items", {})
	for k in bi:
		items[k] = int(items.get(k, 0)) + int(bi[k])
	return {"coins": int(a.get("coins", 0)) + int(b.get("coins", 0)), "items": items,
		"inf_min": int(a.get("inf_min", 0)) + int(b.get("inf_min", 0))}


# --- thời gian ---

static func _shift() -> int:
	return (int(Config.LEADERBOARD.get("grow_tz_hours", 7)) - int(Config.LEADERBOARD.get("grow_hour", 7))) * 3600


## Số ngày BXH. Đổi ngày lúc grow_hour giờ ở GMT+grow_tz_hours (mặc định 7h GMT+7, tức 00:00 UTC).
static func day_of(now: int) -> int:
	return floori(float(now + _shift()) / float(DAY_SEC))


## Giây tới lần bot tăng điểm kế tiếp.
static func seconds_to_grow(now: int) -> int:
	return (day_of(now) + 1) * DAY_SEC - (now + _shift())


# --- trạng thái ---

static func _lb(s: Dictionary) -> Dictionary:
	if not (s.get("lb") is Dictionary):
		s["lb"] = {}
	var b: Dictionary = s.lb
	for k in ["bots", "risen", "pending"]:
		if not (b.get(k) is Array):
			b[k] = []
	for k in ["points", "seed", "seen_rank"]:
		b[k] = int(b.get(k, 0))
	b["day"] = int(b.get("day", -1))
	b["joined"] = bool(b.get("joined", false))
	b["league"] = clampi(int(b.get("league", 0)), 0, maxi(leagues().size() - 1, 0))
	return b


static func joined(s: Dictionary) -> bool:
	return bool(_lb(s).joined)


static func points(s: Dictionary) -> int:
	return int(_lb(s).points)


static func league(s: Dictionary) -> int:
	return int(_lb(s).league)


static func _rng(parts: Array) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(parts)
	return r


## Vào BXH lần đầu: league theo điểm hiện có (bình thường là league đầu, 0 điểm), BXH mới, thưởng league chờ nhận.
## Trả true nếu vừa vào.
static func join(s: Dictionary, now: int) -> bool:
	var b := _lb(s)
	if bool(b.joined) or not enabled():
		return false
	b["joined"] = true
	b["seed"] = hash(["lb", now])
	b["day"] = day_of(now)
	var li := league_for(int(b.points))
	for k in li + 1:
		(b.pending as Array).append(k)
	b["risen"] = []
	_enter(s, li)
	return true


static func _enter(s: Dictionary, li: int) -> void:
	var b := _lb(s)
	b["league"] = li
	b["bots"] = make_board(li, int(b.seed), b.risen)
	b["risen"] = []
	b["seen_rank"] = 0


# --- bot ---

## Bot của BXH league `li`, đủ board_size - 1. Trước hết là `carry` (bot vừa lên hạng cùng người chơi: giữ tên,
## avatar, điểm kẹp vào league). Bot mới chia đều theo vị trí: vị trí k nằm trong dải rộng 1% điểm của league
## (board_size = 100), dải 0 dành cho người chơi vừa vào. League cuối không có trần: random đều trong range_of.
static func make_board(li: int, seed: int, carry: Array = []) -> Array:
	var need := maxi(int(Config.LEADERBOARD.get("board_size", 100)) - 1, 0)
	var rng := _rng(["board", seed, li])
	var r := range_of(li)
	var out: Array = []
	for c in carry:
		if out.size() >= need:
			break
		if not (c is Dictionary):
			continue
		var bot: Dictionary = (c as Dictionary).duplicate()
		bot["p"] = clampi(int(bot.get("p", 0)), r.x, r.y)
		out.append(bot)
	var fresh := need - out.size()
	for k in fresh:
		var bot := make_bot(rng)
		@warning_ignore("integer_division")
		bot["p"] = band_points(li, 1 + k * need / maxi(fresh, 1), rng)
		out.append(bot)
	return out


## Điểm ngẫu nhiên trong dải `band` (0 = đáy) của league `li`. Mỗi dải rộng (khoảng điểm) / board_size.
static func band_points(li: int, band: int, rng: RandomNumberGenerator) -> int:
	var r := range_of(li)
	if is_top(li):
		return rng.randi_range(r.x, r.y)
	var width := float(r.y - r.x + 1) / float(maxi(int(Config.LEADERBOARD.get("board_size", 100)), 1))
	return clampi(r.x + floori((float(band) + rng.randf()) * width), r.x, r.y)


static func make_bot(rng: RandomNumberGenerator) -> Dictionary:
	return {"n": _bot_name(rng), "a": _cosmetic(rng, "avatar"), "f": _cosmetic(rng, "frame"),
		"c": FLAGS[rng.randi_range(0, FLAGS.size() - 1)], "p": 0}


## Avatar hoặc frame theo tỉ lệ: bot_<kind>_default_pct% dùng món mặc định, còn lại random đều trong catalog.
static func _cosmetic(rng: RandomNumberGenerator, kind: String) -> String:
	var pct := int(Config.LEADERBOARD.get("bot_%s_default_pct" % kind, 80))
	var n := int(Config.COSMETICS.get(kind + "_count", 0))
	var def := str(Config.COSMETICS.get("default_" + kind, "%s_00" % kind))
	if n <= 0 or rng.randi_range(1, 100) <= pct:
		return def
	return "%s_%02d" % [kind, rng.randi_range(1, n)]


static func _bot_name(rng: RandomNumberGenerator) -> String:
	if rng.randi_range(1, 100) <= PLAYER_NAME_PCT:
		return "Player_%06x" % rng.randi_range(0, 0xFFFFFF)
	var bot_name := str(NAME_HEAD[rng.randi_range(0, NAME_HEAD.size() - 1)]) + str(NAME_TAIL[rng.randi_range(0, NAME_TAIL.size() - 1)])
	if rng.randi_range(1, 100) <= NAME_NUMBER_PCT:
		bot_name += str(rng.randi_range(1, 99))
	return bot_name


## Điểm một bot ở league `li` tăng trong một ngày: bot_base + round(số ngẫu nhiên * hệ số biến động).
static func gain_for(li: int, rng: RandomNumberGenerator) -> int:
	var rr: Array = Config.LEADERBOARD.get("bot_rand", [0, 0])
	var vr: Array = Config.LEADERBOARD.get("bot_var", [1.0, 1.0])
	var rnd := 0
	if not rr.is_empty():
		rnd = rng.randi_range(int(rr[0]), int(rr[rr.size() - 1]))
	var vary := 1.0
	if not vr.is_empty():
		vary = rng.randf_range(float(vr[0]), float(vr[vr.size() - 1]))
	return maxi(0, int(_league(li).get("bot_base", 0)) + roundi(rnd * vary))


## Bù các ngày BXH đã qua từ lần trước (tối đa grow_max_days ngày): mỗi bot cộng gain_for mỗi ngày. Chưa ở league
## cuối thì bot chạm min league kế rời BXH (vào `risen`, đợi đi cùng người chơi khi lên hạng) và một bot mới vào
## ở đáy league thay chỗ, để BXH luôn đủ người. Đồng hồ lùi thì không làm gì. Trả số ngày đã bù.
static func grow(s: Dictionary, now: int) -> int:
	var b := _lb(s)
	if not bool(b.joined):
		return 0
	var today := day_of(now)
	var last := int(b.day)
	if last >= 0 and today <= last:
		return 0
	b["day"] = today
	if last < 0:
		return 0
	var days := mini(today - last, maxi(int(Config.LEADERBOARD.get("grow_max_days", 14)), 0))
	var li := int(b.league)
	var nxt := next_min(li)
	var bots: Array = b.bots
	var risen: Array = []
	for d in days:
		var rng := _rng(["grow", int(b.seed), li, today - days + 1 + d])
		for i in bots.size():
			var bot: Dictionary = bots[i]
			bot["p"] = int(bot.get("p", 0)) + gain_for(li, rng)
			if nxt >= 0 and int(bot.p) >= nxt:
				risen.push_front(bot)
				var fresh := make_bot(rng)
				fresh["p"] = band_points(li, 0, rng)
				bots[i] = fresh
	b["risen"] = (risen + (b.risen as Array)).slice(0, maxi(int(Config.LEADERBOARD.get("carry_max", 10)), 0))
	return days


# --- điểm ---

## Số mảnh (khối đặc biệt) của một level theo độ khó: "" | "hard" | "very_hard".
static func pieces_for(kind: String) -> int:
	match kind:
		"hard":
			return int(Config.LEADERBOARD.get("pieces_hard", 3))
		"very_hard":
			return int(Config.LEADERBOARD.get("pieces_very_hard", 4))
	return int(Config.LEADERBOARD.get("pieces_normal", 2))


## `n` khối đặc biệt lấy ngẫu nhiên trong `ids`, xác định theo `seed` (chơi lại level thì cùng khối).
static func pick_specials(ids: Array, n: int, seed: int) -> Array[String]:
	var pool := ids.duplicate()
	var rng := _rng(["special", seed])
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var out: Array[String] = []
	for i in mini(maxi(n, 0), pool.size()):
		out.append(str(pool[i]))
	return out


## Cộng `n` mảnh của level vừa thắng. Chạm min league mới thì lên hạng (có thể qua nhiều league một lúc): thưởng
## mỗi league vào `pending`, BXH dựng lại cho league mới. Trả {added, before, after, rank_before, rank_after,
## league_before, league_after, promoted (mảng chỉ số league vừa lên)}; {} nếu chưa vào BXH hoặc n <= 0.
static func add_points(s: Dictionary, n: int) -> Dictionary:
	var b := _lb(s)
	if not bool(b.joined) or n <= 0:
		return {}
	var before := int(b.points)
	var li_before := int(b.league)
	var rank_before := rank(s)
	b["points"] = before + n
	var li := league_for(int(b.points))
	var promoted: Array = []
	if li > li_before:
		for k in range(li_before + 1, li + 1):
			promoted.append(k)
			(b.pending as Array).append(k)
		_enter(s, li)
	return {"added": n, "before": before, "after": int(b.points), "rank_before": rank_before, "rank_after": rank(s),
		"league_before": li_before, "league_after": int(b.league), "promoted": promoted}


# --- xếp hạng ---

## Hạng của người chơi: 1 + số bot có điểm cao hơn (bằng điểm thì người chơi đứng trên).
static func rank(s: Dictionary) -> int:
	var b := _lb(s)
	var me := int(b.points)
	var n := 1
	for bot in b.bots:
		if int(bot.get("p", 0)) > me:
			n += 1
	return n


## Cả BXH đã xếp: [{rank, name, avatar, frame, flag, points, me}]. Hàng người chơi có name "" và avatar, frame
## lấy từ s.cos. Bot bằng điểm giữ thứ tự trong `bots`.
static func standings(s: Dictionary) -> Array:
	var b := _lb(s)
	var bots: Array = b.bots
	var idx: Array = range(bots.size())
	idx.sort_custom(func(x: int, y: int) -> bool:
		var px := int(bots[x].get("p", 0))
		var py := int(bots[y].get("p", 0))
		return px > py or (px == py and x < y))
	var me := int(b.points)
	var out: Array = []
	var placed := false
	for i in idx:
		var bot: Dictionary = bots[i]
		if not placed and int(bot.get("p", 0)) <= me:
			out.append(_me_row(s, out.size() + 1))
			placed = true
		out.append(bot_row(bot, out.size() + 1))
	if not placed:
		out.append(_me_row(s, out.size() + 1))
	return out


static func bot_row(bot: Dictionary, r: int) -> Dictionary:
	return {"rank": r, "name": str(bot.get("n", "")), "avatar": str(bot.get("a", "")), "frame": str(bot.get("f", "")),
		"flag": str(bot.get("c", "")), "points": int(bot.get("p", 0)), "me": false}


static func _me_row(s: Dictionary, r: int) -> Dictionary:
	var cos: Dictionary = s.get("cos", {}) if s.get("cos") is Dictionary else {}
	return {"rank": r, "name": "", "avatar": str(cos.get("avatar", Config.COSMETICS.default_avatar)),
		"frame": str(cos.get("frame", Config.COSMETICS.default_frame)), "flag": "", "points": points(s), "me": true}


## Tối đa view_size hàng của `rows` quanh hạng `my_rank` (người chơi ở giữa). Ví dụ hạng 70 -> hạng 45 tới 94.
static func window(rows: Array, my_rank: int) -> Array:
	var n := maxi(int(Config.LEADERBOARD.get("view_size", 50)), 1)
	@warning_ignore("integer_division")
	var start := clampi(my_rank - n / 2, 1, maxi(rows.size() - n + 1, 1))
	return rows.slice(start - 1, start - 1 + n)


static func players_total() -> int:
	var n := 0
	for lg in leagues():
		n += int(lg.get("players", 0))
	return n


## Số người chơi (mô phỏng theo `players`) có thứ hạng cao hơn người chơi: mọi người ở league cao hơn, cộng phần
## đứng trên trong league của mình (tỉ lệ theo hạng trong BXH).
static func players_above(s: Dictionary) -> float:
	var li := league(s)
	var above := 0.0
	for i in range(li + 1, leagues().size()):
		above += float(_league(i).get("players", 0))
	var size := maxi(int(Config.LEADERBOARD.get("board_size", 100)), 1)
	above += float(rank(s) - 1) / float(size) * float(_league(li).get("players", 0))
	return above


## Vị trí: người có thứ hạng cao hơn / tổng người tham gia * 100%, làm tròn lên, ít nhất 1 ("Top 1%").
static func top_percent(s: Dictionary) -> int:
	var total := players_total()
	if total <= 0:
		return 100
	return clampi(ceili(players_above(s) / float(total) * 100.0), 1, 100)


## Hạng của lần người chơi xem BXH trước (0: chưa xem ở BXH này).
static func seen_rank(s: Dictionary) -> int:
	return int(_lb(s).seen_rank)


static func mark_seen(s: Dictionary) -> void:
	_lb(s)["seen_rank"] = rank(s)


# --- World Ranking ---

## World Ranking mô phỏng: world_size người đứng đầu (đổi theo ngày BXH), điểm trên trần bot của league cuối.
## Người chơi đủ điểm thì chen vào danh sách; không thì hạng ước tính từ players_above (ít nhất world_size + 1).
## Trả {rows, rank, top_percent, total}; mỗi hàng như standings, thêm `league` (id).
static func world(s: Dictionary, now: int) -> Dictionary:
	var n := maxi(int(Config.LEADERBOARD.get("world_size", 50)), 1)
	var rng := _rng(["world", day_of(now)])
	var top := maxi(leagues().size() - 1, 0)
	var p := range_of(top).y + rng.randi_range(1, 50)
	@warning_ignore("integer_division")
	var step := maxi(int(Config.LEADERBOARD.get("top_span", 1000)) / 50, 2)
	var bots: Array = []
	for k in n:
		var bot := make_bot(rng)
		p += rng.randi_range(1, step)
		bot["p"] = p
		bots.push_front(bot)
	var me := points(s)
	var rows: Array = []
	var my_rank := 0
	for bot in bots:
		if my_rank == 0 and int(bot.p) <= me:
			my_rank = rows.size() + 1
			rows.append(_me_row(s, my_rank))
		if rows.size() < n:
			rows.append(bot_row(bot, rows.size() + 1))
	if my_rank == 0:
		my_rank = maxi(n + 1, roundi(players_above(s)) + 1)
	rows = rows.slice(0, n)
	for r in rows:
		r["league"] = league_id(league_for(int(r.points)))
	return {"rows": rows, "rank": my_rank, "top_percent": top_percent(s), "total": players_total()}


# --- thưởng ---

## League đang chờ hiện popup lên hạng (chỉ số league, theo thứ tự).
static func pending(s: Dictionary) -> Array:
	return (_lb(s).pending as Array).duplicate()


## Thưởng gộp của mọi league đang chờ (chưa nhận).
static func pending_reward(s: Dictionary) -> Dictionary:
	var total := _empty()
	for li in _lb(s).pending:
		total = _merge(total, reward_of(int(li)))
	return total


## Nhận thưởng của mọi league đang chờ, xoá danh sách chờ. Trả thưởng gộp ({} nếu không có gì chờ).
static func claim(s: Dictionary) -> Dictionary:
	var b := _lb(s)
	if (b.pending as Array).is_empty():
		return {}
	var total := pending_reward(s)
	b["pending"] = []
	return total
