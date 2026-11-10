extends RefCounted
## Leaderboard theo league (design.md mục 7). Logic thuần: giờ truyền vào (now: unix giây).
## Ghi vào s.lb {joined, points, league, seed, day, seen_rank, bots, risen, pending, pending_cos, t0, week, clock,
## result}. pending_cos: avatar, frame (Config.LEADERBOARD.cosmetics) đã chọn cho các league đang chờ; chỉ đọc s.cos.
## s.lb.guide (popup Cách hoạt động lần đầu) do Game.lb_take_guide ghi.
## Tuần: t0 là lúc vào BXH (mở khoá), tuần k chạy [t0 + k * week_len, t0 + (k + 1) * week_len). Hết tuần thì điểm về
## 0, league về đầu, BXH mới (roll); clock là giờ lớn nhất đã thấy, để đồng hồ lùi không làm tuần chạy ngược.
## Bot: {n: tên, a: avatar, f: frame, c: mã cờ, p: điểm}. Người chơi không nằm trong `bots`: BXH = bots + người chơi.
## Module không cộng hàng: claim, claim_result trả thưởng {coins, items, inf_min, cos: [id avatar/frame]} để Game cộng.

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


## Thưởng cấu hình của league `i`: {coins, items, inf_min, cos: [], cos_random (số avatar/frame random khi vào)}.
static func reward_of(i: int) -> Dictionary:
	var raw: Variant = _league(i).get("reward", {})
	if not (raw is Dictionary):
		return _empty()
	return {"coins": int(raw.get("coins", 0)), "items": (raw.get("items", {}) as Dictionary).duplicate(),
		"inf_min": int(raw.get("inf_min", 0)), "cos": [], "cos_random": int(raw.get("cos_random", 0))}


## League `i` có thưởng khi vào (league đầu thường không có).
static func has_reward(i: int) -> bool:
	var r := reward_of(i)
	var n := int(r.coins) + int(r.inf_min) + int(r.cos_random)
	for k in r.items:
		n += int(r.items[k])
	return n > 0


## Thưởng của league `i` để xem trước (bong bóng, thang giải): cos_random không quá số món còn random được, nên
## hết món thì không còn ô avatar/khung ngẫu nhiên.
static func preview_reward(s: Dictionary, i: int) -> Dictionary:
	var r := reward_of(i)
	r["cos_random"] = mini(int(r.cos_random), cos_left(s).size())
	return r


static func _empty() -> Dictionary:
	return {"coins": 0, "items": {}, "inf_min": 0, "cos": []}


## Cộng hai phần thưởng; cos (món đã chọn) nối lại, cos_random (cấu hình) bỏ đi.
static func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var items: Dictionary = (a.get("items", {}) as Dictionary).duplicate()
	var bi: Dictionary = b.get("items", {})
	for k in bi:
		items[k] = int(items.get(k, 0)) + int(bi[k])
	var cos: Array = []
	for src: Dictionary in [a, b]:
		var c: Variant = src.get("cos", [])
		if c is Array:
			for id in c:
				if not cos.has(str(id)):
					cos.append(str(id))
	return {"coins": int(a.get("coins", 0)) + int(b.get("coins", 0)), "items": items,
		"inf_min": int(a.get("inf_min", 0)) + int(b.get("inf_min", 0)), "cos": cos}


# --- avatar, frame của thưởng league ---

## Avatar, frame chỉ có từ thưởng league (Config.LEADERBOARD.cosmetics).
static func cosmetics() -> Array:
	var raw: Variant = Config.LEADERBOARD.get("cosmetics", [])
	return (raw as Array).duplicate() if raw is Array else []


## League đầu tiên có avatar/frame random; -1 khi không league nào có. Bot ở league dưới không đeo các món này.
static func cos_from() -> int:
	for i in leagues().size():
		if int(reward_of(i).cos_random) > 0:
			return i
	return -1


