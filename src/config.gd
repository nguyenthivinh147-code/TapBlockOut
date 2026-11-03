extends RefCounted
## Mọi con số kinh tế, quảng cáo, mở khoá, offer. Số theo design.md mục 3-7.
## Remote Config ghi đè bằng apply_remote(); reset() trả về mặc định (dùng trong test).
## Gold trong code tên `coins`.

const _ECON := {
	"start_coins": 1000,
	"win_coins": 40,
	"booster_price": {"hint": 900, "move": 1900, "smash": 2900},
	"refill_coins": 900,
	"refill_lives": 5,
	"shop_video_coins": 200,
	"shop_video_max": 5,
	"rescue_prices": [1900, 2200, 2500, 2800],
	"rescue_moves": 3,
	"rescue_video_max": 4,
	"challenge_coins": 100,
}

const _LIVES := {
	"max": 10,
	"regen_sec": 900,
	"from_level": 10,
}

const _ADS := {
	"inter_from_run": 4,
	"inter_every": 2,
	"inter_cooldown": 120,
	"session_warmup": 90,
	"rewarded_grace": 45,
	"first_session_block_until_level": 10,
}

const _UNLOCK := {
	"daily_gift": 4, "hint": 5, "shop": 5, "move": 12, "smash": 17,
	"lives": 10, "starter": 10, "review": 10, "challenge": 50,
	"stone": 14, "ice": 30, "chain": 40, "layer": 55, "fog": 70, "pulse": 90,
}

## 28 ô quà. Tổng: 6.650 gold, 5 hint, 5 move, 4 smash.
const _DAILY := [
	{"coins": 50, "items": {}},
	{"coins": 100, "items": {}},
	{"coins": 0, "items": {"hint": 1}},
	{"coins": 200, "items": {}},
	{"coins": 0, "items": {"move": 1}},
	{"coins": 300, "items": {}},
	{"coins": 500, "items": {"smash": 1}},
	{"coins": 100, "items": {}},
	{"coins": 150, "items": {}},
	{"coins": 0, "items": {"hint": 1}},
	{"coins": 250, "items": {}},
	{"coins": 0, "items": {"move": 1}},
	{"coins": 350, "items": {}},
	{"coins": 600, "items": {"smash": 1}},
	{"coins": 150, "items": {}},
	{"coins": 200, "items": {}},
	{"coins": 0, "items": {"hint": 1}},
	{"coins": 300, "items": {}},
	{"coins": 0, "items": {"move": 1}},
	{"coins": 400, "items": {}},
	{"coins": 700, "items": {"smash": 1}},
	{"coins": 200, "items": {}},
	{"coins": 250, "items": {}},
	{"coins": 0, "items": {"hint": 1}},
	{"coins": 350, "items": {}},
	{"coins": 0, "items": {"move": 1}},
	{"coins": 500, "items": {}},
	{"coins": 1000, "items": {"smash": 1, "hint": 1, "move": 1}},
]

## avatar_01..N và frame_01..N; giá xoay vòng theo `prices`. *_00 miễn phí và luôn có.
const _COSMETICS := {
	"avatar_count": 12,
	"frame_count": 12,
	"prices": [50, 75, 100],
	"default_avatar": "avatar_00",
	"default_frame": "frame_00",
}

