extends RefCounted
## Offer và sale. Logic thuần: giờ truyền vào (now: unix giây, day: số ngày), không gọi AdPacing.
## Ghi vào s.offers {last_run, items: {id: {shown, at, until, bought, bought_at, day, day_n, key}}}
## và s.fail_streak {level, count}.

const Clock := preload("res://src/meta/clock.gd")
const Config := preload("res://src/config.gd")

## Thứ tự ưu tiên khi nhiều offer cùng đủ điều kiện.
const ORDER := ["starter_pack", "remove_ads", "rescue_pack", "level_pack"]
const GOLD_PREFIX := "gold_pack_"
const SALE_SUFFIX := "_sale"


## Hôm nay có sale không (thứ Bảy và Chủ nhật theo giờ máy, Config.SALE_WEEKDAYS).
static func is_sale(now: int, tz: int) -> bool:
	return Config.SALE_WEEKDAYS.has(Clock.weekday(now, tz))


## Các gói gold theo thứ tự, mỗi gói đúng SKU thường hoặc `_sale`.
## [{id: "gold_pack_1", sku, usd, gold, consumable, sale}]
static func catalog(now: int, tz: int) -> Array:
	var sale := is_sale(now, tz)
	var ids: Array = []
	for k in Config.SKUS:
		var key := str(k)
		if key.begins_with(GOLD_PREFIX) and not key.ends_with(SALE_SUFFIX):
			ids.append(key)
	ids.sort()
	var out: Array = []
	for id in ids:
		var sku: String = id
		var use_sale: bool = sale and Config.SKUS.has(id + SALE_SUFFIX)
		if use_sale:
			sku = id + SALE_SUFFIX
		var d: Dictionary = Config.SKUS[sku]
		out.append({
			"id": id, "sku": sku, "usd": float(d.get("usd", 0.0)),
			"gold": int(d.get("gold", 0)), "consumable": bool(d.get("consumable", true)),
			"sale": use_sale,
		})
	return out


## Offer nên hiện bây giờ, "" nếu không có.
## ctx {now, day, level (level sắp chơi), runs, session_start, first_session, inter_today,
##      on_lose (tuỳ chọn: true chỉ xét rescue_pack, false loại rescue_pack, thiếu thì xét hết)}.
static func due(s: Dictionary, ctx: Dictionary) -> String:
	var now: int = int(ctx.get("now", 0))
	var runs: int = int(ctx.get("runs", 0))
	var cfg: Dictionary = Config.OFFERS
	if bool(ctx.get("first_session", false)) \
			and now - int(ctx.get("session_start", now)) < int(cfg.get("min_secs", 300)):
		return ""
	var offers: Dictionary = s.get("offers", {})
	if runs - int(offers.get("last_run", -999)) < int(cfg.get("gap_runs", 3)):
		return ""
	var on_lose: Variant = ctx.get("on_lose", null)
	for id in ORDER:
		if on_lose != null and (id == "rescue_pack") != bool(on_lose):
			continue
		if _eligible(s, id, ctx):
			return id
	return ""


static func _eligible(s: Dictionary, id: String, ctx: Dictionary) -> bool:
	var cfg: Dictionary = Config.OFFERS.get(id, {})
	if cfg.is_empty():
		return false
	var now: int = int(ctx.get("now", 0))
	var it := _item(s, id)
	if int(it.until) > now:
		return false  # đang mở, không hiện lại
	if _once(id) and int(it.bought) > 0:
		return false
	match id:
		"starter_pack":
			if int(it.shown) > 0:
				return false  # một lần: đã mở rồi hết hạn thì thôi
			return int(ctx.get("level", 1)) > int(cfg.after_level) \
				or int(ctx.get("runs", 0)) >= int(cfg.at_run)
		"remove_ads":
			if bool(s.get("no_ads", false)) or int(it.shown) >= int(cfg.max_total):
				return false
			if int(it.day) == int(ctx.get("day", 0)) and int(it.day_n) >= int(cfg.per_day):
				return false
			return int(ctx.get("inter_today", 0)) >= int(cfg.after_inter_today)
		"rescue_pack":
			var fs: Dictionary = s.get("fail_streak", {})
			if int(fs.get("count", 0)) < int(cfg.fail_streak):
				return false
			return int(it.shown) == 0 or now - int(it.at) >= int(cfg.cooldown_hours) * 3600
		"level_pack":
			if not open_offers(s, now).is_empty():
				return false  # không chồng offer: chờ offer đang mở hết đã
			return _milestone(cfg, int(ctx.get("level", 1))) > int(it.key)
	return false


