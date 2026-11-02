extends RefCounted
## Weekly Pass. Logic thuần: giờ truyền vào (now: unix giây, tz: độ lệch múi giờ giây).
## Ghi vào s.weekly {cycle, points, vip, opened, end_seen, claimed_free, claimed_vip, claimed_bank,
## pending_end}. Module không cộng hàng: các hàm claim/refresh trả thưởng {coins, items} để Game cộng.
##
## Chu kỳ: thứ Hai 06:00 -> thứ Hai 00:00 tuần sau (giờ máy). Thứ Hai 00:00-06:00 là Waiting.

const Clock := preload("res://src/meta/clock.gd")
const Config := preload("res://src/config.gd")

const LOCKED := "locked"
const ACTIVE := "active"
const WAITING := "waiting"

const DAY_SEC := 86400


# --- thời gian ---

## Thứ Hai 00:00 (giờ máy) của tuần chứa `now`, tính bằng unix giây.
static func week_start(now: int, tz: int) -> int:
	var day := Clock.day_number(now, tz)
	var since_monday := posmod(Clock.weekday(now, tz) - 1, 7)
	return (day - since_monday) * DAY_SEC - tz


## {start, open_at, end, cycle}. `cycle` đổi vào thứ Hai 00:00, nên Waiting đã thuộc chu kỳ mới.
static func window(now: int, tz: int) -> Dictionary:
	var start := week_start(now, tz)
	var open_h := int(Config.WEEKLY.get("start_hour", 6))
	return {
		"start": start, "open_at": start + open_h * 3600, "end": start + 7 * DAY_SEC,
		"cycle": "W%d" % floori(float(start + tz) / float(DAY_SEC)),
	}


# --- trạng thái ---

## Cấu hình hợp lệ: bật, có SKU, SKU là gói VIP, có mốc.
static func config_valid() -> bool:
	var cfg: Dictionary = Config.WEEKLY
	if not bool(cfg.get("enabled", false)):
		return false
	var info: Dictionary = Config.SKUS.get(str(cfg.get("sku", "")), {})
	return bool(info.get("weekly_vip", false)) and not (cfg.get("main", []) as Array).is_empty()


## `unlocked`: người chơi đã qua level mở khoá (Game tính theo level HARD thứ N).
static func state(now: int, tz: int, unlocked: bool) -> String:
	if not config_valid() or not unlocked:
		return LOCKED
	return ACTIVE if now >= int(window(now, tz).open_at) else WAITING


## Giây còn lại: Active -> tới hết chu kỳ; Waiting -> tới lúc mở.
static func seconds_left(now: int, tz: int, st: String) -> int:
	var w := window(now, tz)
	if st == ACTIVE:
		return maxi(0, int(w["end"]) - now)
	if st == WAITING:
		return maxi(0, int(w["open_at"]) - now)
	return 0


# --- thưởng ---

static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var items: Dictionary = (a.get("items", {}) as Dictionary).duplicate()
	var bi: Dictionary = b.get("items", {})
	for k in bi:
		items[k] = int(items.get(k, 0)) + int(bi[k])
	return {"coins": int(a.get("coins", 0)) + int(b.get("coins", 0)), "items": items}


static func _empty() -> Dictionary:
	return {"coins": 0, "items": {}}