## usd, consumable, gold, inv (booster), no_ads. Gói sale là SKU riêng đuôi `_sale`.
const _SKUS := {
	"gold_pack_1": {"usd": 1.99, "consumable": true, "gold": 1000},
	"gold_pack_2": {"usd": 7.99, "consumable": true, "gold": 5000},
	"gold_pack_3": {"usd": 14.99, "consumable": true, "gold": 10000},
	"gold_pack_4": {"usd": 29.99, "consumable": true, "gold": 25000},
	"gold_pack_5": {"usd": 49.99, "consumable": true, "gold": 50000},
	"gold_pack_6": {"usd": 99.99, "consumable": true, "gold": 100000},
	"gold_pack_1_sale": {"usd": 0.99, "consumable": true, "gold": 2000},
	"gold_pack_2_sale": {"usd": 3.99, "consumable": true, "gold": 5000},
	"gold_pack_3_sale": {"usd": 7.49, "consumable": true, "gold": 10000},
	"gold_pack_4_sale": {"usd": 14.99, "consumable": true, "gold": 25000},
	"gold_pack_5_sale": {"usd": 24.99, "consumable": true, "gold": 50000},
	"gold_pack_6_sale": {"usd": 49.99, "consumable": true, "gold": 100000},
	"remove_ads": {"usd": 4.99, "consumable": false, "gold": 500, "no_ads": true},
	"starter_pack": {"usd": 6.99, "consumable": false, "gold": 6000,
		"inv": {"hint": 1, "move": 1, "smash": 1}},
	"rescue_pack": {"usd": 0.99, "consumable": true, "inv": {"move": 1}},
	"level_pack": {"usd": 4.99, "consumable": true, "gold": 2000,
		"inv": {"hint": 1, "move": 1, "smash": 1}},
	# Mua lại được mỗi tuần nên consumable; trạng thái VIP nằm ở s.weekly.vip.
	"weekly_pass": {"usd": 4.99, "consumable": true, "weekly_vip": true},
	"special_pack": {"usd": 10.99, "consumable": true, "gold": 12000,
		"inv": {"hint": 2, "move": 2, "smash": 2}},
	"special_pack_sale": {"usd": 5.49, "consumable": true, "gold": 12000,
		"inv": {"hint": 2, "move": 2, "smash": 2}},
	# Bước Pay của Chain Offer: thưởng lấy từ chính gói.
	"chain_pack_1": {"usd": 0.99, "consumable": true, "gold": 1500},
	"chain_pack_2": {"usd": 2.99, "consumable": true, "gold": 3000,
		"inv": {"hint": 1, "move": 1}},
}

## Điều kiện hiện gói (PackConditionSO). level_appear: từ level này; purchase_limit: 0 = không giới hạn;
## required: phải đã mua đủ các gói này; exclude: đã sở hữu gói nào trong đây thì ẩn.
const _PACKS := {
	"special_pack": {"sku": "special_pack", "level_appear": 16, "purchase_limit": 0,
		"required": ["starter_pack"], "exclude": []},
}

## Weekly Pass. Chu kỳ: thứ Hai 06:00 -> thứ Hai 00:00 tuần sau (giờ máy); thứ Hai 00:00-06:00 là Waiting.
## points: điểm key theo độ khó; unlock_hard_index: mở sau level HARD thứ N.
## main: mỗi mốc {points, free, vip} với thưởng {coins, items, inf_min}; inf_min là số phút mạng vô hạn. Mốc đầu có points = 0 (mốc khởi đầu,
## nhận được ngay, là phần thưởng "đầu tiên" mà tutorial chỉ vào). bank: sau mốc cuối,
## mỗi `bank_step` key thừa được 1 mốc, tối đa `bank_max` mốc, mỗi mốc là `bank_reward`.
const _WEEKLY := {
	"enabled": true,
	"sku": "weekly_pass",
	"unlock_hard_index": 2,
	"start_hour": 6,
	"vip_bonus_hearts": 3,
	"points_normal": 1,
	"points_hard": 3,
	"points_very_hard": 5,
	"bank_step": 15,
	"bank_max": 10,
	"bank_reward_coins": 400,
	"main": [
		{"points": 0, "free": {"coins": 0, "items": {}, "inf_min": 15}, "vip": {"coins": 150, "items": {}}},
		{"points": 3, "free": {"coins": 100, "items": {}}, "vip": {"coins": 200, "items": {}, "inf_min": 30}},
		{"points": 8, "free": {"coins": 0, "items": {"hint": 1}}, "vip": {"coins": 300, "items": {"hint": 1}}},
		{"points": 15, "free": {"coins": 150, "items": {}}, "vip": {"coins": 400, "items": {}}},
		{"points": 25, "free": {"coins": 0, "items": {"move": 1}}, "vip": {"coins": 0, "items": {"move": 2}}},
		{"points": 38, "free": {"coins": 200, "items": {}}, "vip": {"coins": 600, "items": {}}},
		{"points": 52, "free": {"coins": 0, "items": {"smash": 1}}, "vip": {"coins": 0, "items": {"smash": 2}}},
		{"points": 68, "free": {"coins": 300, "items": {}}, "vip": {"coins": 800, "items": {}}},
		{"points": 85, "free": {"coins": 0, "items": {"hint": 1, "move": 1}}, "vip": {"coins": 500, "items": {"hint": 2, "move": 2}}},
		{"points": 105, "free": {"coins": 400, "items": {}}, "vip": {"coins": 1000, "items": {}}},
		{"points": 130, "free": {"coins": 500, "items": {"smash": 1}}, "vip": {"coins": 2000, "items": {"smash": 2}}},
	],
}