## Món còn random được: chưa có (s.cos.owned), chưa nằm trong thưởng chờ hay kết quả tuần chưa nhận.
static func cos_left(s: Dictionary) -> Array:
	var b := _lb(s)
	var cos: Variant = s.get("cos")
	var owned: Variant = (cos as Dictionary).get("owned", []) if cos is Dictionary else []
	var taken: Array = (b.pending_cos as Array).duplicate()
	var res: Dictionary = b.result
	if res.get("reward") is Dictionary and (res.reward as Dictionary).get("cos") is Array:
		taken.append_array(res.reward.cos)
	var out: Array = []
	for id in cosmetics():
		if not (owned is Array and (owned as Array).has(id)) and not taken.has(id):
			out.append(id)
	return out


## Chọn avatar/frame cho league `li` vừa vào: reward.cos_random món khác nhau trong cos_left, ghi vào pending_cos.
## Xác định theo seed của BXH, tuần và league. Hết món thì thôi, không có gì thay.
static func _roll_cos(s: Dictionary, li: int) -> void:
	var b := _lb(s)
	var n := int(reward_of(li).cos_random)
	if n <= 0:
		return
	var rng := _rng(["cos", int(b.seed), int(b.week), li, (b.pending_cos as Array).size()])
	for k in n:
		var left := cos_left(s)
		if left.is_empty():
			return
		(b.pending_cos as Array).append(str(left[rng.randi_range(0, left.size() - 1)]))


# --- thời gian ---

static func _shift() -> int:
	return (int(Config.LEADERBOARD.get("grow_tz_hours", 7)) - int(Config.LEADERBOARD.get("grow_hour", 7))) * 3600


## Số ngày BXH. Đổi ngày lúc grow_hour giờ ở GMT+grow_tz_hours (mặc định 7h GMT+7, tức 00:00 UTC).
static func day_of(now: int) -> int:
	return floori(float(now + _shift()) / float(DAY_SEC))


## Giây tới lần bot tăng điểm kế tiếp.
static func seconds_to_grow(now: int) -> int:
	return (day_of(now) + 1) * DAY_SEC - (now + _shift())


## Độ dài một tuần BXH (giây): week_days ngày.
static func week_len() -> int:
	return maxi(int(Config.LEADERBOARD.get("week_days", 7)), 1) * DAY_SEC


## Giờ tính tuần: không nhỏ hơn giờ lớn nhất đã thấy (đồng hồ lùi thì tuần đứng yên). Ghi lại giờ đó.
static func _clock(s: Dictionary, now: int) -> int:
	var b := _lb(s)
	var t := maxi(now, int(b.clock))
	b["clock"] = t
	return t


## Chỉ số tuần (0 = tuần đầu) chứa thời điểm t.
static func week_at(s: Dictionary, t: int) -> int:
	return maxi(floori(float(t - int(_lb(s).t0)) / float(week_len())), 0)


## Chỉ số tuần hiện tại (0 = tuần đầu).
static func week(s: Dictionary) -> int:
	return int(_lb(s).week)


## Lúc tuần hiện tại kết thúc (unix giây).
static func week_end(s: Dictionary) -> int:
	var b := _lb(s)
	return int(b.t0) + (int(b.week) + 1) * week_len()


## Giây tới lúc tuần hiện tại kết thúc, trong [0, week_len]; đồng hồ lùi thì tính từ giờ lớn nhất đã thấy.
static func seconds_to_week_end(s: Dictionary, now: int) -> int:
	var b := _lb(s)
	if not bool(b.joined):
		return week_len()
	return clampi(week_end(s) - maxi(now, int(b.clock)), 0, week_len())


# --- trạng thái ---

static func _lb(s: Dictionary) -> Dictionary:
	if not (s.get("lb") is Dictionary):
		s["lb"] = {}
	var b: Dictionary = s.lb
	for k in ["bots", "risen", "pending", "pending_cos"]:
		if not (b.get(k) is Array):
			b[k] = []
	for k in ["points", "seed", "seen_rank", "t0", "week", "clock"]:
		b[k] = int(b.get(k, 0))
	if not (b.get("result") is Dictionary):
		b["result"] = {}
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