static func _reward(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return _empty()
	return {"coins": int(raw.get("coins", 0)), "items": (raw.get("items", {}) as Dictionary).duplicate()}


static func _w(s: Dictionary) -> Dictionary:
	if not (s.get("weekly") is Dictionary):
		s["weekly"] = {}
	var w: Dictionary = s.weekly
	for k in ["claimed_free", "claimed_vip", "claimed_bank"]:
		if not (w.get(k) is Array):
			w[k] = []
	if not (w.get("pending_end") is Dictionary):
		w["pending_end"] = {}
	w["points"] = int(w.get("points", 0))
	return w


static func main_milestones() -> Array:
	return Config.WEEKLY.get("main", [])


static func last_points() -> int:
	var m := main_milestones()
	return int(m[m.size() - 1].points) if not m.is_empty() else 0


static func points(s: Dictionary) -> int:
	return int(_w(s).points)


static func is_vip(s: Dictionary) -> bool:
	return bool(_w(s).get("vip", false))


static func _has(arr: Array, i: int) -> bool:
	for v in arr:
		if int(v) == i:
			return true
	return false


static func free_claimable(s: Dictionary, i: int) -> bool:
	var w := _w(s)
	var m := main_milestones()
	return i >= 0 and i < m.size() and int(w.points) >= int(m[i].points) and not _has(w.claimed_free, i)


static func vip_claimable(s: Dictionary, i: int) -> bool:
	var w := _w(s)
	var m := main_milestones()
	return i >= 0 and i < m.size() and bool(w.get("vip", false)) \
		and int(w.points) >= int(m[i].points) and not _has(w.claimed_vip, i)


## Số ô Main Tree đang nhận được (free + VIP) cộng ô Bonus Bank nhận được. Dùng cho badge.
static func claimable_count(s: Dictionary) -> int:
	var n := 0
	for i in main_milestones().size():
		n += int(free_claimable(s, i)) + int(vip_claimable(s, i))
	for i in bank_slots(s):
		n += int(bank_claimable(s, i))
	return n


static func claim_free(s: Dictionary, i: int) -> Dictionary:
	if not free_claimable(s, i):
		return {}
	_w(s).claimed_free.append(i)
	return _reward(main_milestones()[i].get("free", {}))


static func claim_vip(s: Dictionary, i: int) -> Dictionary:
	if not vip_claimable(s, i):
		return {}
	_w(s).claimed_vip.append(i)
	return _reward(main_milestones()[i].get("vip", {}))


## Nhận hết Main Tree. Trả {reward, count}.
static func claim_all_main(s: Dictionary) -> Dictionary:
	var total := _empty()
	var n := 0
	for i in main_milestones().size():
		var f := claim_free(s, i)
		if not f.is_empty():
			total = merge(total, f)
			n += 1
		var v := claim_vip(s, i)
		if not v.is_empty():
			total = merge(total, v)
			n += 1
	return {"reward": total, "count": n}


# --- Bonus Bank ---

## Số mốc bank đã đạt: mỗi `bank_step` key thừa sau mốc cuối, tối đa `bank_max`.
static func bank_slots(s: Dictionary) -> int:
	var step := maxi(int(Config.WEEKLY.get("bank_step", 15)), 1)
	var extra := int(_w(s).points) - last_points()
	if extra <= 0:
		return 0
	@warning_ignore("integer_division")
	return mini(int(Config.WEEKLY.get("bank_max", 10)), extra / step)


## Mở khi đủ điểm mốc cuối, đã mua VIP và đã xem End popup.
static func bank_unlocked(s: Dictionary) -> bool:
	var w := _w(s)
	return int(w.points) >= last_points() and bool(w.get("vip", false)) and bool(w.get("end_seen", false))


static func bank_claimable(s: Dictionary, i: int) -> bool:
	return bank_unlocked(s) and i >= 0 and i < bank_slots(s) and not _has(_w(s).claimed_bank, i)


static func claim_bank(s: Dictionary, i: int) -> Dictionary:
	if not bank_claimable(s, i):
		return {}
	_w(s).claimed_bank.append(i)
	return {"coins": int(Config.WEEKLY.get("bank_reward_coins", 0)), "items": {}}


static func claim_all_bank(s: Dictionary) -> Dictionary:
	var total := _empty()
	var n := 0
	for i in bank_slots(s):
		var r := claim_bank(s, i)
		if not r.is_empty():
			total = merge(total, r)
			n += 1
	return {"reward": total, "count": n}


## Đã chạm mốc cuối thì End popup được tính là đã xem (UI gọi khi hiện).
static func mark_end_seen(s: Dictionary) -> void:
	var w := _w(s)
	if int(w.points) >= last_points():
		w["end_seen"] = true


# --- điểm và VIP ---

## Điểm key cho một level thắng. kind: "" | "hard" | "very_hard".
static func points_for(kind: String) -> int:
	match kind:
		"hard":
			return int(Config.WEEKLY.get("points_hard", 3))
		"very_hard":
			return int(Config.WEEKLY.get("points_very_hard", 5))
	return int(Config.WEEKLY.get("points_normal", 1))


## Cộng key khi thắng. Chỉ khi Active. Trả số điểm đã cộng.
static func add_points(s: Dictionary, st: String, kind: String) -> int:
	if st != ACTIVE:
		return 0
	var n := points_for(kind)
	var w := _w(s)
	w["points"] = int(w.points) + n
	return n


static func on_vip_purchased(s: Dictionary) -> void:
	_w(s)["vip"] = true


## Cửa sổ chu kỳ này đã mở (Home dùng cho chấm thông báo).
static func mark_opened(s: Dictionary) -> void:
	_w(s)["opened"] = true


## Thưởng tạm của VIP: +N mạng tối đa khi Active.
static func heart_bonus(s: Dictionary, st: String) -> int:
	if st == ACTIVE and is_vip(s):
		return int(Config.WEEKLY.get("vip_bonus_hearts", 3))
	return 0


# --- sang mùa ---

## So chu kỳ đã lưu với chu kỳ hiện tại. Khác nhau thì chốt mùa cũ rồi reset.
## Chỉ VIP tự nhận mọi thưởng chưa claim (Main free, Main VIP, Bonus Bank). Người không VIP
## không nhận lại phần free chưa claim. Trả {settled, reward} (reward {coins, items}).
## Ghi s.weekly.pending_end để UI hiện popup cuối mùa một lần.
static func refresh(s: Dictionary, now: int, tz: int) -> Dictionary:
	var w := _w(s)
	var cycle: String = window(now, tz).cycle
	if str(w.get("cycle", "")) == cycle:
		return {"settled": false, "reward": _empty()}
	var old: String = str(w.get("cycle", ""))
	var result := {"settled": false, "reward": _empty()}
	if old != "" and (int(w.points) > 0 or is_vip(s)):
		var was_vip := is_vip(s)
		var pts := int(w.points)
		var total := _empty()
		if was_vip:
			total = merge(total, claim_all_main(s).reward)
			w["end_seen"] = true  # mùa đã hết: Bank coi như đã xem End popup
			total = merge(total, claim_all_bank(s).reward)
		result = {"settled": true, "reward": total}
		w["pending_end"] = {"vip": was_vip, "points": pts,
			"coins": int(total.coins), "items": (total.items as Dictionary).duplicate()}
	w["cycle"] = cycle
	w["points"] = 0
	w["vip"] = false
	w["opened"] = false
	w["end_seen"] = false
	w["claimed_free"] = []
	w["claimed_vip"] = []
	w["claimed_bank"] = []
	return result


## Lấy và xoá popup cuối mùa đang chờ ({} nếu không có).
static func take_pending_end(s: Dictionary) -> Dictionary:
	var w := _w(s)
	var p: Dictionary = (w.pending_end as Dictionary).duplicate(true)
	w["pending_end"] = {}
	return p