## Chain Offer. days_to_existence: sống bấy nhiêu ngày từ lúc bật; days_to_reset: nghỉ bấy nhiêu ngày
## sau khi hết hạn; level_unlock: từ level này; require_lose: -1 = xét sau mọi ván, khác -1 = chỉ sau
## khi thua ở level không HARD. Chuỗi xoay vòng theo thứ tự. Bước: type free | ad | pay.
const _CHAIN := {
	"days_to_existence": 1,
	"days_to_reset": 3,
	"level_unlock": 24,
	"require_lose": -1,
	"window": 6,
	"sequences": [
		{"id": "chain_a", "steps": [
			{"type": "free", "coins": 300, "items": {}},
			{"type": "ad", "coins": 0, "items": {"hint": 1}},
			{"type": "free", "coins": 500, "items": {}},
			{"type": "pay", "sku": "chain_pack_1"},
			{"type": "ad", "coins": 0, "items": {"move": 1}},
			{"type": "free", "coins": 800, "items": {"smash": 1}},
			{"type": "pay", "sku": "chain_pack_2"},
			{"type": "ad", "coins": 1000, "items": {}},
		]},
		{"id": "chain_b", "steps": [
			{"type": "free", "coins": 0, "items": {"move": 1}},
			{"type": "ad", "coins": 400, "items": {}},
			{"type": "free", "coins": 0, "items": {"hint": 1, "smash": 1}},
			{"type": "pay", "sku": "chain_pack_2"},
			{"type": "ad", "coins": 600, "items": {}},
			{"type": "free", "coins": 1000, "items": {}},
			{"type": "pay", "sku": "chain_pack_1"},
			{"type": "ad", "coins": 0, "items": {"smash": 1}},
		]},
	],
}

## Offer. min_secs: không popup trong N giây đầu phiên đầu; gap_runs: cách nhau ít nhất N lượt.
## starter_pack: mở khi level > after_level hoặc runs >= at_run.
const _OFFERS := {
	"min_secs": 300,
	"gap_runs": 3,
	"starter_pack": {"sku": "starter_pack", "after_level": 10, "at_run": 12, "hours": 48},
	"remove_ads": {"sku": "remove_ads", "after_inter_today": 3, "per_day": 1, "max_total": 3},
	"rescue_pack": {"sku": "rescue_pack", "fail_streak": 3, "cooldown_hours": 24},
	"level_pack": {"sku": "level_pack", "every_levels": 10, "hours": 72},
}

## Lịch thông báo (theo GAME-GUIDE mục 15). Giờ theo giờ máy.
const _NOTIF := {
	"first_week_days": 7,
	"first_week_per_day": 3,
	"lead_min": 15,
	"daily_until_day": 14,
	"sparse_days": [16, 18, 21, 24, 27, 30],
	"earliest_hour": 8,
	"latest_hour": 22,
	"quiet_after_ignored": 9,
	"ask_after_run": 2,
}