## Mốc level đã qua chia cho every_levels (level sắp chơi 11 nghĩa là đã qua 10).
static func _milestone(cfg: Dictionary, level: int) -> int:
	@warning_ignore("integer_division")
	return maxi(level - 1, 0) / maxi(int(cfg.every_levels), 1)


static func _once(id: String) -> bool:
	var sku: String = str(Config.OFFERS.get(id, {}).get("sku", id))
	return not bool(Config.SKUS.get(sku, {}).get("consumable", true))


## Bản ghi của một offer; tạo mới nếu chưa có. Ép kiểu số sau khi nạp JSON.
static func _item(s: Dictionary, id: String) -> Dictionary:
	if not (s.get("offers") is Dictionary):
		s["offers"] = {"last_run": -999, "items": {}}
	var offers: Dictionary = s.offers
	if not (offers.get("items") is Dictionary):
		offers["items"] = {}
	var items: Dictionary = offers.items
	if not (items.get(id) is Dictionary):
		items[id] = {}
	var it: Dictionary = items[id]
	for k in ["shown", "at", "until", "bought", "bought_at", "day_n", "key"]:
		it[k] = int(it.get(k, 0))
	it["day"] = int(it.get("day", -1))
	return it


## Gọi khi popup offer hiện ra. ctx {now, day, runs, level}.
## Offer có `hours` bắt đầu đếm hạn lần đầu hiện (hiện lại khi đang mở không gia hạn).
static func shown(s: Dictionary, id: String, ctx: Dictionary) -> void:
	var cfg: Dictionary = Config.OFFERS.get(id, {})
	var now: int = int(ctx.get("now", 0))
	var day: int = int(ctx.get("day", 0))
	var it := _item(s, id)
	it.shown += 1
	it.at = now
	if int(it.day) != day:
		it.day = day
		it.day_n = 0
	it.day_n += 1
	var hours: int = int(cfg.get("hours", 0))
	if hours > 0 and int(it.until) <= now:
		it.until = now + hours * 3600
	if id == "level_pack":
		it.key = _milestone(cfg, int(ctx.get("level", 1)))
	s.offers["last_run"] = int(ctx.get("runs", 0))


## Gọi sau khi giao hàng. Đóng cửa sổ mở của offer; offer mua một lần thì không hiện lại.
static func bought(s: Dictionary, id: String, now: int) -> void:
	var it := _item(s, id)
	it.bought += 1
	it.bought_at = now
	it.until = 0


## Offer đang mở (còn hạn, chưa bị mua nếu mua một lần), sắp theo hạn gần nhất.
## [{id, sku, until}]
static func open_offers(s: Dictionary, now: int) -> Array:
	var out: Array = []
	for id in ORDER:
		if not Config.OFFERS.has(id):
			continue
		var it := _item(s, id)
		if int(it.until) <= now or (_once(id) and int(it.bought) > 0):
			continue
		out.append({"id": id, "sku": str(Config.OFFERS[id].get("sku", id)), "until": int(it.until)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.until < b.until)
	return out


## Thua level: cộng chuỗi thua liền cùng một level.
static func note_fail(s: Dictionary, level: int) -> void:
	var fs: Dictionary = s.get("fail_streak", {})
	if int(fs.get("level", 0)) == level:
		fs["count"] = int(fs.get("count", 0)) + 1
	else:
		fs["level"] = level
		fs["count"] = 1
	s["fail_streak"] = fs


## Thắng level: xoá chuỗi thua.
static func note_win(s: Dictionary, level: int) -> void:
	s["fail_streak"] = {"level": level, "count": 0}