## Vào BXH lần đầu (lúc mở khoá): tuần đầu bắt đầu lúc này (t0), league theo điểm hiện có (bình thường là league
## đầu, 0 điểm), BXH mới; league có thưởng thì chờ nhận. Trả true nếu vừa vào.
static func join(s: Dictionary, now: int) -> bool:
	var b := _lb(s)
	if bool(b.joined) or not enabled():
		return false
	b["joined"] = true
	b["seed"] = hash(["lb", now])
	b["day"] = day_of(now)
	b["t0"] = now
	b["week"] = 0
	b["clock"] = now
	var li := league_for(int(b.points))
	for k in li + 1:
		if has_reward(k):
			(b.pending as Array).append(k)
			_roll_cos(s, k)
	b["risen"] = []
	_enter(s, li)
	return true


## Bản lưu trước khi có tuần (đã vào BXH, t0 = 0): tuần đầu bắt đầu lúc này. League tính lại theo ngưỡng hiện tại
## (không thêm thưởng), BXH dựng lại; điểm và thưởng chờ giữ nguyên. Trả true nếu vừa chuyển.
static func ensure_week(s: Dictionary, now: int) -> bool:
	var b := _lb(s)
	if not bool(b.joined) or int(b.t0) > 0:
		return false
	b["t0"] = now
	b["week"] = 0
	b["clock"] = now
	b["day"] = day_of(now)
	b["risen"] = []
	_enter(s, league_for(int(b.points)))
	return true


## Hết tuần (theo _clock): bot được bù điểm tới lúc hết tuần rồi chốt hạng; tuần vừa hết có điểm (hoặc còn thưởng
## league chờ) thì ghi `result` {week, league, points, rank, reward}, reward gồm thưởng league còn chờ và thưởng của
## kết quả cũ chưa nhận (không mất thưởng). Rồi điểm về 0, league về đầu, BXH mới, thưởng league nhận lại được.
## Vắng nhiều tuần chỉ tính một lần; tuần không điểm không có kết quả. Trả kết quả vừa ghi; {} nếu tuần chưa hết
## hoặc tuần vừa hết không có kết quả (vẫn reset).
static func roll(s: Dictionary, now: int) -> Dictionary:
	var b := _lb(s)
	if not bool(b.joined) or int(b.t0) <= 0:
		return {}
	var t := _clock(s, now)
	var w := week_at(s, t)
	if w <= int(b.week):
		return {}
	grow(s, week_end(s) - 1)
	var out: Dictionary = {}
	if int(b.points) > 0 or not (b.pending as Array).is_empty():
		var old: Dictionary = b.result
		var prev: Dictionary = old.get("reward", _empty()) if old.get("reward") is Dictionary else _empty()
		out = {"week": int(b.week), "league": int(b.league), "points": int(b.points), "rank": rank(s),
			"reward": _merge(prev, pending_reward(s))}
		b["result"] = out
		b["pending"] = []
		b["pending_cos"] = []
	b["week"] = w
	b["points"] = 0
	b["seed"] = hash(["lb", int(b.seed), w])
	b["day"] = day_of(t)
	b["risen"] = []
	_enter(s, 0)
	return out.duplicate(true)


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
		var bot := make_bot(rng, li)
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


## Bot mới của league `li` (-1: không theo league, đeo được mọi món).
static func make_bot(rng: RandomNumberGenerator, li: int = -1) -> Dictionary:
	return {"n": _bot_name(rng), "a": _cosmetic(rng, "avatar", li), "f": _cosmetic(rng, "frame", li),
		"c": FLAGS[rng.randi_range(0, FLAGS.size() - 1)], "p": 0}