const _CONTENT := {
	"demo_max_level": 20,
	"release_pregen_level": 100,
	"loop_start_level": 51,
	"slack_easy": 5,
	"slack_easy_until": 3,
	"slack_hard": 1,
	"very_hard_from_level": 100,
	"hard_banner_sec": 1.2,
	"slack_min": 2,
	"slack_pct": 10,
	"think_clap_sec": 8,
	"win_delay_sec": 0.8,
	"build": "v1",
	"support_email": "support@horusvn.com",
	"ftue_steps": ["open", "first_tap", "first_win", "first_x2", "first_booster", "run_2", "run_5", "level_10"],
}

## Ngày sale theo Time.get_datetime_dict_from_unix_time().weekday (0 = Chủ nhật, 6 = thứ Bảy).
const _SALE_WEEKDAYS := [5, 6, 0]
## Weekend sale cho ai: 1 = mọi người chơi, 2 = chỉ người chưa mua gói nào, 3 = tắt.
## Remote Config: `weekend_sale_mode`.
const _SALE_MODE := 1
## Số % ghi trên nhãn sale (chỉ để hiển thị; giá thật do SKU `_sale` quyết định).
const _SALE_PERCENT := 50

static var ECON: Dictionary = _ECON.duplicate(true)
static var LIVES: Dictionary = _LIVES.duplicate(true)
static var ADS: Dictionary = _ADS.duplicate(true)
static var UNLOCK: Dictionary = _UNLOCK.duplicate(true)
static var DAILY: Array = _DAILY.duplicate(true)
static var COSMETICS: Dictionary = _COSMETICS.duplicate(true)
static var SKUS: Dictionary = _SKUS.duplicate(true)
static var OFFERS: Dictionary = _OFFERS.duplicate(true)
static var NOTIF: Dictionary = _NOTIF.duplicate(true)
static var PACKS: Dictionary = _PACKS.duplicate(true)
static var WEEKLY: Dictionary = _WEEKLY.duplicate(true)
static var CHAIN: Dictionary = _CHAIN.duplicate(true)
static var CONTENT: Dictionary = _CONTENT.duplicate(true)
static var SALE_WEEKDAYS: Array = _SALE_WEEKDAYS.duplicate(true)
static var SALE_MODE: int = _SALE_MODE
static var SALE_PERCENT: int = _SALE_PERCENT


## Công tắc cho test: -1 theo OS.has_feature("demo"), 0 ép bản phát hành, 1 ép bản demo.
## reset() trả về -1.
static var demo_override: int = -1


static func is_demo() -> bool:
	if demo_override >= 0:
		return demo_override > 0
	return OS.has_feature("demo")


## Trả mọi nhóm về mặc định (test dùng sau khi apply_remote).
static func reset() -> void:
	demo_override = -1
	ECON = _ECON.duplicate(true)
	LIVES = _LIVES.duplicate(true)
	ADS = _ADS.duplicate(true)
	UNLOCK = _UNLOCK.duplicate(true)
	DAILY = _DAILY.duplicate(true)
	COSMETICS = _COSMETICS.duplicate(true)
	SKUS = _SKUS.duplicate(true)
	OFFERS = _OFFERS.duplicate(true)
	NOTIF = _NOTIF.duplicate(true)
	PACKS = _PACKS.duplicate(true)
	WEEKLY = _WEEKLY.duplicate(true)
	CHAIN = _CHAIN.duplicate(true)
	CONTENT = _CONTENT.duplicate(true)
	SALE_WEEKDAYS = _SALE_WEEKDAYS.duplicate(true)
	SALE_MODE = _SALE_MODE
	SALE_PERCENT = _SALE_PERCENT


## Mọi id avatar hoặc frame (kind: "avatar" | "frame"), gồm cả *_00 mặc định ở đầu.
static func cosmetic_ids(kind: String) -> Array:
	var ids: Array = []
	var n: int = int(COSMETICS.get(kind + "_count", 0))
	for i in range(0, n + 1):
		ids.append("%s_%02d" % [kind, i])
	return ids


