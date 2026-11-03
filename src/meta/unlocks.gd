extends RefCounted
## Mở khoá theo level (Config.UNLOCK) và quà hướng dẫn booster.

const Config := preload("res://src/config.gd")

## Luôn mở, không nằm trong Config.UNLOCK.
const ALWAYS_OPEN := ["rescue", "avatar", "frame"]
## Booster được tặng một lần khi tới level mở, theo thứ tự.
const GIFT_ORDER := ["hint", "move", "smash"]
## Không hiện như một "tính năng mới" trên thanh tiến trình của thẻ thắng.
const SILENT := ["starter", "review"]
## Mở màn/nút mới ở Home: thắng xong dẫn người chơi về Home để thấy.
const HOME_FEATURES := ["daily_gift", "shop", "challenge", "lives"]


## `level` là level đang chơi/sắp chơi (người chơi đang ở level này).
static func is_open(feature: String, level: int) -> bool:
	if feature in ALWAYS_OPEN:
		return true
	if not Config.UNLOCK.has(feature):
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


## Tính năng người chơi thấy được và mở đúng ở `level` (sắp theo tên). `max_level` > 0 là trần nội dung (demo).
static func features_at(level: int, max_level: int = 0) -> Array[String]:
	var out: Array[String] = []
	if level <= 1 or (max_level > 0 and level > max_level):
		return out
	for k in Config.UNLOCK:
		if k not in SILENT and int(Config.UNLOCK[k]) == level:
			out.append(str(k))
	out.sort()
	return out


## Thanh tiến trình trên thẻ thắng. `level` là level vừa thắng.
## {has_next, start, end, before, after, features (ở mốc kế tiếp), unlocked (mở ngay khi sang level kế)}.
static func feature_progress(level: int, max_level: int = 0) -> Dictionary:
	var marks: Array[int] = []
	for k in Config.UNLOCK:
		var lv := int(Config.UNLOCK[k])
		if k in SILENT or lv <= 1 or (max_level > 0 and lv > max_level) or lv in marks:
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