## Avatar hoặc frame theo tỉ lệ: bot_<kind>_default_pct% dùng món mặc định, còn lại random đều trong catalog. Bot ở
## league dưới cos_from không đeo món của thưởng league (Config.LEADERBOARD.cosmetics).
static func _cosmetic(rng: RandomNumberGenerator, kind: String, li: int = -1) -> String:
	var pct := int(Config.LEADERBOARD.get("bot_%s_default_pct" % kind, 80))
	var n := int(Config.COSMETICS.get(kind + "_count", 0))
	var def := str(Config.COSMETICS.get("default_" + kind, "%s_00" % kind))
	if n <= 0 or rng.randi_range(1, 100) <= pct:
		return def
	var from := cos_from()
	var hide: Array = cosmetics() if li >= 0 and from >= 0 and li < from else []
	var ids: Array = []
	for k in range(1, n + 1):
		var id := "%s_%02d" % [kind, k]
		if not hide.has(id):
			ids.append(id)
	if ids.is_empty():
		return def
	return str(ids[rng.randi_range(0, ids.size() - 1)])


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
				var fresh := make_bot(rng, li)
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


## Cộng `n` mảnh của level vừa thắng vào tuần hiện tại. Chạm min league mới thì lên hạng (có thể qua nhiều league
## một lúc): thưởng mỗi league có thưởng vào `pending`, BXH dựng lại cho league mới. Trả {added, before, after, rank_before, rank_after,
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
			if has_reward(k):
				(b.pending as Array).append(k)
				_roll_cos(s, k)
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

## World Ranking mô phỏng: world_size người đứng đầu (sinh lại mỗi tuần, đổi theo ngày BXH), điểm trên trần bot
## của league cuối. Người chơi đủ điểm thì chen vào danh sách; không thì hạng ước tính từ players_above (ít nhất
## world_size + 1). Trả {rows, rank, top_percent, total}; mỗi hàng như standings, thêm `league` (id).
static func world(s: Dictionary, now: int) -> Dictionary:
	var n := maxi(int(Config.LEADERBOARD.get("world_size", 50)), 1)
	var rng := _rng(["world", week(s), day_of(now)])
	var top := maxi(leagues().size() - 1, 0)
	var p := range_of(top).y + rng.randi_range(1, 50)
	@warning_ignore("integer_division")
	var step := maxi(int(Config.LEADERBOARD.get("top_span", 1000)) / 50, 2)
	var bots: Array = []
	for k in n:
		var bot := make_bot(rng, top)
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


## Thưởng gộp của mọi league đang chờ (chưa nhận), cos là các món đã chọn lúc vào league.
static func pending_reward(s: Dictionary) -> Dictionary:
	var b := _lb(s)
	var total := _empty()
	for li in b.pending:
		total = _merge(total, reward_of(int(li)))
	return _merge(total, {"cos": b.pending_cos})


## Nhận thưởng của mọi league đang chờ, xoá danh sách chờ. Trả thưởng gộp ({} nếu không có gì chờ).
static func claim(s: Dictionary) -> Dictionary:
	var b := _lb(s)
	if (b.pending as Array).is_empty():
		return {}
	var total := pending_reward(s)
	b["pending"] = []
	b["pending_cos"] = []
	return total


## Kết quả tuần chờ xem {week (0 = tuần đầu), league (chỉ số), points, rank, reward}; {} nếu không có.
static func result(s: Dictionary) -> Dictionary:
	return (_lb(s).result as Dictionary).duplicate(true)


## Xem xong kết quả tuần: xoá kết quả, trả thưởng của nó (có thể rỗng); {} nếu không có kết quả.
static func claim_result(s: Dictionary) -> Dictionary:
	var b := _lb(s)
	var r: Dictionary = b.result
	if r.is_empty():
		return {}
	b["result"] = {}
	var reward: Variant = r.get("reward")
	return _merge(_empty(), reward if reward is Dictionary else _empty())