## Giá gold của một món; *_00 hoặc id lạ trả 0.
static func cosmetic_price(id: String) -> int:
	var parts := id.rsplit("_", true, 1)
	if parts.size() != 2 or not parts[1].is_valid_int():
		return 0
	var n: int = int(parts[1])
	var prices: Array = COSMETICS.get("prices", [])
	if n < 1 or prices.is_empty():
		return 0
	return int(prices[(n - 1) % prices.size()])


## Ghi đè từ Remote Config. Khoá `<nhóm>_<khoá>` (chữ thường, ví dụ `econ_win_coins`,
## `econ_booster_price_hint`, `skus_starter_pack_usd`, `content_ftue_steps`); giá trị là chuỗi
## được ép về đúng kiểu cũ (mảng: các phần tử cách nhau bằng dấu phẩy). Khoá lạ, giá trị hỏng,
## số âm và chuỗi rỗng bị bỏ qua. `DAILY` (mảng ô) không ghi đè được.
static func apply_remote(values: Dictionary) -> void:
	var groups := {
		"econ": ECON, "lives": LIVES, "ads": ADS, "unlock": UNLOCK,
		"cosmetics": COSMETICS, "skus": SKUS, "offers": OFFERS,
		"notif": NOTIF, "content": CONTENT, "weekly": WEEKLY, "chain": CHAIN,
	}
	for raw_key in values:
		var key := str(raw_key).to_lower()
		var raw: Variant = values[raw_key]
		if not (raw is String):
			continue
		if key == "sale_weekdays":
			var arr: Variant = _coerce(SALE_WEEKDAYS, raw)
			if arr != null:
				SALE_WEEKDAYS = arr
			continue
		if key == "weekend_sale_mode":
			var mode: Variant = _coerce(SALE_MODE, raw)
			if mode != null and int(mode) >= 1 and int(mode) <= 3:
				SALE_MODE = int(mode)
			continue
		if key == "sale_percent":
			var pct: Variant = _coerce(SALE_PERCENT, raw)
			if pct != null and int(pct) <= 99:
				SALE_PERCENT = int(pct)
			continue
		for g in groups:
			if key.begins_with(g + "_"):
				_set_path(groups[g], key.substr(g.length() + 1), raw)
				break


static func _set_path(d: Dictionary, path: String, raw: String) -> bool:
	if d.has(path):
		if d[path] is Dictionary:
			return false
		var v: Variant = _coerce(d[path], raw)
		if v == null:
			return false
		d[path] = v
		return true
	for k in d:
		if d[k] is Dictionary and path.begins_with(str(k) + "_"):
			if _set_path(d[k], path.substr(str(k).length() + 1), raw):
				return true
	return false


## Ép chuỗi `raw` về kiểu của `old`. Trả null nếu hỏng.
static func _coerce(old: Variant, raw: String) -> Variant:
	var s := raw.strip_edges()
	if s.is_empty():
		return null
	match typeof(old):
		TYPE_INT:
			if not s.is_valid_int() or int(s) < 0:
				return null
			return int(s)
		TYPE_FLOAT:
			if not s.is_valid_float() or float(s) < 0.0:
				return null
			return float(s)
		TYPE_BOOL:
			var low := s.to_lower()
			if low == "1" or low == "true":
				return true
			if low == "0" or low == "false":
				return false
			return null
		TYPE_STRING:
			return s
		TYPE_ARRAY:
			var arr: Array = old
			if arr.is_empty() or typeof(arr[0]) == TYPE_DICTIONARY or typeof(arr[0]) == TYPE_ARRAY:
				return null
			var out: Array = []
			for part in s.split(",", false):
				var e: Variant = _coerce(arr[0], part)
				if e == null:
					return null
				out.append(e)
			if out.is_empty():
				return null
			return out
	return null
