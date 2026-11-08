extends RefCounted
## Mở khoá theo level (Config.UNLOCK) và quà hướng dẫn booster.

const Config := preload("res://src/config.gd")

## Luôn mở, không nằm trong Config.UNLOCK.
const ALWAYS_OPEN := ["rescue", "avatar", "frame"]
## Booster được tặng một lần khi tới level mở, theo thứ tự.
const GIFT_ORDER := ["hint", "move", "smash"]
## Cơ chế, mỗi cái có một level dạy (design.md mục 4); popup cơ chế mới hiện một lần ở level đó.
const MECHS := ["stone", "ice", "chain", "layer", "fog", "pulse"]
## Không hiện như một "tính năng mới" trên thanh tiến trình của thẻ thắng.
const SILENT := ["starter", "review"]
## Mở màn/nút mới ở Home: thắng xong dẫn người chơi về Home để thấy. Road Trip (mở ngay sau L1) không có ở đây để
## L1 -> L2 liền mạch; hướng dẫn Road Trip hiện lần đầu người chơi về Home.
const HOME_FEATURES := ["daily_gift", "shop", "challenge", "lives", "leaderboard"]


## Switched on in Config.FEATURES (a feature not listed there is on).
static func enabled(feature: String) -> bool:
	return bool(Config.FEATURES.get(feature, true))


## `level` là level đang chơi/sắp chơi (người chơi đang ở level này).
static func is_open(feature: String, level: int) -> bool:
	if feature in ALWAYS_OPEN:
		return true
	if not Config.UNLOCK.has(feature) or not enabled(feature):
		return false
	return level >= int(Config.UNLOCK[feature])


## Booster cần tặng ở level này ("" nếu không có). Gọi lặp lại tới khi hết.
static func pending_gift(s: Dictionary, level: int) -> String:
	for k in GIFT_ORDER:
		if level >= int(Config.UNLOCK.get(k, 1 << 30)) and not bool(s.gifted.get(k, false)):
			return k
	return ""


## Chỉ đánh dấu đã tặng. Việc cộng vào kho do người gọi làm (Wallet.inv_add).
static func mark_gifted(s: Dictionary, kind: String) -> void:
	if kind in GIFT_ORDER:
		s.gifted[kind] = true


## Cơ chế cần giới thiệu ở `level` ("" nếu không có): chỉ đúng level dạy của nó (Config.UNLOCK) và chưa xem.
static func pending_mech(s: Dictionary, level: int) -> String:
	var seen: Array = s.get("mech_seen", [])
	for m in MECHS:
		if level == int(Config.UNLOCK.get(m, -1)) and not (m in seen):
			return m
	return ""


static func mark_mech_seen(s: Dictionary, mech: String) -> void:
	if mech not in MECHS:
		return
	if not (s.get("mech_seen") is Array):
		s["mech_seen"] = []
	if mech not in s.mech_seen:
		s.mech_seen.append(mech)


## Tính năng người chơi thấy được và mở đúng ở `level` (sắp theo tên). `max_level` > 0 là trần nội dung (demo).
static func features_at(level: int, max_level: int = 0) -> Array[String]:
	var out: Array[String] = []
	if level <= 1 or (max_level > 0 and level > max_level):
		return out
	for k in Config.UNLOCK:
		if k not in SILENT and enabled(str(k)) and int(Config.UNLOCK[k]) == level:
			out.append(str(k))
	out.sort()
	return out


## Thanh tiến trình trên thẻ thắng. `level` là level vừa thắng.
## {has_next, start, end, before, after, features (ở mốc kế tiếp), unlocked (mở ngay khi sang level kế)}.
static func feature_progress(level: int, max_level: int = 0) -> Dictionary:
	var marks: Array[int] = []
	for k in Config.UNLOCK:
		var lv := int(Config.UNLOCK[k])
		if k in SILENT or not enabled(str(k)) or lv <= 1 or (max_level > 0 and lv > max_level) or lv in marks:
			continue
		marks.append(lv)
	marks.sort()
	var start := 1
	var end := -1
	for lv in marks:
		if lv <= level:
			start = lv
		elif end < 0:
			end = lv
	var res := {
		"has_next": false, "start": start, "end": end, "before": 0.0, "after": 0.0,
		"features": [] as Array[String], "unlocked": features_at(level + 1, max_level),
	}
	if end < 0:
		return res
	var span := float(end - start)
	res.has_next = true
	res.before = clampf(float(level - start) / span, 0.0, 1.0)
	res.after = clampf(float(level + 1 - start) / span, 0.0, 1.0)
	res.features = features_at(end, max_level)
	return res


## Có tính năng ở Home vừa mở không (đưa người chơi về Home).
static func opens_home(unlocked: Array) -> bool:
	for k in unlocked:
		if k in HOME_FEATURES:
			return true
	return false
